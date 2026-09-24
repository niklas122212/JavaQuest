/* Lädt app.js so, dass man die Rechenteile einzeln prüfen kann.
 *
 * app.js ist ein klassisches Browser-Skript: Alle Funktionen liegen im selben
 * Gültigkeitsbereich, und ganz am Ende startet `los()` die App. Für eine Prüfung
 * wird nur der erste Teil gebraucht. Deshalb wird der Startaufruf entfernt und der
 * Rest in einer Funktion ausgewertet, die die benötigten Namen zurückgibt – mit
 * Setzern für `kurs` und `stand`, damit ein Testfall einen Lernstand vorgeben kann.
 *
 * Bewusst ohne Fremdbibliothek: Die Prüfungen sollen überall laufen, wo es
 * JavaScript gibt – unter Node in der CI genauso wie im Browser von Hand.
 */
export function ladeApp(quelltext, kurs) {
  const ohneStart = quelltext.replace(/^los\(\);\s*$/m, "");
  if (ohneStart === quelltext) {
    throw new Error("Der Startaufruf los(); wurde nicht gefunden – app.js hat sich geändert.");
  }

  const bauen = new Function(`
    ${ohneStart}
    return {
      setzeKurs: (k) => { kurs = k; },
      setzeStand: (s) => { stand = s; },
      holeStand: () => stand,
      auswerten, zweiterTipp, ausgabeZeilen, lueckePasst,
      warumZeileFalsch, warumAusgabeFalsch, warumBlankFalsch,
      staendeVereinen, exegese, befehleDerZeile,
      score, rang, naechsterRang, sterne, beherrschung, gesamtBeherrschung, themenStatus,
      wiedervorlage, faelligeZiele, aktuelleSerie,
      einstufungProzent, einstufungStufe,
      BESTANDEN_AB, PAUSEN, MINDESTFAKTOR, RAENGE,
    };
  `);

  const api = bauen();
  api.setzeKurs(kurs);
  api.setzeStand(leererStand());
  return api;
}

export function leererStand() {
  return { lektionen: {}, verlauf: {}, themen: {}, ziele: {}, serie: null, profil: null, start: null };
}

/** Alle übbaren Aufgaben der Kursdatei – Lektionen plus Übungspool. */
export function alleAufgaben(kurs) {
  const aufgaben = [];
  for (const modul of kurs.modules) {
    for (const lektion of modul.lessons) aufgaben.push(...lektion.tasks);
  }
  aufgaben.push(...(kurs.taskPool || []));
  return aufgaben;
}

/** Die Musterlösung einer Aufgabe in der Form, die `auswerten` erwartet. */
export function musterloesung(aufgabe) {
  switch (aufgabe.type) {
    case "singleChoice": return aufgabe.correctIndex;
    case "predictOutput": return aufgabe.expectedOutput;
    case "fillBlank": return aufgabe.blanks.map((l) => l.accepted[0]);
    default: return aufgabe.sampleSolution.lines
      ? aufgabe.sampleSolution.lines.map((z) => z.code).join("\n")
      : aufgabe.sampleSolution;
  }
}
