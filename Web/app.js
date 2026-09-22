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
  return { lektionen: {}, verlauf: {}, themen: {}, ziele: {} };
}

/* Ältere gespeicherte Stände kennen „ziele“ noch nicht. Sie werden nicht ersetzt,
   sondern nur ergänzt – der bisherige Fortschritt bleibt vollständig erhalten. */
if (!stand.ziele) stand.ziele = {};
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
function merkeAufgabe(aufgabe, wertung, versuche) {
  const alt = stand.verlauf[aufgabe.id];
  stand.verlauf[aufgabe.id] = {
    versuche: (alt ? alt.versuche : 0) + 1,
    wertung,
    datum: Date.now(),
  };
  // Die Wiedervorlage rechnet je Lernziel, nicht je Aufgabe: Wer dasselbe Lernziel dreimal
  // mit drei Varianten getroffen hat, hat es verstanden – und nicht eine Frage auswendig gelernt.
  const schluessel = gruppe(aufgabe);
  const ziel = stand.ziele[schluessel] || { versuche: 0, serie: 0 };
  stand.ziele[schluessel] = {
    versuche: ziel.versuche + 1,
    serie: wertung >= 1 ? ziel.serie + 1 : 0,
    wertung,
    datum: Date.now(),
  };
  const thema = stand.themen[aufgabe.topicId] || { gesehen: 0, richtig: 0, gewichtet: 0, gesamt: 0 };
  thema.gesehen += 1;
  if (wertung >= 1) thema.richtig += 1;
  thema.gewichtet += aufgabe.difficulty * wertung;
  thema.gesamt += aufgabe.difficulty;
  stand.themen[aufgabe.topicId] = thema;
  sichern();
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

function score() {
  // Wie MasterScore: nur bestandene Lektionen zählen, gewichtet nach Niveau.
  const lektionen = alleLektionen();
  let erreicht = 0, gesamt = 0;
  for (const l of lektionen) {
    const gewicht = l.tasks.reduce((s, t) => s + t.difficulty, 0);
    gesamt += gewicht;
    const e = lektionErgebnis(l.id);
    if (e && e.bestanden) erreicht += gewicht * e.quote;
  }
  return gesamt ? Math.round((erreicht / gesamt) * 1000) : 0;
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
      else befunde.push({ art: "schlecht", text: `Lücke ${i + 1} passt noch nicht.` });
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
      else befunde.push({ art: "schlecht", text: `Zeile ${i + 1} weicht ab.` });
    }
    if (treffer) befunde.unshift({ art: "gut", text: `${treffer} von ${erwartet.length} Zeilen stimmen.` });
    if (gegeben.join().toLowerCase() === erwartet.join().toLowerCase()) {
      befunde.push({ art: "tipp", text: "Fast! Achte auf Groß- und Kleinschreibung." });
    } else if (ohneLeerzeichen(gegeben.join()) === ohneLeerzeichen(erwartet.join())) {
      befunde.push({ art: "tipp", text: "Fast! Achte auf Leerzeichen und Zeilenumbrüche – println beginnt eine neue Zeile, print nicht." });
    }
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
    let treffer = false;
    try { treffer = new RegExp(regel.pattern).test(ziel); } catch (e) { treffer = false; }
    const gew = regel.weight || 1;
    if (regel.rule === "require") {
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

function codeBlock(schnipsel) {
  if (!schnipsel || !schnipsel.lines) return "";
  const zeilen = schnipsel.lines.map((z, i) =>
    `<span class="nr">${String(i + 1).padStart(2, " ")}</span>  ${sicher(z.code || "")}`).join("\n");
  return `<pre class="code">${zeilen}</pre>`;
}

function exegese(schnipsel, titel) {
  if (!schnipsel || !schnipsel.lines) return "";
  const zeilen = schnipsel.lines.filter((z) => z.explain).map((z) =>
    `<div class="erklaerzeile"><code>${sicher(z.code)}</code>${sicher(z.explain)}</div>`).join("");
  if (!zeilen) return "";
  return `<details class="exegese"><summary>${sicher(titel)}</summary><div class="zeilen">${zeilen}</div></details>`;
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

  return `<div class="uml"><svg width="${maxBreite}" height="${Math.max(y - LUECKE_Y, 0) + 4}" viewBox="0 0 ${maxBreite} ${Math.max(y - LUECKE_Y, 0) + 4}">${svg}</svg>${legende}</div>`;
}

// ---------------------------------------------------------------- Bildschirme
const el = () => document.getElementById("app");

function zeichne() {
  const s = { start: startSeite, themen: themenSeite, schwaechen: schwaechenSeite,
              lektionen: lektionenSeite, sitzung: sitzungSeite, einstieg: einstiegSeite,
              einstufungErgebnis: einstufungErgebnisSeite }[ansicht.name] || startSeite;
  el().innerHTML = s();
  bindeEreignisse();
  window.scrollTo(0, 0);
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
      <div>von 1.000 · ${fertig} von ${alleLektionen().length} Lektionen</div>
      <div class="balken"><i style="width:${punkte / 10}%"></i></div>
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
      return anzahl ? `
    <div class="karte">
      <div class="marken"><span class="marke stark">Wiederholung</span></div>
      <h2>${anzahl} ${anzahl === 1 ? "Lernziel ist" : "Lernziele sind"} heute fällig</h2>
      <p class="leise">Was du kannst, wird in wachsenden Abständen abgefragt – erst am nächsten Tag,
      dann nach 3, 7, 16 und 35 Tagen. So bleibt es sitzen, ohne dass du dasselbe täglich übst.</p>
      <button class="knopf" data-start="wiederholung">Wiederholung starten</button>
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

function lektionenSeite() {
  const lektionen = alleLektionen();
  let html = `<div class="kopf"><button class="zurueck" data-seite="start">‹</button><span class="titel">Alle Lektionen</span></div>`;
  kurs.modules.forEach((m) => {
    html += `<div class="karte"><h3>${sicher(m.title)}</h3><p class="mini">${sicher(m.subtitle)}</p>`;
    m.lessons.forEach((l) => {
      const index = lektionen.findIndex((x) => x.id === l.id);
      const e = lektionErgebnis(l.id);
      const frei = istFrei(index);
      const zustand = e && e.bestanden ? "fertig" : (frei ? "offen" : "");
      html += `<button class="zeile" data-lektion="${l.id}" ${frei ? "" : "disabled"}>
        <span class="punkt ${zustand}">${e && e.bestanden ? "✓" : (frei ? "▸" : "🔒")}</span>
        <span class="haupt"><strong>${sicher(l.title)}</strong>
        <span class="mini">${e ? `Bestwert ${Math.round(e.quote * 100)} %` : `${l.tasks.length} Aufgaben`}</span></span>
      </button>`;
    });
    html += `</div>`;
  });
  return html;
}

function themenSeite() {
  const gewaehlt = ansicht.gewaehlt || [];
  let html = `<div class="kopf"><button class="zurueck" data-seite="start">‹</button><span class="titel">Themen wählen</span></div>
    <p class="leise">Ohne Auswahl kommt alles gemischt. Jedes Thema ist sofort übbar – auch wenn die Lektion noch nicht dran war.</p>
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
    html += `<button class="kachel ${aktiv ? "aktiv" : ""}" data-thema="${t.id}">
      <strong>${sicher(t.title)}</strong>
      <span class="mini">${anzahl} Aufgaben${m === null ? "" : ` · ${Math.round(m * 100)} %`}</span>
      ${leiste}
      ${wacklig.length ? `<span class="mini warn">Es hakt ab Stufe ${wacklig[0].stufe} – die leichteren sitzen.</span>` : ""}
    </button>`;
  });
  html += `</div><div class="karte"><button class="knopf" data-start="themen">${gewaehlt.length ? `${gewaehlt.length} Thema/Themen üben` : "Gemischt üben"}</button></div>`;
  return html;
}

