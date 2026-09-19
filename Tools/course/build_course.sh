#!/bin/zsh
# Erzeugt java_course.json neu: Erklär-Engine übersetzen, Kurs zusammenbauen, Zeilen erklären.
# Bricht ab, wenn eine Codezeile keine Erklärungsregel findet.
set -euo pipefail
HERE=${0:A:h}
ROOT=${HERE:h:h}
KIT=$ROOT/Packages/JavaQuestKit/Sources/JavaQuestKit
mkdir -p $HERE/.build
swiftc -O -module-name Annotate $KIT/**/*.swift $HERE/annotate/main.swift -o $HERE/.build/annotate
cd $HERE && python3 course_source.py $KIT/Resources/java_course.json
