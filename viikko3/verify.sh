#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
export TZ=UTC
cd -- "$(dirname -- "$0")"
state_dir=${REPORT_STATE_DIR:-/var/lib/jlinux-report}
week2=http://127.0.0.1/viikko2/
week3=http://127.0.0.1/viikko3/
timer=jlinux-report.timer

fail() { printf '%s\n' "$*" >&2; exit 1; }
case ${1:-} in
    ennen|jalkeen) ;;
    *) fail 'Käyttö: bash verify.sh ennen | jalkeen' ;;
esac
[[ -d $state_dir && -w $state_dir ]] || fail 'Aja ensin bash install.sh JLinuxissa.'
umask 077
exec 9>"$state_dir/check.lock"
flock -n 9 || fail 'Toinen testi on jo käynnissä.'
work=$(mktemp -d -- "$state_dir/check.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
systemctl is-enabled --quiet "$timer" || fail 'Ajastimen käynnistys on pois käytöstä.'
systemctl is-active --quiet "$timer" || fail 'Ajastin ei ole käynnissä.'
boot_id=$(cat /proc/sys/kernel/random/boot_id)

report_time() {
    local page stamp
    page=$(curl -fsS --max-time 5 "$week3") || return 1
    stamp=$(sed -n 's/.*<time id="generated"[^>]*>\([^<]*\)<\/time>.*/\1/p' <<< "$page")
    [[ $stamp =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ UTC$ ]] || return 1
    printf '%s\n' "$stamp"
}

observe_updates() {
    local previous triggered current last_trigger start
    previous=$(report_time) || fail 'Viikon 3 aikaleimaa ei löytynyt Nginxin kautta.'
    last_trigger=$(systemctl show "$timer" --property=LastTriggerUSec --value)
    start=$SECONDS
    updates=()
    echo 'Odotetaan kahta ajastimen tekemää päivitystä (noin 1–2 min)…' >&2
    while (( SECONDS - start < 160 )); do
        sleep 3
        current=$(report_time) || continue
        triggered=$(systemctl show "$timer" --property=LastTriggerUSec --value)
        if [[ $current != "$previous" && -n $triggered && $triggered != n/a && $triggered != "$last_trigger" ]]; then
            updates+=("$current")
            echo "Ajastettu raportti: $current" >&2
            previous=$current
            last_trigger=$triggered
            if (( ${#updates[@]} == 2 )); then return 0; fi
        fi
    done
    fail 'Kahta päivitystä ei havaittu. Tarkista: systemctl status jlinux-report.timer jlinux-report.service --no-pager'
}

if [[ $1 == ennen ]]; then
    bash -n report.sh
    bash report.sh
    manual=$(report_time) || fail 'Käsiajon jälkeen raportti ei auennut Nginxin kautta.'
    ok=$(bash report.sh --test-disk 50%)
    at_limit=$(bash report.sh --test-disk 80%)
    over=$(bash report.sh --test-disk 90%)
    [[ $ok == OK && $at_limit == WARNING && $over == WARNING ]] || fail 'Levytilan testi epäonnistui.'
    observe_updates
    cat > "$work/before.html" <<EOF
<h3>Syntax and manual run</h3>
<p><code>bash -n report.sh</code> passed. A manual run published a report that Nginx served with generation time $manual.</p>
<h3>Disk threshold</h3>
<table><thead><tr><th>Test input</th><th>Expected</th><th>Actual</th></tr></thead><tbody>
<tr><td>50%</td><td>OK</td><td>$ok</td></tr>
<tr><td>80%</td><td>WARNING</td><td>$at_limit</td></tr>
<tr><td>90%</td><td>WARNING</td><td>$over</td></tr></tbody></table>
<h3>Automatic updates before reboot</h3><p>${updates[0]} and ${updates[1]}.</p>
EOF
    printf '%s\n' "$boot_id" > "$work/before.boot"
    rm -f -- "$state_dir/after.html" "$state_dir/TESTIT.md"
    mv -f -- "$work/before.boot" "$state_dir/before.boot"
    mv -f -- "$work/before.html" "$state_dir/before.html"
    bash report.sh
    echo 'Ennen-testi valmis. Nyt voit käynnistää JLinuxin uudelleen.'
else
    [[ -r $state_dir/before.boot && -r $state_dir/before.html ]] || fail 'Aja ensin bash verify.sh ennen.'
    [[ $(cat "$state_dir/before.boot") != "$boot_id" ]] || fail 'JLinuxin käynnistystunnus on ennallaan. Tee ensin uudelleenkäynnistys.'
    week2_page=$(curl -fsS --max-time 8 "$week2") || fail 'Viikon 2 sivu ei aukea Nginxin kautta.'
    [[ $week2_page == *'id="visits"'* ]] || fail 'Viikon 2 kävijälaskuria ei löytynyt sivulta.'
    observe_updates
    booted="$(uptime -s) UTC"
    cat > "$work/after.html" <<EOF
<h3>After reboot</h3>
<p>JLinux booted at $booted. The boot ID changed. Nginx served both the Week 2 visitor counter and the Week 3 report.</p>
<p>The next two observed automatic reports were generated at ${updates[0]} and ${updates[1]}.</p>
EOF
    cat > "$work/TESTIT.md" <<EOF
# JLinuxin uudelleenkäynnistystesti

Kone käynnistyi $booted. Käynnistystunnus vaihtui ja Nginx palveli viikon 2 laskurin ja viikon 3 raportin.

Uuden käynnistyksen jälkeen ajastin julkaisi raportit ${updates[0]} ja ${updates[1]}.
EOF
    mv -f -- "$work/after.html" "$state_dir/after.html"
    mv -f -- "$work/TESTIT.md" "$state_dir/TESTIT.md"
    bash report.sh
    echo 'Uudelleenkäynnistystesti valmis. Päivitä /viikko3/ selaimessa.'
fi
