#!/bin/zsh
# Baut die Web-Fassung: Kurs kopieren, Dateien prüfen, Versionsnummer eintragen, ZIP schnüren.
set -euo pipefail
HERE=${0:A:h}
ROOT=${HERE:h}
WEB=$ROOT/Web
DIST=$ROOT/dist

cp $ROOT/Packages/JavaQuestKit/Sources/JavaQuestKit/Resources/java_course.json $WEB/java_course.json
python3 -c "
import json, sys
kurs = json.load(open('$WEB/java_course.json'))
lektionen = [l for m in kurs['modules'] for l in m['lessons']]
aufgaben = sum(len(l['tasks']) for l in lektionen) + len(kurs.get('taskPool', []))
print(f\"Kurs: {len(kurs['modules'])} Module, {len(lektionen)} Lektionen, {aufgaben} übbare Aufgaben\")
"
for datei in index.html app.js styles.css sw.js manifest.webmanifest icons/icon-180.png icons/icon-192.png icons/icon-512.png; do
  [[ -f $WEB/$datei ]] || { echo "FEHLT: $datei"; exit 1; }
done
python3 -c "import json; json.load(open('$WEB/manifest.webmanifest')); print('Manifest: in Ordnung')"

# Versionsnummer aus dem Inhalt berechnen und in sw.js und index.html eintragen. Ohne neue
# Nummer lädt der Service Worker nichts nach – Stammnutzer behielten den alten Kurs.
node $ROOT/Tools/web_fassung.mjs --schreiben
node $ROOT/Tools/web_fassung.mjs >/dev/null

mkdir -p $DIST
rm -f $DIST/JavaQuest-Web.zip
(cd $WEB && zip -q -r $DIST/JavaQuest-Web.zip . -x '.*')
ls -la $DIST/JavaQuest-Web.zip | awk '{printf "ZIP: %.1f MB  %s\n", $5/1048576, $9}'
