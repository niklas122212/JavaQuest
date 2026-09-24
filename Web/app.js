/* JavaQuest als Web-App.
 *
 * Gleiche Inhalte und gleiche Regeln wie die iPhone- und Windows-Fassung:
 * dieselbe Kursdatei, dieselbe Bestehensgrenze (69 %), dieselbe Auswahl der
 * Aufgaben-Varianten. Der Fortschritt bleibt im Browser des Geräts.
 */
"use strict";

const BESTANDEN_AB = 0.69;   // wie LessonSession.passThreshold
const MAX_VERSUCHE = 3;
const RUNDE = 8;

let kurs = null;
let stand = laden();
let ansicht = { name: "start" };
let sitzung = null;

// ---------------------------------------------------------------- Fortschritt
function laden() {
  try {
    const roh = localStorage.getItem("javaquest");
    if (roh) return JSON.parse(roh);
  } catch (e) { /* privater Modus o. Ä.: dann eben ohne gespeicherten Stand */ }
  return leererStand();
}

function leererStand() {
  return { lektionen: {}, verlauf: {}, themen: {}, ziele: {}, serie: null, profil: null, protokoll: [] };
}

/* Ältere gespeicherte Stände kennen „ziele“ und „protokoll“ noch nicht. Sie werden nicht
   ersetzt, sondern nur ergänzt – der bisherige Fortschritt bleibt vollständig erhalten. */
if (!stand.ziele) stand.ziele = {};
if (!Array.isArray(stand.protokoll)) stand.protokoll = [];
/* Ebenso beim Einstieg: Wer die App schon benutzt hat, wird nicht nachträglich befragt.
   Vorhandener Fortschritt gilt als Beleg dafür, dass der Einstieg längst hinter einem liegt. */
if (!stand.start && (Object.keys(stand.verlauf).length || Object.keys(stand.lektionen).length)) {
  stand.start = { fertig: true };
}

function sichern() {
  try {
    localStorage.setItem("javaquest", JSON.stringify(stand));
  } catch (e) { /* Speicher voll oder gesperrt – die Sitzung läuft trotzdem weiter */ }
}

/** Merkt sich, wie eine Aufgabe ausging – Grundlage für Varianten und Schwächen. */
function merkeAufgabe(aufgabe, wertung, versuche, kontext) {
  const datum = Date.now();
  bucheAntwort(stand, aufgabe, wertung, datum);
  // Jede einzelne Antwort, wie in den Apps. Nur damit lässt sich der Stand verlustfrei
  // in die Mac-, iPhone- und Windows-App mitnehmen (siehe „Austausch mit den Apps“).
  stand.protokoll.push({ taskId: aufgabe.id, credit: wertung, tries: versuche || 1, date: datum, context: kontext });
  merkeAktivitaet();
  sichern();
}

/** Verbucht eine Antwort in Verlauf, Lernziel und Thema – beim Üben wie beim Übernehmen aus einer App. */
function bucheAntwort(s, aufgabe, wertung, datum) {
  const alt = s.verlauf[aufgabe.id];
  s.verlauf[aufgabe.id] = {
    versuche: (alt ? alt.versuche : 0) + 1,
    wertung,
    datum,
  };
  // Die Wiedervorlage rechnet je Lernziel, nicht je Aufgabe: Wer dasselbe Lernziel dreimal
  // mit drei Varianten getroffen hat, hat es verstanden – und nicht eine Frage auswendig gelernt.
  const schluessel = gruppe(aufgabe);
  const ziel = s.ziele[schluessel] || { versuche: 0, serie: 0 };
  s.ziele[schluessel] = {
    versuche: ziel.versuche + 1,
    serie: wertung >= 1 ? ziel.serie + 1 : 0,
    wertung,
    datum,
  };
  const thema = s.themen[aufgabe.topicId] || { gesehen: 0, richtig: 0, gewichtet: 0, gesamt: 0 };
  thema.gesehen += 1;
  if (wertung >= 1) thema.richtig += 1;
  thema.gewichtet += aufgabe.difficulty * wertung;
  thema.gesamt += aufgabe.difficulty;
  s.themen[aufgabe.topicId] = thema;
}

function beherrschung(themaId) {
  const t = stand.themen[themaId];
  if (!t || t.gesamt === 0) return null;
  return (t.gewichtet + 1) / (t.gesamt + 2);   // Laplace-geglättet wie im Kern
}

/* ---------------------------------------------------------------- Verteiltes Wiederholen
   Karteikasten-Prinzip, dieselben Werte wie in der iPhone- und Windows-Fassung:
   Was dreimal hintereinander saß, kommt nicht morgen wieder dran, sondern in einer Woche –
   bevor es verblasst. Ein Fehler wirft das Lernziel sofort ganz nach vorn zurück. */
const PAUSEN = [0, 1, 3, 7, 16, 35];   // Tage je Fach
const MINDESTFAKTOR = 0.25;

const fach = (ziel) => Math.min(ziel.serie || 0, PAUSEN.length - 1);
const pause = (ziel) => PAUSEN[fach(ziel)];
const faellig = (ziel, jetzt) => (jetzt - ziel.datum) / 86400000 >= pause(ziel);

/** Faktor fürs Gewicht: gedämpft vor dem Termin, angehoben danach. */
function wiedervorlage(schluessel, jetzt) {
  const ziel = stand.ziele[schluessel];
  if (!ziel || !ziel.serie) return 1;
  const p = pause(ziel);
  if (p <= 0) return 1;
  const vergangen = Math.max((jetzt - ziel.datum) / 86400000, 0);
  if (vergangen >= p) return 1 + Math.min((vergangen - p) / p, 1);
  return MINDESTFAKTOR + (1 - MINDESTFAKTOR) * (vergangen / p);
}

/** Die Lernziele, deren Pause abgelaufen ist. */
function faelligeZiele(jetzt) {
  return Object.keys(stand.ziele).filter((k) => faellig(stand.ziele[k], jetzt));
}

/* ---------------------------------------------------------------- Erinnerung
   Das verteilte Wiederholen wirkt nur, wenn man im richtigen Abstand zurückkommt – und
   daran hat lange nichts erinnert. Die Apple-App meldet sich selbst; eine Web-App kann
   das ohne eigenen Server nicht. Deshalb gibt es hier einen Kalendereintrag für die
   nächste Wiederholung, samt Alarm. Dieselbe Rechnung wie ReviewReminder.plan in der
   Apple-App: nur Tage, an denen zur Uhrzeit wirklich etwas fällig ist. */
const ERINNERUNG_MINUTEN = 18 * 60;

/** Wann jedes Lernziel wieder dran ist (Millisekunden). */
function faelligkeiten() {
  return Object.values(stand.ziele).map((z) => z.datum + pause(z) * 86400000);
}

/** Die nächsten Termine zur Uhrzeit (Ortszeit), an denen etwas fällig ist. */
function erinnerungsTermine(faelligAb, jetzt, minuten = ERINNERUNG_MINUTEN, hoechstens = 3) {
  if (!faelligAb.length) return [];
  const tag = new Date(Math.max(jetzt, Math.min(...faelligAb)));
  tag.setHours(0, 0, 0, 0);
  const termine = [];
  for (let i = 0; i < hoechstens + 2 && termine.length < hoechstens; i++) {
    const zeit = new Date(tag);
    zeit.setHours(Math.floor(minuten / 60), minuten % 60, 0, 0);
    if (zeit.getTime() > jetzt) {
      const anzahl = faelligAb.filter((f) => f <= zeit.getTime()).length;
      if (anzahl) termine.push({ datum: zeit.getTime(), anzahl });
    }
    tag.setDate(tag.getDate() + 1);
  }
  return termine;
}

/** Text für Kalenderfelder: Backslash, Semikolon, Komma und Zeilenumbruch maskiert (RFC 5545). */
const kalenderText = (t) => String(t).replace(/[\\;,]/g, (z) => `\\${z}`).replace(/\n/g, "\\n");

/** Zeilen über 75 Byte werden umbrochen; die Fortsetzung beginnt mit einem Leerzeichen. */
function kalenderZeile(zeile) {
  const teile = [];
  let aktuell = "", laenge = 0;
  for (const zeichen of zeile) {
    const c = zeichen.codePointAt(0);
    const bytes = c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4;
    if (laenge + bytes > (teile.length ? 74 : 75)) { teile.push(aktuell); aktuell = ""; laenge = 0; }
    aktuell += zeichen;
    laenge += bytes;
  }
  teile.push(aktuell);
  return teile.join("\r\n ");
}

/** Ein Kalendereintrag mit Alarm für einen Termin – in Ortszeit, wie ein Wecker. */
function kalenderEintrag(termin, jetzt) {
  const zwei = (n) => String(n).padStart(2, "0");
  const d = new Date(termin.datum);
  const beginn = `${d.getFullYear()}${zwei(d.getMonth() + 1)}${zwei(d.getDate())}T${zwei(d.getHours())}${zwei(d.getMinutes())}00`;
  const ziele = termin.anzahl === 1 ? "1 Lernziel" : `${termin.anzahl} Lernziele`;
  const adresse = "https://niklas122212.github.io/JavaQuest/";
  const warten = termin.anzahl === 1 ? "wartet" : "warten";
  return [
    "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//JavaQuest//Wiederholung//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
    "BEGIN:VEVENT",
    `UID:javaquest-wiederholung-${beginn}@niklas122212.github.io`,
    `DTSTAMP:${isoZeit(jetzt).replace(/[-:]/g, "")}`,
    `DTSTART:${beginn}`,
    "DURATION:PT15M",
    `SUMMARY:${kalenderText(`JavaQuest: ${ziele} wiederholen`)}`,
    `DESCRIPTION:${kalenderText(`${ziele} ${warten} auf die Wiederholung – kurz reinschauen, bevor es verblasst.\n${adresse}`)}`,
    `URL:${adresse}`,
    "BEGIN:VALARM", "ACTION:DISPLAY", `DESCRIPTION:${kalenderText(`JavaQuest: ${ziele} wiederholen`)}`, "TRIGGER:PT0M", "END:VALARM",
    "END:VEVENT", "END:VCALENDAR",
  ].map(kalenderZeile).join("\r\n") + "\r\n";
}

function erinnerungHerunterladen() {
  const termin = erinnerungsTermine(faelligkeiten(), Date.now())[0];
  if (!termin) return;
  dateiHerunterladen(kalenderEintrag(termin, Date.now()), "text/calendar;charset=utf-8", "javaquest-wiederholung.ics");
  melde("Kalendereintrag erstellt – öffne ihn, um ihn in deinen Kalender zu übernehmen.");
}

/** Wie ein Thema auf den einzelnen Schwierigkeitsstufen läuft. */
function stufen(themaId) {
  const gesehen = {}, geloest = {};
  for (const a of uebbareAufgaben()) {
    if (a.topicId !== themaId) continue;
    const v = stand.verlauf[a.id];
    if (!v) continue;
    gesehen[a.difficulty] = (gesehen[a.difficulty] || 0) + 1;
    if (v.wertung >= 1) geloest[a.difficulty] = (geloest[a.difficulty] || 0) + 1;
  }
  return Object.keys(gesehen).map(Number).sort((a, b) => a - b).map((stufe) => {
    const s = gesehen[stufe], r = geloest[stufe] || 0;
    // Wacklig erst ab zwei Versuchen und unter der Bestehensgrenze – ein Fehlversuch zählt nicht.
    return { stufe, gesehen: s, geloest: r, wacklig: s >= 2 && r / s < BESTANDEN_AB };
  });
}

// ---------------------------------------------------------------- Kurs
const alleLektionen = () => kurs.modules.flatMap((m) => m.lessons);
const uebbareAufgaben = () => alleLektionen().flatMap((l) => l.tasks).concat(kurs.taskPool || []);
const gruppe = (a) => a.variantGroup || a.id;
const thema = (id) => kurs.topics.find((t) => t.id === id);

function lektionErgebnis(id) { return stand.lektionen[id] || null; }

function istFrei(index) {
  if (index === 0) return true;
  const vorher = alleLektionen()[index - 1];
  const e = lektionErgebnis(vorher.id);
  return !!(e && e.bestanden);
}

function naechsteLektion() {
  const lektionen = alleLektionen();
  return lektionen.find((l) => !(lektionErgebnis(l.id) || {}).bestanden) || null;
}

/* Stufenfaktor wie MasterScore.tierFactor: Fortgeschrittene Module zählen mehr.
   Ohne ihn käme auf demselben Stand im Web eine andere Zahl heraus als in der App. */
const STUFENFAKTOR = { beginner: 1.0, intermediate: 1.25, advanced: 1.5 };

function score(lektionen = stand.lektionen) {
  // Wie MasterScore: nur bestandene Lektionen zählen, gewichtet nach Niveau und Modulstufe.
  let erreicht = 0, gesamt = 0;
  for (const m of kurs.modules) {
    const faktor = STUFENFAKTOR[m.tier] || 1;
    for (const l of m.lessons) {
      const gewicht = l.tasks.reduce((s, t) => s + t.difficulty, 0) * faktor;
      gesamt += gewicht;
      const e = (lektionen || {})[l.id];
      if (e && e.bestanden) erreicht += gewicht * Math.min(Math.max(e.quote, 0), 1);
    }
  }
  return gesamt ? Math.round((erreicht / gesamt) * 1000) : 0;
}

/* Ränge wie MasterScore.ranks. */
const RAENGE = [
  { titel: "Neuling", ab: 0, symbol: "🌱" },
  { titel: "Code-Talent", ab: 150, symbol: "✨" },
  { titel: "Java-Profi", ab: 350, symbol: "🔨" },
  { titel: "Architektur-Ass", ab: 600, symbol: "🏛️" },
  { titel: "Java Master", ab: 850, symbol: "👑" },
];

const rang = (punkte) => RAENGE.filter((r) => punkte >= r.ab).pop();
const naechsterRang = (punkte) => RAENGE.find((r) => punkte < r.ab) || null;

/* Sterne wie Stars.forAccuracy – beide Grenzen leiten sich aus der Bestehensgrenze ab. */
const ZWEI_STERNE_AB = BESTANDEN_AB + (1 - BESTANDEN_AB) / 2;

function sterne(quote) {
  if (quote >= 0.999) return 3;
  if (quote >= ZWEI_STERNE_AB) return 2;
  return quote >= BESTANDEN_AB ? 1 : 0;
}

/* Tagesserie wie im Kern: aufeinanderfolgende Tage mit mindestens einer gelösten Aufgabe. */
const heuteAlsTag = () => Math.floor(Date.now() / 86400000);

function merkeAktivitaet() {
  const heute = heuteAlsTag();
  const serie = stand.serie || { aktuell: 0, laengste: 0, letzterTag: null };
  if (serie.letzterTag === heute) return;
  serie.aktuell = serie.letzterTag !== null && heute - serie.letzterTag === 1 ? serie.aktuell + 1 : 1;
  serie.laengste = Math.max(serie.laengste, serie.aktuell);
  serie.letzterTag = heute;
  stand.serie = serie;
}

