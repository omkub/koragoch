-- ============================================================================
--  โลโก้โรงเรียน: เก็บไฟล์ที่ Google Drive (โฟลเดอร์ LogoRPB) ฐานข้อมูลเก็บแค่ลิงก์
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง ต้องรัน school_logo.sql มาก่อนแล้ว
--
--  เดิม Schools.logo เก็บรูปทั้งก้อน (data URL) — ตอนนี้เว็บส่วนกลางอัปโหลดรูป
--  ผ่าน school-bridge → Apps Script ไปไว้ใน Drive บัญชีเดียวกับใบรับรองแพทย์ /
--  รูปโปรไฟล์ แล้วเก็บเฉพาะลิงก์ (https://drive.google.com/...)
--  ยังรับ data URL ได้เหมือนเดิม (เผื่อมีค่าเก่าค้าง)
-- ============================================================================

alter table public."Schools"
  drop constraint if exists schools_logo_check;
alter table public."Schools"
  add constraint schools_logo_check
  check (
    logo is null
    or (logo like 'https://%' and length(logo) <= 2000)
    or (logo like 'data:image/%' and length(logo) <= 500000)
  );

comment on column public."Schools".logo is
  'ลิงก์โลโก้โรงเรียนใน Google Drive (โฟลเดอร์ LogoRPB) — ว่าง = ไม่มีโลโก้';

select id_school, "fullName", left(logo, 60) as โลโก้
from public."Schools"
order by id_school;
