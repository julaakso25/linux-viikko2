# JLinux · Viikko 4

| Palvelin | Arvioitava kohde |
| --- | --- |
| A · alkuperäinen palvelin | [Kirjoittava vierailulaskuri](http://193.166.24.87/viikko2/) · [Viikon 3 tilaraportti](http://193.166.24.87/viikko3/) |
| B · kopio snapshotista jlinux-week4-base | [Paikallinen lukukopio, dokumentaatio ja mitatut tulokset](http://193.166.24.105/viikko4/) |

B luotiin A:n cPouta-snapshotista. Kummallakin koneella on oma yksityinen ja julkinen osoite. B:n sivun levytaulukot näyttävät verkkojuuren, tietokannan ja varmistushakemiston todelliset liitospisteet. Tietokannan ja sivutiedostojen varmistustapa eroavat toisistaan.

## Tiedostojen varmistus

[B:n cron](backup-web.cron) ajaa [varmistusskriptin](backup-web.sh) kerran tunnissa. B:n jlbackup hakee A:n verkkojuuren jlwebread-tunnuksen rajatulla SSH-avaimella. Aikaleimatut arkistot ja ajokohtainen loki sijaitsevat B:llä hakemistossa /var/backups/jlinux-web. Hakemiston omistaa jlbackup ja sen oikeudet ovat 0700. Palautusvertailussa käytetään A:n alkuperäisen index.html-tiedoston ja erilliseen sijaintiin puretun kopion SHA-256-tiivisteitä.

## MariaDB ja verkkosovellus

[A:n ja B:n MariaDB-asetukset](mariadb/) määrittävät erilliset palvelintunnukset, A:n rivilokin, B:n lukutilan ja laskuritaulun suodattimen. [Yhteyden alustus](yhdista.py) käyttää tietokantavedokseen kirjattua sijaintia. [A:n asetukset](asenna-a.sh) rajaavat replikaatiotunnuksen paikalliseen TCP-yhteyteen ja SSH-avaimen B:n projektiverkon osoitteeseen. [B:n socket ja palvelut](systemd/) välittävät liikenteen salattuna SSH:n kautta. Replikaatio siirtää myös virheelliset muutokset. Tietokannan aiemman tilan palauttamiseen tarvitaan erillinen tietokantavarmistus.

[B:n sovellus](app.py) suorittaa paikallisen SELECT-kyselyn Unix-socketin kautta. Sovelluksen jlweek4-tunnuksella on lukuoikeus laskuritauluun. [Nginx](nginx-viikko4.conf) ohjaa viikko 4:n pyynnöt sovellukselle. A:n alkuperäinen sovellus kasvattaa samaa laskuria A:n tietokannassa.

## Todennus

[Palvelintesti](todenna.py) kirjaa replikaatiosäikeiden tilan, vertaa käynnistystunnisteita sekä tarkistaa kaksi eri tunnin cron-ajoa ja tiedoston palautuksen. [Julkiset sivutestit](jlinux.ps1) mittaavat lukemat opiskelijan Windows-koneelta. Arviointiaineisto on [B:n sivulla](http://193.166.24.105/viikko4/) ja loppumittauksen jälkeen [testitulosten tiedostossa](TULOKSET.md). Mittaukset sisältävät kellonajat, laskurin lukemat, varmistusversiot ja tiedostojen vertailun tuloksen.
