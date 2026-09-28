#!/usr/bin/env python3
"""
Spielt die fertige APK auf einem laufenden Emulator durch – so, wie ein Mensch tippt.

Installieren, starten, Onboarding als Anfänger, erste Lektion bis zur ersten Aufgabe,
Zurück-Taste, alle fünf Bereiche der unteren Leiste, dann Querformat. Nach jedem Schritt
wird geprüft, ob der erwartete Text auf dem Bildschirm steht, und am Ende, ob die App
irgendwann abgestürzt ist. Bildschirmfotos landen in einem Ordner (CI-Artefakt).

Gefunden werden Elemente über ihren Text in der Accessibility-Ansicht (uiautomator dump) –
genau das, was auch TalkBack sieht.

Aufruf: emulator_durchlauf.py <apk> <ordner-fuer-bilder>
"""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

PAKET = "io.github.niklas122212.javaquest"
ACTIVITY = f"{PAKET}/app.javaquest.android.MainActivity"


def adb(*args: str, check: bool = True, binaer: bool = False):
    ergebnis = subprocess.run(["adb", *args], capture_output=True, check=False)
    if check and ergebnis.returncode != 0:
        raise RuntimeError(f"adb {' '.join(args)} → {ergebnis.returncode}: {ergebnis.stderr.decode(errors='replace')}")
    return ergebnis.stdout if binaer else ergebnis.stdout.decode(errors="replace")


def bildschirm() -> ET.Element:
    """Die aktuelle Oberfläche als Baum. uiautomator braucht manchmal einen zweiten Anlauf."""
    for _ in range(8):
        adb("shell", "uiautomator", "dump", "/sdcard/ui.xml", check=False)
        roh = adb("shell", "cat", "/sdcard/ui.xml", check=False)
        if "<hierarchy" in roh:
            baum = ET.fromstring(roh[roh.index("<hierarchy"):])
            if not systemdialog_wegklicken(baum):
                return baum
        time.sleep(1)
    raise RuntimeError("uiautomator dump lieferte keine Oberfläche")


def systemdialog_wegklicken(baum: ET.Element) -> bool:
    """
    Auf CI-Emulatoren meldet sich gern eine System-App als hängend („Pixel Launcher isn't
    responding“) und legt ihren Dialog über alles. Das ist nicht JavaQuest – „Wait“ tippen
    und weitermachen. Stammt der Dialog von JavaQuest, ist das ein echter Fehler.
    """
    alles = " ".join(n.get("text") or "" for n in baum.iter("node"))
    if "isn't responding" not in alles and "reagiert nicht" not in alles:
        return False
    if "JavaQuest isn't responding" in alles or "JavaQuest reagiert nicht" in alles:
        raise AssertionError(f"JavaQuest reagiert nicht (ANR): {alles}")
    print(f"  (System-Dialog weggeklickt: {alles.strip()[:80]})")
    for knoten in baum.iter("node"):
        if (knoten.get("text") or "") in ("Wait", "Warten"):
            x1, y1, x2, y2 = map(int, re.findall(r"\d+", knoten.get("bounds")))
            adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
            time.sleep(1)
            return True
    adb("shell", "am", "broadcast", "-a", "android.intent.action.CLOSE_SYSTEM_DIALOGS", check=False)
    time.sleep(1)
    return True


def texte(baum: ET.Element) -> list[str]:
    return [n.get("text") or n.get("content-desc") or "" for n in baum.iter("node")]


def unten(knoten: ET.Element) -> int:
    return int(re.findall(r"\d+", knoten.get("bounds"))[3])


def finde(text: str, genau: bool = False, versuche: int = 15, unterster: bool = False) -> ET.Element:
    """Erstes Element mit diesem Text – oder mit unterster=True das am weitesten unten (Leiste)."""
    for _ in range(versuche):
        baum = bildschirm()
        treffer = []
        for knoten in baum.iter("node"):
            teile = [knoten.get("text") or "", knoten.get("content-desc") or ""]
            if (text in teile) if genau else any(text in t for t in teile):
                treffer.append(knoten)
        if treffer:
            return max(treffer, key=unten) if unterster else treffer[0]
        time.sleep(1)
    alles = "\n  ".join(t for t in texte(bildschirm()) if t)
    raise AssertionError(f"„{text}“ nicht auf dem Bildschirm. Sichtbar:\n  {alles}")


def tippe(text: str, genau: bool = False, unterster: bool = False) -> None:
    knoten = finde(text, genau, unterster=unterster)
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", knoten.get("bounds")))
    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
    time.sleep(1.2)


