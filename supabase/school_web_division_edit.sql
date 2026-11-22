-- ============================================================================
--  F4 + F5: สิทธิ์ "แก้ไขฝ่าย / ระบบงาน" ของ web โรงเรียน บังคับในฐานข้อมูล
--
--  ต้องรันก่อนแล้ว: school_web_*.sql ทั้งหมด, school_web_security_fix1.sql
--  รันซ้ำได้ (Idempotent) · ไม่กระทบแอปวันลา (แตะเฉพาะตาราง SchoolWeb* + แถว Permissions menu_id ติดลบของ web)
--
--  เดิม (F4): ตาราง web โรงเรียนเขียนได้เฉพาะแอดมิน (id_role 22) → ครูที่แอดมินให้สิทธิ์ "แก้ไข"
--             ฝ่าย/ระบบงานเห็นปุ่มแก้ แต่กดบันทึกแล้ว error
--  หลังรัน : แอดมิน / ส่วนกลาง เหมือนเดิม + ผู้ที่ได้สิทธิ์แก้ไขฝ่ายหรือระบบงานนั้นในโรงเรียนตัวเอง
--
--  ลำดับตัดสิน (ตรงกับ web: roleModulePermissions.ts / staffDivisionMapping.ts)
--    1. ส่วนกลาง / แอดมินโรงเรียน / บทบาทที่ตั้งระดับ "แอดมินโรงเรียน" (menu_id -602) → แก้ได้
--    2. สิทธิ์รายบุคคลของระบบงาน (-(100000 + id*100 + 20 + slot)) ถ้ามี → ตามค่านั้น
--    3. สิทธิ์รายบุคคลของฝ่าย: ถ้าบุคคลนี้ถูกผูกฝ่ายใดไว้ → แก้ได้เฉพาะฝ่ายที่ได้ "แก้ไข"
--    4. สิทธิ์ตามบทบาทของระบบงาน (-50x) ถ้ามี → ตามค่านั้น ไม่มี → ของฝ่าย (-30x)
--
--  F5: ตาราง SchoolWebRoleDivisionAccess (สิทธิ์ฝ่ายตามบทบาท ชุดเก่า) ซ้ำกับ Permissions -20x/-30x
--      → คัดลอกค่าที่ยังไม่มีเข้า Permissions แล้ว web เลิกอ่านตารางเก่า (ไม่ลบตาราง)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) เปิดช่วง menu_id ติดลบของ web ในตาราง Permissions
--    เดิม check (menu_id between 0 and 10) จาก attendance_permissions.sql → สิทธิ์ทุกตัวของ web
--    (แพ็กเกจ -1xx, ฝ่าย -2xx/-3xx, ระบบงาน -4xx/-5xx, ระดับ -60x, รายบุคคล -1000xx…) บันทึกไม่ลง
--    เมนูของแอปยังเป็น 0–10 เหมือนเดิม · แอปอ่านเมนูตามเลขที่รู้จักเท่านั้น แถวติดลบไม่กระทบ
--    ถ้ารัน attendance_permissions.sql / official_trips_permissions.sql ซ้ำ ต้องรันไฟล์นี้ซ้ำด้วย
-- ----------------------------------------------------------------------------
alter table public."Permissions" drop constraint if exists "Permissions_menu_id_range";
alter table public."Permissions"
  add constraint "Permissions_menu_id_range"
  check (menu_id between 0 and 10 or menu_id <= -100);


-- ----------------------------------------------------------------------------
-- 1) F5: ย้ายค่าจากตารางเก่าเข้า Permissions (เฉพาะที่ยังไม่มี — ค่าที่ตั้งในหน้าใหม่ชนะ)
-- ----------------------------------------------------------------------------
do $$
begin
  if to_regclass('public."SchoolWebRoleDivisionAccess"') is null then
    return;
  end if;

  insert into public."Permissions" (id_school, id_role, menu_id, status, "updatedAt")
  select a.id_school, a.id_role, m.menu_id, m.on_off::bit, now()
  from public."SchoolWebRoleDivisionAccess" a
  join public."SchoolWebDivisions" d on d.id = a.division_id
  cross join lateral (values
    (case d.division_key when 'hr' then -201 when 'academic' then -202
                         when 'admin' then -203 when 'finance' then -204 end,
     case when a.can_view then '1' else '0' end),
    (case d.division_key when 'hr' then -301 when 'academic' then -302
                         when 'admin' then -303 when 'finance' then -304 end,
     case when a.can_edit then '1' else '0' end)
  ) as m(menu_id, on_off)
  where m.menu_id is not null
    and not exists (
      select 1 from public."Permissions" p
      where p.id_school = a.id_school and p.id_role = a.id_role and p.menu_id = m.menu_id
    );
