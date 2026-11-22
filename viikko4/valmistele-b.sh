#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == jlinux-b && $(id -u) == 0 ]] || { echo "Aja sudolla B:llä."; exit 1; }
cd "$(dirname "$0")"
exec 9>/run/lock/jlinux-week4-asennus.lock
flock -x 9
asetukset() {
    mariadb -NBe "SELECT @@global.server_id, @@global.read_only, IFNULL(NULLIF(@@global.replicate_do_table,''),'-')"
}
kerro_tila() {
    local tunnus luku suodatin
    IFS=$'\t' read -r tunnus luku suodatin <<< "$1"
    printf 'B: server_id=%s, read_only=%s, laskuririvejä (id=1)=%s, suodatin=%s\n' "$tunnus" "$luku" "$rivit" "$suodatin"
}
tila=$(asetukset)
kanavat=$(mariadb -NBe 'SHOW ALL SLAVES STATUS')
taulu=$(mariadb -NBe "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='jlweek2' AND TABLE_NAME='counter'")
rivit=0
if [[ $taulu == 1 ]]; then rivit=$(mariadb -NBe 'SELECT COUNT(*) FROM jlweek2.counter WHERE id=1'); fi
kerro_tila "$tila"
odotus=$'2\t1\tjlweek2.counter'
if [[ $tila != "$odotus" ]]; then
    if [[ -n $kanavat ]]; then
        echo "B:llä on jo määritetty replikaatioyhteys. Tarkista yllä näkyvät asetukset ennen muutoksia."
        exit 1
    fi
    asetus=/etc/mysql/mariadb.conf.d/90-jlinux-b.cnf
    vara=$(mktemp -d)
    trap 'rm -rf -- "$vara"' EXIT
    if [[ -f $asetus ]]; then cp -p -- "$asetus" "$vara/aiempi.cnf"; fi
    echo "Otetaan B:n replika-asetukset käyttöön ja käynnistetään B:n MariaDB uudelleen."
    install -m 0644 mariadb/palvelin-b.cnf "$asetus.uusi"
    mv -fT -- "$asetus.uusi" "$asetus"
    if ! systemctl restart mariadb; then
        if [[ -e $vara/aiempi.cnf ]]; then cp -p -- "$vara/aiempi.cnf" "$asetus"; else rm -f -- "$asetus"; fi
        systemctl restart mariadb || true
        echo "B:n asetustiedosto palautettiin. Katso B:llä: sudo journalctl -u mariadb -n 20 --no-pager"
        exit 1
    fi
    tila=$(asetukset)
    kerro_tila "$tila"
    [[ $tila == "$odotus" ]] || { echo "B:n MariaDB ei ladannut odotettua asetusta: server_id=2, read_only=1, suodatin=jlweek2.counter."; exit 1; }
fi
if [[ $rivit != 1 && -n $kanavat ]]; then
    echo "B:llä on jo replikaatioyhteys, mutta laskurin rivi id=1 puuttuu. Tarkista yhteyden tila."
    exit 1
fi
if [[ $rivit == 0 ]]; then echo "Ensimmäinen alustus hakee puuttuvan laskuririvin A:n lähtökopiosta."; fi
# Install the already tested cron file if only the manual run was completed.
if [[ ! -f /etc/cron.d/jlinux-web-backup ]]; then
    install -m 644 /home/ubuntu/linux-viikko2/viikko4/backup-web.cron /etc/cron.d/jlinux-web-backup
fi
test -x /usr/local/sbin/jlinux-web-backup
test -d /var/backups/jlinux-web
systemctl enable --now cron
id jldbpipe >/dev/null 2>&1 || useradd --system --user-group --create-home --home-dir /var/lib/jldbpipe --shell /usr/sbin/nologin jldbpipe
avaimet=/var/lib/jldbpipe/.ssh
install -d -m 700 -o jldbpipe -g jldbpipe "$avaimet"
if [[ ! -e $avaimet/repl ]]; then
    runuser -u jldbpipe -- ssh-keygen -q -t ed25519 -N '' -C 'JLinux-B-database' -f "$avaimet/repl"
fi
install -o ubuntu -g ubuntu -m 600 "$avaimet/repl.pub" /home/ubuntu/jlweek4-tunneli.pub
echo "B:n replikaatioavain valmis."