def wische_hoch() -> None:
    groesse = re.findall(r"(\d+)x(\d+)", adb("shell", "wm", "size"))[-1]
    breite, hoehe = int(groesse[0]), int(groesse[1])
    adb("shell", "input", "swipe", str(breite // 2), str(hoehe * 3 // 4), str(breite // 2), str(hoehe // 4), "300")
    time.sleep(0.8)


def lebt() -> bool:
    return adb("shell", "pidof", PAKET, check=False).strip() != ""


def main() -> int:
    apk, ordner = Path(sys.argv[1]), Path(sys.argv[2])
    ordner.mkdir(parents=True, exist_ok=True)
    nummer = 0

    def foto(name: str) -> None:
        nonlocal nummer
        nummer += 1
        (ordner / f"{nummer:02d}-{name}.png").write_bytes(adb("exec-out", "screencap", "-p", binaer=True))
        print(f"  Foto {nummer:02d}-{name}")

    def schritt(name: str) -> None:
        print(f"▸ {name}")
        if not lebt():
            raise AssertionError(f"App läuft nicht mehr (vor: {name})")

    # Nach dem Hochfahren arbeiten System-Apps noch eine Weile – erst dann starten.
    time.sleep(15)
    adb("shell", "am", "broadcast", "-a", "android.intent.action.CLOSE_SYSTEM_DIALOGS", check=False)
    adb("logcat", "-c")
    # Eine vorher installierte Debug-Fassung (instrumentierte Tests) trägt eine andere Signatur.
    adb("uninstall", PAKET, check=False)
    print(f"Installiere {apk.name} ({apk.stat().st_size // 1024} KB)")
    adb("install", "-r", "-g", str(apk))
    start = time.time()
    adb("shell", "am", "start", "-W", "-n", ACTIVITY)
    time.sleep(2)
    print(f"  läuft: {'ja' if lebt() else 'NEIN'}")

    schritt("Start: Kurs laden, Willkommen")
    finde("Level für Level", versuche=40)
    print(f"  Startbildschirm nach {time.time() - start:.1f} s")
    foto("willkommen")

    schritt("Onboarding: 0 Erfahrung")
    tippe("Los geht")
    tippe("Ich habe 0 Erfahrung")
    foto("erfahrung")
    tippe("Mit dem Grundkurs starten")

    schritt("Erste Lektion: Theorie")
    finde("Theorie-Happen 1/")
    foto("theorie")
    for _ in range(8):
        baum = bildschirm()
        if any("Zu den Aufgaben" in t for t in texte(baum)):
            break
        tippe("Weiter", genau=True)
    tippe("Zu den Aufgaben")

    schritt("Erste Aufgabe")
    finde("Prüfen", genau=True)
    foto("aufgabe")

    schritt("Zurück-Taste schließt die Lektion")
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(1.5)
    finde("Java Master Score")
    foto("uebersicht")
    wische_hoch()
    foto("uebersicht-unten")

    for bereich, erwartet in [
        ("Lernpfad", "Eine Lektion wird frei"),
        ("Themen", "Such dir aus, was du üben willst"),
        ("Analyse", "Wissensanalyse"),
        ("Profil", "Fortschritt sichern"),
    ]:
        schritt(f"Leiste unten: {bereich}")
        tippe(bereich, genau=True, unterster=True)
        finde(erwartet)
        foto(bereich.lower())

    schritt("Zurück-Taste führt zur Übersicht")
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(1.5)
    finde("Java Master Score")

    schritt("Querformat: Seitenleiste statt Leiste unten")
    adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
    adb("shell", "settings", "put", "system", "user_rotation", "1")
    time.sleep(3)
    finde("JavaQuest", genau=True)  # Kopf der Seitenleiste – den gibt es nur im breiten Aufbau
    foto("quer")
    adb("shell", "settings", "put", "system", "user_rotation", "0")
    time.sleep(2)

    schritt("Lernstand übersteht einen Neustart")
    adb("shell", "am", "force-stop", PAKET)
    adb("shell", "am", "start", "-W", "-n", ACTIVITY)
    finde("Java Master Score", versuche=40)

    abstuerze = adb("logcat", "-d", "-b", "crash")
    if PAKET in abstuerze or "FATAL EXCEPTION" in abstuerze:
        print(abstuerze)
        raise AssertionError("Die App ist abgestürzt (siehe oben)")
    zeilen = [z for z in adb("logcat", "-d", "-s", "JavaQuest").splitlines() if "Kurs geladen" in z]
    for z in zeilen:
        print(" ", z)
    print(f"✓ Durchlauf ohne Absturz – {nummer} Bildschirmfotos in {ordner}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as fehler:  # noqa: BLE001 – für die CI: Protokoll ausgeben, dann scheitern
        print(f"✗ {fehler}")
        print("--- Absturz-Puffer ---")
        print(adb("logcat", "-d", "-b", "crash", check=False)[-8000:])
        print("--- JavaQuest und Laufzeit ---")
        protokoll = adb("logcat", "-d", check=False).splitlines()
        wichtig = [z for z in protokoll if PAKET in z or " JavaQuest" in z or "AndroidRuntime" in z or " E " in z]
        print("\n".join(wichtig[-150:]))
        try:
            ordner = Path(sys.argv[2])
            ordner.mkdir(parents=True, exist_ok=True)
            (ordner / "99-fehler.png").write_bytes(adb("exec-out", "screencap", "-p", binaer=True))
        except Exception:  # noqa: BLE001
            pass
        sys.exit(1)