/** Die Serie zählt nur, solange kein Tag ausgelassen wurde. */
function aktuelleSerie() {
  const serie = stand.serie;
  if (!serie || serie.letzterTag === null) return 0;
  return heuteAlsTag() - serie.letzterTag <= 1 ? serie.aktuell : 0;
}

/* Wissensanalyse wie KnowledgeAnalyzer – gleiche Schwellen, gleiche Mindestzahlen. */
const STAERKE_AB = 0.75;
const LUECKE_UNTER = 0.55;

function themenStatus(themaId) {
  const t = stand.themen[themaId];
  if (!t || !t.gesehen) return "unbekannt";
  const m = beherrschung(themaId);
  if (t.gesehen >= 3 && m >= STAERKE_AB) return "staerke";
  if (t.gesehen >= 2 && m < LUECKE_UNTER) return "luecke";
  return "aufbau";
}

const STATUS_TITEL = { staerke: "Stärken", aufbau: "Im Aufbau", luecke: "Wissenslücken", unbekannt: "Noch unbekannt" };
const STATUS_SYMBOL = { staerke: "✓", aufbau: "↗", luecke: "!", unbekannt: "?" };

/** Gesamte Beherrschung über alle Themen – gewichtet nach Niveau. */
function gesamtBeherrschung() {
  let gewichtet = 0, gesamt = 0;
  for (const t of Object.values(stand.themen)) { gewichtet += t.gewichtet; gesamt += t.gesamt; }
  return gesamt ? (gewichtet + 1) / (gesamt + 2) : null;
}

// ---------------------------------------------------------------- Varianten
/** Eine Aufgabe je Lernziel – nach einem Fehler bewusst eine andere als zuletzt. */
function waehleVariante(varianten) {
  if (varianten.length === 1) return varianten[0];
  const ungesehen = varianten.filter((a) => !stand.verlauf[a.id]);
  if (ungesehen.length) return ungesehen.sort((a, b) => a.difficulty - b.difficulty)[0];
  const juengste = varianten.reduce((a, b) =>
    (stand.verlauf[a.id]?.datum || 0) >= (stand.verlauf[b.id]?.datum || 0) ? a : b);
  const andere = varianten.filter((a) => a.id !== juengste.id)
    .sort((a, b) => (stand.verlauf[a.id]?.datum || 0) - (stand.verlauf[b.id]?.datum || 0));
  return andere[0] || juengste;
}

function eineProGruppe(aufgaben) {
  const nach = new Map();
  for (const a of aufgaben) {
    const k = gruppe(a);
    if (!nach.has(k)) nach.set(k, []);
    nach.get(k).push(a);
  }
  return [...nach.values()].map(waehleVariante);
}

function lektionsAufgaben(lektion) {
  const schluessel = new Set(lektion.tasks.map(gruppe));
  const extra = (kurs.taskPool || []).filter((a) => schluessel.has(gruppe(a)));
  return eineProGruppe(lektion.tasks.concat(extra)).sort((a, b) => a.difficulty - b.difficulty);
}

/** Gewicht wie im Kern: Schwaches, Falsches und lange nicht Gesehenes kommt öfter. */
function gewicht(aufgabe) {
  const jetzt = Date.now();
  const schluessel = gruppe(aufgabe);
  let g = 1;
  const m = beherrschung(aufgabe.topicId);
  g += (1 - (m === null ? 0.5 : m)) * 3;
  const v = stand.verlauf[aufgabe.id];
  // Noch nie geübt – aber vielleicht eine andere Variante desselben Lernziels.
  if (!v) return (g + 2) * wiedervorlage(schluessel, jetzt);
  g += (1 - Math.min(Math.max(v.wertung, 0), 1)) * 3;
  const tage = Math.max((jetzt - v.datum) / 86400000, 0);
  g += Math.min(tage, 14) / 7;
  if (stand.ziele[schluessel]) return g * wiedervorlage(schluessel, jetzt);
  // Ohne Wiedervorlage-Daten bleibt die alte, gröbere Regel als Rückfallebene.
  if (tage < 1 && v.wertung >= 1) g /= 3;
  return g;
}

function runde(topf, anzahl) {
  const kandidaten = eineProGruppe(topf).map((a) => ({ a, g: gewicht(a) }));
  const gewaehlt = [];
  while (gewaehlt.length < anzahl && kandidaten.length) {
    const summe = kandidaten.reduce((s, k) => s + k.g, 0);
    let los = Math.random() * summe;
    let i = kandidaten.length - 1;
    for (let k = 0; k < kandidaten.length; k++) {
      los -= kandidaten[k].g;
      if (los <= 0) { i = k; break; }
    }
    gewaehlt.push(kandidaten.splice(i, 1)[0].a);
  }
  return gewaehlt.sort((a, b) => a.difficulty - b.difficulty);
}

/** Lernziele, die zuletzt nicht saßen. */
function schwaechen() {
  const nach = new Map();
  for (const a of uebbareAufgaben()) {
    const k = gruppe(a);
    if (!nach.has(k)) nach.set(k, []);
    nach.get(k).push(a);
  }
  const offen = [];
  for (const [k, varianten] of nach) {
    const versuche = varianten.filter((a) => stand.verlauf[a.id]);
    if (!versuche.length) continue;
    const juengste = versuche.reduce((a, b) =>
      stand.verlauf[a.id].datum >= stand.verlauf[b.id].datum ? a : b);
    const v = stand.verlauf[juengste.id];
    if (v.wertung >= 1) continue;
    offen.push({ gruppe: k, aufgabe: juengste, wertung: v.wertung, datum: v.datum, varianten: varianten.length });
  }
  return offen.sort((a, b) => a.wertung - b.wertung || b.datum - a.datum);
}

/* ---------------------------------------------------------------- Einstufung
   Adaptiv wie in der iPhone- und Windows-Fassung: Start auf Stufe 3, nach einer richtigen
   Antwort steigt das Zielniveau, nach einer falschen sinkt es. Gewählt wird jeweils die noch
   ungestellte Frage, die dem Ziel am nächsten liegt – bei Gleichstand ein neues Thema.
   Bewertet wird gewichtet: Schwere Fragen zählen mehr. */
const einstufungPool = () => ((kurs.placement && kurs.placement.pools) || {}).intermediate || [];

function naechsteEinstufungsfrage(test) {
  const gestellteThemen = new Set(test.antworten.map((x) => x.aufgabe.topicId));
  let beste = -1;
  test.rest.forEach((a, i) => {
    if (beste < 0) { beste = i; return; }
    const b = test.rest[beste];
    const da = Math.abs(a.difficulty - test.ziel), db = Math.abs(b.difficulty - test.ziel);
    if (da !== db) { if (da < db) beste = i; return; }
    const neuA = !gestellteThemen.has(a.topicId), neuB = !gestellteThemen.has(b.topicId);
    if (neuA !== neuB && neuA) beste = i;
  });
  return beste < 0 ? null : test.rest.splice(beste, 1)[0];
}

function einstufungProzent(test) {
  const gesamt = test.antworten.reduce((x, y) => x + y.aufgabe.difficulty, 0);
  if (!gesamt) return 0;
  const erreicht = test.antworten.reduce((x, y) => x + y.aufgabe.difficulty * y.wertung, 0);
  return Math.round(erreicht / gesamt * 100);
}

/** Drei Ausgänge statt bestanden/durchgefallen. */
function einstufungStufe(prozent) {
  const c = kurs.placement;
  if (prozent >= (c.advancedThreshold || 101)) return "advanced";
  return prozent >= c.passThreshold ? "intermediate" : "beginner";
}

function einstiegsModul(stufe) {
  return kurs.modules.find((m) => m.tier === stufe) || kurs.modules[0];
}

// ---------------------------------------------------------------- Auswertung
const ohneLeerzeichen = (t) => t.replace(/\s+/g, "");

function ausgabeZeilen(text) {
  let zeilen = text.replace(/\r\n/g, "\n").split("\n").map((z) => z.replace(/[ \t]+$/, ""));
  while (zeilen.length && zeilen[0] === "") zeilen.shift();
  while (zeilen.length && zeilen[zeilen.length - 1] === "") zeilen.pop();
  return zeilen;
}

function lueckePasst(luecke, wert) {
  const norm = (t) => {
    const kompakt = ohneLeerzeichen(t);
    return luecke.caseSensitive === false ? kompakt.toLowerCase() : kompakt;
  };
  const kandidaten = [norm(wert)];
  if (kandidaten[0].endsWith(";")) kandidaten.push(kandidaten[0].slice(0, -1));
  const erlaubt = new Set(luecke.accepted.map(norm));
  return kandidaten.some((k) => erlaubt.has(k));
}

/** Kommentare entfernen, Strings leeren – wie JavaSource im Kern. */
function ohneKommentare(quelle) {
  return quelle.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, " "))
               .replace(/\/\/[^\n]*/g, "");
}
function ohneLiterale(quelle) {
  return ohneKommentare(quelle).replace(/"(?:\\.|[^"\\])*"/g, '""');
}

// Warum diese Eingabe die Lücke nicht füllt – konkret statt „passt noch nicht“.
// Ein bloßes „falsch“ lässt den Lernenden im Dunkeln; die häufigen Fälle lassen sich benennen.
function warumBlankFalsch(wert, luecke, alle, index) {
  const eingabe = (wert || "").trim();
  const klein = eingabe.toLowerCase();
  const richtig = luecke.accepted[0] || "";
  if (luecke.accepted.some((a) => a.toLowerCase() === klein)) return "fast – achte auf Groß- und Kleinschreibung.";
  for (let j = 0; j < alle.length; j++) {
    if (j !== index && alle[j].accepted.some((a) => a.toLowerCase() === klein)) return `das gehört in Lücke ${j + 1}.`;
  }
  const ohneKlammern = eingabe.replace("()", "").toLowerCase();
  if (luecke.accepted.some((a) => a.toLowerCase() === ohneKlammern)) return "die runden Klammern stehen hier schon im Text.";
  if (luecke.accepted.some((a) => a.toLowerCase() === klein + "()")) return "fast – es fehlen die runden Klammern.";
  if (richtig && richtig.toLowerCase().startsWith(klein)) return "der Anfang stimmt, es fehlt noch etwas.";
  if (eingabe && richtig && klein.startsWith(richtig.toLowerCase())) return "da steht etwas zu viel.";
  return "stimmt noch nicht.";
}

// Was an dieser einen Zeile abweicht – benannt, nicht nur festgestellt.
function warumZeileFalsch(gegeben, erwartet) {
  if (gegeben.toLowerCase() === erwartet.toLowerCase()) return "richtig bis auf die Groß- und Kleinschreibung.";
  if (ohneLeerzeichen(gegeben) === ohneLeerzeichen(erwartet)) return "richtig bis auf die Leerzeichen.";
  if (erwartet.endsWith(".0") && erwartet.slice(0, -2) === gegeben) {
    return "die Nachkommastelle fehlt – sobald eine Kommazahl beteiligt ist, hat auch das Ergebnis eine.";
  }
  if (gegeben.endsWith(".0") && gegeben.slice(0, -2) === erwartet) {
    return "hier wird mit ganzen Zahlen gerechnet, da kommt keine Nachkommastelle heraus.";
  }
  if (erwartet.startsWith("[") && erwartet.endsWith("]") && erwartet.slice(1, -1) === gegeben) {
    return "eine Liste gibt sich mit eckigen Klammern aus.";
  }
  if (erwartet.length === gegeben.length) return "gleich lang, aber ein anderer Inhalt.";
  return gegeben.length < erwartet.length ? "da fehlt noch etwas." : "da steht etwas zu viel.";
}

// Ein Befund über die ganze Ausgabe – für Fehler, die man nur im Zusammenhang sieht.
function warumAusgabeFalsch(gegeben, erwartet) {
  const g = gegeben.join(""), e = erwartet.join("");
  // Nur melden, wenn sich der Text wirklich in der Schreibweise unterscheidet – sonst
  // verdeckt dieser Fall den print/println-Fehler, bei dem der Text identisch ist.
  if (g.toLowerCase() === e.toLowerCase() && g !== e) {
    return "Fast! Achte auf Groß- und Kleinschreibung.";
  }
  if (gegeben.length === 1 && erwartet.length > 1 && gegeben[0] === e) {
    return "Der Inhalt stimmt, aber alles steht in einer Zeile. println beginnt danach eine neue, print nicht.";
  }
  if (erwartet.length === 1 && gegeben.length > 1 && erwartet[0] === g) {
    return "Der Inhalt stimmt, aber er ist auf mehrere Zeilen verteilt. Nur println bricht um.";
  }
  if (ohneLeerzeichen(g) === ohneLeerzeichen(e)) {
    return "Fast! Achte auf Leerzeichen und Zeilenumbrüche – println beginnt eine neue Zeile, print nicht.";
  }
  if (gegeben.length > erwartet.length) {
    return `Es erscheinen ${gegeben.length - erwartet.length} Zeile(n) zu viel. Zähl nach, wie oft die Ausgabe wirklich erreicht wird.`;
  }
  if (gegeben.length < erwartet.length) {
    return `Es fehlen ${erwartet.length - gegeben.length} Zeile(n). Zähl nach, wie oft die Ausgabe erreicht wird.`;
  }
  return null;
}

/* Der zweite Tipp: konkreter als der erste, aber immer noch nicht die Lösung.

   Er wird nicht geschrieben, sondern aus der Aufgabe abgeleitet. Das hat zwei Gründe.
   Erstens ist er dadurch für jede der 685 Aufgaben da und kann nicht vergessen werden.
   Zweitens richtet er sich nach dem, was tatsächlich schon versucht wurde: Bei einer
   Auswahlaufgabe streicht er zwei Antworten, die man noch nicht gewählt hat – ein fest
   geschriebener Satz könnte das nicht. Die Lösung nennt er in keinem Fall. */
function zweiterTipp(aufgabe, gewaehlt) {
  if (aufgabe.type === "singleChoice") {
    // Zwei falsche Antworten streichen, die noch nicht dran waren – aus vier mach zwei.
    const streichbar = aufgabe.choices
      .map((text, i) => ({ text, i, grund: (aufgabe.whyWrong || [])[i] }))
      .filter((c) => c.i !== aufgabe.correctIndex && c.i !== gewaehlt && c.grund);
    if (streichbar.length >= 2) {
      const [a, b] = streichbar;
      return `Streich schon mal zwei: „${a.text}“ und „${b.text}“ scheiden aus. ${a.grund}`;
    }
    if (streichbar.length === 1) {
      return `Auch „${streichbar[0].text}“ scheidet aus. ${streichbar[0].grund}`;
    }
    return null;
  }
  if (aufgabe.type === "predictOutput") {
    const zeilen = ausgabeZeilen(aufgabe.expectedOutput);
    return zeilen.length === 1
      ? "Die Ausgabe besteht aus genau einer Zeile."
      : `Die Ausgabe besteht aus genau ${zeilen.length} Zeilen. Geh den Code Anweisung für Anweisung durch und zähl mit.`;
  }
  if (aufgabe.type === "fillBlank") {
    const teile = aufgabe.blanks.map((l, i) => {
      const wort = l.accepted[0] || "";
      return `Lücke ${i + 1}: ${wort.length} Zeichen, beginnt mit „${wort.slice(0, 1)}“`;
    });
    return teile.join(" · ");
  }
  if (aufgabe.type === "code") {
    const quelle = (aufgabe.sampleSolution && aufgabe.sampleSolution.lines)
      ? aufgabe.sampleSolution.lines.map((z) => z.code) : [];
    const zeilen = quelle.filter((z) => z.trim()).length;
    return zeilen ? `Die Musterlösung kommt mit ${zeilen} Zeilen aus – mehr brauchst du nicht.` : null;
  }
  return null;
}

