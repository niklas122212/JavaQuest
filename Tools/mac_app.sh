#!/bin/zsh
# Eine einzige JavaQuest-App auf dem Mac, immer auf dem veröffentlichten Stand.
#
# Vorher lagen drei JavaQuest-Apps auf dem Mac: eine von Hand nach ~/Applications kopierte
# vom 21.09. und zwei Bauzwischenstände von Xcode, die Spotlight und das Launchpad als
# eigene Programme anzeigen. Welche man erwischte, war Zufall – und die kopierte blieb für
# immer auf ihrem alten Stand.
#
# Dieses Skript baut den veröffentlichten Stand (origin/main) in einem Ordner, den
# Spotlight nicht erfasst (*.noindex), und legt das Ergebnis als ~/Applications/JavaQuest.app
# ab. Eine laufende App wird nie unterbrochen: Die neue Fassung wartet fertig gebaut, bis
# JavaQuest geschlossen ist, und wird beim nächsten Aufruf eingesetzt. Der Lernstand liegt
# nicht in der App, sondern in ~/Library/Containers/io.github.niklas122212.JavaQuest. Das
# Skript verändert ihn nie; vor jedem Einsetzen legt es eine Kopie ab, weil eine neue
# Fassung die Datenbank beim ersten Start umstellen kann.
#
#   Tools/mac_app.sh               aktualisieren, falls es etwas Neues gibt
#   Tools/mac_app.sh --einrichten  ab jetzt von selbst: bei der Anmeldung und alle 10 Minuten
#   Tools/mac_app.sh --ausschalten das wieder abschalten (die installierte App bleibt)
#   Tools/mac_app.sh --aufraeumen  Xcode-Zwischenstände aus Spotlight und Launchpad nehmen
#   Tools/mac_app.sh --zurueck     die vorige Fassung wiederherstellen
set -euo pipefail

# Ganz oben festhalten: In einer zsh-Funktion ist $0 der Name der Funktion, nicht des Skripts.
SKRIPT=${0:A}
REPO=${SKRIPT:h:h}
KENNUNG=io.github.niklas122212.JavaQuest
ZIEL=$HOME/Applications/JavaQuest.app
ARBEIT=$HOME/Library/Caches/JavaQuest-Aktualisierung.noindex
BEREIT=$ARBEIT/bereit/JavaQuest.app
VORHER=$ARBEIT/vorher/JavaQuest.app
LERNSTAND="$HOME/Library/Containers/$KENNUNG/Data/Library/Application Support"
# Nicht unter Caches: Den Ordner darf macOS bei Platzmangel leeren, und eine Sicherung
# ist genau dann wertvoll, wenn man sie nicht erwartet hat zu brauchen.
SICHERUNGEN="$HOME/Library/Application Support/JavaQuest-Aktualisierung/Lernstand"
AUFTRAG=$KENNUNG.aktualisieren
AGENT=$HOME/Library/LaunchAgents/$AUFTRAG.plist
PROTOKOLL=$HOME/Library/Logs/JavaQuest-Aktualisierung.log
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

meldung() { print -r -- "$(date '+%d.%m. %H:%M')  $*"; }

# Jede Mac-Fassung von JavaQuest, egal aus welchem Ordner (die im Simulator zählt nicht).
laeuft() { pgrep -f "/JavaQuest\.app/Contents/MacOS/JavaQuest" >/dev/null; }

