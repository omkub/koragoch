# CLAUDE.md

รายละเอียดโปรเจค วิธีรัน และวิธี deploy ดูที่ `README.md`

## คำเรียกส่วนต่างๆ ของระบบ

ใช้คำเหล่านี้ทุกครั้งที่คุย สรุป วางแผน หรือแก้งาน

| คำเรียก | คืออะไร | โค้ด |
|---|---|---|
| **web** | เว็บส่วนกลาง (React + TypeScript + Vite) เสิร์ฟที่ `/central/` | `central/` |
| **app** | แอป Flutter (build เป็นเว็บ) | `lib/` |
| ├ **app PC** | จอกว้าง ≥ 1100px → `MainLayout` | `lib/screens/main_layout.dart` + หน้าจอใน `lib/screens/` |
| └ **app มือถือ** | จอแคบกว่า 1100px | — |
| &nbsp;&nbsp;&nbsp;• แบบใหม่ | `MobileShell` (ค่าเริ่มต้น) | `lib/screens/mobile_v2/` |
| &nbsp;&nbsp;&nbsp;• แบบเดิม | `MobileMainLayout` (โรงเรียนเลือกได้ — `SchoolInfo.useOldMobileUi`) | `lib/screens/mobile/` |

- ตัวเลือกหน้าจอ PC / มือถือ อยู่ที่ `lib/screens/responsive_layout.dart`
- โฟลเดอร์ `web/` ที่ root เป็นไฟล์ประกอบของ Flutter (`index.html`, ไอคอน) **ไม่ใช่** "web"
- ถ้าสั่งงาน "app" โดยไม่ระบุ และงานกระทบหน้าจอ ให้ระบุให้ชัดว่าแก้ app PC, app มือถือ (แบบใหม่ / แบบเดิม) หรือทั้งหมด
