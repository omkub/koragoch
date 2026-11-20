-- ============================================================================
--  School Web — คำสั่งแต่งตั้ง พาร์ท 2: โครงสร้าง 3 ชั้น + ลงนามหน้าแรก
--
--  ต้องรัน supabase/school_web_appointment_orders.sql ก่อน
--  รันซ้ำได้ (Idempotent) · เพิ่มคอลัมน์อย่างเดียว ข้อมูลเดิมใช้ค่าเริ่มต้นได้ทันที
--
--  SchoolWebOrderGroups
--    kind      : 'section'   หัวข้อกลุ่ม (กลุ่มบริหารวิชาการ) — กึ่งกลาง ไม่มีเลข เริ่มนับข้อใหม่
--                'committee' คณะ/งาน + ตารางรายชื่อ + ให้มีหน้าที่ (ค่าเดิมของทุกแถว)
--                'person'    รายบุคคล ชื่อ ⇥ ตำแหน่ง + หน้าที่ (ไม่มีตาราง)
--    level     : 1 = ข้อหลัก (๖.)  2 = ข้อย่อย (๖.๑)
--    numbered  : แสดงเลขข้อหรือไม่
--  SchoolWebOrders
--    sign_first: ลงนามหน้าแรก แล้วตามด้วยรายละเอียดแนบท้าย
-- ============================================================================

alter table public."SchoolWebOrderGroups"
  add column if not exists kind text not null default 'committee';

alter table public."SchoolWebOrderGroups"
  add column if not exists level smallint not null default 1;

alter table public."SchoolWebOrderGroups"
  add column if not exists numbered boolean not null default true;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'school_web_order_groups_kind_check'
  ) then
    alter table public."SchoolWebOrderGroups"
      add constraint school_web_order_groups_kind_check
      check (kind in ('section', 'committee', 'person'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'school_web_order_groups_level_check'
  ) then
    alter table public."SchoolWebOrderGroups"
      add constraint school_web_order_groups_level_check
      check (level in (1, 2));
  end if;
end $$;

alter table public."SchoolWebOrders"
  add column if not exists sign_first boolean not null default false;
