// service worker ขั้นต่ำ ให้เบราว์เซอร์นับว่าเป็นแอปที่ "ติดตั้งได้"
// (Chrome / Edge / Samsung Internet บน Android และ PC) ปุ่ม "ติดตั้งแอปลงเครื่อง"
// จึงกดแล้วติดตั้งได้เลย — ลงทะเบียนใน web/index.html
//
// ไม่แคชอะไรเลย: ทุกคำขอวิ่งไปเน็ตตามปกติ deploy แล้วผู้ใช้ได้เวอร์ชันใหม่ทันที
// แตะเฉพาะการเปิดหน้า (navigate) ตอนไม่มีเน็ต ให้ขึ้นข้อความแทนหน้าพังของเบราว์เซอร์

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

self.addEventListener('fetch', (event) => {
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
