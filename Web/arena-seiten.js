/* Die Arena-Bildschirme der Web-Fassung: Übersicht, Missionen mit Spielfeld und Abzeichen –
   wie in der Apple-App (JavaQuest/Features/Arena). Die Logik steht in arena.js und spiel.js,
   hier nur die Oberfläche. Klassisches Browser-Skript im selben Gültigkeitsbereich wie app.js:
   Es nutzt dessen Hilfen (h, sicher, gehe, stand, kurs …) erst, wenn etwas gezeichnet wird. */

let katalog = null;   // ArenaKern.catalog(…) – nach dem Laden in los()
let bonusAufgaben = {}; // Code-Puzzle und Bug-Jagd je Lektion (bonus_aufgaben.json)
let einsatz = null;   // die laufende Mission, wie `sitzung` für Lektionen

const TEMPO = { langsam: 0.7, normal: 0.38, schnell: 0.14 };

// ---------------------------------------------------------------- Daten

/** Eine Aufgabe nach ID – aus dem Kurs oder den Bonus-Aufgaben. */
function aufgabeNachId(id) {
  const eintrag = aufgabeMitLektion(id);
  if (eintrag) return eintrag.aufgabe;
  for (const liste of Object.values(bonusAufgaben)) {
    const a = liste.find((x) => x.id === id);
    if (a) return a;
  }
  return null;
}

function spielFakten(s = stand) {
  return SpielKern.fakten({
    kurs, katalog, protokoll: s.protokoll, lektionen: s.lektionen,
    laengsteSerie: (s.serie || {}).laengste || 0, aufgabe: aufgabeNachId,
  });
}

const lektionsReihenfolge = () => alleLektionen().map((l) => l.id);
const missionFrei = (m) => SpielKern.freigeschalteteMission(m, kurs, stand.lektionen);

/** Speichert eine gelöste Mission wie ProgressStore.recordMission: nur Verbesserungen – oder die Tagesmission. */
function missionMerken(mission, ergebnis) {
  if (!ergebnis.solved) return;
  const f = spielFakten();
  const jetzt = Date.now();
  const tages = SpielKern.tagesmission(f, jetzt);
  const istTages = !!tages && tages.id === mission.id && !f.tagesmissionGeschafft(jetzt);
  if (istTages || ergebnis.stars > (f.sterne[mission.id] || 0)) {
    stand.protokoll.push({ taskId: mission.id, credit: SpielKern.gutschrift(ergebnis.stars), tries: 1, date: jetzt, context: istTages ? "daily" : "mission" });
  }
  merkeAktivitaet();
  sichern();
}

// ---------------------------------------------------------------- Bausteine

const sternText = (n) => `${"★".repeat(n)}${"☆".repeat(3 - n)}`;

/** Eine kleine Münze – das Emoji 🪙 zeigen nicht alle Browser. */
const muenzeBild = (groesse = 16) => `<svg width="${groesse}" height="${groesse}" viewBox="-1 -1 2 2" aria-hidden="true" class="muenze-bild">
  <circle r="0.95" fill="#FFC72E" stroke="#DB8F0D" stroke-width="0.12"/><text y="0.36" text-anchor="middle" font-size="1" font-weight="800" fill="#DB8F0D">€</text></svg>`;

/** Byte als SVG – Mittelpunkt bei (0, 0), Radius 0,39, schaut nach rechts. */
function byteSvg(kaputt = false) {
  const farbe = kaputt ? "#E8424D" : "url(#byte-farbe)";
  return `<polygon points="0.34,-0.13 0.53,0 0.34,0.13" fill="${kaputt ? "#E8424D" : "#F57321"}"/>
    <circle r="0.39" fill="${farbe}" stroke="#fff" stroke-width="0.05"/>
    <circle cx="0.13" cy="-0.13" r="0.085" fill="#fff"/><circle cx="0.155" cy="-0.13" r="0.042" fill="#29293F"/>
    <circle cx="0.13" cy="0.13" r="0.085" fill="#fff"/><circle cx="0.155" cy="0.13" r="0.042" fill="#29293F"/>`;
}

function byteBild(groesse = 64, grad = 0) {
  return `<svg class="byte-bild" width="${groesse}" height="${groesse}" viewBox="-0.6 -0.6 1.2 1.2" aria-hidden="true">
    <defs><linearGradient id="byte-farbe" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F57321"/><stop offset="1" stop-color="#E8424D"/></linearGradient></defs>
    <g transform="rotate(${grad})">${byteSvg()}</g></svg>`;
}

// ---------------------------------------------------------------- Übersicht

function arenaSeite() {
  if (!katalog) {
    return `<div class="kopf"><button class="zurueck" data-seite="start" aria-label="Zurück zur Übersicht">‹</button><span class="titel">Arena</span></div>
      <div class="karte"><h2>Arena nicht geladen</h2><p class="leise">Die Missionen konnten nicht geladen werden. Bitte die Seite neu laden.</p></div>`;
  }
  const f = spielFakten();
  const sterne = Object.values(f.sterne).reduce((a, b) => a + b, 0);
  let html = `<div class="kopf"><button class="zurueck" data-seite="start" aria-label="Zurück zur Übersicht">‹</button><span class="titel">Arena</span></div>
    <div class="arena-held">
      ${byteBild(64)}
      <div><h1>Die Arena</h1>
        <p>Steuere Byte mit echtem Java-Code: Jede Zeile, die du schreibst, wird wirklich ausgeführt – und du siehst sofort, was sie bewirkt.</p>
        <strong>★ ${sterne} von ${katalog.missions.length * 3} Sternen</strong></div>
    </div>
    ${tagesmissionKarte(f, false)}
    <div class="karte">
      <div class="marken"><span class="marke spielplatz">✨ Spielplatz</span><span class="mini">Ohne Ziel, ohne Bewertung</span></div>
      <h2>Freies Ausprobieren</h2>
      <p class="leise">Eine offene Welt mit Münzen und Mauern: Teste Schleifen, Methoden und Ideen, ganz ohne Druck.</p>
      <button class="knopf zweit" data-spielplatz="1">Spielplatz öffnen</button>
    </div>`;
  for (const modul of kurs.modules) {
    const ids = modul.lessons.map((l) => l.id);
    const missionen = katalog.missions
      .filter((m) => (m.kind === "boss" ? m.moduleId === modul.id : ids.includes(m.lessonId)))
      .sort((a, b) => {
        const rang = (m) => [m.kind === "boss" ? 1 : 0, ids.indexOf(m.lessonId), m.kind === "lesson" ? 0 : 1];
        const [x, y] = [rang(a), rang(b)];
        return x[0] - y[0] || x[1] - y[1] || x[2] - y[2];
      });
    if (!missionen.length) continue;
    html += `<div class="karte"><h3>${sicher(modul.title)}</h3><p class="mini">${sicher(modul.subtitle)}</p>`;
    for (const m of missionen) {
      const frei = missionFrei(m);
      const art = { lesson: ["🎮", "Mission"], training: ["🏋️", "Training"], boss: ["🛡️", "Boss"] }[m.kind];
      const lektion = alleLektionen().find((l) => l.id === m.lessonId);
      const grund = m.kind === "boss" ? "Schließe das ganze Modul ab"
        : m.kind === "training" ? `Schließe „${lektion ? lektion.title : m.lessonId}“ ab` : `Erreiche die Lektion „${lektion ? lektion.title : m.lessonId}“`;
      const st = f.sterne[m.id] || 0;
      html += `<button class="zeile" data-mission="${m.id}" ${frei ? "" : "disabled"}
          aria-label="${art[1]}: ${sicher(m.title)}${frei ? `, ${st} von 3 Sternen` : `, gesperrt: ${sicher(grund)}`}">
        <span class="punkt ${frei ? (st ? "fertig" : "offen") : ""}" aria-hidden="true">${frei ? art[0] : "🔒"}</span>
        <span class="haupt"><span class="mini">${art[1].toUpperCase()}${m.worlds.length > 1 ? ` · ${m.worlds.length} Welten` : ""}</span>
          <strong>${sicher(m.title)}</strong>
          ${frei ? "" : `<span class="mini">${sicher(grund)}</span>`}</span>
        ${frei ? `<span class="sterne" aria-hidden="true">${sternText(st)}</span>` : ""}
      </button>`;
    }
    html += `</div>`;
  }
  html += `<details class="karte befehlsliste"><summary><strong>Was Byte alles kann</strong></summary>
    ${ArenaKern.COMMANDS.map((c) => `<div class="erklaerzeile"><code class="begriff">${c.call}</code> <span class="mini">${c.returnType}</span><div class="mini">${sicher(c.detail)}</div></div>`).join("")}
    <p class="mini">Befehle mit void tun etwas. Befehle mit boolean beantworten eine Frage mit true oder false – perfekt für if und while. robot.coins() liefert eine Zahl (int).</p>
  </details>`;
  return html;
}