end $$;


-- ----------------------------------------------------------------------------
-- 2) ตัวตรวจสิทธิ์
-- ----------------------------------------------------------------------------

-- ค่าของแถว Permissions: true / false / null (ไม่มีแถว)
create or replace function public.school_web_perm(
  target_school bigint, target_role bigint, target_menu bigint
) returns boolean
language sql stable security definer set search_path = public
as $$
  select case when lower(trim(p.status::text)) in ('1', 'true', 't') then true else false end
  from public."Permissions" p
  where p.id_school = target_school and p.id_role = target_role and p.menu_id = target_menu
  limit 1;
$$;

create or replace function public.can_edit_school_web(
  target_school bigint, division_key text, module_key text default null
) returns boolean
language plpgsql stable security definer set search_path = public
as $$
declare
  uid bigint;
  rid bigint;
  div_slot int;
  mod_slot int;
  div_edit_menu bigint;
  mod_edit_menu bigint;
  v boolean;
  assigned boolean;
begin
  if target_school is null then
    return public.is_super_admin();
  end if;
  if public.can_manage_school(target_school) then
    return true;
  end if;
  if target_school is distinct from public.current_school_id() then
    return false;
  end if;

  select t.id_user, t.id_role into uid, rid
  from public."Teachers" t where t.auth_uid = auth.uid() limit 1;
  if uid is null then
    return false;
  end if;

  -- บทบาทระดับ "แอดมินโรงเรียน" ใน web
  if rid is not null and coalesce(public.school_web_perm(target_school, rid, -602), false) then
    return true;
  end if;

  div_slot := case division_key when 'hr' then 41 when 'academic' then 42
                                when 'admin' then 43 when 'finance' then 44 end;
  div_edit_menu := case division_key when 'hr' then -301 when 'academic' then -302
                                     when 'admin' then -303 when 'finance' then -304 end;
  mod_slot := case module_key
    when 'leave-system' then 1 when 'staff-registry' then 2 when 'departments' then 3
    when 'students-classrooms' then 4 when 'curriculum-schedule' then 5
    when 'documents' then 6 when 'announcements' then 7
    when 'finance-budget' then 8 when 'appointment-orders' then 9 end;
  mod_edit_menu := case when mod_slot is not null then -(500 + mod_slot) end;

  -- 2. รายบุคคล: ระบบงาน
  if mod_slot is not null then
    v := public.school_web_perm(target_school, 22, -(100000 + uid * 100 + 20 + mod_slot));
    if v is not null then
      return v;
    end if;
  end if;

  -- 3. รายบุคคล: ฝ่าย (ผูกฝ่ายไว้ = เห็น/แก้เฉพาะฝ่ายที่ผูก)
  select exists (
    select 1 from public."Permissions" p
    where p.id_school = target_school and p.id_role = 22
      and p.menu_id in (-(100000 + uid * 100 + 41), -(100000 + uid * 100 + 42),
                        -(100000 + uid * 100 + 43), -(100000 + uid * 100 + 44),
                        -(100000 + uid * 100 + 51), -(100000 + uid * 100 + 52),
                        -(100000 + uid * 100 + 53), -(100000 + uid * 100 + 54))
      and lower(trim(p.status::text)) in ('1', 'true', 't')
  ) into assigned;
  if assigned then
    return div_slot is not null and coalesce(
      public.school_web_perm(target_school, 22, -(100000 + uid * 100 + 10 + div_slot)), false);
  end if;

  -- 4. ตามบทบาท
  if rid is null then
    return false;
  end if;
  if mod_edit_menu is not null then
    v := public.school_web_perm(target_school, rid, mod_edit_menu);
    if v is not null then
      return v;
    end if;
  end if;
  return div_edit_menu is not null
     and coalesce(public.school_web_perm(target_school, rid, div_edit_menu), false);