function auswerten(aufgabe, antwort) {
  const befunde = [];
  if (aufgabe.type === "singleChoice") {
    const richtig = antwort === aufgabe.correctIndex;
    return { richtig, wertung: richtig ? 1 : 0,
             befunde: [{ art: richtig ? "gut" : "schlecht", text: richtig ? "Richtig gewählt." : "Diese Antwort stimmt leider nicht." }] };
  }

  if (aufgabe.type === "fillBlank") {
    let treffer = 0;
    aufgabe.blanks.forEach((l, i) => {
      const wert = (antwort[i] || "").trim();
      if (lueckePasst(l, wert)) { treffer++; befunde.push({ art: "gut", text: `Lücke ${i + 1} stimmt.` }); }
      else if (!wert) befunde.push({ art: "schlecht", text: `Lücke ${i + 1} ist noch leer.` });
      else befunde.push({ art: "schlecht", text: `Lücke ${i + 1}: ${warumBlankFalsch(wert, l, aufgabe.blanks, i)}` });
    });
    return { richtig: treffer === aufgabe.blanks.length, wertung: treffer / aufgabe.blanks.length, befunde };
  }

  if (aufgabe.type === "predictOutput") {
    const gegeben = ausgabeZeilen(antwort || "");
    const erwartungen = [aufgabe.expectedOutput].concat(aufgabe.alsoAccepted || []).map(ausgabeZeilen);
    if (erwartungen.some((e) => e.join("\n") === gegeben.join("\n"))) {
      return { richtig: true, wertung: 1, befunde: [{ art: "gut", text: "Die Ausgabe stimmt exakt." }] };
    }
    if (!gegeben.length) return { richtig: false, wertung: 0, befunde: [{ art: "schlecht", text: "Noch keine Ausgabe eingegeben." }] };
    const erwartet = erwartungen[0];
    let treffer = 0;
    for (let i = 0; i < Math.max(erwartet.length, gegeben.length); i++) {
      if (erwartet[i] !== undefined && erwartet[i] === gegeben[i]) treffer++;
      else if (erwartet[i] === undefined) befunde.push({ art: "schlecht", text: `Zeile ${i + 1} ist zu viel.` });
      else if (gegeben[i] === undefined) befunde.push({ art: "schlecht", text: `Zeile ${i + 1} fehlt noch.` });
      else befunde.push({ art: "schlecht", text: `Zeile ${i + 1}: ${warumZeileFalsch(gegeben[i], erwartet[i])}` });
    }
    if (treffer) befunde.unshift({ art: "gut", text: `${treffer} von ${erwartet.length} Zeilen stimmen.` });
    const gesamt = warumAusgabeFalsch(gegeben, erwartet);
    if (gesamt) befunde.push({ art: "tipp", text: gesamt });
    return { richtig: false, wertung: treffer / Math.max(erwartet.length, gegeben.length), befunde };
  }

  // Code: Regeln auf dem Quelltext prüfen, wie im Kern.
  const quelle = antwort || "";
  const roh = ohneKommentare(quelle);
  const maskiert = ohneLiterale(quelle);
  if (!maskiert.trim()) return { richtig: false, wertung: 0, befunde: [{ art: "schlecht", text: "Hier steht noch kein Code." }] };

  let erreicht = 1, gesamt = 1, alleErfuellt = true, verstoesse = 0;
  for (const regel of aufgabe.rules || []) {
    const ziel = regel.scope === "raw" ? roh : maskiert;
    // Bei „anyOf“ genügt einer der gleichwertigen Wege.
    const muster = (regel.patterns && regel.patterns.length) ? regel.patterns : [regel.pattern];
    let treffer = false;
    for (const m of muster) {
      try { if (new RegExp(m).test(ziel)) { treffer = true; break; } } catch (e) { /* ungültiges Muster zählt als kein Treffer */ }
    }
    const gew = regel.weight || 1;
    if (regel.rule === "require" || regel.rule === "anyOf") {
      gesamt += gew;
      if (treffer) { erreicht += gew; befunde.push({ art: "gut", text: regel.message }); }
      else { alleErfuellt = false; befunde.push({ art: "schlecht", text: regel.message }); }
    } else if (treffer) {
      verstoesse++;
      befunde.push({ art: "schlecht", text: regel.message });
    }
  }
  let wertung = erreicht / gesamt;
  if (verstoesse) wertung *= 0.5;
  return { richtig: alleErfuellt && verstoesse === 0, wertung, befunde };
}

function musterAntwort(aufgabe) {
  switch (aufgabe.type) {
    case "singleChoice": return aufgabe.correctIndex;
    case "fillBlank": return aufgabe.blanks.map((l) => l.accepted[0]);
    case "predictOutput": return aufgabe.expectedOutput;
    case "code": return aufgabe.sampleSolution.lines.map((z) => z.code).join("\n");
  }
}

// ---------------------------------------------------------------- Darstellung
const h = (html) => html;
const sicher = (t) => String(t == null ? "" : t).replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

/** Code als HTML – Lücken {{0}}, {{1}} … erscheinen als nummerierte Markierung wie in den Apps. */
function codeZeile(code) {
  return sicher(code || "").replace(/\{\{(\d+)\}\}/g, (_, i) =>
    `<span class="lueckenmarke" aria-label="Lücke ${Number(i) + 1}">${Number(i) + 1}</span>`);
}

function codeBlock(schnipsel) {
  if (!schnipsel || !schnipsel.lines) return "";
  const zeilen = schnipsel.lines.map((z, i) =>
    `<span class="nr">${String(i + 1).padStart(2, " ")}</span>  ${codeZeile(z.code)}`).join("\n");
  // role="img" mit Beschriftung: Sonst buchstabieren Sprachausgaben jedes Sonderzeichen einzeln.
  // Die Exegese darunter liest den Code Zeile für Zeile in Worten vor.
  return `<pre class="code" tabindex="0" role="img" aria-label="Java-Code, ${schnipsel.lines.length} Zeilen. Die Erklärung Zeile für Zeile steht darunter.">${zeilen}</pre>`;
}

/* Zeile für Zeile erklärt. Vor dem Lösen einer Lückenaufgabe bleibt die Erklärung jeder
   Zeile mit Lücke verdeckt – sie nennt die Antwort (bei 152 von 201 Lückenzeilen). Die
   Befehle der Zeile bleiben sichtbar: Wo die Antwort darunter ist, steht sie ohnehin
   schon in derselben Zeile (siehe Prüfung in tests/pruefungen.mjs). */
function exegese(schnipsel, titel, verdeckeLuecken = false) {
  if (!schnipsel || !schnipsel.lines) return "";
  const zeilen = schnipsel.lines.filter((z) => z.explain).map((z) => {
    const verdeckt = verdeckeLuecken && /\{\{\d+\}\}/.test(z.code || "");
    const text = verdeckt
      ? `<span class="leise">Hier steckt eine Lücke – die ganze Erklärung erscheint, sobald du die Aufgabe gelöst hast.</span>`
      : sicher(z.explain);
    return `<div class="erklaerzeile"><code>${codeZeile(z.code)}</code>${text}${befehle(z)}</div>`;
  }).join("");
  if (!zeilen) return "";
  return `<details class="exegese"><summary>${sicher(titel)}</summary><div class="zeilen">${zeilen}</div></details>`;
}

/** Die Lückenvorlage mit der ersten richtigen Antwort in jeder Lücke – wie `solvedSnippet` in den Apps. */
function geloesteVorlage(aufgabe) {
  return {
    lines: aufgabe.template.lines.map((z) => {
      const terms = [...(z.terms || [])];
      const code = (z.code || "").replace(/\{\{(\d+)\}\}/g, (_, i) => {
        const antwort = ((aufgabe.blanks[Number(i)] || {}).accepted || [""])[0];
        // Der eingesetzte Befehl wird jetzt ebenfalls erklärt (Methoden stehen im Lexikon mit „()“).
        for (const kandidat of [antwort, `${antwort}()`]) if (antwort && !terms.includes(kandidat)) terms.push(kandidat);
        return antwort;
      });
      return Object.assign({}, z, { code, terms });
    }),
  };
}

/* Befehlslexikon: Jede erklärte Zeile nennt in der Kursdatei ihre Befehle („terms“),
   das Glossar sagt, was jeder bedeutet. Die Apps zeigen das als „Befehle in dieser
   Zeile“; die Web-Fassung hat die Liste lange mitgeladen und nie angezeigt. */
let lexikon = { kurs: null, bedeutung: new Map() };

/** Die Befehle einer Zeile als [Begriff, Bedeutung] – nur solche mit Glossareintrag. */
function befehleDerZeile(zeile) {
  if (lexikon.kurs !== kurs) {
    lexikon = { kurs, bedeutung: new Map(((kurs && kurs.glossary) || []).map((e) => [e.term, e.meaning])) };
  }
  return (zeile.terms || [])
    .filter((t) => lexikon.bedeutung.has(t))
    .map((t) => [t, lexikon.bedeutung.get(t)]);
}

/** Aufklappbar wie in den Apps nur auf Wunsch – sonst würde die Erklärung zur Liste. */
function befehle(zeile) {
  const liste = befehleDerZeile(zeile);
  if (!liste.length) return "";
  const eintraege = liste.map(([t, b]) =>
    `<div><dt><code class="begriff">${sicher(t)}</code></dt> <dd>${sicher(b)}</dd></div>`).join("");
  return `<details class="befehle"><summary>Befehle in dieser Zeile (${liste.length})</summary><dl class="lexikon">${eintraege}</dl></details>`;
}

/** UML-Klassendiagramm zeichnen – gleiche Anordnung wie in den anderen Fassungen. */
function umlDiagramm(d) {
  if (!d) return "";
  const BREITE = 210, KOPF = 34, ZEILE = 20, POLSTER = 8, LUECKE_X = 34, LUECKE_Y = 60;
  const hoehe = (k) => KOPF + 2 + (Math.max(k.fields?.length || 0, 1) * ZEILE + POLSTER * 2)
                              + (Math.max(k.methods?.length || 0, 1) * ZEILE + POLSTER * 2);
  const ebene = {};
  d.classes.forEach((k) => { ebene[k.name] = 0; });
  for (let n = 0; n < d.classes.length; n++) {
    for (const r of d.relations || []) {
      if (r.kind !== "extendsRelation" && r.kind !== "implementsRelation") continue;
      if ((ebene[r.from] || 0) <= (ebene[r.to] || 0)) ebene[r.from] = (ebene[r.to] || 0) + 1;
    }
  }
  const reihen = {};
  d.classes.forEach((k) => { (reihen[ebene[k.name]] ||= []).push(k); });
  const gelegt = [];
  let y = 0, maxBreite = 0;
  Object.keys(reihen).sort().forEach((stufe) => {
    const reihe = reihen[stufe];
    const breite = reihe.length * BREITE + (reihe.length - 1) * LUECKE_X;
    maxBreite = Math.max(maxBreite, breite);
    let x = 0, maxH = 0;
    reihe.forEach((k) => {
      const hh = hoehe(k);
      gelegt.push({ k, x, y, h: hh });
      x += BREITE + LUECKE_X; maxH = Math.max(maxH, hh);
    });
    y += maxH + LUECKE_Y;
  });
  gelegt.forEach((p) => {
    const reihe = gelegt.filter((q) => q.y === p.y);
    const breite = Math.max(...reihe.map((q) => q.x + BREITE)) - Math.min(...reihe.map((q) => q.x));
    p.x += (maxBreite - breite) / 2;
  });
  const finde = (name) => gelegt.find((p) => p.k.name === name);

  let svg = "";
  for (const r of d.relations || []) {
    const von = finde(r.from), zu = finde(r.to);
    if (!von || !zu) continue;
    const nebeneinander = Math.abs(von.y - zu.y) < 1;
    const sx = nebeneinander ? von.x + BREITE : von.x + BREITE / 2;
    const sy = nebeneinander ? von.y + von.h / 2 : von.y;
    const ex = nebeneinander ? zu.x : zu.x + BREITE / 2;
    const ey = nebeneinander ? zu.y + zu.h / 2 : zu.y + zu.h;
    const mitte = (sy + ey) / 2;
    const pfad = nebeneinander ? `M${sx},${sy} L${ex},${ey}` : `M${sx},${sy} L${sx},${mitte} L${ex},${mitte} L${ex},${ey}`;
    const gestrichelt = r.kind === "implementsRelation" || r.kind === "dependency";
    svg += `<path d="${pfad}" fill="none" stroke="#544FE6" stroke-width="1.8"${gestrichelt ? ' stroke-dasharray="6 4"' : ""}/>`;
    if (r.kind === "extendsRelation" || r.kind === "implementsRelation") {
      svg += `<path d="M${ex},${ey} L${ex - 7},${ey + 11} L${ex + 7},${ey + 11} Z" fill="#fff" stroke="#544FE6" stroke-width="1.8"/>`;
    } else if (r.kind === "aggregation" || r.kind === "composition") {
      svg += `<path d="M${ex},${ey} L${ex - 5},${ey + 8} L${ex},${ey + 16} L${ex + 5},${ey + 8} Z" fill="${r.kind === "composition" ? "#544FE6" : "#fff"}" stroke="#544FE6" stroke-width="1.8"/>`;
    } else {
      svg += `<path d="M${ex - 5},${ey + 9} L${ex},${ey} L${ex + 5},${ey + 9}" fill="none" stroke="#544FE6" stroke-width="1.8"/>`;
    }
    const beschriftung = r.label || r.multiplicity;
    if (beschriftung) svg += `<text x="${(sx + ex) / 2 + 8}" y="${(sy + ey) / 2}" font-size="11" fill="#6C6C70">${sicher(beschriftung)}</text>`;
  }
  for (const p of gelegt) {
    const stereotyp = { interfaceType: "«interface»", abstractType: "«abstract»", recordType: "«record»" }[p.k.kind];
    svg += `<rect x="${p.x}" y="${p.y}" width="${BREITE}" height="${p.h}" rx="8" fill="#fff" stroke="#544FE6" stroke-width="1.5"/>`;
    svg += `<rect x="${p.x}" y="${p.y}" width="${BREITE}" height="${KOPF}" rx="8" fill="#544FE6" fill-opacity="0.12"/>`;
    let ty = p.y + (stereotyp ? 14 : 22);
    if (stereotyp) {
      svg += `<text x="${p.x + BREITE / 2}" y="${ty}" text-anchor="middle" font-size="10" fill="#544FE6">${stereotyp}</text>`;
      ty += 14;
    }
    svg += `<text x="${p.x + BREITE / 2}" y="${ty}" text-anchor="middle" font-size="14" font-weight="700" font-family="ui-monospace, monospace" fill="#11111A">${sicher(p.k.name)}</text>`;
    let zy = p.y + KOPF + POLSTER + 14;
    const abschnitt = (mitglieder) => {
      (mitglieder || []).forEach((m) => {
        const farbe = { "+": "#2EAE61", "-": "#E8424D", "#": "#F57321" }[m.visibility] || "#6C6C70";
        svg += `<text x="${p.x + 10}" y="${zy}" font-size="12" font-family="ui-monospace, monospace" fill="${farbe}" font-weight="700">${sicher(m.visibility)}</text>`;
        svg += `<text x="${p.x + 24}" y="${zy}" font-size="12" font-family="ui-monospace, monospace" fill="#11111A">${sicher(m.type ? `${m.name}: ${m.type}` : m.name)}</text>`;
        zy += ZEILE;
      });
      if (!mitglieder || !mitglieder.length) zy += ZEILE;
      zy += POLSTER * 2;
      svg += `<line x1="${p.x}" y1="${zy - POLSTER * 2 - ZEILE + 6}" x2="${p.x + BREITE}" y2="${zy - POLSTER * 2 - ZEILE + 6}" stroke="#544FE6" stroke-opacity="0.25"/>`;
    };
    abschnitt(p.k.fields);
    abschnitt(p.k.methods);
  }

  const bedeutung = {
    extendsRelation: ["Vererbung (extends)", "„ist ein“: Die Kind-Klasse erbt alles von der Eltern-Klasse. Pfeil mit leerer Dreiecksspitze zur Eltern-Klasse."],
    implementsRelation: ["Interface umsetzen (implements)", "Die Klasse unterschreibt einen Vertrag. Gestrichelte Linie mit leerer Dreiecksspitze zum Interface."],
    association: ["Assoziation", "„kennt“: Die eine Klasse benutzt die andere dauerhaft, z. B. als Feld."],
    aggregation: ["Aggregation", "„hat“, aber die Teile leben weiter – leere Raute an der Ganzes-Seite."],
    composition: ["Komposition", "„besteht aus“: Ohne das Ganze gibt es die Teile nicht – gefüllte Raute."],
    dependency: ["Abhängigkeit", "„benutzt kurz“, z. B. als Parameter. Gestrichelter Pfeil."],
  };
  const vielfach = { "1": "genau eins", "0..1": "keins oder eins", "1..*": "mindestens eins", "*": "beliebig viele" };
  const legende = (d.relations || []).map((r) => {
    const [titel, text] = bedeutung[r.kind] || ["Beziehung", ""];
    const v = r.multiplicity ? ` Vielfachheit ${r.multiplicity}: ${vielfach[r.multiplicity] || "wie angegeben"}.` : "";
    return `<div class="legende"><b>${sicher(r.from)} → ${sicher(r.to)}: ${titel}</b><span class="leise">${sicher(text + v)}</span></div>`;
  }).join("");

  // Das Diagramm selbst ist ein Bild; was darauf zu sehen ist, steht als Titel und
  // ausführlich in der Legende darunter – die lesen Sprachausgaben ohnehin vor.
  const klassen = d.classes.map((k) => k.name).join(", ");
  const beschreibung = `UML-Klassendiagramm mit ${d.classes.length === 1 ? "der Klasse" : "den Klassen"} ${klassen}.`;
  return `<div class="uml"><svg width="${maxBreite}" height="${Math.max(y - LUECKE_Y, 0) + 4}" viewBox="0 0 ${maxBreite} ${Math.max(y - LUECKE_Y, 0) + 4}" role="img" aria-label="${sicher(beschreibung)}"><title>${sicher(beschreibung)}</title>${svg}</svg>${legende}</div>`;
}

