param([Parameter(Mandatory=$true, Position=0)]
      [ValidateSet('hae','koodi','asenna','ennen','jalkeen','valmis')][string]$Vaihe)
$ErrorActionPreference = 'Stop'
$A = 'ubuntu@193.166.24.87'
$B = 'ubuntu@193.166.24.105'
$Aurl = 'http://193.166.24.87/viikko2/'
$Burl = 'http://193.166.24.105/viikko4/'
$KeyFile = Join-Path $env:USERPROFILE '.ssh\linuxkurssi-jlinux'
$Options = @('-o','IdentitiesOnly=yes','-o','ServerAliveInterval=30','-o','ConnectTimeout=15','-i',$KeyFile)
$RemotePath = '/home/ubuntu/jlinux-week4-lahde'
$PublicRepo = 'https://github.com/julaakso25/linux-viikko2.git'
if ($Vaihe -ne 'koodi' -and -not (Test-Path -LiteralPath $KeyFile -PathType Leaf)) { throw "SSH-avainta ei löytynyt: $KeyFile" }

function Remote([string]$Target, [string]$Command) {
    & ssh.exe @Options $Target $Command
    if ($LASTEXITCODE -ne 0) { throw "Komento epäonnistui palvelimella $Target (exit $LASTEXITCODE)." }
}
function Copy-Remote([string]$From, [string]$To) {
    & scp.exe -3 -p @Options $From $To
    if ($LASTEXITCODE -ne 0) { throw "SCP-siirto epäonnistui (exit $LASTEXITCODE)." }
}
function Save-Sources([string]$Message, [string[]]$Files) {
    & git -C $PSScriptRoot add -- @Files
    if ($LASTEXITCODE -ne 0) { throw 'Lähdetiedostojen lisääminen Gitiin epäonnistui.' }
    & git -C $PSScriptRoot diff --cached --quiet -- @Files
    $difference = $LASTEXITCODE
    if ($difference -eq 1) {
        & git -C $PSScriptRoot commit --only -m $Message -- @Files
        if ($LASTEXITCODE -ne 0) { throw 'Commit epäonnistui.' }
    } elseif ($difference -ne 0) { throw 'Git-muutosten vertailu epäonnistui.' }
}
function Get-Counter([string]$Uri) {
    $response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri $Uri
    $value = [regex]::Match([string]$response.Content, '<strong\s+id="visits"\s*>\s*(\d+)\s*</strong>')
    if ($response.StatusCode -ne 200 -or -not $value.Success) { throw "Laskuria ei löytynyt sivulta $Uri" }
    if ($Uri -eq $Burl -and -not $response.Content.Contains('https://github.com/julaakso25/linux-viikko2/tree/main/viikko4')) {
        throw "B:n sivulta puuttuu projektin GitHub-linkki."
    }
    return [long]::Parse($value.Groups[1].Value)
}
function Public-Test([string]$Phase) {
    $ready = $false
    for ($i = 0; $i -lt 25; $i++) {
        try { $null = Get-Counter $Burl; $ready = $true; break }
        catch { if ($i -eq 24) { throw }; Start-Sleep -Seconds 4 }
    }
    if (-not $ready) { throw 'B:n HTTP-sivu ei avautunut.' }
    $week3 = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri 'http://193.166.24.87/viikko3/'
    if ($week3.StatusCode -ne 200 -or -not ([string]$week3.Content -match '(?i)<html')) { throw 'A:n viikon 3 raportti ei avautunut.' }
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $b1 = Get-Counter $Burl
        $b2 = Get-Counter $Burl
        if ($b1 -ne $b2) { Start-Sleep -Seconds 2; continue }
        $acount = Get-Counter $Aurl
        if ($acount -le $b2) { throw 'A:n lataus ei kasvattanut lukemaa odotetusti.' }
        for ($i = 0; $i -lt 30; $i++) {
            $b3 = Get-Counter $Burl
            if ($b3 -ge $acount) {
                Remote $B "sudo /usr/bin/python3 /opt/jlinux-week4/todenna.py $Phase $b1 $b2 $acount $b3"
                return
            }
            Start-Sleep -Seconds 2
        }
        throw 'A:n uusi lukema ei saapunut B:lle minuutissa. Tarkista MariaDB:n replikaatiotila B:llä.'
    }
    throw 'B:n kahden lukukerran väliin tuli muutoksia. Aja testi uudelleen rauhallisella hetkellä.'
}
switch ($Vaihe) {
    'hae' {
        $folder = '/home/ubuntu/jlinux-replika/lahdekoodi'
        Remote $B "install -d -m 0700 $folder && (test -f /etc/cron.d/jlinux-web-backup || sudo install -m 0644 /home/ubuntu/linux-viikko2/viikko4/backup-web.cron /etc/cron.d/jlinux-web-backup) && sudo install -o ubuntu -g ubuntu -m 0600 /usr/local/sbin/jlinux-web-backup $folder/backup-web.sh && sudo install -o ubuntu -g ubuntu -m 0600 /etc/cron.d/jlinux-web-backup $folder/backup-web.cron && sudo systemctl enable --now cron"
        Copy-Remote "${B}:$folder/backup-web.sh" (Join-Path $PSScriptRoot 'backup-web.sh')
        Copy-Remote "${B}:$folder/backup-web.cron" (Join-Path $PSScriptRoot 'backup-web.cron')
        Write-Host 'B:n käytössä oleva varmistusskripti ja cron-asetus haettu.'
    }
    'koodi' {
        $infra = @('.gitattributes','.gitignore','backup-web.sh','backup-web.cron','mariadb/palvelin-a.cnf','mariadb/palvelin-b.cnf','systemd/jlinux-db-link.socket','systemd/jlinux-db-link@.service','valmistele-b.sh','asenna-a.sh','yhdista.py')
        $site = @('app.py','sivu.html','asenna-b.sh','mittaa-levyt.sh','nginx-viikko4.conf','systemd/jlinux-week4.service','todenna.py','jlinux.ps1','README.md')
        Save-Sources 'Lisää tuntivarmistus ja rajattu MariaDB-replikaatio' $infra
        Save-Sources 'Julkaise lukukopion laskuri ja lisää palautus- ja käynnistystestit' $site
    }
    'asenna' {
        $rev = (& git -C "$PSScriptRoot" rev-parse HEAD | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $rev -notmatch '^[a-f0-9]{40}$') { throw 'Git-revisio puuttuu.' }
        $sync = "if test -d $RemotePath/.git; then git -C $RemotePath fetch -q origin main; else git clone -q $PublicRepo $RemotePath; fi && git -C $RemotePath checkout -q --detach $rev"
        Remote $B "$sync && sudo bash $RemotePath/viikko4/valmistele-b.sh"
        Copy-Remote "${B}:/home/ubuntu/jlweek4-tunneli.pub" "${A}:/home/ubuntu/jlweek4-tunneli.pub"
        Remote $A "$sync && sudo bash $RemotePath/viikko4/asenna-a.sh"
        Copy-Remote "${A}:/home/ubuntu/jlinux-replika/jlweek4-yhteys.tgz" "${B}:/home/ubuntu/jlweek4-yhteys.tgz"
        Remote $B "sudo bash $RemotePath/viikko4/asenna-b.sh"
        Remote $A 'rm -f /home/ubuntu/jlinux-replika/jlweek4-yhteys.tgz'
        Write-Host "ASENNUS OK. $Burl"
    }
    'ennen' { Public-Test 'ennen' }
    'jalkeen' { Public-Test 'jalkeen' }
    'valmis' {
        Remote $B 'sudo /usr/bin/python3 /opt/jlinux-week4/todenna.py odota'
        $line = (Remote $A 'sha256sum /var/www/html/index.html' | Out-String).Trim()
        if ($line -notmatch '(?m)^([a-f0-9]{64})\s+/var/www/html/index\.html$') { throw 'A:n tiedoston tiiviste puuttuu.' }
        $hash = $Matches[1]
        Remote $B "sudo /usr/bin/python3 /opt/jlinux-week4/todenna.py valmis $hash"
        Copy-Remote "${B}:/var/lib/jlinux-week4/public/TULOKSET.md" (Join-Path $PSScriptRoot 'TULOKSET.md')
        $page = Invoke-WebRequest -UseBasicParsing -TimeoutSec 12 -Uri $Burl
        if (-not ([string]$page.Content).Contains($hash)) { throw 'Lopullinen tulos ei vielä näy B:n julkisella sivulla.' }
        Write-Host 'PALVELINTESTIT VALMIIT. TULOKSET.md on nyt myös paikallisessa repossa.'
    }
}
