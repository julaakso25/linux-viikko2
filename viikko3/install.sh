#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
bash -n report.sh
bash -n verify.sh

sudo install -d -m 0755 /opt/jlinux-report
sudo install -m 0644 report.sh /opt/jlinux-report/report.sh
sudo install -d -o ubuntu -g ubuntu -m 0755 /var/www/html/viikko3
sudo install -d -o ubuntu -g ubuntu -m 0700 /var/lib/jlinux-report
sudo install -m 0644 systemd/jlinux-report.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start jlinux-report.service
sudo systemctl enable --now jlinux-report.timer

curl -fsS --max-time 8 http://127.0.0.1/viikko3/ | grep 'id="generated"' >/dev/null
echo 'Week 3 is available locally. Open /viikko3/ in your browser.'
