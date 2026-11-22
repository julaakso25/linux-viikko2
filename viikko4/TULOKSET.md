JLinux · viikon 4 mittaukset

Ennen B:n uudelleenkäynnistystä — 2026-11-22 19:47:07 UTC
Julkinen HTTP Windowsista: A /viikko2/, A /viikko3/ ja B /viikko4/ vastasivat.
B:n kaksi peräkkäistä latausta: 35 → 35. A:n lataus: 36. B sen jälkeen: 36.
MariaDB: I/O Yes, SQL Yes, viimeiset virhekoodit 0. Lokikohta jlinux-a-bin.000001:586.
Nginx, MariaDB, B:n sovellus, tietokantayhteyden socket ja cron aktiivisia ja käytössä.

B:n uudelleenkäynnistyksen jälkeen — 2026-11-22 19:51:59 UTC
Julkinen HTTP Windowsista: A /viikko2/, A /viikko3/ ja B /viikko4/ vastasivat.
B:n kaksi peräkkäistä latausta: 36 → 36. A:n lataus: 37. B sen jälkeen: 37.
MariaDB: I/O Yes, SQL Yes, viimeiset virhekoodit 0. Lokikohta jlinux-a-bin.000001:841.
Nginx, MariaDB, B:n sovellus, tietokantayhteyden socket ja cron aktiivisia ja käytössä.

B:n käynnistystunniste vaihtui. Linuxin ilmoittama käynnistysaika 2026-11-22 19:51:03 UTC.

Testiajastus oli minuutin mittainen. Kaksi automaattista ajoa tarkistettiin. Lopullinen ajastus on kerran tunnissa.
Ajastetut varmistukset ja palautus — 2026-11-22 20:11:05 UTC
Cron OK · 2026-11-22 20:03:01 UTC · html-20261122T200301Z-JPXdK2.tar.gz
Cron OK · 2026-11-22 20:05:06 UTC · html-20261122T200506Z-ABHPbR.tar.gz
Uusin näistä arkistoista syntyi B:n uudelleenkäynnistyksen jälkeen.
Palautettu erilliseen sijaintiin /var/lib/jlinux-week4/private/palautus/index.html.
A:n alkuperäisen ja B:llä palautetun index.html:n sama SHA-256:
e51178c93047807f563466482429609141bf53ee84f90a269a598c0f55237dce
