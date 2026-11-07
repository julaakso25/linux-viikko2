# JLinux • Viikko 2

Nginx ohjaa osoitteen /viikko2/ paikalliseen Python-sovellukseen. Viikon 1 sivu on osoitteessa /. MariaDB säilyttää sivulatausten yhteismäärän. Sovellus käyttää paikallista järjestelmätiliä ja tietokantayhteyttä ilman salasanaa. Tietokannan käyttäjällä on SELECT- ja UPDATE-oikeudet laskuritauluun.

- app.py käsittelee sivupyynnön, kasvattaa lukua ja lukee sen saman tietokantatapahtuman aikana.
- page.html sisältää sivun sisällön ja ulkoasun.
- deploy/ sisältää Nginxin polun, MariaDB-taulun, systemd-palvelun ja uudelleenkäynnistystestin.

## Asennus Ubuntussa

Kloonaa oma julkinen GitHub-repositorio HTTPS-osoitteella ja aja sen juuresta `bash deploy/install.sh`. Asennus on tarkoitettu Ubuntun oletusarvoiselle Nginx-sivustolle. Julkinen linkki muodostetaan origin-osoitteesta. Avaa selaimella / ja /viikko2/.

## Pysyvyystesti

Aja `sudo python3 deploy/reboot-test.py ennen`, sitten `sudo reboot`. Kirjaudu takaisin, palaa repositorion juureen ja aja `sudo python3 deploy/reboot-test.py jalkeen`. Ohjelma vertaa Linuxin käynnistystunnisteita ja Nginxin kautta mitattuja lukemia. Tulos näkyy sivulla seuraavalla latauksella.
