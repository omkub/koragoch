# CLAUDE.md

รายละเอียดโปรเจค วิธีรัน และวิธี deploy ดูที่ `README.md`

## คำเรียกส่วนต่างๆ ของระบบ

ใช้คำเหล่านี้ทุกครั้งที่คุย สรุป วางแผน หรือแก้งาน

| คำเรียก | คืออะไร | โค้ด |
|---|---|---|
| **web** | เว็บโรงเรียน + ส่วนดูแลระบบวันลา (React + TypeScript + Vite) เสิร์ฟที่ `/central/` | `central/` |
| ├ **web โรงเรียน** | ฝ่าย 4 ฝ่าย → Module ย่อย (`/`, `/division/:divisionKey/:moduleKey`) | `central/src/school/` |
| └ **web ดูแลระบบ** | ตั้งค่าระบบวันลา / โรงเรียน / สิทธิ์ (`/leave-admin`, `/schools`, `/forms`, `/admin/*` …) | `central/src/pages/` |
| **app** | แอป Flutter ระบบวันลา (build เป็นเว็บ) | `lib/` |
| ├ **app PC** | จอกว้าง ≥ 1100px → `MainLayout` | `lib/screens/main_layout.dart` + หน้าจอใน `lib/screens/` |
| └ **app มือถือ** | จอแคบกว่า 1100px | — |
| &nbsp;&nbsp;&nbsp;• แบบใหม่ | `MobileShell` (ค่าเริ่มต้น) | `lib/screens/mobile_v2/` |
| &nbsp;&nbsp;&nbsp;• แบบเดิม | `MobileMainLayout` (โรงเรียนเลือกได้ — `SchoolInfo.useOldMobileUi`) | `lib/screens/mobile/` |

- ตัวเลือกหน้าจอ PC / มือถือ อยู่ที่ `lib/screens/responsive_layout.dart`
- โฟลเดอร์ `web/` ที่ root เป็นไฟล์ประกอบของ Flutter (`index.html`, ไอคอน) **ไม่ใช่** "web"
- `school-web/` (เว็บโรงเรียนแยกที่ `/school/`) **เลิกใช้แล้ว** — รวมเข้า `central/src/school/` ตั้งแต่ commit `20d67d8`
- ถ้าสั่งงาน "app" โดยไม่ระบุ และงานกระทบหน้าจอ ให้ระบุให้ชัดว่าแก้ app PC, app มือถือ (แบบใหม่ / แบบเดิม) หรือทั้งหมด

## web โรงเรียน: โรงเรียน → ฝ่าย → Module

- ฝ่ายเริ่มต้น 4 ฝ่าย (`division_key`): `hr` บุคคล · `academic` วิชาการ · `admin` บริหารทั่วไป · `finance` งบประมาณ
  ตาราง `SchoolWebDivisions` (ต่อโรงเรียน) + `SchoolWebDivisionModules` (Module ในฝ่าย) + `SchoolWebModuleCatalog` (ทะเบียน Module กลาง)
  นิยามฝั่งโค้ด + ค่าสำรองเมื่อยังไม่มีตาราง: `central/src/school/mapping.ts` (`FALLBACK_CATALOG`)
- Module มาตรฐาน (`module_key`): `leave-system`, `staff-registry`, `departments` (hr) · `students-classrooms`, `curriculum-schedule` (academic) · `documents`, `announcements` (admin) · `finance-budget` (finance) · `appointment-orders` (ทุกฝ่าย)
- เพิ่ม Module ใหม่: เพิ่มใน `FALLBACK_CATALOG` + แถวใน `SchoolWebModuleCatalog` (SQL) + หน้าใน `central/src/school/` + ผูกเส้นทางใน `central/src/App.tsx`
- โครงหน้า (เมนูฝ่าย / Module): `central/src/school/UnifiedShell.tsx`

## สิทธิ์ 4 ระดับ (web โรงเรียน)

นิยามที่ `central/src/school/staffDivisionMapping.ts` (`SchoolRoleTier`)

| ระดับ | เห็นอะไร |
|---|---|
| `user` ผู้ใช้งาน | เฉพาะฝ่ายที่ตัวเองสังกัด และ Module ในฝ่ายนั้น |
| `executive` ผู้บริหาร | ทุกฝ่ายในโรงเรียน (ดูรายงาน / อนุมัติ) |
| `school_admin` Admin โรงเรียน | ทุกฝ่าย ทุก Module ในโรงเรียนตัวเอง + จัดการได้ |
| `super_admin` | ทุกโรงเรียน + กำหนดเพดานสิทธิ์ระดับโรงเรียน |

- สังกัดฝ่ายของบุคลากร (บุคลากร ↔ ฝ่าย ↔ Module): หน้า `/admin/mapping` (`DivisionMappingPage.tsx`)
- สิทธิ์ฝ่าย / Module / แท็บ "เว็บโรงเรียน" ตามบทบาท + รายบุคคล: `/admin/division-permissions`, `/user-permissions` — โค้ด `roleModulePermissions.ts`
- เพดานระดับโรงเรียน (แพ็กเกจ + Module ที่อนุญาต) โดย Super Admin: `schoolPackage.ts`
- สิทธิ์ "แก้ไข" ฝ่าย / ระบบงาน บังคับในฐานข้อมูลด้วย `can_edit_school_web(id_school, division_key, module_key)` (`supabase/school_web_division_edit.sql`) — แก้ลำดับตัดสินสิทธิ์ใน web ต้องแก้ฟังก์ชันนี้ให้ตรงกันด้วย
- ตาราง `SchoolWebRoleDivisionAccess` เลิกใช้แล้ว (ย้ายเข้า `Permissions`)
- **ไม่มีตารางสิทธิ์ใหม่** — สิทธิ์ทั้งหมดเก็บในตาราง `Permissions` เดิม `(id_school, id_role, menu_id, status)` ด้วย `menu_id` พิเศษ (ดูค่าคงที่ใน `schoolPackage.ts` / `roleModulePermissions.ts`) เพื่อผ่าน RLS เดิมได้ทันที ห้ามใช้ `menu_id` ชนกับเมนูของ app
- ตัวกันสิทธิ์จริงคือ RLS ในฐานข้อมูล ฝั่งเว็บแค่ซ่อนเมนู