// ---------------------------------------------------------------- Bildschirme
const el = () => document.getElementById("app");

function zeichne() {
  const s = { start: startSeite, themen: themenSeite, schwaechen: schwaechenSeite,
              lektionen: lektionenSeite, sitzung: sitzungSeite, einstieg: einstiegSeite,
              einstufungErgebnis: einstufungErgebnisSeite, analyse: analyseSeite,
              profil: profilSeite }[ansicht.name] || startSeite;
  // Die Leiste gibt es überall außer im Einstieg und während einer laufenden Aufgabe –
  // wie in der App, wo die Seitenleiste dort ebenfalls zurücktritt.
  const mitLeiste = !["einstieg", "sitzung", "einstufungErgebnis"].includes(ansicht.name);
  const vorherigerFokus = document.activeElement;
  el().innerHTML = s() + (mitLeiste ? tableiste() : "");
  document.body.classList.toggle("mit-leiste", mitLeiste);
  bindeEreignisse();
  fokusSetzen(vorherigerFokus);
  window.scrollTo(0, 0);
}

/* Beim Neuzeichnen geht der Fokus verloren – wer ohne Maus arbeitet, stünde danach
   wieder am Seitenanfang. Deshalb: Bei einem echten Seitenwechsel bekommt die
   Überschrift den Fokus (Sprachausgaben lesen den neuen Bereich vor), innerhalb
   derselben Aufgabe dagegen der Knopf, der als Nächstes dran ist. */
let zuletztGezeigt = null;

function fokusSetzen(vorher) {
  const kennung = ansicht.name + "#" + (sitzung ? `${sitzung.index}:${sitzung.seite}` : "");
  const seitenwechsel = kennung !== zuletztGezeigt;
  zuletztGezeigt = kennung;

  if (seitenwechsel) {
    const kopf = el().querySelector("h1, .kopf .titel");
    if (kopf) {
      kopf.setAttribute("tabindex", "-1");
      kopf.focus({ preventScroll: true });
    }
    return;
  }
  // Innerhalb einer Aufgabe: dorthin, wo die Bedienung weitergeht.
  const weiter = hauptaktion();
  if (weiter) weiter.focus({ preventScroll: true });
  else if (vorher && vorher.id) document.getElementById(vorher.id)?.focus({ preventScroll: true });
}

/** Der Knopf, den Strg/⌘ + Enter auslöst – die naheliegende nächste Handlung. */
function hauptaktion() {
  for (const wahl of ["[data-theorie]", "[data-weiter]", "[data-pruefen]"]) {
    const knopf = document.querySelector(wahl);
    if (knopf && !knopf.disabled) return knopf;
  }
  return null;
}

/* Tastaturkürzel. Bewusst nicht ⌘ + 1 bis 5 wie in der Mac-App: Im Browser wechselt
   das die Browser-Tabs. Alt ist der Ersatz, den Browser freilassen. */
function tastenkuerzel(e) {
  const imTextfeld = /^(INPUT|TEXTAREA)$/.test((document.activeElement || {}).tagName || "");

  if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
    const knopf = hauptaktion();
    if (knopf) { e.preventDefault(); knopf.click(); }
    return;
  }
  if (e.key === "Escape") {
    const abbrechen = document.querySelector("[data-abbruch]");
    if (abbrechen) { e.preventDefault(); abbrechen.click(); }
    return;
  }
  if (e.altKey && /^[1-5]$/.test(e.key)) {
    const ziel = document.querySelectorAll(".leiste button")[Number(e.key) - 1];
    if (ziel) { e.preventDefault(); ziel.click(); }
    return;
  }
  // Zifferntasten wählen eine Antwort – aber nicht, während jemand tippt.
  if (!imTextfeld && !e.ctrlKey && !e.metaKey && !e.altKey && /^[1-4]$/.test(e.key)) {
    const wahl = document.querySelector(`[data-wahl="${Number(e.key) - 1}"]`);
    if (wahl && !wahl.disabled) { e.preventDefault(); wahl.click(); }
  }
}

function gehe(name, daten) { ansicht = Object.assign({ name }, daten || {}); zeichne(); }

function startSeite() {
  if (!stand.start) return einstiegSeite();
  const punkte = score();
  const naechste = naechsteLektion();
  const offen = schwaechen();
  const gelöst = Object.keys(stand.verlauf).length;
  const fertig = alleLektionen().filter((l) => (lektionErgebnis(l.id) || {}).bestanden).length;

  return h(`
    <h1>JavaQuest</h1>
    <p class="leise">Java lernen, Level für Level – jede Codezeile in Alltagssprache erklärt.</p>

    <div class="score">
      <div class="zahl">${punkte}</div>
      <div>${rang(punkte).symbol} ${rang(punkte).titel} · ${fertig} von ${alleLektionen().length} Lektionen</div>
      <div class="balken"><i style="width:${punkte / 10}%"></i></div>
      <div class="mini" style="color:rgba(255,255,255,.8);margin-top:8px">
        ${naechsterRang(punkte) ? `Noch ${naechsterRang(punkte).ab - punkte} Punkte bis „${naechsterRang(punkte).titel}“` : "Höchster Rang erreicht"}
        ${aktuelleSerie() ? ` · 🔥 ${aktuelleSerie()} ${aktuelleSerie() === 1 ? "Tag" : "Tage"} in Folge` : ""}
      </div>
    </div>

    ${naechste ? `
    <div class="karte">
      <div class="marken"><span class="marke stark">Weiter lernen</span></div>
      <h2>${sicher(naechste.title)}</h2>
      <p class="leise">${sicher(naechste.summary)}</p>
      <button class="knopf" data-lektion="${naechste.id}">Lektion starten</button>
    </div>` : `
    <div class="karte"><h2>Kurs geschafft!</h2><p class="leise">Alle Lektionen bestanden. Übe weiter im Training oder nach Themen.</p></div>`}

    ${offen.length ? `
    <div class="karte">
      <div class="marken"><span class="marke">Meine Schwächen</span></div>
      <h2>${offen.length} ${offen.length === 1 ? "Lernziel" : "Lernziele"} zum Nacharbeiten</h2>
      <p class="leise">Du bekommst nicht dieselbe Frage noch einmal, sondern eine andere Aufgabe zum gleichen Lernziel.</p>
      <div class="knopf-reihe">
        <button class="knopf zweit" data-start="schwaechen">Schwächen üben</button>
        <button class="knopf still" data-seite="schwaechen">Alle ansehen</button>
      </div>
    </div>` : ""}

    ${(() => {
      const anzahl = faelligeZiele(Date.now()).length;
      const termin = erinnerungsTermine(faelligkeiten(), Date.now())[0];
      const wann = termin ? new Date(termin.datum).toLocaleString("de-DE",
        { weekday: "short", day: "numeric", month: "numeric", hour: "2-digit", minute: "2-digit" }) : "";
      const kalender = termin ? `<button class="knopf still" data-kalender="1"
        aria-label="Erinnerung für ${sicher(wann)} Uhr in den Kalender eintragen">📅 Erinnerung in den Kalender (${sicher(wann)} Uhr)</button>` : "";
      if (anzahl) return `
    <div class="karte">
      <div class="marken"><span class="marke stark">Wiederholung</span></div>
      <h2>${anzahl} ${anzahl === 1 ? "Lernziel ist" : "Lernziele sind"} heute fällig</h2>
      <p class="leise">Was du kannst, wird in wachsenden Abständen abgefragt – erst am nächsten Tag,
      dann nach 3, 7, 16 und 35 Tagen. So bleibt es sitzen, ohne dass du dasselbe täglich übst.</p>
      <button class="knopf" data-start="wiederholung">Wiederholung starten</button>
      ${kalender}
    </div>`;
      return termin ? `
    <div class="karte">
      <div class="marken"><span class="marke">Wiederholung</span></div>
      <h2>Nächste Wiederholung: ${sicher(wann)} Uhr</h2>
      <p class="leise">Dann ${termin.anzahl === 1 ? "ist 1 Lernziel" : `sind ${termin.anzahl} Lernziele`} fällig.
      Ein Kalendereintrag erinnert dich rechtzeitig – die Web-App selbst kann das nicht.</p>
      ${kalender}
    </div>` : "";
    })()}

    <div class="karte">
      <h2>Üben</h2>
      <p class="leise">${uebbareAufgaben().length} Aufgaben über ${kurs.topics.length} Themen – jedes sofort übbar.</p>
      <div class="knopf-reihe">
        <button class="knopf zweit" data-start="training">Gemischt üben</button>
        <button class="knopf zweit" data-seite="themen">Themen wählen</button>
      </div>
      <button class="knopf still" data-seite="lektionen">Alle Lektionen ansehen</button>
    </div>

    <div class="karte">
      <h3>Dein Stand</h3>
      <p class="mini">${gelöst} Aufgaben bearbeitet · Bestanden ab ${Math.round(BESTANDEN_AB * 100)} %</p>
      <p class="mini">Der Fortschritt liegt nur auf diesem Gerät.</p>
    </div>
  `);
}

/** Erster Besuch: Vorkenntnisse ja oder nein – und bei ja eine kurze Einstufung. */
function einstiegSeite() {
  const anzahl = Math.min((kurs.placement || {}).questionsPerTest || 0, einstufungPool().length);
  const c = kurs.placement || {};
  return h(`
    <h1>Willkommen bei JavaQuest</h1>
    <p class="leise">Java lernen, Level für Level – jede Codezeile in Alltagssprache erklärt.
    Eine Frage vorweg, damit du an der richtigen Stelle anfängst.</p>
    ${(() => {
      // Direkt nach dem Zurücksetzen landet man hier – falls es ein Versehen war.
      const kopie = kopieVorZuruecksetzen();
      return kopie ? `
    <div class="karte">
      <h2>Doch nicht neu anfangen?</h2>
      <p class="leise">${sicher(kopieBeschreibung(kopie))}</p>
      <button class="knopf zweit" data-wiederherstellen="1">Stand von vorher wiederherstellen</button>
    </div>` : "";
    })()}

    <div class="karte">
      <h2>Ich habe 0 Erfahrung</h2>
      <p class="leise">Kein Problem. Du startest mit dem Grundkurs: kurze Theorie, jede Codezeile
      erklärt, sehr einfache Aufgaben.</p>
      <button class="knopf" data-einstieg="anfaenger">Mit dem Grundkurs starten</button>
    </div>

    ${anzahl ? `
    <div class="karte">
      <h2>Ich habe schon Vorkenntnisse</h2>
      <p class="leise">Beantworte ${anzahl} kurze Fragen. Sie passen sich an: Nach einer richtigen
      Antwort wird es schwerer, nach einer falschen leichter. Schwere Fragen zählen mehr.</p>
      <p class="mini">Ab ${c.passThreshold} % überspringst du den Grundkurs und startest bei den Objekten,
      ab ${c.advancedThreshold} % geht es direkt in den fortgeschrittenen Teil.</p>
      <button class="knopf zweit" data-einstieg="einstufung">Einstufung starten</button>
    </div>` : ""}

    <p class="mini">Der Fortschritt bleibt auf diesem Gerät. Du kannst jederzeit jedes Thema frei üben.</p>
  `);
}

