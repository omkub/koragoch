-- ============================================================================
--  School Web — ความปลอดภัยรอบ 1 (จากการตรวจสถาปัตยกรรม)
--
--  ต้องรันก่อนแล้ว: super_admin.sql, roles_per_school.sql,
--                   school_web_academic.sql, school_web_appointment_orders.sql
--  รันซ้ำได้ (Idempotent) · ไม่ลบข้อมูล
--
--  1) เพดานแพ็กเกจโรงเรียน (Permissions.menu_id -199 … -100) แก้ได้เฉพาะผู้ดูแลส่วนกลาง
--     เดิม: policy menu_write ให้แอดมินโรงเรียนเขียนทุกแถวของโรงเรียนตัวเอง
--     → แอดมินโรงเรียนเปิด Module / ฝ่ายที่ส่วนกลางไม่อนุญาตให้ตัวเองได้ผ่าน API
--
--  2) คำสั่งแต่งตั้ง แก้ / ลบได้เฉพาะแอดมินโรงเรียนนั้น และผู้ดูแลส่วนกลาง
--     (ตรงกับหน้าเว็บที่เปิดให้แก้เฉพาะ 2 กลุ่มนี้อยู่แล้ว) — ทุกคนในโรงเรียนยังอ่านได้
--     เดิม: ทุกคนในโรงเรียนสร้าง / แก้ / ลบคำสั่งได้ผ่าน API
--     + บันทึกผู้สร้าง / ผู้แก้ไขล่าสุด
--
--  3) ชื่อ-เบอร์ผู้ปกครองนักเรียน → ตาราง SchoolWebStudentGuardians
--     อ่านได้เฉพาะ แอดมินโรงเรียนนั้น / ผู้ดูแลส่วนกลาง / ครูที่ปรึกษาของห้องนักเรียนคนนั้น
--     รายชื่อนักเรียน (SchoolWebStudents) ทุกคนในโรงเรียนยังอ่านได้ตามเดิม
--     trigger: ใครเขียน guardian_name / guardian_phone ลง SchoolWebStudents
--     ระบบย้ายไปตารางใหม่ให้อัตโนมัติ คอลัมน์เดิมจึงว่างเสมอ (แบบเดียวกับ TeacherPasswords)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) กันแถวแพ็กเกจโรงเรียนใน Permissions
--    menu_id -100 (เปิดเว็บโรงเรียน) / -101…-109 (Module) / -121…-124 (ฝ่าย)
--    (สิทธิ์ฝ่ายตามบทบาท -201… / -301… และสิทธิ์รายคน ≤ -100000 แอดมินโรงเรียนแก้ได้ตามเดิม)
--    auth.uid() ว่าง = รันจาก SQL Editor / service_role → ข้ามการตรวจ
-- ----------------------------------------------------------------------------

create or replace function public.guard_school_package_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  touched_menu bigint;
begin
  touched_menu := case when tg_op = 'DELETE' then old.menu_id else new.menu_id end;

  if auth.uid() is not null
     and not public.is_super_admin()
     and (
       touched_menu between -199 and -100
       or (tg_op = 'UPDATE' and old.menu_id between -199 and -100)
     )
  then
    raise exception 'แพ็กเกจของโรงเรียน (Module / ฝ่ายที่เปิดใช้) แก้ได้เฉพาะผู้ดูแลส่วนกลาง'
      using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_school_package on public."Permissions";
create trigger guard_school_package
  before insert or update or delete on public."Permissions"
  for each row execute function public.guard_school_package_permissions();


-- ----------------------------------------------------------------------------
-- 2) คำสั่งแต่งตั้ง: เขียนได้เฉพาะแอดมินโรงเรียนนั้น / ผู้ดูแลส่วนกลาง
-- ----------------------------------------------------------------------------

create or replace function public.can_manage_school(target bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
      or (target is not null and public.is_admin() and target = public.current_school_id());
$$;

grant execute on function public.can_manage_school(bigint) to authenticated;

alter table public."SchoolWebOrders"
  add column if not exists created_by bigint default public.current_teacher_id();
alter table public."SchoolWebOrders"
  add column if not exists updated_by bigint;

create or replace function public.stamp_school_web_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, public.current_teacher_id());
  else
    new.created_by := old.created_by; -- ผู้สร้างเปลี่ยนไม่ได้
  end if;
  new.updated_by := public.current_teacher_id();
  return new;
end;
$$;

drop trigger if exists stamp_school_web_order on public."SchoolWebOrders";
create trigger stamp_school_web_order
  before insert or update on public."SchoolWebOrders"
  for each row execute function public.stamp_school_web_order();

drop policy if exists "school_web_orders_write" on public."SchoolWebOrders";
create policy "school_web_orders_write"
  on public."SchoolWebOrders" for all to authenticated
  using (public.can_manage_school(id_school))
  with check (public.can_manage_school(id_school));

drop policy if exists "school_web_order_groups_write" on public."SchoolWebOrderGroups";
create policy "school_web_order_groups_write"
  on public."SchoolWebOrderGroups" for all to authenticated
  using (public.can_manage_school(id_school))
  with check (public.can_manage_school(id_school));

