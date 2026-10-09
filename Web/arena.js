/* Die Arena: Byte, der Roboter, wird mit echtem Java gesteuert. Dieselben Missionen und
   Regeln wie in der Apple-App (Packages/JavaQuestKit/Sources/JavaQuestKit/Arena) und unter
   Windows – Welten, Sterne, Tempo der Wiedergabe und das Einfügen aus der Befehlsleiste.

   Nur Logik, keine Oberfläche: Die steht in app.js. Klassisches Browser-Skript; es braucht
   `JavaKern` aus java.js und legt nur `ArenaKern` an. Die Prüfungen laden dieselbe Datei
   (tests/arena.mjs). */
const ArenaKern = (() => {
  "use strict";
  const Java = JavaKern;

  // MARK: - Befehle

  /** Die Befehle des Roboters – mit Kurzbeschreibung für die Befehlsleiste. */
  const COMMANDS = [
    { name: "move", returnType: "void", summary: "Ein Feld vorwärts fahren",
      detail: "Fährt ein Feld in Blickrichtung. Steht dort eine Wand, gibt es einen Unfall." },
    { name: "turnLeft", returnType: "void", summary: "Um 90° nach links drehen",
      detail: "Dreht Byte auf der Stelle um 90° nach links – er fährt dabei nicht." },
    { name: "turnRight", returnType: "void", summary: "Um 90° nach rechts drehen",
      detail: "Dreht Byte auf der Stelle um 90° nach rechts – er fährt dabei nicht." },
    { name: "pickCoin", returnType: "void", summary: "Münze auf dem Feld aufheben",
      detail: "Hebt die Münze auf, auf der Byte gerade steht. Liegt dort keine, gibt es einen Fehler." },
    { name: "frontIsClear", returnType: "boolean", summary: "Ist vorne frei?",
      detail: "Antwortet true, wenn das Feld vor Byte frei ist – sonst false." },
    { name: "leftIsClear", returnType: "boolean", summary: "Ist links frei?",
      detail: "Antwortet true, wenn das Feld links neben Byte frei ist – sonst false." },
    { name: "rightIsClear", returnType: "boolean", summary: "Ist rechts frei?",
      detail: "Antwortet true, wenn das Feld rechts neben Byte frei ist – sonst false." },
    { name: "onCoin", returnType: "boolean", summary: "Liegt hier eine Münze?",
      detail: "Antwortet true, wenn auf dem Feld von Byte eine Münze liegt – sonst false." },
    { name: "atGoal", returnType: "boolean", summary: "Steht er auf dem Ziel?",
      detail: "Antwortet true, wenn Byte auf der Zielflagge steht – sonst false." },
    { name: "coins", returnType: "int", summary: "Wie viele Münzen hat er?",
      detail: "Antwortet mit der Zahl der Münzen, die Byte schon aufgehoben hat (eine ganze Zahl)." },
  ].map((c) => Object.freeze({ ...c, call: `robot.${c.name}()` }));
  const commandNamed = (name) => COMMANDS.find((c) => c.name === name) || null;

  // MARK: - Welt

  const HEADINGS = {
    north: { left: "west", right: "east", dx: 0, dy: -1, direction: "nach oben", degrees: 270 },
    east: { left: "north", right: "south", dx: 1, dy: 0, direction: "nach rechts", degrees: 0 },
    south: { left: "east", right: "west", dx: 0, dy: 1, direction: "nach unten", degrees: 90 },
    west: { left: "south", right: "north", dx: -1, dy: 0, direction: "nach links", degrees: 180 },
  };
  const key = (p) => `${p.x},${p.y}`;
  const moved = (p, heading) => ({ x: p.x + HEADINGS[heading].dx, y: p.y + HEADINGS[heading].dy });
  const same = (a, b) => a != null && b != null && a.x === b.x && a.y === b.y;

  /** Eine Spielwelt als Textkarte: # Wand · . Boden · o Münze · G Ziel · R Startfeld. */
  function world(spec) {
    const map = spec.map;
    const points = (ch) => {
      const result = [];
      map.forEach((row, y) => Array.from(row).forEach((c, x) => { if (c === ch) result.push({ x, y }); }));
      return result;
    };
    const cell = (p) => {
      if (p.y < 0 || p.y >= map.length) return "#";
      const row = Array.from(map[p.y]);
      if (p.x < 0 || p.x >= row.length) return "#";
      return row[p.x];
    };
    return {
      map,
      facing: spec.facing || "east",
      expectedOutput: spec.expectedOutput == null ? null : spec.expectedOutput,
      width: Math.max(0, ...map.map((r) => Array.from(r).length)),
      height: map.length,
      coins: points("o"),
      goal: points("G")[0] || null,
      start: points("R")[0] || null,
      cell,
      isWall: (p) => cell(p) === "#",
    };
  }

  // MARK: - Simulation

  const MAX_ACTIONS = 400;
  const MAX_FRAMES = 1500;
  /** So oft darf der Roboter hintereinander gefragt werden, ohne sich zu bewegen. */
  const MAX_QUESTIONS_IN_A_ROW = 250;
  /** So viele Fragen hintereinander zeigt die Wiedergabe als Sprechblase. Mehr braucht keine
      Mission zwischen zwei Aktionen – eine Schleife ohne robot.move(); hätte sonst 250 gleiche Bilder. */
  const SHOWN_QUESTIONS_IN_A_ROW = 6;

  /** Stellt dem Interpreter das Objekt `robot` bereit und zeichnet jedes Standbild auf. */
  class Simulation {
    constructor(spec, commandNames = COMMANDS.map((c) => c.name)) {
      this.world = spec;
      this.commandNames = commandNames;
      this.objectNames = new Set(["robot"]);
      this.robot = spec.start || { x: 0, y: 0 };
      this.heading = spec.facing;
      this.coins = new Set(spec.coins.map(key));
      this.collected = 0;
      this.actions = 0;
      this.frames = [];
      this.questionsInARow = 0;
      this.record({ type: "start" }, null);
    }

    get wantsSnapshot() { return this.frames.length < MAX_FRAMES; }

    record(action, context) {
      if (this.frames.length >= MAX_FRAMES) return;
      this.frames.push({
        robot: { ...this.robot }, heading: this.heading, coins: new Set(this.coins), collected: this.collected, action,
        line: context ? context.line : null, output: context ? context.output : "", variables: context ? context.variables : [],
      });
    }

    call(object, method, args, context) {
      const command = commandNamed(method);
      if (!command) {
        const similar = COMMANDS.find((c) => c.name.toLowerCase() === method.toLowerCase());
        const tip = similar
          ? ` Meintest du robot.${similar.name}()? Achte auf Groß- und Kleinschreibung.`
          : ` Er kann hier: ${this.commandNames.map((n) => `${n}()`).join(", ")}.`;
        throw new Java.JavaProblem("syntax", `Der Roboter kennt den Befehl ${method}() nicht.${tip}`, context.line);
      }
      if (args.length) throw new Java.JavaProblem("syntax", `robot.${method}() braucht nichts in den Klammern.`, context.line);
      if (command.returnType === "void") {
        this.questionsInARow = 0;
        this.actions += 1;
        if (this.actions > MAX_ACTIONS) {
          throw new Java.JavaProblem("stepLimit", `Der Roboter hat schon ${MAX_ACTIONS} Aktionen gemacht und ist immer noch unterwegs – läuft er im Kreis?`, context.line);
        }
      }
      switch (method) {
        case "move": {
          const next = moved(this.robot, this.heading);
          if (this.world.isWall(next)) {
            this.record({ type: "crash", wall: next }, context);
            throw new Java.JavaProblem("runtime", "Bumm! Der Roboter ist gegen eine Wand gefahren. Prüfe vorher mit robot.frontIsClear(), ob der Weg frei ist.", context.line);
          }
          this.robot = next;
          this.record({ type: "move" }, context);
          break;
        }
        case "turnLeft":
          this.heading = HEADINGS[this.heading].left;
          this.record({ type: "turnLeft" }, context);
          break;
        case "turnRight":
          this.heading = HEADINGS[this.heading].right;
          this.record({ type: "turnRight" }, context);
          break;
        case "pickCoin":
          if (!this.coins.has(key(this.robot))) {
            this.record({ type: "crash", wall: null }, context);
            throw new Java.JavaProblem("runtime", "Hier liegt keine Münze – der Roboter greift ins Leere. Prüfe vorher mit robot.onCoin().", context.line);
          }
          this.coins.delete(key(this.robot));
          this.collected += 1;
          this.record({ type: "pickCoin" }, context);
          break;
        case "coins":
          return Java.V.int(this.collected);
        default: {
          this.questionsInARow += 1;
          if (this.questionsInARow > MAX_QUESTIONS_IN_A_ROW) {
            throw new Java.JavaProblem("stepLimit", "Byte wird immer wieder gefragt, bewegt sich aber nicht – vermutlich eine Schleife ohne robot.move(); im Körper.", context.line);
          }
          const h = HEADINGS[this.heading];
          const answer = {
            frontIsClear: () => !this.world.isWall(moved(this.robot, this.heading)),
            leftIsClear: () => !this.world.isWall(moved(this.robot, h.left)),
            rightIsClear: () => !this.world.isWall(moved(this.robot, h.right)),
            onCoin: () => this.coins.has(key(this.robot)),
          }[method] || (() => same(this.robot, this.world.goal));
          const value = answer();
          if (this.questionsInARow <= SHOWN_QUESTIONS_IN_A_ROW) {
            this.record({ type: "look", question: method, answer: value }, context);
          }
          return Java.V.boolean(value);
        }
      }
      return Java.VOID;
    }
  }

  // MARK: - Auswertung

  const STEP_LIMIT = 60000;

  /** Wie AnswerEvaluator.outputLines: Leerzeichen am Zeilenende und Leerzeilen außen zählen nicht. */
  function outputLines(text) {
    const lines = String(text).replace(/\r\n/g, "\n").split("\n").map((l) => l.replace(/[ \t]+$/, ""));
    while (lines.length && lines[0] === "") lines.shift();
    while (lines.length && lines[lines.length - 1] === "") lines.pop();
    return lines;
  }

  function outputDifference(output, expected) {
    const given = outputLines(output);
    if (!given.length) return "aber dein Programm gibt nichts aus. Fehlt ein System.out.println(…)?";
    const shown = given.slice(0, 3).join(" ⏎ ") + (given.length > 3 ? " …" : "");
    return `dein Programm gibt „${shown}“ aus, erwartet wird „${outputLines(expected).join(" ⏎ ")}“.`;
  }

  const matches = (pattern, text) => { try { return new RegExp(pattern).test(text); } catch { return false; } };

  /** Zählt „echte“ Codezeilen: ohne Leerzeilen, Kommentare, reine Klammerzeilen und ohne den
      Programmrahmen (public class … und public static void main(…)) – der gehört zu jedem
      Programm und soll bei „Höchstens N Zeilen“ nicht zählen. */
  function codeLineCount(code) {
    return Java.strippingComments(code).split("\n").map((l) => l.trim())
      .filter((l) => l !== "" && !Array.from(l).every((c) => "{}();".includes(c)) && !isFrameLine(l)).length;
  }

  /** Kopf der Klasse oder der main-Methode. */
  function isFrameLine(line) {
    return /^(public\s+)?(final\s+)?class\s+\w+\s*\{?$/.test(line)
      || /^public\s+static\s+void\s+main\s*\(\s*String\s*(\[\]\s*\w+|\.\.\.\s*\w+|\w+\s*\[\])\s*\)\s*\{?$/.test(line);
  }

  function criterionTitle(c) {
    switch (c.type) {
      case "allCoins": return "Alle Münzen eingesammelt";
      case "maxLines": return `Höchstens ${c.value} Zeilen Code`;
      case "maxActions": return `Höchstens ${c.value} Roboter-Aktionen`;
      default: return c.label;
    }
  }

  function progressOf(c, met, runs, lines) {
    switch (c.type) {
      case "allCoins": {
        if (met) return null;
        const left = runs.reduce((sum, r) => sum + r.coinsLeft, 0);
        return left === 1 ? "1 Münze liegt noch" : `${left} Münzen liegen noch`;
      }
      case "maxLines": return lines === 1 ? "du: 1 Zeile" : `du: ${lines} Zeilen`;
      // Bei mehreren Welten zählt die Welt mit den meisten Aktionen.
      case "maxActions": return `du: ${Math.max(0, ...runs.map((r) => r.actions))}`;
      default: return null;
    }
  }

  function evaluateWorld(spec, simulation, result, mission) {
    const failures = [];
    if (result.problem) failures.push(result.problem.description);
    const reachedGoal = spec.goal == null || same(simulation.robot, spec.goal);
    if (!result.problem) {
      if (mission.reachGoal && !reachedGoal) failures.push("Der Roboter steht am Ende nicht auf dem Zielfeld.");
      if (mission.collectAllCoins && simulation.coins.size > 0) {
        const count = simulation.coins.size;
        failures.push(count === 1 ? "Es liegt noch 1 Münze herum." : `Es liegen noch ${count} Münzen herum.`);
      }
    }
    let outputMatches = null;
    if (spec.expectedOutput != null) {
      outputMatches = outputLines(result.output).join("\n") === outputLines(spec.expectedOutput).join("\n");
      if (!result.problem && !outputMatches) {
        failures.push(outputDifference(result.output, spec.expectedOutput));
      }
    }
    return {
      world: spec, frames: simulation.frames, output: result.output, problem: result.problem,
      reachedGoal, coinsLeft: simulation.coins.size, actions: simulation.actions, outputMatches, failures,
      get succeeded() { return this.failures.length === 0; },
    };
  }

  /** Führt Code in allen Welten einer Mission aus und bewertet das Ergebnis. */
  function run(code, mission) {
    const source = Java.normalizingTypography(code);
    const runs = [];
    const warnings = [];
    for (const spec of mission.worlds) {
      const simulation = new Simulation(spec, mission.commandNames);
      const result = Java.run(source, { stepLimit: STEP_LIMIT, host: simulation });
      for (const w of result.warnings) if (!warnings.some((x) => x.message === w.message && x.line === w.line)) warnings.push(w);
      runs.push(evaluateWorld(spec, simulation, result, mission));
      // Ein Syntaxfehler ist in jeder Welt derselbe – ein Lauf reicht.
      if (result.problem && (result.problem.kind === "syntax" || result.problem.kind === "unsupported")) break;
    }

    const masked = Java.maskingLiterals(source);
    const missingRequirements = mission.requirements.filter((rule) => {
      const hit = matches(rule.pattern, rule.scope === "raw" ? Java.strippingComments(source) : masked);
      return rule.rule === "require" ? !hit : hit;
    }).map((rule) => rule.message);

    const solved = runs.length === mission.worlds.length && runs.every((r) => r.succeeded) && missingRequirements.length === 0;
    const lines = codeLineCount(source);
    const criteria = mission.bonus.map((criterion) => {
      let met;
      switch (criterion.type) {
        case "allCoins": met = runs.length === mission.worlds.length && runs.every((r) => r.coinsLeft === 0); break;
        case "maxLines": met = lines <= criterion.value; break;
        case "maxActions": met = runs.every((r) => r.actions <= criterion.value); break;
        default: met = matches(criterion.pattern, masked);
      }
      return { criterion, title: criterionTitle(criterion), met: solved && met, progress: solved ? progressOf(criterion, met, runs, lines) : null };
    });
    const stars = solved ? 1 + criteria.filter((c) => c.met).length : 0;
    const failing = runs.findIndex((r) => !r.succeeded);
    return { runs, missingRequirements, solved, criteria, codeLines: lines, warnings, stars, firstFailingWorld: failing === -1 ? null : failing };
  }

  // MARK: - Missionen und Katalog

  function mission(raw) {
    const m = {
      id: raw.id, kind: raw.kind, title: raw.title, story: raw.story, lessonId: raw.lessonId,
      moduleId: raw.moduleId || null, topicId: raw.topicId, difficulty: raw.difficulty,
      worlds: raw.worlds.map(world),
      starterCode: typeof raw.starterCode === "string" ? raw.starterCode : (raw.starterCode?.lines || []).map((l) => l.code).join("\n"),
      solution: typeof raw.solution === "string" ? raw.solution : (raw.solution?.lines || []).map((l) => l.code).join("\n"),
      hint: raw.hint,
      reachGoal: raw.reachGoal !== false,
      collectAllCoins: raw.collectAllCoins === true,
      requirements: raw.requirements || [],
      bonus: raw.bonus || [],
      newCommands: raw.newCommands || [],
      steps: raw.steps || [],
      conceptIds: raw.concepts || [],
      /** Name der Klasse im Programm – und damit der Datei (ErsteSchritte.java). */
      className: raw.className || "Mission",
      commandNames: COMMANDS.map((c) => c.name),
    };
    m.goals = goalsOf(m);
    return m;
  }

  /** Was zum Lösen nötig ist – als Liste für den Auftrag. */
  function goalsOf(m) {
    const goals = [];
    if (m.reachGoal) goals.push({ kind: "reachGoal", text: "Fahr Byte auf die Zielflagge." });
    if (m.collectAllCoins) goals.push({ kind: "collectCoins", text: "Sammle alle Münzen ein." });
    const outputs = m.worlds.map((w, i) => (w.expectedOutput == null ? null : { world: i + 1, text: w.expectedOutput })).filter(Boolean);
    if (outputs.length) {
      if (new Set(outputs.map((o) => o.text)).size === 1 && outputs.length === m.worlds.length) {
        goals.push({ kind: "output", text: "Gib am Ende genau das aus:", outputs: [{ world: null, text: outputs[0].text }] });
      } else {
        goals.push({ kind: "output", text: "Gib am Ende genau das aus – in jeder Welt etwas anderes:", outputs });
      }
    }
    for (const rule of m.requirements) goals.push({ kind: "rule", text: rule.message });
    if (m.worlds.length === 2) {
      goals.push({ kind: "allWorlds", text: "Derselbe Code muss in beiden Welten klappen. Nach dem Ausführen schaltest du über „Welt 1“ und „Welt 2“ um." });
    } else if (m.worlds.length > 2) {
      goals.push({ kind: "allWorlds", text: `Derselbe Code muss in allen ${m.worlds.length} Welten klappen. Nach dem Ausführen schaltest du über „Welt 1“ bis „Welt ${m.worlds.length}“ um.` });
    }
    return goals.map((g) => ({ outputs: [], ...g }));
  }

  /** Der Spielplatz: eine freie Welt ohne Ziel, ohne Pflicht und ohne Sterne. */
  function playground(spec) {
    return mission({
      id: "playground", kind: "training", title: "Spielplatz",
      story: "Hier gibt es kein Ziel und keine Bewertung – probier einfach aus, was Byte alles kann.",
      lessonId: "", topicId: "syntax", difficulty: 1, worlds: [spec], className: "Spielplatz",
      starterCode: "public class Spielplatz {\n    public static void main(String[] args) {\n        // Probier dich aus!\n        robot.move();\n        robot.turnLeft();\n    }\n}",
      solution: "", hint: "Tippe unten auf einen Befehl, um ihn einzufügen.", reachGoal: false,
      newCommands: COMMANDS.map((c) => c.name),
    });
  }

  /** Vorlagen für die Befehlsleiste – nur angeboten, wenn ihre Bausteine und Befehle schon bekannt sind. */
  const TEMPLATES = [
    { name: "if", code: "if (robot.onCoin()) {\n    robot.pickCoin();\n}", conceptIds: ["if"], commandNames: ["onCoin", "pickCoin"] },
    { name: "while", code: "while (!robot.atGoal()) {\n    robot.move();\n}", conceptIds: ["while", "nicht"], commandNames: ["atGoal", "move"] },
    { name: "for", code: "for (int i = 0; i < 3; i++) {\n    robot.move();\n}", conceptIds: ["for"], commandNames: ["move"] },
    { name: "Methode", code: "static void schritt() {\n    robot.move();\n}", conceptIds: ["methode"], commandNames: ["move"] },
  ];

  /** Alle Missionen der Arena (arena_missions.json) – in Kursreihenfolge. */
  function catalog(json) {
    // Jede Mission kann die Befehle, die sie selbst oder eine Mission vor ihr eingeführt hat.
    const known = new Set();
    const missions = json.missions.map((raw) => {
      const m = mission(raw);
      m.newCommands.forEach((n) => known.add(n));
      m.commandNames = COMMANDS.map((c) => c.name).filter((n) => known.has(n));
      return m;
    });
    const concepts = json.concepts || [];
    const conceptById = (id) => concepts.find((c) => c.id === id) || null;
    const before = (m) => {
      const index = missions.findIndex((x) => x.id === m.id);
      return index < 0 ? [] : missions.slice(0, index);
    };

    /** Ist ein Baustein in dieser Mission bekannt? Ja, wenn der Kurs ihn bis zu ihrer Lektion
        beigebracht hat, die Mission ihn selbst erklärt oder eine frühere Mission ihn eingeführt hat. */
    function knows(conceptId, m, lessonOrder) {
      if (m.conceptIds.includes(conceptId)) return true;
      if (before(m).some((x) => x.conceptIds.includes(conceptId))) return true;
      const taughtIn = conceptById(conceptId)?.lessonId;
      if (!taughtIn) return false;
      const taught = lessonOrder.indexOf(taughtIn), current = lessonOrder.indexOf(m.lessonId);
      return taught >= 0 && current >= 0 && taught <= current;
    }

    return {
      missions,
      playground: playground(json.playground),
      concepts,
      concept: conceptById,
      mission: (id) => missions.find((m) => m.id === id) || null,
      /** Die Abschluss-Mission einer Lektion. */
      lessonMission: (lessonId) => missions.find((m) => m.kind === "lesson" && m.lessonId === lessonId) || null,
      bossMission: (moduleId) => missions.find((m) => m.kind === "boss" && m.moduleId === moduleId) || null,
      /** Die Bausteine einer Mission für ihren Auftrag – „NEU“, wenn sie hier zum ersten Mal vorkommen. */
      conceptUses(m) {
        const earlier = before(m);
        return m.conceptIds.map((id) => {
          const concept = conceptById(id);
          if (!concept) return null;
          const introducedBefore = earlier.some((x) => x.conceptIds.includes(id));
          return { id, concept, isNew: concept.lessonId == null && !introducedBefore };
        }).filter(Boolean);
      },
      knows,
      /** Vorlagen für die Befehlsleiste, die in dieser Mission schon verständlich sind. */
      templates: (m, lessonOrder) => TEMPLATES.filter((t) =>
        t.conceptIds.every((id) => knows(id, m, lessonOrder)) && t.commandNames.every((n) => m.commandNames.includes(n))),
    };
  }

  // MARK: - Wiedergabe

  /** Anteil einer normalen Schrittdauer, den eine Frage bekommt. */
  const QUESTION_WEIGHT = 0.4;
  /** So viele normale Schritte lang darf eine Wiedergabe höchstens dauern. */
  const MAX_STEPS = 50;
  /** Kürzer wird kein Bild – sonst sieht man die Bewegung nicht mehr. */
  const MINIMUM_DELAY = 0.05;

  /** Wartezeit in Sekunden, bevor Bild i erscheint ([0] ist das Startbild und immer 0).
      Fragen ziehen schneller vorbei als Fahrten, lange Fahrten werden gestaucht. */
  function delays(frames, base) {
    if (!frames.length) return [];
    const weights = frames.map((f, i) => (i === 0 ? 0 : f.action.type === "look" ? QUESTION_WEIGHT : 1));
    const total = weights.reduce((a, b) => a + b, 0);
    const scale = total > MAX_STEPS ? MAX_STEPS / total : 1;
    return weights.map((w, i) => (i === 0 ? 0 : Math.max(base * w * scale, MINIMUM_DELAY)));
  }

  // MARK: - Einfügen aus der Befehlsleiste

  /** Fügt einen Befehl oder eine Vorlage als eigene, eingerückte Zeile ein – an der Cursorzeile
      (am Zeilenanfang davor, sonst dahinter), ohne Cursor im ersten leeren Block mit
      Platzhalter-Kommentar, sonst am Ende. Positionen sind UTF-16 wie selectionStart. */
  function insert(snippet, code, cursor) {
    const lines = code.split("\n");
    if (code.trim() === "") return { code: snippet, cursor: snippet.length };

    // Ein echtes Programm (Klasse + main): Methoden gehören in die Klasse über main,
    // alle anderen Befehle in eine Methode – nie neben den Rahmen.
    const frame = programFrame(lines);
    if (frame && snippet.trim().startsWith("static ")) {
      const indent = lines[frame.mainLine].match(/^[ \t]*/)[0];
      const block = snippet.split("\n").map((l) => (l === "" ? l : indent + l));
      lines.splice(frame.mainLine, 0, ...block, "");
      const lastInserted = frame.mainLine + block.length - 1;
      const newCursor = lines.slice(0, lastInserted + 1).reduce((sum, l) => sum + l.length, 0) + lastInserted;
      return { code: lines.join("\n"), cursor: newCursor };
    }

    let index;
    let before = false;
    if (cursor != null) {
      [index, before] = position(cursor, lines);
    } else {
      index = placeholderLine(lines);
      if (index == null) index = frame ? frame.lastBodyLine : lastCodeLine(lines);
    }
    if (frame && !insideMethod(index, before, lines)) {
      index = frame.lastBodyLine;
      before = false;
    }
    const line = lines[index];
    const isBlank = line.trim() === "";
    let indent = line.match(/^[ \t]*/)[0];
    if (!before && !isBlank && opensBlock(line)) indent += "    ";
    const block = snippet.split("\n").map((l) => (l === "" ? l : indent + l));

    let insertAt;
    if (isBlank) {
      // Eine leere Zeile wird zur Befehlszeile.
      lines.splice(index, 1, ...block);
      insertAt = index;
    } else {
      insertAt = before ? index : index + 1;
      lines.splice(insertAt, 0, ...block);
    }
    const lastInserted = insertAt + block.length - 1;
    const newCursor = lines.slice(0, lastInserted + 1).reduce((sum, l) => sum + l.length, 0) + lastInserted;
    return { code: lines.join("\n"), cursor: newCursor };
  }

  function position(cursor, lines) {
    let offset = 0;
    for (let index = 0; index < lines.length; index += 1) {
      const line = lines[index];
      if (cursor <= offset + line.length) {
        const column = cursor - offset;
        const leading = line.match(/^[ \t]*/)[0].length;
        return [index, line.trim() !== "" && column <= leading];
      }
      offset += line.length + 1;
    }
    return [lines.length - 1, false];
  }

  function placeholderLine(lines) {
    for (let i = 0; i < lines.length - 1; i += 1) {
      if (lines[i].trim().startsWith("//") && lines[i + 1].trim().startsWith("}")) return i;
    }
    return null;
  }

  function lastCodeLine(lines) {
    for (let i = lines.length - 1; i >= 0; i -= 1) if (lines[i].trim() !== "") return i;
    return lines.length - 1;
  }

  const opensBlock = (line) => line.split("//")[0].trim().endsWith("{");

  /** Klasse und main eines echten Programms – wo main steht und wo ihr Rumpf endet. */
  function programFrame(lines) {
    if (!lines.some((l) => /^\s*(public\s+)?(final\s+)?class\s+\w+/.test(l))) return null;
    const main = lines.findIndex((l) => /\bstatic\s+void\s+main\s*\(/.test(l));
    if (main < 0) return null;
    let depth = 0;
    let opened = false;
    let end = null;
    for (let i = main; i < lines.length; i += 1) {
      depth += braceDelta(lines[i]);
      if (depth > 0) opened = true;
      if (opened && depth <= 0) { end = i; break; }
    }
    if (end == null) return null;
    let lastBodyLine = main;
    for (let i = main + 1; i < end; i += 1) if (lines[i].trim() !== "") lastBodyLine = i;
    return { mainLine: main, lastBodyLine };
  }

  /** Landet ein Befehl an dieser Stelle in einer Methode (Tiefe ≥ 2: Klasse + Methode)? */
  function insideMethod(index, before, lines) {
    const upTo = before || lines[index].trim() === "" ? index : index + 1;
    return lines.slice(0, upTo).reduce((sum, l) => sum + braceDelta(l), 0) >= 2;
  }

  /** Geschweifte Klammern einer Zeile ({ +1, } −1) – ohne Text in Anführungszeichen und Kommentare. */
  function braceDelta(line) {
    let delta = 0;
    let quote = null;
    let previous = " ";
    for (const c of line) {
      if (quote) {
        if (c === quote && previous !== "\\") quote = null;
      } else if (c === "\"" || c === "'") {
        quote = c;
      } else if (c === "/" && previous === "/") {
        break;
      } else if (c === "{") {
        delta += 1;
      } else if (c === "}") {
        delta -= 1;
      }
      previous = c;
    }
    return delta;
  }

  return {
    COMMANDS, commandNamed, HEADINGS, TEMPLATES,
    world, Simulation, run, catalog, playground, delays, insert, codeLineCount, criterionTitle, outputLines,
    SHOWN_QUESTIONS_IN_A_ROW, MAX_STEPS,
  };
})();
