-- ============================================================================
--  พาร์ท E ขั้น 4 — เปิด RLS ให้ทุกตาราง + เขียน policy
--
--  วิธีรัน: เปิด Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (ใช้ drop policy if exists ก่อนสร้างทุกอัน)
--
--  หลักการ:
--    - anon (ยังไม่ล็อกอิน) = อ่านไม่ได้เลยสักตาราง
--    - authenticated (ครูที่ล็อกอินแล้ว) = อ่านข้อมูลที่ต้องใช้ทำงานได้
--    - เขียนข้อมูลหลัก (ตาราง master) = เฉพาะผู้ดูแลระบบ
--    - ใบลา = เจ้าของแก้ของตัวเอง, ผู้บริหาร/ผู้ดูแลระบบ แก้ของทุกคนได้
--    - service_role (Edge Function) ข้าม RLS อัตโนมัติ ไม่ต้องเขียน policy ให้
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ฟังก์ชันผู้ช่วย
--
--    ต้องเป็น security definer เพราะถูกเรียกจากใน policy ของตาราง Teachers เอง
--    ถ้าเป็นฟังก์ชันธรรมดาจะวนลูปไม่รู้จบ (policy เรียกตัวเอง)
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
  limit 1;
$$;

create or replace function public.current_access_right()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(r."Accessrights", t.role, 'ครู')
  from "Teachers" t
  left join roles r on r."ID_Roles" = t.id_role
  where t.auth_uid = auth.uid()
  limit 1;
$$;

-- ผู้ดูแลระบบเท่านั้น
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_access_right() = 'ผู้ดูแลระบบ';
$$;

-- ผู้ที่อนุมัติใบลาได้ = ผู้บริหาร + ผู้ดูแลระบบ
create or replace function public.is_approver()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_access_right() in ('ผู้ดูแลระบบ', 'ผู้บริหาร');
$$;

grant execute on function public.current_teacher_id()  to authenticated;
grant execute on function public.current_access_right() to authenticated;
grant execute on function public.is_admin()            to authenticated;
grant execute on function public.is_approver()         to authenticated;


-- ----------------------------------------------------------------------------
-- 2) เปิด RLS ทุกตาราง
--
--    พอเปิดแล้วและยังไม่มี policy = ปิดสนิททั้งอ่านและเขียน
--    policy ข้างล่างจะค่อย ๆ เปิดช่องให้ทีละตาราง
-- ----------------------------------------------------------------------------

alter table "Teachers"           enable row level security;
alter table "Leaves"             enable row level security;
alter table "LeaveTypes"         enable row level security;
alter table "LeaveReasons"       enable row level security;
alter table "FiscalRounds"       enable row level security;
alter table "SpecialHolidays"    enable row level security;
alter table "SpecialWorkingDays" enable row level security;
alter table "Settings"           enable row level security;
alter table "LoginLogs"          enable row level security;
alter table "UserRoles"          enable row level security;
alter table "Permissions"        enable row level security;
alter table "MobilePermissions"  enable row level security;
alter table academics            enable row level security;
alter table adminroles           enable row level security;
alter table departments          enable row level security;
alter table positions            enable row level security;
alter table roles                enable row level security;
alter table appconfig            enable row level security;


-- ----------------------------------------------------------------------------
-- 3) Teachers — ทะเบียนบุคลากร
--
--    ทุกคนที่ล็อกอินแล้วอ่านได้ เพราะหน้าปฏิทิน/บุคลากร/ฟอร์มใบลา
--    ต้องแสดงชื่อเพื่อนร่วมงานทั้งโรงเรียน
--    แก้ไขได้เฉพาะแถวของตัวเอง (เปลี่ยนรหัส/อัปรูป) หรือผู้ดูแลระบบ
-- ----------------------------------------------------------------------------

drop policy if exists teachers_select on "Teachers";
create policy teachers_select on "Teachers"
  for select to authenticated using (true);

