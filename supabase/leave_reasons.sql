-- ตารางเหตุผลการลา (master) สำหรับให้เลือกในฟอร์มใบลา
-- รันครั้งเดียวใน Supabase SQL Editor
--
-- แนวคิด:
--   * Leaves.reason ยังเป็น text อิสระเหมือนเดิม ไม่ผูก FK
--     ครูจึงพิมพ์เหตุผลนอกรายการได้ และข้อมูลเก่า 158 ใบไม่ต้อง migrate
--   * ตารางนี้ทำหน้าที่เป็น "ตัวเลือกด่วน" อย่างเดียว
--   * ตั้ง PK เป็น identity GENERATED ALWAYS ให้เหมือน LeaveTypes
BEGIN;

CREATE TABLE IF NOT EXISTS public."LeaveReasons" (
    "id_leaveReason" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "reasonName"     text NOT NULL UNIQUE,
    "createdAt"      timestamptz DEFAULT now(),
    "updatedAt"      timestamptz DEFAULT now()
);

-- เหตุผลตั้งต้น คัดจากที่ใช้บ่อยที่สุดในข้อมูลจริง
INSERT INTO public."LeaveReasons" ("reasonName")
VALUES
    ('ทำธุระส่วนตัว'),
    ('ทำธุระต่างจังหวัด'),
    ('พบแพทย์ตามนัด'),
    ('เป็นไข้'),
    ('เป็นไข้หวัด'),
    ('ปวดศีรษะ'),
    ('ปวดท้อง'),
    ('ติดโควิด-19'),
    ('ร่วมงานศพ'),
    ('ลาไปโรงพยาบาล')
ON CONFLICT ("reasonName") DO NOTHING;

-- ให้ PostgREST มองเห็นตารางใหม่ทันที
NOTIFY pgrst, 'reload schema';

COMMIT;
