-- ============================================================================
--  Multi-school ชั้นที่ 3 — RLS กันการมองข้ามโรงเรียน + วันหยุด 2 แบบ
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--  ต้องรันก่อนแล้ว: enable_rls.sql, create_schools_table.sql,
--                  multi_school_step1_id_school.sql, super_admin.sql
--
--  หลักการ:
--    - ทุกคนเห็น/แก้ได้เฉพาะข้อมูลของโรงเรียนตัวเอง
--    - ผู้ดูแลส่วนกลาง (is_super_admin) เห็น/แก้ได้ทุกโรงเรียน
--    - สิทธิ์ภายในโรงเรียนเหมือนเดิมทุกอย่าง (ครู/ผู้บริหาร/ผู้ดูแลระบบ)
--
--  วันหยุด / วันทำงานพิเศษ:
--    id_school ว่าง   = วันหยุดตามปฏิทิน ใช้ทุกโรงเรียน (แก้ได้เฉพาะส่วนกลาง)
--    id_school มีค่า  = เฉพาะโรงเรียนนั้น (แอดมินโรงเรียนนั้นแก้ได้)
--    ข้อมูลเดิมทั้งหมดถือเป็นวันหยุดตามปฏิทิน
--
--  ยังไม่แตะ (ตั้งใจ):
--    ตารางที่ใช้ร่วมกัน (FiscalRounds, LeaveTypes, roles, positions ฯลฯ)
--    ยังให้แอดมินทุกโรงเรียนแก้ได้เหมือนเดิม — ดูหมายเหตุท้ายไฟล์
--    Settings รอทำพร้อมความปลอดภัยข้อ 2
--
--  ย้อนกลับ: รัน enable_rls.sql ใหม่ แล้วรันข้อ 3 ของ create_schools_table.sql
--  (คอลัมน์ id_school ของตารางวันหยุดปล่อยไว้ได้ ไม่กระทบอะไร)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ฟังก์ชันผู้ช่วย: ผู้ใช้คนนี้มองเห็นโรงเรียนนี้ได้ไหม
-- ----------------------------------------------------------------------------

create or replace function public.can_see_school(target bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
      or (target is not null and target = public.current_school_id());
$$;

grant execute on function public.can_see_school(bigint) to authenticated;


-- ----------------------------------------------------------------------------
-- 2) วันหยุด / วันทำงานพิเศษ — เพิ่ม id_school (ว่างได้)
--
--    trigger: ถ้าไม่ใช่ผู้ดูแลส่วนกลางแล้วไม่ได้ระบุโรงเรียนมา ให้เป็นของ
--    โรงเรียนตัวเองอัตโนมัติ (กันแอปเวอร์ชันเก่าที่ยังค้างในเครื่องเขียนไม่ได้)
-- ----------------------------------------------------------------------------

alter table public."SpecialHolidays"
  add column if not exists id_school bigint references public."Schools"(id_school);
alter table public."SpecialWorkingDays"
  add column if not exists id_school bigint references public."Schools"(id_school);

create index if not exists "SpecialHolidays_id_school_idx"
  on public."SpecialHolidays" (id_school);
create index if not exists "SpecialWorkingDays_id_school_idx"
  on public."SpecialWorkingDays" (id_school);

create or replace function public.fill_special_date_school()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.id_school is null
     and auth.uid() is not null
     and not public.is_super_admin() then
    new.id_school := public.current_school_id();
  end if;
  return new;
end;
$$;

drop trigger if exists fill_special_date_school on public."SpecialHolidays";
create trigger fill_special_date_school
  before insert or update on public."SpecialHolidays"
  for each row execute function public.fill_special_date_school();

drop trigger if exists fill_special_date_school on public."SpecialWorkingDays";
create trigger fill_special_date_school
  before insert or update on public."SpecialWorkingDays"
  for each row execute function public.fill_special_date_school();


-- ----------------------------------------------------------------------------
-- 3) ล้าง policy เดิมของตารางที่จะเขียนใหม่
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
  p record;
begin
  foreach t in array array[
    'Teachers', 'Leaves', 'LoginLogs', 'departments', 'adminroles',
    'SpecialHolidays', 'SpecialWorkingDays', 'Schools'
  ]
  loop
    for p in
      select policyname from pg_policies
      where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 4) Teachers
