/* Prüfungen für die Bonus-Aufgaben der Web-Fassung: Code-Puzzle und Bug-Jagd
 * (bonus_aufgaben.json, dieselbe Datei wie apple_extra_tasks.json der Apple-App).
 * Die Regeln stammen aus AnswerEvaluator.swift und SecondHint.swift.
 */
const ok = (name) => ({ name, ok: true });
const fehler = (name, hinweis) => ({ name, ok: false, hinweis });
const pruefe = (name, bedingung, hinweis) => (bedingung ? ok(name) : fehler(name, hinweis));

export function bonusPruefungen(api, bonus) {
  const ergebnisse = [];
  const aufgaben = Object.values(bonus.lessons).flat();
  const puzzles = aufgaben.filter((a) => a.type === "ordering");
  const jagden = aufgaben.filter((a) => a.type === "findBug");

  {
    const daneben = aufgaben.filter((a) => !api.auswerten(a, api.musterAntwort(a)).richtig);
    ergebnisse.push(pruefe(
      `Bonus: Alle ${aufgaben.length} Musterantworten werden akzeptiert (${puzzles.length} Puzzles, ${jagden.length} Bug-Jagden)`,
      daneben.length === 0 && puzzles.length > 0 && jagden.length > 0 && aufgaben.every(api.istBonusAufgabe),
      daneben.map((a) => a.id).join(", "),
    ));
  }
  {
    const schonRichtig = puzzles.filter((a) => {
      const teile = api.puzzleTeile(a);
      const mischung = api.puzzleMischung(a);
      return mischung.length !== teile.length || mischung.every((x, i) => teile[x] === teile[i])
        || JSON.stringify(api.puzzleMischung(a)) !== JSON.stringify(mischung);
    });
    ergebnisse.push(pruefe("Bonus: Die Bausteine eines Puzzles sind gemischt – immer gleich und nie schon richtig", schonRichtig.length === 0, schonRichtig.map((a) => a.id).join(", ")));
  }
  {
    // Gleiche Zeilen (zwei „}“) sind austauschbar – verglichen wird der Text.
    const mitDoppelten = puzzles.find((a) => { const t = api.puzzleTeile(a); return t.filter((z) => z === "}").length >= 2; });
    let tauschOk = true;
    if (mitDoppelten) {
      const t = api.puzzleTeile(mitDoppelten);
      const klammern = t.map((z, i) => (z === "}" ? i : -1)).filter((i) => i >= 0);
      const order = t.map((_, i) => i);
      [order[klammern[0]], order[klammern[1]]] = [order[klammern[1]], order[klammern[0]]];
      tauschOk = api.auswerten(mitDoppelten, order).richtig;
    }
    const p = puzzles[0];
    const falsch = api.auswerten(p, api.puzzleTeile(p).map((_, i) => i).reverse());
    const halb = api.auswerten(p, [0, 1]);
    ergebnisse.push(pruefe(
      "Bonus: Puzzle – gleiche Zeilen sind austauschbar, falsche Reihenfolge und fehlende Zeilen werden benannt",
      tauschOk && !falsch.richtig && falsch.befunde.some((b) => b.text.includes("erste Zeile")) && !halb.richtig && halb.befunde.some((b) => b.text.includes("fehlen noch")),
      JSON.stringify([falsch.befunde, halb.befunde]),
    ));
  }
  {
    const p = puzzles.find((a) => a.id === "t01-p") || puzzles[0];
    const programm = api.puzzleZusammensetzen(api.puzzleTeile(p));
    ergebnisse.push(pruefe(
      "Bonus: Das zusammengesetzte Puzzle wird nach Klammertiefe eingerückt",
      programm[0] === "public class Main {" && programm[1] === "    public static void main(String[] args) {" && programm[2].startsWith("        System") && programm.at(-1) === "}",
      programm.join(" | "),
    ));
  }
  {
    const j = jagden[0];
    const daneben = api.auswerten(j, j.bugLine === 1 ? 2 : 1);
    const tipp = api.zweiterTipp(j, null);
    ergebnisse.push(pruefe(
      "Bug-Jagd: falsche Zeile wird abgelehnt, der zweite Tipp grenzt auf drei Zeilen ein",
      !daneben.richtig && daneben.befunde[0].text.includes("in Ordnung") && /Zeilen \d+ bis \d+/.test(tipp || ""),
      `${daneben.befunde[0].text} | ${tipp}`,
    ));
  }
  return ergebnisse;
}