/** Die Mission des Tages – auf der Übersicht und in der Arena. */
function tagesmissionKarte(f, mitArenaLink) {
  if (!katalog) return "";
  const m = SpielKern.tagesmission(f, Date.now());
  const geschafft = !!f.tagesmissionGeschafft(Date.now());
  return `<div class="karte tagesmission">
    <div class="marken"><span class="marke sonne">☀️ Tagesmission</span><span class="mini">+${SpielKern.PUNKTE.tagesmission} XP Bonus · hält deine Serie am Leben</span></div>
    ${m ? `<h2>${sicher(m.title)}${geschafft ? " ✓" : ""}</h2>
      <p class="leise">${sicher(m.story)}</p>
      ${geschafft ? `<p class="gut-text">Für heute geschafft – morgen wartet eine neue Mission.</p>`
        : `<button class="knopf" data-mission="${m.id}">Mission starten</button>`}`
      : `<p class="leise">Starte die erste Lektion – danach wartet hier jeden Tag eine Mission auf dich.</p>`}
    ${mitArenaLink ? `<button class="knopf still" data-seite="arena">🎮 Zur Arena</button>` : ""}
  </div>`;
}

/** Level, XP und Abzeichen auf einen Blick – auf der Übersicht. */
function levelKarte(f) {
  if (!katalog) return "";
  const l = SpielKern.level(f.xp);
  const frei = SpielKern.freigeschaltet(f).size;
  return `<div class="karte level-karte">
    <div class="level-kopf"><span class="level-zahl">Level ${l.level}</span><span class="mini">${f.xp} XP</span></div>
    <div class="balken" role="progressbar" aria-label="Fortschritt bis Level ${l.level + 1}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(l.anteil * 100)}"><i style="width:${l.anteil * 100}%"></i></div>
    <p class="mini">Noch ${l.rest} XP bis Level ${l.level + 1}</p>
    <button class="knopf still" data-seite="abzeichen">🏅 ${frei} von ${SpielKern.ABZEICHEN.length} Abzeichen ansehen</button>
  </div>`;
}

function abzeichenSeite() {
  const f = spielFakten();
  const frei = SpielKern.freigeschaltet(f);
  const l = SpielKern.level(f.xp);
  const liste = SpielKern.ABZEICHEN.slice().sort((a, b) => {
    const fa = frei.has(a.id), fb = frei.has(b.id);
    if (fa !== fb) return fa ? -1 : 1;
    return SpielKern.aktuell(b, f) / b.ziel - SpielKern.aktuell(a, f) / a.ziel;
  });
  return `<div class="kopf"><button class="zurueck" data-seite="start" aria-label="Zurück zur Übersicht">‹</button><span class="titel">Abzeichen</span></div>
    <div class="karte level-karte">
      <div class="level-kopf"><span class="level-zahl">Level ${l.level}</span><span class="mini">${f.xp} XP</span></div>
      <div class="balken"><i style="width:${l.anteil * 100}%"></i></div>
      <p class="mini">Noch ${l.rest} XP bis Level ${l.level + 1} · ${frei.size} von ${SpielKern.ABZEICHEN.length} Abzeichen</p>
      <p class="mini">XP gibt es für jede Aufgabe (beim ersten Versuch doppelt), für jeden Missionsstern, jede bestandene Lektion und jede Tagesmission.</p>
    </div>
    <div class="abzeichen-gitter">${liste.map((a) => {
      const ist = frei.has(a.id);
      const stand = SpielKern.aktuell(a, f);
      return `<div class="abzeichen ${ist ? "frei" : ""}" role="group" aria-label="${sicher(a.titel)}: ${ist ? "freigeschaltet" : `${stand} von ${a.ziel}`}">
        <span class="symbol" aria-hidden="true">${a.symbol}</span>
        <strong>${sicher(a.titel)}</strong>
        <span class="mini">${sicher(a.text)}</span>
        ${ist ? `<span class="gut-text mini">✓ Freigeschaltet</span>`
          : `<div class="balken"><i style="width:${(stand / a.ziel) * 100}%"></i></div><span class="mini">${stand} / ${a.ziel}</span>`}
      </div>`;
    }).join("")}</div>`;
}

/** „+75 XP“, Levelaufstieg und neue Abzeichen. */
function belohnungHtml(gewinn) {
  if (!gewinn || (gewinn.xp <= 0 && !gewinn.levelAuf && !gewinn.abzeichen.length)) return "";
  return `<div class="belohnung">
    <div>${gewinn.xp > 0 ? `<strong class="xp">✨ +${gewinn.xp} XP</strong>` : ""}
      ${gewinn.levelAuf ? ` <strong class="levelauf">⬆️ Level ${gewinn.levelAuf}!</strong>` : ""}</div>
    ${gewinn.abzeichen.map((a) => `<div class="neues-abzeichen"><span aria-hidden="true">${a.symbol}</span>
      <div><strong>Neues Abzeichen: ${sicher(a.titel)}</strong><div class="mini">${sicher(a.text)}</div></div></div>`).join("")}
  </div>`;
}

// ---------------------------------------------------------------- Mission starten

function neuerEinsatz(mission, kontext, spielplatz = false) {
  const reihenfolge = lektionsReihenfolge();
  return {
    mission, kontext, spielplatz,
    code: mission.starterCode, cursor: null,
    ergebnis: null, welt: 0, bild: 0, spielt: false, timer: null, tempo: "normal",
    unfaelle: 0, feiern: 0, laeufe: 0, loesungGezeigt: false, gewinn: null, tippOffen: false, zuschauen: false,
    bausteine: spielplatz ? [] : katalog.conceptUses(mission),
    befehle: spielplatz ? ArenaKern.COMMANDS : ArenaKern.COMMANDS.filter((c) => mission.commandNames.includes(c.name)),
    vorlagen: spielplatz ? ArenaKern.TEMPLATES : katalog.templates(mission, reihenfolge),
    kenntMethoden: spielplatz || katalog.knows("methode", mission, reihenfolge),
  };
}

