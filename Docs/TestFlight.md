# JavaQuest per TestFlight verschicken

So kommt die App auf das iPhone einer anderen Person – ohne Kabel, ohne Mac bei ihr.

**Was du brauchst:** Deinen Mac mit Xcode, deine Apple-ID und das Apple Developer Program
(rund 100 € im Jahr). Die Schritte 1 und 2 macht man einmal, danach dauert ein neuer
Build etwa zehn Minuten.

> Diese Schritte kann nur **du** ausführen: Sie verlangen deine Apple-ID, deine
> Zahlungsdaten und die Bestätigung per Zwei-Faktor-Code auf deinem iPhone.

---

## Schritt 1: Beim Apple Developer Program anmelden

1. Auf <https://developer.apple.com/programs/enroll/> gehen und mit deiner Apple-ID anmelden.
2. Als **Einzelperson** (Individual) anmelden – das ist der einfachere Weg. Du brauchst
   einen Ausweis zur Identitätsprüfung.
3. Bezahlen (rund 100 € im Jahr) und die Freischaltung abwarten. Das dauert meist
   ein bis zwei Tage, manchmal auch nur Stunden.

Erst wenn die Mitgliedschaft aktiv ist, funktionieren die nächsten Schritte.

## Schritt 2: Xcode mit deinem Konto verbinden

1. Xcode öffnen → Menü **Xcode → Settings → Accounts**.
2. Mit **+** deine Apple-ID hinzufügen.
3. `JavaQuest.xcodeproj` öffnen, links das Ziel **JavaQuest** anklicken,
   Reiter **Signing & Capabilities**.
4. Bei **Team** dein Team auswählen. Damit füllt sich die bisher leere Einstellung
   `DEVELOPMENT_TEAM`. **Automatically manage signing** bleibt angehakt – Xcode
   erledigt die Zertifikate dann selbst.

Die Bundle-ID `io.github.niklas122212.JavaQuest` steht schon richtig drin und ist
weltweit eindeutig. Sie darf ab jetzt nicht mehr geändert werden, sonst gilt die App
für Apple als eine andere.

## Schritt 3: Den Eintrag in App Store Connect anlegen

1. Auf <https://appstoreconnect.apple.com> anmelden → **Apps** → **+** → **Neue App**.
2. Ausfüllen:
   - **Plattform:** iOS
   - **Name:** JavaQuest (falls der Name vergeben ist, etwas anhängen, z. B. „JavaQuest Lernen“)
   - **Sprache:** Deutsch
   - **Bundle-ID:** `io.github.niklas122212.JavaQuest` aus der Liste wählen
   - **SKU:** irgendein eigenes Kürzel, z. B. `javaquest-1`

Für reines TestFlight brauchst du noch keine Screenshots und keine Beschreibung –
das ist erst für die Veröffentlichung im App Store nötig.

## Schritt 4: Build hochladen

1. In Xcode oben als Ziel **Any iOS Device (arm64)** wählen – nicht den Simulator.
2. Menü **Product → Archive**. Der Vorgang dauert ein paar Minuten.
3. Im Organizer, der sich öffnet: **Distribute App** → **TestFlight & App Store** → **Upload**.
4. Die Vorschläge bestätigen und warten, bis „Upload complete“ erscheint.

Nach dem Upload braucht Apple etwa 5 bis 30 Minuten, bis der Build in App Store Connect
unter **TestFlight** auftaucht. Solange steht dort „Wird verarbeitet“.

Die Frage nach der Verschlüsselung („Export Compliance“) erscheint nicht – die Antwort
steht schon in `Config/Info.plist` (`ITSAppUsesNonExemptEncryption = false`), weil die App
keine eigene Verschlüsselung nutzt.

## Schritt 5: Deinen Freund einladen

Es gibt zwei Wege. Der erste ist schneller, der zweite braucht weniger von deinem Freund.

### Variante A: Interner Tester – sofort, ohne Prüfung durch Apple

1. In App Store Connect: **Benutzer und Zugriff** → **+** → die Apple-ID deines Freundes
   eintragen, Rolle z. B. **Developer** oder **Marketing**.
2. Er bestätigt die Einladung per E-Mail.
3. Unter **TestFlight → Interne Tests** eine Gruppe anlegen, ihn hinzufügen und den
   Build auswählen.

Er kann sofort installieren – Apple prüft hier nichts.

### Variante B: Externer Tester – nur E-Mail nötig

1. Unter **TestFlight → Externe Tests** eine Gruppe anlegen.
2. Die E-Mail-Adresse deines Freundes eintragen (oder einen öffentlichen Link erzeugen).
3. Beim **ersten** Build prüft Apple kurz (meist ein bis zwei Tage). Danach gehen
   weitere Builds ohne neue Prüfung durch.

Was du dabei angeben musst: eine kurze Beschreibung, was getestet werden soll
(z. B. „Java-Lern-App, bitte Lernpfad und freies Training ausprobieren“) und eine
Kontakt-E-Mail.

## Schritt 6: Was dein Freund tut

1. Die kostenlose App **TestFlight** aus dem App Store laden.
2. Deinen Einladungslink antippen (aus der E-Mail).
3. In TestFlight auf **Installieren** tippen – fertig.

Danach ist JavaQuest eine normale App auf seinem Homescreen.

---

## Gut zu wissen

- **Jeder Build läuft 90 Tage.** Danach lädst du einen neuen hoch (Schritt 4 wiederholen),
  deine Tester bekommen ihn automatisch angeboten.
- **Vor jedem neuen Upload** muss die Build-Nummer steigen. In Xcode ist das
  `CURRENT_PROJECT_VERSION` (aktuell `1`) – beim nächsten Mal also `2`. Die sichtbare
  Version `MARKETING_VERSION` (aktuell `1.0`) darf gleich bleiben.
- **Bis zu 100 interne** und **10 000 externe** Tester sind möglich – für einen Freund
  also reichlich Luft.
- **Der Fortschritt deines Freundes** liegt nur auf seinem Gerät. Die App braucht kein
  Konto, keine Anmeldung und keine Internetverbindung.
- **Ohne Mitgliedschaft geht es nicht.** Läuft sie aus, verschwindet die App nach Ablauf
  des letzten Builds vom Gerät deines Freundes.

## Wenn etwas klemmt

| Problem | Ursache und Lösung |
|---|---|
| „No account for team“ oder Signierungsfehler | In Xcode unter *Signing & Capabilities* ist kein Team gewählt (Schritt 2). |
| **Archive** ist ausgegraut | Oben ist der Simulator als Ziel gewählt. Auf **Any iOS Device (arm64)** umstellen. |
| „The bundle version must be higher“ | Build-Nummer `CURRENT_PROJECT_VERSION` erhöhen und neu archivieren. |
| Build bleibt bei „Wird verarbeitet“ | Normal, bis zu 30 Minuten. Danach hilft ein erneuter Upload mit höherer Build-Nummer. |
| Freund sieht die App nicht in TestFlight | Er muss mit **derselben** Apple-ID angemeldet sein, an die die Einladung ging. |

## Stand des Projekts (geprüft)

- Release-Build für echte iPhones: erfolgreich, 7 MB, iOS 17 und neuer
- Bundle-ID `io.github.niklas122212.JavaQuest`, Version 1.0 (Build 1)
- App-Symbol inklusive 1024 × 1024 für den Store vorhanden
- `PrivacyInfo.xcprivacy` liegt bei (Apple verlangt sie seit 2024)
- Kursdatei ist eingebettet – die App braucht kein Internet
- Offen: nur `DEVELOPMENT_TEAM`, das sich mit Schritt 2 von selbst füllt