bauen() {
  local sha=$1 quelle=$ARBEIT/quelle
  meldung "Baue ${sha[1,7]} …"
  rm -rf $quelle && mkdir -p $quelle
  # Aus dem veröffentlichten Stand, nicht aus dem Arbeitsordner: Halbfertiges dort bleibt draußen.
  git -C $REPO archive $sha | tar -x -C $quelle
  # Laufende Nummer = Zahl der Commits; steht unter „Über JavaQuest“ in Klammern.
  local nummer=$(git -C $REPO rev-list --count $sha)
  if ! xcodebuild -quiet -project $quelle/JavaQuest.xcodeproj -scheme JavaQuest -configuration Release \
       -destination 'generic/platform=macOS' -derivedDataPath $ARBEIT/bau \
       CURRENT_PROJECT_VERSION=$nummer build >$ARBEIT/bau.log 2>&1; then
    meldung "Bau fehlgeschlagen – die installierte App bleibt, wie sie ist. Einzelheiten: $ARBEIT/bau.log"
    return 1
  fi
  local app=$ARBEIT/bau/Build/Products/Release/JavaQuest.app
  local kennung=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" $app/Contents/Info.plist)
  if [[ $kennung != $KENNUNG ]]; then
    # Eine andere Kennung hieße ein anderer Datenordner – der Lernstand wäre scheinbar weg.
    meldung "Gebaute App hat die Kennung $kennung statt $KENNUNG – wird nicht eingesetzt"
    return 1
  fi
  codesign --verify --deep --strict $app
  rm -rf $ARBEIT/bereit && mkdir -p $ARBEIT/bereit
  ditto $app $BEREIT
  print $sha > $ARBEIT/bereit.sha
  meldung "Fassung ${sha[1,7]} (Nummer $nummer) ist gebaut"
}

