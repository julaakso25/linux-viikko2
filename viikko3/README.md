# JLinux – Viikon 3 palvelinraportti

[Avaa palvelinraportti](http://193.166.24.87/viikko3/)

JLinux on CSC cPoudassa toimiva Ubuntu-palvelin. Raportti näyttää luontiajan UTC-aikana, palvelimen käynnissäoloajan, juuriosion käyttöasteen sekä kokonaismuistin ja käytettävissä olevan muistin (MiB).

## Toteutus

[report.sh](report.sh) lukee tiedot komennoilla `date`, `uptime`, `df` ja `free`. Putki `df -P / | awk 'NR == 2 {print $5}'` poimii juuriosion käyttöprosentin. Skripti kirjoittaa HTML:n ensin väliaikaiseen tiedostoon ja siirtää valmiin raportin Nginxin palveltavaksi.

[systemd-ajastin](systemd/jlinux-report.timer) käynnistää [raporttipalvelun](systemd/jlinux-report.service) kerran minuutissa. Ajastin käynnistyy myös palvelimen uudelleenkäynnistyksen jälkeen.

## Testitulokset

`bash -n report.sh` läpäisi syntaksitarkistuksen. Levytilatestissä 50 % tuotti tilan `OK`, 80 % tilan `WARNING` ja 90 % tilan `WARNING`. Varoitus alkaa siis täsmälleen 80 prosentista.

JLinux käynnistyi uudelleen 14.11.2026 klo 18.00.43 UTC. Sekä [viikon 2 laskuri](http://193.166.24.87/viikko2/) että viikon 3 raportti avautuivat. Ajastin julkaisi seuraavat havaitut raportit klo 18.02 ja 18.03 UTC. [Testiloki](TESTIT.md)
