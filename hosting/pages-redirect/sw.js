// แทน sw.js ของแอปที่เคยอยู่บน GitHub Pages (omkub.github.io/koragoch/) — ระบบย้ายไป
// rbp-chanikarnn.web.app แล้ว
//
// เครื่องที่เคยติดตั้ง / เปิดแจ้งเตือนจาก GitHub Pages: เบราว์เซอร์ตรวจไฟล์นี้ใหม่ตอนเปิด
// เจอเวอร์ชันนี้แล้ว ลบแคช → ถอดตัวเองออก (การรับแจ้งเตือนของที่อยู่เก่ายกเลิกไปด้วย
// แถวใน PushSubscriptions ถูกลบเองตอนส่งครั้งถัดไป เพราะปลายทางตอบ 404/410)
// → โหลดหน้าใหม่ = เจอหน้าพาไปที่อยู่ใหม่

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((key) => caches.delete(key)));
      await self.registration.unregister();
      const windows = await self.clients.matchAll({ type: 'window' });
      windows.forEach((client) => client.navigate(client.url));
    })(),
  );
});
