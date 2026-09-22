#!/usr/bin/env python3
"""Prüft die fertige Kursdatei auf inhaltliche Widersprüche.

Ergänzt `swift test` (Struktur, Erklärungen, Musterlösungen) und
`verify_java_content.py` (echtes Java) um die Fragen, die sonst niemand stellt:
Ist jedes Thema erreichbar? Gibt es dieselbe Aufgabe zweimal? Zeigt eine
UML-Linie ins Leere? Trainiert eine Variantengruppe nur eine einzige Antwort?

Aufruf: python3 Tools/check_course.py
Rückgabewert 1, sobald ein Befund auftaucht.
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

# Untergrenze für Erklärungen – dieselbe Zahl wie in Tools/course/explanations.py.
MIN_ERKLAERUNG = 90

COURSE = Path(__file__).resolve().parent.parent / "Packages/JavaQuestKit/Sources/JavaQuestKit/Resources/java_course.json"


def body(task):
    """Der eigentliche Inhalt einer Aufgabe – Frage plus Code plus Antworten."""
    parts = [task["prompt"], json.dumps(task.get("choices"), ensure_ascii=False)]
    for key in ("code", "template", "starterCode", "expectedOutput"):
        value = task.get(key)
        if isinstance(value, dict):
            value = "\n".join(line.get("code", "") for line in value.get("lines", []))
        parts.append(str(value))
    return "\n".join(parts)


def main():
    course = json.loads(COURSE.read_text(encoding="utf-8"))
    lessons = [l for m in course["modules"] for l in m["lessons"]]
    lesson_tasks = [t for l in lessons for t in l["tasks"]]
    pool = course.get("taskPool", [])
    tasks = lesson_tasks + pool
    findings = []

    # Erklärungen: vorhanden – und ausführlich genug, um ein „Warum“ zu enthalten.
    # Die Länge ist kein Qualitätsmaß, sondern eine Untergrenze: Ein Satz wie
    # „int steht für ganze Zahlen.“ sagt nur das WAS und hilft beim Lernen nicht weiter.
    findings += [f"{t['id']}: keine Erklärung" for t in tasks if not t.get("explanation", "").strip()]
    findings += [f"{t['id']}: Erklärung zu knapp ({len(t['explanation'])} Zeichen, mindestens {MIN_ERKLAERUNG})"
                 for t in tasks if 0 < len(t.get("explanation", "").strip()) < MIN_ERKLAERUNG]

    # Auswahlaufgaben: Nach einer falschen Antwort muss dastehen, warum sie falsch war.
    ohne_begruendung = [t["id"] for t in tasks if t["type"] == "singleChoice" and not t.get("whyWrong")]
    if ohne_begruendung:
        findings.append(f"{len(ohne_begruendung)} Auswahlaufgabe(n) ohne Begründung der falschen Antworten: "
                        f"{', '.join(sorted(ohne_begruendung)[:8])}"
                        + (" …" if len(ohne_begruendung) > 8 else ""))

    # Eindeutige IDs
    findings += [f"ID doppelt vergeben: {i}" for i, n in Counter(t["id"] for t in tasks).items() if n > 1]

    # Inhaltlich identische Aufgaben trainieren nur die Antwort
    same = defaultdict(list)
    for task in tasks:
        same[body(task)].append(task["id"])
    findings += [f"inhaltsgleiche Aufgaben: {ids}" for ids in same.values() if len(ids) > 1]

    # Themen: keine Karteileichen, nichts Unerreichbares
    topics = {t["id"] for t in course["topics"]}
    used = {t["topicId"] for t in tasks}
    findings += [f"Thema ohne Aufgabe (in der freien Auswahl unsichtbar): {t}" for t in sorted(topics - used)]
    findings += [f"Aufgabe zeigt auf unbekanntes Thema: {t['id']} → {t['topicId']}" for t in tasks if t["topicId"] not in topics]

    # Varianten
    groups = defaultdict(list)
    for task in tasks:
        groups[task.get("variantGroup", task["id"])].append(task)
    for key, variants in groups.items():
        if len(variants) > 1 and len({t["topicId"] for t in variants}) > 1:
            findings.append(f"Variantengruppe {key} mischt Themen: {sorted({t['topicId'] for t in variants})}")
    pool_groups = {t["variantGroup"] for t in pool if t.get("variantGroup")}
    lesson_ids = {t["id"] for t in lesson_tasks}
    findings += [f"Variantengruppe ohne Lektionsaufgabe: {g}" for g in sorted(pool_groups - lesson_ids)]

    # Abwechslung: keine Stufe eines Themas darf aus einem einzigen Aufgabentyp bestehen.
    # Ankreuzen prüft Wiedererkennen, selbst schreiben prüft Können – wer nur eines davon
    # bekommt, übt einseitig.
    je_stufe = defaultdict(list)
    for task in tasks:
        je_stufe[(task["topicId"], task["difficulty"])].append(task)
    for (topic, level), gleiche in sorted(je_stufe.items()):
        typen = {t["type"] for t in gleiche}
        if len(gleiche) >= 3 and len(typen) == 1:
            findings.append(f"{topic} Stufe {level}: {len(gleiche)} Aufgaben, alle vom Typ {typen.pop()}")

    # Und kein Thema darf überwiegend aus „Was gibt das aus?“ bestehen.
    je_thema = defaultdict(Counter)
    for task in tasks:
        je_thema[task["topicId"]][task["type"]] += 1
    for topic, zaehler in sorted(je_thema.items()):
        gesamt = sum(zaehler.values())
        if gesamt >= 10 and zaehler["predictOutput"] / gesamt > 0.5:
            findings.append(f"{topic}: {zaehler['predictOutput']} von {gesamt} Aufgaben sind „Was gibt das aus?“")

    # Tiefe: Ab drei Varianten wiederholt sich auch im dritten Anlauf keine Frage.
    duenn = [key for key, variants in groups.items() if len(variants) < 3]
    if duenn:
        findings.append(f"{len(duenn)} Lernziel(e) mit weniger als drei Varianten: "
                        f"{', '.join(sorted(duenn)[:8])}" + (" …" if len(duenn) > 8 else ""))

    # Multiple Choice: genug Auswahl, richtige Antwort vorhanden
    for task in tasks:
        if task["type"] != "singleChoice":
            continue
        choices = task.get("choices", [])
        if len(choices) < 3:
            findings.append(f"{task['id']}: nur {len(choices)} Antwortmöglichkeiten")
        if not 0 <= task.get("correctIndex", -1) < len(choices):
            findings.append(f"{task['id']}: correctIndex zeigt ins Leere")
        if len(set(choices)) != len(choices):
            findings.append(f"{task['id']}: doppelte Antwortmöglichkeit")

    # UML: jede Linie braucht zwei Kästen
    diagrams = [(l["id"], c["diagram"]) for l in lessons for c in l["theory"] if c.get("diagram")]
    diagrams += [(t["id"], t["diagram"]) for t in tasks if t.get("diagram")]
    for where, diagram in diagrams:
        names = {b["name"] for b in diagram["classes"]}
        for relation in diagram.get("relations", []):
            missing = {relation["from"], relation["to"]} - names
            if missing:
                findings.append(f"{where}: UML-Linie ohne Kasten {sorted(missing)}")

    # Niveaus steigen innerhalb einer Lektion an
    for lesson in lessons:
        levels = [t["difficulty"] for t in lesson["tasks"]]
        if levels != sorted(levels) or levels[0] != 1:
            findings.append(f"{lesson['id']}: Niveaus steigen nicht an ({levels})")

    print(f"{len(course['modules'])} Module · {len(lessons)} Lektionen · {len(lesson_tasks)} Lektionsaufgaben "
          f"· {len(pool)} im Übungspool · {len(tasks)} übbar")
    print(f"{len(groups)} Lernziele, davon {sum(1 for v in groups.values() if len(v) > 1)} mit mehreren Varianten "
          f"· {len(diagrams)} UML-Diagramme · {len(topics)} Themen, alle mit Aufgaben"
          if not (topics - used) else f"{len(groups)} Lernziele · {len(diagrams)} UML-Diagramme")

    if findings:
        print(f"\n{len(findings)} Befund(e):")
        for finding in findings:
            print(" -", finding)
        return 1
    print("\nKeine Befunde.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
