-- ============================================================================
--  พาร์ท E ขั้น 4 — เปิด RLS ให้ทุกตาราง + เขียน policy
--
--  วิธีรัน: เปิด Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--
--  หลักการ:
--    - anon (ยังไม่ล็อกอิน) = อ่านไม่ได้เลยสักตาราง
--    - authenticated (ครูที่ล็อกอินแล้ว) = อ่านข้อมูลที่ต้องใช้ทำงานได้
--    - เขียนข้อมูลหลัก (ตาราง master) = เฉพาะผู้ดูแลระบบ
--    - ใบลา = เจ้าของแก้ของตัวเอง, ผู้บริหาร/ผู้ดูแลระบบ แก้ของทุกคนได้
--    - service_role (Edge Function) ข้าม RLS อัตโนมัติ ไม่ต้องเขียน policy ให้
--
--  ⚠️ สำคัญ: สคริปต์นี้ "ล้าง policy เดิมทั้งหมด" ของตารางที่ระบุไว้ก่อนเสมอ
--     เพราะรอบแรกที่รันพบว่ามี policy เก่าค้างอยู่ตั้งแต่ก่อนหน้า (ตอน RLS ปิดอยู่
--     จึงไม่มีผล) พอเปิด RLS แล้ว policy เป็นแบบ OR กัน ของเก่าที่เปิดกว้าง
--     เช่น "ให้ทุกคนอ่านได้" จะลบล้างของใหม่ทั้งหมด → anon ยังอ่านได้เหมือนเดิม
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
-- 2) เปิด RLS + ล้าง policy เก่าทิ้งให้หมด
--
--    ข้ามตารางที่ไม่มีอยู่จริงให้อัตโนมัติ (เช่น appconfig ที่ถูกลบไปแล้ว)
--    หลังบล็อกนี้ทุกตารางจะ "ปิดสนิท" ชั่วคราว แล้วค่อยเปิดช่องทีละอัน
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
  p record;
begin
  foreach t in array array[
    'Teachers', 'Leaves', 'LeaveTypes', 'LeaveReasons', 'FiscalRounds',
    'SpecialHolidays', 'SpecialWorkingDays', 'Settings', 'LoginLogs',
    'UserRoles', 'Permissions', 'MobilePermissions',
    'academics', 'adminroles', 'departments', 'positions', 'roles',
    'Subjects', 'AdminViewCodes',
    'school_auth_challenges', 'school_auth_limits',
    'appconfig'
  ]
  loop
    if to_regclass(format('public.%I', t)) is null then
      raise notice 'ข้ามตาราง % (ไม่มีอยู่จริง)', t;
      continue;
    end if;

    execute format('alter table public.%I enable row level security', t);

    -- ล้าง policy เดิมทั้งหมดของตารางนี้ ไม่ว่าใครสร้างไว้ตอนไหน
    for p in
      select policyname from pg_policies
      where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy %I on public.%I', p.policyname, t);
      raise notice 'ลบ policy เก่า %.%', t, p.policyname;
    end loop;
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 3) Teachers — ทะเบียนบุคลากร
--
--    ทุกคนที่ล็อกอินแล้วอ่านได้ เพราะหน้าปฏิทิน/บุคลากร/ฟอร์มใบลา
--    ต้องแสดงชื่อเพื่อนร่วมงานทั้งโรงเรียน
--    แก้ไขได้เฉพาะแถวของตัวเอง (เปลี่ยนรหัส/อัปรูป) หรือผู้ดูแลระบบ
-- ----------------------------------------------------------------------------

create policy teachers_select on "Teachers"
  for select to authenticated using (true);

create policy teachers_update_self_or_admin on "Teachers"
  for update to authenticated
  using (auth_uid = auth.uid() or public.is_admin())
  with check (auth_uid = auth.uid() or public.is_admin());

create policy teachers_insert_admin on "Teachers"
  for insert to authenticated with check (public.is_admin());

create policy teachers_delete_admin on "Teachers"
  for delete to authenticated using (public.is_admin());


