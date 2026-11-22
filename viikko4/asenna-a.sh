#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
[[ $(hostname -s) == jlinux && $(id -u) == 0 ]] || { echo "Aja sudolla A:lla."; exit 1; }
tila=$(mariadb -NBe "SELECT @@global.server_id, @@global.log_bin, @@global.binlog_format")
if [[ $tila != $'1\t1\tROW' ]]; then
    printf 'A: server_id, log_bin ja binlog_format ovat %s. Odotettu 1, 1, ROW. Ota mariadb/palvelin-a.cnf käyttöön A:lla.\n' "$tila"
    exit 1
fi
[[ -x /usr/bin/nc.openbsd ]] || { apt-get update && apt-get install -y netcat-openbsd; }
# The forced command can reach only the database on A's own loopback interface.
id jldbpipe >/dev/null 2>&1 || useradd --system --user-group --create-home --home-dir /var/lib/jldbpipe --shell /bin/sh jldbpipe
pub=/home/ubuntu/jlweek4-tunneli.pub
[[ $(wc -l < "$pub") == 1 ]]
ssh-keygen -lf "$pub" >/dev/null
read -r tyyppi avain _ < "$pub"
[[ $tyyppi == ssh-ed25519 && $avain =~ ^[A-Za-z0-9+/=]+$ ]]
kansio=/var/lib/jldbpipe/.ssh
install -d -o jldbpipe -g jldbpipe -m 700 "$kansio"
rivi="from=\"192.168.1.75\",restrict,command=\"/usr/bin/nc.openbsd -N 127.0.0.1 3306\" $tyyppi $avain"
# This Linux account is reserved entirely for the database stream.
tmpavain=$(mktemp "$kansio/.authorized.XXXXXXXX")
printf '%s\n' "$rivi" > "$tmpavain"
chown jldbpipe:jldbpipe "$tmpavain"
chmod 600 "$tmpavain"
mv -fT "$tmpavain" "$kansio/authorized_keys"
install -d -m 700 /etc/jlinux-week4
salasana=/etc/jlinux-week4/repl-password
umask 077
if [[ ! -s $salasana ]]; then
    openssl rand -hex 32 > "$salasana.uusi"
    mv -fT "$salasana.uusi" "$salasana"
fi
tunniste=$(cat "$salasana")
[[ $tunniste =~ ^[a-f0-9]{64}$ ]]
tyo=$(mktemp -d)
trap 'rm -rf -- "$tyo"' EXIT
if ! mariadb 2>"$tyo/sql-error" <<SQL
SET SESSION sql_log_bin=0;
CREATE USER IF NOT EXISTS 'jlrepl'@'127.0.0.1' IDENTIFIED BY '$tunniste';
ALTER USER 'jlrepl'@'127.0.0.1' IDENTIFIED BY '$tunniste';
GRANT REPLICATION SLAVE ON *.* TO 'jlrepl'@'127.0.0.1';
SQL
then
    sed -E 's/[a-f0-9]{64}/[piilotettu]/g' "$tyo/sql-error" >&2
    exit 1
fi
/usr/bin/nc.openbsd -z -w 2 127.0.0.1 3306 || { echo "Tarkista MariaDB:n kuuntelu A:n osoitteessa 127.0.0.1:3306."; exit 1; }
install -m 600 "$salasana" "$tyo/repl-password"
printf '192.168.1.226 %s\n' "$(cut -d' ' -f1-2 /etc/ssh/ssh_host_ed25519_key.pub)" > "$tyo/known_hosts"
bash mittaa-levyt.sh /var/www/html /var/lib/mysql > "$tyo/levyt-a.txt"
mariadb-dump --single-transaction --master-data=2 --no-create-info --skip-triggers --skip-extended-insert --where='id=1' jlweek2 counter > "$tyo/laskuri.sql"
tar -czf "$tyo/yhteys.tgz" -C "$tyo" repl-password known_hosts levyt-a.txt laskuri.sql
install -d -o ubuntu -g ubuntu -m 700 /home/ubuntu/jlinux-replika
install -o ubuntu -g ubuntu -m 600 "$tyo/yhteys.tgz" /home/ubuntu/jlinux-replika/jlweek4-yhteys.tgz
echo "A:n replikaatiotunnus ja B:n rajattu SSH-yhteys valmiina."
