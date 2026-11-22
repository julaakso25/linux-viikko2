"""Record only measured course results. Run on B as root."""
import argparse
import fcntl
import hashlib
import json
import os
import pwd
import re
import stat
import subprocess
import tarfile
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/var/lib/jlinux-week4")
PRIVATE = ROOT / "private"
PUBLIC = ROOT / "public"
BACKUPS = Path("/var/backups/jlinux-web")
CRON = Path("/etc/cron.d/jlinux-web-backup")
STATE = PRIVATE / "mittaukset.json"


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def atomic(path, content, mode):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as f:
        f.write(content)
        os.fchmod(f.fileno(), mode)
    os.replace(f.name, path)


def health():
    values = command("mariadb", "-NBe", "SELECT @@server_id,@@read_only,@@replicate_do_table")
    if values.split() != ["2", "1", "jlweek2.counter"]:
        raise ValueError("B:n palvelintunnus, lukutila tai taulusuodatin poikkeaa asetuksesta.")
    status = command("mariadb", "-e", "SHOW SLAVE STATUS\\G")
    fields = dict(re.findall(r"(?m)^\s*([\w]+):[ \t]*(.*?)$", status))
    if (fields.get("Slave_IO_Running"), fields.get("Slave_SQL_Running")) != ("Yes", "Yes") or any(
            fields.get(k) != "0" for k in ("Last_IO_Errno", "Last_SQL_Errno")):
        raise ValueError("Replikaatio ei ole kunnossa. I/O: %s, SQL: %s" %
                         (fields.get("Last_IO_Error") or fields.get("Slave_IO_Running"),
                          fields.get("Last_SQL_Error") or fields.get("Slave_SQL_Running")))
    for unit in ("mariadb", "nginx", "cron", "jlinux-db-link.socket", "jlinux-week4"):
        if command("systemctl", "is-active", unit) != "active" or command("systemctl", "is-enabled", unit) != "enabled":
            raise ValueError("Tarkista palvelun tila ja automaattikäynnistys: " + unit)
    if not re.search(r"(?m)^\s*5\s+\*\s+\*\s+\*\s+\*\s+jlbackup\s+[^#]*?/usr/local/sbin/jlinux-web-backup\s+cron\s*$", CRON.read_text()):
        raise ValueError("Tarkista /etc/cron.d/jlinux-web-backup ja sen tuntiajo.")
    info = BACKUPS.stat()
    if pwd.getpwuid(info.st_uid).pw_name != "jlbackup" or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError("Varmistuskansion pitää olla jlbackup-tunnuksen omistama ja tilassa 0700.")
    return fields.get("Relay_Master_Log_File", "?"), fields.get("Exec_Master_Log_Pos", "?")


