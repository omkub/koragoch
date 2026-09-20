-- ตารางเก็บรหัสยืนยันตัวตนก่อนดูรหัสผ่านของครู (2FA ผ่านไลน์)
-- รันครั้งเดียวใน Supabase SQL Editor
--
-- แนวคิด:
--   * แอดมินกดดูรหัสผ่าน -> ระบบสุ่มรหัส 6 หลัก เก็บแถวนี้ แล้วยิงเข้ากลุ่มไลน์
--   * แอดมินอ่านรหัสจากไลน์แล้วกรอกกลับ -> ตรวจกับแถวนี้ -> ผ่านถึงจะเห็นรหัสผ่าน
--   * รหัส 1 ตัวใช้ดูได้ครูคนเดียว ใช้ได้ครั้งเดียว หมดอายุใน 5 นาที
--
-- ความปลอดภัย: เปิด RLS แบบไม่มี policy เลย แปลว่า anon/authenticated
-- แตะตารางนี้ไม่ได้ทั้งอ่านและเขียน มีแต่ Edge Function (service_role) ที่เข้าถึงได้
BEGIN;

CREATE TABLE IF NOT EXISTS public."AdminViewCodes" (
    "id_code"        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "code"           text        NOT NULL,
    "requested_by"   uuid        NOT NULL,   -- auth.users.id ของแอดมินที่กดขอ
    "target_id_user" bigint      NOT NULL,   -- Teachers.id_user ของครูที่จะดู
    "expires_at"     timestamptz NOT NULL,
    "used_at"        timestamptz,
    "created_at"     timestamptz NOT NULL DEFAULT now()
);

-- ใช้ค้นตอนตรวจรหัส
CREATE INDEX IF NOT EXISTS admin_view_codes_lookup_idx
    ON public."AdminViewCodes" ("requested_by", "target_id_user", "expires_at");

ALTER TABLE public."AdminViewCodes" ENABLE ROW LEVEL SECURITY;
-- ตั้งใจไม่สร้าง policy ใด ๆ: ฝั่งเว็บจึงอ่าน/เขียนตารางนี้ไม่ได้เลย

NOTIFY pgrst, 'reload schema';
COMMIT;
