# SchoolLeaveApp

A staff leave management system used in production at [Romburipittayakhom Ratchamungklapisek School], Thailand.

- **Staff** submit leave requests and official trip requests, check in by face scan, and view their history.
- **School administrators** approve requests, manage personnel and roles, and track leave per fiscal year on a live dashboard.
- **Central administrators** manage schools, permissions, LINE notifications, attendance devices, and the printed form templates.
- **Stack:** Flutter (web) app + React/TypeScript central admin web, both on **Supabase** (Postgres, Auth, RLS, Edge Functions). Firebase is kept read-only for the legacy data import tool.
- **Live:** https://omkub.github.io/koragoch/ (app) and https://omkub.github.io/koragoch/central/ (central admin), deployed automatically with GitHub Actions.

Documentation below is in Thai.

---

# SchoolLeaveApp (โปรแกรมระบบลาโรงเรียน)

ระบบมี 2 ส่วน ในเอกสารนี้และในการคุยงานใช้คำเรียกตามนี้เสมอ

| เรียกว่า | คืออะไร | โค้ด | URL | ผู้ใช้ |
|---|---|---|---|---|
| **app** | แอป Flutter (build เป็นเว็บ) | `lib/` (+ `web/` ไฟล์ประกอบของ Flutter) | https://omkub.github.io/koragoch/ | ครู / บุคลากร / แอดมินโรงเรียน |
| **web** | เว็บผู้ดูแลระบบส่วนกลาง (React + TypeScript + Vite) | `central/` | https://omkub.github.io/koragoch/central/ | ผู้ดูแลส่วนกลาง / แอดมินโรงเรียน |

> โฟลเดอร์ `web/` เป็นไฟล์ประกอบของแอป Flutter (`index.html`, ไอคอน) **ไม่ใช่** "web" ในตารางข้างบน

- ฐานข้อมูล: **Supabase** (ตาราง / สิทธิ์ RLS / Auth / Edge Functions) — SQL อยู่ใน `supabase/`
- รองรับหลายโรงเรียน: ข้อมูลแยกตาม `id_school` สิทธิ์จริงคุมด้วย RLS ฝั่งฐานข้อมูล
- Firebase (`rbp-chanikarnn` / Firestore `school`): ข้อมูลเก่า ใช้อ่านอย่างเดียวในเครื่องมือนำเข้าข้อมูลเท่านั้น
- Repo: https://github.com/omkub/koragoch · Release: แท็บ [Releases](https://github.com/omkub/koragoch/releases)

---

## ความสามารถหลัก

**app**
- ส่งใบลา / ประวัติการลา / ปฏิทินกิจกรรม / แดชบอร์ด / รายงานสรุปการลา — พิมพ์ใบลาเป็น PDF ได้
- **บันทึกไปราชการ / ประชุม** (ฟอร์มซ้าย + พรีวิวเอกสารขวา) และ **ประวัติไปราชการ / ประชุม** (อนุมัติ / รายงานผล / พิมพ์)
- **ลงเวลา**: ดูสถานะรายวัน รายงานรายเดือน นำเข้าไฟล์จากเครื่องสแกน
- จัดการบุคลากร ผู้ใช้ สิทธิ์เมนู ประวัติการเข้าใช้งาน
- มือถือ (จอแคบกว่า 1100px) ใช้หน้าจอชุด `lib/screens/mobile/`

**web**
- โรงเรียน / ผู้ดูแลโรงเรียน / เพดานสิทธิ์ / สิทธิ์ผู้ใช้
- LINE แจ้งเตือน (ต่อโรงเรียน) / ลงเวลา (เครื่องสแกนหน้า + สรุป LINE ประจำวัน)
- **แบบฟอร์ม**: ออกแบบใบลาและใบขออนุญาตไปราชการ (ดูหัวข้อถัดไป)

---

## แม่แบบฟอร์ม (ออกแบบที่ web → ใช้ใน app)

ใบลาและใบขออนุญาตไปราชการทุกใบใน app (พรีวิว + พิมพ์ / PDF) วาดจากแม่แบบที่ออกแบบในหน้า **แบบฟอร์ม** ของ web

