/* Prüfungen für die Arena der Web-Fassung (Web/arena.js) – dieselben Regeln wie
 * ArenaTests.swift: Jede Musterlösung schafft 3 Sterne, kein Startcode löst eine Mission,
 * Missionen brauchen nur Bekanntes, Wiedergabe-Tempo, Sterne mit Messwert und das Einfügen
 * aus der Befehlsleiste.
 *
 * Laufzeitneutral wie pruefungen.mjs: Interpreter und Arena werden als Text übergeben.
 */

/** Wertet java.js und arena.js aus und gibt `{ Java, Arena }` zurück. */
export function ladeArena(javaQuelltext, arenaQuelltext) {
  return new Function(`${javaQuelltext}\n${arenaQuelltext}\nreturn { Java: JavaKern, Arena: ArenaKern };`)();
}

const ok = (name) => ({ name, ok: true });
const fehler = (name, hinweis) => ({ name, ok: false, hinweis });
const pruefe = (name, bedingung, hinweis) => (bedingung ? ok(name) : fehler(name, hinweis));
const gleich = (a, b) => JSON.stringify(a) === JSON.stringify(b);

/** Welche Bausteine ein Programm benutzt – grob per Muster, wie in ArenaTests.swift. */
function benutzteBausteine(Java, quelle) {
  const roh = Java.strippingComments(quelle);
  const maskiert = Java.maskingLiterals(quelle);
  const muster = [
    ["ausgabe", /System\.out\.print/, maskiert],
    ["variable", /^\s*(int|String|double|boolean)\s+\w+\s*=/m, maskiert],
    ["hochzaehlen", /\b(\w+)\s*=\s*\1\s*\+\s*1\b|\w\+\+\s*;|\+=\s*1\b/, maskiert],
    ["textUndZahl", /"\s*\+|\+\s*"/, roh],
    ["antwort", /=\s*robot\.\w+\(\)/, maskiert],
    ["rechnen", /[\w)]\s*\*\s*[\w(]/, maskiert],
    ["if", /\bif\s*\(/, maskiert],
    ["ifElse", /\belse\b(?!\s+if\b)/, maskiert],
    ["elseIf", /\belse\s+if\b/, maskiert],
    ["nicht", /!(?!=)/, maskiert],
    ["while", /\bwhile\s*\(/, maskiert],
    ["for", /\bfor\s*\(\s*int\s+\w+\s*=/, maskiert],
    ["forRunter", /\bfor\s*\([^)]*--/, maskiert],
    ["methode", /\bstatic\s+void\s+\w+\s*\(\s*\)/, maskiert],
    ["methodeMitWert", /\bstatic\s+void\s+\w+\s*\(\s*\w+\s+\w+/, maskiert],
    ["array", /\[\]\s*\w+\s*=\s*\{/, maskiert],
    ["forEach", /\bfor\s*\(\s*\w+\s+\w+\s*:/, maskiert],
    ["textAnhaengen", /\+=\s*"/, roh],
  ];
  return new Set(muster.filter(([, re, text]) => re.test(text)).map(([id]) => id));
}

/** Eine Schleife steht im Block einer anderen – das erklärt der Kurs bis Lektion 8 nicht. */
function hatSchleifeInSchleife(Java, quelle) {
  const bloecke = [];
  for (const zeile of Java.maskingLiterals(quelle).split("\n")) {
    const istSchleife = /^\s*(\}\s*)?(for|while)\s*\(/.test(zeile);
    if (istSchleife && bloecke.includes(true)) return true;
    for (const z of zeile) {
      if (z === "}") bloecke.pop();
      if (z === "{") bloecke.push(istSchleife);
    }
  }
  return false;
}

export function arenaPruefungen({ Java, Arena }, missionen, kurs) {
  const ergebnisse = [];
  const katalog = Arena.catalog(missionen);
  const lektionen = kurs.modules.flatMap((m) => m.lessons.map((l) => l.id));
  const lektionsIndex = (m) => { const i = lektionen.indexOf(m.lessonId); return i < 0 ? Infinity : i; };

  /** Eine Testmission wie in ArenaTests.mission(…). */
  const testMission = (map, { muenzen = false, ausgabe = null } = {}) => Arena.catalog({
    playground: { map: ["###", "#R#", "###"] },
    missions: [{
      id: "test", kind: "training", title: "T", story: "", lessonId: "l01-hello", topicId: "syntax", difficulty: 1,
      worlds: [{ map, ...(ausgabe != null ? { expectedOutput: ausgabe } : {}) }], solution: "", hint: "",
      collectAllCoins: muenzen, bonus: [{ type: "allCoins" }, { type: "maxLines", value: 3 }],
      newCommands: Arena.COMMANDS.map((c) => c.name),
    }],
  }).missions[0];

  {
    const daneben = katalog.missions.filter((m) => {
      const r = Arena.run(m.solution, m);
      return !r.solved || r.stars !== 3;
    });
    ergebnisse.push(pruefe(
      `Arena: Jede der ${katalog.missions.length} Musterlösungen schafft alle Welten mit 3 Sternen`,
      daneben.length === 0 && katalog.missions.length >= 13,
      daneben.map((m) => {
        const r = Arena.run(m.solution, m);
        return `${m.id}: ${[...r.runs.flatMap((x) => x.failures), ...r.missingRequirements, ...r.criteria.filter((c) => !c.met).map((c) => c.title)].join("; ")}`;
      }).join(" | "),
    ));
  }
  {
    const daneben = katalog.missions.filter((m) => Arena.run(m.starterCode, m).solved);
    ergebnisse.push(pruefe("Arena: Der Startcode allein löst keine Mission", daneben.length === 0, daneben.map((m) => m.id).join(", ")));
  }
  {
    const gang = testMission(["#####", "#R.G#", "#####"]);
    const r = Arena.run("robot.move();\nrobot.move();\nrobot.move();", gang);
    const lauf = r.runs[0];
    const griff = Arena.run("robot.pickCoin();", gang).runs[0];
    ergebnisse.push(pruefe(
      "Arena: Gegen die Wand fahren bricht mit Zeilennummer ab, die Wand ist bekannt",
      !r.solved && lauf.problem?.line === 3 && lauf.problem.message.includes("Wand")
        && gleich(lauf.frames[lauf.frames.length - 1].action, { type: "crash", wall: { x: 4, y: 1 } })
        && lauf.frames[0].action.type === "start" && gleich(lauf.frames.map((f) => f.robot.x), [1, 2, 3, 3])
        && gleich(griff.frames[griff.frames.length - 1].action, { type: "crash", wall: null }),
      JSON.stringify(lauf.frames.map((f) => f.action)),
    ));
  }
  {
    const level = testMission(["######", "#Ro.G#", "######"], { muenzen: true, ausgabe: "fertig" });
    const faul = Arena.run("robot.move();\nrobot.move();\nrobot.move();\nSystem.out.println(\"fertig\");", level);
    const falsch = Arena.run("robot.move();\nrobot.pickCoin();\nrobot.move();\nrobot.move();", level);
    const gut = Arena.run("robot.move();\nrobot.pickCoin();\nrobot.move();\nrobot.move();\nSystem.out.println(\"fertig\");", level);
    ergebnisse.push(pruefe(
      "Arena: Ziel, Münzen und Ausgabe werden geprüft",
      !faul.solved && faul.runs[0].failures.some((f) => f.includes("Münze")) && !falsch.solved && gut.solved && gut.stars === 2,
      `faul: ${faul.runs[0].failures}, falsch: ${falsch.solved}, gut: ${gut.solved}/${gut.stars}`,
    ));
  }
  {
    const level = testMission(["####", "#RG#", "####"]);
    const gross = Arena.run("robot.Move();", level).runs[0].problem?.message || "";
    const nackt = Arena.run("move();", level).runs[0].problem?.message || "";
    ergebnisse.push(pruefe(
      "Arena: Hilfreiche Meldungen bei Tippfehlern im Roboter-Befehl",
      gross.includes("robot.move()") && nackt.includes("robot.move()"),
      `${gross} | ${nackt}`,
    ));
  }
  {
    const raum = testMission(["#####", "#R..#", "#..G#", "#####"]);
    const kreis = Arena.run("while (true) {\n  robot.turnLeft();\n}", raum).runs[0];
    const gang = testMission(["######", "#R..G#", "######"]);
    const fragen = Arena.run("while (!robot.atGoal()) {\n}", gang).runs[0];
    ergebnisse.push(pruefe(
      "Arena: Ein Roboter im Kreis wird gestoppt, eine Schleife ohne robot.move(); zeigt nur 6 Fragen",
      kreis.problem?.kind === "stepLimit" && fragen.problem?.kind === "stepLimit" && fragen.frames.length === 1 + Arena.SHOWN_QUESTIONS_IN_A_ROW,
      `Kreis: ${kreis.problem?.kind}, Fragen: ${fragen.frames.length} Bilder`,
    ));
  }
  {
    const level = testMission(["######", "#Ro.G#", "######"]);
    const nicht = Arena.run("robot.move();\nrobot.move();\nrobot.move();\nrobot.move();", level);
    const geloest = Arena.run("robot.move();\nrobot.move();\nrobot.move();", level);
    const muenzen = geloest.criteria.find((c) => c.criterion.type === "allCoins");
    const zeilen = geloest.criteria.find((c) => c.criterion.type === "maxLines");
    ergebnisse.push(pruefe(
      "Arena: Sterne nennen, was der Code geschafft hat („du: 3 Zeilen“)",
      nicht.criteria.every((c) => c.progress == null) && !muenzen.met && muenzen.progress === "1 Münze liegt noch"
        && zeilen.met && zeilen.progress === "du: 3 Zeilen",
      JSON.stringify(geloest.criteria.map((c) => [c.title, c.met, c.progress])),
    ));
  }
  {
    const kurz = katalog.mission("a01-erste-schritte");
    const bilder = Arena.run(kurz.solution, kurz).runs[0].frames;
    let gut = gleich(Arena.delays(bilder, 0.4), [0, ...bilder.slice(1).map(() => 0.4)]);
    const zuLang = [];
    for (const m of katalog.missions) {
      for (const lauf of Arena.run(m.solution, m).runs) {
        const d = Arena.delays(lauf.frames, 0.38);
        if (d.reduce((a, b) => a + b, 0) > 0.38 * Arena.MAX_STEPS + 0.001) zuLang.push(m.id);
        lauf.frames.forEach((f, i) => { if (i > 0 && f.action.type === "look" && !(d[i] < 0.38)) gut = false; });
      }
    }
    ergebnisse.push(pruefe("Arena: Wiedergabe – Fragen sind kürzer, lange Fahrten werden gestaucht", gut && zuLang.length === 0, zuLang.join(", ")));
  }
  {
    const schleife = "while (!robot.atGoal()) {\n    // Was soll in jeder Runde passieren?\n}";
    const faelle = [];
    const erstes = Arena.insert("robot.move();", schleife, null);
    faelle.push([erstes.code, "while (!robot.atGoal()) {\n    // Was soll in jeder Runde passieren?\n    robot.move();\n}"]);
    const zweites = Arena.insert("robot.pickCoin();", erstes.code, erstes.cursor);
    faelle.push([zweites.code.endsWith("    robot.move();\n    robot.pickCoin();\n}"), true]);
    faelle.push([Arena.insert("if (robot.onCoin()) {\n    robot.pickCoin();\n}", schleife, null).code.includes("\n    if (robot.onCoin()) {\n        robot.pickCoin();\n    }\n}"), true]);
    faelle.push([Arena.insert("robot.move();", "while (true) {\n}", 14).code, "while (true) {\n    robot.move();\n}"]);
    faelle.push([Arena.insert("robot.move();", "robot.turnLeft();\nrobot.pickCoin();", 18).code, "robot.turnLeft();\nrobot.move();\nrobot.pickCoin();"]);
    faelle.push([Arena.insert("robot.move();", "int a = 0;\n\nrobot.turnLeft();", 11).code, "int a = 0;\nrobot.move();\nrobot.turnLeft();"]);
    faelle.push([Arena.insert("robot.move();", "// Start\nrobot.move();\n", null).code, "// Start\nrobot.move();\nrobot.move();\n"]);
    faelle.push([Arena.insert("robot.move();", "", null).code, "robot.move();"]);
    const daneben = faelle.map(([ist, soll], i) => (gleich(ist, soll) ? null : `Fall ${i + 1}: ${JSON.stringify(ist)}`)).filter(Boolean);
    ergebnisse.push(pruefe("Arena: Befehle landen an der Stelle, an der man schreibt", daneben.length === 0, daneben.join(" | ")));
  }
  {
    const rahmen = "public class Test {\n    public static void main(String[] args) {\n        robot.move();\n    }\n}";
    ergebnisse.push(pruefe(
      "Arena: Codezeilen zählen nur echte Anweisungen – der Programmrahmen zählt nicht",
      Arena.codeLineCount("// Kommentar\nrobot.move();\n\n}\n  }\nrobot.move(); // weiter") === 2 && Arena.codeLineCount(rahmen) === 1,
      `${Arena.codeLineCount("// Kommentar\nrobot.move();\n\n}\n  }\nrobot.move(); // weiter")} / ${Arena.codeLineCount(rahmen)}`,
    ));
  }
  {
    const programm = "public class Test {\n    static void schritt() {\n        robot.move();\n    }\n\n    public static void main(String[] args) {\n        robot.move();\n    }\n}";
    const angehaengt = Arena.insert("robot.turnLeft();", programm, null).code;
    const faelle = [
      [angehaengt.includes("        robot.move();\n        robot.turnLeft();\n    }\n}"), "ans Ende von main"],
      [Arena.insert("robot.turnLeft();", programm, 5).code === angehaengt, "Cursor auf der Klassenzeile"],
      [Arena.insert("robot.turnLeft();", programm, programm.length).code === angehaengt, "Cursor hinter der letzten }"],
      [Arena.insert("robot.pickCoin();", programm, "public class Test {\n    static void schritt() {\n        robot.move();".length).code
        .includes("        robot.move();\n        robot.pickCoin();\n    }\n\n    public static void main"), "Cursor in einer Methode"],
      [Arena.insert("static void drehen() {\n    robot.turnLeft();\n}", programm, null).code
        .includes("    static void drehen() {\n        robot.turnLeft();\n    }\n\n    public static void main"), "Methode über main"],
      [Arena.insert("robot.move();", "public class A {\n    public static void main(String[] args) {\n    }\n}", null).code
        === "public class A {\n    public static void main(String[] args) {\n        robot.move();\n    }\n}", "leeres main"],
    ];
    const daneben = faelle.filter(([gut]) => !gut).map(([, name]) => name);
    ergebnisse.push(pruefe("Arena: Im echten Programm landen Befehle in main und Methoden in der Klasse", daneben.length === 0, daneben.join(", ")));
  }
  {
    const probleme = [];
    for (const m of katalog.missions) {
      if (!/^[A-Z][A-Za-z0-9]*$/.test(m.className)) probleme.push(`${m.id}: ${m.className}`);
      for (const schnipsel of [m.starterCode, m.solution]) {
        if (!schnipsel.startsWith(`public class ${m.className} {`) || !schnipsel.includes("    public static void main(String[] args) {")) probleme.push(`${m.id}: kein Programmrahmen`);
      }
    }
    if (new Set(katalog.missions.map((m) => m.className)).size !== katalog.missions.length) probleme.push("Klassennamen doppelt");
    const spielplatz = katalog.playground;
    if (!spielplatz.starterCode.startsWith("public class Spielplatz {") || Arena.run(spielplatz.starterCode, spielplatz).runs[0].problem) probleme.push("Spielplatz");
    ergebnisse.push(pruefe("Arena: Jede Mission ist ein echtes Java-Programm, die Datei passt zum Klassennamen", probleme.length === 0, probleme.join(" | ")));
  }

  // ------------------------------------------------------------ nur Bekanntes, klarer Auftrag
  {
    const indizes = katalog.missions.map(lektionsIndex);
    ergebnisse.push(pruefe("Arena: Missionen stehen in Kursreihenfolge", gleich(indizes, [...indizes].sort((a, b) => a - b)), katalog.missions.map((m) => m.lessonId).join(", ")));
  }
  {
    const probleme = [];
    for (const m of katalog.missions) {
      if (m.steps.length < 2) probleme.push(`${m.id}: Schritte fehlen`);
      if (!m.goals.length) probleme.push(`${m.id}: kein Auftrag`);
      if (!m.conceptIds.length) probleme.push(`${m.id}: keine Bausteine`);
      for (const id of m.conceptIds) {
        const baustein = katalog.concept(id);
        if (!baustein) { probleme.push(`${m.id}: Baustein ${id} fehlt`); continue; }
        if (baustein.lessonId && lektionen.indexOf(baustein.lessonId) > lektionsIndex(m)) probleme.push(`${m.id} braucht ${id} aus ${baustein.lessonId}`);
      }
    }
    ergebnisse.push(pruefe("Arena: Jede Mission sagt in Schritten, was zu tun ist, und nennt ihre Bausteine", probleme.length === 0, probleme.join(" | ")));
  }
  {
    // Ein Baustein im Auftrag deckt auch die einfacheren mit ab (if–else enthält if).
    const abgedeckt = { ausgabe: ["textUndZahl"], variable: ["antwort", "rechnen", "text"], if: ["ifElse", "elseIf"], ifElse: ["elseIf"], for: ["forRunter"] };
    const probleme = [];
    for (const m of katalog.missions) {
      for (const schnipsel of [m.starterCode, m.solution]) {
        for (const benutzt of benutzteBausteine(Java, schnipsel)) {
          const genannt = m.conceptIds.some((id) => id === benutzt || (abgedeckt[benutzt] || []).includes(id));
          const gelehrtIn = katalog.concept(benutzt)?.lessonId;
          const gelehrt = gelehrtIn != null && lektionen.indexOf(gelehrtIn) >= 0 && lektionen.indexOf(gelehrtIn) <= lektionsIndex(m);
          if (!genannt && !gelehrt) probleme.push(`${m.id} braucht „${benutzt}“`);
        }
        if (hatSchleifeInSchleife(Java, schnipsel)) probleme.push(`${m.id}: Schleife in der Schleife`);
        if (/^[^{\n]*\bif\s*\([^{\n]*;\s*$/m.test(Java.maskingLiterals(schnipsel))) probleme.push(`${m.id}: if ohne Klammern`);
        for (const [, name] of Java.maskingLiterals(schnipsel).matchAll(/robot\.(\w+)\s*\(/g)) {
          if (!m.commandNames.includes(name)) probleme.push(`${m.id} nutzt robot.${name}() zu früh`);
        }
      }
    }
    ergebnisse.push(pruefe(
      "Arena: Missionen brauchen nur Bausteine und Befehle, die schon erklärt sind",
      probleme.length === 0 && gleich(katalog.mission("a01-erste-schritte").commandNames, ["move", "pickCoin"]),
      probleme.join(" | "),
    ));
  }
  {
    const vorlagen = (id) => katalog.templates(katalog.mission(id), lektionen).map((t) => t.name);
    ergebnisse.push(pruefe(
      "Arena: Die Befehlsleiste bietet nur Vorlagen an, die schon erklärt sind",
      vorlagen("a01-erste-schritte").length === 0 && vorlagen("b1-tunnelschatz").length === 0
        && gleich(vorlagen("a04-die-weiche"), ["if"]) && gleich(vorlagen("a05-langer-gang"), ["if", "while", "for"])
        && !vorlagen("t2-zickzack").includes("Methode") && vorlagen("a06-die-treppe").includes("Methode"),
      ["a04-die-weiche", "a05-langer-gang", "t2-zickzack"].map((id) => `${id}: ${vorlagen(id)}`).join(" | "),
    ));
  }
  {
    const neu = (missionId, bausteinId) => katalog.conceptUses(katalog.mission(missionId)).find((u) => u.id === bausteinId)?.isNew;
    ergebnisse.push(pruefe(
      "Arena: Neues ist markiert – Bekanntes nicht",
      neu("a05-langer-gang", "nicht") === true && neu("a05-langer-gang", "while") === false && neu("t3-huerdenlauf", "nicht") === false,
      "",
    ));
  }
  {
    const erste = katalog.mission("a01-erste-schritte");
    const knacker = katalog.mission("b3-codeknacker");
    const weiche = katalog.mission("a04-die-weiche");
    ergebnisse.push(pruefe(
      "Arena: Der Auftrag nennt Ziel, Ausgabe, Pflicht und Welten",
      gleich(erste.goals.map((g) => g.kind), ["reachGoal", "output"])
        && gleich(erste.goals[1].outputs, [{ world: null, text: "Angekommen!" }])
        && gleich(knacker.goals.find((g) => g.kind === "output").outputs.map((o) => o.world), [1, 2])
        && gleich(weiche.goals.map((g) => g.kind), ["reachGoal", "collectCoins", "rule", "allWorlds"]),
      JSON.stringify(erste.goals),
    ));
  }
  return ergebnisse;
}
