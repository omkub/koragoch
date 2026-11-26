# SchoolLeaveApp

A staff leave management system used in production at [Romburipittayakhom Ratchamungklapisek School], Thailand.

- **Staff** submit leave requests and official trip requests, check in by face scan, and view their history.
- **School administrators** approve requests, manage personnel and roles, and track leave per fiscal year on a live dashboard.
- **Central administrators** manage schools, permissions, LINE notifications, attendance devices, and the printed form templates.
- **School web:** the central web is also the school's own portal — 4 divisions with sub-modules (staff, students, documents, budget, appointment orders with .docx export), 4-tier permissions, and two-way SSO with the app.
- **Stack:** Flutter (web) app + React/TypeScript central web, both on **Supabase** (Postgres, Auth, RLS, Edge Functions). Firebase is kept read-only for the legacy data import tool.
- **Live:** https://rbp-chanikarnn.web.app/ (app) and https://rbp-chanikarnn.web.app/central/ (central admin) on Firebase Hosting, deployed automatically with GitHub Actions. The old https://omkub.github.io/koragoch/ redirects there.

Documentation below is in Thai.

---

# SchoolLeaveApp (โปรแกรมระบบลาโรงเรียน)

ระบบมี 2 ส่วน ในเอกสารนี้และในการคุยงานใช้คำเรียกตามนี้เสมอ

| เรียกว่า | คืออะไร | โค้ด | URL | ผู้ใช้ |
|---|---|---|---|---|
| **app** | แอป Flutter (build เป็นเว็บ) | `lib/` (+ `web/` ไฟล์ประกอบของ Flutter) | https://rbp-chanikarnn.web.app/ | ครู / บุคลากร / แอดมินโรงเรียน |
| **web** | เว็บโรงเรียน (4 ฝ่าย) + ส่วนดูแลระบบวันลา (React + TypeScript + Vite) | `central/` | https://rbp-chanikarnn.web.app/central/ | ครู / ผู้บริหาร / แอดมินโรงเรียน / ผู้ดูแลส่วนกลาง |

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
- มือถือ (จอแคบกว่า 1100px) ใช้หน้าจอชุด `lib/screens/mobile_v2/` (แบบใหม่) หรือ `lib/screens/mobile/` (แบบเดิม) ตามที่โรงเรียนตั้ง
- app PC มีแท็บ **เว็บโรงเรียน** ฝัง web ไว้ในแอป เข้าได้โดยไม่ต้องล็อกอินซ้ำ (SSO)

**web — เว็บโรงเรียน** (`central/src/school/`)
- โรงเรียน → **ฝ่าย 4 ฝ่าย** (บุคคล / วิชาการ / บริหารทั่วไป / งบประมาณ) → **Module ย่อย**
  - บุคคล: ระบบวันลา, ทะเบียนบุคลากร, กลุ่มสาระ/ฝ่าย · วิชาการ: นักเรียน/ห้องเรียน, หลักสูตร/ตารางสอน · บริหารทั่วไป: หนังสือราชการ, ประกาศ · งบประมาณ: งบประมาณ/โครงการ/พัสดุ
  - **คำสั่งแต่งตั้ง** (ทุกฝ่าย): ฟอร์มซ้าย + ตัวอย่าง A4 ขวา ส่งออก .docx พร้อมตราครุฑ เลือกเลขไทย/อารบิกได้
- **สิทธิ์ 4 ระดับ**: ผู้ใช้งาน (เห็นเฉพาะฝ่ายที่สังกัด) / ผู้บริหาร (ทุกฝ่าย) / Admin โรงเรียน (จัดการทุกฝ่าย) / Super Admin (ทุกโรงเรียน + เพดานแพ็กเกจ)
- map บุคลากรเข้าฝ่าย (`/admin/mapping`) และสิทธิ์ฝ่าย/Module ตามบทบาทและรายบุคคล (`/admin/division-permissions`, `/user-permissions`)
- **SSO 2 ทาง** กับ app (ส่ง session ผ่าน URL / localStorage โดเมนเดียวกัน) — รายละเอียดใน `CLAUDE.md`