function einstufungErgebnisSeite() {
  const { prozent, stufe, modulId, antworten } = ansicht;
  const modul = kurs.modules.find((m) => m.id === modulId);
  const ueberschrift = { advanced: "Das saß – großer Sprung!", intermediate: "Stark eingestuft!",
                         beginner: "Guter Startpunkt gefunden" }[stufe];
  const erklaerung = {
    advanced: `Auch die schweren Fragen saßen. Du startest direkt in „${modul.title}“ – alles davor wird dir angerechnet.`,
    intermediate: `Du startest direkt in „${modul.title}“. Die Lektionen davor werden dir angerechnet.`,
    beginner: `Für den Einstieg bei den Objekten reicht es noch nicht ganz. Du startest mit „${modul.title}“ – dort ist jede Codezeile erklärt.`,
  }[stufe];

  let html = h(`
    <div class="score">
      <div class="zahl">${prozent} %</div>
      <div>Bestanden ab ${kurs.placement.passThreshold} %</div>
      <div class="balken"><i style="width:${prozent}%"></i></div>
    </div>
    <div class="karte">
      <h2>${ueberschrift}</h2>
      <p class="leise">${sicher(erklaerung)}</p>
    </div>
    <div class="karte"><h3>Deine Antworten</h3>`);
  antworten.forEach((x, i) => {
    html += `<div class="erklaerzeile">
      <strong>${x.richtig ? "✓" : "✗"} Frage ${i + 1} · Niveau ${x.aufgabe.difficulty}/5</strong>
      <div class="mini">${sicher(x.aufgabe.prompt)}</div>
      <div class="mini">${x.richtig ? "richtig" : `richtig wäre: ${sicher(musterAntwortText(x.aufgabe))}`}</div>
    </div>`;
  });
  html += `</div><div class="karte"><button class="knopf" data-seite="start">Loslegen</button></div>`;
  return html;
}

/** Die Musterlösung als kurzer Text – für die Nachbesprechung der Einstufung. */
function musterAntwortText(a) {
  if (a.type === "singleChoice") return a.choices[a.correctIndex];
  if (a.type === "predictOutput") return a.expectedOutput;
  if (a.type === "fillBlank") return a.blanks.map((l, i) => `Lücke ${i + 1}: ${l.accepted[0]}`).join(" · ");
  return "siehe Musterlösung";
}

/** Die Leiste unten – dieselben fünf Bereiche wie die Seitenleiste der App. */
function tableiste() {
  const bereiche = [
    { seite: "start", titel: "Übersicht", symbol: "◎" },
    { seite: "lektionen", titel: "Lernpfad", symbol: "⌘" },
    { seite: "themen", titel: "Themen", symbol: "▦" },
    { seite: "analyse", titel: "Analyse", symbol: "◔" },
    { seite: "profil", titel: "Profil", symbol: "☺" },
  ];
  return `<nav class="leiste" aria-label="Bereiche">${bereiche.map((b, i) => {
    const aktiv = ansicht.name === b.seite;
    return `<button class="${aktiv ? "aktiv" : ""}" data-seite="${b.seite}"
       ${aktiv ? 'aria-current="page"' : ""}
       aria-label="${b.titel}${aktiv ? ", aktueller Bereich" : ""}. Tastenkürzel Alt plus ${i + 1}">
       <span class="zeichen" aria-hidden="true">${b.symbol}</span><span>${b.titel}</span>
     </button>`;
  }).join("")}</nav>`;
}

/** Analyse: Stärken, Wissenslücken und was noch unbekannt ist – wie in der App. */
function analyseSeite() {
  const gesamt = gesamtBeherrschung();
  let html = `<h1>Analyse</h1>`;

  if (gesamt === null) {
    return html + `<div class="karte"><h2>Noch keine Daten</h2>
      <p class="leise">Sobald du Aufgaben löst, zeigt dir die App hier Stärken und Wissenslücken.</p></div>`;
  }

  html += `<div class="score">
    <div class="zahl">${Math.round(gesamt * 100)} %</div>
    <div>Gesamte Beherrschung</div>
    <div class="balken"><i style="width:${gesamt * 100}%"></i></div>
  </div>
  <div class="karte">
    <h3>Wie das gerechnet wird</h3>
    <p class="leise">Gewichtet nach Niveau: Schwere Aufgaben zählen mehr. Wenige Antworten werden
    vorsichtig bewertet – ein einzelner Treffer macht noch keine Stärke.</p>
  </div>`;

  const gruppen = { staerke: [], aufbau: [], luecke: [], unbekannt: [] };
  for (const t of kurs.topics) {
    if (!uebbareAufgaben().some((a) => a.topicId === t.id)) continue;
    gruppen[themenStatus(t.id)].push(t);
  }

  for (const [status, themen] of Object.entries(gruppen)) {
    if (!themen.length) continue;
    html += `<div class="karte"><h3>${STATUS_SYMBOL[status]} ${STATUS_TITEL[status]} · ${themen.length}</h3>`;
    if (status === "staerke") html += `<p class="mini">Ab 75 % bei mindestens 3 Aufgaben.</p>`;
    if (status === "luecke") html += `<p class="mini">Unter 55 % bei mindestens 2 Aufgaben – hier lohnt sich Üben am meisten.</p>`;
    themen.forEach((t) => {
      const m = beherrschung(t.id);
      const gesehen = (stand.themen[t.id] || {}).gesehen || 0;
      html += `<button class="zeile" data-uebe="${t.id}">
        <span class="haupt"><strong>${sicher(t.title)}</strong>
        <span class="mini">${m === null ? "noch nicht geübt" : `${Math.round(m * 100)} % · ${gesehen} ${gesehen === 1 ? "Aufgabe" : "Aufgaben"}`}</span></span>
        <span class="mini aktion" aria-hidden="true">üben ›</span>
      </button>`;
    });
    html += `</div>`;
  }
  return html;
}

/** Profil: Lernprofil, Fortschritt, Datenschutz, Zurücksetzen – wie in der App. */
function profilSeite() {
  const punkte = score();
  const r = rang(punkte);
  const naechster = naechsterRang(punkte);
  const p = stand.profil || {};
  const stufenName = { beginner: "Anfänger", intermediate: "Leicht fortgeschritten", advanced: "Erfahren" };
  const modul = p.stufe ? (kurs.modules.find((m) => m.tier === p.stufe) || {}).title : null;
  const fertig = alleLektionen().filter((l) => (lektionErgebnis(l.id) || {}).bestanden).length;
  const serie = stand.serie || { laengste: 0 };
  const datum = p.seit ? new Date(p.seit).toLocaleDateString("de-DE", { day: "numeric", month: "long", year: "numeric" }) : "–";

  const zeile = (name, wert) => `<div class="erklaerzeile"><strong>${sicher(name)}</strong><div class="mini">${sicher(wert)}</div></div>`;

  return `<h1>Profil</h1>
    <div class="karte"><h3>Lernprofil</h3>
      ${zeile("Selbsteinschätzung", stufenName[p.selbsteinschaetzung] || "–")}
      ${p.einstufung !== null && p.einstufung !== undefined ? zeile("Einstufung", `${p.einstufung} %`) : ""}
      ${modul ? zeile("Eingestiegen bei", modul) : ""}
      ${zeile("Dabei seit", datum)}
    </div>
    <div class="karte"><h3>Fortschritt</h3>
      ${zeile("Java Master Score", `${punkte} / 1000`)}
      ${zeile("Rang", `${r.symbol} ${r.titel}${naechster ? ` · noch ${naechster.ab - punkte} bis ${naechster.titel}` : ""}`)}
      ${zeile("Aktuelle Serie", aktuelleSerie() === 1 ? "1 Tag" : `${aktuelleSerie()} Tage`)}
      ${zeile("Längste Serie", serie.laengste === 1 ? "1 Tag" : `${serie.laengste} Tage`)}
      ${zeile("Lektionen", `${fertig} von ${alleLektionen().length}`)}
    </div>
    <div class="karte"><h3>Bedienung ohne Maus</h3>
      <p class="leise">Mit der Tabulatortaste springst du von Element zu Element, der Fokus ist
      immer sichtbar umrandet.</p>
      ${zeile("Antwort wählen", "Tasten 1 bis 4")}
      ${zeile("Prüfen und weiter", "Strg + Enter (auf dem Mac ⌘ + Enter)")}
      ${zeile("Runde abbrechen", "Esc")}
      ${zeile("Bereich wechseln", "Alt + 1 bis Alt + 5")}
    </div>
    <div class="karte"><h3>🔒 Datenschutz</h3>
      <p class="leise">Alle Daten bleiben auf diesem Gerät. Kein Konto, kein Tracking, keine
      Übertragung – auch die Auswertung deiner Antworten läuft hier im Browser.</p>
    </div>
    <div class="karte"><h3>Fortschritt sichern</h3>
      <p class="leise">Dein Stand liegt nur in diesem Browser. Wer die Browserdaten löscht oder das
      Gerät wechselt, verliert ihn – es sei denn, er hat vorher eine Sicherung angelegt.</p>
      <button class="knopf zweit" data-sichern="1">Sicherung herunterladen</button>
      <button class="knopf zweit" data-einlesen="1">Sicherung einlesen</button>
      <input type="file" accept="application/json,.json" id="sicherung-datei" hidden
             aria-label="Sicherungsdatei auswählen">
      <p class="mini">Beim Einlesen wird nichts gelöscht: Aus beiden Ständen wird jeweils das
      bessere Ergebnis übernommen. Die Datei passt in jede Fassung: Web-App, Mac, iPhone und Windows.</p>
    </div>
    ${(() => {
      const kopie = kopieVorZuruecksetzen();
      if (!kopie) return "";
      return `
    <div class="karte"><h3>Stand vor dem Zurücksetzen</h3>
      <p class="leise">${sicher(kopieBeschreibung(kopie))}</p>
      <button class="knopf zweit" data-wiederherstellen="1">Wiederherstellen</button>
      <p class="mini">Nichts wird gelöscht: Was du seitdem gelernt hast, bleibt – von beiden Ständen gilt jeweils das bessere Ergebnis.</p>
    </div>`;
    })()}
    <div class="karte">
      <button class="knopf zweit" data-reset="1">Fortschritt zurücksetzen</button>
      <p class="mini">Score, Lernpfad und Analyse werden gelöscht. Danach startest du wieder mit dem Einstieg.</p>
    </div>`;
}

/* Sicherung des Fortschritts.

   Der Stand liegt nur im localStorage dieses Browsers. Gelöschte Browserdaten, ein
   neues Gerät oder der private Modus – und er ist weg, ohne Vorwarnung. Eine Datei
   zum Mitnehmen ist die einzige Absicherung, die ohne Konto und ohne Server auskommt. */
function sicherungHerunterladen() {
  const inhalt = JSON.stringify(sicherungsDatei(stand, Date.now()), null, 1);
  dateiHerunterladen(inhalt, "application/json", `javaquest-${new Date().toISOString().slice(0, 10)}.json`);
}

function dateiHerunterladen(inhalt, typ, name) {
  const url = URL.createObjectURL(new Blob([inhalt], { type: typ }));
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

/* ---------------------------------------------------------------- Austausch mit den Apps
   Mac-, iPhone- und Windows-App speichern jede einzelne Antwort (Aufgabe, Wertung,
   Zeitpunkt), die Web-App fasste lange nur je Aufgabe und Lernziel zusammen. Deshalb
   passte eine Sicherung von hier in keine App und umgekehrt – wer im Browser und am
   Mac lernte, hatte zwei getrennte Lernstände. Jetzt schreibt die Web-App ihre Sicherung
   im Aufbau der Apps und legt den eigenen Stand unter „web“ bei, damit Web → Web
   verlustfrei bleibt; die Apps übergehen dieses Feld. Gelesen werden beide Aufbauten
   und auch ältere Web-Sicherungen. Dieselbe Beispieldatei prüfen alle drei Testreihen
   (Tests/Sicherungen/). */

/** Zeitpunkt wie in den Apps: ISO 8601 ohne Sekundenbruchteile – der Apple-Decoder lehnt sie ab. */
const isoZeit = (ms) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, "Z");
const ausIsoZeit = (text) => (typeof text === "string" ? Date.parse(text) : NaN);

let verzeichnis = { kurs: null, aufgaben: {} };
/** Jede übbare Aufgabe mit ihrer Lektion – für Thema, Niveau und Lernziel beim Umwandeln. */
function aufgabeMitLektion(id) {
  if (verzeichnis.kurs !== kurs) {
    const aufgaben = {};
    for (const l of alleLektionen()) for (const a of l.tasks) aufgaben[a.id] = { aufgabe: a, lektionId: l.id };
    for (const a of kurs.taskPool || []) if (!aufgaben[a.id]) aufgaben[a.id] = { aufgabe: a, lektionId: null };
    verzeichnis = { kurs, aufgaben };
  }
  return verzeichnis.aufgaben[id] || null;
}

/** Die Sicherungsdatei: Aufbau der Apps, dazu der eigene Stand unter „web“. */
function sicherungsDatei(s, jetzt) {
  return { app: "JavaQuest", version: 1, erstellt: isoZeit(jetzt), stand: alsAppStand(s, jetzt), web: s };
}

/** Der Web-Stand im Aufbau von ProgressBackup.Stand (Apple) bzw. ProgressData (Windows). */
function alsAppStand(s, jetzt) {
  const attempts = [];
  const mitProtokoll = new Set();
  const versuch = (eintrag, credit, tries, datum, kontext) => ({
    taskId: eintrag.aufgabe.id,
    topicId: eintrag.aufgabe.topicId,
    lessonId: kontext === "lesson" ? eintrag.lektionId : null,
    context: kontext,
    difficulty: eintrag.aufgabe.difficulty,
    credit,
    solved: credit > 0,
    tries,
    date: isoZeit(datum),
  });
  for (const p of s.protokoll || []) {
    const eintrag = aufgabeMitLektion(p.taskId);
    if (!eintrag) continue;
    mitProtokoll.add(p.taskId);
    attempts.push(versuch(eintrag, p.credit, p.tries || 1, p.date, p.context || "training"));
  }
  // Ältere Stände ohne Protokoll: je Aufgabe der letzte bekannte Ausgang. Eine lange Serie
  // richtig beantworteter Varianten wird dabei kürzer – das Lernziel kommt in der App also
  // eher früher als später wieder dran, nie zu spät.
  for (const [id, v] of Object.entries(s.verlauf || {})) {
    const eintrag = aufgabeMitLektion(id);
    if (mitProtokoll.has(id) || !eintrag || !v.datum) continue;
    const wertung = v.wertung || 0;
    attempts.push(versuch(eintrag, wertung, wertung >= 1 ? 1 : 2, v.datum, eintrag.lektionId ? "lesson" : "training"));
  }
  attempts.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));

  const zuletzt = (pruefe) => {
    let max = 0;
    for (const [id, v] of Object.entries(s.verlauf || {})) {
      const eintrag = aufgabeMitLektion(id);
      if (eintrag && pruefe(eintrag) && v.datum > max) max = v.datum;
    }
    return max ? isoZeit(max) : null;
  };
  const lessonRecords = {};
  for (const [id, e] of Object.entries(s.lektionen || {})) {
    lessonRecords[id] = {
      bestAccuracy: e.quote || 0,
      lastAccuracy: e.quote || 0,
      playCount: e.viaEinstufung ? 0 : 1,
      isCompleted: !!e.bestanden,
      completedViaPlacement: !!e.viaEinstufung,
      firstCompletedAt: null,
      lastPlayedAt: zuletzt((a) => a.lektionId === id),
    };
  }
  const topicMasteries = {};
  for (const [id, t] of Object.entries(s.themen || {})) {
    topicMasteries[id] = {
      attempts: t.gesehen || 0,
      firstTryCorrect: t.richtig || 0,
      weightedCorrect: t.gewichtet || 0,
      weightedTotal: t.gesamt || 0,
      lastPracticedAt: zuletzt((a) => a.aufgabe.topicId === id),
    };
  }
  const profil = s.profil || {}, start = s.start || {}, serie = s.serie || null;
  const tag = Math.floor(jetzt / 86400000);
  const stufen = ["beginner", "intermediate", "advanced"];
  const fruehestes = attempts.length ? ausIsoZeit(attempts[0].date) : jetzt;
  return {
    schemaVersion: 1,
    createdAt: isoZeit(profil.seit || fruehestes),
    experienceLevel: stufen.includes(profil.selbsteinschaetzung) ? profil.selbsteinschaetzung : "beginner",
    placedLevel: stufen.includes(profil.stufe) ? profil.stufe : null,
    placementScore: Number.isFinite(profil.einstufung) ? Math.round(profil.einstufung) : null,
    onboardingCompleted: !!start.fertig,
    masterScore: score(s.lektionen),
    currentStreak: serie && serie.letzterTag !== null && tag - serie.letzterTag <= 1 ? serie.aktuell || 0 : 0,
    longestStreak: (serie && serie.laengste) || 0,
    lastActiveDay: serie && serie.letzterTag !== null ? isoZeit(serie.letzterTag * 86400000) : null,
    lessonRecords,
    topicMasteries,
    attempts,
    scoreHistory: [],
  };
}

