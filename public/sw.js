/* Service worker WiFiMarket : cache des ressources statiques + page hors connexion.
   Ne met JAMAIS en cache : authentification, API Supabase, pages connectées, requêtes non-GET. */
const VERSION = "wm-v1";
const STATIC_CACHE = `${VERSION}-static`;
const PAGES_CACHE = `${VERSION}-pages`;
const OFFLINE_URL = "/offline";
const PRECACHE = [OFFLINE_URL, "/icons/icon-192.png", "/icons/icon-512.png"];
const PRIVATE_PREFIXES = ["/compte", "/messages", "/admin", "/auth", "/connexion", "/inscription", "/commande", "/panier", "/vendre", "/api"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(STATIC_CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => !k.startsWith(VERSION)).map((k) => caches.delete(k)))).then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // Supabase, CDN… : réseau uniquement

  // Ressources statiques immuables : cache d'abord
  if (url.pathname.startsWith("/_next/static/") || url.pathname.startsWith("/icons/")) {
    event.respondWith(
      caches.match(req).then((hit) => hit || fetch(req).then((res) => {
        if (res.ok) { const copy = res.clone(); caches.open(STATIC_CACHE).then((c) => c.put(req, copy)); }
        return res;
      })),
    );
    return;
  }

  // Navigation : réseau d'abord ; pages publiques gardées pour la lecture hors ligne ; sinon page /offline
  if (req.mode === "navigate") {
    const isPrivate = PRIVATE_PREFIXES.some((p) => url.pathname === p || url.pathname.startsWith(p + "/"));
    event.respondWith(
      fetch(req).then((res) => {
        if (res.ok && !isPrivate) { const copy = res.clone(); caches.open(PAGES_CACHE).then((c) => c.put(req, copy)); }
        return res;
      }).catch(async () => (!isPrivate && (await caches.match(req))) || (await caches.match(OFFLINE_URL)) || Response.error()),
    );
  }
});