**web — ดูแลระบบวันลา**
- ภาพรวมระบบวันลา (`/leave-admin`) / โรงเรียน / ผู้ดูแลโรงเรียน / เพดานสิทธิ์ / สิทธิ์ผู้ใช้
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

เมื่อ merge เข้า `main` แล้ว GitHub Actions (`.github/workflows/deploy-firebase.yml`) จะ

1. สร้างแม่แบบเริ่มต้น + ชุดทดสอบตัววาดจากโค้ด web
2. เทียบตัววาดเอกสาร app กับ web (ไม่ผ่าน = หยุด ไม่ deploy)
3. build app (Flutter web) และ web (`central/`) แล้ววาง web ไว้ใต้ `/central/`
4. deploy ขึ้น Firebase Hosting (`rbp-chanikarnn.web.app`) เฉพาะ hosting · ย้อนเวอร์ชันได้ที่ Firebase Console > Hosting

ตรวจสถานะได้ที่ https://github.com/omkub/koragoch/actions — รอบที่เป็นสีแดง เว็บจะยังเป็นเวอร์ชันก่อนหน้า

### ย้ายจาก GitHub Pages ไป Firebase Hosting (`rbp-chanikarnn.web.app`) — เสร็จแล้ว

`.github/workflows/deploy-firebase.yml` build ชุดเดียวกันแต่เสิร์ฟที่ราก `/`
(app: `--base-href /`, web: `npm run build -- --base /central/`) แล้ว deploy เฉพาะ hosting

| พาท | สถานะ | ปลายทาง |
|---|---|---|
| 1 เตรียม ✅ | build ได้ทั้ง `/koragoch/` และ `/` · `firebase.json` · ตัวล้างแอปเดิม (`hosting/flutter_service_worker.js`) | — |
| 2 ทดสอบ ✅ | deploy ขึ้น preview channel `test` (ลิงก์อยู่ในผลของ workflow) | `rbp-chanikarnn--test-….web.app` |
| 3 สลับจริง ✅ | นำเข้าข้อมูลรอบสุดท้าย แล้ว deploy ขึ้น live (merge = ขึ้นเว็บจริงอัตโนมัติ) — ย้อนกลับได้ที่ Firebase Console > Hosting | `rbp-chanikarnn.web.app` |
| 4 ปิด Pages ✅ | GitHub Pages พาไปที่อยู่ใหม่ (`hosting/pages-redirect/`) · deploy อัตโนมัติไป Firebase แทน | — |

ต้องมี secret `FIREBASE_SERVICE_ACCOUNT_RBP_CHANIKARNN` (JSON ของ service account) ไม่มีจะ build อย่างเดียว ไม่ deploy
ห้าม `firebase deploy` แบบไม่ระบุ `--only hosting` — จะไปทับกฎ Firestore / Storage ของแอปเดิม

---

## ฐานข้อมูล (Supabase)

- SQL ทุกไฟล์อยู่ใน `supabase/` รันใน Supabase Dashboard → SQL Editor ไฟล์ส่วนใหญ่รันซ้ำได้ หัวไฟล์บอกลำดับที่ต้องรันก่อน
- Edge Functions อยู่ใน `supabase/functions/` (งานแอดมิน `clever-responder`, ลงเวลา `attendance-ingest` / `attendance-daily-line`, `school-bridge`)
- ตัวเชื่อมเครื่องสแกนลงเวลา: `tools/attendance-connector/` (ดู README ในโฟลเดอร์)
- สร้างบัญชี Auth ให้ครูที่ยังไม่มี: `tools/create_auth_users.mjs`

### SQL ของเว็บโรงเรียน (รันตามลำดับ)

