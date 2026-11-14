#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

web_root=${REPORT_DIR:-/var/www/html/viikko3}
state_dir=${REPORT_STATE_DIR:-/var/lib/jlinux-report}

disk_status() {
    local used=${1%\%}
    if (( used >= 80 )); then
        printf 'WARNING\n'
    else
        printf 'OK\n'
    fi
}

if [[ ${1:-} == --test-disk ]]; then
    if [[ $# != 2 || ! $2 =~ ^(100|[1-9]?[0-9])%?$ ]]; then
        echo 'Usage: bash report.sh --test-disk 0..100' >&2
        exit 2
    fi
    disk_status "$2"
    exit
fi
if (( $# != 0 )); then
    echo 'Usage: bash report.sh [--test-disk PERCENT]' >&2
    exit 2
fi

GENERATED_AT=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
UPTIME_TEXT=$(uptime -p)
DISK_USAGE=$(df -P / | awk 'NR == 2 {print $5}')
[[ $DISK_USAGE =~ ^[0-9]+%$ ]] || { echo 'Could not read root disk usage.' >&2; exit 1; }
DISK_STATUS=$(disk_status "$DISK_USAGE")
memory=$(free -m | awk '$1 == "Mem:" {print $2, $7}')
read -r MEM_TOTAL MEM_AVAILABLE <<< "$memory"
[[ $MEM_TOTAL =~ ^[0-9]+$ && $MEM_AVAILABLE =~ ^[0-9]+$ ]] || { echo 'Could not read memory.' >&2; exit 1; }
GITHUB_URL='https://github.com/julaakso25/linux-viikko2/tree/main/viikko3'

# A same-directory rename publishes a complete file even if the next run is interrupted.
TEMP_FILE=$(mktemp -- "$web_root/.report.XXXXXXXX")
trap 'rm -f -- "$TEMP_FILE"' EXIT
cat > "$TEMP_FILE" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>JLinux · Server status</title>
  <style>
    :root { color-scheme: light; --paper:#f8f5ed; --ink:#1c302c; --green:#17473c; --line:#cdcec2; }
    * { box-sizing:border-box; }
    body { margin:0; background:var(--paper); color:var(--ink); font:1rem/1.6 "Inter",system-ui,sans-serif; }
    main,nav,footer { max-width:54rem; margin:auto; padding:0 1.25rem; }
    nav,footer { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:.5rem 1.4rem; }
    nav { padding-block:1rem; border-bottom:1px solid var(--line); }
    a { color:var(--green); text-underline-offset:.2em; } a:focus-visible { outline:3px solid #a64712; }
    header { padding:clamp(1.8rem,5vw,3.5rem) 0 1.3rem; }
    h1,h2,h3 { line-height:1.2; font-family:"Spectral",Georgia,serif; }
    h1 { font-size:clamp(2.5rem,7vw,4.2rem); margin:0 0 .65rem; }
    h2 { font-size:1.6rem; margin:0 0 .65rem; } h3 { font-size:1.18rem; margin:1.4rem 0 .35rem; }
    p { margin:.45rem 0; } section { padding:1.4rem 0; border-top:1px solid var(--line); }
    .stamp { padding:1.15rem 1.4rem; background:var(--green); color:#fff8e9; border-radius:.5rem; }
    .stamp time { display:block; font-size:clamp(1.1rem,4vw,1.65rem); font-weight:bold; }
    table { width:100%; border-collapse:collapse; margin:.6rem 0 1rem; font-variant-numeric:tabular-nums; }
    th,td { text-align:left; padding:.55rem .55rem; border-bottom:1px solid var(--line); }
    thead th { color:var(--green); } tbody th { font-weight:500; }
    .flag { font-weight:bold; } .flag.WARNING { color:#8c330a; } .flag.OK { color:var(--green); }
    dt { margin-top:.85rem; } dd { margin:.1rem 0; }
    code { font: .94em/1.5 "IBM Plex Mono",monospace; overflow-wrap:anywhere; }
    footer { border-top:1px solid var(--line); padding-block:1.25rem 2rem; }
  </style>
</head>
<body>
<nav aria-label="Project"><strong>JLinux</strong><a href="/viikko2/">Week 2 visitor counter</a></nav>
<main>
  <header><h1>Server status</h1>
    <p>Week 3 on JLinux. This report measures the Ubuntu virtual machine that hosts my visitor counter on CSC cPouta.</p>
  </header>
  <div class="stamp">Report generated<time id="generated" datetime="${GENERATED_AT:0:10}T${GENERATED_AT:11:8}Z">$GENERATED_AT</time></div>
  <section aria-labelledby="current"><h2 id="current">Current server readings</h2>
    <table><thead><tr><th scope="col">Measurement</th><th scope="col">Value</th></tr></thead><tbody>
      <tr><th scope="row">Server uptime</th><td>$UPTIME_TEXT</td></tr>
      <tr><th scope="row">Root filesystem used (/)</th><td>$DISK_USAGE</td></tr>
      <tr><th scope="row">Disk space status</th><td class="flag $DISK_STATUS">$DISK_STATUS</td></tr>
      <tr><th scope="row">Total RAM</th><td>$MEM_TOTAL MiB</td></tr>
      <tr><th scope="row">Available RAM</th><td>$MEM_AVAILABLE MiB</td></tr>
    </tbody></table>
    <p>Reload after one or two minutes to see the next report.</p>
  </section>
  <section><h2>How the measurements work</h2>
    <dl>
      <dt><code>date -u '+%Y-%m-%d %H:%M:%S UTC'</code></dt><dd>Records when Bash wrote the report, in UTC.</dd>
      <dt><code>uptime -p</code></dt><dd>Shows how long Ubuntu has been running since boot.</dd>
      <dt><code>df -P / | awk 'NR == 2 {print &#36;5}'</code></dt><dd>The pipe sends disk usage to awk. On the second line, the fifth field contains the percentage used on the root filesystem.</dd>
      <dt><code>free -m</code></dt><dd>The Mem row gives total RAM in column 2 and available RAM in column 7, both in MiB. Available RAM estimates what new applications can use.</dd>
    </dl>
    <p>Bash stores each measurement in a variable using command substitution. The <code>disk_status</code> function strips the percent sign and uses an <code>if</code> to return <strong>WARNING</strong> at 80% and above, or <strong>OK</strong> below 80%.</p>
    <p>The script writes a temporary HTML file in the site directory and renames it to <code>index.html</code> when complete. Nginx serves the latest complete report.</p>
  </section>
  <section><h2>Schedule</h2>
    <p>The systemd timer starts the report service at the start of each minute. Enabling <code>jlinux-report.timer</code> makes it start on boot. The report shows its generation time even when nobody has the page open.</p>
  </section>
  <section><h2>Test results on JLinux</h2>
EOF
for part in before after; do
    if [[ -f $state_dir/$part.html ]]; then
        cat -- "$state_dir/$part.html" >> "$TEMP_FILE"
    elif [[ $part == before ]]; then
        echo '<p>Awaiting the syntax, manual run, disk threshold and timer tests.</p>' >> "$TEMP_FILE"
    else
        echo '<p>Awaiting the virtual machine reboot test.</p>' >> "$TEMP_FILE"
    fi
done
cat >> "$TEMP_FILE" <<EOF
  </section>
  <section><h2>One lesson from the disk test</h2>
    <p>The 80% case distinguishes <code>&gt;=</code> from <code>&gt;</code>. Passing a test value directly to the same function lets me check the exact boundary while the public report continues to use the measured disk usage.</p>
  </section>
</main>
<footer><a href="$GITHUB_URL">Bash source and timer on GitHub</a></footer>
</body>
</html>
EOF
chmod 0644 -- "$TEMP_FILE"
mv -fT -- "$TEMP_FILE" "$web_root/index.html"
