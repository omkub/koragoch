{{flutter_js}}
{{flutter_build_config}}

// ไม่ใช้ service worker ของ Flutter (เลิกใช้แล้ว ตัวมันลบตัวเองทิ้ง และจะลบ
// sw.js ของเราที่อยู่ scope เดียวกันไปด้วย) — ดู web/sw.js
_flutter.loader.load();
