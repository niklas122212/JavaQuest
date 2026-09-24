/* Die Prüfungen für die Web-Fassung.
 *
 * Warum es sie gibt: `Web/app.js` ist eine Handübersetzung des Kerns – Score, Ränge,
 * Wiedervorlage, Einstufung und der komplette Prüfer stehen dort ein zweites Mal.
 * Apple und Windows haben dafür Testreihen, die Web-Fassung hatte lange keine. Genau
 * an dieser Stelle driften die drei Fassungen auseinander, ohne dass es auffällt.
 *
 * Die Zahlen hier sind dieselben wie in `CourseContentTests.swift` und `CoreTests.kt`.
 * Wer eine davon ändert, muss sie überall ändern – das ist der Zweck.
 *
 * Laufzeitneutral geschrieben: keine Node- und keine Browser-Schnittstellen, damit
 * dieselben Prüfungen in der CI und von Hand im Browser laufen.
 */
import { alleAufgaben, leererStand, musterloesung } from "./laden.mjs";

/** Ergebnis einer einzelnen Prüfung. */
const ok = (name) => ({ name, ok: true });
const fehler = (name, hinweis) => ({ name, ok: false, hinweis });

function pruefe(name, bedingung, hinweis) {
  return bedingung ? ok(name) : fehler(name, hinweis);
}