drop policy if exists teachers_update_self_or_admin on "Teachers";
create policy teachers_update_self_or_admin on "Teachers"
  for update to authenticated
  using (auth_uid = auth.uid() or public.is_admin())
  with check (auth_uid = auth.uid() or public.is_admin());

drop policy if exists teachers_insert_admin on "Teachers";
create policy teachers_insert_admin on "Teachers"
  for insert to authenticated with check (public.is_admin());

drop policy if exists teachers_delete_admin on "Teachers";
create policy teachers_delete_admin on "Teachers"
  for delete to authenticated using (public.is_admin());


-- ----------------------------------------------------------------------------
-- 4) Leaves — ใบลา
--
--    อ่านได้ทุกคน (ปฏิทินและรายงานภาพรวมแสดงใบลาของทั้งโรงเรียนอยู่แล้ว)
--    สร้างได้เฉพาะใบลาของตัวเอง ยกเว้นผู้ดูแลระบบที่คีย์แทนได้
--    แก้/ลบ = เจ้าของ หรือ ผู้บริหาร/ผู้ดูแลระบบ (ต้องกดอนุมัติได้)
-- ----------------------------------------------------------------------------

drop policy if exists leaves_select on "Leaves";
create policy leaves_select on "Leaves"
  for select to authenticated using (true);

drop policy if exists leaves_insert on "Leaves";
create policy leaves_insert on "Leaves"
  for insert to authenticated
  with check (id_user = public.current_teacher_id() or public.is_approver());

drop policy if exists leaves_update on "Leaves";
create policy leaves_update on "Leaves"
  for update to authenticated
  using (id_user = public.current_teacher_id() or public.is_approver())
  with check (id_user = public.current_teacher_id() or public.is_approver());

drop policy if exists leaves_delete on "Leaves";
create policy leaves_delete on "Leaves"
  for delete to authenticated
  using (id_user = public.current_teacher_id() or public.is_approver());


-- ----------------------------------------------------------------------------
-- 5) ตารางข้อมูลหลัก — ทุกคนอ่านได้ เขียนได้เฉพาะผู้ดูแลระบบ
--
--    ใช้ loop เพื่อไม่ต้องเขียน policy ซ้ำ 14 รอบ
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'LeaveTypes', 'LeaveReasons', 'FiscalRounds',
    'SpecialHolidays', 'SpecialWorkingDays', 'Settings',
    'UserRoles', 'Permissions', 'MobilePermissions',
    'academics', 'adminroles', 'departments', 'positions', 'roles', 'appconfig'
  ]
  loop
    execute format('drop policy if exists master_select on %I', t);
    execute format(
      'create policy master_select on %I for select to authenticated using (true)', t);

    execute format('drop policy if exists master_write on %I', t);
    execute format(
      'create policy master_write on %I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 6) LoginLogs — ประวัติการเข้าใช้งาน
--
--    ครูเขียนของตัวเองได้ (ระบบบันทึกให้ตอนล็อกอิน) แต่ดูย้อนหลังไม่ได้
--    เห็นได้เฉพาะผู้ดูแลระบบ เพราะเป็นข้อมูลการเฝ้าระวัง
-- ----------------------------------------------------------------------------

drop policy if exists loginlogs_insert_self on "LoginLogs";
create policy loginlogs_insert_self on "LoginLogs"
  for insert to authenticated
  with check (id_user = public.current_teacher_id() or public.is_admin());

drop policy if exists loginlogs_select_admin on "LoginLogs";
create policy loginlogs_select_admin on "LoginLogs"
  for select to authenticated using (public.is_admin());

drop policy if exists loginlogs_write_admin on "LoginLogs";
create policy loginlogs_write_admin on "LoginLogs"
  for delete to authenticated using (public.is_admin());


-- ----------------------------------------------------------------------------
-- 7) ตรวจผลหลังรัน — ต้องได้ rowsecurity = true ครบทุกแถว
-- ----------------------------------------------------------------------------

select tablename, rowsecurity,
       (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = c.tablename) as policies
from pg_tables c
where schemaname = 'public'
order by rowsecurity, tablename;