function missionStarten(id) {
  const m = katalog && katalog.mission(id);
  if (!m) return;
  einsatzAnhalten();
  einsatz = neuerEinsatz(m, "arena");
  gehe("mission");
}

function spielplatzOeffnen() {
  if (!katalog) return;
  einsatzAnhalten();
  einsatz = neuerEinsatz(katalog.playground, "arena", true);
  gehe("mission");
}

function einsatzAnhalten() {
  if (einsatz && einsatz.timer) clearTimeout(einsatz.timer);
  if (einsatz) { einsatz.timer = null; einsatz.spielt = false; }
}

/** Die nächste freigeschaltete Mission ohne volle Sterne – in Katalog-Reihenfolge nach der aktuellen. */
function naechsteMission() {
  if (!einsatz || einsatz.spielplatz) return null;
  const f = spielFakten();
  const liste = katalog.missions;
  const start = liste.findIndex((m) => m.id === einsatz.mission.id) + 1;
  const reihe = [...liste.slice(start), ...liste.slice(0, Math.max(start - 1, 0))];
  return reihe.find((m) => missionFrei(m) && (f.sterne[m.id] || 0) < 3 && m.id !== einsatz.mission.id) || null;
}

// ---------------------------------------------------------------- Missionsbildschirm

function missionSeite() {
  if (!einsatz) return arenaSeite();
  return `<div id="einsatz">${einsatzHtml()}</div>`;
}

const aktuelleWelt = () => einsatz.mission.worlds[Math.min(einsatz.welt, einsatz.mission.worlds.length - 1)];
const aktuellerLauf = () => (einsatz.ergebnis ? einsatz.ergebnis.runs[einsatz.welt] || null : null);
const bilder = () => (aktuellerLauf() ? aktuellerLauf().frames : []);
const amEnde = () => bilder().length === 0 || einsatz.bild >= bilder().length - 1;
const zeigtErgebnis = () => einsatz.ergebnis && (amEnde() || !einsatz.spielt);
const geloest = () => !!(einsatz.ergebnis && einsatz.ergebnis.solved);
const feiert = () => geloest() && !einsatz.spielplatz && !einsatz.loesungGezeigt && amEnde();

function einsatzHtml() {
  const m = einsatz.mission;
  const art = einsatz.spielplatz ? ["✨", "Spielplatz", "spielplatz"]
    : { lesson: ["🎮", "Mission", "mission"], training: ["🏋️", "Training", "training"], boss: ["🛡️", "Boss-Level", "boss"] }[m.kind];
  const f = einsatz.spielplatz ? null : spielFakten();
  const tages = f && SpielKern.tagesmission(f, Date.now());
  const istTages = !!tages && tages.id === m.id && !f.tagesmissionGeschafft(Date.now());
  const beste = f ? f.sterne[m.id] || 0 : 0;

  const auftrag = `<div class="karte auftrag" style="order:1">
      <div class="marken"><span class="marke ${art[2]}">${art[0]} ${art[1]}</span>${istTages ? `<span class="marke sonne">☀️ Tagesmission</span>` : ""}
        ${einsatz.spielplatz ? "" : `<span class="sterne" aria-label="Bisher ${beste} von 3 Sternen">${sternText(beste)}</span>`}</div>
      <h1>${sicher(m.title)}</h1>
      <p class="leise">${sicher(m.story)}</p>
      ${einsatz.spielplatz ? "" : `<div class="abschnitt"><h3>🏁 Dein Auftrag</h3>${m.goals.map(zielZeile).join("")}</div>`}
    </div>`;
  const anleitung = `<div class="karte anleitung" style="order:2">${anleitungHtml()}</div>`;

  return `<div class="kopf"><button class="zurueck" data-einsatz-schliessen="1" aria-label="${einsatz.kontext === "lektion" ? "Lektion verlassen" : "Mission schließen"}, Taste Escape">✕</button>
      <span class="titel">${sicher(einsatz.kontext === "lektion" && sitzung ? sitzung.titel : m.title)}</span></div>
    <div class="einsatz-spalten">
      <div class="einsatz-spalte">
        ${auftrag}
        ${brettKarte()}
        ${konsoleKarte()}
      </div>
      <div class="einsatz-spalte">
        ${codeKarte()}
        <div id="einsatz-ergebnis" style="order:6" data-sichtbar="${zeigtErgebnis() ? "1" : ""}">${ergebnisHtml()}</div>
        ${anleitung}
      </div>
    </div>
    ${aktionsleiste()}`;
}

function zielZeile(ziel) {
  const zeichen = { reachGoal: "🏁", collectCoins: muenzeBild(16), output: "💬", rule: "✔️", allWorlds: "🗂️" }[ziel.kind];
  const ausgaben = ziel.outputs.map((o) => `${o.world ? `<div class="mini">Welt ${o.world}</div>` : ""}<pre class="code ausgabe">${sicher(o.text)}</pre>`).join("");
  return `<div class="ziel"><span aria-hidden="true">${zeichen}</span><div>${sicher(ziel.text)}${ausgaben}</div></div>`;
}

function anleitungHtml() {
  const m = einsatz.mission;
  const neu = (name) => m.newCommands.includes(name) && !einsatz.spielplatz;
  const hatNeues = !einsatz.spielplatz && (m.newCommands.length > 0 || einsatz.bausteine.some((b) => b.isNew));
  const reihenfolge = lektionsReihenfolge();
  const lektionsNummer = (id) => { const i = reihenfolge.indexOf(id); return i < 0 ? null : i + 1; };
  const schritte = !einsatz.spielplatz && m.steps.length ? `<details class="abschnitt" open><summary><h3>📋 So gehst du vor</h3></summary>
      <ol class="schritte">${m.steps.map((s) => `<li>${sicher(s)}</li>`).join("")}</ol></details>` : "";
  const bausteine = einsatz.bausteine.length ? `<p class="beschriftung">Java-Bausteine, die du brauchst</p>${einsatz.bausteine.map((b) => `
      <div class="baustein"><strong>${sicher(b.concept.title)}</strong> ${b.isNew ? `<span class="neu">NEU</span>`
        : b.concept.lessonId && lektionsNummer(b.concept.lessonId) ? `<span class="mini">aus Lektion ${lektionsNummer(b.concept.lessonId)}</span>` : ""}
        <pre class="code">${sicher(b.concept.code)}</pre><p class="mini">${sicher(b.concept.text)}</p></div>`).join("")}` : "";
  const befehle = `<p class="beschriftung">${einsatz.spielplatz ? "Alle Befehle" : "Befehle, die Byte hier kann"}</p>${einsatz.befehle.map((c) => `
      <div class="befehl"><code class="${neu(c.name) ? "neu-befehl" : ""}">${c.call}${c.returnType === "void" ? ";" : ""}</code>${neu(c.name) ? ` <span class="neu">NEU</span>` : ""}
        <div class="mini">${sicher(c.detail)}</div></div>`).join("")}`;
  const zusammenfassung = [...einsatz.bausteine.map((b) => b.concept.title), einsatz.befehle.length === 1 ? "1 Befehl" : `${einsatz.befehle.length} Befehle`].join(" · ");
  const werkzeug = `<details class="abschnitt" ${hatNeues || einsatz.spielplatz ? "open" : ""}><summary><h3>🧰 ${einsatz.spielplatz ? "Das kann Byte" : "Dein Werkzeugkasten"}</h3>
      <span class="mini zu">${sicher(zusammenfassung)}</span></summary>${bausteine}${befehle}</details>`;
  const sterne = einsatz.spielplatz ? "" : `<div class="abschnitt"><h3>⭐ Sterne</h3>
      <div class="mini">★ Auftrag erfüllt</div>${m.bonus.map((b) => `<div class="mini">★ ${sicher(ArenaKern.criterionTitle(b))}</div>`).join("")}</div>`;
  return schritte + werkzeug + sterne;
}

