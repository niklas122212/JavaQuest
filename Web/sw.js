/* Offline-Betrieb: Beim ersten Besuch wird alles abgelegt, danach lädt die App
   auch ohne Internet – wichtig, wenn sie wie eine App vom Home-Bildschirm startet. */
const CACHE = "javaquest-v3";
const DATEIEN = [
  "./", "./index.html", "./app.js", "./styles.css",
  "./java_course.json", "./manifest.webmanifest",
  "./icons/icon-180.png", "./icons/icon-192.png", "./icons/icon-512.png",
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(DATEIEN)).then(() => self.skipWaiting()));
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