export function pruefungen(api, kurs, beispiele) {
  const aufgaben = alleAufgaben(kurs);
  const ergebnisse = [];

  // ---------------------------------------------------------------- Prüfer
  {
    const daneben = aufgaben.filter((a) => !api.auswerten(a, musterloesung(a)).richtig);
    ergebnisse.push(pruefe(
      `Alle ${aufgaben.length} Musterlösungen werden akzeptiert`,
      daneben.length === 0,
      `abgelehnt: ${daneben.slice(0, 5).map((a) => a.id).join(", ")}`,
    ));
  }
  {
    const gleichwertig = kurs.equivalentSolutions || {};
    const nachId = Object.fromEntries(aufgaben.map((a) => [a.id, a]));
    const daneben = [];
    let anzahl = 0;
    for (const [id, loesungen] of Object.entries(gleichwertig)) {
      for (const loesung of loesungen) {
        anzahl += 1;
        if (!api.auswerten(nachId[id], loesung).richtig) daneben.push(id);
      }
    }
    ergebnisse.push(pruefe(
      `Alle ${anzahl} gleichwertigen Lösungen werden akzeptiert`,
      anzahl > 0 && daneben.length === 0,
      daneben.length ? `abgelehnt: ${daneben.slice(0, 5).join(", ")}` : "keine gleichwertigen Lösungen in der Kursdatei",
    ));
  }
  {
    const durchgerutscht = [];
    let geprueft = 0;
    for (const a of aufgaben) {
      if (a.type !== "singleChoice") continue;
      for (let i = 0; i < a.choices.length; i++) {
        if (i === a.correctIndex) continue;
        geprueft += 1;
        if (api.auswerten(a, i).richtig) durchgerutscht.push(`${a.id}#${i}`);
      }
    }
    ergebnisse.push(pruefe(
      `Alle ${geprueft} falschen Auswahlantworten werden abgelehnt`,
      durchgerutscht.length === 0,
      `durchgerutscht: ${durchgerutscht.slice(0, 5).join(", ")}`,
    ));
  }
  {
    // Gegenprobe zur Lockerung der Regeln: Unfug darf nicht durchgehen.
    const code = aufgaben.filter((a) => a.type === "code");
    const unfug = ["", "// hier kommt noch was", 'System.out.println("irgendwas ganz anderes");'];
    const durchgerutscht = [];
    for (const quelle of unfug) {
      for (const a of code) if (api.auswerten(a, quelle).richtig) durchgerutscht.push(`${a.id} ← ${quelle || "leer"}`);
    }
    ergebnisse.push(pruefe(
      `Unfug wird bei allen ${code.length} Code-Aufgaben abgelehnt`,
      durchgerutscht.length === 0,
      `akzeptiert: ${durchgerutscht.slice(0, 3).join(", ")}`,
    ));
  }

  // ------------------------------------------------------------- Tipps
  {
    const ohne = aufgaben.filter((a) => !(a.hint || "").trim());
    ergebnisse.push(pruefe("Jede Aufgabe hat einen Tipp", ohne.length === 0,
                           `ohne Tipp: ${ohne.slice(0, 5).map((a) => a.id).join(", ")}`));
    const knapp = aufgaben.filter((a) => (a.hint || "").trim().length < 25);
    ergebnisse.push(pruefe("Kein Tipp ist kürzer als 25 Zeichen", knapp.length === 0,
                           `zu knapp: ${knapp.slice(0, 5).map((a) => a.id).join(", ")}`));
  }
  {
    const ohne = aufgaben.filter((a) => !api.zweiterTipp(a, null));
    ergebnisse.push(pruefe("Jede Aufgabe hat einen zweiten Tipp", ohne.length === 0,
                           `ohne zweiten Tipp: ${ohne.slice(0, 5).map((a) => a.id).join(", ")}`));
    // Der zweite Tipp darf bei Auswahlaufgaben nie die Antwort streichen, die
    // gerade gewählt wurde – sonst wiederholt er nur den Fehler.
    const falsch = [];
    for (const a of aufgaben) {
      if (a.type !== "singleChoice") continue;
      for (let i = 0; i < a.choices.length; i++) {
        if (i === a.correctIndex) continue;
        const tipp = api.zweiterTipp(a, i);
        if (tipp && tipp.includes(`„${a.choices[i]}“`)) falsch.push(a.id);
      }
    }
    ergebnisse.push(pruefe("Der zweite Tipp streicht nie die gerade gewählte Antwort",
                           falsch.length === 0, `betroffen: ${falsch.slice(0, 5).join(", ")}`));
  }

  // -------------------------------------------- Begründete Abweichungen
  {
    const faelle = [
      [() => api.warumZeileFalsch("hallo", "Hallo"), "Groß- und Kleinschreibung"],
      [() => api.warumZeileFalsch("a b", "ab"), "Leerzeichen"],
      [() => api.warumZeileFalsch("10", "10.0"), "Nachkommastelle"],
      [() => api.warumZeileFalsch("1, 2", "[1, 2]"), "eckigen Klammern"],
      [() => api.warumAusgabeFalsch(["ABC"], ["A", "B", "C"]), "einer Zeile"],
      [() => api.warumAusgabeFalsch(["A", "B", "C"], ["ABC"]), "mehrere Zeilen"],
      [() => api.warumAusgabeFalsch(["abc"], ["ABC"]), "Groß- und Kleinschreibung"],
      [() => api.warumAusgabeFalsch(["a", "b", "c"], ["a", "b"]), "zu viel"],
      [() => api.warumAusgabeFalsch(["a"], ["a", "b"]), "fehlen"],
    ];
    const daneben = faelle.filter(([f, erwartet]) => !String(f() || "").includes(erwartet));
    ergebnisse.push(pruefe("Abweichungen werden benannt, nicht nur festgestellt",
                           daneben.length === 0,
                           `ohne Treffer: ${daneben.map(([, e]) => e).join(", ")}`));
  }
  {
    const println = { accepted: ["println"] };
    const elseB = { accepted: ["else"] };
    const faelle = [
      [api.warumBlankFalsch("PRINTLN", println, [println], 0), "Groß- und Klein"],
      [api.warumBlankFalsch("else", println, [println, elseB], 0), "Lücke 2"],
      [api.warumBlankFalsch("print", println, [println], 0), "Anfang stimmt"],
    ];
    const daneben = faelle.filter(([text, erwartet]) => !String(text).includes(erwartet));
    ergebnisse.push(pruefe("Eine falsch gefüllte Lücke wird begründet", daneben.length === 0,
                           `ohne Treffer: ${daneben.map(([, e]) => e).join(", ")}`));
  }

  // --------------------------------------------------- Gleiche Zahlen wie im Kern
  {
    ergebnisse.push(pruefe("Bestehensgrenze ist 69 %", Math.round(api.BESTANDEN_AB * 100) === 69,
                           `ist ${api.BESTANDEN_AB}`));
    ergebnisse.push(pruefe("Pausen der Wiedervorlage: 0/1/3/7/16/35 Tage",
                           api.PAUSEN.join(",") === "0,1,3,7,16,35", `ist ${api.PAUSEN.join(",")}`));
    ergebnisse.push(pruefe("Mindestfaktor der Wiedervorlage ist 0,25", api.MINDESTFAKTOR === 0.25,
                           `ist ${api.MINDESTFAKTOR}`));
    ergebnisse.push(pruefe("Ränge beginnen bei 0/150/350/600/850",
                           api.RAENGE.map((r) => r.ab).join(",") === "0,150,350,600,850",
                           `ist ${api.RAENGE.map((r) => r.ab).join(",")}`));
    ergebnisse.push(pruefe("Sterne: 69 % → 1, 84,5 % → 2, 100 % → 3",
                           api.sterne(0.69) === 1 && api.sterne(0.845) === 2 && api.sterne(1) === 3,
                           `ist ${api.sterne(0.69)}/${api.sterne(0.845)}/${api.sterne(1)}`));
    ergebnisse.push(pruefe("Unter der Grenze gibt es keinen Stern", api.sterne(0.68) === 0,
                           `ist ${api.sterne(0.68)}`));
  }
  {
    // Die Wiedervorlage dämpft vor dem Termin und hebt danach an.
    const tag = 86400000;
    const jetzt = 1_790_000_000_000;
    api.setzeStand(Object.assign(leererStand(), {
      ziele: {
        frisch: { serie: 1, datum: jetzt },                 // Pause 1 Tag, gerade eben
        faellig: { serie: 1, datum: jetzt - 1 * tag },      // genau fällig
        ueberfaellig: { serie: 1, datum: jetzt - 3 * tag }, // lange überfällig
      },
    }));
    const f = api.wiedervorlage("frisch", jetzt);
    const g = api.wiedervorlage("faellig", jetzt);
    const h = api.wiedervorlage("ueberfaellig", jetzt);
    ergebnisse.push(pruefe("Wiedervorlage: frisch gedämpft (0,25), fällig 1, überfällig bis 2",
                           f === 0.25 && g === 1 && h === 2, `ist ${f}/${g}/${h}`));
    const faellige = api.faelligeZiele(jetzt).sort();
    ergebnisse.push(pruefe("Fällig sind genau die, deren Pause abgelaufen ist",
                           faellige.join(",") === "faellig,ueberfaellig", `ist ${faellige.join(",")}`));
    api.setzeStand(leererStand());
  }
  {
    // Der Score zählt nur bestandene Lektionen, gewichtet nach Modulstufe.
    ergebnisse.push(pruefe("Ohne Fortschritt ist der Score 0", api.score() === 0, `ist ${api.score()}`));
    const alleBestanden = {};
    for (const m of kurs.modules) for (const l of m.lessons) alleBestanden[l.id] = { quote: 1, bestanden: true };
    api.setzeStand(Object.assign(leererStand(), { lektionen: alleBestanden }));
    ergebnisse.push(pruefe("Alles bestanden ergibt 1000", api.score() === 1000, `ist ${api.score()}`));
    api.setzeStand(leererStand());
  }
  {
    const p = api.einstufungProzent({ antworten: [] });
    ergebnisse.push(pruefe("Einstufung ohne Antworten ergibt 0 %", p === 0, `ist ${p}`));
    ergebnisse.push(pruefe("Einstufung: 0 % → Grundkurs, 70 % → Objekte, 90 % → fortgeschritten",
                           api.einstufungStufe(0) === "beginner"
                           && api.einstufungStufe(70) === "intermediate"
                           && api.einstufungStufe(90) === "advanced",
                           `ist ${api.einstufungStufe(0)}/${api.einstufungStufe(70)}/${api.einstufungStufe(90)}`));
  }

  // ------------------------------------------------------- Sicherung
  {
    const eigen = {
      lektionen: { l1: { quote: 0.7, bestanden: false } },
      verlauf: { a: { wertung: 1, datum: 1_790_000_000_000 }, b: { wertung: 0, datum: 1_790_086_400_000 } },
      themen: {}, ziele: { z1: { versuche: 3, serie: 1, wertung: 0.5, datum: 1_790_086_400_000 } },
      serie: { laengste: 4 }, profil: { stufe: "beginner" },
    };
    const fremd = {
      lektionen: { l1: { quote: 0.9, bestanden: true }, l2: { quote: 1, bestanden: true } },
      verlauf: { b: { wertung: 1, datum: 1_789_000_000_000 }, c: { wertung: 1, datum: 1_789_086_400_000 } },
      themen: {}, ziele: { z1: { versuche: 1, serie: 5, wertung: 1, datum: 1_789_000_000_000 } },
      serie: { laengste: 9 }, profil: null,
    };
    const neu = api.staendeVereinen(eigen, fremd);
    ergebnisse.push(pruefe("Sicherung: das bessere Lektionsergebnis gewinnt",
                           neu.lektionen.l1.quote === 0.9, `ist ${neu.lektionen.l1.quote}`));
    ergebnisse.push(pruefe("Sicherung: fremde Lektion kommt dazu", !!neu.lektionen.l2));
    ergebnisse.push(pruefe("Sicherung: einmal bestanden bleibt bestanden",
                           neu.lektionen.l1.bestanden === true, `ist ${neu.lektionen.l1.bestanden}`));
    ergebnisse.push(pruefe("Sicherung: eigene bessere Aufgabe bleibt", neu.verlauf.a.wertung === 1));
    ergebnisse.push(pruefe("Sicherung: fremde bessere Aufgabe gewinnt", neu.verlauf.b.wertung === 1));
    ergebnisse.push(pruefe("Sicherung: fremde Aufgabe kommt dazu", !!neu.verlauf.c));
    ergebnisse.push(pruefe("Sicherung: längere Serie und mehr Versuche bleiben",
                           neu.ziele.z1.serie === 5 && neu.ziele.z1.versuche === 3,
                           `ist Serie ${neu.ziele.z1.serie}, Versuche ${neu.ziele.z1.versuche}`));
    ergebnisse.push(pruefe("Sicherung: höchster Serien-Rekord bleibt", neu.serie.laengste === 9,
                           `ist ${neu.serie.laengste}`));
    const andersherum = api.staendeVereinen(fremd, eigen);
    ergebnisse.push(pruefe("Sicherung: die Reihenfolge ändert nichts Wesentliches",
                           andersherum.lektionen.l1.quote === neu.lektionen.l1.quote
                           && Object.keys(andersherum.verlauf).length === Object.keys(neu.verlauf).length
                           && andersherum.serie.laengste === neu.serie.laengste));
  }

  // ------------------------------------------------------- Befehlslexikon
  {
    const zeilen = erklaerteZeilen(kurs);
    const ohneBedeutung = zeilen.filter((z) => api.befehleDerZeile(z).length !== (z.terms || []).length);
    ergebnisse.push(pruefe(
      `Alle ${zeilen.length} erklärten Codezeilen: jeder Befehl hat eine Bedeutung`,
      zeilen.length > 0 && ohneBedeutung.length === 0,
      zeilen.length ? `ohne Glossareintrag: ${ohneBedeutung.slice(0, 3).map((z) => z.code.trim()).join(" | ")}`
                    : "keine erklärten Zeilen gefunden – hat sich das Kursformat geändert?",
    ));

    const zeile = zeilen.find((z) => z.terms && z.terms.includes("public"));
    const html = api.exegese({ lines: [zeile] }, "Test");
    const oeffentlich = (kurs.glossary.find((e) => e.term === "public") || {}).meaning || "";
    ergebnisse.push(pruefe(
      "Die Exegese zeigt die Befehle einer Zeile samt Bedeutung",
      html.includes(`Befehle in dieser Zeile (${zeile.terms.length})`) && oeffentlich !== ""
        && html.includes(oeffentlich.replace(/&/g, "&amp;").replace(/"/g, "&quot;")),
      `„Befehle in dieser Zeile“ oder die Bedeutung von public fehlt für: ${zeile.code.trim()}`,
    ));

    // Der Inhalt jedes Begriffs-Kästchens darf kein rohes <, > oder & enthalten.
    const spitze = zeilen.filter((z) => (z.terms || []).some((t) => /[<>&]/.test(t)));
    const roh = spitze.filter((z) => {
      const inhalte = [...api.exegese({ lines: [z] }, "Test").matchAll(/<code class="begriff">(.*?)<\/code>/g)].map((t) => t[1]);
      return inhalte.some((i) => /[<>]|&(?!amp;|lt;|gt;|quot;|#39;)/.test(i));
    });
    ergebnisse.push(pruefe(
      `Befehle wie < und && werden als Text ausgegeben (${spitze.length} Zeilen)`,
      spitze.length > 0 && roh.length === 0,
      spitze.length ? `ungeschützt in: ${roh.slice(0, 3).map((z) => z.code.trim()).join(" | ")}` : "keine Zeile mit < oder & gefunden",
    ));

    const ohne = api.exegese({ lines: [{ code: "}", explain: "Schließt den Block.", terms: [] }] }, "Test");
    ergebnisse.push(pruefe("Eine Zeile ohne Befehle bekommt keinen leeren Kasten",
                           ohne !== "" && !ohne.includes("befehle"), ohne));
  }

  // ------------------------------------------- Erklärung vor dem Antworten
  {
    const alle = [...aufgaben, ...Object.values((kurs.placement || {}).pools || {}).flat()];
    const luecken = alle.filter((a) => a.type === "fillBlank");
    const LUECKE = /\{\{(\d+)\}\}/g;
    const wort = (w) => new RegExp(`(?<![\\w])${w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?![\\w])`);

    // Die Befehlsliste einer Lückenzeile ist vor dem Lösen sichtbar. Sie darf die Antwort
    // nur enthalten, wenn das Wort ohnehin schon sichtbar in derselben Zeile steht.
    const leck = [];
    let lueckenzeilen = 0;
    for (const a of luecken) {
      for (const z of a.template.lines) {
        const nummern = [...(z.code || "").matchAll(LUECKE)].map((t) => Number(t[1]));
        if (!nummern.length) continue;
        lueckenzeilen += 1;
        const sichtbar = z.code.replace(LUECKE, " ");
        for (const n of nummern) {
          for (const antwort of a.blanks[n].accepted) {
            const genannt = (z.terms || []).some((t) => t === antwort || t === `${antwort}()`);
            if (genannt && !wort(antwort).test(sichtbar)) leck.push(`${a.id}: ${antwort}`);
          }
        }
      }
    }
    ergebnisse.push(pruefe(
      `Befehle einer Lückenzeile verraten keine Antwort (${lueckenzeilen} Zeilen)`,
      lueckenzeilen > 0 && leck.length === 0, `verraten: ${leck.slice(0, 5).join(", ")}`,
    ));

    // Vorher verdeckt: Die Erklärung einer Lückenzeile nennt meist die Antwort.
    const offen = [];
    for (const a of luecken) {
      const html = api.exegese(a.template, "Test", true);
      for (const z of a.template.lines) {
        if (!z.explain) continue;
        const text = api.exegese({ lines: [Object.assign({}, z, { terms: [] })] }, "x").match(/<\/code>(.*?)<\/div>/)[1];
        const hatLuecke = /\{\{\d+\}\}/.test(z.code);
        if (hatLuecke === html.includes(text)) offen.push(`${a.id}: ${z.code.trim().slice(0, 30)}`);
      }
    }
    ergebnisse.push(pruefe(
      `Vor dem Lösen: Erklärung jeder Lückenzeile verdeckt, alle anderen sichtbar (${luecken.length} Aufgaben)`,
      offen.length === 0, `falsch behandelt: ${offen.slice(0, 3).join(" | ")}`,
    ));

    // Nach dem Lösen: gefüllte Vorlage, keine Platzhalter mehr, jede Antwort an ihrer Stelle.
    const kaputt = luecken.filter((a) => {
      const code = api.geloesteVorlage(a).lines.map((z) => z.code).join("\n");
      return /\{\{/.test(code) || !a.blanks.every((b) => code.includes(b.accepted[0]));
    });
    ergebnisse.push(pruefe(
      `Gelöste Vorlage: alle Lücken gefüllt (${luecken.length} Aufgaben)`,
      kaputt.length === 0, `noch offen: ${kaputt.slice(0, 5).map((a) => a.id).join(", ")}`,
    ));

    const marke = api.codeZeile('System.out.{{0}}("<b>");');
    ergebnisse.push(pruefe(
      "Lücken erscheinen als nummerierte Markierung, nicht als {{0}}",
      marke.includes('class="lueckenmarke"') && marke.includes(">1</span>") && !marke.includes("{{") && marke.includes("&lt;b&gt;"),
      marke,
    ));
  }

  // ------------------------------------------- Sicherung zwischen den Fassungen
  // Dieselben Dateien und Zahlen wie in SicherungAustauschTests.swift und
  // SicherungAustauschTest.kt – wer eine davon ändert, muss sie überall ändern.
  if (beispiele) {
    const stichtag = Date.parse("2026-09-24T12:00:00Z");
    const vorher = api.holeStand();
    const faellig = (s) => { api.setzeStand(s); return api.faelligeZiele(stichtag).length; };
    const bestanden = (s) => Object.values(s.lektionen).filter((l) => l.bestanden).length;

    const ausApp = api.standAusDatei(beispiele.ausDerApp);
    ergebnisse.push(pruefe("Sicherung aus der App wird gelesen", !!ausApp, "abgelehnt"));
    if (ausApp) {
      ergebnisse.push(pruefe(
        "App-Sicherung: 9 Antworten ohne Einstufung, 2 Lektionen, 3 fällige Lernziele, Score 32",
        ausApp.protokoll.length === 9 && bestanden(ausApp) === 2 && faellig(ausApp) === 3 && api.score(ausApp.lektionen) === 32,
        `Antworten ${ausApp.protokoll.length}, Lektionen ${bestanden(ausApp)}, fällig ${faellig(ausApp)}, Score ${api.score(ausApp.lektionen)}`,
      ));
      // Die Apps speichern den Tagesbeginn in Ortszeit – der 23.09. muss der 23.09. bleiben.
      ergebnisse.push(pruefe("App-Sicherung: letzter Lerntag bleibt derselbe Tag",
        ausApp.serie.letzterTag === Math.floor(Date.parse("2026-09-23T12:00:00Z") / 86400000),
        `ist Tag ${ausApp.serie.letzterTag}`));
    }

    const web = beispiele.ausDemWeb;
    // Festgeschrieben: So schreibt die Web-App ihre Sicherung. Swift und Kotlin lesen genau
    // diese Datei – ändert sich der Aufbau, muss die Datei neu erzeugt und dort geprüft werden.
    const neu = api.sicherungsDatei(web.web, Date.parse(web.erstellt));
    ergebnisse.push(pruefe("Web-Sicherung hat den Aufbau, den die Apps lesen (Tests/Sicherungen/aus-dem-web.json)",
      JSON.stringify(neu) === JSON.stringify(web), "Aufbau weicht ab – Datei neu erzeugen und in allen Testreihen prüfen"));

    // Einmal durch die Apps und zurück: dieselbe Wiedervorlage.
    const zurueck = api.ausAppStand(web.stand);
    ergebnisse.push(pruefe("Web → App → Web: dieselben 4 fälligen Lernziele und 7 Antworten",
      faellig(web.web) === 4 && faellig(zurueck) === 4 && zurueck.protokoll.length === 7,
      `vorher ${faellig(web.web)}, nachher ${faellig(zurueck)}, Antworten ${zurueck.protokoll.length}`));

    ergebnisse.push(pruefe("Ältere Web-Sicherungen bleiben lesbar",
      api.standAusDatei({ app: "JavaQuest", version: 1, stand: web.web }) === web.web));
    ergebnisse.push(pruefe("Fremde Dateien werden abgelehnt",
      api.standAusDatei({ app: "Anders", stand: web.web }) === null
      && api.standAusDatei({ app: "JavaQuest", stand: {} }) === null
      && api.standAusDatei(null) === null));

    const zweimal = api.staendeVereinen(ausApp, api.standAusDatei(beispiele.ausDerApp));
    ergebnisse.push(pruefe("Zweimal eingelesen ergibt keine doppelten Antworten",
      zweimal.protokoll.length === ausApp.protokoll.length, `${zweimal.protokoll.length} statt ${ausApp.protokoll.length}`));

    // Neue Antworten landen im Protokoll – sonst ginge der Stand beim Export wieder verloren.
    api.setzeStand(Object.assign(JSON.parse(JSON.stringify(web.web))));
    api.merkeAufgabe(aufgaben.find((a) => a.id === "t03-1"), 1, 1, "lesson");
    const nachher = api.holeStand();
    ergebnisse.push(pruefe("Jede neue Antwort kommt ins Protokoll",
      nachher.protokoll.length === web.web.protokoll.length + 1 && nachher.protokoll.at(-1).context === "lesson"));
    api.setzeStand(vorher);
  }

  // ------------------------------------------------------- Erinnerung
  // Dieselbe Rechnung wie ReviewReminderTests.swift. Die Web-App rechnet in Ortszeit;
  // deshalb sind die Zeitpunkte hier auf „heute 12 Uhr Ortszeit“ bezogen und gelten in
  // jeder Zeitzone – in der CI (UTC) genauso wie auf einem Rechner in Deutschland.
  {
    const TAG = 86400000;
    const mittag = new Date(); mittag.setHours(12, 0, 0, 0);
    const um = (tage, stunde) => { const d = new Date(mittag); d.setDate(d.getDate() + tage); d.setHours(stunde, 0, 0, 0); return d.getTime(); };
    const plan = (faellig, jetzt) => api.erinnerungsTermine(faellig, jetzt).map((t) => [t.datum, t.anzahl]);

    ergebnisse.push(pruefe("Erinnerung: nichts fällig – kein Termin", plan([], mittag.getTime()).length === 0));
    const heute = plan([mittag.getTime() - 3 * TAG], mittag.getTime());
    ergebnisse.push(pruefe("Erinnerung: schon fällig – heute 18 Uhr, dann höchstens noch zwei Tage",
      JSON.stringify(heute) === JSON.stringify([[um(0, 18), 1], [um(1, 18), 1], [um(2, 18), 1]]), JSON.stringify(heute)));
    ergebnisse.push(pruefe("Erinnerung: nach 18 Uhr – erst morgen",
      plan([mittag.getTime() - TAG], um(0, 19))[0][0] === um(1, 18)));
    ergebnisse.push(pruefe("Erinnerung: erst abends fällig – am Tag darauf",
      plan([um(1, 20)], mittag.getTime())[0][0] === um(2, 18)));
    ergebnisse.push(pruefe("Erinnerung: die Zahl wächst mit dem, was dazukommt",
      JSON.stringify(plan([um(0, 8), um(1, 8), um(6, 8)], mittag.getTime()).map((t) => t[1])) === "[1,2,2]"));

    const ics = api.kalenderEintrag({ datum: um(2, 18), anzahl: 4 }, mittag.getTime());
    const zeilen = ics.split("\r\n");
    const entfaltet = ics.replace(/\r\n /g, "");
    const d = new Date(um(2, 18));
    const beginn = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}T180000`;
    const bytes = (z) => [...z].reduce((n, c) => { const p = c.codePointAt(0); return n + (p < 0x80 ? 1 : p < 0x800 ? 2 : p < 0x10000 ? 3 : 4); }, 0);
    ergebnisse.push(pruefe("Kalendereintrag: Zeilenende CRLF, keine Zeile über 75 Byte",
      !/[^\r]\n/.test(ics) && ics.endsWith("\r\n") && zeilen.every((z) => bytes(z) <= 75),
      zeilen.filter((z) => bytes(z) > 75).join(" | ")));
    ergebnisse.push(pruefe("Kalendereintrag: Termin in Ortszeit um 18 Uhr, mit Alarm und Zahl",
      entfaltet.includes(`DTSTART:${beginn}\r\n`) && entfaltet.includes("BEGIN:VALARM") && entfaltet.includes("TRIGGER:PT0M")
      && entfaltet.includes("SUMMARY:JavaQuest: 4 Lernziele wiederholen"), entfaltet));
    // Das Komma im Text („kurz reinschauen, bevor …“) muss maskiert sein, sonst lesen
    // manche Kalender die Beschreibung als Liste und schneiden sie ab.
    const beschreibung = entfaltet.match(/\r\nDESCRIPTION:(.*?)\r\n/)[1];
    ergebnisse.push(pruefe("Kalendereintrag: Komma und Zeilenumbruch in der Beschreibung maskiert",
      beschreibung.includes("\\,") && !/[^\\],/.test(beschreibung) && beschreibung.includes("\\n"), beschreibung));
  }

  return ergebnisse;
}

/** Jede Codezeile mit Erklärung, egal wo sie in der Kursdatei steht. */
function erklaerteZeilen(kurs) {
  const zeilen = [];
  const besuche = (o) => {
    if (Array.isArray(o)) { o.forEach(besuche); return; }
    if (!o || typeof o !== "object") return;
    if (typeof o.code === "string" && typeof o.explain === "string") zeilen.push(o);
    Object.values(o).forEach(besuche);
  };
  besuche(kurs);
  return zeilen;
}
