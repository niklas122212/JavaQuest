/* Prüfungen für den Java-Interpreter der Web-Fassung (Web/java.js).
 *
 * Dieselben Fälle wie InterpreterTests.swift: Ausgaben eines echten JDK
 * (Tests/…/Fixtures/java_differential.json), verständliche Fehlermeldungen, „nicht
 * unterstützt“ statt Fehler, und jede Kursaufgabe mit bekannter Ausgabe, deren Code der
 * Interpreter versteht, muss genau diese Ausgabe liefern.
 *
 * Laufzeitneutral wie pruefungen.mjs: Der Interpreter wird als Text übergeben.
 */
import { alleAufgaben } from "./laden.mjs";

/** Wertet java.js aus und gibt `JavaKern` zurück. */
export function ladeJava(quelltext) {
  return new Function(`${quelltext}\nreturn JavaKern;`)();
}

const ok = (name) => ({ name, ok: true });
const fehler = (name, hinweis) => ({ name, ok: false, hinweis });
const pruefe = (name, bedingung, hinweis) => (bedingung ? ok(name) : fehler(name, hinweis));

/** Wie AnswerEvaluator.outputLines: Leerzeichen am Zeilenende und Leerzeilen außen zählen nicht. */
export function ausgabeZeilen(text) {
  const zeilen = String(text).replace(/\r\n/g, "\n").split("\n").map((z) => z.replace(/[ \t]+$/, ""));
  while (zeilen.length && zeilen[0] === "") zeilen.shift();
  while (zeilen.length && zeilen[zeilen.length - 1] === "") zeilen.pop();
  return zeilen;
}

const quelle = (schnipsel) => (schnipsel && schnipsel.lines ? schnipsel.lines.map((z) => z.code).join("\n") : schnipsel || "");

