#!/usr/bin/env node
/* Führt die Prüfungen der Web-Fassung unter Node aus.
 *
 * Aufruf: node Web/tests/lauf.mjs
 * Rückgabewert 1, sobald eine Prüfung fehlschlägt – damit die CI stehen bleibt.
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ladeApp } from "./laden.mjs";
import { pruefungen } from "./pruefungen.mjs";
import { abweichungen, berechneNummer } from "../../Tools/web_fassung.mjs";

const hier = dirname(fileURLToPath(import.meta.url));
const web = join(hier, "..");

const quelltext = readFileSync(join(web, "app.js"), "utf8");
const kurs = JSON.parse(readFileSync(join(web, "java_course.json"), "utf8"));

// Dieselben zwei Beispiel-Sicherungen liest auch die Apple- und die Windows-Testreihe.
const sicherungen = join(web, "..", "Tests", "Sicherungen");
const beispiele = {
  ausDerApp: JSON.parse(readFileSync(join(sicherungen, "aus-der-app.json"), "utf8")),
  ausDemWeb: JSON.parse(readFileSync(join(sicherungen, "aus-dem-web.json"), "utf8")),
};

const api = ladeApp(quelltext, kurs);
const ergebnisse = pruefungen(api, kurs, beispiele);

// Nur unter Node prüfbar, deshalb nicht in pruefungen.mjs: Passt die Versionsnummer zum
// Inhalt? Sonst lädt der Service Worker bei Stammnutzern die Änderung nie nach.
{
  const fehler = abweichungen(web);
  ergebnisse.push({
    name: `Versionsnummer ${berechneNummer(web)} passt zum ausgelieferten Inhalt`,
    ok: fehler.length === 0,
    hinweis: `${fehler.join("; ")} – Tools/build_web.sh ausführen.`,
  });
}

const gescheitert = ergebnisse.filter((e) => !e.ok);
for (const e of ergebnisse) {
  console.log(`${e.ok ? "✔" : "✘"} ${e.name}${e.ok ? "" : `\n    ${e.hinweis ?? ""}`}`);
}
console.log(`\n${ergebnisse.length - gescheitert.length}/${ergebnisse.length} Prüfungen bestanden.`);

if (gescheitert.length) {
  console.error(`\n${gescheitert.length} Prüfung(en) fehlgeschlagen.`);
  process.exit(1);
}
