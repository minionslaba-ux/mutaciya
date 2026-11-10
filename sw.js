// Офлайн-режим «Мутации». Файл генерирует build.py — правьте src/sw.template.js.
const CACHE = "mutaciya-f81a04759dcc";
const ASSETS = [
  "./",
  "index.html",
  "manifest.webmanifest",
  "favicon.svg",
  "favicon.ico",
  "vendor/matter-0.19.0.min.js",
  "fonts/ibm-plex-mono-cyrillic-400-normal.woff2",
  "fonts/ibm-plex-mono-cyrillic-600-normal.woff2",
  "fonts/ibm-plex-mono-latin-400-normal.woff2",
  "fonts/ibm-plex-mono-latin-600-normal.woff2",
  "fonts/ibm-plex-sans-cyrillic-400-normal.woff2",
  "fonts/ibm-plex-sans-cyrillic-600-normal.woff2",
  "fonts/ibm-plex-sans-latin-400-normal.woff2",
  "fonts/ibm-plex-sans-latin-600-normal.woff2",
  "fonts/rubik-distressed-cyrillic-400-normal.woff2",
  "fonts/rubik-distressed-latin-400-normal.woff2",
  "fonts/rubik-glitch-cyrillic-400-normal.woff2",
  "fonts/rubik-glitch-latin-400-normal.woff2",
  "fonts/rubik-wet-paint-cyrillic-400-normal.woff2",
  "fonts/rubik-wet-paint-latin-400-normal.woff2",
  "icons/apple-touch-icon.png",
  "icons/favicon-16.png",
  "icons/favicon-32.png",
  "icons/icon-192.png",
  "icons/icon-512.png",
  "icons/icon-maskable-512.png"
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith("mutaciya-") && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== location.origin) return;
  if (req.mode === "navigate") {
    // страница: сначала сеть, чтобы приходили обновления; без сети — из кэша.
    // Игра кэшируется как index.html, остальные страницы (оферта, контакты…) — под своим адресом.
    const path = new URL(req.url).pathname;
    const isGame = path === "/" || path.endsWith("/index.html") || path.endsWith("/");
    const key = isGame ? "index.html" : req;
    e.respondWith(
      fetch(req)
        .then((res) => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(key, copy)); } return res; })
        .catch(() => caches.match(key).then((hit) => hit || caches.match("index.html")))
    );
    return;
  }
  // остальное: из кэша, а если нет — из сети
  e.respondWith(caches.match(req).then((hit) => hit || fetch(req)));
});