function brettKarte() {
  const m = einsatz.mission;
  const w = aktuelleWelt();
  const welten = m.worlds.length > 1 ? `<div class="welten" role="group" aria-label="Welt wählen">${m.worlds.map((_, i) => {
    const lauf = einsatz.ergebnis && einsatz.ergebnis.runs[i];
    const zeichen = lauf ? (lauf.succeeded ? "✓ " : "✗ ") : "";
    return `<button class="chip ${i === einsatz.welt ? "aktiv" : ""} ${lauf ? (lauf.succeeded ? "gut" : "schlecht") : ""}" data-welt="${i}" aria-pressed="${i === einsatz.welt}">${zeichen}Welt ${i + 1}</button>`;
  }).join("")}</div>` : "";
  const legende = `<div class="legende mini"><span>${byteBild(18, ArenaKern.HEADINGS[w.facing].degrees)} Byte – schaut am Anfang ${ArenaKern.HEADINGS[w.facing].direction}</span>
    ${w.goal ? "<span>🏁 Ziel</span>" : ""}${w.coins.length ? `<span>${muenzeBild(15)} Münze</span>` : ""}<span><i class="wand-muster"></i> Wand</span></div>`;
  return `<div class="karte brett-karte" id="brett-karte" style="order:3">
    ${welten}
    <div class="brett" id="brett" style="aspect-ratio:${w.width} / ${w.height}">${brettSvg(w)}
      <div class="muenzzaehler" id="muenzzaehler" ${w.coins.length ? "" : "hidden"}>${muenzeBild(14)} <span>0/${w.coins.length}</span></div>
      <div class="ueberlage" id="ueberlage"></div>
    </div>
    ${legende}
    <div class="steuerung">
      <button class="steuer" data-abspielen="anfang" aria-label="Zum Anfang">⏮</button>
      <button class="steuer haupt" data-abspielen="spielen" aria-label="Abspielen">▶</button>
      <button class="steuer" data-abspielen="schritt" aria-label="Ein Schritt">⏭</button>
      <button class="steuer" data-abspielen="ende" aria-label="Zum Ende">⏩</button>
      <span class="mini zaehler" id="bildzaehler"></span>
      <select id="tempo" aria-label="Tempo">${Object.keys(TEMPO).map((t) => `<option value="${t}" ${einsatz.tempo === t ? "selected" : ""}>${t[0].toUpperCase() + t.slice(1)}</option>`).join("")}</select>
    </div>
  </div>`;
}

function brettSvg(w) {
  let felder = "";
  for (let y = 0; y < w.height; y += 1) {
    for (let x = 0; x < w.width; x += 1) {
      const wand = w.isWall({ x, y });
      const ziel = w.goal && w.goal.x === x && w.goal.y === y;
      felder += wand
        ? `<rect x="${x + 0.03}" y="${y + 0.03}" width="0.94" height="0.94" rx="0.16" class="wand"/><rect x="${x + 0.18}" y="${y + 0.18}" width="0.64" height="0.64" rx="0.1" class="wand-oben"/>`
        : `<rect x="${x + 0.04}" y="${y + 0.04}" width="0.92" height="0.92" rx="0.14" class="${ziel ? "zielfeld" : (x + y) % 2 ? "boden2" : "boden"}"/>`;
    }
  }
  const muenzen = w.coins.map((c) => `<g class="muenze" data-feld="${c.x},${c.y}" transform="translate(${c.x + 0.5} ${c.y + 0.5})">
      <g class="muenze-innen"><circle r="0.25" fill="url(#muenz-farbe)"/><circle r="0.18" fill="none" stroke="#DB8F0D" stroke-width="0.035"/>
      <text y="0.09" text-anchor="middle" font-size="0.24" font-weight="800" fill="#DB8F0D">€</text></g></g>`).join("");
  const ziel = w.goal ? `<text class="flagge" x="${w.goal.x + 0.5}" y="${w.goal.y + 0.68}" text-anchor="middle" font-size="0.5">🏁</text>` : "";
  return `<svg viewBox="0 0 ${w.width} ${w.height}" role="img" aria-label="${sicher(brettBeschreibung(w, null))}" id="brett-svg">
    <defs>
      <linearGradient id="byte-farbe" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F57321"/><stop offset="1" stop-color="#E8424D"/></linearGradient>
      <radialGradient id="muenz-farbe" cx="0.3" cy="0.3" r="0.9"><stop offset="0" stop-color="#FFC72E"/><stop offset="1" stop-color="#DB8F0D"/></radialGradient>
    </defs>
    ${felder}
    <polyline id="spur" points="" fill="none" stroke="#F57321" stroke-opacity="0.6" stroke-width="0.11" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="0.001 0.24"/>
    ${ziel}${muenzen}
    <g id="byte" class="byte"><g class="byte-koerper">${byteSvg()}</g></g>
  </svg>`;
}

function brettBeschreibung(w, bild) {
  const robot = bild ? bild.robot : w.start || { x: 0, y: 0 };
  const blick = bild ? bild.heading : w.facing;
  const muenzen = bild ? bild.coins.size : w.coins.length;
  let text = `Spielfeld ${w.width} mal ${w.height}. Byte steht in Spalte ${robot.x + 1}, Zeile ${robot.y + 1} und schaut ${ArenaKern.HEADINGS[blick].direction}.`;
  text += muenzen ? ` Noch ${muenzen} Münzen.` : " Keine Münzen mehr.";
  if (w.goal) text += ` Ziel in Spalte ${w.goal.x + 1}, Zeile ${w.goal.y + 1}.`;
  return text;
}

