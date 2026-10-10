// Shiny Ledger service worker: the app opens and counts with no signal.
// Bump VERSION whenever you deploy so phones pick up the new files.
const VERSION = 'shiny-ledger-v8';
const SHELL = ['./','index.html','config.js','supabase.js','591.supabase.js'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL.map(u => new Request(u, { cache: 'reload' })))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // Icons and the manifest always come straight from the site. iOS reads these when
  // you tap Add to Home Screen, and it can fail if a service worker answers instead.
  if (/\.(png|ico|svg)$|\.webmanifest$/.test(url.pathname)) return;
  // Never cache Supabase API or auth traffic.
  if (url.hostname.endsWith('supabase.co') || url.hostname.endsWith('supabase.in')) return;
  // App pages and config: network first so updates land, cache when offline.
  if (req.mode === 'navigate' || url.pathname.endsWith('/config.js')) {
    e.respondWith(fetch(req).then(res => { const copy = res.clone(); caches.open(VERSION).then(c => c.put(req, copy)); return res; })
      .catch(() => caches.match(req).then(r => r || caches.match('./'))));
    return;
  }
  // Everything else (fonts, icons, scripts): cache first, refresh in the background.
  e.respondWith(caches.match(req).then(hit => {
    const net = fetch(req).then(res => { if (res && (res.ok || res.type === 'opaque')) { const copy = res.clone(); caches.open(VERSION).then(c => c.put(req, copy)); } return res; }).catch(() => hit);
    return hit || net;
  }));
});
