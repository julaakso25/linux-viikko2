#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
[[ $(hostname -s) == jlinux-b && $(id -u) == 0 ]] || { echo "Aja sudolla B:llä."; exit 1; }
tila=$(mariadb -NBe 'SELECT @@server_id=2 AND @@read_only=1')
[[ $tila == 1 ]]
tyo=$(mktemp -d)
trap 'rm -rf -- "$tyo"' EXIT
for nimi in known_hosts levyt-a.txt repl-password; do
    tar -xzOf /home/ubuntu/jlweek4-yhteys.tgz "$nimi" > "$tyo/$nimi"
    test -s "$tyo/$nimi"
done
grep -Eq '^192\.168\.1\.226 ssh-ed25519 [A-Za-z0-9+/=]+$' "$tyo/known_hosts"
install -o jldbpipe -g jldbpipe -m 600 "$tyo/known_hosts" /var/lib/jldbpipe/.ssh/known_hosts
install -m 644 systemd/jlinux-db-link{.socket,@.service} systemd/jlinux-week4.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now mariadb jlinux-db-link.socket
/usr/bin/python3 yhdista.py "$tyo/repl-password"
id jlweek4 >/dev/null 2>&1 || useradd --system --user-group --no-create-home --shell /usr/sbin/nologin jlweek4
mariadb <<'SQL'
CREATE USER IF NOT EXISTS 'jlweek4'@'localhost' IDENTIFIED VIA unix_socket;
GRANT SELECT ON jlweek2.counter TO 'jlweek4'@'localhost';
SQL
root=/var/lib/jlinux-week4
install -d -m 755 "$root" "$root/public" /opt/jlinux-week4
install -d -m 700 "$root/private"
install -m 644 "$tyo/levyt-a.txt" "$root/public/levyt-a.txt"
bash mittaa-levyt.sh /var/www/html /var/lib/mysql /var/backups/jlinux-web > "$tyo/levyt-b.txt"
install -m 644 "$tyo/levyt-b.txt" "$root/public/levyt-b.txt"
install -m 644 app.py sivu.html todenna.py /opt/jlinux-week4/
systemctl enable --now jlinux-week4.service
systemctl restart jlinux-week4.service
curl -fsS --retry 10 --retry-all-errors --retry-delay 1 --max-time 4 http://127.0.0.1:8764/viikko4/ -o "$tyo/sivu"
site=/etc/nginx/sites-available/default
include='include /etc/nginx/snippets/jlinux-viikko4.conf;'
anchor='^[[:space:]]*include[[:space:]]+/etc/nginx/snippets/jlinux-week2\.conf;[[:space:]]*$'
[[ $(readlink -f /etc/nginx/sites-enabled/default) == "$site" ]]
cp -p "$site" "$tyo/site-original"
snippet=/etc/nginx/snippets/jlinux-viikko4.conf
if [[ -f $snippet ]]; then cp -p "$snippet" "$tyo/snippet-original"; fi
install -m 644 nginx-viikko4.conf "$snippet"
if ! grep -Fq "$include" "$site"; then
    [[ $(grep -Ec "$anchor" "$site") == 1 ]] || { echo "B:n Nginxistä puuttuu viikon 2 include-rivi."; exit 1; }
    sed -i -E "\@$anchor@a\        $include" "$site"
fi
if ! nginx -t || ! systemctl reload nginx || ! curl -fsS --retry 6 --retry-all-errors --retry-delay 1 --max-time 4 http://127.0.0.1/viikko4/ -o "$tyo/nginx-sivu" || ! grep -q 'id="visits"' "$tyo/nginx-sivu"; then
    cp -p "$tyo/site-original" "$site"
    if [[ -f $tyo/snippet-original ]]; then cp -p "$tyo/snippet-original" "$snippet"; else rm -f "$snippet"; fi
    nginx -t && systemctl reload nginx
    echo "B:n sivutarkistus epäonnistui. Aiempi Nginx-asetus palautettu."
    exit 1
fi
systemctl enable nginx cron
rm -f /home/ubuntu/jlweek4-yhteys.tgz
echo "B:n sivu valmis osoitteessa http://193.166.24.105/viikko4/"
