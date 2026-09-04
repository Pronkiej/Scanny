# WoningScan

Een eigen iOS-app om woningen op te meten voor een energielabel (EPA/NTA 8800). Meet gevels,
daken, vloeren en kozijnen in met de LiDAR-ondersteunde AR-liniaal, leg notities en foto's vast,
en exporteer alles als één .zip (JSON + CSV per categorie) om later handmatig of via een eigen
koppeling in Vabi te verwerken.

**Status:** v1 — de kernflow (scannen/meten + notities + foto's + export) werkt. De export volgt
nog niet exact het benodigde Vabi-importformaat (dat kan later verfijnd worden zodra nodig);
voor nu haalt hij alle vastgelegde data van het toestel.

## Wat zit erin

- **Meten met LiDAR**: tik twee punten aan in de camera-weergave om een afstand te meten
  (`Measuring/ARMeasureView.swift`). Vereist een fysiek toestel met LiDAR-sensor (iPhone 12 Pro
  e.v. Pro-modellen, iPad Pro 2020 e.v.) — werkt niet in de Simulator.
- **Kompas**: elke gevel/dak kan automatisch de windrichting (N/NO/O/ZO/Z/ZW/W/NW) overnemen van
  het kompas van het toestel.
- **Invoerflow**: per woning → per verdieping → gevels (met geneste ramen/deuren/panelen), daken,
  vloeren, gebouwhoogte, gebruiksoppervlak per verdieping, en boiler/aftappunten — zie `Views/`.
- **Foto's en notities** per element.
- **Lokale opslag**: alles wordt als JSON op het toestel zelf bewaard (`Persistence/ProjectStore.swift`),
  geen account of server nodig.
- **Export**: genereert één .zip met `woning.json`, CSV's per categorie, en de foto's — te delen via
  het iOS-deelvenster (AirDrop/Mail/Bestanden). Zie `Export/`.

## Hoe dit gebouwd wordt zonder zelf een Mac te bezitten

Xcode (de compiler voor iOS-apps) draait alleen op macOS. Dit project is zo opgezet dat je dat
probleem omzeilt met gratis cloud-diensten:

1. **GitHub Actions** (`.github/workflows/build-ios.yml`) bouwt de app op een gratis macOS-runner
   in de cloud, elke keer als je naar de `main`-branch pusht (of handmatig via het "Actions"-tabblad
   → "Build iOS app" → "Run workflow"). Resultaat: een `WoningScan.ipa`-bestand als "artifact"
   onderaan de workflow-run, om te downloaden.
   - Gratis quotum: bij een privé-repository ~200 build-minuten/maand (macOS-runners tellen 10x
     zo zwaar); bij een publieke repository onbeperkt. Eén build duurt hier meestal 5-10 minuten.
2. **Sideloadly** (gratis, [sideloadly.io](https://sideloadly.io), werkt op Windows en macOS)
   installeert dat `.ipa`-bestand op je iPhone via een USB-kabel, met alleen een **gratis Apple ID**
   (geen Apple Developer Program nodig). Sideloadly regelt zelf het signeren ("free provisioning").
   - Beperking van een gratis Apple ID: de installatie verloopt na 7 dagen. Sluit dan je iPhone
     opnieuw aan op Sideloadly en klik nogmaals op installeren — kost een minuut, geen geld.
3. Zodra je ooit wél een Mac + Apple Developer Program-account (€99/jaar) hebt: dan kan diezelfde
   `project.yml` ook gewoon lokaal in Xcode geopend worden (`xcodegen generate` en dubbelklik het
   `.xcodeproj`-bestand), met normale automatische signing, TestFlight, etc.

### Stap voor stap: van deze bestanden naar een werkende app op je iPhone

1. Maak een gratis account op [github.com](https://github.com) als je die nog niet hebt.
2. Maak een nieuwe (privé of publieke) repository aan en zet de inhoud van deze map erin
   (upload via de website, of git gebruiken als je daar bekend mee bent).
3. Ga naar het tabblad **Actions** van die repository — de workflow "Build iOS app" start
   automatisch. Wacht tot 'ie groen is (5-10 minuten).
4. Klik de afgeronde workflow-run open, en download onderaan de pagina het artifact
   **WoningScan-ipa** (een .zip met daarin `WoningScan.ipa`).
5. Installeer [Sideloadly](https://sideloadly.io) op je Windows-pc, en (indien nog niet aanwezig)
   Apple's "Apple Devices"/iTunes-drivers zodat Windows je iPhone via USB herkent.
6. Sluit je iPhone aan, open Sideloadly, sleep het `.ipa`-bestand erin, vul je Apple ID in, en klik
   op installeren.
7. Op je iPhone: ga naar **Instellingen → Algemeen → VPN en apparaatbeheer** en vertrouw het
   ontwikkelaarsprofiel van je Apple ID, anders weigert de app te starten.
8. Geef de app bij eerste gebruik toestemming voor camera en locatie (voor het kompas).

## De isolatie/glas-catalogus aanpassen

`Sources/WoningScan/Resources/EigenschappenCatalogus.json` bevat de keuzelijsten voor
isolatiewaarden (wanden/daken/vloeren/deuren/panelen). De waarden die letterlijk in jullie eigen
eerdere exportbestanden voorkwamen staan er al in; een aantal tussenstappen is aangevuld als indicatie en
gemarkeerd met "- controleer" — check die tegen de exacte lijst in jullie Vabi-installatie voordat
je erop vertrouwt. Dit bestand aanpassen vereist geen Swift-kennis, gewoon een teksteditor; na een
wijziging moet de app opnieuw gebouwd worden (commit + push, GitHub Actions doet de rest).

## Projectstructuur

```
project.yml                          XcodeGen-configuratie (genereert het .xcodeproj)
.github/workflows/build-ios.yml      GitHub Actions CI (gratis macOS-build)
Sources/WoningScan/
  App/WoningScanApp.swift            App entry point
  Models/                            Datamodel (Woning, Gevel, Opening, Dak, Vloer, ...)
  Measuring/                         AR-liniaal (ARKit/LiDAR) + kompas
  Persistence/ProjectStore.swift     Lokale JSON-opslag + foto's
  Views/                             Alle schermen (invoerflow)
  Export/                            .zip-export (JSON + CSV + foto's)
  Resources/                         Info.plist, isolatie-catalogus (JSON)
```

## Bekende beperkingen / volgende stappen

- De export volgt nu een CSV-structuur die dicht tegen het benodigde Vabi-importformaat aanzit,
  maar nog niet exact (samengevoegde cellen, precieze kolomvolgorde) — prima om zelf te
  fine-tunen zodra bekend is hoe jullie 'm in Vabi willen inladen.
- Geen RoomPlan-automatisch-scannen (auto-gegenereerd 3D-model) — alleen de handmatige AR-liniaal
  per gevel/opening. Kan later toegevoegd worden als versnelling.
- Geen opgemaakt PDF-fotorapport — de foto's zitten wel in de export, alleen nog niet in een
  opgemaakt rapport.
- Getest kan alleen worden op een fysiek toestel met LiDAR; de Simulator ondersteunt geen camera/AR.