- เก็บในตาราง `FormTemplates` แบบเวอร์ชัน (`supabase/form_templates.sql`)
- ลำดับที่ใช้: แม่แบบของโรงเรียน → แม่แบบกลาง → แม่แบบเริ่มต้นในโค้ด
- บันทึกที่ web แล้ว app ใช้แม่แบบใหม่ภายใน 5 นาที (หรือทันทีเมื่อเข้าระบบใหม่)
- เขียนในช่องข้อความได้: `{ชื่อ}` = ตัวแทนข้อมูล, `**ข้อความ**` = ตัวหนา, `[[ข้อความ]]` = ช่องเส้นประในบรรทัด

**ตัววาดมี 2 ชุดที่ต้องได้ผลเหมือนกันทุกตัวอักษร**

| | web | app |
|---|---|---|
| แม่แบบ (โครงสร้าง) | `central/src/forms/template.ts` | `lib/forms/form_template.dart` |
| ตัววาด แม่แบบ → HTML | `central/src/forms/render.ts` | `lib/forms/form_render.dart` |
| ข้อมูลใบลา → ตัวแทนข้อมูล | `leaveContext()` ใน `leaveTemplate.ts` | `lib/forms/leave_render_context.dart` |
| ข้อมูลไปราชการ → ตัวแทนข้อมูล | `tripContext()` ใน `tripTemplate.ts` | `lib/forms/trip_render_context.dart` |
| แม่แบบเริ่มต้น | `leaveTemplate.ts` / `tripTemplate.ts` | `lib/forms/default_templates.g.dart` (สร้างอัตโนมัติ) |

แก้ฝั่งใดฝั่งหนึ่งต้องแก้อีกฝั่งให้ตรงกัน แล้วรัน

```bash
cd central
npm run form-defaults   # แม่แบบเริ่มต้นของ web → lib/forms/default_templates.g.dart
npm run form-fixtures   # ชุดทดสอบจากตัววาดของ web → test/fixtures/*.json
cd ..
flutter test test/form_template_test.dart test/form_render_parity_test.dart
```

- กรณีทดสอบอยู่ที่ `central/scripts/form-render-cases.ts` — เพิ่มตัวเลือกใหม่ในแม่แบบให้เพิ่มกรณีที่นี่ด้วย
- **CI รันทั้งสองคำสั่งและเทสเทียบให้ก่อน deploy ทุกครั้ง ถ้าตัววาดสองฝั่งไม่ตรงกัน จะไม่ deploy** (เว็บเดิมยังใช้งานได้)

---

## เริ่มใช้งานบนเครื่องใหม่