function codeKarte() {
  const zeilen = ArenaKern.codeLineCount(einsatz.code);
  const lauf = aktuellerLauf();
  const palette = einsatz.zuschauen ? "" : `<div class="palette" role="group" aria-label="Befehle einfügen">
      ${einsatz.befehle.map((c) => {
        const neu = !einsatz.spielplatz && einsatz.mission.newCommands.includes(c.name);
        return `<button class="befehlsknopf ${neu ? "neu" : ""}" data-einfuegen="${sicher(c.returnType === "void" ? `${c.call};` : c.call)}" title="${sicher(c.summary)}">${c.call}</button>`;
      }).join("")}
      ${einsatz.vorlagen.map((t) => `<button class="befehlsknopf vorlage" data-einfuegen="${sicher(t.code)}" title="Vorlage einfügen">+ ${sicher(t.name)}</button>`).join("")}
    </div>`;
  const tipp = einsatz.kenntMethoden ? `<p class="mini">${einsatz.spielplatz ? "" : "Tipp: "}Eigene Methoden (static void …) darfst du über oder unter deine Befehle schreiben.</p>` : "";
  const editor = einsatz.zuschauen
    ? `<div class="spur-code" id="spur-code" tabindex="0" role="button" aria-label="Code beim Ausführen – zum Bearbeiten antippen" data-bearbeiten="1">${einsatz.code.split("\n").map((z, i) =>
        `<div class="codezeile" data-zeile="${i + 1}"><span class="nr">${i + 1}</span><span>${sicher(z) || " "}</span></div>`).join("")}</div>`
    : `<textarea id="einsatz-code" class="einsatz-code" spellcheck="false" autocapitalize="off" autocorrect="off"
        aria-label="Dein Java-Code" placeholder="// Befehle für Byte, z. B. robot.move();">${sicher(einsatz.code)}</textarea>`;
  return `<div class="karte code-karte" style="order:4">
    <div class="code-kopf"><h3>‹/› Dein Java-Code</h3><span class="mini" id="zeilenzahl">${zeilen === 1 ? "1 Zeile" : `${zeilen} Zeilen`}</span>
      ${einsatz.zuschauen ? `<button class="knopf still" data-bearbeiten="1">✎ Bearbeiten</button>` : ""}</div>
    ${editor}${palette}${tipp}
    ${lauf && lauf.problem && einsatz.zuschauen ? "" : ""}
  </div>`;
}

function konsoleKarte() {
  return `<div class="karte konsole-karte" id="konsole-karte" style="order:5" ${einsatz.ergebnis ? "" : "hidden"}>
    <div class="konsole-zeile">
      <div class="konsole-teil"><p class="beschriftung">Konsole</p><pre class="code" id="konsole" aria-live="off"></pre></div>
      <div class="variablen-teil" id="variablen-teil" hidden><p class="beschriftung">Variablen</p><div id="variablen" class="variablen"></div></div>
    </div>
  </div>`;
}

function ergebnisHtml() {
  if (!zeigtErgebnis()) return einsatz.tippOffen ? tippHtml() : "";
  const e = einsatz.ergebnis;
  let html = einsatz.tippOffen ? tippHtml() : "";
  if (einsatz.spielplatz) {
    const lauf = e.runs[0];
    html += `<div class="ergebnis spielplatz-ergebnis" role="status">
      <h3>${lauf.problem ? "⚠️ Programm angehalten" : "✓ Programm fertig ausgeführt"}</h3>
      ${lauf.problem ? `<p>${sicher(lauf.problem.description)}</p>` : ""}
      <p class="leise">Byte hat ${lauf.actions} Aktionen gemacht und ${lauf.world.coins.length - lauf.coinsLeft} Münzen eingesammelt.</p></div>`;
    return html;
  }
  const kopf = e.solved ? (e.stars === 3 ? "Perfekt gelöst!" : "Mission geschafft!") : "Noch nicht ganz";
  const unter = einsatz.loesungGezeigt ? "Mit der gezeigten Lösung gibt es keine Sterne."
    : e.solved ? (e.stars === 3 ? "Alle drei Sterne – stark!" : "Schaffst du auch die übrigen Sterne?")
      : "Schau dir an, wo Byte hängen bleibt – und passe den Code an.";
  const stern = (an, text, fortschritt) => `<div class="kriterium ${an ? "an" : ""}"><span class="kz" aria-hidden="true">${an ? "★" : "☆"}</span>
      <span>${sicher(text)}${fortschritt ? ` <span class="messwert ${an ? "gut" : "schlecht"}">${sicher(fortschritt)}</span>` : ""}</span></div>`;
  const fehler = [...e.missingRequirements, ...weltFehler(e)].slice(0, 5);
  html += `<div class="ergebnis ${e.solved ? "geschafft" : "offen"}" role="status">
    <div class="ergebnis-kopf"><span class="ergebnis-zeichen" aria-hidden="true">${e.solved ? "✅" : "🔁"}</span>
      <div><h3>${kopf}</h3><p class="leise">${unter}</p></div>
      <span class="sterne gross enthuellen" aria-label="${e.stars} von 3 Sternen">${[0, 1, 2].map((i) => `<i class="${i < e.stars ? "an" : ""}" style="animation-delay:${0.2 + i * 0.3}s">${i < e.stars ? "★" : "☆"}</i>`).join("")}</span></div>
    ${stern(e.solved, "Mission erfüllt")}
    ${e.criteria.map((c) => stern(c.met, c.title, c.progress)).join("")}
    ${fehler.map((t) => `<div class="befund"><span>✗</span><span>${sicher(t)}</span></div>`).join("")}
    ${e.warnings.map((w) => `<div class="befund"><span>💡</span><span>Zeile ${w.line}: ${sicher(w.message)}</span></div>`).join("")}
    ${belohnungHtml(einsatz.gewinn)}
  </div>`;
  if (einsatz.loesungGezeigt || e.solved) {
    html += `<div class="karte"><h3>Musterlösung</h3><pre class="code">${sicher(einsatz.mission.solution)}</pre></div>`;
  }
  return html;
}

/** Fehler je Welt – was in jeder Welt gleich schiefging, steht nur einmal da. */
function weltFehler(e) {
  const welten = einsatz.mission.worlds.length;
  if (welten <= 1) return e.runs.flatMap((r) => r.failures);
  const liste = [];
  e.runs.forEach((lauf, i) => {
    // Ein Syntaxfehler steht im Code, nicht in einer Welt (geprüft wird nur die erste).
    if (lauf.problem && (lauf.problem.kind === "syntax" || lauf.problem.kind === "unsupported")) {
      for (const f of lauf.failures) if (!liste.includes(f)) liste.push(f);
      return;
    }
    for (const f of lauf.failures) {
      const ueberall = e.runs.length === welten && e.runs.every((r) => r.failures.includes(f));
      const text = ueberall ? `In allen Welten: ${f}` : `Welt ${i + 1}: ${f}`;
      if (!liste.includes(text)) liste.push(text);
    }
  });
  return liste;
}

function tippHtml() {
  return `<div class="kasten tipp">💡 ${sicher(einsatz.mission.hint)}</div>`;
}

