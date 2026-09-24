#!/bin/zsh
# Baut das portable Windows-Paket (ZIP): App + Java-Laufzeit, ohne Installation startbar.
# Läuft auf macOS oder Linux; ein MSI-Installer entsteht nur unter Windows (siehe README).
set -euo pipefail
HERE=${0:A:h}
PROJECT=${HERE:h}
JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jre_x64_windows_hotspot_21.0.12.1_1.zip"
JRE_SHA256="d35f31e712f0fcf6ac5a093edc90204fbff22f720ba3950bd09d331d5e621636"
WORK=$PROJECT/build/portable
DIST=$PROJECT/../dist
OUT=$DIST/JavaQuest-Windows

# Versionsnummer aus dem Git-Tag – Gradle ist die einzige Quelle (siehe build.gradle.kts).
VERSION=$(cd $PROJECT && ./gradlew -q zeigeVersion --console=plain)
[[ $VERSION =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "Unbrauchbare Versionsnummer: $VERSION" >&2; exit 1; }
echo "== Version $VERSION"

echo "== 1/5 App bauen"
(cd $PROJECT && ./gradlew packageUberJarForCurrentOS --console=plain -q)
# Genau die JAR dieser Version: Mit „ls JavaQuest-*.jar | head -1“ hätte eine liegen
# gebliebene …-1.0.0.jar vor …-1.0.1.jar sortiert – das Paket bekäme die alte App.
JARS=($PROJECT/build/compose/jars/JavaQuest-*-$VERSION.jar(N))
(( ${#JARS} == 1 )) || { echo "Erwarte genau eine JAR für Version $VERSION, gefunden: ${#JARS}" >&2; exit 1; }
JAR=$JARS[1]
mkdir -p $WORK

echo "== 2/5 Ungenutzte Symbole entfernen"
python3 $HERE/strip_unused_icons.py $JAR $WORK/JavaQuest-all.jar

echo "== 3/5 Selbsttest: jeden Bildschirm aus der fertigen JAR zeichnen"
rm -rf $WORK/selfcheck
java -Djavaquest.selfcheck=$WORK/selfcheck -jar $WORK/JavaQuest-all.jar 2>&1 | grep -v '^WARNING'

echo "== 4/5 Java-Laufzeit für Windows (Eclipse Temurin 21)"
if [[ ! -f $WORK/jre.zip ]] || ! echo "$JRE_SHA256  $WORK/jre.zip" | shasum -a 256 -c --status; then
  curl -sL -o $WORK/jre.zip "$JRE_URL"
fi
echo "$JRE_SHA256  $WORK/jre.zip" | shasum -a 256 -c

echo "== 5/5 Paket zusammenstellen"
rm -rf $OUT $DIST/JavaQuest-Windows-$VERSION.zip $WORK/jre-unpacked
mkdir -p $OUT/app $WORK/jre-unpacked
unzip -q $WORK/jre.zip -d $WORK/jre-unpacked
mv $WORK/jre-unpacked/*/ $OUT/runtime
[[ -f $OUT/runtime/bin/javaw.exe ]] || { echo "Laufzeit fehlt im Paket" >&2; exit 1; }
cp $WORK/JavaQuest-all.jar $OUT/app/JavaQuest.jar
zip -q -d $OUT/app/JavaQuest.jar 'libskiko-macos-*' 'libskiko-linux-*' 2>/dev/null || true
printf '@echo off\r\nrem JavaQuest starten - keine Installation und kein eigenes Java noetig.\r\nstart "" "%%~dp0runtime\\bin\\javaw.exe" -Dfile.encoding=UTF-8 -jar "%%~dp0app\\JavaQuest.jar"\r\n' > "$OUT/JavaQuest starten.bat"
cp $HERE/LIES-MICH.txt $OUT/LIES-MICH.txt
(cd $DIST && zip -rq -X JavaQuest-Windows-$VERSION.zip JavaQuest-Windows)
ls -la $DIST/JavaQuest-Windows-$VERSION.zip
shasum -a 256 $DIST/JavaQuest-Windows-$VERSION.zip
