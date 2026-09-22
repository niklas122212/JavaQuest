"""Bausteine zum Schreiben von Kursinhalten (Aufgaben, Theorie-Karten, Lektionen)."""
import hashlib
import json
import sys
from textwrap import dedent


def c(text):
    return dedent(text).strip("\n")


def rotate(choices, key):
    """Deterministische Permutation: richtige Antwort steht nicht immer vorne."""
    shift = int(hashlib.sha1(key.encode()).hexdigest(), 16) % len(choices)
    rotated = choices[shift:] + choices[:shift]
    return rotated, rotated.index(choices[0])


def base(id, type, topic, d, prompt, explanation, hint=None, code=None, ctx=None, verify=None, group=None, diagram=None):
    t = {"id": id, "type": type, "topicId": topic, "difficulty": d, "prompt": prompt}
    if diagram:
        t["diagram"] = diagram
    if group:
        # Aufgaben derselben Gruppe fragen dasselbe Lernziel ab; pro Sitzung kommt eine davon dran.
        t["variantGroup"] = group
    if code:
        t["code"] = c(code)
    if hint:
        t["hint"] = hint
    t["explanation"] = explanation
    if ctx:
        t["javaContext"] = ctx
    if verify:
        t["verify"] = {k: (c(v) if isinstance(v, str) else v) for k, v in verify.items()}
    return t


def mc(id, topic, d, prompt, choices, explanation, why=None, **kw):
    """choices[0] ist die richtige Antwort.

    why (optional): Begründungen in derselben Reihenfolge wie choices – also why[0]
    zur richtigen Antwort (bleibt ungenutzt, üblicherweise None). Sie werden mit den
    Antworten mitgedreht und erscheinen, wenn jemand genau diese Antwort wählt.
    """
    t = base(id, "singleChoice", topic, d, prompt, explanation, **kw)
    t["choices"], t["correctIndex"] = rotate(choices, id)
    if why:
        assert len(why) == len(choices), f"{id}: {len(why)} Begründungen für {len(choices)} Antworten"
        t["whyWrong"], _ = rotate(why, id)
        t["whyWrong"][t["correctIndex"]] = None
    return t


def fill(id, topic, d, prompt, template, blanks, explanation, **kw):
    t = base(id, "fillBlank", topic, d, prompt, explanation, **kw)
    t["template"] = c(template)
    t["blanks"] = [{"accepted": b} if isinstance(b, list) else b for b in blanks]
    return t


def out(id, topic, d, prompt, code, expected, explanation, also=None, **kw):
    t = base(id, "predictOutput", topic, d, prompt, explanation, code=code, **kw)
    t["expectedOutput"] = c(expected)
    if also:
        t["alsoAccepted"] = also
    return t


def code(id, topic, d, prompt, starter, solution, rules, explanation, expected=None, structure=None, **kw):
    t = base(id, "code", topic, d, prompt, explanation, **kw)
    t["starterCode"] = c(starter) + "\n"
    t["sampleSolution"] = c(solution)
    if expected:
        t["expectedOutput"] = c(expected)
    t["rules"] = rules
    if structure is not None:
        t["structure"] = structure
    return t


def req(pattern, message, scope=None):
    r = {"rule": "require", "pattern": pattern, "message": message}
    if scope:
        r["scope"] = scope
    return r


def forbid(pattern, message, scope=None):
    r = {"rule": "forbid", "pattern": pattern, "message": message}
    if scope:
        r["scope"] = scope
    return r


def card(title, body, code=None, tip=None, warning=None, info=None, verify=None, diagram=None):
    """verify (optional): {"context": statements|members|file, "main": …, "output": …} – prüft das Beispiel mit javac/java."""
    k = {"title": title, "body": body}
    if code:
        k["code"] = c(code)
    if diagram:
        k["diagram"] = diagram
    if verify:
        k["verify"] = {key: (c(v) if isinstance(v, str) else v) for key, v in verify.items()}
    for kind, text in (("tip", tip), ("warning", warning), ("info", info)):
        if text:
            k["callout"] = {"kind": kind, "text": text}
    return k


def lesson(id, title, summary, topics, minutes, theory, tasks):
    return {"id": id, "title": title, "summary": summary, "topicIds": topics,
            "estimatedMinutes": minutes, "theory": theory, "tasks": tasks}