def cron_copies(text, directory):
    by_hour = {}
    for line in text.splitlines():
        if not re.search(r"\bcron\b[\] :=|\t-]*OK\b", line, re.I):
            continue
        found = re.search(r"([A-Za-z0-9][\w.-]*\.tar\.gz)\b", line)
        if not found:
            continue
        name = found[1]
        path = directory / name
        if path.is_symlink() or not path.is_file():
            continue
        timestamp = re.search(r"\d{8}T\d{6}Z", name)
        if timestamp:
            dt = datetime.strptime(timestamp[0], "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
        else:
            timestamp = re.search(r"\d{4}-\d\d-\d\d[T ]\d\d:\d\d:\d\d", line)
            if not timestamp:
                continue
            dt = datetime.fromisoformat(timestamp[0]).replace(tzinfo=timezone.utc)
        by_hour[dt.replace(minute=0, second=0, microsecond=0)] = (dt, name)
    return [by_hour[key] for key in sorted(by_hour)]


def restore_test(archive, expected, destination):
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tarfile.open(archive, "r:gz") as tar:
        member = next((m for m in tar if m.name.removeprefix("./") == "html/index.html" and m.isfile()), None)
        if not member:
            raise ValueError("Arkistosta puuttuu html/index.html.")
        with tar.extractfile(member) as src, destination.open("wb") as out:
            while chunk := src.read(65536):
                out.write(chunk)
    os.chmod(destination, 0o600)
    with destination.open("rb") as restored:
        actual = hashlib.file_digest(restored, "sha256").hexdigest()
    if actual != expected:
        raise ValueError("Palautetun index.html:n SHA-256 eroaa A:n alkuperäisestä.")
    return actual


def publish(state):
    lines = ["JLinux · viikon 4 mittaukset", ""]
    for key, label in (("ennen", "Ennen B:n uudelleenkäynnistystä"), ("jalkeen", "B:n uudelleenkäynnistyksen jälkeen")):
        if key in state:
            row = state[key]
            b1, b2, a, b3 = row["counts"]
            lines.extend([label + " — " + row["time"],
                          "Julkinen HTTP Windowsista: A /viikko2/, A /viikko3/ ja B /viikko4/ vastasivat.",
                          f"B:n kaksi peräkkäistä latausta: {b1} → {b2}. A:n lataus: {a}. B sen jälkeen: {b3}.",
                          "MariaDB: I/O Yes, SQL Yes, viimeiset virhekoodit 0. Lokikohta " + ":".join(row["position"]) + ".",
                          "Nginx, MariaDB, B:n sovellus, tietokantayhteyden socket ja cron aktiivisia ja käytössä.", ""])
    if "jalkeen" in state:
        lines += ["B:n käynnistystunniste vaihtui. Linuxin ilmoittama käynnistysaika " + state["boot_time"] + ".", ""]
    if "files" in state:
        result = state["files"]
        lines.append("Tuntivarmistukset ja palautus — " + result["time"])
        for event in result["copies"]:
            lines.append("Cron OK · " + event)
        lines += ["Uusin näistä arkistoista syntyi B:n uudelleenkäynnistyksen jälkeen.",
                  "Palautettu erilliseen sijaintiin /var/lib/jlinux-week4/private/palautus/index.html.",
                  "A:n alkuperäisen ja B:llä palautetun index.html:n sama SHA-256:", result["hash"]]
    else:
        lines.append("Kahden tuntivarmistuksen ja testipalautuksen tulos odottaa tarkistusta.")
    atomic(STATE, json.dumps(state, ensure_ascii=False), 0o600)
    atomic(PUBLIC / "TULOKSET.md", "\n".join(lines) + "\n", 0o644)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["ennen", "jalkeen", "odota", "valmis"])
    parser.add_argument("data", nargs="*")
    args = parser.parse_args()
    if os.geteuid() or os.uname().nodename.split(".")[0] != "jlinux-b":
        raise ValueError("Todennus kuuluu JLinux-B:n ylläpidolle.")
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    btime = int(re.search(r"(?m)^btime (\d+)$", Path("/proc/stat").read_text())[1])
    position = health()
    if args.phase in ("ennen", "jalkeen"):
        counts = list(map(int, args.data))
        if len(counts) != 4 or not (0 <= counts[0] == counts[1] < counts[2] <= counts[3]):
            raise ValueError("Julkisten laskuritestien tulokset eivät täsmää.")
        if args.phase == "ennen":
            state = {"boot_before": boot}
        else:
            if not state.get("ennen") or state["boot_before"] == boot:
                raise ValueError("Tee ennen-testi ja käynnistä sitten vain B uudelleen.")
            state.pop("files", None)
            state["boot_after"] = boot
            state["boot_time"] = datetime.fromtimestamp(btime, timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        state[args.phase] = {"time": now(), "counts": counts, "position": position}
        publish(state)
        print("Testi OK:", args.phase, *counts)
        return
    if args.phase == "valmis" and (len(args.data) != 1 or not re.fullmatch(r"[a-f0-9]{64}", args.data[0])):
        raise ValueError("Anna A:n alkuperäisen tiedoston SHA-256.")
    if not state.get("jalkeen") or state.get("boot_after") != boot:
        raise ValueError("Tee käynnistyksen jälkeinen julkinen testi ensin.")
    deadline = time.monotonic() + 2 * 3600 + 15 * 60
    while True:
        copies = cron_copies((BACKUPS / "backup.log").read_text(), BACKUPS)
        if len(copies) >= 2 and copies[-1][0].timestamp() >= btime:
            break
        if time.monotonic() >= deadline:
            raise ValueError("Kaksi ajastettua versiota ei toteutunut. Tarkista backup.log ja cron, korjaa syy ja aja valmis uudelleen.")
        print(f"Odotetaan cron-ajoja. Eri tuntien onnistuneita versioita: {len(copies)}. Tarvitaan myös ajo B:n käynnistyksen jälkeen.", flush=True)
        time.sleep(60)
    health()
    if args.phase == "odota":
        print("Kaksi ajastettua kopiota saatavilla. Verrataan nyt A:n alkuperäistä uusimpaan arkistoon.")
        return
    latest = copies[-2:]
    digest = restore_test(BACKUPS / latest[-1][1], args.data[0], PRIVATE / "palautus/index.html")
    state["files"] = {"time": now(), "copies": [dt.strftime("%Y-%m-%d %H:%M:%S UTC") + " · " + name for dt, name in latest], "hash": digest}
    publish(state)
    print("PALAUTUSTESTI OK — kaksi tuntivarmistusta, uusin rebootin jälkeen ja SHA-256 täsmää.")


if __name__ == "__main__":
    try:
        with (PRIVATE / "test.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            main()
    except (OSError, subprocess.CalledProcessError, ValueError, tarfile.TarError) as error:
        raise SystemExit(str(error))