function aktionsleiste() {
  const loesbar = !einsatz.spielplatz;
  // Auf dem Spielplatz gibt es nichts abzuschließen – dort bleibt „Erneut ausführen“.
  const fertig = loesbar && geloest() && zeigtErgebnis();
  const hilfe = loesbar ? `<details class="hilfe-menue">
      <summary class="knopf zweit" aria-label="Hilfe">${fertig ? "?" : "? Hilfe"}</summary>
      <div class="menue">
        <button data-hilfe="tipp">💡 ${einsatz.tippOffen ? "Tipp ausblenden" : "Tipp anzeigen"}</button>
        <button data-hilfe="start">↩ Startcode wiederherstellen</button>
        ${einsatz.laeufe > 0 ? `<button data-hilfe="loesung">👁 Lösung zeigen</button>` : ""}
        ${einsatz.kontext === "lektion" && !geloest() ? `<button data-hilfe="ueberspringen">⏭ Mission überspringen</button>` : ""}
      </div></details>` : "";
  let haupt;
  if (fertig) {
    if (einsatz.kontext === "lektion") {
      haupt = `<button class="knopf" data-einsatz-weiter="lektion">Weiter zur Auswertung</button>`;
    } else {
      const naechste = naechsteMission();
      haupt = naechste
        ? `<button class="knopf zweit breit-nur" data-einsatz-schliessen="1">✓ Fertig</button><button class="knopf" data-einsatz-weiter="${naechste.id}">Nächste Mission →</button>`
        : `<button class="knopf" data-einsatz-schliessen="1">✓ Fertig</button>`;
    }
  } else {
    haupt = `<button class="knopf gruen" data-ausfuehren="1" ${einsatz.code.trim() ? "" : "disabled"}>▶ ${einsatz.laeufe ? "Erneut ausführen" : "Ausführen"}</button>`;
  }
  return `<div class="aktionsleiste" id="aktionsleiste">${hilfe}${haupt}</div>`;
}

// ---------------------------------------------------------------- Ereignisse

function bindeArenaEreignisse() {
  const klick = (wahl, tu) => document.querySelectorAll(wahl).forEach((k) => k.addEventListener("click", tu));
  klick("[data-mission]", (e) => missionStarten(e.currentTarget.dataset.mission));
  klick("[data-spielplatz]", spielplatzOeffnen);
  if (!document.getElementById("einsatz") || !einsatz) return;

  klick("[data-einsatz-schliessen]", einsatzSchliessen);
  klick("[data-einsatz-weiter]", (e) => {
    const ziel = e.currentTarget.dataset.einsatzWeiter;
    if (ziel === "lektion") return lektionsMissionBeenden(einsatz.ergebnis);
    missionStarten(ziel);
  });
  klick("[data-ausfuehren]", ausfuehren);
  klick("[data-bearbeiten]", () => { einsatzAnhalten(); einsatz.zuschauen = false; einsatzNeu(); fokusImEditor(); });
  klick("[data-welt]", (e) => weltWaehlen(Number(e.currentTarget.dataset.welt)));
  klick("[data-abspielen]", (e) => {
    const was = e.currentTarget.dataset.abspielen;
    if (was === "anfang") { einsatzAnhalten(); einsatz.bild = 0; bildZeigen(); }
    else if (was === "spielen") { if (einsatz.spielt) { einsatzAnhalten(); bildZeigen(); } else abspielen(); }
    else if (was === "schritt") { einsatzAnhalten(); vorwaerts(); }
    else { einsatzAnhalten(); einsatz.bild = Math.max(bilder().length - 1, 0); bildErreicht(); bildZeigen(); }
  });
  const tempo = document.getElementById("tempo");
  if (tempo) tempo.addEventListener("change", () => { einsatz.tempo = tempo.value; });
  klick("[data-einfuegen]", (e) => einfuegen(e.currentTarget.dataset.einfuegen));
  klick("[data-hilfe]", (e) => hilfe(e.currentTarget.dataset.hilfe));

  const feld = document.getElementById("einsatz-code");
  if (feld) {
    const merke = () => { einsatz.cursor = feld.selectionEnd; };
    feld.addEventListener("input", () => { einsatz.code = feld.value; merke(); codeGeaendert(); });
    for (const art of ["click", "keyup", "select", "focus"]) feld.addEventListener(art, merke);
  }
  bildZeigen(false);
}

function einsatzSchliessen() {
  einsatzAnhalten();
  if (einsatz && einsatz.kontext === "lektion") {
    einsatz = null;
    return gehe("start");
  }
  einsatz = null;
  gehe("arena");
}

/** Den Missionsbildschirm neu aufbauen, ohne die Seite zu wechseln (Scrollposition bleibt). */
function einsatzNeu() {
  const kasten = document.getElementById("einsatz");
  if (!kasten) return zeichne();
  kasten.innerHTML = einsatzHtml();
  bindeArenaEreignisse();
}

function fokusImEditor() {
  const feld = document.getElementById("einsatz-code");
  if (!feld) return;
  // Vor dem Fokus merken: Das Setzen des Textes hat die Schreibmarke ans Ende geschoben, und das
  // focus-Ereignis würde genau diese Stelle als Cursor übernehmen – der nächste Befehl landete am Ende.
  const cursor = einsatz.cursor;
  if (cursor != null) feld.setSelectionRange(cursor, cursor);
  feld.focus({ preventScroll: true });
  if (cursor != null) {
    feld.setSelectionRange(cursor, cursor);
    einsatz.cursor = cursor;
  }
}

/** Neuer Code: Das alte Ergebnis passt nicht mehr – zurück zum Startbild, ohne den Editor neu zu zeichnen. */
function codeGeaendert() {
  const zahl = document.getElementById("zeilenzahl");
  if (zahl) { const n = ArenaKern.codeLineCount(einsatz.code); zahl.textContent = n === 1 ? "1 Zeile" : `${n} Zeilen`; }
  const knopf = document.querySelector("[data-ausfuehren]");
  if (knopf) knopf.disabled = !einsatz.code.trim();
  if (!einsatz.ergebnis) return;
  einsatzAnhalten();
  einsatz.ergebnis = null;
  einsatz.gewinn = null;
  einsatz.bild = 0;
  document.getElementById("einsatz-ergebnis").innerHTML = ergebnisHtml();
  document.getElementById("konsole-karte").hidden = true;
  document.querySelectorAll("[data-welt]").forEach((k) => { k.classList.remove("gut", "schlecht"); k.textContent = `Welt ${Number(k.dataset.welt) + 1}`; });
  const leiste = document.getElementById("aktionsleiste");
  if (leiste) { leiste.outerHTML = aktionsleiste(); bindeLeiste(); }
  bildZeigen(false);
}

function bindeLeiste() {
  const leiste = document.getElementById("aktionsleiste");
  if (!leiste) return;
  leiste.querySelectorAll("[data-ausfuehren]").forEach((k) => k.addEventListener("click", ausfuehren));
  leiste.querySelectorAll("[data-hilfe]").forEach((k) => k.addEventListener("click", (e) => hilfe(e.currentTarget.dataset.hilfe)));
  leiste.querySelectorAll("[data-einsatz-schliessen]").forEach((k) => k.addEventListener("click", einsatzSchliessen));
  leiste.querySelectorAll("[data-einsatz-weiter]").forEach((k) => k.addEventListener("click", (e) => {
    const ziel = e.currentTarget.dataset.einsatzWeiter;
    if (ziel === "lektion") lektionsMissionBeenden(einsatz.ergebnis); else missionStarten(ziel);
  }));
}

function einfuegen(schnipsel) {
  if (einsatz.zuschauen) { einsatzAnhalten(); einsatz.zuschauen = false; einsatzNeu(); }
  const neu = ArenaKern.insert(schnipsel, einsatz.code, einsatz.cursor);
  einsatz.code = neu.code;
  einsatz.cursor = neu.cursor;
  const feld = document.getElementById("einsatz-code");
  if (feld) feld.value = neu.code;
  codeGeaendert();
  fokusImEditor();
}

