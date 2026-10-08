/* Prüfungen für XP, Level, Abzeichen und Tagesmission der Web-Fassung (Web/spiel.js) –
 * dieselben Fälle wie GamificationTests.swift.
 */
import { alleAufgaben } from "./laden.mjs";

/** Wertet java.js, arena.js und spiel.js aus und gibt `{ Java, Arena, Spiel }` zurück. */
export function ladeSpiel(javaQuelltext, arenaQuelltext, spielQuelltext) {
  return new Function(`${javaQuelltext}\n${arenaQuelltext}\n${spielQuelltext}\nreturn { Java: JavaKern, Arena: ArenaKern, Spiel: SpielKern };`)();
}

const ok = (name) => ({ name, ok: true });
const fehler = (name, hinweis) => ({ name, ok: false, hinweis });
const pruefe = (name, bedingung, hinweis) => (bedingung ? ok(name) : fehler(name, hinweis));

export function spielPruefungen({ Arena, Spiel }, kurs, missionen, bonus) {
  const ergebnisse = [];
  const katalog = Arena.catalog(missionen);
  const aufgaben = new Map(alleAufgaben(kurs).map((a) => [a.id, a]));
  for (const liste of Object.values((bonus && bonus.lessons) || {})) for (const a of liste) aufgaben.set(a.id, a);
  const aufgabe = (id) => aufgaben.get(id) || null;
  const lektionen = kurs.modules.flatMap((m) => m.lessons);
  const tag = new Date(2026, 2, 10, 12).getTime();
  const versuch = (taskId, context = "lesson", { credit = 1, tries = 1, tageZurueck = 0, datum = null } = {}) =>
    ({ taskId, context, credit, tries, date: datum != null ? datum : tag - tageZurueck * 86400000 });
  const fakten = (protokoll, ergebnisse = {}, serie = 0) =>
    Spiel.fakten({ kurs, katalog, protokoll, lektionen: ergebnisse, laengsteSerie: serie, aufgabe });
  const bestanden = (anzahl) => Object.fromEntries(lektionen.slice(0, anzahl).map((l) => [l.id, { quote: 1, bestanden: true }]));

  {
    // t01-1 (Niveau 1): 10 · t01-3 (Niveau 2) im 2. Versuch: 10 · t01-4 ungelöst: 2 · Mission 3 Sterne: 75 · Boss 1 Stern: 50
    const xp = fakten([
      versuch("t01-1"), versuch("t01-3", "lesson", { tries: 2, credit: 0.5 }), versuch("t01-4", "lesson", { credit: 0, tries: 3 }),
      versuch("a01-erste-schritte", "mission", { credit: Spiel.gutschrift(2) }),
      versuch("a01-erste-schritte", "mission", { credit: Spiel.gutschrift(3) }),
      versuch("b1-tunnelschatz", "mission", { credit: Spiel.gutschrift(1) }),
    ]).xp;
    const erwartet = 10 * aufgabe("t01-1").difficulty + 5 * aufgabe("t01-3").difficulty + 2 + 75 + 50;
    ergebnisse.push(pruefe("Spiel: XP – erster Versuch zählt doppelt, Missionen nach Bestwert, Boss-Sterne mehr", xp === erwartet, `${xp} statt ${erwartet}`));
  }
  {
    const l = Spiel.level(200);
    ergebnisse.push(pruefe(
      "Spiel: Level-Kurve 100, 300, 600 … XP",
      Spiel.level(0).level === 1 && Spiel.level(99).level === 1 && Spiel.level(100).level === 2 && Spiel.level(300).level === 3
        && l.level === 2 && l.anteil === 0.5 && l.rest === 100,
      JSON.stringify(l),
    ));
  }
  {
    const combo = fakten([1, 2, 3, 4, 5].map((n) => versuch(`t0${n}-1`)));
    const unterbrochen = fakten([versuch("t01-1"), versuch("t01-2"), versuch("t01-3", "lesson", { tries: 2, credit: 0.5 }), versuch("t01-4"), versuch("t01-5")]);
    const boss = fakten([versuch("b2-labyrinth", "mission", { credit: Spiel.gutschrift(1) })]);
    const frei = (f) => Spiel.freigeschaltet(f);
    ergebnisse.push(pruefe(
      "Spiel: Abzeichen Combo, Boss, Roboter-Pilot – 19 verschiedene",
      frei(combo).has("combo-5") && !frei(combo).has("combo-10") && unterbrochen.besteCombo === 2
        && frei(boss).has("boss") && frei(boss).has("first-mission") && !frei(boss).has("all-bosses")
        && new Set(Spiel.ABZEICHEN.map((a) => a.id)).size === 19,
      `Combo: ${[...frei(combo)]}, Boss: ${[...frei(boss)]}`,
    ));
  }
  if (bonus) {
    const jagden = Object.values(bonus.lessons).flat().filter((a) => a.type === "findBug").slice(0, 5).map((a) => versuch(a.id));
    ergebnisse.push(pruefe("Spiel: Abzeichen Bug-Jäger nach 5 Bug-Jagden", Spiel.freigeschaltet(fakten(jagden)).has("bug-hunter"), String(jagden.length)));
  }
  {
    const fast = Object.fromEntries(lektionen.slice(0, -1).map((l) => [l.id, { quote: 1, bestanden: true }]));
    const alle = { ...fast, [lektionen[lektionen.length - 1].id]: { quote: 1, bestanden: true } };
    ergebnisse.push(pruefe(
      `Spiel: „Java Master“ erst nach allen ${lektionen.length} Lektionen`,
      Spiel.KURS_LEKTIONEN === lektionen.length && !Spiel.freigeschaltet(fakten([], fast)).has("course") && Spiel.freigeschaltet(fakten([], alle)).has("course"),
      `KURS_LEKTIONEN = ${Spiel.KURS_LEKTIONEN}, Kurs: ${lektionen.length}`,
    ));
  }
  {
    const frisch = Spiel.verfuegbareMissionen(katalog, kurs, {});
    const sechs = bestanden(6);
    const verfuegbar = Spiel.verfuegbareMissionen(katalog, kurs, sechs);
    const erste = Spiel.missionFuerTag(tag, verfuegbar, {});
    const spaeter = Spiel.missionFuerTag(tag + 3600000, verfuegbar, {});
    const alleDrei = Object.fromEntries(verfuegbar.filter((m) => m.id !== "t1-countdown").map((m) => [m.id, 3]));
    ergebnisse.push(pruefe(
      "Spiel: Tagesmission – fest pro Tag, nur Freigeschaltetes, Unfertiges zuerst",
      frisch.map((m) => m.id).join() === "a01-erste-schritte"
        && verfuegbar.some((m) => m.id === "b2-labyrinth") && !verfuegbar.some((m) => m.id === "b3-codeknacker")
        && erste && spaeter && erste.id === spaeter.id && Spiel.missionFuerTag(tag, verfuegbar, alleDrei).id === "t1-countdown",
      `frisch: ${frisch.map((m) => m.id)}, erste: ${erste && erste.id}`,
    ));
  }
  {
    const sechs = bestanden(6);
    const morgen = new Date(2026, 2, 10, 8).getTime();
    const mittag = morgen + 4 * 3600000;
    const tages = Spiel.tagesmission(fakten([], sechs), morgen);
    const gespielt = versuch(tages.id, "mission", { datum: mittag });
    const geschafft = versuch(tages.id, "daily", { datum: mittag });
    const fertig = fakten([gespielt, geschafft], sechs);
    ergebnisse.push(pruefe(
      "Spiel: Neue Sterne am selben Tag ändern die Tagesmission nicht, die geschaffte bleibt sichtbar",
      Spiel.tagesmission(fakten([gespielt], sechs), mittag).id === tages.id
        && fertig.tagesmissionGeschafft(mittag) === tages.id && Spiel.tagesmission(fertig, mittag).id === tages.id,
      tages.id,
    ));
  }
  {
    // Gleiche Rechnung wie in der Apple-App: Mitternacht Ortszeit seit dem 1. 1. 2001, ganze Tage.
    const n = Spiel.tagesnummer(new Date(2026, 2, 10, 12).getTime());
    const erwartet = Math.trunc((new Date(2026, 2, 10).getTime() / 1000 - 978307200) / 86400);
    ergebnisse.push(pruefe("Spiel: Tagesnummer wie in der Apple-App", n === erwartet && n > 9000, `${n}`));
  }
  return ergebnisse;
}
