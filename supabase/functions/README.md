# Edge Functions

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