### 1) ติดตั้งของที่ต้องมี
- [Git](https://git-scm.com/download/win)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
- [Node.js](https://nodejs.org/) 20 ขึ้นไป (สำหรับ web และสคริปต์แม่แบบฟอร์ม)
- Google Chrome (สำหรับรัน app)
- (ถ้าจะ push กลับ) [GitHub CLI](https://cli.github.com/) — `gh`

```bash
flutter doctor
gh auth login        # ครั้งแรก: GitHub.com → HTTPS → web browser
```

### 2) Clone และติดตั้ง dependency
```bash
git clone https://github.com/omkub/koragoch.git SchoolLeaveApp
cd SchoolLeaveApp
flutter pub get
cd central
npm install
cd ..
```

### 3) รัน
```bash
flutter run -d chrome          # app
```

```bash
npm --prefix central run dev   # web (http://localhost:5173/koragoch/central/)
```

> ค่าเชื่อมต่อ (Supabase URL + anon key ใน `lib/main.dart` และ `central/src/supabase.ts`, `lib/firebase_options.dart`) อยู่ใน repo แล้ว ใช้ได้เลยไม่ต้องตั้งค่าเพิ่ม anon key เป็นค่าสาธารณะ สิทธิ์จริงคุมด้วย RLS
> `node_modules/`, `build/`, `.dart_tool/` ถูก `.gitignore` สร้างใหม่ได้จากขั้นตอนด้านบน

### 4) ตรวจก่อนส่งงาน
```bash
flutter analyze
flutter test
npm --prefix central run build
```

---

## ส่งงานและ deploy

ทำงานบน branch แยก แล้วเปิด Pull Request เข้า `main`

```bash
git pull origin main
git checkout -b ชื่อ-branch
git add -A
git commit -m "อธิบายสิ่งที่แก้"
git push -u origin ชื่อ-branch
gh pr create --base main
```

เมื่อ merge เข้า `main` แล้ว GitHub Actions (`.github/workflows/deploy-pages.yml`) จะ

1. สร้างแม่แบบเริ่มต้น + ชุดทดสอบตัววาดจากโค้ด web
2. เทียบตัววาดเอกสาร app กับ web (ไม่ผ่าน = หยุด ไม่ deploy)
3. build app (Flutter web) และ web (`central/`) แล้ววาง web ไว้ใต้ `/central/`
4. deploy ขึ้น GitHub Pages

ตรวจสถานะได้ที่ https://github.com/omkub/koragoch/actions — รอบที่เป็นสีแดง เว็บจะยังเป็นเวอร์ชันก่อนหน้า

---

## ฐานข้อมูล (Supabase)

- SQL ทุกไฟล์อยู่ใน `supabase/` รันใน Supabase Dashboard → SQL Editor ไฟล์ส่วนใหญ่รันซ้ำได้ หัวไฟล์บอกลำดับที่ต้องรันก่อน
- Edge Functions อยู่ใน `supabase/functions/` (งานแอดมิน `clever-responder`, ลงเวลา `attendance-ingest` / `attendance-daily-line`, `school-bridge`)
- ตัวเชื่อมเครื่องสแกนลงเวลา: `tools/attendance-connector/` (ดู README ในโฟลเดอร์)
- สร้างบัญชี Auth ให้ครูที่ยังไม่มี: `tools/create_auth_users.mjs`

### นำเข้าข้อมูลเก่าจาก Firebase

เมนู **จัดการระบบ → แท็บ "นำเข้าข้อมูล"** (ผู้ดูแลระบบ)

- **Firebase อ่านอย่างเดียว** — การนำเข้าไม่แก้/ลบข้อมูล Firebase
- ปุ่ม **"ล้างข้อมูล"** ล้างเฉพาะตารางฝั่ง Supabase
- ลำดับนำเข้า (master → Teachers → dependent) จัดให้อัตโนมัติ
- ชื่อคอลัมน์ฝั่งโค้ดยึดตามที่มีจริงใน Supabase เช่น `roles.Accessrights`, `appconfig."Key AppTitle"`

---

## การออกเวอร์ชัน (Release)

เลขเวอร์ชันแบบวันที่ `YY.M.D+N` ใน `pubspec.yaml` (ปัจจุบัน `26.9.24+11`) และ tag `YY.M.D.N` ต่อ release

```bash
git tag -a <version> -m "Release <version>"
git push origin <version>
gh release create <version> --title <version> --notes-file RELEASE_NOTES_<version>.md
```

---

## โครงสร้างหลัก

| ส่วน | ไฟล์ |
|---|---|
| app: เริ่มแอป / เชื่อม Supabase | `lib/main.dart` |
| app: เมนูและหน้าจอ (จอกว้าง / มือถือ) | `lib/screens/main_layout.dart`, `lib/screens/mobile/mobile_main_layout.dart` |
| app: หน้าจอ | `lib/screens/` |
| app: บริการข้อมูล | `lib/services/` (ใบลา/บุคลากร `firebase_service.dart` — ชื่อเดิม แต่ใช้ Supabase, ไปราชการ, ลงเวลา, แม่แบบฟอร์ม) |
| app: แม่แบบฟอร์ม + ตัววาด | `lib/forms/` |
| app: ข้อมูลโรงเรียนปัจจุบัน | `lib/utils/school_info.dart` |
| web: หน้าเว็บ | `central/src/pages/` |
| web: แม่แบบฟอร์ม + ตัวแก้ไข | `central/src/forms/` |
| สคริปต์ส่งออกแม่แบบให้ app | `central/scripts/` |
| ฐานข้อมูล / Edge Functions | `supabase/` |
| เทส | `test/` (ชุดทดสอบจาก web อยู่ใน `test/fixtures/`) |
