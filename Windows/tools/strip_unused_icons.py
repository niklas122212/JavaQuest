#!/usr/bin/env python3
"""Entfernt ungenutzte Material-Symbole aus einer Uber-JAR (spart ~35 MB).

Behalten wird jede Symbol-Klasse, auf die eine andere Klasse der JAR verweist
(Konstantenpool-Suche nach „androidx/compose/material/icons/…“), transitiv.
Aufruf: strip_unused_icons.py <eingabe.jar> <ausgabe.jar>
"""
import re
import sys
import zipfile

ICON_PREFIX = "androidx/compose/material/icons/"
REF = re.compile(rb"androidx/compose/material/icons/[A-Za-z0-9_/$]+")

def is_icon_class(name):
    # Unterpakete (rounded/, filled/, automirrored/rounded/ …) enthalten die einzelnen Symbole.
    return name.startswith(ICON_PREFIX) and name.endswith(".class") and "/" in name[len(ICON_PREFIX):]

src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as z:
    entries = z.infolist()
    data = {e.filename: z.read(e.filename) for e in entries}

keep = set()
queue = [name for name in data if name.endswith(".class") and not is_icon_class(name)]
seen = set(queue)
while queue:
    name = queue.pop()
    for ref in REF.findall(data[name]):
        cls = ref.decode() + ".class"
        if cls in data and cls not in seen:
            seen.add(cls)
            if is_icon_class(cls):
                keep.add(cls)
            queue.append(cls)

removed = 0
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as out:
    for e in entries:
        if is_icon_class(e.filename) and e.filename not in keep:
            removed += 1
            continue
        out.writestr(e, data[e.filename])
print(f"Symbole: {len(keep)} behalten, {removed} Klassen entfernt")
