-- ============================================================================
--  หน้าจอมือถือของแต่ละโรงเรียน — แบบใหม่ (new) หรือแบบเดิม (old)
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง ต้องรัน super_admin.sql มาก่อนแล้ว
--
--  สิ่งที่ทำ:
--    1) คอลัมน์ Schools.mobile_ui ค่าเริ่มต้น 'new' (ทุกโรงเรียนเดิม + โรงเรียนใหม่)
--    2) เปลี่ยนค่าได้เฉพาะผู้ดูแลส่วนกลาง — แอดมินโรงเรียนแก้แถว Schools
--       ของตัวเองได้ (policy schools_update) จึงต้องกันด้วย trigger
--
--  ตั้งค่าที่เว็บส่วนกลาง > โรงเรียน > แก้ไข > หน้าจอมือถือ
--  แอปอ่านค่าตอนเปิดแอป/ล็อกอิน — เปลี่ยนแล้วมีผลเมื่อเปิดแอปครั้งถัดไป
--  ก่อนรันไฟล์นี้ แอปใช้แบบใหม่ทุกโรงเรียน (ไม่มีคอลัมน์ = แบบใหม่)
--  ตั้งรายสิทธิ์: รัน school_mobile_ui_by_role.sql ต่อ (ถ้ารันไฟล์นี้ซ้ำทีหลัง
--  ต้องรันไฟล์นั้นซ้ำด้วย เพราะฟังก์ชันกันสิทธิ์ในไฟล์นั้นครอบคลุมกว่า)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) คอลัมน์
-- ----------------------------------------------------------------------------

alter table public."Schools"
  add column if not exists mobile_ui text not null default 'new';

alter table public."Schools"
  drop constraint if exists schools_mobile_ui_check;
alter table public."Schools"
  add constraint schools_mobile_ui_check check (mobile_ui in ('new', 'old'));

comment on column public."Schools".mobile_ui is
  'หน้าจอแอปบนมือถือ: new = แบบแอป (แถบล่าง 4 ปุ่ม), old = แบบเดิม (แถบล่าง 9 ปุ่ม) — แก้ได้เฉพาะผู้ดูแลส่วนกลาง';


-- ----------------------------------------------------------------------------
-- 2) กันแอดมินโรงเรียนเปลี่ยนค่าเอง
--    SQL Editor (ไม่มีผู้ล็อกอิน) เปลี่ยนได้เสมอ
-- ----------------------------------------------------------------------------

create or replace function public.guard_school_mobile_ui()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.is_super_admin()
     and (
       (tg_op = 'INSERT' and new.mobile_ui <> 'new')
       or (tg_op = 'UPDATE' and new.mobile_ui is distinct from old.mobile_ui)
     ) then
    raise exception 'เปลี่ยนหน้าจอมือถือได้เฉพาะผู้ดูแลระบบส่วนกลาง';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_school_mobile_ui on public."Schools";
create trigger guard_school_mobile_ui
  before insert or update on public."Schools"
  for each row execute function public.guard_school_mobile_ui();


-- ----------------------------------------------------------------------------
-- 3) ตรวจผล — ทุกแถวต้องมี mobile_ui (new หลังรันครั้งแรก)
-- ----------------------------------------------------------------------------

select id_school, "fullName", mobile_ui
from public."Schools"
order by id_school;
