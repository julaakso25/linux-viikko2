#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == jlinux-b && $(id -u) == 0 ]] || { echo "Aja sudolla B:llä."; exit 1; }
tila=$(mariadb -NBe 'SELECT @@server_id=2 AND @@global.read_only=1 AND EXISTS (SELECT 1 FROM jlweek2.counter WHERE id=1)')
[[ $tila == 1 ]] || { echo "Tarkista B:n laskuri, server_id ja read_only."; exit 1; }
if [[ ! -s /home/ubuntu/jlweek2-lahto.sql && -z $(mariadb -NBe 'SHOW ALL SLAVES STATUS') ]]; then
    echo "B:n ensimmäiseen alustukseen tarvitaan A:lta siirretty jlweek2-lahto.sql."
    exit 1
fi
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