export function javaPruefungen(Java, kurs, jdkFaelle) {
  const ergebnisse = [];
  const problem = (code) => Java.run(code).problem;

  // ------------------------------------------------------------ wie ein echtes JDK
  for (const fall of jdkFaelle) {
    const lauf = Java.run(fall.source);
    const erwartet = fall.expected.split("\n");
    const bekommen = lauf.output.split("\n");
    const erste = erwartet.findIndex((zeile, i) => bekommen[i] !== zeile);
    ergebnisse.push(pruefe(
      `Interpreter: gleiche Ausgabe wie ein echtes JDK („${fall.name}“)`,
      !lauf.problem && erste === -1 && bekommen.length === erwartet.length,
      lauf.problem ? lauf.problem.description
        : erste >= 0 ? `Zeile ${erste + 1}: erwartet „${erwartet[erste]}“, bekommen „${bekommen[erste] ?? "<fehlt>"}“`
          : `${bekommen.length} statt ${erwartet.length} Zeilen`,
    ));
  }

  // ------------------------------------------------------------ Fehlermeldungen
  {
    const faelle = [
      ["int x = 5\nSystem.out.println(x);", (p) => p.kind === "syntax" && p.line === 1 && p.message.includes("Semikolon")],
      ["int zahl = 3;\nSystem.out.println(Zahl);", (p) => p.line === 2 && p.message.includes("Meintest du „zahl“")],
      ["int x = 2.5;", (p) => p.message.includes("(int)")],
      ["int[] a = new int[3];\na[3] = 1;", (p) => p.kind === "runtime" && p.message.includes("ArrayIndexOutOfBoundsException") && p.line === 2],
      ["int a = 5;\nint b = 0;\nSystem.out.println(a / b);", (p) => p.kind === "runtime" && p.line === 3],
      ["int x = 1;\nint x = 2;", (p) => p.message.includes("gibt es hier schon")],
      ["int x = 1;\nif (x = 2) { }", (p) => p.message.includes("==")],
      ["static int f(int x) {\n  if (x > 0) return 1;\n}\nSystem.out.println(f(-1));", (p) => p.message.includes("return")],
      ["final int MAX = 3;\nMAX = 4;", (p) => p.message.includes("final")],
    ];
    const daneben = faelle.filter(([code, passt]) => { const p = problem(code); return !p || !passt(p); });
    ergebnisse.push(pruefe(
      "Interpreter: Fehler kommen mit Zeile und verständlicher Meldung",
      daneben.length === 0,
      daneben.map(([code]) => `${code.split("\n")[0]} → ${problem(code)?.description ?? "kein Fehler"}`).join(" | "),
    ));
  }
  {
    const schleife = Java.run("int i = 0;\nwhile (i < 10) {\n  System.out.print(\"\");\n}", { stepLimit: 5000 });
    const rekursion = problem("static int f(int n) { return f(n + 1); }\nSystem.out.println(f(0));");
    ergebnisse.push(pruefe(
      "Interpreter: Endlosschleifen und endlose Rekursion werden sauber gestoppt",
      schleife.problem?.kind === "stepLimit" && rekursion?.message.includes("StackOverflowError"),
      `Schleife: ${schleife.problem?.description}, Rekursion: ${rekursion?.description}`,
    ));
  }
  {
    const beispiele = [
      "List<String> l = new ArrayList<>();",
      "class Hund { String name; Hund(String n) { name = n; } }",
      "try { int x = 1; } catch (Exception e) { }",
      "Runnable r = () -> System.out.println(1);",
      "float f = 1.5f;",
      "sealed interface Form permits Kreis {}\nrecord Kreis(double r) implements Form {}",
    ];
    const daneben = beispiele.filter((code) => problem(code)?.kind !== "unsupported");
    ergebnisse.push(pruefe(
      "Interpreter: Unbekannte Java-Bausteine sind „nicht unterstützt“, kein Fehler",
      daneben.length === 0,
      daneben.map((code) => `${code} → ${problem(code)?.description ?? "kein Problem"}`).join(" | "),
    ));
  }
  {
    const lauf = Java.run("String a = \"x\";\nString b = \"x\";\nif (a == b) System.out.println(1);");
    ergebnisse.push(pruefe(
      "Interpreter: Strings mit == vergleichen gibt einen Hinweis",
      lauf.warnings.some((w) => w.message.includes("equals") && w.line === 3),
      JSON.stringify(lauf.warnings),
    ));
  }
  {
    const faelle = [[1e7, "1.0E7"], [1.5e-5, "1.5E-5"], [123.0, "123.0"], [0.001, "0.001"], [-2.5, "-2.5"]];
    const daneben = faelle.filter(([zahl, text]) => Java.formatDouble(zahl) !== text);
    ergebnisse.push(pruefe(
      "Interpreter: Kommazahlen wie in Java (1.0E7, 0.001, 123.0)",
      daneben.length === 0,
      daneben.map(([zahl, text]) => `${zahl} → ${Java.formatDouble(zahl)} statt ${text}`).join(", "),
    ));
  }

  // ------------------------------------------------------------ Ausführen und zusehen (wie TraceTests.swift)
  {
    const schleife = Java.trace("int summe = 0;\nfor (int i = 1; i <= 3; i++) {\n    summe += i;\n}\nSystem.out.println(summe);");
    const zweiter = schleife.steps[4] || { variables: [] };
    const wert = (schritt, name) => (schritt.variables.find((v) => v.name === name) || {}).value;
    ergebnisse.push(pruefe(
      "Zusehen: Jede Anweisung und jede Schleifenrunde wird ein Schritt – mit Variablen und Ausgabe",
      !schleife.problem && !schleife.isTruncated && JSON.stringify(schleife.steps.map((x) => x.line)) === "[1,2,3,2,3,2,3,2,5,null]"
        && wert(zweiter, "i") === "2" && wert(zweiter, "summe") === "1" && schleife.steps.at(-1).output === "6\n" && Java.traceIsUseful(schleife),
      JSON.stringify(schleife.steps.map((x) => x.line)),
    ));
    const methode = Java.trace("public class Rechner {\n    static int doppelt(int zahl) {\n        return zahl * 2;\n    }\n\n    public static void main(String[] args) {\n        int x = doppelt(21);\n        System.out.println(x);\n    }\n}");
    ergebnisse.push(pruefe(
      "Zusehen: Methodenaufrufe springen in die Methode und zurück",
      JSON.stringify(methode.steps.map((x) => x.line)) === "[7,3,8,null]" && methode.steps[1].method === "doppelt"
        && JSON.stringify(methode.steps[1].variables.map((v) => v.name)) === '["zahl"]' && methode.steps.at(-1).output === "42\n",
      JSON.stringify(methode.steps.map((x) => [x.line, x.method])),
    ));
    const fehler = Java.trace("int x = 0;\nSystem.out.println(5 / x);");
    const fremd = Java.trace("List<String> namen = new ArrayList<>();");
    const endlos = Java.trace("int i = 0;\nwhile (true) {\n    i++;\n}", 50);
    ergebnisse.push(pruefe(
      "Zusehen: Laufzeitfehler bleiben an ihrer Zeile stehen, Unbekanntes und Endlosschleifen sind begrenzt",
      fehler.problem?.kind === "runtime" && JSON.stringify(fehler.steps.map((x) => x.line)) === "[1,2,2]" && Java.traceIsUseful(fehler)
        && !Java.traceIsUseful(fremd) && endlos.isTruncated && endlos.steps.length === 50 && Java.traceIsUseful(endlos),
      `Fehler ${JSON.stringify(fehler.steps.map((x) => x.line))}, endlos ${endlos.steps.length}`,
    ));
    const beispiele = kurs.modules.flatMap((m) => m.lessons).flatMap((l) => (l.theory || []).map((k) => k.code).filter(Boolean)).map(quelle);
    const sehenswert = beispiele.filter((b) => Java.traceIsUseful(Java.trace(b))).length;
    ergebnisse.push(pruefe(`Zusehen: ${sehenswert} von ${beispiele.length} Theorie-Beispielen lassen sich beobachten (mindestens 14)`, sehenswert >= 14, String(sehenswert)));
  }

  // ------------------------------------------------------------ Kursinhalt
  {
    let verstanden = 0;
    const daneben = [];
    for (const aufgabe of alleAufgaben(kurs)) {
      let code, erwartet;
      if (aufgabe.type === "predictOutput" && aufgabe.code) {
        code = quelle(aufgabe.code);
        erwartet = aufgabe.expectedOutput;
      } else if (aufgabe.type === "code" && aufgabe.expectedOutput != null) {
        code = quelle(aufgabe.sampleSolution);
        erwartet = aufgabe.expectedOutput;
      } else {
        continue;
      }
      const lauf = Java.run(code);
      if (lauf.problem?.kind === "unsupported") continue;
      verstanden += 1;
      if (lauf.problem || ausgabeZeilen(lauf.output).join("\n") !== ausgabeZeilen(erwartet).join("\n")) {
        daneben.push(`${aufgabe.id}: ${lauf.problem ? lauf.problem.description : `„${lauf.output}“ statt „${erwartet}“`}`);
      }
    }
    ergebnisse.push(pruefe(
      `Interpreter: ${verstanden} Kursprogramme rechnen wie Java (mindestens 17)`,
      daneben.length === 0 && verstanden >= 17,
      daneben.slice(0, 5).join(" | "),
    ));
  }
  return ergebnisse;
}
