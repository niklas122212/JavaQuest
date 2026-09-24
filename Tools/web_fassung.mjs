#!/usr/bin/env node
/* Die Versionsnummer der Web-Fassung – aus dem Inhalt berechnet, nicht von Hand gepflegt.
 *
 * Warum: Der Service Worker liefert zuerst aus dem Zwischenspeicher und lädt nur dann
 * neu, wenn sich sw.js selbst ändert. Solange die Nummer von Hand erhöht werden musste,
 * ging das schief: Am 23.09. kam die vierte Theoriekarte je Lektion (+256 Zeilen in
 * java_course.json) ohne neue Nummer hinaus. Wer die Seite davor schon geöffnet hatte,
 * bekam den alten Kurs weiter aus dem Zwischenspeicher – ohne jeden Hinweis.
 *
 * Jetzt ist die Nummer eine Prüfsumme über alles, was ausgeliefert wird. Ändert sich
 * eine einzige Datei, ändert sich die Nummer; vergessen kann man sie nicht mehr. Die
 * CI prüft, dass die eingetragene Nummer zum Inhalt passt (siehe Web/tests/lauf.mjs).
 *
 *   node Tools/web_fassung.mjs              zeigt die Nummer und ob sie stimmt
 *   node Tools/web_fassung.mjs --schreiben  trägt sie in sw.js und index.html ein
 */
import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

/** Nicht Teil der Prüfsumme: sw.js trägt die Nummer selbst, der Rest wird nicht zwischengespeichert. */
const AUSGENOMMEN = new Set(["sw.js", "README.md"]);
const AUSGENOMMENE_ORDNER = new Set(["tests"]);

/** In index.html stehen die Nummern selbst – für die Prüfsumme werden sie ausgeblendet. */
const VERWEIS = /\b(app\.js|styles\.css)\?v=[^"']*/g;
const SW_NUMMER = /const VERSION = "([^"]*)";/;
const TEXT = /\.(html|js|css|json|webmanifest)$/;

function dateien(ordner, basis = ordner) {
  const liste = [];
  for (const eintrag of readdirSync(ordner, { withFileTypes: true })) {
    if (eintrag.name.startsWith(".")) continue;
    const pfad = join(ordner, eintrag.name);
    const rel = relative(basis, pfad).split(sep).join("/");
    if (eintrag.isDirectory()) {
      if (!AUSGENOMMENE_ORDNER.has(rel)) liste.push(...dateien(pfad, basis));
    } else if (!AUSGENOMMEN.has(rel)) {
      liste.push(rel);
    }
  }
  return liste;
}

/** Die Nummer, die zum aktuellen Inhalt von `web` gehört. */
export function berechneNummer(web) {
  const summe = createHash("sha256");
  for (const rel of dateien(web).sort()) {
    let inhalt = readFileSync(join(web, rel));
    if (TEXT.test(rel)) {
      // Zeilenenden vereinheitlichen: Ein Windows-Klon mit autocrlf soll dieselbe Nummer ergeben.
      let text = inhalt.toString("utf8").replace(/\r\n/g, "\n");
      if (rel === "index.html") text = text.replace(VERWEIS, "$1?v=");
      inhalt = Buffer.from(text, "utf8");
    }
    summe.update(rel).update("\0").update(inhalt).update("\0");
  }
  return summe.digest("hex").slice(0, 12);
}

/** Was in sw.js und index.html eingetragen ist. */
export function eingetrageneNummern(web) {
  const sw = readFileSync(join(web, "sw.js"), "utf8");
  const html = readFileSync(join(web, "index.html"), "utf8");
  const verweise = [...html.matchAll(/\b(app\.js|styles\.css)\?v=([^"']*)/g)].map((t) => [t[1], t[2]]);
  return { sw: (sw.match(SW_NUMMER) || [])[1] ?? null, verweise };
}

/** Leere Liste, wenn alles zusammenpasst – sonst je Abweichung ein Satz. */
export function abweichungen(web) {
  const soll = berechneNummer(web);
  const ist = eingetrageneNummern(web);
  const fehler = [];
  if (ist.sw !== soll) fehler.push(`sw.js trägt „${ist.sw}“, der Inhalt verlangt „${soll}“`);
  for (const datei of ["app.js", "styles.css"]) {
    const treffer = ist.verweise.filter(([d]) => d === datei);
    if (treffer.length === 0) fehler.push(`index.html verweist nicht mit ?v= auf ${datei}`);
    for (const [, nummer] of treffer) {
      if (nummer !== soll) fehler.push(`index.html lädt ${datei}?v=${nummer}, der Inhalt verlangt ${soll}`);
    }
  }
  return fehler;
}

export function schreibeNummer(web) {
  const nummer = berechneNummer(web);
  const swPfad = join(web, "sw.js");
  const htmlPfad = join(web, "index.html");
  const sw = readFileSync(swPfad, "utf8");
  if (!SW_NUMMER.test(sw)) throw new Error("In sw.js fehlt die Zeile const VERSION = \"…\";");
  writeFileSync(swPfad, sw.replace(SW_NUMMER, `const VERSION = "${nummer}";`));
  writeFileSync(htmlPfad, readFileSync(htmlPfad, "utf8").replace(VERWEIS, `$1?v=${nummer}`));
  return nummer;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const web = join(dirname(fileURLToPath(import.meta.url)), "..", "Web");
  if (process.argv.includes("--schreiben")) {
    console.log(`Web-Fassung: ${schreibeNummer(web)} – in sw.js und index.html eingetragen`);
  } else {
    const fehler = abweichungen(web);
    console.log(`Web-Fassung: ${berechneNummer(web)}`);
    for (const f of fehler) console.error(`  ${f}`);
    process.exit(fehler.length ? 1 : 0);
  }
}
