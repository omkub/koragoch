-- ============================================================================
--  ทำให้ Schools."fullName" คำนวณจาก namePart1 + namePart2 ให้อัตโนมัติ
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--
--  ทำไม: เดิมต้องแก้ 3 ช่องให้ตรงกันเอง (fullName, namePart1, namePart2)
--  ลืมช่องใดช่องหนึ่งแล้วใบลาจะแสดงชื่อไม่ตรงกันโดยไม่มีอะไรเตือน
--  เปลี่ยนเป็นคอลัมน์คำนวณ (generated column) แก้แค่สองท่อนก็พอ
--
--  ⚠️ หลังรันไฟล์นี้จะเขียนทับ "fullName" โดยตรงไม่ได้อีก (ฐานข้อมูลจะปฏิเสธ)
--     ถ้าเคยแก้ fullName ไว้เป็นค่าอื่น ค่านั้นจะหายไปและกลับมาเป็น
--     namePart1 + namePart2 แทน
-- ============================================================================

-- คอลัมน์คำนวณต้องใช้นิพจน์ที่ผลลัพธ์คงที่เสมอ (immutable) จึงใช้ || กับ case
-- แทน concat_ws ที่ Postgres ไม่ยอมให้ใช้ในคอลัมน์แบบนี้
alter table public."Schools" drop column if exists "fullName";

alter table public."Schools"
  add column "fullName" text
  generated always as (
    coalesce("namePart1", '') ||
    case
      when coalesce("namePart2", '') = '' then ''
      else ' ' || "namePart2"
    end
  ) stored;

comment on column public."Schools"."fullName" is
  'ชื่อเต็ม คำนวณจาก namePart1 + namePart2 อัตโนมัติ แก้โดยตรงไม่ได้';


-- ----------------------------------------------------------------------------
-- ตรวจผล — ชื่อเต็มต้องเท่ากับสองท่อนต่อกัน
-- ----------------------------------------------------------------------------

select
  id_school,
  "namePart1",
  "namePart2",
  "fullName",
  ("fullName" = "namePart1" || ' ' || "namePart2") as ชื่อตรงกัน
from public."Schools"
order by id_school;