ทุกไฟล์รันซ้ำได้ สร้างเฉพาะตารางใหม่ ไม่แตะตารางของระบบวันลา (ต้องรัน SQL ของระบบวันลามาก่อน — RLS ใช้ `can_see_school` / `is_admin` / `is_super_admin` / `current_school_id`)

| ลำดับ | ไฟล์ | ตาราง |
|---|---|---|
| 1 | `school_web_core.sql` | `AcademicYears`, `AcademicTerms`, `SchoolDepartments`, `SchoolModules` |
| 2 | `school_web_academic.sql` | `SchoolWebClassrooms`, `SchoolWebStudents`, `SchoolWebSubjects`, `SchoolWebTeachingSchedules` |
| 3 | `school_web_admin.sql` | `SchoolWebDocuments`, `SchoolWebAnnouncements` |
| 4 | `school_web_part4_permissions_finance.sql` | `SchoolWebModuleCatalog`, `SchoolWebDivisions`, `SchoolWebDivisionModules`, `SchoolWebRoleDivisionAccess`, `SchoolWebFinanceItems` + `seed_school_web_divisions()` (รวม `school_web_mapping.sql` ไว้แล้ว) |
| 5 | `school_web_appointment_orders.sql` | `SchoolWebOrders`, `SchoolWebOrderGroups`, `SchoolWebOrderMembers` |
| 6 | `school_web_appointment_orders_part2.sql` | เพิ่มคอลัมน์ `kind` / `level` / `numbered` (หัวข้อ 3 ชั้น) และ `sign_first` (ลงนามหน้าแรก) |
| 7 | `school_web_security_fix1.sql` | กันแพ็กเกจโรงเรียนใน `Permissions` (แก้ได้เฉพาะส่วนกลาง) · คำสั่งแต่งตั้งแก้ได้เฉพาะแอดมิน + บันทึกผู้สร้าง/ผู้แก้ · ข้อมูลผู้ปกครองย้ายไป `SchoolWebStudentGuardians` (แอดมิน / ครูที่ปรึกษาเท่านั้น) |
| 8 | `school_admin_leave_settings.sql` | แอดมินโรงเรียนตั้งค่า LINE / แบบฟอร์มของโรงเรียน / ลงเวลา / เครื่องสแกน ของโรงเรียนตัวเองได้ (เดิมเฉพาะส่วนกลาง) |
| 9 | `master_data_lock.sql` | F7: ข้อมูลกลางแก้ได้เฉพาะส่วนกลาง · ตารางที่มี `id_school` แอดมินแก้ได้เฉพาะโรงเรียนตัวเอง |
| 10 | `schema_migrations.sql` | F9: ตาราง `SchemaMigrations` บันทึกว่าไฟล์ไหนรันแล้ว (ใส่แถว 1–9 ให้แล้ว) |
| 11 | `school_web_division_edit.sql` | F4 + F5: ผู้ที่ได้สิทธิ์ "แก้ไข" ฝ่าย/ระบบงานบันทึกข้อมูลได้จริง (`can_edit_school_web`) · ย้าย `SchoolWebRoleDivisionAccess` เข้า `Permissions` (web เลิกใช้ตารางเก่า) |
| 12 | `school_public_web.sql` | เว็บโรงเรียนสาธารณะ: ตาราง `SchoolPublicWebConfigs` (ทุกคนอ่านได้) + `SchoolPublicWebMessages` (คนนอกส่งได้อย่างเดียว) + ระบบงาน `public-web-settings` |
| 13 | `school_web_sgs_grades.sql` | แฟ้มประวัตินักเรียน (`SchoolWebStudentProfiles` อ่านได้เฉพาะผู้มีสิทธิ์แก้ไขนักเรียน) + คะแนน SGS (`SchoolWebSgsGrades`) |
| 14 | `school_web_realtime_public.sql` | เว็บสาธารณะดึงข้อมูลจริง (โรงเรียน / บุคลากร / สถิตินักเรียน / ประกาศ) + ตรวจผลการเรียนออนไลน์ (รหัสนักเรียน + เลขบัตร 13 หลัก, จำกัดการลองผิด) |
| 15 | `school_public_web_admissions.sql` | รับสมัครนักเรียนออนไลน์ (ม.1 / ม.4) + ตรวจสถานะการสมัคร (เลขที่ใบสมัคร + เลขบัตร 13 หลัก, จำกัดการลองผิด) |
| 16 | `school_web_teacher_grades.sql` | ครูกรอกคะแนนได้เฉพาะวิชา / ห้องที่ตัวเองสอน (งานของฉัน → กรอกคะแนน) |
| 17 | `school_web_demo_setup.sql` | โรงเรียนทดลองใช้ (id 3): ตาราง `SchoolWebDemoConfig`, เมนูแอปของ "ครู" โรงเรียนทดลอง, editor ฝ่ายวิชาการแก้ข้อมูลผู้ปกครองได้ (เฉพาะโรงเรียนทดลอง) — หลังรันให้รัน `school_web_realtime_public.sql` (ข้อ 14) ซ้ำ เพื่อซ่อนรายชื่อบุคลากรโรงเรียนทดลองบนเว็บสาธารณะ |
| 18 | `school_web_demo_seed.sql` | ข้อมูลตั้งต้นของโรงเรียนทดลอง (นักเรียน 1,200 คน, ห้องเรียน, รายวิชา 87 วิชา, ตารางสอน, คะแนน SGS, ประกาศ) + `reset_demo_school_data()` — ทำงานเฉพาะโรงเรียนใน `SchoolWebDemoConfig` · รันแล้วเติมข้อมูลให้ทันที |
| 19 | `school_web_demo_signup.sql` | ระบบสมัครทดลองใช้: `SchoolWebDemoAccounts` (วันหมดอายุ), `SchoolWebDemoSignupAttempts` (จำกัด 5 ครั้ง/ชม./IP), `get_demo_school_info()` · ใช้คู่กับ Edge Function `trial-register` |
| 20 | `school_web_demo_cleanup.sql` | ลบบัญชีทดลองหมดอายุอัตโนมัติทุกวัน 03:00 น. (`cleanup_expired_demo_accounts`, ต้องเปิด pg_cron) + ปิด LINE ของโรงเรียนทดลอง |