-- ----------------------------------------------------------------------------
-- 4) Leaves — ใบลา
--
--    อ่านได้ทุกคน (ปฏิทินและรายงานภาพรวมแสดงใบลาของทั้งโรงเรียนอยู่แล้ว)
--    สร้างได้เฉพาะใบลาของตัวเอง ยกเว้นผู้บริหาร/ผู้ดูแลระบบที่คีย์แทนได้
--    แก้/ลบ = เจ้าของ หรือ ผู้บริหาร/ผู้ดูแลระบบ (ต้องกดอนุมัติได้)
-- ----------------------------------------------------------------------------

create policy leaves_select on "Leaves"
  for select to authenticated using (true);

create policy leaves_insert on "Leaves"
  for insert to authenticated
  with check (id_user = public.current_teacher_id() or public.is_approver());

create policy leaves_update on "Leaves"
  for update to authenticated
  using (id_user = public.current_teacher_id() or public.is_approver())
  with check (id_user = public.current_teacher_id() or public.is_approver());

create policy leaves_delete on "Leaves"
  for delete to authenticated
  using (id_user = public.current_teacher_id() or public.is_approver());


-- ----------------------------------------------------------------------------
-- 5) ตารางข้อมูลหลัก — ทุกคนอ่านได้ เขียนได้เฉพาะผู้ดูแลระบบ
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'LeaveTypes', 'LeaveReasons', 'FiscalRounds',
    'SpecialHolidays', 'SpecialWorkingDays', 'Settings',
    'UserRoles', 'Permissions', 'MobilePermissions',
    'academics', 'adminroles', 'departments', 'positions', 'roles',
    'Subjects', 'appconfig'
  ]
  loop
    if to_regclass(format('public.%I', t)) is null then
      continue;
    end if;

    execute format(
      'create policy master_select on public.%I '
      'for select to authenticated using (true)', t);

    execute format(
      'create policy master_write on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 6) LoginLogs — ประวัติการเข้าใช้งาน
--
--    ครูเขียนของตัวเองได้ (ระบบบันทึกให้ตอนล็อกอิน) แต่ดูย้อนหลังไม่ได้
--    เห็นได้เฉพาะผู้ดูแลระบบ เพราะเป็นข้อมูลการเฝ้าระวัง
-- ----------------------------------------------------------------------------

create policy loginlogs_insert_self on "LoginLogs"
  for insert to authenticated
  with check (id_user = public.current_teacher_id() or public.is_admin());

create policy loginlogs_select_admin on "LoginLogs"
  for select to authenticated using (public.is_admin());

create policy loginlogs_delete_admin on "LoginLogs"
  for delete to authenticated using (public.is_admin());


-- ----------------------------------------------------------------------------
-- 7) ตารางที่ไม่มีโค้ดในแอปเรียกใช้ — ปิดสนิท
--
--    AdminViewCodes         ของเก่าจากตอนยืนยันตัวตนผ่านไลน์ เลิกใช้แล้ว
--    school_auth_challenges ไม่พบการเรียกใช้ในโค้ดเลย และไม่มีข้อมูล
--    school_auth_limits     เช่นเดียวกัน
--
--    เปิด RLS ไว้โดยไม่สร้าง policy = เข้าถึงได้เฉพาะ service_role
--    (ทำไปแล้วในข้อ 2 — ตรงนี้เขียนไว้เพื่อบันทึกเจตนา ไม่ต้องทำอะไรเพิ่ม)
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- 8) ตรวจผลหลังรัน
--
--    ทุกตารางต้อง rowsecurity = true
--    และจำนวน policy ต้องตรงกับที่ออกแบบไว้:
--      Teachers 4 / Leaves 4 / LoginLogs 3 / ตาราง master 2
--      AdminViewCodes, school_auth_* = 0 (ปิดสนิทโดยตั้งใจ)
-- ----------------------------------------------------------------------------

select c.tablename,
       c.rowsecurity,
       (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = c.tablename) as policies
from pg_tables c
where c.schemaname = 'public'
order by c.rowsecurity, c.tablename;
