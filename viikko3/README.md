# JLinux · Viikko 3

Bash mittaa JLinuxin käynnissäoloajan, juuriosion käyttöasteen sekä kokonais- ja käytettävissä olevan muistin. Nginx näyttää uusimman raportin osoitteessa [http://193.166.24.87/viikko3/](http://193.166.24.87/viikko3/). Raportin aika on UTC-aikaa. Viikon 2 sovelluksella on oma [osoitteensa](http://193.166.24.87/viikko2/).

### Valmistelu Windowsissa

Jos `viikko3` on jo purettu paikalliseen repoon, aloita kohdasta 1. Muutoin lataa `linux-viikko3.zip` Lataukset-kansioon ja aja Windows PowerShellissä alla olevat komennot. Jos tallensit paketin muualle, vaihda sen sijainti `Expand-Archive`-komentoon.

```powershell
cd 'D:\Codes\OAMK\linux-viikko2'
git pull --ff-only
Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\linux-viikko3.zip" -DestinationPath .
```

## 1. Harjoittele komennot JLinuxissa

Avaa Windows Terminalissa uusi PowerShell-välilehti (+) ja kirjaudu samalla avaimella kuin viikolla 2. Alkuperäinen välilehti jää paikalliseen Git-repoon.

```powershell
ssh -o IdentitiesOnly=yes -i "$env:USERPROFILE\.ssh\linuxkurssi-jlinux" ubuntu@193.166.24.87
```

Kun rivin alussa näkyy `ubuntu@jlinux`, aja komennot yksi kerrallaan.

```bash
date -u '+%Y-%m-%d %H:%M:%S UTC'
uptime -p
df -P /
df -P / | awk 'NR == 2 {print $5}'
free -m
```

Vertaa kahden `df`-komennon tuloksia. Jälkimmäisessä putki syöttää saman taulukon awkille, joka tulostaa käyttöprosentin. Katso muistitaulukon Mem-riviltä sarakkeet total ja available.

## 2. Lisää raportti GitHubiin Windowsista

Palaa alkuperäiseen Windows PowerShell -välilehteen. Näiden komentojen kohdalla kehotteen alussa on `PS`.

```powershell
cd 'D:\Codes\OAMK\linux-viikko2'
git status --short
```

Paketti purkaa uuden `viikko3`-kansion repon juureen. Sivun GitHub-linkki osoittaa tämän repon `main`-haaran `viikko3`-kansioon. Tee ensimmäinen commit raportista.

```powershell
git add -- viikko3/.gitattributes viikko3/report.sh
git commit -m "Lisää JLinuxin tilaraportti ja levytilan varoitusraja"
git push
```

Palaa **Ubuntu-välilehteen**. Hae raportti, tarkista syntaksi ja kokeile samaa funktiota, jota oikea raportti käyttää. Onnistunut `bash -n` palaa kehotteeseen. Odotetut tilat ovat järjestyksessä OK, WARNING ja WARNING.

```bash
cd ~/linux-viikko2
git pull --ff-only
cd viikko3
bash -n report.sh
bash report.sh --test-disk 50
bash report.sh --test-disk 80
bash report.sh --test-disk 90
```

## 3. Julkaise sivu ja käynnistä ajastus

Palaa **Windows PowerShellin** repo-välilehteen. Tallenna ajastin, käyttöönotto ja testaus toisena työvaiheena.

```powershell
git add -- viikko3/systemd viikko3/install.sh viikko3/verify.sh viikko3/README.md
git commit -m "Ajasta minuuttiraportti ja lisää uudelleenkäynnistyksen tarkistus"
git push
```

Aja **Ubuntussa** seuraavat komennot.

```bash
cd ~/linux-viikko2/viikko3
git pull --ff-only && bash install.sh
systemctl list-timers jlinux-report.timer --no-pager
```

Asennus käyttää viikon 1 Nginxin sivustohakemistoa. Se tekee alikansion `/var/www/html/viikko3/`, asentaa generaattorin `/opt/jlinux-report/`-hakemistoon ja kytkee ajastimen käyttöön. Palvelu ajaa Bashin käyttäjänä ubuntu. `OnCalendar=minutely` ajastaa palvelun kerran minuutissa ja `enable --now` ottaa ajastimen käyttöön heti ja myös tulevissa käynnistyksissä.

Avaa **Windowsin selaimessa** [viikon 3 sivu](http://193.166.24.87/viikko3/). Tarkista aikaleima, käytetty levytila ja muisti. Päivitä sivu noin 1–2 minuutin päästä. Avaa myös [viikon 2 laskuri](http://193.166.24.87/viikko2/).

## 4. Kerää testitulokset omalla koneellasi

Aja **Ubuntussa** seuraava komento. Anna sen käydä rauhassa noin 1–2 minuuttia.

```bash
cd ~/linux-viikko2/viikko3
bash verify.sh ennen
```

Ennen-vaihe tarkistaa syntaksin, ajaa skriptin käsin, lukee HTML-sivun Nginxin kautta ja testaa 50, 80 ja 90 prosentin syötteet. Testisyötteet annetaan suoraan funktiolle. Sivu käyttää koko ajan oikeaa levytilaa. Testi havaitsee kaksi ajastimen tekemää päivitystä ja tallentaa mitatut ajat sivulle.

Kun terminaalissa näkyy **Ennen-testi valmis**, käynnistä JLinux uudelleen seuraavalla komennolla.

```bash
sudo reboot
```

SSH-yhteys katkeaa käynnistyksen ajaksi. Kirjaudu **Windows PowerShellissä** uudelleen kohdan 1 SSH-komennolla. Jatka **Ubuntussa** näillä komennoilla.

```bash
cd ~/linux-viikko2/viikko3
bash verify.sh jalkeen
```

Testi vertaa käynnistystunnuksia, avaa viikon 2 laskurin sekä viikon 3 raportin Nginxin kautta ja odottaa kaksi uutta ajastettua raporttia. Sivulle tulee käynnistysaika ja havaitut päivitysajat. Tarkistuksen tekeminen kestää noin 1–2 minuuttia. Käynnistystunnus jää palvelimen yksityiseen testihakemistoon. Avaa lopuksi molemmat julkiset osoitteet Windowsin selaimessa ja tarkista raportin **Test results on JLinux** sekä sen GitHub-linkki.

## 5. Tallenna oma testitulos ja palauta

Jälkeen-vaihe tuottaa lyhyen tiedoston todellisista mittauksista. Kopioi se **Windows PowerShellin repo-välilehdessä** ja tee testituloksesta viimeinen commit.

```powershell
cd 'D:\Codes\OAMK\linux-viikko2'
scp -o IdentitiesOnly=yes -i "$env:USERPROFILE\.ssh\linuxkurssi-jlinux" ubuntu@193.166.24.87:/var/lib/jlinux-report/TESTIT.md .\viikko3\TESTIT.md
git add -- viikko3/TESTIT.md
git commit -m "Kirjaa JLinuxissa mitatut ajastetut päivitykset uudelleenkäynnistyksen jälkeen"
git push
```

Moodleen palautetaan vain [http://193.166.24.87/viikko3/](http://193.166.24.87/viikko3/). Pidä JLinux ja sen ajastin käynnissä vertaisarvioinnin läpi. Viikon 2 sovellus jatkaa alkuperäisessä osoitteessaan vähintään viikon.

### Jos aikaleima pysyy samana

Katso JLinuxissa seuraava ajo sekä viimeisimmän ajon tulos.

```bash
systemctl list-timers jlinux-report.timer --no-pager
systemctl status jlinux-report.service --no-pager
journalctl -u jlinux-report.service -n 12 --no-pager
```

Palvelu on tyyppiä `oneshot`, joten onnistuneen ajon jälkeen se voi olla `inactive (dead)`. Ajastimen kuuluu olla `active (waiting)`.
