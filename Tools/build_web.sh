#!/bin/zsh
# Baut die Web-Fassung: Kurs kopieren, Dateien prüfen, ZIP schnüren.
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

# Die Versionsnummer aus sw.js muss in index.html stehen, sonst liefert der Browser
# nach einem Update weiter seine zwischengespeicherte app.js aus.
python3 - "$WEB" <<'PY'
import re, sys, pathlib
web = pathlib.Path(sys.argv[1])
sw = (web / "sw.js").read_text(encoding="utf-8")
html = (web / "index.html").read_text(encoding="utf-8")
version = re.search(r'const VERSION = "([^"]+)"', sw).group(1)
fehlend = [datei for datei in ("app.js", "styles.css") if f'{datei}?v={version}' not in html]
if fehlend:
    raise SystemExit(f"index.html verweist nicht auf Version {version}: {', '.join(fehlend)}")
print(f"Version: {version} – sw.js und index.html stimmen überein")
PY

mkdir -p $DIST
rm -f $DIST/JavaQuest-Web.zip
(cd $WEB && zip -q -r $DIST/JavaQuest-Web.zip . -x '.*')
ls -la $DIST/JavaQuest-Web.zip | awk '{printf "ZIP: %.1f MB  %s\n", $5/1048576, $9}'
