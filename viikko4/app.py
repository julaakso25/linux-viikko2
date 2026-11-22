import html
from pathlib import Path
from string import Template

import pymysql

PAGE = Template(Path(__file__).with_name("sivu.html").read_text(encoding="utf-8"))
PUBLIC = Path("/var/lib/jlinux-week4/public")


def document(name, fallback):
    try:
        return html.escape((PUBLIC / name).read_text(encoding="utf-8"))
    except FileNotFoundError:
        return fallback


def local_count():
    with pymysql.connect(unix_socket="/run/mysqld/mysqld.sock", user="jlweek4",
                         database="jlweek2", connect_timeout=3, autocommit=True) as db:
        with db.cursor() as cursor:
            cursor.execute("SELECT visits FROM counter WHERE id=1")
            row = cursor.fetchone()
            if row is None:
                raise ValueError("Laskurin rivi puuttuu")
            return int(row[0])


def application(environ, start_response):
    headers = [("Content-Type", "text/html; charset=utf-8"), ("Cache-Control", "no-store")]
    if environ["PATH_INFO"] != "/viikko4/":
        start_response("404 Not Found", headers)
        return []
    if environ["REQUEST_METHOD"] not in ("GET", "HEAD"):
        start_response("405 Method Not Allowed", headers + [("Allow", "GET, HEAD")])
        return []
    try:
        count = local_count()
    except (pymysql.MySQLError, ValueError):
        start_response("503 Service Unavailable", headers)
        return [b"Laskuria ei juuri nyt voitu lukea."]
    body = PAGE.substitute(visits=count, disk_a=document("levyt-a.txt", "Mittaus odottaa."),
                           disk_b=document("levyt-b.txt", "Mittaus odottaa."),
                           results=document("TULOKSET.md", "Testitulokset julkaistaan mittausten valmistuttua."))
    start_response("200 OK", headers)
    return [] if environ["REQUEST_METHOD"] == "HEAD" else [body.encode("utf-8")]