function hilfe(was) {
  document.querySelectorAll(".hilfe-menue").forEach((d) => { d.open = false; });
  if (was === "tipp") {
    einsatz.tippOffen = !einsatz.tippOffen;
  } else if (was === "start") {
    einsatz.code = einsatz.mission.starterCode;
    einsatz.cursor = null;
    einsatz.zuschauen = false;
    einsatz.ergebnis = null;
    einsatz.gewinn = null;
  } else if (was === "loesung") {
    if (!confirm("Lösung anzeigen? Mit der gezeigten Lösung gibt es keine Sterne und keine XP – aber du kannst nachlesen, wie sie funktioniert.")) return;
    einsatz.loesungGezeigt = true;
    einsatz.code = einsatz.mission.solution;
    einsatz.cursor = null;
    einsatz.zuschauen = false;
    einsatz.ergebnis = null;
    einsatz.gewinn = null;
  } else if (was === "ueberspringen") {
    return lektionsMissionBeenden(null);
  }
  einsatzAnhalten();
  einsatzNeu();
}

function weltWaehlen(index) {
  if (index === einsatz.welt) return;
  einsatzAnhalten();
  einsatz.welt = index;
  einsatz.bild = 0;
  // Ganz neu aufbauen: Nur das Spielfeld zu ersetzen, hätte die übrigen Knöpfe doppelt belegt.
  einsatzNeu();
  if (aktuellerLauf()) abspielen();
}

// ---------------------------------------------------------------- Ausführen und Abspielen

function ausfuehren() {
  const feld = document.getElementById("einsatz-code");
  if (feld) einsatz.code = feld.value;
  if (!einsatz.code.trim()) return;
  einsatzAnhalten();
  const ergebnis = ArenaKern.run(einsatz.code, einsatz.mission);
  einsatz.ergebnis = ergebnis;
  einsatz.laeufe += 1;
  einsatz.welt = ergebnis.firstFailingWorld == null ? 0 : ergebnis.firstFailingWorld;
  einsatz.bild = 0;
  einsatz.gewinn = null;
  einsatz.zuschauen = true;
  // Schon beim Aufbau als laufend markieren – sonst stünden Ergebnis und „Nächste Mission“
  // da, bevor Byte losgefahren ist.
  einsatz.spielt = true;
  if (ergebnis.solved && !einsatz.spielplatz && !einsatz.loesungGezeigt) {
    const vorher = spielFakten();
    missionMerken(einsatz.mission, ergebnis);
    einsatz.gewinn = SpielKern.gewinn(vorher, spielFakten());
  }
  einsatzNeu();
  const brett = document.getElementById("brett-karte");
  if (brett && window.innerWidth < 900) brett.scrollIntoView({ behavior: bewegungErlaubt() ? "smooth" : "auto", block: "start" });
  abspielen();
}

const bewegungErlaubt = () => !window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function abspielen() {
  if (!bilder().length) { einsatz.spielt = false; bildZeigen(); return; }
  if (amEnde()) einsatz.bild = 0;
  einsatz.spielt = true;
  bildZeigen();
  plane();
}

function plane() {
  if (!einsatz || !einsatz.spielt) return;
  if (amEnde()) { einsatz.spielt = false; bildZeigen(); return; }
  const verzoegerung = ArenaKern.delays(bilder(), TEMPO[einsatz.tempo])[einsatz.bild + 1] || TEMPO[einsatz.tempo];
  einsatz.timer = setTimeout(() => {
    if (!einsatz || !einsatz.spielt) return;
    vorwaerts();
    plane();
  }, verzoegerung * 1000);
}

function vorwaerts() {
  if (amEnde()) return;
  einsatz.bild += 1;
  bildErreicht();
  bildZeigen();
}

function bildErreicht() {
  const bild = bilder()[einsatz.bild];
  if (bild && bild.action.type === "crash") einsatz.unfaelle += 1;
  if (feiert()) einsatz.feiern += 1;
}

/** Den Weg, den Byte gefahren ist – bis zum Feld, das er gerade verlassen hat; am Ende der ganze Weg. */
function spurBis() {
  const liste = bilder().slice(0, amEnde() ? bilder().length : einsatz.bild).map((b) => b.robot);
  return liste.filter((p, i) => i === 0 || p.x !== liste[i - 1].x || p.y !== liste[i - 1].y);
}

/** Fortlaufender Drehwinkel, damit eine Drehung von 270° auf 0° nicht rückwärts animiert. */
function winkelBis(index) {
  let winkel = ArenaKern.HEADINGS[aktuelleWelt().facing].degrees;
  bilder().slice(0, index + 1).forEach((b) => {
    if (b.action.type === "turnLeft") winkel -= 90;
    if (b.action.type === "turnRight") winkel += 90;
  });
  return winkel;
}

