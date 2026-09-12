self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
// Network-only: authenticated Sites HTML is intentionally not cached.