/** Ein Stand aus einer App-Sicherung, umgerechnet in den Aufbau der Web-App. */
function ausAppStand(a) {
  const s = leererStand();
  // Die Einstufung bleibt außen vor – wie in den Apps sagt sie nichts darüber, ob ein Lernziel sitzt.
  s.protokoll = (a.attempts || [])
    .filter((v) => v.context !== "placement" && aufgabeMitLektion(v.taskId))
    .map((v) => ({ taskId: v.taskId, credit: Number(v.credit) || 0, tries: v.tries || 1,
                   date: ausIsoZeit(v.date), context: v.context || "training" }))
    .filter((v) => Number.isFinite(v.date))
    .sort((x, y) => x.date - y.date);
  for (const v of s.protokoll) bucheAntwort(s, aufgabeMitLektion(v.taskId).aufgabe, v.credit, v.date);
  for (const [id, r] of Object.entries(a.lessonRecords || {})) {
    if (!r.isCompleted && !r.playCount) continue;
    s.lektionen[id] = Object.assign({ quote: r.bestAccuracy || 0, bestanden: !!r.isCompleted },
                                    r.completedViaPlacement ? { viaEinstufung: true } : {});
  }
  const letzterTag = ausIsoZeit(a.lastActiveDay);
  // Gerundet statt abgeschnitten: Die Apps speichern den Tagesbeginn in Ortszeit, in
  // Deutschland also 22:00 Uhr am Vortag (UTC) – abgeschnitten wäre das ein Tag zu früh.
  s.serie = { aktuell: a.currentStreak || 0, laengste: a.longestStreak || 0,
              letzterTag: Number.isFinite(letzterTag) ? Math.round(letzterTag / 86400000) : null };
  if (a.placedLevel || Number.isFinite(a.placementScore)) {
    s.profil = { selbsteinschaetzung: a.experienceLevel, einstufung: a.placementScore,
                 stufe: a.placedLevel, seit: ausIsoZeit(a.createdAt) };
  }
  if (a.onboardingCompleted) s.start = { fertig: true, stufe: a.placedLevel || a.experienceLevel || "beginner" };
  return s;
}

/** Was in einer Datei steckt, im Aufbau der Web-App – oder null, wenn es keine Sicherung ist. */
function standAusDatei(daten) {
  if (!daten || daten.app !== "JavaQuest") return null;
  if (daten.web && typeof daten.web === "object" && daten.web.verlauf) return daten.web;            // von hier
  if (daten.stand && Array.isArray(daten.stand.attempts)) return ausAppStand(daten.stand);         // aus einer App
  if (daten.stand && typeof daten.stand === "object" && daten.stand.verlauf) return daten.stand;   // ältere Web-Sicherung
  return null;
}

/* Führt zwei Stände zusammen, statt einen zu überschreiben.

   Beim Einlesen darf nichts verlorengehen – weder das Gesicherte noch das, was seit
   der Sicherung dazugekommen ist. Deshalb gewinnt bei jeder Aufgabe das bessere
   Ergebnis, bei jedem Lernziel die längere Serie und bei der Tagesserie der höhere Wert. */
function staendeVereinen(eigen, fremd) {
  const neu = {
    lektionen: Object.assign({}, fremd.lektionen, eigen.lektionen),
    verlauf: Object.assign({}, fremd.verlauf),
    themen: Object.assign({}, fremd.themen, eigen.themen),
    ziele: Object.assign({}, fremd.ziele),
    serie: eigen.serie || fremd.serie || null,
    profil: eigen.profil || fremd.profil || null,
    start: eigen.start || fremd.start || null,
    protokoll: protokolleVereinen(eigen.protokoll, fremd.protokoll),
  };
  // Lektionen: die bessere Quote gewinnt, und einmal bestanden bleibt bestanden.
  // (Das Feld heißt quote, nicht wertung – siehe merkeLektion weiter unten.)
  for (const [id, e] of Object.entries(eigen.lektionen || {})) {
    const f = (fremd.lektionen || {})[id];
    if (!f) continue;
    const besser = (f.quote || 0) > (e.quote || 0) ? f : e;
    neu.lektionen[id] = Object.assign({}, besser, { bestanden: !!(e.bestanden || f.bestanden) });
  }
  // Aufgaben: die bessere Wertung gewinnt, bei Gleichstand der jüngere Eintrag.
  for (const [id, e] of Object.entries(eigen.verlauf || {})) {
    const f = neu.verlauf[id];
    if (!f) { neu.verlauf[id] = e; continue; }
    if ((e.wertung || 0) > (f.wertung || 0)) neu.verlauf[id] = e;
    else if ((e.wertung || 0) === (f.wertung || 0) && (e.datum || "") >= (f.datum || "")) neu.verlauf[id] = e;
  }
  // Lernziele: die längere Serie und die höhere Zahl an Versuchen.
  for (const [id, e] of Object.entries(eigen.ziele || {})) {
    const f = neu.ziele[id];
    if (!f) { neu.ziele[id] = e; continue; }
    neu.ziele[id] = {
      versuche: Math.max(e.versuche || 0, f.versuche || 0),
      serie: Math.max(e.serie || 0, f.serie || 0),
      wertung: Math.max(e.wertung || 0, f.wertung || 0),
      datum: (e.datum || "") >= (f.datum || "") ? e.datum : f.datum,
    };
  }
  // Tagesserie: der höhere Bestwert bleibt.
  if (eigen.serie && fremd.serie) {
    neu.serie = Object.assign({}, eigen.serie, {
      laengste: Math.max(eigen.serie.laengste || 0, fremd.serie.laengste || 0),
    });
  }
  return neu;
}

/* ---------------------------------------------------------------- Zurücksetzen mit Netz
   „Fortschritt zurücksetzen“ löschte sofort und endgültig. Jetzt bleibt vorher eine Kopie
   liegen – im Aufbau der Sicherungsdatei – und lässt sich im Profil wiederherstellen.
   Dieselbe Regel in der Apple- und der Windows-Fassung: eine Kopie nur, wenn es etwas zu
   verlieren gibt, und wiederhergestellt wird zusammengeführt, nicht ersetzt. */
const VOR_ZURUECKSETZEN = "javaquest-vor-zuruecksetzen";

function hatFortschritt(s) {
  return Object.keys((s && s.verlauf) || {}).length > 0 || Object.keys((s && s.lektionen) || {}).length > 0;
}

function fortschrittZuruecksetzen(jetzt = Date.now()) {
  if (hatFortschritt(stand)) {
    try { localStorage.setItem(VOR_ZURUECKSETZEN, JSON.stringify(sicherungsDatei(stand, jetzt))); } catch (e) { /* voll oder gesperrt */ }
  }
  stand = leererStand();
  try { localStorage.removeItem("javaquest"); } catch (e) { /* gesperrt: dann bleibt es bei der Sitzung */ }
}

/** Die Kopie vom letzten Zurücksetzen – oder null. */
function kopieVorZuruecksetzen() {
  try {
    const roh = localStorage.getItem(VOR_ZURUECKSETZEN);
    const daten = roh ? JSON.parse(roh) : null;
    const s = standAusDatei(daten);
    return s ? { datum: Date.parse(daten.erstellt), stand: s } : null;
  } catch (e) { return null; }
}

