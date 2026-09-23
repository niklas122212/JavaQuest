#!/usr/bin/env python3
"""Prüft die Java-Inhalte der Kursdatei mit einem echten JDK.

Für jede Aufgabe wird der relevante Code (Musterlösung, Lückentext mit erster
akzeptierter Antwort, gezeigter Code) kompiliert und – wo eine erwartete Ausgabe
bekannt ist – ausgeführt und mit der Ausgabe im JSON verglichen.

Code-Felder dürfen einfacher Text oder ein Objekt mit Zeilen und Erklärungen sein
({"lines": [{"code": …, "explain": …}]}); geprüft wird immer der zusammengesetzte Code.

Das Feld "verify" im JSON ist reine Autoren-Metadaten und wird von der App ignoriert:
  verify.main      Anweisungen für eine Test-main (bei javaContext members/file)
  verify.output    erwartete Ausgabe, falls die Aufgabe selbst keine angibt
  verify.compiles  false, wenn der gezeigte Code absichtlich nicht kompiliert

Aufruf: python3 Tools/verify_java_content.py [pfad/zur/java_course.json]
Benötigt javac/java im PATH (JDK 21 oder neuer).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

IMPORTS = ("import java.util.*;\nimport java.util.function.*;\nimport java.util.stream.*;\n"
           "import java.util.concurrent.*;\nimport java.util.concurrent.atomic.*;\n"
           "import java.io.*;\nimport java.nio.file.*;\nimport java.time.*;\nimport java.time.format.*;\n\n")
DEFAULT_PATH = os.path.join(os.path.dirname(__file__), "..", "Packages", "JavaQuestKit",
                            "Sources", "JavaQuestKit", "Resources", "java_course.json")


def indent(text, spaces):
    return "\n".join((" " * spaces + line) if line else line for line in text.splitlines())


def normalize_output(text):
    lines = [line.rstrip(" \t") for line in text.replace("\r\n", "\n").split("\n")]
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()
    return lines


def build_source(snippet, context, verify_main):
    """Liefert (Quelltext, auszuführende Klasse oder None)."""
    has_main = re.search(r"static\s+void\s+main\s*\(", snippet) is not None
    if context == "statements":
        body = indent(snippet, 8)
        return IMPORTS + f"public class Main {{\n    public static void main(String[] args) throws Exception {{\n{body}\n    }}\n}}\n", "Main"
    if context == "members":
        main = ""
        if not has_main and verify_main:
            main = f"\n\n    public static void main(String[] args) throws Exception {{\n{indent(verify_main, 8)}\n    }}"
        run = "Main" if (has_main or verify_main) else None
        return IMPORTS + f"public class Main {{\n{indent(snippet, 4)}{main}\n}}\n", run
    # file: Top-Level-Typen dürfen nicht public sein, damit jeder Dateiname passt.
    source = re.sub(r"(?m)^public\s+(?=(final\s+|abstract\s+|sealed\s+)*(class|interface|record|enum)\b)", "", snippet)
    if verify_main:
        source += f"\n\nclass VerifyMain {{\n    public static void main(String[] args) throws Exception {{\n{indent(verify_main, 8)}\n    }}\n}}\n"
        return IMPORTS + source, "VerifyMain"
    if re.search(r"class\s+Main\b", source) and has_main:
        return IMPORTS + source, "Main"
    return IMPORTS + source, None


def run_case(case):
    name, snippet, context, verify_main, expected, must_compile = case
    source, run_class = build_source(snippet, context, verify_main)
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "Main.java")
        with open(path, "w", encoding="utf-8") as f:
            f.write(source)
        compiled = subprocess.run(["javac", "-encoding", "UTF-8", "-nowarn", "-d", tmp, path],
                                  capture_output=True, text=True)
        if compiled.returncode != 0:
            if must_compile:
                return name, False, "Kompilierfehler:\n" + compiled.stderr.strip() + "\n--- Quelltext ---\n" + source
            return name, True, "kompiliert erwartungsgemäß nicht"
        if not must_compile:
            return name, False, "sollte nicht kompilieren, tut es aber"
        if expected is None:
            return name, True, "kompiliert"
        if run_class is None:
            return name, False, "erwartete Ausgabe vorhanden, aber nichts ausführbar"
        result = subprocess.run(["java", "-Dstdout.encoding=UTF-8", "-cp", tmp, run_class],
                                capture_output=True, text=True, timeout=20, encoding="utf-8")
        actual = normalize_output(result.stdout)
        wanted = normalize_output(expected)
        if actual != wanted:
            return name, False, f"Ausgabe weicht ab\n  erwartet: {wanted}\n  erhalten: {actual}\n  stderr: {result.stderr.strip()[:300]}"
        return name, True, "Ausgabe stimmt"


def source(snippet):
    """Code-Felder sind entweder Text oder {"lines": [{"code": …, "explain": …}]}."""
    if isinstance(snippet, dict):
        return "\n".join(line["code"] for line in snippet["lines"])
    return snippet


def fill_template(task):
    text = source(task["template"])
    for index, blank in enumerate(task["blanks"]):
        text = text.replace("{{%d}}" % index, blank["accepted"][0])
    return text


def cases_for(task):
    verify = task.get("verify", {})
    if verify.get("skip"):
        return  # z. B. JUnit-Code: braucht eine Bibliothek, die ein reines JDK nicht mitbringt
    context = task.get("javaContext", "statements")
    main = verify.get("main")
    kind = task["type"]
    name = task["id"]
    if kind == "predictOutput":
        yield name, source(task["code"]), context, main, task["expectedOutput"], True
    elif kind == "code":
        expected = task.get("expectedOutput", verify.get("output"))
        yield name + " (Musterlösung)", source(task["sampleSolution"]), context, main, expected, True
        # Die gleichwertigen Lösungen sind die Behauptung, dass es auch anders geht.
        # Wenn sie nicht übersetzen oder etwas anderes ausgeben, ist die Behauptung falsch –
        # und die gelockerte Prüfregel dahinter genauso.
        for nummer, alternative in enumerate(task.get("_equivalents", []), start=1):
            yield f"{name} (gleichwertig {nummer})", alternative, context, main, expected, True
    elif kind == "fillBlank":
        yield name + " (ausgefüllt)", fill_template(task), context, main, verify.get("output"), True
    elif kind == "singleChoice" and task.get("code"):
        yield name + " (Code)", source(task["code"]), context, main, verify.get("output"), verify.get("compiles", True)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH
    with open(path, encoding="utf-8") as f:
        course = json.load(f)
    tasks = [t for m in course["modules"] for l in m["lessons"] for t in l["tasks"]]
    tasks += course.get("taskPool", [])  # Übungsaufgaben außerhalb der Lektionen
    tasks += [t for pool in course["placement"]["pools"].values() for t in pool]
    # Gleichwertige Lösungen an ihre Aufgabe hängen, damit sie mitgeprüft werden.
    gleichwertig = course.get("equivalentSolutions", {})
    for t in tasks:
        if t["id"] in gleichwertig:
            t["_equivalents"] = gleichwertig[t["id"]]
    cases = [case for task in tasks for case in cases_for(task)]
    # Theorie-Beispiele mit verify werden ebenfalls übersetzt und ausgeführt.
    for m in course["modules"]:
        for l in m["lessons"]:
            for index, card in enumerate(l["theory"]):
                v = card.get("verify")
                if v and card.get("code"):
                    cases.append((f"{l['id']} Theorie {index + 1}", source(card["code"]), v.get("context", "statements"),
                                  v.get("main"), v.get("output"), True))
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(run_case, cases))
    failures = [r for r in results if not r[1]]
    executed = sum(1 for r in results if r[2] == "Ausgabe stimmt")
    for name, ok, message in results:
        if not ok:
            print(f"FEHLER {name}: {message}\n")
    print(f"{len(tasks)} Aufgaben + Theorie-Beispiele, {len(cases)} Java-Prüfungen: {len(results) - len(failures)} ok "
          f"({executed} mit Ausgabevergleich), {len(failures)} fehlgeschlagen")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