/** Zeigt das aktuelle Bild: Byte, Münzen, Spur, Sprechblasen, Code-Zeile, Konsole und Knöpfe. */
function bildZeigen(mitAnimation = true) {
  if (!einsatz || !document.getElementById("brett")) return;
  const w = aktuelleWelt();
  const liste = bilder();
  const bild = liste.length ? liste[Math.min(einsatz.bild, liste.length - 1)] : null;
  const robot = bild ? bild.robot : w.start || { x: 0, y: 0 };
  const winkel = bild ? winkelBis(einsatz.bild) : ArenaKern.HEADINGS[w.facing].degrees;
  const verzoegerungen = ArenaKern.delays(liste, TEMPO[einsatz.tempo]);
  const dauer = Math.min((verzoegerungen[einsatz.bild] || TEMPO[einsatz.tempo]) * 0.85, 0.5);

  const byte = document.getElementById("byte");
  byte.style.transitionDuration = mitAnimation && bewegungErlaubt() ? `${dauer}s` : "0s";
  byte.style.transform = `translate(${robot.x + 0.5}px, ${robot.y + 0.5}px) rotate(${winkel}deg)`;
  const kaputt = !!bild && bild.action.type === "crash";
  byte.classList.toggle("kaputt", kaputt);
  const koerper = byte.querySelector(".byte-koerper");
  if (kaputt && mitAnimation && bewegungErlaubt()) neuAnimieren(koerper, "wackeln");
  if (feiert() && mitAnimation && bewegungErlaubt()) { neuAnimieren(koerper, "huepfen"); neuAnimieren(document.querySelector("#brett .flagge"), "wippen"); konfetti(); }

  const offen = bild ? bild.coins : new Set(w.coins.map((c) => `${c.x},${c.y}`));
  document.querySelectorAll("#brett .muenze").forEach((m) => m.classList.toggle("weg", !offen.has(m.dataset.feld)));
  const zaehler = document.querySelector("#muenzzaehler span");
  if (zaehler) zaehler.textContent = `${bild ? bild.collected : 0}/${w.coins.length}`;
  document.getElementById("spur").setAttribute("points", spurBis().map((p) => `${p.x + 0.5},${p.y + 0.5}`).join(" "));
  document.getElementById("brett-svg").setAttribute("aria-label", brettBeschreibung(w, bild));

  // Sprechblase, „+1“ und Aufprall als Ebene über dem Spielfeld.
  const ebene = document.getElementById("ueberlage");
  ebene.innerHTML = "";
  const ort = (p, html, klasse) => {
    const el = document.createElement("div");
    el.className = klasse;
    el.style.left = `${((p.x + 0.5) / w.width) * 100}%`;
    el.style.top = `${((p.y + 0.5) / w.height) * 100}%`;
    el.innerHTML = html;
    ebene.appendChild(el);
    return el;
  };
  if (bild && bild.action.type === "look") {
    const befehl = ArenaKern.commandNamed(bild.action.question);
    const blase = ort(robot, sicher(`${befehl ? befehl.summary : bild.action.question} ${bild.action.answer ? "ja" : "nein"}`), `blase ${bild.action.answer ? "ja" : "nein"}`);
    blase.style.left = `clamp(70px, ${((robot.x + 0.5) / w.width) * 100}%, calc(100% - 70px))`;
  } else if (bild && bild.action.type === "crash" && !bild.action.wall) {
    ort(robot, "Hier liegt keine Münze!", "blase nein");
  }
  if (bild && bild.action.type === "crash" && bild.action.wall) ort(bild.action.wall, "💥", "aufprall");
  if (bild && bild.action.type === "pickCoin" && mitAnimation && bewegungErlaubt()) ort(robot, "+1", "plus-eins");

  // Steuerung und Zähler
  const anzahl = liste.length;
  document.getElementById("bildzaehler").textContent = anzahl ? `${einsatz.bild + 1}/${anzahl}` : "";
  const knopf = (was) => document.querySelector(`[data-abspielen="${was}"]`);
  knopf("anfang").disabled = !anzahl;
  knopf("spielen").disabled = !anzahl;
  knopf("schritt").disabled = !anzahl || amEnde();
  knopf("ende").disabled = !anzahl || amEnde();
  knopf("spielen").textContent = einsatz.spielt ? "⏸" : "▶";
  knopf("spielen").setAttribute("aria-label", einsatz.spielt ? "Pause" : "Abspielen");

  // Code-Zeile und Fehlerzeile
  const lauf = aktuellerLauf();
  const fehlerzeile = amEnde() && lauf && lauf.problem ? lauf.problem.line : null;
  document.querySelectorAll("#spur-code .codezeile").forEach((z) => {
    const nr = Number(z.dataset.zeile);
    z.classList.toggle("aktiv", !!bild && nr === bild.line);
    z.classList.toggle("fehler", nr === fehlerzeile);
  });
  const aktiv = document.querySelector("#spur-code .codezeile.aktiv, #spur-code .codezeile.fehler");
  const kasten = document.getElementById("spur-code");
  if (aktiv && kasten) kasten.scrollTop = aktiv.offsetTop - kasten.clientHeight / 2;

  // Konsole und Variablen
  const konsole = document.getElementById("konsole");
  if (konsole && lauf) {
    const text = amEnde() ? lauf.output : bild ? bild.output : "";
    konsole.textContent = text || "(noch keine Ausgabe)";
    konsole.classList.toggle("leer", !text);
    const variablen = bild ? bild.variables : [];
    document.getElementById("variablen-teil").hidden = !variablen.length;
    document.getElementById("variablen").innerHTML = variablen.map((v) =>
      `<div><strong>${sicher(v.name)}</strong> = <span>${sicher(v.value)}</span></div>`).join("");
  }

  // Am Ende: Ergebnis und Aktionsleiste zeigen
  const ergebnisKasten = document.getElementById("einsatz-ergebnis");
  if (ergebnisKasten && einsatz.ergebnis) {
    const sichtbar = ergebnisKasten.dataset.sichtbar === "1";
    if (zeigtErgebnis() && !sichtbar) {
      ergebnisKasten.innerHTML = ergebnisHtml();
      ergebnisKasten.dataset.sichtbar = "1";
      const leiste = document.getElementById("aktionsleiste");
      if (leiste) { leiste.outerHTML = aktionsleiste(); bindeLeiste(); }
      if (window.innerWidth < 900 && mitAnimation) {
        setTimeout(() => ergebnisKasten.scrollIntoView({ behavior: bewegungErlaubt() ? "smooth" : "auto", block: "start" }), feiert() ? 1100 : 120);
      }
    } else if (!zeigtErgebnis() && sichtbar) {
      ergebnisKasten.innerHTML = ergebnisHtml();
      ergebnisKasten.dataset.sichtbar = "";
    }
  }
}

function neuAnimieren(el, klasse) {
  if (!el) return;
  el.classList.remove(klasse);
  void el.getBoundingClientRect();
  el.classList.add(klasse);
}

/** Konfetti über den ganzen Bildschirm – eine Ladung je gelöster Mission. */
function konfetti() {
  const leinwand = document.createElement("canvas");
  leinwand.className = "konfetti";
  leinwand.setAttribute("aria-hidden", "true");
  document.body.appendChild(leinwand);
  const breite = (leinwand.width = window.innerWidth * devicePixelRatio);
  const hoehe = (leinwand.height = window.innerHeight * devicePixelRatio);
  const farben = ["#F57321", "#FFC72E", "#2EAE61", "#544FE6", "#8B5CF6", "#14B8A6", "#FFFFFF"];
  const teile = Array.from({ length: 110 }, () => ({
    x: Math.random() * 0.9 + 0.05, drift: Math.random() * 0.24 - 0.12, tempo: Math.random() * 0.3 + 0.15,
    dreh: Math.random() * 6 - 3, warten: Math.random() * 0.35,
    b: (Math.random() * 4 + 5) * devicePixelRatio, h: (Math.random() * 3 + 3) * devicePixelRatio,
    farbe: farben[Math.floor(Math.random() * farben.length)],
  }));
  const ctx = leinwand.getContext("2d");
  const start = performance.now();
  const dauer = 2.4;
  function zeichnen(jetzt) {
    const t0 = (jetzt - start) / 1000;
    ctx.clearRect(0, 0, breite, hoehe);
    for (const s of teile) {
      const t = t0 - s.warten;
      if (t <= 0) continue;
      ctx.save();
      ctx.globalAlpha = Math.max(0, 1 - t / (dauer - s.warten));
      ctx.translate((s.x + s.drift * t + Math.sin(t * 4 + s.dreh) * 0.02) * breite, (-0.08 + s.tempo * t + 0.22 * t * t) * hoehe);
      ctx.rotate(s.dreh * t * 3);
      ctx.fillStyle = s.farbe;
      ctx.fillRect(-s.b / 2, -s.h / 2, s.b, s.h);
      ctx.restore();
    }
    if (t0 < dauer) requestAnimationFrame(zeichnen); else leinwand.remove();
  }
  requestAnimationFrame(zeichnen);
}

// ---------------------------------------------------------------- Mission am Ende einer Lektion

/** Die Abschluss-Mission einer Lektion – wie in der Apple-App nach der letzten Aufgabe. */
function lektionsMission() {
  if (!katalog || !sitzung || !sitzung.lektionId || sitzung.einstufung) return null;
  return katalog.lessonMission(sitzung.lektionId);
}

function lektionsMissionBeenden(ergebnis) {
  einsatzAnhalten();
  sitzung.missionFertig = true;
  sitzung.missionErgebnis = ergebnis && ergebnis.solved ? ergebnis : null;
  einsatz = null;
  zeichne();
}
