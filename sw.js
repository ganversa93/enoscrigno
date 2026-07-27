// ══ Service Worker Enoscrigno — permette all'app di aprirsi anche
// senza connessione, mostrando l'ultima versione salvata in cache.
// I dati (vini, profilo) sono gestiti separatamente in localStorage
// dall'app stessa (vedi index.html), qui ci occupiamo solo dei file
// dell'app (HTML/CSS/JS/immagini), non delle chiamate a Supabase.

const CACHE_NAME = 'enoscrigno-shell-v1';
const SHELL_FILES = [
  './',
  './index.html',
  './manifest.json',
  './assets/enoscrigno-icon-white.png',
  './assets/enoscrigno-logo-v2.png',
  './assets/favicon-192.png',
  './assets/favicon-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(SHELL_FILES))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(names =>
      Promise.all(names.filter(n => n !== CACHE_NAME).map(n => caches.delete(n)))
    )
  );
  self.clients.claim();
});

// Strategia: prova la rete (per avere sempre l'ultima versione se
// disponibile); se la rete non risponde, usa la cache. Le chiamate a
// Supabase (API esterne) non vengono mai intercettate qui.
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (url.origin !== location.origin) return; // lascia passare le chiamate a Supabase

  event.respondWith(
    fetch(event.request)
      .then(response => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request).then(cached => cached || caches.match('./index.html')))
  );
});
