# Edge Functions

## school-bridge

ตัวกลางไป Google Apps Script (แจ้งเตือน LINE / อัปโหลด-ลบไฟล์ Google Drive)
`secretKey` ของ Apps Script อยู่ในตาราง `AppSecrets` ซึ่งอ่านได้เฉพาะฟังก์ชันนี้
แอปไม่เคยเห็นค่าลับ (ดู `supabase/settings_secrets.sql`)

| คำสั่ง | ใครเรียกได้ |
|---|---|
| `notify_new_leave` | เจ้าของใบลา / ผู้ดูแลระบบ — ส่งเข้ากลุ่มของโรงเรียนนั้น (SchoolLineSettings) ส่งได้ครั้งเดียวต่อใบ |
| `drive_upload` | ทุกคนที่ล็อกอิน (โฟลเดอร์กำหนดฝั่งเซิร์ฟเวอร์) |
| `drive_delete` | ผู้ดูแลระบบ หรือคนที่อัปโหลดไฟล์นั้นเอง |
| `line_test`, `line_latest_id` | ผู้ดูแลระบบส่วนกลาง |

```bash
npx supabase functions deploy school-bridge --project-ref uziajblqlbrvqmxvizsi
```

---

## admin-users

งานที่ต้องใช้สิทธิ์ระดับแอดมินของ Supabase Auth ซึ่งเรียกจากเว็บตรง ๆ ไม่ได้
เพราะต้องใช้ `service_role` key ที่ห้ามฝังในโค้ดฝั่งผู้ใช้

| คำสั่ง | ทำอะไร |
|---|---|
| `create_auth` | สร้างบัญชี Auth ให้ครูที่มีแถวใน `Teachers` แล้ว (ใช้ตอนเพิ่มผู้ใช้ใหม่) |
| `reset_password` | ตั้งรหัสผ่านใหม่ให้ครูคนอื่น (ใช้ตอนครูลืมรหัส) |

ฟังก์ชันตรวจ token ของผู้เรียกทุกครั้ง และอนุญาตเฉพาะผู้ที่มีสิทธิ์
**ผู้ดูแลระบบ** ในตาราง `Teachers` เท่านั้น

---

## attendance-ingest

จุดรับเวลาสแกนจากเครื่องสแกนหน้า เข้าตาราง `AttendanceLogs` (ดู `supabase/attendance.sql`)
เครื่องยืนยันตัวด้วย **รหัสลับเครื่อง** ที่ออกจาก web (หน้า ลงเวลา > เครื่องสแกน)

> ⚠️ ต้องปิด **Enforce JWT verification** (เครื่องสแกนไม่มี token ของ Supabase)
> ถ้าเปิดไว้ทุกคำขอจะได้ `401` ก่อนถึงโค้ด

```bash
npx supabase functions deploy attendance-ingest --no-verify-jwt --project-ref uziajblqlbrvqmxvizsi
```

ทดสอบหลัง deploy (ใช้รหัสจริงที่ออกจาก web):

```bash
curl -H "x-device-key: <รหัสลับเครื่อง>" https://uziajblqlbrvqmxvizsi.supabase.co/functions/v1/attendance-ingest
```

ส่งข้อมูล:

```bash
curl -X POST -H "x-device-key: <รหัสลับเครื่อง>" -H "content-type: application/json" -d "{\"logs\":[{\"code\":\"1001\",\"time\":\"2026-10-09 07:45:12\"}]}" https://uziajblqlbrvqmxvizsi.supabase.co/functions/v1/attendance-ingest
```

| เรื่อง | รายละเอียด |
|---|---|
| รูปแบบข้อมูล | `{ logs: [{ code, time }] }` — เวลาไม่มีโซน = เวลาไทย, ครั้งละไม่เกิน 2,000 แถว |
| ส่งซ้ำ | ได้ ไม่บันทึกเบิ้ล |
| รหัสที่ยังไม่จับคู่กับครู | เก็บไว้ก่อน ผูกให้อัตโนมัติเมื่อใส่รหัสให้ครูที่ web |
| เครื่องที่ปิดใช้งานที่ web | ตอบ `403` ไม่รับข้อมูล |

---

## attendance-daily-line

ส่งสรุปลงเวลาประจำวันเข้ากลุ่ม LINE ของแต่ละโรงเรียน เช่น "มา 45 · สาย 3 · ลา 2 · ไปราชการ 1 · ยังไม่สแกน 4"
พร้อมรายชื่อคนสายและคนที่ยังไม่สแกน ตั้งค่าต่อโรงเรียนที่ web > ลงเวลา > สรุปประจำวันทาง LINE

> ⚠️ ต้องปิด **Enforce JWT verification** เพราะ pg_cron ไม่มี token ผู้ใช้ ฟังก์ชันตรวจสิทธิ์เองในโค้ด

```bash
npx supabase functions deploy attendance-daily-line --no-verify-jwt --project-ref uziajblqlbrvqmxvizsi
```

| เรียกจาก | ยืนยันตัวด้วย | ทำอะไร |
|---|---|---|
| pg_cron ทุก 10 นาที (`supabase/attendance_line_cron.sql`) | header `x-cron-secret` = `AppSecrets.attendance_cron_secret` | ส่งให้โรงเรียนที่ถึงเวลา วันละครั้ง เฉพาะวันทำการ |
| ปุ่ม "ทดลองส่งสรุปวันนี้" ที่ web | token ของผู้ดูแลส่วนกลาง | ส่งทันที ไม่นับเป็นการส่งประจำวัน |

ใช้ Apps Script / กลุ่ม LINE ตัวเดียวกับ `school-bridge` (`SchoolLineSettings`)

---

## วิธี deploy (ไม่ต้องติดตั้งอะไรเพิ่ม)

ทำผ่านหน้าเว็บของ Supabase ได้เลย

1. เปิด **Supabase Dashboard** → เมนูซ้าย **Edge Functions**
2. กด **Deploy a new function** → เลือก **Via Editor**
3. ตั้งชื่อฟังก์ชันว่า **`admin-users`** (ต้องตรงตัว)
4. ลบโค้ดตัวอย่างทิ้งทั้งหมด แล้ววางเนื้อหาจากไฟล์
   `supabase/functions/admin-users/index.ts` ลงไปแทน
5. กด **Deploy**

> `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
> Supabase ใส่ให้อัตโนมัติอยู่แล้ว **ไม่ต้องตั้งค่าเพิ่ม**

---

## วิธี deploy ด้วย CLI (ถ้าสะดวกกว่า)

```bash
npm install -g supabase
supabase login
supabase link --project-ref uziajblqlbrvqmxvizsi
supabase functions deploy admin-users
```

---

## ตรวจว่า deploy สำเร็จ

ในหน้า Edge Functions ต้องเห็นฟังก์ชัน `admin-users` สถานะ **Active**

ถ้าเรียกโดยไม่ได้ล็อกอินจะตอบ `401` และถ้าเรียกด้วยบัญชีที่ไม่ใช่ผู้ดูแลระบบ
จะตอบ `403` ซึ่งเป็นพฤติกรรมที่ถูกต้อง