drop policy if exists "school_web_order_members_write" on public."SchoolWebOrderMembers";
create policy "school_web_order_members_write"
  on public."SchoolWebOrderMembers" for all to authenticated
  using (public.can_manage_school(id_school))
  with check (public.can_manage_school(id_school));


-- ----------------------------------------------------------------------------
-- 3) ข้อมูลผู้ปกครอง → ตารางแยก อ่านได้เฉพาะแอดมิน / ส่วนกลาง / ครูที่ปรึกษา
-- ----------------------------------------------------------------------------

create table if not exists public."SchoolWebStudentGuardians" (
  student_id      bigint primary key
                  references public."SchoolWebStudents"(id) on delete cascade
                  deferrable initially deferred,
  id_school       bigint not null references public."Schools"(id_school) on delete cascade,
  guardian_name   text,
  guardian_phone  text,
  updated_at      timestamptz not null default now()
);

create index if not exists "SchoolWebStudentGuardians_school_idx"
  on public."SchoolWebStudentGuardians" (id_school);

alter table public."SchoolWebStudentGuardians" enable row level security;

-- ครูที่ปรึกษาของห้องที่นักเรียนคนนี้อยู่
create or replace function public.is_student_advisor(target_student bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from "SchoolWebStudents" s
    join "SchoolWebClassrooms" c on c.id = s.classroom_id
    where s.id = target_student
      and c.advisor_teacher_id is not null
      and c.advisor_teacher_id = public.current_teacher_id()
  );
$$;

grant execute on function public.is_student_advisor(bigint) to authenticated;

drop policy if exists "school_web_guardians_select" on public."SchoolWebStudentGuardians";
create policy "school_web_guardians_select"
  on public."SchoolWebStudentGuardians" for select to authenticated
  using (
    public.can_manage_school(id_school)
    or (public.can_see_school(id_school) and public.is_student_advisor(student_id))
  );

drop policy if exists "school_web_guardians_write" on public."SchoolWebStudentGuardians";
create policy "school_web_guardians_write"
  on public."SchoolWebStudentGuardians" for all to authenticated
  using (public.can_manage_school(id_school))
  with check (public.can_manage_school(id_school));

-- ย้ายค่าเดิม แล้วล้างคอลัมน์ใน SchoolWebStudents
insert into public."SchoolWebStudentGuardians" as g (student_id, id_school, guardian_name, guardian_phone)
select s.id, s.id_school, nullif(trim(s.guardian_name), ''), nullif(trim(s.guardian_phone), '')
from public."SchoolWebStudents" s
where coalesce(trim(s.guardian_name), '') <> '' or coalesce(trim(s.guardian_phone), '') <> ''
on conflict (student_id) do update
  set guardian_name  = coalesce(excluded.guardian_name, g.guardian_name),
      guardian_phone = coalesce(excluded.guardian_phone, g.guardian_phone),
      updated_at     = now();

-- ปิด trigger ข้อ 3 ไว้ก่อน (ยังไม่สร้าง) แล้วล้างค่า
update public."SchoolWebStudents"
set guardian_name = null, guardian_phone = null
where guardian_name is not null or guardian_phone is not null;

-- เขียนผู้ปกครองลง SchoolWebStudents (หน้าเว็บ / นำเข้า) → ย้ายไปตารางใหม่อัตโนมัติ
-- ค่าว่าง ('' หรือ null) = ไม่เปลี่ยน
create or replace function public.move_student_guardian()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  g_name  text := nullif(trim(coalesce(new.guardian_name, '')), '');
  g_phone text := nullif(trim(coalesce(new.guardian_phone, '')), '');
begin
  if g_name is not null or g_phone is not null then
    if auth.uid() is not null and not public.can_manage_school(new.id_school) then
      raise exception 'ข้อมูลผู้ปกครองแก้ได้เฉพาะแอดมินโรงเรียน' using errcode = '42501';
    end if;
    insert into "SchoolWebStudentGuardians" as g (student_id, id_school, guardian_name, guardian_phone)
    values (new.id, new.id_school, g_name, g_phone)
    on conflict (student_id) do update
      set guardian_name  = coalesce(excluded.guardian_name, g.guardian_name),
          guardian_phone = coalesce(excluded.guardian_phone, g.guardian_phone),
          id_school      = excluded.id_school,
          updated_at     = now();
  end if;
  new.guardian_name := null;
  new.guardian_phone := null;
  return new;
end;
$$;

drop trigger if exists move_student_guardian on public."SchoolWebStudents";
create trigger move_student_guardian
  before insert or update on public."SchoolWebStudents"
  for each row execute function public.move_student_guardian();


-- ----------------------------------------------------------------------------
-- ตรวจผล
-- ----------------------------------------------------------------------------
select 'guardians' as what, count(*)::text as value from public."SchoolWebStudentGuardians"
union all
select 'students ที่ยังมีเบอร์ในตารางเดิม (ควรเป็น 0)', count(*)::text
  from public."SchoolWebStudents" where guardian_phone is not null or guardian_name is not null
union all
select 'policy orders_write', qual from pg_policies
  where tablename = 'SchoolWebOrders' and policyname = 'school_web_orders_write';
