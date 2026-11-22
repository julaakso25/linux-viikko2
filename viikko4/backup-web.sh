#!/usr/bin/env bash
set -eu
umask 077
cd /var/backups/jlinux-web
exec >>backup.log 2>&1

stamp=$(date -u +%Y%m%dT%H%M%SZ)
run=${1:-manual}
trap 'echo "$stamp $run FAIL"' ERR
tmp=$(mktemp ".html-$stamp-XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
archive="${tmp#.}.tar.gz"

ssh -nT -i /var/lib/jlbackup/.ssh/webpull \
    -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
    -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=2 \
    jlwebread@192.168.1.226 >"$tmp"

tar -tzf "$tmp" >/dev/null
mv -- "$tmp" "$archive"
echo "$stamp $run OK $archive"