# Kopie des Lernstands (die SQLite-Datei samt -wal und -shm), die letzten zehn bleiben.
lernstand_sichern() {
  # Frühere Fassungen dieses Skripts legten die Kopien unter Caches ab – umziehen, nicht löschen.
  if [[ -d $ARBEIT/lernstand ]]; then
    mkdir -p "$SICHERUNGEN"
    local alt_ordner
    for alt_ordner in $ARBEIT/lernstand/*(N/); do mv "$alt_ordner" "$SICHERUNGEN/"; done
    rmdir $ARBEIT/lernstand 2>/dev/null || true
  fi
  local dateien=("$LERNSTAND"/JavaQuest.store*(N))
  (( ${#dateien} )) || return 0
  local ziel="$SICHERUNGEN/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$ziel"
  cp -p $dateien "$ziel/"
  # Nur die mit Zeitstempel benannten Kopien rotieren; von Hand abgelegte bleiben.
  local alt=("$SICHERUNGEN"/<->-<->(N/On))
  (( ${#alt} > 10 )) && rm -rf ${alt[11,-1]}
  meldung "Lernstand gesichert: ${ziel/#$HOME/~}"
}

einsetzen() {
  local sha=$(<$ARBEIT/bereit.sha)
  lernstand_sichern
  mkdir -p $HOME/Applications $ARBEIT/vorher
  if [[ -d $ZIEL ]]; then
    rm -rf $VORHER
    mv $ZIEL $VORHER
  fi
  mv $BEREIT $ZIEL
  mv $ARBEIT/bereit.sha $ARBEIT/installiert
  $LSREGISTER -f $ZIEL
  meldung "JavaQuest ${sha[1,7]} eingesetzt – vorige Fassung liegt in ${VORHER/#$HOME/~}"
}

aktualisieren() {
  mkdir -p $ARBEIT
  # Ohne Netz einfach beim nächsten Mal – im Hintergrund ohne Eintrag ins Protokoll.
  if ! git -C $REPO fetch -q origin main 2>/dev/null; then
    [[ -t 1 ]] && meldung "Kein Netz – nichts geprüft"
    return 0
  fi
  local neu=$(git -C $REPO rev-parse origin/main)
  local installiert=$(cat $ARBEIT/installiert 2>/dev/null || true)
  local gebaut=$(cat $ARBEIT/bereit.sha 2>/dev/null || true)

  if [[ ! -d $ZIEL || $neu != $installiert ]] && [[ $neu != $gebaut || ! -d $BEREIT ]]; then
    bauen $neu || return 1
  fi
  if [[ -d $BEREIT ]]; then
    if laeuft; then
      # Im Hintergrund nur einmal je Fassung melden, nicht alle 10 Minuten.
      local bereit_sha=$(<$ARBEIT/bereit.sha)
      if [[ -t 1 || $(cat $ARBEIT/gemeldet 2>/dev/null || true) != $bereit_sha ]]; then
        if [[ -f $AGENT ]]; then
          meldung "Neue Fassung liegt bereit – sie wird eingesetzt, sobald JavaQuest geschlossen ist"
        else
          meldung "Neue Fassung liegt bereit – JavaQuest schließen (⌘Q) und das Skript noch einmal aufrufen"
        fi
        print $bereit_sha > $ARBEIT/gemeldet
      fi
    else
      einsetzen
    fi
  elif [[ -t 1 ]]; then
    # Nur von Hand gemeldet: Im Hintergrund würde das Protokoll sonst alle 10 Minuten wachsen.
    meldung "JavaQuest ist aktuell (${installiert[1,7]})"
  fi
}

# Die Xcode-Zwischenstände aus Spotlight und Launchpad nehmen und dafür sorgen, dass
# künftige Xcode-Bauten dieses Projekts dort gar nicht erst auftauchen.
aufraeumen() {
  # Projektbezogene Xcode-Einstellung (nur für diesen Benutzer, xcuserdata ist nicht im
  # Repo): Bauten landen in einem *.noindex-Ordner, den Spotlight überspringt.
  local einstellungen=$REPO/JavaQuest.xcodeproj/project.xcworkspace/xcuserdata/$USER.xcuserdatad
  mkdir -p $einstellungen
  cat > $einstellungen/WorkspaceSettings.xcsettings <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildLocationStyle</key>
	<string>UseAppPreferences</string>
	<key>DerivedDataCustomLocation</key>
	<string>$HOME/Library/Developer/Xcode/DerivedData.noindex</string>
	<key>DerivedDataLocationStyle</key>
	<string>AbsolutePath</string>
</dict>
</plist>
PLIST
  local app
  for app in $HOME/Library/Developer/Xcode/DerivedData/JavaQuest-*/Build/Products/*/JavaQuest.app(N); do
    if pgrep -f "${app}/" >/dev/null; then
      meldung "Läuft noch, bleibt vorerst: ${app/#$HOME/~}"
      continue
    fi
    $LSREGISTER -u $app 2>/dev/null || true
    # In den Papierkorb statt löschen – nur ein Bauzwischenstand, aber so bleibt er zurückholbar.
    mv $app $HOME/.Trash/JavaQuest-${${app:h}:t}-$(date +%Y%m%d-%H%M%S).app
    meldung "Aus Spotlight entfernt (liegt im Papierkorb): ${app/#$HOME/~}"
  done
}

einrichten() {
  mkdir -p ${AGENT:h} ${PROTOKOLL:h}
  cat > $AGENT <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$AUFTRAG</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>$SKRIPT</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>600</integer>
	<key>ProcessType</key>
	<string>Background</string>
	<key>LowPriorityIO</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$PROTOKOLL</string>
	<key>StandardErrorPath</key>
	<string>$PROTOKOLL</string>
</dict>
</plist>
PLIST
  plutil -lint -s $AGENT
  launchctl bootout gui/$UID/$AUFTRAG 2>/dev/null || true
  launchctl bootstrap gui/$UID $AGENT
  meldung "Automatische Aktualisierung ist an: bei der Anmeldung und alle 10 Minuten. Protokoll: ${PROTOKOLL/#$HOME/~}"
}

case ${1:-} in
  --einrichten)
    einrichten
    ;;
  --ausschalten)
    launchctl bootout gui/$UID/$AUFTRAG 2>/dev/null || true
    rm -f $AGENT
    meldung "Automatische Aktualisierung ist aus. Die installierte App bleibt."
    ;;
  --aufraeumen)
    aufraeumen
    ;;
  --zurueck)
    [[ -d $VORHER ]] || { meldung "Keine vorige Fassung vorhanden"; exit 1; }
    laeuft && { meldung "Bitte JavaQuest zuerst schließen"; exit 1; }
    rm -rf $ARBEIT/tausch && mkdir -p $ARBEIT/tausch
    mv $ZIEL $ARBEIT/tausch/JavaQuest.app
    mv $VORHER $ZIEL
    mv $ARBEIT/tausch/JavaQuest.app $VORHER
    $LSREGISTER -f $ZIEL
    meldung "Vorige Fassung wiederhergestellt"
    ;;
  "")
    aktualisieren
    ;;
  *)
    print -u2 "Unbekannt: $1 – erlaubt sind --einrichten, --ausschalten, --aufraeumen und --zurueck"
    exit 2
    ;;
esac