function schwaechenSeite() {
  const offen = schwaechen();
  let html = `<div class="kopf"><button class="zurueck" data-seite="start">‹</button><span class="titel">Meine Schwächen</span></div>`;
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
  if (art === "schwaechen") {
    const gruppen = new Set(schwaechen().map((s) => s.gruppe));
    topf = uebbareAufgaben().filter((a) => gruppen.has(gruppe(a)));
    titel = "Meine Schwächen";
  } else if (art === "wiederholung") {
    const gruppen = new Set(faelligeZiele(Date.now()));
    topf = uebbareAufgaben().filter((a) => gruppen.has(gruppe(a)));
    titel = "Wiederholung";
  } else if (art === "themen" && themen && themen.length) {
    topf = uebbareAufgaben().filter((a) => themen.includes(a.topicId));
    titel = "Üben: " + themen.map((t) => (thema(t) || {}).title).filter(Boolean).join(", ");
  } else {
    topf = uebbareAufgaben();
    titel = "Gemischt üben";
  }
  if (!topf.length) return;
  sitzung = { titel, lektionId: null, theorie: [], seite: 0, aufgaben: runde(topf, RUNDE),
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
    <div class="kopf"><button class="zurueck" data-abbruch="1">✕</button>
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
    eingabe = a.choices.map((c, i) => {
      let klasse = "antwort";
      if (fertig && i === a.correctIndex) klasse += " richtig";
      else if (sitzung.entwurf === i) klasse += sitzung.ergebnis && !sitzung.ergebnis.richtig ? " falsch" : " gewaehlt";
      return `<button class="${klasse}" data-wahl="${i}" ${fertig ? "disabled" : ""}>
        <span class="buchstabe">${"ABCD"[i]}</span><span>${sicher(c)}</span></button>`;
    }).join("");
  } else if (a.type === "fillBlank") {
    eingabe = a.blanks.map((_, i) => `<div class="luecke"><span class="nummer">${i + 1}</span>
      <input type="text" data-luecke="${i}" value="${sicher((sitzung.entwurf || [])[i] || "")}" ${fertig ? "disabled" : ""} placeholder="Lücke ${i + 1}"></div>`).join("");
  } else if (a.type === "predictOutput") {
    eingabe = `<textarea class="konsole" data-text="1" ${fertig ? "disabled" : ""} placeholder="Ausgabe Zeile für Zeile eintippen …">${sicher(sitzung.entwurf || "")}</textarea>`;
  } else {
    const start = (a.starterCode && a.starterCode.lines.map((z) => z.code).join("\n")) || "";
    eingabe = `<textarea data-text="1" ${fertig ? "disabled" : ""}>${sicher(sitzung.entwurf === null ? start : sitzung.entwurf)}</textarea>`;
  }

  const zeigeCode = a.code && (a.type === "singleChoice" || a.type === "predictOutput");
  const vorlage = a.type === "fillBlank" ? a.template : null;

  return h(`
    <div class="kopf"><button class="zurueck" data-abbruch="1">✕</button>
      <span class="titel">${sicher(sitzung.titel)}</span>
      <span class="mini">${sitzung.einstufung
        ? `Frage ${sitzung.einstufung.antworten.length + 1} von ${sitzung.einstufung.anzahl}`
        : `${sitzung.index + 1}/${sitzung.aufgaben.length}`}</span></div>
    <div class="balken" style="margin-bottom:14px"><i style="width:${sitzung.einstufung
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
      ${vorlage ? codeBlock(fertig ? a.sampleSolution || vorlage : vorlage) : ""}
      ${a.javaContext && a.type === "code" ? `<p class="mini">${sicher({ statements: "Schreibe nur die Anweisungen – der main-Block ist schon da.", members: "Schreibe die Methoden bzw. Felder innerhalb der Klasse.", file: "Schreibe den vollständigen Code inklusive Klassen." }[a.javaContext])}</p>` : ""}
      ${a.type === "code" && a.expectedOutput ? `<p class="mini">Erwartete Ausgabe:</p><pre class="code">${sicher(a.expectedOutput)}</pre>` : ""}
      ${eingabe}
      ${fertig && zeigeCode ? exegese(a.code, "Code Zeile für Zeile erklären") : ""}
      ${fertig && a.type === "code" ? exegese(a.sampleSolution, "Musterlösung Zeile für Zeile") : ""}
    </div>

    ${rueckmeldung(a, fertig)}

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

  let kopf = richtig ? (sitzung.versuche === 1 ? "Richtig – volle Punktzahl!" : `Richtig – im ${sitzung.versuche}. Anlauf.`)
                     : (sitzung.aufgedeckt ? "Lösung aufgedeckt" : "Noch nicht ganz");
  let unter = richtig ? (sitzung.versuche === 1 ? "Das zählt voll." : "Das zählt zur Hälfte.")
                      : (sitzung.aufgedeckt ? "Schau dir die Lösung in Ruhe an – beim nächsten Mal klappt’s."
                                            : (rest > 0 ? `Du hast noch ${rest} ${rest === 1 ? "Versuch" : "Versuche"}.` : "Keine Versuche mehr – unten steht, woran es lag."));

  let html = `<div class="rueck ${klasse}"><h3>${kopf}</h3><p class="leise">${unter}</p>`;

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
  }
  return html + `</div>`;
}

function auswertungSeite() {
  const gesamt = sitzung.ergebnisse.reduce((s, r) => s + r.gewicht, 0);
  const erreicht = sitzung.ergebnisse.reduce((s, r) => s + r.gewicht * r.wertung, 0);
  const quote = gesamt ? erreicht / gesamt : 0;
  const bestanden = quote >= BESTANDEN_AB;
  const ersterVersuch = sitzung.ergebnisse.filter((r) => r.wertung >= 1 && r.versuche === 1).length;

  if (sitzung.lektionId) {
    const alt = lektionErgebnis(sitzung.lektionId);
    if (!alt || quote > alt.quote) {
      stand.lektionen[sitzung.lektionId] = { quote, bestanden: bestanden || (alt && alt.bestanden) || false };
      sichern();
    }
  }

  return h(`
    <div class="kopf"><span class="titel">${sicher(sitzung.titel)}</span></div>
    <div class="karte" style="text-align:center">
      <div style="font-size:52px">${bestanden ? "🏆" : "🔁"}</div>
      <h1>${sitzung.lektionId ? (bestanden ? "Lektion gemeistert!" : "Fast geschafft!") : "Runde geschafft"}</h1>
      <p class="leise">${sitzung.lektionId && !bestanden
        ? `Ab ${Math.round(BESTANDEN_AB * 100)} % gilt eine Lektion als bestanden. Wiederhole sie – es zählt immer dein Bestwert.`
        : "Was noch hakt, kommt in den nächsten Runden öfter dran – so lange, bis es sitzt."}</p>
      <div class="gitter" style="margin-top:14px">
        <div class="kachel"><strong>${Math.round(quote * 100)} %</strong><span class="mini">Trefferquote</span></div>
        <div class="kachel"><strong>${ersterVersuch}/${sitzung.ergebnisse.length}</strong><span class="mini">beim ersten Versuch</span></div>
      </div>
    </div>
    <button class="knopf" data-seite="start">Zur Übersicht</button>
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
  if (!sitzung.einstufung) merkeAufgabe(a, wertung, sitzung.versuche);
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
    sichern();
    gehe("start");
  });
  klick("[data-thema]", (e) => {
    const id = e.currentTarget.dataset.thema;
    const gewaehlt = ansicht.gewaehlt || [];
    ansicht.gewaehlt = gewaehlt.includes(id) ? gewaehlt.filter((x) => x !== id) : gewaehlt.concat(id);
    zeichne();
  });
}

// ---------------------------------------------------------------- Start
async function los() {
  try {
    const antwort = await fetch("java_course.json");
    kurs = await antwort.json();
  } catch (e) {
    el().innerHTML = `<div class="karte"><h2>Kurs konnte nicht geladen werden</h2><p class="leise">Bitte die Seite neu laden.</p></div>`;
    return;
  }
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
