"""Connect a fresh replica at its dump coordinates. Preserve an existing channel's position."""
import re
import sys
import time
from pathlib import Path

import pymysql
from pymysql.cursors import DictCursor


def coordinates(dump):
    match = re.search(r"(?m)^--\s*CHANGE MASTER TO\s+MASTER_LOG_FILE='([\w.-]+)',\s*MASTER_LOG_POS=(\d+)", dump)
    if not match:
        raise ValueError("Lähtökopiosta puuttuu lokitiedosto tai sijainti.")
    return match[1], int(match[2])


def seed_counter(cur, path):
    dump = path.read_text()
    filename, position = coordinates(dump)
    seeds = re.findall(r"(?im)^INSERT INTO `?counter`? VALUES\s*\(\s*1\s*,\s*(\d+)\s*\)\s*;", dump)
    if len(seeds) != 1 or int(seeds[0]) > 2**64 - 1:
        raise ValueError("A:n tuoreesta lähtökopiosta pitää löytyä yksi kelvollinen laskuririvi id=1.")
    visits = int(seeds[0])
    cur.execute("CREATE DATABASE IF NOT EXISTS jlweek2")
    cur.execute("""CREATE TABLE IF NOT EXISTS jlweek2.counter (
                id TINYINT PRIMARY KEY, visits BIGINT UNSIGNED NOT NULL) ENGINE=InnoDB""")
    cur.execute("""INSERT INTO jlweek2.counter (id, visits) VALUES (1, %s)
                ON DUPLICATE KEY UPDATE visits=VALUES(visits)""", (visits,))
    cur.execute("SELECT visits FROM jlweek2.counter WHERE id=1")
    if cur.fetchone()["visits"] != visits:
        raise ValueError("B:n lähtölukeman tarkistus epäonnistui.")
    print(f"B:n lähtölukema {visits} A:n lokikohdassa {filename}:{position}.")
    return filename, position


def connect_replica(secret, seed_path):
    db = pymysql.connect(unix_socket="/run/mysqld/mysqld.sock", user="root",
                         autocommit=True, cursorclass=DictCursor)
    with db, db.cursor() as cur:
        cur.execute("SELECT @@server_id AS id, @@read_only AS ro")
        if cur.fetchone() != {"id": 2, "ro": 1}:
            raise ValueError("B:n pitää olla palvelin 2 ja lukutilassa.")
        cur.execute("SHOW ALL SLAVES STATUS")
        rows = cur.fetchall()
        if rows:
            if len(rows) != 1 or rows[0]["Master_Host"] != "127.0.0.1" or int(rows[0]["Master_Port"]) != 13306 or rows[0]["Master_User"] != "jlrepl" or rows[0].get("Connection_name", ""):
                raise ValueError("B:llä on eri replikaatioyhteys. Se jätettiin koskematta.")
        else:
            filename, position = seed_counter(cur, seed_path)
            cur.execute("""CHANGE MASTER TO MASTER_HOST='127.0.0.1', MASTER_PORT=13306,
                        MASTER_USER='jlrepl', MASTER_PASSWORD=%s, MASTER_LOG_FILE=%s,
                        MASTER_LOG_POS=%s, MASTER_USE_GTID=no, MASTER_SSL=0, MASTER_CONNECT_RETRY=5""",
                        (secret, filename, position))
        cur.execute("START SLAVE")
        for _ in range(35):
            cur.execute("SHOW SLAVE STATUS")
            status = cur.fetchone()
            if (status["Slave_IO_Running"], status["Slave_SQL_Running"]) == ("Yes", "Yes") and not status["Last_IO_Errno"] and not status["Last_SQL_Errno"]:
                print("Replikaatio OK. I/O Yes, SQL Yes.")
                return
            time.sleep(2)
        raise RuntimeError("Replikaatio ei käynnistynyt. I/O: %s; SQL: %s" %
                           (status["Last_IO_Error"] or status["Slave_IO_Running"],
                            status["Last_SQL_Error"] or status["Slave_SQL_Running"]))


if __name__ == "__main__":
    password = Path(sys.argv[1]).read_text().strip()
    if not re.fullmatch(r"[a-f0-9]{64}", password):
        raise SystemExit("Replikaatiotunnuksen siirto epäonnistui.")
    try:
        connect_replica(password, Path(sys.argv[2]))
    except Exception as error:
        raise SystemExit(str(error).replace(password, "[piilotettu]"))
