# SchoolLeaveApp (โปรแกรมระบบลาโรงเรียน)

แอป Flutter (web) สำหรับจัดการการลาของบุคลากร ใช้ **Firebase Firestore** (database `school`) เป็นฐานข้อมูลหลักในการแสดงผล และมีระบบ **นำเข้าข้อมูลไป Supabase** (dual-write + migration)

- Firebase project: `rbp-chanikarnn` · Firestore database: `school`
- Repo: https://github.com/omkub/koragoch
- Release ล่าสุด: ดูที่แท็บ [Releases](https://github.com/omkub/koragoch/releases)

---

## เริ่มใช้งานบนเครื่องใหม่

เครื่องใหม่สามารถ clone จาก GitHub แล้วรัน/แก้ไขต่อได้เหมือนเครื่องเดิม เมื่อ push ไปที่ `main` GitHub Actions จะ build และ deploy GitHub Pages อัตโนมัติ

- เว็บไซต์: https://omkub.github.io/koragoch/
- ตรวจสถานะ deploy: https://github.com/omkub/koragoch/actions
- เวอร์ชันปัจจุบัน: `26.9.17+4`

### 1) ติดตั้งของที่ต้องมี
- [Git](https://git-scm.com/download/win)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
- Google Chrome (สำหรับรัน web)
- (ถ้าจะ push กลับ) [GitHub CLI](https://cli.github.com/) — `gh`

ตรวจว่า Flutter พร้อมใช้งาน:
```bash
flutter doctor
```

ถ้าต้องการแก้โค้ดแล้ว push กลับ GitHub ให้ล็อกอินครั้งแรกบนเครื่องใหม่:
```bash
gh auth login
```

เลือก `GitHub.com` → `HTTPS` → เปิด browser เพื่อล็อกอิน

### 2) Clone โปรเจกต์จาก GitHub
```bash
git clone https://github.com/omkub/koragoch.git SchoolLeaveApp
cd SchoolLeaveApp
```

### 3) ติดตั้ง dependency
```bash
flutter pub get
npm install        # ถ้ามีการใช้สคริปต์ Node (package.json)
```

### 4) รันแอป
```bash
flutter run -d chrome
```

> config สำคัญ (`lib/firebase_options.dart`, Supabase anon key ใน `lib/main.dart`, `firebase.json`, `firestore.rules`) อยู่ใน repo แล้ว เครื่องใหม่ใช้ได้เลยไม่ต้องตั้งค่าเพิ่ม
> ไฟล์ที่ถูก `.gitignore` (`node_modules/`, `build/`, `.dart_tool/`) จะถูกสร้างใหม่อัตโนมัติจากขั้นตอนด้านบน

### 5) แก้โค้ดแล้วอัพกลับ GitHub
```bash
git status
git add -A
git commit -m "อธิบายสิ่งที่แก้"
git push origin main
```

ถ้าเครื่องใหม่แก้ต่อจากงานเดิม ให้ดึงโค้ดล่าสุดก่อนเริ่มทุกครั้ง:
```bash
git pull origin main
flutter pub get
```

---

## ทำงานหลายเครื่อง

```bash
# ก่อนเริ่มงานทุกครั้ง — ดึงล่าสุดก่อน
git pull
flutter pub get

# ทำเสร็จ — commit แล้ว push
git add -A
git commit -m "อธิบายสิ่งที่แก้"
git push
```

ครั้งแรกบนเครื่องใหม่ ถ้ายังไม่ได้ล็อกอิน GitHub:
```bash
gh auth login        # เลือก GitHub.com → HTTPS → web browser
```

---

## การนำเข้าข้อมูล Firebase → Supabase

เข้าเมนู **จัดการผู้ใช้ → แท็บ "นำเข้าข้อมูล"** (ต้องล็อกอินเป็นผู้ดูแลระบบ)

- **Firebase อ่านอย่างเดียว** — การนำเข้าไม่แก้/ลบข้อมูล Firebase
- ปุ่ม **"ล้างข้อมูล"** ล้างเฉพาะตารางฝั่ง **Supabase**
- ลำดับนำเข้า (master → Teachers → dependent) ถูกจัดให้อัตโนมัติ
- SQL helper อยู่ในโฟลเดอร์ `supabase/` (รันใน Supabase SQL Editor เมื่อต้องปรับ schema)

> ชื่อคอลัมน์ฝั่งโค้ดยึดตามที่มีจริงใน Supabase เช่น `roles.Accessrights`, `appconfig."Key AppTitle"`

---

## การออกเวอร์ชัน (Release)

ใช้เลขเวอร์ชันแบบวันที่พร้อม build number `YY.M.D+N` (เช่น `26.9.17+4`) ใน `pubspec.yaml` และใช้ tag `YY.M.D.N` (เช่น `26.9.17.4`) สำหรับ release แต่ละครั้ง

```bash
git add -A
git commit -m "Release <version>: ..."
git push origin main
git tag -a <version> -m "Release <version>"
git push origin <version>
gh release create <version> --title <version> --notes-file RELEASE_NOTES_<version>.md
```

---

## โครงสร้างหลัก

| ส่วน | ไฟล์ |
|---|---|
| Entry / init Firebase+Supabase | `lib/main.dart` |
| บริการ Firebase + dual-write | `lib/services/firebase_service.dart` |
| นำเข้า/ย้ายข้อมูล | `lib/services/migration_service.dart`, `lib/services/import_service.dart`, `lib/services/mobile_permission_migration.dart` |
| หน้าจอ | `lib/screens/` (login, dashboard, personnel, leave_form, leave_history, user_management, ...) |
| SQL helper ฝั่ง Supabase | `supabase/*.sql` |
