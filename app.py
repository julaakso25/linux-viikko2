import html
import os
from pathlib import Path
from string import Template

import pymysql

PAGE = Template(Path(__file__).with_name("page.html").read_text(encoding="utf-8"))
REPORT = Path("/var/lib/jlinux-week2/result.txt")


def record_visit():
    db = pymysql.connect(unix_socket="/run/mysqld/mysqld.sock",
                         user="jlweek2", database="jlweek2", connect_timeout=3)
    try:
        with db.cursor() as cursor:
            cursor.execute("UPDATE counter SET visits = visits + 1 WHERE id = 1")
            cursor.execute("SELECT visits FROM counter WHERE id = 1")
            count, = cursor.fetchone()
        db.commit()
        return count
    finally:
        db.close()


def application(environ, start_response):
    method = environ["REQUEST_METHOD"]
    if environ["PATH_INFO"] != "/viikko2/":
        start_response("404 Not Found", [])
        return []
    if method not in ("GET", "HEAD"):
        start_response("405 Method Not Allowed", [("Allow", "GET, HEAD")])
        return []
    headers = [("Content-Type", "text/html; charset=utf-8"), ("Cache-Control", "no-store")]
    if method == "HEAD":
        start_response("200 OK", headers)
        return []
    visits = record_visit()
    result = REPORT.read_text(encoding="utf-8").strip() if REPORT.exists() else "Testi odottaa palvelimen uudelleenkäynnistystä."
    body = PAGE.substitute(visits=visits, result=html.escape(result),
                           repo=html.escape(os.environ["REPO_URL"], quote=True))
    start_response("200 OK", headers)
    return [body.encode("utf-8")]
