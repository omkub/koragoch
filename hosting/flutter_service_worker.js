// ตัวล้างแอปเดิม — วางทับ flutter_service_worker.js ตอน deploy ขึ้น Firebase Hosting
// (คัดลอกโดย .github/workflows/deploy-firebase.yml หลัง flutter build)
//
// แอปเดิมที่ rbp-chanikarnn.web.app ลงทะเบียน service worker ชื่อนี้ไว้ และเก็บไฟล์
// ของแอปเดิมไว้ในเครื่อง เปิดเว็บแล้วอาจยังเจอแอปเดิมจากแคช
// เบราว์เซอร์ตรวจไฟล์นี้ใหม่ทุกครั้งที่เปิดเว็บ เจอเวอร์ชันนี้แล้ว:
//   ลบแคชทั้งหมด → ถอดตัวเองออก → โหลดหน้าใหม่ = ได้แอปใหม่ (ซึ่งใช้ sw.js ของตัวเอง)
// แอปใหม่ไม่ได้ลงทะเบียนไฟล์นี้ ไฟล์นี้มีไว้ล้างของเก่าอย่างเดียว

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
