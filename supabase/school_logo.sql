-- ============================================================================
--  โลโก้โรงเรียน — ตั้งที่เว็บส่วนกลาง > โรงเรียน > แก้ไข
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--
--  Schools.logo = รูปแบบ data URL (data:image/png;base64,...) แบบเดียวกับ
--  รูปโปรไฟล์ครู เว็บย่อรูปเหลือไม่เกิน 256×256 ก่อนบันทึก (~20–80 KB)
--  ว่าง = ไม่มีโลโก้ (แอปแสดงไอคอนกลางแทน)
--
--  แอป: หลังล็อกอินใช้โลโก้ของโรงเรียนผู้ใช้ และจำไว้ในเครื่อง — เปิดแอป
--  ครั้งถัดไป (ติ๊ก "จำการเข้าระบบ" ไว้) หน้าล็อกอินขึ้นโลโก้โรงเรียนตัวเองเลย
-- ============================================================================

alter table public."Schools"
  add column if not exists logo text;

-- กันรูปใหญ่เกิน (ฐานข้อมูล + ที่เก็บในเครื่องของผู้ใช้) — ~375 KB หลัง base64
alter table public."Schools"
  drop constraint if exists schools_logo_check;
alter table public."Schools"
  add constraint schools_logo_check
  check (logo is null or (logo like 'data:image/%' and length(logo) <= 500000));

comment on column public."Schools".logo is
  'โลโก้โรงเรียน (data URL ไม่เกิน 256×256) — ว่าง = ไม่มีโลโก้';


-- ตรวจผล
select id_school, "fullName", (logo is not null) as มีโลโก้, length(logo) as ขนาด
from public."Schools"
order by id_school;
