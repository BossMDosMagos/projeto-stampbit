var CACHE = 'stampbit-v5';
var URLS = [
  '/projeto-stampbit/',
  '/projeto-stampbit/index.html',
  '/projeto-stampbit/style.css',
  '/projeto-stampbit/manifest.json'
];

self.addEventListener('install', function(e) {
  e.waitUntil(caches.open(CACHE).then(function(c) { return c.addAll(URLS); }));
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(caches.keys().then(function(k) {
    return Promise.all(k.filter(function(n){return n!==CACHE}).map(function(n){return caches.delete(n)}));
  }));
  self.clients.claim();
});

self.addEventListener('fetch', function(e) {
  e.respondWith(
    caches.match(e.request).then(function(r) { return r || fetch(e.request); }).catch(function() {
      return caches.match('/projeto-stampbit/index.html');
    })
  );
});
