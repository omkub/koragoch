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
