#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
url=$(git remote get-url origin)
url=${url%.git}
if [[ ! $url =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Kloonaa oma repo julkisella GitHubin HTTPS-osoitteella."; exit 1
fi
site=/etc/nginx/sites-available/default
include='include /etc/nginx/snippets/jlinux-week2.conf;'
anchor='^[[:space:]]*location[[:space:]]+/[[:space:]]*\{[[:space:]]*$'
if [[ $(readlink -f /etc/nginx/sites-enabled/default) != "$site" ]] || [[ $(grep -Ec "$anchor" "$site") != 1 ]]; then
  echo "Nginxin nykyinen asetus eroaa viikon 1 oletuksesta. Keskeytetty. Näytä tulos: sudo nginx -T"; exit 1
fi
before=$(curl -fsS http://127.0.0.1/ | sha256sum)
sudo apt-get update
sudo apt-get install -y mariadb-server python3-gunicorn python3-pymysql curl
if ! id jlweek2 >/dev/null 2>&1; then
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin jlweek2
fi
sudo systemctl enable --now mariadb
sudo mariadb < deploy/schema.sql
sudo install -d -m 755 /opt/jlinux-week2 /var/lib/jlinux-week2
sudo install -m 644 app.py page.html /opt/jlinux-week2/
printf 'REPO_URL=%s\n' "$url" | sudo tee /etc/jlinux-week2.env >/dev/null
sudo install -m 644 deploy/jlinux-week2.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now jlinux-week2
sudo systemctl restart jlinux-week2
curl -fsS --retry 8 --retry-connrefused --retry-delay 1 http://127.0.0.1:8762/viikko2/ >/dev/null
sudo install -m 644 deploy/nginx-location.conf /etc/nginx/snippets/jlinux-week2.conf
backup=$(sudo mktemp /etc/nginx/week2-backup.XXXXXXXX)
sudo cp -p "$site" "$backup"
if ! grep -Fq "$include" "$site"; then
  sudo sed -i -E "\@$anchor@i\        $include" "$site"
fi
restore_site() {
  sudo cp -p "$backup" "$site"
  sudo nginx -t && sudo systemctl reload nginx
}
if ! sudo nginx -t || ! sudo systemctl reload nginx; then restore_site; exit 1; fi
if ! curl -fsS --retry 8 --retry-all-errors --retry-delay 1 --max-time 3 http://127.0.0.1/viikko2/ | grep 'id="visits"' >/dev/null ||
   [[ $(curl -fsS http://127.0.0.1/ | sha256sum) != "$before" ]]; then
  restore_site; echo "Sivutarkistus epäonnistui. Aiempi palvelinasetus palautettu."; exit 1
fi
sudo systemctl enable nginx
echo "Molemmat sivut toimivat paikallisesti. Viikon 1 sisältö on tarkistettu."
