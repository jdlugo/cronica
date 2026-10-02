const CACHE_NAME = "daily-reel-shell-v29";
const APP_SHELL = [
  "/",
  "/index.html",
  "/styles.css?v=21",
  "/public/manifest.webmanifest?v=4",
  "/public/icon.svg",
  "/src/app.js?v=25",
  "/src/session-telemetry.js?v=1",
  "/src/challenge-context.js?v=1",
  "/src/daily-reel-calendar.js?v=2",
  "/src/daily-reel-client.js?v=6",
  "/src/daily-reel-machine.js?v=7",
  "/src/daily-reel-progress.js?v=1",
  "/src/demo-client.js?v=3",
  "/src/firebase-app-check.js?v=3",
  "/src/firebase-config.js?v=2",
  "/src/game-copy.js?v=2",
  "/src/posthog-bridge.js?v=8",
  "/src/register-service-worker.js?v=2",
  "/src/share-delivery.js?v=1",
];

async function fetchAndCache(request) {
  const response = await fetch(request);
  if (response.ok) {
    const cache = await caches.open(CACHE_NAME);
    await cache.put(request, response.clone());
  }
  return response;
}

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)),
    )),
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).catch(() => caches.match("/index.html")),
    );
    return;
  }

  event.respondWith(
    caches.match(request).then((cached) => {
      if (!cached) return fetchAndCache(request);
      event.waitUntil(fetchAndCache(request).catch(() => undefined));
      return cached;
    }),
  );
});