## SSO ระหว่าง app ↔ web (2 ทาง)

ทั้งสองอยู่โดเมนเดียวกัน (`rbp-chanikarnn.web.app` และ `/central/`) ใช้ Supabase Auth ชุดเดียวกัน
- **app → web**: app PC มีแท็บ "เว็บโรงเรียน" (`lib/screens/school_web_tab_screen.dart`) ฝัง `/central/` (`lib/widgets/school_web_frame*.dart`) และส่ง `sso_access_token` / `sso_refresh_token` ทาง URL hash (`lib/utils/web_platform_web.dart`) — web รับที่ `hydrateSsoSession()` ใน `central/src/supabase.ts`
- **web → app**: app อ่าน `sso_refresh_token` จาก URL หรือ session ของ web ใน localStorage (`consumeIncomingSsoRefreshToken()`) แล้ว `setSession` ใน `lib/main.dart` และเติมข้อมูลผู้ใช้ลง SharedPreferences
- การเห็นแท็บ "เว็บโรงเรียน" ใน app คุมด้วยสิทธิ์เมนู `6` / `เว็บโรงเรียน`
- แก้ชื่อ key ของ token ต้องแก้ทั้งสองฝั่งพร้อมกัน

## คำสั่งแต่งตั้ง (Module `appointment-orders`)

- หน้า 2 ฝั่ง: ฟอร์มซ้าย + ตัวอย่าง A4 ขวา (`AppointmentOrdersPage.tsx`, `OrderWordPreviewPane.tsx`)
- ข้อมูล: `appointmentOrders.ts` → ตาราง `SchoolWebOrders`, `SchoolWebOrderGroups`, `SchoolWebOrderMembers`
- หัวข้อ 3 ชนิด (`kind`): `section` หัวข้อกลุ่ม · `committee` คณะ/งาน + ตาราง · `person` รายบุคคล · ชั้น `level` 1 = ๖. 2 = ๖.๑ · เลขข้อคำนวณที่ `computeHeadingLabels()` ที่เดียว (นับใหม่ทุกหัวข้อกลุ่ม) · `sign_first` = ลงนามหน้าแรก + แนบท้าย
- รูปแบบอ้างอิง: ไฟล์ต้นฉบับคำสั่งแต่งตั้งของโรงเรียน (ตาราง 4 คอลัมน์ ลำดับ | ชื่อ | ตำแหน่ง | หน้าที่ในคณะ, หน้าที่ในคณะใช้คำว่า "กรรมการ")
- ส่งออก .docx สร้างเองในเบราว์เซอร์ (ZIP + OpenXML, ฝังตราครุฑ, ตัวเลขไทย/อารบิกต่อส่วน): `exportOrderDocx.ts`

## ฐานข้อมูลของ web โรงเรียน

SQL อยู่ใน `supabase/school_web_*.sql` (รันซ้ำได้ · สร้างตารางใหม่ขึ้นต้น `SchoolWeb…` ไม่แตะตารางของระบบวันลา · RLS ใช้ `can_see_school` / `is_admin` / `is_super_admin` / `current_school_id` ที่มีอยู่แล้ว) ลำดับรันอยู่ใน `README.md`

## ดีไซน์

ชุดสี / ตัวอักษรกลางของ app อยู่ที่ `lib/theme/app_tokens.dart` (สีหลักน้ำเงินกรมท่า `#1E3A8A`, Sarabun, สถานะเป็นตรายาง `StatusStamp`) — web ใช้ชุดเดียวกันใน `central/tailwind.config.js` (`brand`) ห้ามเพิ่มสี hex เองในหน้าจอ

**ข้อยกเว้น: หน้าเว็บสาธารณะ** (`/public`, `PublicSchoolWebPage.tsx`) ใช้ชุดสี / ฟอนต์ตามแบบ `webschool.html` (สี `surface-*` `primary-*` `secondary-*` ฯลฯ ใน `tailwind.config.js`, ฟอนต์ Noto Sans Thai / Prompt, ไอคอน Material Symbols) ใช้ได้เฉพาะหน้านี้ หน้าอื่นของ web ยังใช้ `brand` + Sarabun

## เว็บสาธารณะ (`/public`)

- ข้อมูลหน้าเว็บ: `SchoolPublicWebConfigs` (jsonb แถวเดียวต่อโรงเรียน, **ทุกคนอ่านได้** — ห้ามใส่ข้อมูลส่วนตัว) · ข้อความติดต่อ: `SchoolPublicWebMessages` (anon insert ได้อย่างเดียว) · โค้ด `publicWebConfig.ts`
- สิทธิ์ตั้งค่า: `can_manage_public_school_web` (`supabase/school_public_web.sql`) ↔ `canUserManagePublicSchoolWeb` ใน `roleModulePermissions.ts` — แก้ที่หนึ่งต้องแก้อีกที่
