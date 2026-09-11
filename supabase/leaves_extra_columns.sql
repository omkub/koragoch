-- เพิ่มคอลัมน์รองรับหน้าส่งใบลา (leave_form) เวอร์ชัน Supabase
-- รันครั้งเดียวใน Supabase SQL Editor ก่อนใช้งาน
--
-- แนวคิด:
--   * department / position ดึงจาก id_user ได้อยู่แล้ว (id_department/id_position -> master) จึงไม่เพิ่ม
--   * phone / academicStanding เป็นคุณสมบัติของครูแต่ละคน แต่ Supabase Teachers ยังไม่มี -> เพิ่มที่ Teachers
--   * isHalfDay / halfDayPeriod เป็นข้อมูลเฉพาะใบลา -> เพิ่มที่ Leaves
BEGIN;

-- ข้อมูลประจำตัวครู (ดึงผ่าน id_user)
ALTER TABLE public."Teachers"
    ADD COLUMN IF NOT EXISTS "phone" text,
    ADD COLUMN IF NOT EXISTS "academicStanding" text;

-- ข้อมูลเฉพาะใบลา
ALTER TABLE public."Leaves"
    ADD COLUMN IF NOT EXISTS "isHalfDay" boolean DEFAULT false,
    ADD COLUMN IF NOT EXISTS "halfDayPeriod" text;

-- ให้ totalDays เก็บทศนิยมได้ (เช่น 0.5 สำหรับลาครึ่งวัน)
-- ถ้าของเดิมเป็น numeric(_,2) อยู่แล้ว คำสั่งนี้ไม่กระทบข้อมูล
ALTER TABLE public."Leaves"
    ALTER COLUMN "totalDays" TYPE numeric(6, 2) USING "totalDays"::numeric;

-- ให้ PostgREST รีโหลด schema เพื่อให้ REST API มองเห็นคอลัมน์ใหม่ทันที
NOTIFY pgrst, 'reload schema';

COMMIT;