ตั้งแต่ไฟล์ 10 เป็นต้นไป ไฟล์ SQL ใหม่ทุกไฟล์จบด้วย `insert into "SchemaMigrations"(name) values ('<ไฟล์>.sql') on conflict do nothing;` · ดูว่ารันอะไรไปแล้ว: `select * from "SchemaMigrations" order by applied_at;`

สิทธิ์ฝ่าย / Module / แพ็กเกจโรงเรียน ไม่มีตารางใหม่ — เก็บในตาราง `Permissions` เดิมด้วย `menu_id` พิเศษ

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
| app: แท็บเว็บโรงเรียน + SSO | `lib/screens/school_web_tab_screen.dart`, `lib/widgets/school_web_frame*.dart`, `lib/utils/web_platform_web.dart` |
| app: ชุดสี / ตัวอักษรกลาง | `lib/theme/` |
| web: เส้นทางทั้งหมด | `central/src/App.tsx` |
| web: เว็บโรงเรียน (ฝ่าย / Module / สิทธิ์ / คำสั่งแต่งตั้ง) | `central/src/school/` |
| web: SSO / เชื่อม Supabase | `central/src/supabase.ts` |
| web: หน้าดูแลระบบวันลา | `central/src/pages/` |
| web: แม่แบบฟอร์ม + ตัวแก้ไข | `central/src/forms/` |
| สคริปต์ส่งออกแม่แบบให้ app | `central/scripts/` |
| ฐานข้อมูล / Edge Functions | `supabase/` |
| เทส | `test/` (ชุดทดสอบจาก web อยู่ใน `test/fixtures/`) |
