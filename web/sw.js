// service worker ขั้นต่ำ ให้เบราว์เซอร์นับว่าเป็นแอปที่ "ติดตั้งได้"
// (Chrome / Edge / Samsung Internet บน Android และ PC) ปุ่ม "ติดตั้งแอปลงเครื่อง"
// จึงกดแล้วติดตั้งได้เลย — ลงทะเบียนใน web/index.html
//
// แคชเฉพาะ main.dart.js (ตัวแอป 1 MB) ผูกกับรหัส build — ไฟล์อื่นวิ่งไปเน็ตตามปกติ
// แตะการเปิดหน้า (navigate) ตอนไม่มีเน็ต ให้ขึ้นข้อความแทนหน้าพังของเบราว์เซอร์
//
// ทำไมต้องแคชเอง: Firebase Hosting ไม่ตอบ 304 ให้ไฟล์ที่ตั้ง no-cache (วัดจริง
// 28 ต.ค. 2569 — ส่ง If-None-Match ตรงกันก็ยังได้ 200 เต็มไฟล์) เปิดแอปทุกครั้ง
// จึงโหลด main.dart.js ใหม่ทั้งก้อน หน้า Login ช้า
//
// ไม่ได้ของเก่าค้าง: ทุกครั้งถาม app-version.json (ไม่กี่ไบต์ CI เขียนใหม่ทุก deploy)
// build ตรงกับที่เก็บไว้ = ใช้ของในเครื่อง · ไม่ตรง = โหลดใหม่แล้วลบของเก่าทิ้ง
// ไม่มี app-version.json (รันในเครื่อง) = ไม่แคช โหลดจากเน็ตเหมือนเดิม

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// ── แจ้งเตือนแบบแอป (Web Push) — เฉพาะผู้ดูแลระบบที่เปิดไว้ ─────────────────
// ส่งมาจาก Edge Function push-notify: { title, body, url, tag }
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { title: 'ระบบวันลา', body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'ระบบวันลา', {
      body: data.body || '',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-maskable-192.png',
      tag: data.tag || undefined,
      renotify: !!data.tag,
      data: { url: data.url || './' },
    }),
  );
});

// แตะแจ้งเตือน → สลับไปแอปที่เปิดอยู่ ไม่มีก็เปิดใหม่
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL((event.notification.data && event.notification.data.url) || './', self.registration.scope).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if (c.url.startsWith(self.registration.scope) && 'focus' in c) return c.focus();
      }
      return self.clients.openWindow(target);
    }),
  );
});

const APP_CACHE_PREFIX = 'koragoch-app-';

/** รหัส build ปัจจุบันจากเซิร์ฟเวอร์ (null = ไม่รู้ — ไม่มีไฟล์ / ไม่มีเน็ต / ช้าเกิน) */
async function currentBuild() {
  try {
    const url = new URL('app-version.json', self.registration.scope);
    url.searchParams.set('t', Date.now());
    const res = await Promise.race([
      fetch(url, { cache: 'no-store' }),
      new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 4000)),
    ]);
    if (!res.ok) return null;
    const build = String((await res.json()).build || '').trim();
    return build || null;
  } catch (_) {
    return null;
  }
}

/** ตัวแอปที่เก็บไว้ล่าสุด (ใช้ตอนไม่มีเน็ต) */
async function anyCachedApp(request) {
  const keys = await caches.keys();
  for (const key of keys.filter((k) => k.startsWith(APP_CACHE_PREFIX))) {
    const hit = await (await caches.open(key)).match(request, { ignoreSearch: true });
    if (hit) return hit;
  }
  return null;
}

async function serveAppBundle(request) {
  const build = await currentBuild();
  if (!build) {
    // ไม่รู้เวอร์ชัน: ลองเน็ตก่อน (ไม่ให้ได้ของเก่าโดยไม่ตั้งใจ) ไม่ได้ค่อยใช้ของในเครื่อง
    try {
      return await fetch(request);
    } catch (e) {
      const cached = await anyCachedApp(request);
      if (cached) return cached;
      throw e;
    }
  }

  const name = APP_CACHE_PREFIX + build;
  const cache = await caches.open(name);
  const hit = await cache.match(request, { ignoreSearch: true });
  if (hit) return hit;

  const res = await fetch(request, { cache: 'no-store' });
  if (res.ok && res.status === 200) {
    await cache.put(request, res.clone());
    // deploy ใหม่แล้ว — ลบตัวแอปเวอร์ชันก่อนๆ ไม่ให้เปลืองที่ในเครื่อง
    const keys = await caches.keys();
    await Promise.all(
      keys.filter((k) => k.startsWith(APP_CACHE_PREFIX) && k !== name).map((k) => caches.delete(k)),
    );
  }
  return res;
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method === 'GET') {
    const url = new URL(request.url);
    if (url.origin === self.location.origin && url.pathname.endsWith('/main.dart.js')) {
      event.respondWith(serveAppBundle(request));
      return;
    }
  }
  if (event.request.mode !== 'navigate') return;
  event.respondWith(
    fetch(event.request).catch(
      () =>
        new Response(
          '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
            '<title>ระบบวันลา</title><body style="font-family:sans-serif;text-align:center;padding:48px 16px;color:#334155">' +
            '<h2>ไม่มีการเชื่อมต่ออินเทอร์เน็ต</h2><p>ต่ออินเทอร์เน็ตแล้วเปิดแอปใหม่อีกครั้ง</p></body>',
          { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
        ),
    ),
  );
});
