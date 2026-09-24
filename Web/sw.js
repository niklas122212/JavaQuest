/* Offline-Betrieb: Beim ersten Besuch wird alles abgelegt, danach lädt die App
   auch ohne Internet – wichtig, wenn sie wie eine App vom Home-Bildschirm startet. */
/* Eine einzige Versionsnummer für alles. Sie steckt auch in den Adressen von app.js und
   styles.css (siehe index.html) – sonst liefert der Browser aus seinem eigenen Zwischen-
   speicher die alte Fassung aus, selbst wenn der Service Worker längst erneuert wurde.
   Die Nummer ist eine Prüfsumme über alle ausgelieferten Dateien und wird NICHT von Hand
   gepflegt: Tools/build_web.sh trägt sie ein, die CI lehnt eine unpassende ab. Von Hand
   ging es schief – eine Kursänderung ohne neue Nummer erreichte Stammnutzer nie. */
const VERSION = "9125375838eb";
const CACHE = `javaquest-v${VERSION}`;
const DATEIEN = [
  "./", "./index.html", `./app.js?v=${VERSION}`, `./styles.css?v=${VERSION}`,
  "./java_course.json", "./manifest.webmanifest",
  "./icons/icon-180.png", "./icons/icon-192.png", "./icons/icon-512.png",
];

self.addEventListener("install", (e) => {
  // cache: "reload" umgeht den HTTP-Zwischenspeicher des Browsers. Sonst könnte die neue
  // Fassung dort noch eine Minuten alte java_course.json finden und sie wieder ablegen.
  const frisch = DATEIEN.map((d) => new Request(d, { cache: "reload" }));
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(frisch)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((namen) =>
    Promise.all(namen.filter((n) => n !== CACHE).map((n) => caches.delete(n)))
  ).then(() => self.clients.claim()));
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    caches.match(e.request).then((treffer) =>
      treffer || fetch(e.request).then((antwort) => {
        const kopie = antwort.clone();
        caches.open(CACHE).then((c) => c.put(e.request, kopie)).catch(() => {});
        return antwort;
      }).catch(() => caches.match("./index.html"))
    )
  );
});