/** „Vom 24.09.2026, 10:20 Uhr · 8 Lektionen bestanden · 102 Aufgaben“ – wie in den Apps. */
function kopieBeschreibung(kopie) {
  const wann = new Date(kopie.datum).toLocaleString("de-DE",
    { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
  const lektionen = Object.values(kopie.stand.lektionen).filter((l) => l.bestanden).length;
  const aufgaben = Object.keys(kopie.stand.verlauf).length;
  return `Vom ${wann} Uhr · ${lektionen} ${lektionen === 1 ? "Lektion" : "Lektionen"} bestanden · `
    + `${aufgaben} ${aufgaben === 1 ? "Aufgabe" : "Aufgaben"}`;
}

/** Führt die Kopie mit dem jetzigen Stand zusammen; danach wird sie nicht mehr angeboten. */
function vorZuruecksetzenWiederherstellen() {
  const kopie = kopieVorZuruecksetzen();
  if (!kopie) return false;
  stand = staendeVereinen(stand, kopie.stand);
  sichern();
  try { localStorage.removeItem(VOR_ZURUECKSETZEN); } catch (e) { /* bleibt eben liegen */ }
  return true;
}

/** Beide Protokolle, ohne Doppelte. Auf die Sekunde genau: So weit reicht die Zeit in App-Dateien. */
function protokolleVereinen(a, b) {
  const gesehen = new Set();
  return [...(a || []), ...(b || [])]
    .filter((p) => {
      const kennung = `${p.taskId}|${Math.floor(p.date / 1000)}|${p.context}`;
      if (gesehen.has(kennung)) return false;
      gesehen.add(kennung);
      return true;
    })
    .sort((x, y) => x.date - y.date);
}

function sicherungEinlesen(datei) {
  const leser = new FileReader();
  leser.onload = () => {
    let daten;
    try { daten = JSON.parse(String(leser.result)); } catch (e) { daten = null; }
    const fremd = standAusDatei(daten);
    if (!fremd) {
      melde("Das sieht nicht nach einer JavaQuest-Sicherung aus.");
      return;
    }
    const vorher = Object.keys(stand.verlauf || {}).length;
    stand = staendeVereinen(stand, fremd);
    sichern();
    const nachher = Object.keys(stand.verlauf).length;
    melde(`Sicherung eingelesen: ${nachher - vorher} Aufgabe(n) dazugekommen, nichts gelöscht.`);
    zeichne();
  };
  leser.readAsText(datei);
}

/** Kurze Rückmeldung, die auch eine Sprachausgabe vorliest. */
function melde(text) {
  let kasten = document.getElementById("meldung");
  if (!kasten) {
    kasten = document.createElement("div");
    kasten.id = "meldung";
    kasten.className = "meldung";
    kasten.setAttribute("role", "status");
    document.body.appendChild(kasten);
  }
  kasten.textContent = text;
  kasten.hidden = false;
  setTimeout(() => { kasten.hidden = true; }, 6000);
}

function lektionenSeite() {
  const lektionen = alleLektionen();
  const stufenName = { beginner: "Grundkurs", intermediate: "Aufbau", advanced: "Fortgeschritten" };
  let html = `<h1>Lernpfad</h1>
    <p class="leise">Eine Lektion wird frei, sobald die davor bestanden ist. Frei üben kannst du jedes Thema jederzeit.</p>`;
  kurs.modules.forEach((m) => {
    const fertig = m.lessons.filter((l) => (lektionErgebnis(l.id) || {}).bestanden).length;
    const anteil = fertig / m.lessons.length;
    html += `<div class="karte">
      <div class="marken"><span class="marke">${stufenName[m.tier] || m.tier}</span>
        <span class="marke ${fertig === m.lessons.length ? "stark" : ""}">${fertig}/${m.lessons.length} Lektionen</span></div>
      <h3>${sicher(m.title)}</h3><p class="mini">${sicher(m.subtitle)}</p>
      <div class="balken" style="margin:10px 0 4px"><i style="width:${anteil * 100}%"></i></div>`;
    m.lessons.forEach((l) => {
      const index = lektionen.findIndex((x) => x.id === l.id);
      const e = lektionErgebnis(l.id);
      const frei = istFrei(index);
      const zustand = e && e.bestanden ? "fertig" : (frei ? "offen" : "");
      const st = e && e.bestanden ? sterne(e.quote) : 0;
      html += `<button class="zeile" data-lektion="${l.id}" ${frei ? "" : "disabled"}>
        <span class="punkt ${zustand}">${e && e.bestanden ? "✓" : (frei ? "▸" : "🔒")}</span>
        <span class="haupt"><strong>${sicher(l.title)}</strong>
        <span class="mini">${e ? `Bestwert ${Math.round(e.quote * 100)} %` : `${l.tasks.length} Aufgaben · ${l.estimatedMinutes} Min.`}</span></span>
        ${st ? `<span class="sterne">${"★".repeat(st)}${"☆".repeat(3 - st)}</span>` : ""}
      </button>`;
    });
    html += `</div>`;
  });
  return html;
}

function themenSeite() {
  const gewaehlt = ansicht.gewaehlt || [];
  const niveaus = ansicht.niveaus || [];
  const anzahl = ansicht.anzahl || 10;
  const passend = uebbareAufgaben().filter((a) =>
    (!gewaehlt.length || gewaehlt.includes(a.topicId)) && (!niveaus.length || niveaus.includes(a.difficulty))).length;

  let html = `<h1>Such dir aus, was du üben willst</h1>
    <p class="leise">Ohne Auswahl kommt alles gemischt. Jedes Thema ist sofort übbar – auch wenn die Lektion noch nicht dran war.</p>
    <div class="karte">
      <h3>Niveau</h3><p class="mini">Ohne Auswahl: alle Niveaus</p>
      <div class="chips" role="group" aria-label="Niveau auswählen">${[1, 2, 3, 4, 5].map((n) =>
        `<button class="chip ${niveaus.includes(n) ? "aktiv" : ""}" data-niveau="${n}"
          aria-pressed="${niveaus.includes(n)}" aria-label="Niveau ${n}">${n}</button>`).join("")}</div>
      <h3 style="margin-top:14px">Wie viele Aufgaben?</h3>
      <div class="chips" role="group" aria-label="Anzahl der Aufgaben">${[5, 10, 15, 25].map((n) =>
        `<button class="chip ${anzahl === n ? "aktiv" : ""}" data-anzahl="${n}"
          aria-pressed="${anzahl === n}" aria-label="${n} Aufgaben">${n}</button>`).join("")}</div>
      ${gewaehlt.length ? `<button class="knopf still" data-zuruecksetzen="1">Auswahl zurücksetzen</button>` : ""}
    </div>
    <div class="gitter">`;
  kurs.topics.forEach((t) => {
    const anzahl = uebbareAufgaben().filter((a) => a.topicId === t.id).length;
    if (!anzahl) return;
    const m = beherrschung(t.id);
    const aktiv = gewaehlt.includes(t.id);
    const st = stufen(t.id);
    // Je Stufe getrennt: Ein Thema kann unten sitzen und oben wackeln.
    const leiste = st.length ? `<span class="stufen">${st.map((x) =>
      `<span class="stufe ${x.wacklig ? "wacklig" : ""}" title="Stufe ${x.stufe}: ${x.geloest} von ${x.gesehen} richtig">${x.stufe}<i>${x.geloest}/${x.gesehen}</i></span>`).join("")}</span>` : "";
    const wacklig = st.filter((x) => x.wacklig);
    html += `<button class="kachel ${aktiv ? "aktiv" : ""}" data-thema="${t.id}" aria-pressed="${aktiv}"
      aria-label="${sicher(t.title)}, ${anzahl} Aufgaben${aktiv ? ", ausgewählt" : ""}">
      <strong>${sicher(t.title)}</strong>
      <span class="mini">${anzahl} Aufgaben${m === null ? "" : ` · ${Math.round(m * 100)} %`}</span>
      ${leiste}
      ${wacklig.length ? `<span class="mini warn">Es hakt ab Stufe ${wacklig[0].stufe} – die leichteren sitzen.</span>` : ""}
    </button>`;
  });
  html += `</div><div class="karte">
    <p class="leise">${passend === 0
      ? "Zu dieser Auswahl gibt es keine Aufgaben – nimm ein Niveau dazu."
      : `${Math.min(anzahl, passend)} von ${passend} passenden Aufgaben · Niveau: ${niveaus.length ? niveaus.slice().sort().join(", ") : "alle"}`}</p>
    <button class="knopf" data-start="themen" ${passend === 0 ? "disabled" : ""}>${gewaehlt.length ? `${gewaehlt.length} Thema/Themen üben` : "Gemischt üben"}</button>
  </div>`;
  return html;
}

function schwaechenSeite() {
  const offen = schwaechen();
  let html = `<div class="kopf"><button class="zurueck" data-seite="start" aria-label="Zurück zur Übersicht">‹</button><span class="titel">Meine Schwächen</span></div>`;
  if (!offen.length) {
    return html + `<div class="karte"><h2>Alles sitzt</h2><p class="leise">Was du zuletzt geübt hast, hat im ersten Anlauf gesessen.</p></div>`;
  }
  html += `<div class="karte">`;
  offen.forEach((s) => {
    const t = thema(s.aufgabe.topicId);
    html += `<div class="erklaerzeile">
      <strong>${sicher(s.aufgabe.prompt)}</strong>
      <div class="mini">${sicher(t ? t.title : s.aufgabe.topicId)} · ${s.wertung === 0 ? "zuletzt nicht gelöst" : "erst im zweiten Anlauf"} · ${s.varianten - 1} andere Aufgabe(n) dazu</div>
    </div>`;
  });
  html += `</div><div class="karte"><button class="knopf" data-start="schwaechen">Schwächen üben</button></div>`;
  return html;
}

// ---------------------------------------------------------------- Lern-Loop
function starteLektion(id) {
  const lektion = alleLektionen().find((l) => l.id === id);
  sitzung = { titel: lektion.title, lektionId: id, theorie: lektion.theory || [], seite: 0,
              aufgaben: lektionsAufgaben(lektion), index: 0, versuche: 0, ergebnis: null,
              aufgedeckt: false, entwurf: null, ergebnisse: [] };
  gehe("sitzung");
}

function starteRunde(art, themen) {
  let topf, titel;
  const niveaus = ansicht.niveaus || [];
  const wunschAnzahl = ansicht.anzahl || RUNDE;
  if (art === "schwaechen") {
    const gruppen = new Set(schwaechen().map((s) => s.gruppe));
    topf = uebbareAufgaben().filter((a) => gruppen.has(gruppe(a)));
    titel = "Meine Schwächen";
  } else if (art === "wiederholung") {
    const gruppen = new Set(faelligeZiele(Date.now()));
    topf = uebbareAufgaben().filter((a) => gruppen.has(gruppe(a)));
    titel = "Wiederholung";
  } else if (art === "themen") {
    const gewaehlt = themen && themen.length ? themen : null;
    topf = uebbareAufgaben().filter((a) =>
      (!gewaehlt || gewaehlt.includes(a.topicId)) && (!niveaus.length || niveaus.includes(a.difficulty)));
    titel = gewaehlt
      ? "Üben: " + gewaehlt.map((t) => (thema(t) || {}).title).filter(Boolean).join(", ")
      : "Gemischt üben";
  } else {
    topf = uebbareAufgaben();
    titel = "Gemischt üben";
  }
  if (!topf.length) return;
  sitzung = { titel, lektionId: null, art, theorie: [], seite: 0,
              aufgaben: runde(topf, art === "themen" ? wunschAnzahl : RUNDE),
              index: 0, versuche: 0, ergebnis: null, aufgedeckt: false, entwurf: null, ergebnisse: [] };
  gehe("sitzung");
}

const aktuelleAufgabe = () => sitzung.aufgaben[sitzung.index];

function sitzungSeite() {
  if (sitzung.seite < sitzung.theorie.length) return theorieSeite();
  if (sitzung.index >= sitzung.aufgaben.length) return auswertungSeite();
  return aufgabenSeite();
}

function theorieSeite() {
  const karte = sitzung.theorie[sitzung.seite];
  return h(`
    <div class="kopf"><button class="zurueck" data-abbruch="1" aria-label="Runde abbrechen, Taste Escape">✕</button>
      <span class="titel">${sicher(sitzung.titel)}</span>
      <span class="mini">Happen ${sitzung.seite + 1}/${sitzung.theorie.length}</span></div>
    <div class="karte">
      <h2>${sicher(karte.title)}</h2>
      <p>${sicher(karte.body)}</p>
      ${umlDiagramm(karte.diagram)}
      ${codeBlock(karte.code)}
      ${exegese(karte.code, "Code Zeile für Zeile erklären")}
      ${karte.callout ? `<div class="kasten ${karte.callout.kind === "warning" ? "falsch" : "richtig"}">${sicher(karte.callout.text)}</div>` : ""}
    </div>
    <button class="knopf" data-theorie="weiter">Weiter</button>
  `);
}

function aufgabenSeite() {
  const a = aktuelleAufgabe();
  const fertig = (sitzung.ergebnis && sitzung.ergebnis.richtig) || sitzung.aufgedeckt;
  const niveau = ["", "Sehr leicht", "Leicht", "Mittel", "Anspruchsvoll", "Schwer"][a.difficulty];
  const t = thema(a.topicId);

  let eingabe = "";
  if (a.type === "singleChoice") {
    const knoepfe = a.choices.map((c, i) => {
      let klasse = "antwort";
      let zusatz = "";
      if (fertig && i === a.correctIndex) { klasse += " richtig"; zusatz = ", richtige Antwort"; }
      else if (sitzung.entwurf === i) {
        const daneben = sitzung.ergebnis && !sitzung.ergebnis.richtig;
        klasse += daneben ? " falsch" : " gewaehlt";
        if (daneben) zusatz = ", war leider falsch";
      }
      // aria-checked statt reiner Farbe: Ohne Zustand wüsste eine Sprachausgabe nicht,
      // welche Antwort gewählt ist – die Umrandung allein sieht sie nicht.
      return `<button class="${klasse}" data-wahl="${i}" role="radio"
        aria-checked="${sitzung.entwurf === i ? "true" : "false"}"
        aria-label="Antwort ${"ABCD"[i]}: ${sicher(c)}${zusatz}. Tastenkürzel ${i + 1}"
        ${fertig ? "disabled" : ""}>
        <span class="buchstabe" aria-hidden="true">${"ABCD"[i]}</span><span>${sicher(c)}</span></button>`;
    }).join("");
    eingabe = `<div role="radiogroup" aria-label="Antwortmöglichkeiten">${knoepfe}</div>`;
  } else if (a.type === "fillBlank") {
    eingabe = a.blanks.map((_, i) => `<div class="luecke"><span class="nummer" aria-hidden="true">${i + 1}</span>
      <input type="text" data-luecke="${i}" value="${sicher((sitzung.entwurf || [])[i] || "")}" ${fertig ? "disabled" : ""}
        aria-label="Lücke ${i + 1} von ${a.blanks.length}" placeholder="Lücke ${i + 1}"
        autocapitalize="off" autocorrect="off" spellcheck="false"></div>`).join("");
  } else if (a.type === "predictOutput") {
    eingabe = `<textarea class="konsole" data-text="1" ${fertig ? "disabled" : ""}
      aria-label="Erwartete Ausgabe, Zeile für Zeile" placeholder="Ausgabe Zeile für Zeile eintippen …"
      autocapitalize="off" autocorrect="off" spellcheck="false">${sicher(sitzung.entwurf || "")}</textarea>`;
  } else {
    const start = (a.starterCode && a.starterCode.lines.map((z) => z.code).join("\n")) || "";
    eingabe = `<textarea data-text="1" ${fertig ? "disabled" : ""} aria-label="Dein Java-Code"
      autocapitalize="off" autocorrect="off" spellcheck="false">${sicher(sitzung.entwurf === null ? start : sitzung.entwurf)}</textarea>`;
  }

  const zeigeCode = a.code && (a.type === "singleChoice" || a.type === "predictOutput");
  const vorlage = a.type === "fillBlank" ? (fertig ? geloesteVorlage(a) : a.template) : null;
  // Wie in den Apps: Die Erklärung lässt sich schon vor dem Antworten aufklappen. Nur im
  // Einstufungstest nicht – dort soll gemessen werden, was schon sitzt.
  const erklaeren = !sitzung.einstufung;

  return h(`
    <div class="kopf"><button class="zurueck" data-abbruch="1" aria-label="Runde abbrechen, Taste Escape">✕</button>
      <span class="titel">${sicher(sitzung.titel)}</span>
      <span class="mini">${sitzung.einstufung
        ? `Frage ${sitzung.einstufung.antworten.length + 1} von ${sitzung.einstufung.anzahl}`
        : `${sitzung.index + 1}/${sitzung.aufgaben.length}`}</span></div>
    <div class="balken" style="margin-bottom:14px" role="progressbar"
         aria-label="Fortschritt in dieser Runde"
         aria-valuemin="0" aria-valuemax="${sitzung.einstufung ? sitzung.einstufung.anzahl : sitzung.aufgaben.length}"
         aria-valuenow="${sitzung.einstufung ? sitzung.einstufung.antworten.length : sitzung.index}"><i style="width:${sitzung.einstufung
      ? (sitzung.einstufung.antworten.length / sitzung.einstufung.anzahl) * 100
      : (sitzung.index / sitzung.aufgaben.length) * 100}%"></i></div>

    <div class="karte">
      <div class="marken">
        <span class="marke stark">Niveau ${a.difficulty}/5 · ${niveau}</span>
        ${t ? `<span class="marke">${sicher(t.title)}</span>` : ""}
      </div>
      <h2>${sicher(a.prompt)}</h2>
      ${umlDiagramm(a.diagram)}
      ${zeigeCode ? codeBlock(a.code) : ""}
      ${vorlage ? codeBlock(vorlage) : ""}
      ${a.javaContext && a.type === "code" ? `<p class="mini">${sicher({ statements: "Schreibe nur die Anweisungen – der main-Block ist schon da.", members: "Schreibe die Methoden bzw. Felder innerhalb der Klasse.", file: "Schreibe den vollständigen Code inklusive Klassen." }[a.javaContext])}</p>` : ""}
      ${a.type === "code" && a.expectedOutput ? `<p class="mini">Erwartete Ausgabe:</p><pre class="code">${sicher(a.expectedOutput)}</pre>` : ""}
      ${eingabe}
      ${erklaeren && zeigeCode ? exegese(a.code, "Code Zeile für Zeile erklären") : ""}
      ${erklaeren && vorlage ? exegese(vorlage, "Code Zeile für Zeile erklären", !fertig) : ""}
      ${erklaeren && a.type === "code" && !fertig ? exegese(a.starterCode, "Startcode Zeile für Zeile erklärt") : ""}
      ${fertig && a.type === "code" ? exegese(a.sampleSolution, "Musterlösung Zeile für Zeile") : ""}
    </div>

    ${rueckmeldung(a, fertig)}

    <p class="kuerzel">Ohne Maus: <kbd>1</kbd>–<kbd>4</kbd> wählt eine Antwort,
       <kbd>Strg</kbd>+<kbd>Enter</kbd> prüft und geht weiter, <kbd>Esc</kbd> bricht ab.</p>

    <div class="knopf-reihe">
      ${sitzung.einstufung
        ? `<button class="knopf" data-pruefen="1">${sitzung.einstufung.antworten.length + 1 === sitzung.einstufung.anzahl ? "Antwort abgeben & auswerten" : "Antwort abgeben"}</button>`
        : fertig
        ? `<button class="knopf" data-weiter="1">${sitzung.index + 1 < sitzung.aufgaben.length ? "Weiter" : "Zur Auswertung"}</button>`
        : `${sitzung.ergebnis ? `<button class="knopf zweit" data-aufdecken="1">Lösung zeigen</button>` : ""}
           <button class="knopf" data-pruefen="1">${sitzung.ergebnis ? "Erneut prüfen" : "Prüfen"}</button>`}
    </div>
  `);
}

function rueckmeldung(a, fertig) {
  const e = sitzung.ergebnis;
  // In der Einstufung gibt es zwischendurch keine Rückmeldung – die Auswertung kommt am Ende.
  if (sitzung.einstufung) return "";
  if (!e && !sitzung.aufgedeckt) return "";
  const richtig = e && e.richtig;
  const klasse = richtig ? "gut" : (sitzung.aufgedeckt ? "auf" : "schlecht");
  const rest = MAX_VERSUCHE - sitzung.versuche;

  // Wer nach einem Fehlversuch und dem Tipp selbst draufkommt, hat mehr geleistet als
  // wer es gleich wusste. Das soll auch so klingen.
  function kopfzeile() {
    if (!richtig) return sitzung.aufgedeckt ? "Lösung aufgedeckt" : "Noch nicht ganz";
    if (sitzung.versuche === 1) return "Richtig – volle Punktzahl!";
    if (sitzung.versuche === 2) return "Stark – nach dem Tipp selbst draufgekommen!";
    return `Geschafft – im ${sitzung.versuche}. Anlauf, ohne die Lösung aufzudecken.`;
  }
  let kopf = kopfzeile();
  let unter = richtig ? (sitzung.versuche === 1 ? "Das zählt voll." : "Das zählt zur Hälfte.")
                      : (sitzung.aufgedeckt ? "Schau dir die Lösung in Ruhe an – beim nächsten Mal klappt’s."
                                            : (rest > 0 ? `Du hast noch ${rest} ${rest === 1 ? "Versuch" : "Versuche"}.` : "Keine Versuche mehr – unten steht, woran es lag."));

  // role="status" sorgt dafür, dass Sprachausgaben die Rückmeldung von selbst vorlesen –
  // sonst bliebe sie unbemerkt, weil der Fokus beim Knopf stehen bleibt.
  let html = `<div class="rueck ${klasse}" role="status" aria-live="polite"><h3>${kopf}</h3><p class="leise">${unter}</p>`;

  // Warum die gewählte Antwort nicht stimmt – und was richtig gewesen wäre.
  if (!richtig && a.type === "singleChoice" && sitzung.entwurf !== null && sitzung.entwurf !== a.correctIndex) {
    const grund = (a.whyWrong || [])[sitzung.entwurf];
    html += `<div class="kasten falsch"><strong>Deine Antwort: ${sicher(a.choices[sitzung.entwurf])}</strong>${grund ? `<p class="leise" style="margin-top:6px">${sicher(grund)}</p>` : ""}</div>`;
  }
  if (!richtig && (fertig || rest === 0)) {
    let loesung = null;
    if (a.type === "singleChoice") loesung = a.choices[a.correctIndex];
    else if (a.type === "predictOutput") loesung = "die Ausgabe\n" + a.expectedOutput;
    else if (a.type === "fillBlank") loesung = a.blanks.map((l, i) => `Lücke ${i + 1}: ${l.accepted[0]}`).join(" · ");
    if (loesung) html += `<div class="kasten richtig"><strong>Richtig wäre: ${sicher(loesung)}</strong></div>`;
  }

  if (e && !sitzung.aufgedeckt) {
    (e.befunde || []).slice(0, 5).forEach((b) => {
      const zeichen = b.art === "gut" ? "✓" : (b.art === "tipp" ? "💡" : "✗");
      html += `<div class="befund"><span>${zeichen}</span><span>${sicher(b.text)}</span></div>`;
    });
  }
  if (richtig || sitzung.aufgedeckt || rest === 0) {
    html += `<div style="margin-top:12px"><strong>Erklärung</strong><p class="leise">${sicher(a.explanation)}</p></div>`;
  } else if (a.hint) {
    html += `<div class="kasten falsch" style="margin-top:12px">💡 ${sicher(a.hint)}</div>`;
    // Ab dem zweiten Fehlversuch wird der Tipp konkreter, statt sich zu wiederholen.
    if (sitzung.versuche >= 2) {
      const mehr = zweiterTipp(a, a.type === "singleChoice" ? sitzung.entwurf : null);
      if (mehr) html += `<div class="kasten falsch" style="margin-top:8px">💡💡 ${sicher(mehr)}</div>`;
    }
  }
  return html + `</div>`;
}

function auswertungSeite() {
  const gesamt = sitzung.ergebnisse.reduce((s, r) => s + r.gewicht, 0);
  const erreicht = sitzung.ergebnisse.reduce((s, r) => s + r.gewicht * r.wertung, 0);
  const quote = gesamt ? erreicht / gesamt : 0;
  const bestanden = quote >= BESTANDEN_AB;
  const ersterVersuch = sitzung.ergebnisse.filter((r) => r.wertung >= 1 && r.versuche === 1).length;

  const vorher = score();
  if (sitzung.lektionId) {
    const alt = lektionErgebnis(sitzung.lektionId);
    if (!alt || quote > alt.quote) {
      stand.lektionen[sitzung.lektionId] = { quote, bestanden: bestanden || (alt && alt.bestanden) || false };
      sichern();
    }
  }
  const zuwachs = score() - vorher;
  const st = sitzung.lektionId && bestanden ? sterne(quote) : 0;

  return h(`
    <div class="kopf"><span class="titel">${sicher(sitzung.titel)}</span></div>
    <div class="karte" style="text-align:center">
      <div style="font-size:52px">${bestanden ? "🏆" : "🔁"}</div>
      <h1>${sitzung.lektionId ? (bestanden ? "Lektion gemeistert!" : "Fast geschafft!") : "Runde geschafft"}</h1>
      <p class="leise">${sitzung.lektionId && !bestanden
        ? `Ab ${Math.round(BESTANDEN_AB * 100)} % gilt eine Lektion als bestanden. Wiederhole sie – es zählt immer dein Bestwert.`
        : "Was noch hakt, kommt in den nächsten Runden öfter dran – so lange, bis es sitzt."}</p>
      ${sitzung.lektionId ? `<div class="sterne gross">${"★".repeat(st)}${"☆".repeat(3 - st)}</div>` : ""}
      <div class="gitter" style="margin-top:14px">
        <div class="kachel"><strong>${Math.round(quote * 100)} %</strong><span class="mini">Trefferquote</span></div>
        <div class="kachel"><strong>${ersterVersuch}/${sitzung.ergebnisse.length}</strong><span class="mini">beim ersten Versuch</span></div>
        ${zuwachs > 0 ? `<div class="kachel"><strong>+${zuwachs}</strong><span class="mini">Score</span></div>` : ""}
      </div>
    </div>
    <div class="knopf-reihe">
      ${sitzung.lektionId ? "" : `<button class="knopf zweit" data-nochmal="1">Noch eine Runde</button>`}
      <button class="knopf" data-seite="start">Zur Übersicht</button>
    </div>
  `);
}

// ---------------------------------------------------------------- Eingaben
function entwurfLesen(a) {
  if (a.type === "singleChoice") return sitzung.entwurf;
  if (a.type === "fillBlank") return [...document.querySelectorAll("[data-luecke]")].map((i) => i.value);
  const feld = document.querySelector("[data-text]");
  return feld ? feld.value : "";
}

function pruefen() {
  const a = aktuelleAufgabe();
  const antwort = entwurfLesen(a);
  if (a.type === "singleChoice" && antwort === null) return;
  if (a.type !== "singleChoice" && !String(Array.isArray(antwort) ? antwort.join("") : antwort).trim()) return;
  sitzung.entwurf = antwort;
  sitzung.versuche += 1;
  sitzung.ergebnis = auswerten(a, antwort);
  if (sitzung.einstufung) return einstufungAntwortAbgeben(a, sitzung.ergebnis);
  if (sitzung.ergebnis.richtig) abschliessen(sitzung.versuche === 1 ? 1 : 0.5);
  zeichne();
}

/** Eine Einstufungsantwort: keine Rückmeldung, Zielniveau anpassen, nächste Frage holen. */
function einstufungAntwortAbgeben(aufgabe, ergebnis) {
  const test = sitzung.einstufung;
  test.antworten.push({ aufgabe, wertung: ergebnis.wertung, richtig: ergebnis.richtig });
  test.ziel = Math.min(5, Math.max(1, aufgabe.difficulty + (ergebnis.richtig ? 1 : -1)));
  const naechste = test.antworten.length < test.anzahl ? naechsteEinstufungsfrage(test) : null;
  if (naechste) {
    sitzung.aufgaben.push(naechste);
    sitzung.index += 1;
    sitzung.versuche = 0;
    sitzung.ergebnis = null;
    sitzung.entwurf = null;
    zeichne();
  } else {
    einstufungAbschliessen();
  }
}

/** Ergebnis festhalten und die übersprungenen Lektionen anrechnen. */
function einstufungAbschliessen() {
  const test = sitzung.einstufung;
  const prozent = einstufungProzent(test);
  const stufe = einstufungStufe(prozent);
  const modul = einstiegsModul(stufe);
  const quote = Math.max(prozent, kurs.placement.passThreshold) / 100;
  if (stufe !== "beginner") {
    for (const m of kurs.modules) {
      if (m.id === modul.id) break;
      for (const l of m.lessons) {
        if (!stand.lektionen[l.id]) stand.lektionen[l.id] = { quote, bestanden: true, viaEinstufung: true };
      }
    }
  }
  stand.start = { fertig: true, stufe, prozent };
  stand.profil = { selbsteinschaetzung: "intermediate", einstufung: prozent, stufe, seit: Date.now() };
  sichern();
  gehe("einstufungErgebnis", { prozent, stufe, modulId: modul.id, antworten: test.antworten });
}

function starteEinstufung() {
  const pool = einstufungPool();
  if (!pool.length) { stand.start = { fertig: true, stufe: "beginner" }; sichern(); return gehe("start"); }
  const test = {
    rest: pool.slice(),
    antworten: [],
    ziel: kurs.placement.startDifficulty,
    anzahl: Math.min(kurs.placement.questionsPerTest, pool.length),
  };
  const erste = naechsteEinstufungsfrage(test);
  sitzung = { titel: "Einstufung", lektionId: null, theorie: [], seite: 0, aufgaben: [erste],
              index: 0, versuche: 0, ergebnis: null, aufgedeckt: false, entwurf: null,
              ergebnisse: [], einstufung: test };
  gehe("sitzung");
}

function aufdecken() {
  const a = aktuelleAufgabe();
  sitzung.aufgedeckt = true;
  sitzung.entwurf = musterAntwort(a);
  abschliessen(0);
  zeichne();
}

function abschliessen(wertung) {
  const a = aktuelleAufgabe();
  sitzung.ergebnisse.push({ id: a.id, gewicht: a.difficulty, wertung, versuche: sitzung.versuche });
  // Einstufungsfragen gehören nicht zum Übungsstoff – sie dürfen die Wiedervorlage nicht verfälschen.
  if (!sitzung.einstufung) {
    // Dieselben Namen wie in den Apps: lesson, practice (ein Thema), training (gemischt).
    const kontext = sitzung.lektionId ? "lesson" : sitzung.art === "themen" ? "practice" : "training";
    merkeAufgabe(a, wertung, sitzung.versuche, kontext);
  }
}

function weiter() {
  sitzung.index += 1;
  sitzung.versuche = 0;
  sitzung.ergebnis = null;
  sitzung.aufgedeckt = false;
  sitzung.entwurf = aktuelleAufgabe() && aktuelleAufgabe().type === "singleChoice" ? null : null;
  zeichne();
}

function bindeEreignisse() {
  const klick = (wahl, tu) => document.querySelectorAll(wahl).forEach((k) => k.addEventListener("click", tu));
  klick("[data-seite]", (e) => gehe(e.currentTarget.dataset.seite));
  klick("[data-lektion]", (e) => starteLektion(e.currentTarget.dataset.lektion));
  klick("[data-start]", (e) => starteRunde(e.currentTarget.dataset.start, ansicht.gewaehlt));
  klick("[data-theorie]", () => { sitzung.seite += 1; zeichne(); });
  klick("[data-wahl]", (e) => { sitzung.entwurf = Number(e.currentTarget.dataset.wahl); zeichne(); });
  klick("[data-pruefen]", pruefen);
  klick("[data-aufdecken]", aufdecken);
  klick("[data-weiter]", weiter);
  klick("[data-abbruch]", () => gehe("start"));
  klick("[data-einstieg]", (e) => {
    if (e.currentTarget.dataset.einstieg === "einstufung") return starteEinstufung();
    stand.start = { fertig: true, stufe: "beginner" };
    stand.profil = { selbsteinschaetzung: "beginner", einstufung: null, stufe: "beginner", seit: Date.now() };
    sichern();
    gehe("start");
  });
  klick("[data-thema]", (e) => {
    const id = e.currentTarget.dataset.thema;
    const gewaehlt = ansicht.gewaehlt || [];
    ansicht.gewaehlt = gewaehlt.includes(id) ? gewaehlt.filter((x) => x !== id) : gewaehlt.concat(id);
    zeichne();
  });
  klick("[data-niveau]", (e) => {
    const n = Number(e.currentTarget.dataset.niveau);
    const niveaus = ansicht.niveaus || [];
    ansicht.niveaus = niveaus.includes(n) ? niveaus.filter((x) => x !== n) : niveaus.concat(n);
    zeichne();
  });
  klick("[data-anzahl]", (e) => { ansicht.anzahl = Number(e.currentTarget.dataset.anzahl); zeichne(); });
  klick("[data-zuruecksetzen]", () => { ansicht.gewaehlt = []; zeichne(); });
  klick("[data-nochmal]", () => starteRunde("training"));
  // Aus der Analyse heraus direkt das betroffene Thema üben.
  klick("[data-uebe]", (e) => gehe("themen", { gewaehlt: [e.currentTarget.dataset.uebe] }));
  klick("[data-sichern]", () => sicherungHerunterladen());
  klick("[data-kalender]", () => erinnerungHerunterladen());
  klick("[data-wiederherstellen]", () => {
    if (vorZuruecksetzenWiederherstellen()) melde("Wiederhergestellt – dein Stand von vorher ist wieder da, und nichts von seitdem ging verloren.");
    zeichne();
  });
  klick("[data-einlesen]", () => {
    const feld = document.getElementById("sicherung-datei");
    if (!feld) return;
    feld.onchange = () => {
      if (feld.files && feld.files[0]) sicherungEinlesen(feld.files[0]);
      feld.value = "";
    };
    feld.click();
  });
  klick("[data-reset]", () => {
    if (!confirm("Gesamten Fortschritt löschen? Score, Lernpfad und Analyse werden entfernt. Eine Kopie bleibt liegen – im Profil kannst du sie wiederherstellen.")) return;
    fortschrittZuruecksetzen();
    gehe("start");
  });
}

// ---------------------------------------------------------------- Start
async function los() {
  try {
    const antwort = await fetch("java_course.json");
    kurs = await antwort.json();
  } catch (e) {
    el().innerHTML = `<div class="karte" role="alert"><h2>Kurs konnte nicht geladen werden</h2><p class="leise">Bitte die Seite neu laden.</p></div>`;
    return;
  }
  // Einmal registriert, gilt für die ganze Sitzung – beim Neuzeichnen nicht erneut.
  document.addEventListener("keydown", tastenkuerzel);
  zeichne();

  // Hinweis auf „Zum Home-Bildschirm“ – nur in Safari und nur, solange die App
  // noch nicht installiert ist.
  const alsApp = window.navigator.standalone === true ||
                 window.matchMedia("(display-mode: standalone)").matches;
  const iOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
  if (iOS && !alsApp && !localStorage.getItem("javaquest-hinweis")) {
    const box = document.getElementById("installieren");
    box.hidden = false;
    document.getElementById("installieren-zu").addEventListener("click", () => {
      box.hidden = true;
      try { localStorage.setItem("javaquest-hinweis", "1"); } catch (e) { /* egal */ }
    });
  }

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("sw.js").catch(() => { /* ohne Offline-Betrieb läuft es auch */ });
  }
}

los();
