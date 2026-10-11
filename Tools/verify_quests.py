#!/usr/bin/env python3
"""Prüft die Code-Quests mit einem echten JDK.

Für jede Quest aus Resources/code_quests.json:
  * Die Musterlösung übersetzt und besteht alle Tests – so, wie javac und java sie sehen.
  * Der Startcode übersetzt (Spieler beginnen nie mit einem Compilerfehler) und besteht nicht alles.

Die Tests laufen wie in der App: Vorbereitung, dann der Ausdruck; verglichen wird mit Typ
(assertEquals(true, …) ist nicht dasselbe wie assertEquals("true", …)).

    python3 Tools/verify_quests.py
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HIER = os.path.dirname(os.path.abspath(__file__))
QUESTS = os.path.join(HIER, "..", "Packages", "JavaQuestKit", "Sources", "JavaQuestKit", "Resources", "code_quests.json")
JAVA_OPTS = ["-Dstdout.encoding=UTF-8", "-Dfile.encoding=UTF-8"]


def java_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def harness(tests):
    """Testklasse: jeder Test in einer eigenen Methode, jedes Ergebnis als „T<n> <Typ> <Text>“."""
    methods, calls = [], []
    for n, t in enumerate(tests):
        if "expression" not in t:
            continue
        setup = "\n".join("        " + zeile for zeile in t.get("setup", "").splitlines())
        methods.append(f"""
    static void t{n}() {{
{setup}
        Object wert = {t['expression']};
        System.out.println("T{n} " + typ(wert) + " " + String.valueOf(wert).replace("\\n", "\\\\n"));
    }}""")
        calls.append(f"""
        try {{
            t{n}();
        }} catch (Throwable e) {{
            System.out.println("T{n} EXC " + e.getClass().getSimpleName());
        }}""")
    return f"""import java.util.*;

public class QuestCheck__ {{
    static String typ(Object wert) {{
        if (wert == null) return "null";
        if (wert instanceof Boolean) return "boolean";
        if (wert instanceof Integer || wert instanceof Long || wert instanceof Short || wert instanceof Byte) return "integer";
        if (wert instanceof Double || wert instanceof Float) return "double";
        if (wert instanceof String) return "string";
        return "other";
    }}
{''.join(methods)}

    public static void main(String[] args) {{{''.join(calls)}
    }}
}}
"""


def expected_line(n, expect):
    if "exception" in expect:
        return f"T{n} EXC {expect['exception']}"
    if "text" in expect:
        return (f"T{n} ", expect["text"])
    value = expect["value"]
    if value is None:
        return f"T{n} null null"
    if isinstance(value, bool):
        return f"T{n} boolean {'true' if value else 'false'}"
    if isinstance(value, int):
        return f"T{n} integer {value}"
    if isinstance(value, float):
        return f"T{n} double {value!r}"
    return f"T{n} string {value}"


def run(cmd, cwd, timeout=20):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)


def check(quest, code, workdir):
    """Liefert (übersetzt, Fehlschläge) für diesen Code."""
    shutil.rmtree(workdir, ignore_errors=True)
    os.makedirs(workdir)
    with open(os.path.join(workdir, quest["className"] + ".java"), "w", encoding="utf-8") as f:
        f.write(code + "\n")
    compiled = run(["javac", "-encoding", "UTF-8", "-Xlint:none", "-nowarn", quest["className"] + ".java"], workdir)
    if compiled.returncode != 0:
        return False, [compiled.stderr.strip()]

    failures = []
    tests = quest["tests"]
    # Tests, die nur die Ausgabe von main prüfen
    for t in tests:
        if "expression" in t:
            continue
        out = run(["java", *JAVA_OPTS, quest["className"]], workdir)
        actual = out.stdout.rstrip("\n")
        if actual != t["expect"]["output"]:
            failures.append(f"{t['name']}: Ausgabe {actual!r} statt {t['expect']['output']!r}")

    if any("expression" in t for t in tests):
        with open(os.path.join(workdir, "QuestCheck__.java"), "w", encoding="utf-8") as f:
            f.write(harness(tests))
        compiled = run(["javac", "-encoding", "UTF-8", "-nowarn", "-cp", ".", "QuestCheck__.java"], workdir)
        if compiled.returncode != 0:
            return True, failures + ["Tests übersetzen nicht: " + compiled.stderr.strip().splitlines()[0]]
        out = run(["java", *JAVA_OPTS, "-cp", ".", "QuestCheck__"], workdir)
        lines = {line.split(" ", 1)[0]: line for line in out.stdout.splitlines() if line.startswith("T")}
        for n, t in enumerate(tests):
            if "expression" not in t:
                continue
            got = lines.get(f"T{n}", f"T{n} (keine Ausgabe) {out.stderr.strip()[:200]}")
            want = expected_line(n, t["expect"])
            if isinstance(want, tuple):
                ok = got.split(" ", 2)[2:] == [want[1].replace("\n", "\\n")] if got.count(" ") >= 2 else False
                want = f"T{n} … {want[1]}"
            elif t["expect"].get("exception") in ("Exception", "RuntimeException"):
                ok = " EXC " in got
            else:
                ok = got == want
            if not ok:
                failures.append(f"{t['name']}: {got!r} statt {want!r}")
    return True, failures


def main():
    if not shutil.which("javac"):
        print("Kein JDK gefunden (javac fehlt).")
        return 2
    with open(QUESTS, encoding="utf-8") as f:
        book = json.load(f)
    errors = []
    with tempfile.TemporaryDirectory() as tmp:
        for quest in book["quests"]:
            work = os.path.join(tmp, quest["id"])
            compiled, failures = check(quest, quest["solution"], work)
            if not compiled or failures:
                errors.append(f"{quest['id']}: Musterlösung – " + "; ".join(failures))
            compiled, failures = check(quest, quest["starterCode"], work + "-start")
            # Fehlende Methoden lassen die Testklasse scheitern – das zählt als „nicht gelöst“.
            if not compiled:
                errors.append(f"{quest['id']}: Startcode übersetzt nicht – " + "; ".join(failures))
            elif not failures:
                errors.append(f"{quest['id']}: Startcode besteht schon alle Tests")
            print(f"  {'✓' if not any(e.startswith(quest['id'] + ':') for e in errors) else '✗'} {quest['id']}")
    tests = sum(len(q["tests"]) for q in book["quests"])
    if errors:
        print("\n".join(errors))
        return 1
    print(f"Alle {len(book['quests'])} Quests mit {tests} Tests bestehen auf dem echten JDK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
