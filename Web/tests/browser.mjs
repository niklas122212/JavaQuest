#!/usr/bin/env node
/* Spielt die Web-App in einem echten Browser durch – mit Klicks und Tastendrücken.
 *
 * Warum zusätzlich zu lauf.mjs: Die dortigen Prüfungen laufen ohne Browser und damit ohne
 * CSS. Der Installationshinweis stand deshalb drei Tage lang bei jedem Besuch über den
 * Knöpfen (eine Klasse mit display: flex hob hidden auf), ohne dass eine Prüfung anschlug.
 *
 * Geprüft wird:
 *   - Installationshinweis: in Chrome unsichtbar, in iPhone-Safari sichtbar, „Verstanden“
 *     schließt ihn dauerhaft
 *   - alle Lektionen der Reihe nach über den Lernpfad (jede wird erst durch die davor frei):
 *     jede Theoriekarte mit allen erklärten Zeilen, jede Aufgabe mit der Musterlösung
 *     eingetippt, danach „Lektion gemeistert!“ mit drei Sternen
 *   - vor dem Lösen ist keine Lückenzeile erklärt; nirgends steht undefined, NaN oder {{0}}
 *   - am Ende Score 1000
 *
 * Aufruf: node Web/tests/browser.mjs            (braucht playwright-core und Chrome/Chromium)
 * Browser: CHROME=/pfad/zum/chrome, sonst die üblichen Orte.
 */
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { createServer } from "node:net";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const web = join(dirname(fileURLToPath(import.meta.url)), "..");
const chrome = [process.env.CHROME, "/usr/bin/google-chrome", "/opt/pw-browsers/chromium/chrome-linux/chrome",
  "/opt/pw-browsers/chromium-1194/chrome-linux/chrome", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"]
  .find((p) => p && existsSync(p));
if (!chrome) { console.error("Kein Chrome gefunden – Pfad mit CHROME=… angeben."); process.exit(1); }

const port = await new Promise((fertig) => {
  const s = createServer().listen(0, "127.0.0.1", () => { const p = s.address().port; s.close(() => fertig(p)); });
});
const server = spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1"], { cwd: web, stdio: "ignore" });
const adresse = `http://127.0.0.1:${port}/index.html`;

const befunde = [];
const browser = await chromium.launch({ executablePath: chrome });

async function oeffnen(kontext) {
  const seite = await kontext.newPage();
  // Ein Klick, den etwas verdeckt, soll schnell scheitern – nicht erst nach 30 Sekunden.
  seite.setDefaultTimeout(5000);
  seite.on("pageerror", (e) => befunde.push(`JavaScript-Fehler: ${e.message}`));
  for (let versuch = 0; ; versuch++) {
    try { await seite.goto(adresse); break; } catch (e) { if (versuch > 20) throw e; await seite.waitForTimeout(250); }
  }
  await seite.waitForFunction(() => typeof kurs !== "undefined" && kurs && kurs.modules);
  return seite;
}

async function sichtbarPruefen(seite, wo) {
  const text = await seite.evaluate(() => document.body.innerText);
  for (const muster of ["undefined", "NaN", "[object Object]", "{{"]) {
    if (text.includes(muster)) befunde.push(`${wo}: „${muster}“ steht sichtbar auf der Seite`);
  }
}

try {
  // ------------------------------------------------------------ Installationshinweis
  {
    const iphone = await browser.newContext({
      viewport: { width: 390, height: 844 },
      userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
    });
    const seite = await oeffnen(iphone);
    const vorher = await seite.locator("#installieren").isVisible();
    if (vorher) await seite.click("#installieren-zu");
    const nachher = await seite.locator("#installieren").isVisible();
    await seite.reload();
    await seite.waitForFunction(() => typeof kurs !== "undefined" && kurs && kurs.modules);
    const neu = await seite.locator("#installieren").isVisible();
    if (!vorher) befunde.push("Installationshinweis erscheint in iPhone-Safari nicht");
    if (nachher || neu) befunde.push("Installationshinweis bleibt nach „Verstanden“ stehen");
    await iphone.close();
  }

  // ------------------------------------------------------------ alle Lektionen
  const kontext = await browser.newContext({ viewport: { width: 420, height: 900 } });
  const seite = await oeffnen(kontext);
  if (await seite.locator("#installieren").isVisible()) befunde.push("Installationshinweis in Chrome sichtbar");

  await seite.click('[data-einstieg]:not([data-einstieg="einstufung"])');
  const lektionen = await seite.evaluate(() => alleLektionen().map((l) => l.id));
  let karten = 0, aufgaben = 0;
  for (const id of lektionen) {
    await seite.evaluate(() => gehe("lektionen"));
    const knopf = seite.locator(`[data-lektion="${id}"]`);
    if (await knopf.isDisabled()) { befunde.push(`${id}: im Lernpfad gesperrt, obwohl die Lektion davor bestanden ist`); break; }
    await knopf.click();

    const anzahlKarten = await seite.evaluate(() => sitzung.theorie.length);
    for (let i = 0; i < anzahlKarten; i++) {
      const exegese = seite.locator(".karte > details.exegese");
      if (await exegese.count()) {
        await exegese.first().locator(":scope > summary").click();
        const sichtbar = await exegese.first().locator(".erklaerzeile").count();
        const soll = await seite.evaluate(() => (sitzung.theorie[sitzung.seite].code?.lines || []).filter((z) => z.explain).length);
        if (sichtbar !== soll) befunde.push(`${id}, Karte ${i + 1}: ${sichtbar} von ${soll} erklärten Zeilen sichtbar`);
      }
      await sichtbarPruefen(seite, `${id}, Karte ${i + 1}`);
      await seite.click("[data-theorie]");
      karten++;
    }

    const anzahl = await seite.evaluate(() => sitzung.aufgaben.length);
    for (let i = 0; i < anzahl; i++) {
      const a = await seite.evaluate(() => { const a = aktuelleAufgabe(); return { id: a.id, typ: a.type, antwort: musterAntwort(a) }; });
      if (a.typ === "fillBlank") {
        const verraten = await seite.evaluate(() => [...document.querySelectorAll(".erklaerzeile")]
          .filter((z) => z.querySelector("code .lueckenmarke") && !z.querySelector(".leise")).length);
        if (verraten) befunde.push(`${a.id}: ${verraten} Lückenzeile(n) schon vor dem Lösen erklärt`);
      }
      if (a.typ === "singleChoice") await seite.keyboard.press(String(a.antwort + 1));
      else if (a.typ === "fillBlank") for (let j = 0; j < a.antwort.length; j++) await seite.fill(`[data-luecke="${j}"]`, a.antwort[j]);
      else await seite.fill("[data-text]", a.antwort);
      await sichtbarPruefen(seite, `${a.id} vor dem Prüfen`);
      await seite.click("[data-pruefen]");
      if (!(await seite.evaluate(() => !!(sitzung.ergebnis && sitzung.ergebnis.richtig)))) {
        befunde.push(`${a.id} (${a.typ}): Musterlösung über die Oberfläche als falsch gewertet`);
        await seite.click("[data-aufdecken]");
      }
      await sichtbarPruefen(seite, `${a.id} nach dem Prüfen`);
      await seite.keyboard.press("Control+Enter");
      aufgaben++;
    }

    const titel = await seite.locator("h1").first().innerText();
    const sterne = await seite.locator(".sterne.gross").innerText();
    if (titel !== "Lektion gemeistert!" || sterne !== "★★★") befunde.push(`${id}: Auswertung „${titel}“ ${sterne}`);
  }

  const score = await seite.evaluate(() => score());
  if (score !== 1000) befunde.push(`Score nach allen Lektionen: ${score} statt 1000`);
  console.log(`${lektionen.length} Lektionen im Browser durchgespielt: ${karten} Theoriekarten, ${aufgaben} Aufgaben, Score ${score}`);
} catch (e) {
  befunde.push(`Abgebrochen: ${e.message.split("\n")[0]}`);
} finally {
  await browser.close();
  server.kill();
}

if (befunde.length) {
  console.error(`\n${befunde.length} Befund(e):\n- ${befunde.join("\n- ")}`);
  process.exit(1);
}
console.log("Installationshinweis nur in iPhone-Safari, keine Befunde.");