--
--    อ่าน: ครูในโรงเรียนเดียวกัน
--    แก้แถวตัวเอง: ได้เสมอ (เปลี่ยนรหัส/อัปรูป) — ย้ายโรงเรียนเองไม่ได้
--      (trigger fill_id_school กันไว้แล้ว)
--    แอดมิน: เพิ่ม/แก้/ลบ ได้เฉพาะครูในโรงเรียนตัวเอง และย้ายครูไป
--      โรงเรียนอื่นไม่ได้ (with check ตรวจโรงเรียนปลายทางด้วย)
-- ----------------------------------------------------------------------------

create policy teachers_select on "Teachers"
  for select to authenticated
  using (public.can_see_school(id_school));

create policy teachers_update on "Teachers"
  for update to authenticated
  using (auth_uid = auth.uid()
         or (public.is_admin() and public.can_see_school(id_school)))
  with check (auth_uid = auth.uid()
              or (public.is_admin() and public.can_see_school(id_school)));

create policy teachers_insert on "Teachers"
  for insert to authenticated
  with check (public.is_admin() and public.can_see_school(id_school));

create policy teachers_delete on "Teachers"
  for delete to authenticated
  using (public.is_admin() and public.can_see_school(id_school));


-- ----------------------------------------------------------------------------
-- 4.1) กันครูเลื่อนสิทธิ์ตัวเอง (ช่องโหว่เดิมตั้งแต่ enable_rls.sql)
--
--    policy ให้ครูแก้แถวของตัวเองได้ (เปลี่ยนรหัส/อัปรูป) แต่ policy ตรวจ
--    ไม่ได้ว่าแก้คอลัมน์ไหน ครูจึงเปิด devtools แล้วตั้ง id_role = ผู้ดูแลระบบ
--    ให้ตัวเองได้ — trigger นี้ให้เฉพาะผู้ดูแลระบบเปลี่ยนคอลัมน์สิทธิ์
--
--    ใช้ to_jsonb เทียบ เพราะบางคอลัมน์ (เช่น id_permission) อาจไม่มีในตาราง
-- ----------------------------------------------------------------------------

create or replace function public.guard_teacher_privileges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  col text;
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  foreach col in array array[
    'id_role', 'role', 'permission', 'id_permission', 'id_adminrole'
  ]
  loop
    if (to_jsonb(new) -> col) is distinct from (to_jsonb(old) -> col) then
      raise exception 'ไม่มีสิทธิ์เปลี่ยนสิทธิ์การใช้งาน (%)', col;
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists guard_teacher_privileges on public."Teachers";
create trigger guard_teacher_privileges
  before update on public."Teachers"
  for each row execute function public.guard_teacher_privileges();


-- ----------------------------------------------------------------------------
-- 5) Leaves — เหมือนเดิม แต่จำกัดอยู่ในโรงเรียนตัวเอง
-- ----------------------------------------------------------------------------

create policy leaves_select on "Leaves"
  for select to authenticated
  using (public.can_see_school(id_school));

create policy leaves_insert on "Leaves"
  for insert to authenticated
  with check (public.can_see_school(id_school)
              and (id_user = public.current_teacher_id() or public.is_approver()));

create policy leaves_update on "Leaves"
  for update to authenticated
  using (public.can_see_school(id_school)
         and (id_user = public.current_teacher_id() or public.is_approver()))
  with check (public.can_see_school(id_school)
              and (id_user = public.current_teacher_id() or public.is_approver()));

create policy leaves_delete on "Leaves"
  for delete to authenticated
  using (public.can_see_school(id_school)
         and (id_user = public.current_teacher_id() or public.is_approver()));


-- ----------------------------------------------------------------------------
-- 6) LoginLogs — เขียนของตัวเองได้ ดู/ลบได้เฉพาะแอดมินของโรงเรียนนั้น
-- ----------------------------------------------------------------------------

create policy loginlogs_insert on "LoginLogs"
  for insert to authenticated
  with check (id_user = public.current_teacher_id()
              or (public.is_admin() and public.can_see_school(id_school)));

