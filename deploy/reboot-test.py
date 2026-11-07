"""Run with sudo before and after reboot; use Nginx for all page loads."""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen

state = Path("/var/lib/jlinux-week2")
baseline = state / "baseline.json"
result = state / "result.txt"


def load_count():
    with urlopen("http://127.0.0.1/viikko2/", timeout=10) as response:
        match = re.search(rb'<strong id="visits">(\d+)</strong>', response.read())
    if not match:
        sys.exit("Laskuria ei löytynyt sivulta.")
    return int(match[1])


def save(path, content):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.chmod(0o644)
    temporary.replace(path)


if os.geteuid() != 0 or sys.argv[1:] not in (["ennen"], ["jalkeen"]):
    sys.exit("Käyttö: sudo python3 deploy/reboot-test.py ennen | jalkeen")
boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
if sys.argv[1] == "ennen":
    first = load_count()
    second = load_count()
    if second <= first:
        sys.exit("Laskuri ei kasvanut uudella latauksella.")
    save(baseline, json.dumps({"boot": boot, "count": second}))
    result.unlink(missing_ok=True)
    print(f"Peräkkäiset lataukset: {first} ja {second}. Lähtöarvo tallennettu.")
else:
    if not baseline.exists():
        sys.exit("Suorita ensin ennen-vaihe.")
    previous = json.loads(baseline.read_text())
    if previous["boot"] == boot:
        sys.exit("Kone on yhä samassa käynnistyksessä. Testi odottaa uudelleenkäynnistystä.")
    count = load_count()
    if count <= previous["count"]:
        sys.exit("Laskuri ei jatkanut lähtöarvosta. Tarkista tietokanta.")
    date = datetime.now(timezone.utc).strftime("%d.%m.%Y %H:%M UTC")
    report = f"Testattu {date}. Ennen virtuaalikoneen uudelleenkäynnistystä lukema oli {previous['count']}, ja sen jälkeen tehdyllä sivulatauksella se oli {count}."
    save(result, report)
    print(report)
