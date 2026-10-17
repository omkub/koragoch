-- ============================================================================
--  สถานะบุคลากร: ปฏิบัติงาน / ลาออก / เกษียณ / ย้าย
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง ต้องรัน admin_role_by_id.sql และ multi_school_step3_rls.sql
--  มาก่อนแล้ว
--
--  หลักการ: ไม่ลบรายชื่อ (ใบลาเก่าเป็นเอกสารราชการ) แต่ตั้งสถานะ + วันที่พ้นสภาพ
--    employment_status  active | resigned | retired | transferred  (ค่าเริ่มต้น active)
--    left_date          พ้นสภาพตั้งแต่วันที่ (วันแรกที่ไม่ได้ปฏิบัติงาน เช่น เกษียณ 1 ต.ค.)
--
--  สิ่งที่ทำ:
--    1) คอลัมน์ใหม่ใน Teachers — ทุกคนที่มีอยู่เป็น active (ไม่มีใครถูกกระทบ)
--    2) คนที่พ้นสภาพ "ใช้ระบบไม่ได้" แม้ session ยังค้าง: ฟังก์ชันที่ RLS ใช้
--       ตัดสินตัวตน (current_teacher_id / current_school_id / is_admin /
--       is_approver / is_super_admin) นับเฉพาะคนที่ active
--    3) เปลี่ยนสถานะได้เฉพาะผู้ดูแลระบบ (แอดมินโรงเรียน / ส่วนกลาง) —
--       policy ให้ครูแก้แถวตัวเองได้ (เปลี่ยนรหัส/รูป) จึงต้องกันด้วย trigger
--    4) my_employment_status() ให้หน้าล็อกอินบอกได้ว่า "บัญชีนี้พ้นสภาพแล้ว"
--
--  ⚠️ ถ้ารัน enable_rls.sql / multi_school_step1_id_school.sql /
--     admin_role_by_id.sql ซ้ำทีหลัง ต้องรันไฟล์นี้ซ้ำด้วย (ไฟล์เหล่านั้น
--     สร้างฟังก์ชันชุดเดียวกันแบบไม่ดูสถานะ)
--  ⚠️ แอดมินอย่าตั้งตัวเองเป็นพ้นสภาพ — จะเข้าระบบไม่ได้ทันที
--     (แก้คืนได้จาก SQL Editor หรือให้แอดมินคนอื่น/ส่วนกลางคืนสถานะให้)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) คอลัมน์
-- ----------------------------------------------------------------------------

alter table public."Teachers"
  add column if not exists employment_status text not null default 'active';

alter table public."Teachers"
  add column if not exists left_date date;

alter table public."Teachers"
  drop constraint if exists teachers_employment_status_check;
alter table public."Teachers"
  add constraint teachers_employment_status_check
  check (employment_status in ('active', 'resigned', 'retired', 'transferred'));

comment on column public."Teachers".employment_status is
  'สถานะบุคลากร: active ปฏิบัติงาน, resigned ลาออก, retired เกษียณ, transferred ย้าย';
comment on column public."Teachers".left_date is
  'พ้นสภาพตั้งแต่วันที่ (วันแรกที่ไม่ได้ปฏิบัติงาน) — รายงานปีงบประมาณที่เริ่มวันนี้หรือหลังจากนี้จะไม่นับคนนี้';


-- ----------------------------------------------------------------------------
-- 2) ตัวตนใน RLS นับเฉพาะคนที่ยังปฏิบัติงาน
--    เงื่อนไขเดิมคงไว้ทุกตัว (ดู enable_rls.sql, multi_school_step1_id_school.sql,
--    admin_role_by_id.sql) เพิ่มแค่ employment_status = 'active'
-- ----------------------------------------------------------------------------

create or replace function public.current_teacher_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select t.id_user
  from "Teachers" t
  where t.auth_uid = auth.uid()
    and t.employment_status = 'active'
  limit 1;
$$;

create or replace function public.current_school_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select t.id_school
  from "Teachers" t
  where t.auth_uid = auth.uid()
    and t.employment_status = 'active'
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from "Teachers" t
    where t.auth_uid = auth.uid() and t.id_role = 22
      and t.employment_status = 'active'
  );
$$;

create or replace function public.is_approver()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from "Teachers" t
    where t.auth_uid = auth.uid() and t.id_role = 22
      and t.employment_status = 'active'
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from "Teachers" t
    where t.auth_uid = auth.uid()
      and t.id_role = 22
      and t.is_super_admin
      and t.employment_status = 'active'
  );
$$;


-- ----------------------------------------------------------------------------
-- 3) เปลี่ยนสถานะได้เฉพาะผู้ดูแลระบบ — SQL Editor (ไม่มีผู้ล็อกอิน) ได้เสมอ
-- ----------------------------------------------------------------------------

create or replace function public.guard_employment_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.is_admin()
     and (
       (tg_op = 'INSERT' and (new.employment_status <> 'active' or new.left_date is not null))
       or (tg_op = 'UPDATE' and (new.employment_status is distinct from old.employment_status
                                 or new.left_date is distinct from old.left_date))
     ) then
    raise exception 'เปลี่ยนสถานะบุคลากรได้เฉพาะผู้ดูแลระบบ';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_employment_status on public."Teachers";
create trigger guard_employment_status
  before insert or update on public."Teachers"
  for each row execute function public.guard_employment_status();


-- ----------------------------------------------------------------------------
-- 4) สถานะของคนที่ล็อกอินอยู่ — อ่านได้แม้พ้นสภาพแล้ว (RLS ซ่อนแถวตัวเอง)
--    null = ไม่พบบัญชีที่ผูกกับ Auth
-- ----------------------------------------------------------------------------

create or replace function public.my_employment_status()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select t.employment_status
  from "Teachers" t
  where t.auth_uid = auth.uid()
  limit 1;
$$;

grant execute on function public.my_employment_status() to authenticated;


-- ----------------------------------------------------------------------------
-- 5) ตรวจผล — จำนวนบุคลากรตามสถานะในแต่ละโรงเรียน (หลังรันครั้งแรก = active ทั้งหมด)
-- ----------------------------------------------------------------------------

select id_school, employment_status, count(*) as จำนวน
from public."Teachers"
group by id_school, employment_status
order by id_school, employment_status;