create policy loginlogs_select on "LoginLogs"
  for select to authenticated
  using (public.is_admin() and public.can_see_school(id_school));

create policy loginlogs_delete on "LoginLogs"
  for delete to authenticated
  using (public.is_admin() and public.can_see_school(id_school));


-- ----------------------------------------------------------------------------
-- 7) กลุ่มสาระ / ตำแหน่งบริหาร — ของโรงเรียนใครโรงเรียนมัน
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['departments', 'adminroles']
  loop
    execute format(
      'create policy school_master_select on public.%I for select '
      'to authenticated using (public.can_see_school(id_school))', t);
    execute format(
      'create policy school_master_write on public.%I for all '
      'to authenticated '
      'using (public.is_admin() and public.can_see_school(id_school)) '
      'with check (public.is_admin() and public.can_see_school(id_school))', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 8) วันหยุด / วันทำงานพิเศษ
--
--    อ่าน: วันหยุดตามปฏิทิน (id_school ว่าง) + ของโรงเรียนตัวเอง
--    เขียน: ส่วนกลางทำได้ทุกแถว / แอดมินโรงเรียนทำได้เฉพาะแถวของโรงเรียนตัวเอง
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['SpecialHolidays', 'SpecialWorkingDays']
  loop
    execute format(
      'create policy special_date_select on public.%I for select '
      'to authenticated '
      'using (id_school is null or public.can_see_school(id_school))', t);
    execute format(
      'create policy special_date_write on public.%I for all '
      'to authenticated '
      'using (public.is_super_admin() or (public.is_admin() '
      '       and id_school is not null and id_school = public.current_school_id())) '
      'with check (public.is_super_admin() or (public.is_admin() '
      '       and id_school is not null and id_school = public.current_school_id()))', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 9) Schools
--
--    อ่าน: โรงเรียนตัวเอง (ส่วนกลางเห็นทุกโรงเรียน)
--    แก้: แอดมินแก้ข้อมูลโรงเรียนตัวเองได้ (แท็บข้อมูลโรงเรียน)
--    เพิ่ม/ลบโรงเรียน: เฉพาะส่วนกลาง
-- ----------------------------------------------------------------------------

create policy schools_select on "Schools"
  for select to authenticated
  using (public.can_see_school(id_school));

create policy schools_update on "Schools"
  for update to authenticated
  using (public.is_admin() and public.can_see_school(id_school))
  with check (public.is_admin() and public.can_see_school(id_school));

create policy schools_insert on "Schools"
  for insert to authenticated
  with check (public.is_super_admin());

create policy schools_delete on "Schools"
  for delete to authenticated
  using (public.is_super_admin());


-- ----------------------------------------------------------------------------
-- 10) ตรวจผล
--     ทุกตารางต้อง rowsecurity = true และจำนวน policy:
--       Teachers 4 / Leaves 4 / LoginLogs 3 / departments 2 / adminroles 2
--       SpecialHolidays 2 / SpecialWorkingDays 2 / Schools 4
-- ----------------------------------------------------------------------------

select c.tablename,
       c.rowsecurity,
       (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = c.tablename) as policies
from pg_tables c
where c.schemaname = 'public'
  and c.tablename in ('Teachers', 'Leaves', 'LoginLogs', 'departments',
                      'adminroles', 'SpecialHolidays', 'SpecialWorkingDays',
                      'Schools')
order by c.tablename;


-- ----------------------------------------------------------------------------
-- หมายเหตุ: ตารางที่ใช้ร่วมกันทุกโรงเรียน
--
--   FiscalRounds, LeaveTypes, LeaveReasons, roles, positions, academics,
--   Permissions, MobilePermissions ยังใช้ policy เดิมจาก enable_rls.sql
--   = แอดมินของ "ทุกโรงเรียน" แก้ได้ และมีผลกับทุกโรงเรียน
--
--   ตอนมีโรงเรียนเดียวไม่เป็นปัญหา ก่อนเปิดโรงเรียนที่ 2 ควรตัดสินใจว่า
--   จะให้แก้ได้เฉพาะผู้ดูแลส่วนกลางหรือไม่ (เปลี่ยน is_admin() เป็น
--   is_super_admin() ใน master_write)
-- ----------------------------------------------------------------------------
