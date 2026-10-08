/* XP, Level, Abzeichen und die Tagesmission – dieselben Regeln wie in der Apple-App
   (Packages/JavaQuestKit/Sources/JavaQuestKit/Progress/Gamification.swift) und unter Windows.

   Alles wird aus dem vorhandenen Stand abgeleitet, nichts zusätzlich gespeichert: aus dem
   Aufgaben-Protokoll (Missionen stehen dort mit Kontext „mission“ bzw. „daily“, credit =
   Sterne ÷ 3 – wie in den Apps), den Lektionsergebnissen und der längsten Tagesserie.

   Klassisches Browser-Skript; es legt nur `SpielKern` an. Die Prüfungen laden dieselbe
   Datei (tests/spiel.mjs). */
const SpielKern = (() => {
  "use strict";

  const PUNKTE = { missionsStern: 25, bossStern: 50, tagesmission: 50, lektion: 50 };
  const BESTANDEN_AB = 0.69;
  const ZWEI_STERNE_AB = BESTANDEN_AB + (1 - BESTANDEN_AB) / 2;
  /** So viele Lektionen hat der Kurs – Ziel des Abzeichens „Java Master“. Eine Prüfung hält die Zahl aktuell. */
  const KURS_LEKTIONEN = 35;

  const istAufgabe = (kontext) => kontext !== "mission" && kontext !== "daily";
  /** Sterne einer Mission (0–3) aus dem gespeicherten credit. */
  const sterneAus = (credit) => Math.round((Number(credit) || 0) * 3);
  /** Sterne → credit, wie ActivityRecord.credit(forStars:). */
  const gutschrift = (sterne) => Math.min(Math.max(sterne, 0), 3) / 3;
  /** Sterne einer Lektion wie Stars.forAccuracy. */
  const lektionsSterne = (quote) => (quote >= 0.999 ? 3 : quote >= ZWEI_STERNE_AB ? 2 : quote >= BESTANDEN_AB ? 1 : 0);

  /** Beginn des Tages in Ortszeit (Millisekunden). */
  function tagesbeginn(ms) {
    const d = new Date(ms);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  /**
   * Alles, was Abzeichen, XP und die Tagesmission brauchen.
   * - protokoll: [{ taskId, credit, tries, date, context }] (Web-Stand)
   * - lektionen: { id: { quote, bestanden, viaEinstufung } }
   * - aufgabe(id): { type, difficulty } für Kurs- und Bonus-Aufgaben, sonst null
   */
  function fakten({ kurs, katalog, protokoll, lektionen, laengsteSerie, aufgabe }) {
    const versuche = (protokoll || []).slice().sort((a, b) => a.date - b.date).map((p) => ({
      taskId: p.taskId,
      context: p.context || "training",
      credit: Number(p.credit) || 0,
      solved: (Number(p.credit) || 0) > 0,
      tries: p.tries || 1,
      date: p.date,
      difficulty: istAufgabe(p.context) ? (aufgabe(p.taskId) || {}).difficulty || 1 : (katalog.mission(p.taskId) || {}).difficulty || 1,
    }));
    const aufgabenVersuche = versuche.filter((v) => istAufgabe(v.context));
    const ergebnisse = lektionen || {};
    const alleLektionen = kurs.modules.flatMap((m) => m.lessons);

    function missionsSterne(vor = Infinity) {
      const beste = {};
      for (const v of versuche) {
        if (istAufgabe(v.context) || !v.solved || !(v.date < vor)) continue;
        beste[v.taskId] = Math.max(beste[v.taskId] || 0, sterneAus(v.credit));
      }
      return beste;
    }

    const bestanden = new Set(Object.keys(ergebnisse).filter((id) => ergebnisse[id].bestanden));
    const verdient = new Set(Object.keys(ergebnisse).filter((id) => ergebnisse[id].bestanden && !ergebnisse[id].viaEinstufung));

    /** Längste Folge von Aufgaben, die beim ersten Versuch saßen (über Lektionen hinweg). */
    let besteCombo = 0;
    let combo = 0;
    for (const v of aufgabenVersuche) {
      if (v.context === "placement") continue;
      combo = v.solved && v.tries === 1 ? combo + 1 : 0;
      besteCombo = Math.max(besteCombo, combo);
    }

    const tagesErfolge = new Set(versuche.filter((v) => v.context === "daily" && v.solved).map((v) => tagesbeginn(v.date))).size;

    const f = {
      kurs, katalog, versuche, aufgabenVersuche, ergebnisse, alleLektionen,
      laengsteSerie: laengsteSerie || 0,
      missionsSterne,
      sterne: missionsSterne(),
      bestanden, verdient, besteCombo, tagesErfolge,
      geloestVomTyp: (typ) => new Set(aufgabenVersuche.filter((v) => v.solved && (aufgabe(v.taskId) || {}).type === typ).map((v) => v.taskId)).size,
      /** Die Tagesmission, die an diesem Tag geschafft wurde. */
      tagesmissionGeschafft(tag) {
        const beginn = tagesbeginn(tag);
        const treffer = versuche.filter((v) => v.context === "daily" && v.solved && tagesbeginn(v.date) === beginn);
        return treffer.length ? treffer[treffer.length - 1].taskId : null;
      },
    };
    f.xp = erfahrung(f);
    return f;
  }

  // MARK: - XP und Level

  function punkteFuerAufgabe(v) {
    if (!v.solved) return 2;
    return v.tries === 1 ? 10 * v.difficulty : 5 * v.difficulty;
  }

  /** Erfahrungspunkte: Jede Aufgabe, jede Mission und jeder Tageserfolg bringt XP – anders als der Score wächst XP immer weiter. */
  function erfahrung(f) {
    const aufgaben = f.aufgabenVersuche.reduce((s, v) => s + punkteFuerAufgabe(v), 0);
    const missionen = Object.entries(f.sterne).reduce((s, [id, n]) => {
      const boss = (f.katalog.mission(id) || {}).kind === "boss";
      return s + n * (boss ? PUNKTE.bossStern : PUNKTE.missionsStern);
    }, 0);
    return aufgaben + missionen + f.tagesErfolge * PUNKTE.tagesmission + f.verdient.size * PUNKTE.lektion;
  }

  /** XP, die man insgesamt braucht, um ein Level zu erreichen (Level 1 ab 0 XP): 100, 300, 600 … */
  function schwelle(level) {
    const n = Math.max(level - 1, 0);
    return 50 * n * (n + 1);
  }

  function level(xp) {
    let stufe = 1;
    while (schwelle(stufe + 1) <= xp) stufe += 1;
    const start = schwelle(stufe), ende = schwelle(stufe + 1);
    return { level: stufe, xp, start, ende, anteil: (xp - start) / Math.max(ende - start, 1), rest: ende - xp };
  }

  // MARK: - Abzeichen

  const bossAnzahl = (f) => Object.keys(f.sterne).filter((id) => (f.katalog.mission(id) || {}).kind === "boss").length;

  const ABZEICHEN = [
    { id: "first-task", titel: "Hallo, Welt!", text: "Löse deine erste Aufgabe.", symbol: "👋", ziel: 1,
      mass: (f) => new Set(f.aufgabenVersuche.filter((v) => v.solved && v.context !== "placement").map((v) => v.taskId)).size },
    { id: "first-lesson", titel: "Durchstarter", text: "Schließe deine erste Lektion ab.", symbol: "🏁", ziel: 1, mass: (f) => f.verdient.size },
    { id: "perfect", titel: "Fehlerfrei", text: "Hol in einer Lektion alle 3 Sterne.", symbol: "🌟", ziel: 1,
      mass: (f) => Object.values(f.ergebnisse).filter((e) => e.bestanden && !e.viaEinstufung && lektionsSterne(e.quote || 0) === 3).length },
    { id: "combo-5", titel: "Combo ×5", text: "Löse 5 Aufgaben in Folge beim ersten Versuch.", symbol: "⚡", ziel: 5, mass: (f) => f.besteCombo },
    { id: "combo-10", titel: "Unaufhaltsam", text: "Löse 10 Aufgaben in Folge beim ersten Versuch.", symbol: "⚡", ziel: 10, mass: (f) => f.besteCombo },
    { id: "streak-3", titel: "Dranbleiber", text: "Lerne 3 Tage in Folge.", symbol: "🔥", ziel: 3, mass: (f) => f.laengsteSerie },
    { id: "streak-7", titel: "Wochenkrieger", text: "Lerne 7 Tage in Folge.", symbol: "🔥", ziel: 7, mass: (f) => f.laengsteSerie },
    { id: "coder", titel: "Selbst geschrieben", text: "Löse 5 Aufgaben, in denen du eigenen Code schreibst.", symbol: "💻", ziel: 5, mass: (f) => f.geloestVomTyp("code") },
    { id: "bug-hunter", titel: "Bug-Jäger", text: "Finde den Fehler in 5 Bug-Jagden.", symbol: "🐞", ziel: 5, mass: (f) => f.geloestVomTyp("findBug") },
    { id: "puzzler", titel: "Puzzle-Profi", text: "Löse 5 Code-Puzzles.", symbol: "🧩", ziel: 5, mass: (f) => f.geloestVomTyp("ordering") },
    { id: "first-mission", titel: "Roboter-Pilot", text: "Schaffe deine erste Arena-Mission.", symbol: "🎮", ziel: 1, mass: (f) => Object.keys(f.sterne).length },
    { id: "star-collector", titel: "Sternensammler", text: "Sammle 15 Sterne in der Arena.", symbol: "✨", ziel: 15,
      mass: (f) => Object.values(f.sterne).reduce((a, b) => a + b, 0) },
    { id: "boss", titel: "Bossbezwinger", text: "Besiege ein Boss-Level.", symbol: "🛡️", ziel: 1, mass: bossAnzahl },
    { id: "all-bosses", titel: "Endgegner", text: "Besiege alle Boss-Level.", symbol: "👑", ziel: 3, mass: bossAnzahl },
    { id: "daily-3", titel: "Tagesheld", text: "Schaffe 3 tägliche Missionen.", symbol: "☀️", ziel: 3, mass: (f) => f.tagesErfolge },
    { id: "training-10", titel: "Wiederholungstäter", text: "Löse 10 Aufgaben im Training oder in der Wiederholung.", symbol: "🔁", ziel: 10,
      mass: (f) => f.aufgabenVersuche.filter((v) => v.context === "training" && v.solved).length },
    { id: "module-1", titel: "Grundlagen sitzen", text: "Schließe Modul 1 ab.", symbol: "1️⃣", ziel: 1,
      mass: (f) => { const ls = f.kurs.modules[0] ? f.kurs.modules[0].lessons : []; return ls.length && ls.every((l) => f.bestanden.has(l.id)) ? 1 : 0; } },
    { id: "level-5", titel: "Aufsteiger", text: "Erreiche Level 5.", symbol: "📈", ziel: 5, mass: (f) => level(f.xp).level },
    { id: "course", titel: "Java Master", text: "Schließe alle Lektionen ab.", symbol: "🏆", ziel: KURS_LEKTIONEN,
      mass: (f) => f.alleLektionen.filter((l) => f.bestanden.has(l.id)).length },
  ];

  const aktuell = (abzeichen, f) => Math.min(abzeichen.mass(f), abzeichen.ziel);
  const freigeschaltet = (f) => new Set(ABZEICHEN.filter((a) => a.mass(f) >= a.ziel).map((a) => a.id));

  // MARK: - Tagesmission

  /** Spielbar wie LessonState.isPlayable: bestanden oder die erste noch offene Lektion. */
  function spielbareLektionen(kurs, ergebnisse) {
    const spielbar = new Set();
    let aktuelleGefunden = false;
    for (const l of kurs.modules.flatMap((m) => m.lessons)) {
      if (ergebnisse[l.id] && ergebnisse[l.id].bestanden) spielbar.add(l.id);
      else if (!aktuelleGefunden) { spielbar.add(l.id); aktuelleGefunden = true; }
    }
    return spielbar;
  }

  /** Missionen, die man spielen darf: Lektion erreicht (Lektion), bestanden (Training) bzw. Modul geschafft (Boss). */
  function freigeschalteteMission(mission, kurs, ergebnisse, spielbar = spielbareLektionen(kurs, ergebnisse)) {
    switch (mission.kind) {
      case "lesson": return spielbar.has(mission.lessonId);
      case "training": return !!(ergebnisse[mission.lessonId] && ergebnisse[mission.lessonId].bestanden);
      default: {
        const modul = kurs.modules.find((m) => m.id === mission.moduleId);
        return !!modul && modul.lessons.every((l) => ergebnisse[l.id] && ergebnisse[l.id].bestanden);
      }
    }
  }

  function verfuegbareMissionen(katalog, kurs, ergebnisse) {
    const spielbar = spielbareLektionen(kurs, ergebnisse);
    return katalog.missions.filter((m) => freigeschalteteMission(m, kurs, ergebnisse, spielbar));
  }

  /** Tagesnummer wie in der Apple-App (Sekunden seit 2001-01-01 bis Mitternacht Ortszeit, durch 86 400) –
      so ist es auf allen Geräten am selben Tag dieselbe Mission. */
  function tagesnummer(tag) {
    return Math.trunc((tagesbeginn(tag) / 1000 - 978307200) / 86400);
  }

  /** Die Mission des Tages: fest je Kalendertag, bevorzugt Trainingsmissionen und solche ohne alle Sterne. */
  function missionFuerTag(tag, verfuegbar, sterne) {
    if (!verfuegbar.length) return null;
    const offen = verfuegbar.filter((m) => (sterne[m.id] || 0) < 3);
    const topf = (offen.length ? offen : verfuegbar).slice().sort((a, b) => {
      const x = a.kind === "training" ? 0 : 1, y = b.kind === "training" ? 0 : 1;
      if (x !== y) return x - y;
      return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    });
    const n = tagesnummer(tag);
    return topf[((n % topf.length) + topf.length) % topf.length];
  }

  /** Die Tagesmission – stabil vom Morgen bis zum Abend, auch wenn zwischendurch Sterne dazukommen. */
  function tagesmission(f, tag) {
    const geschafft = f.tagesmissionGeschafft(tag);
    if (geschafft && f.katalog.mission(geschafft)) return f.katalog.mission(geschafft);
    return missionFuerTag(tag, verfuegbareMissionen(f.katalog, f.kurs, f.ergebnisse), f.missionsSterne(tagesbeginn(tag)));
  }

  // MARK: - Belohnung

  /** Was sich zwischen zwei Ständen getan hat: XP, Levelaufstieg, neue Abzeichen. */
  function gewinn(vorher, nachher) {
    const alt = freigeschaltet(vorher), neu = freigeschaltet(nachher);
    const levelAlt = level(vorher.xp).level, levelNeu = level(nachher.xp).level;
    return {
      xp: nachher.xp - vorher.xp,
      levelAuf: levelNeu > levelAlt ? levelNeu : null,
      abzeichen: ABZEICHEN.filter((a) => neu.has(a.id) && !alt.has(a.id)),
    };
  }

  return {
    PUNKTE, KURS_LEKTIONEN, ABZEICHEN,
    fakten, level, schwelle, aktuell, freigeschaltet, gewinn,
    tagesmission, missionFuerTag, verfuegbareMissionen, freigeschalteteMission, tagesbeginn, tagesnummer,
    istAufgabe, sterneAus, gutschrift,
  };
})();
