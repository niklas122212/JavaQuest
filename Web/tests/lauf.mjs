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

const hier = dirname(fileURLToPath(import.meta.url));
const web = join(hier, "..");

const quelltext = readFileSync(join(web, "app.js"), "utf8");
const kurs = JSON.parse(readFileSync(join(web, "java_course.json"), "utf8"));

const api = ladeApp(quelltext, kurs);
const ergebnisse = pruefungen(api, kurs);

const gescheitert = ergebnisse.filter((e) => !e.ok);
for (const e of ergebnisse) {
  console.log(`${e.ok ? "✔" : "✘"} ${e.name}${e.ok ? "" : `\n    ${e.hinweis ?? ""}`}`);
}
console.log(`\n${ergebnisse.length - gescheitert.length}/${ergebnisse.length} Prüfungen bestanden.`);

if (gescheitert.length) {
  console.error(`\n${gescheitert.length} Prüfung(en) fehlgeschlagen.`);
  process.exit(1);
}