end;
$$;

revoke all on function public.can_edit_school_web(bigint, text, text) from public, anon;
grant execute on function public.can_edit_school_web(bigint, text, text) to authenticated;
revoke all on function public.school_web_perm(bigint, bigint, bigint) from public, anon;
grant execute on function public.school_web_perm(bigint, bigint, bigint) to authenticated;


-- ----------------------------------------------------------------------------
-- 3) policy เขียนของตาราง web โรงเรียน → ตามฝ่าย / ระบบงาน
-- ----------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('SchoolWebClassrooms',        'school_web_classrooms_write',    'academic', 'students-classrooms'),
      ('SchoolWebStudents',          'school_web_students_write',      'academic', 'students-classrooms'),
      ('SchoolWebSubjects',          'school_web_subjects_write',      'academic', 'curriculum-schedule'),
      ('SchoolWebTeachingSchedules', 'school_web_schedules_write',     'academic', 'curriculum-schedule'),
      ('SchoolWebDocuments',         'school_web_documents_write',     'admin',    'documents'),
      ('SchoolWebAnnouncements',     'school_web_announcements_write', 'admin',    'announcements'),
      ('SchoolWebFinanceItems',      'school_web_finance_items_write', 'finance',  'finance-budget')
    ) as t(tbl, pol, div, mod)
  loop
    if to_regclass(format('public.%I', r.tbl)) is null then
      continue;
    end if;
    execute format('drop policy if exists %I on public.%I', r.pol, r.tbl);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (public.can_edit_school_web(id_school, %L, %L)) '
      'with check (public.can_edit_school_web(id_school, %L, %L))',
      r.pol, r.tbl, r.div, r.mod, r.div, r.mod);
  end loop;
end $$;

-- คำสั่งแต่งตั้ง: ตามฝ่ายของคำสั่ง (division_key) + ระบบงาน appointment-orders
drop policy if exists "school_web_orders_write" on public."SchoolWebOrders";
create policy "school_web_orders_write"
  on public."SchoolWebOrders" for all to authenticated
  using (public.can_edit_school_web(id_school, division_key, 'appointment-orders'))
  with check (public.can_edit_school_web(id_school, division_key, 'appointment-orders'));

drop policy if exists "school_web_order_groups_write" on public."SchoolWebOrderGroups";
create policy "school_web_order_groups_write"
  on public."SchoolWebOrderGroups" for all to authenticated
  using (exists (select 1 from public."SchoolWebOrders" o where o.id = order_id
                 and o.id_school = "SchoolWebOrderGroups".id_school
                 and public.can_edit_school_web(o.id_school, o.division_key, 'appointment-orders')))
  with check (exists (select 1 from public."SchoolWebOrders" o where o.id = order_id
                 and o.id_school = "SchoolWebOrderGroups".id_school
                 and public.can_edit_school_web(o.id_school, o.division_key, 'appointment-orders')));

drop policy if exists "school_web_order_members_write" on public."SchoolWebOrderMembers";
create policy "school_web_order_members_write"
  on public."SchoolWebOrderMembers" for all to authenticated
  using (exists (select 1 from public."SchoolWebOrders" o where o.id = order_id
                 and o.id_school = "SchoolWebOrderMembers".id_school
                 and public.can_edit_school_web(o.id_school, o.division_key, 'appointment-orders')))
  with check (exists (select 1 from public."SchoolWebOrders" o where o.id = order_id
                 and o.id_school = "SchoolWebOrderMembers".id_school
                 and public.can_edit_school_web(o.id_school, o.division_key, 'appointment-orders')));

insert into public."SchemaMigrations"(name) values ('school_web_division_edit.sql') on conflict do nothing;

notify pgrst, 'reload schema';

-- ตรวจผล
select tablename, policyname, cmd, qual
from pg_policies
where schemaname = 'public' and tablename like 'SchoolWeb%' and cmd = 'ALL'
order by tablename;
