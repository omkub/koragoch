-- ============================================================================
--  โรงเรียนทดลองใช้ (Demo) — พาร์ท 1: ตั้งค่าโรงเรียนทดลอง + สิทธิ์
--
--  รันซ้ำได้ · ไม่กระทบแอปวันลา · ไม่แก้ตาราง Schools (เก็บสถานะทดลองในตารางใหม่)
--  ต้องรันหลัง: roles_per_school.sql, teacher_role_per_school.sql, school_web_mapping.sql,
--              school_web_security_fix1.sql, school_web_division_edit.sql
--
--  ผู้ทดลองใช้ = "ครู" ของโรงเรียนทดลอง (ระดับผู้ใช้งาน ไม่ใช่แอดมิน)
--               + สังกัด editor ทั้ง 4 ฝ่าย (ผูกตอนสมัคร — พาร์ท 3)
--
--  ⚠️ ก่อนรัน: ตรวจว่า id_school = 3 เป็นโรงเรียนทดสอบ ไม่มีบุคลากร / ข้อมูลจริง
--     ไฟล์นี้หยุดเองถ้าโรงเรียน 3 มีบุคลากร (ที่ไม่ใช่ผู้ดูแลส่วนกลาง) เกิน 5 คน
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) ตารางตั้งค่าโรงเรียนทดลอง
-- ----------------------------------------------------------------------------
create table if not exists public."SchoolWebDemoConfig" (
  id_school           bigint primary key references public."Schools"("id_school") on delete cascade,
  demo_signup_enabled boolean not null default false,   -- ส่วนกลางเปิดรับสมัครเอง (พาร์ท 4)
  account_ttl_days    int not null default 7 check (account_ttl_days between 1 and 90),
  trial_role_id       bigint,                            -- "ครู" ของโรงเรียนทดลอง
  updated_at          timestamptz not null default now()
);

alter table public."SchoolWebDemoConfig" enable row level security;

drop policy if exists "school_web_demo_config_read" on public."SchoolWebDemoConfig";
create policy "school_web_demo_config_read"
  on public."SchoolWebDemoConfig" for select to authenticated
  using (true);

drop policy if exists "school_web_demo_config_write" on public."SchoolWebDemoConfig";
create policy "school_web_demo_config_write"
  on public."SchoolWebDemoConfig" for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

create or replace function public.is_demo_school(target bigint)
returns boolean
language sql stable security definer set search_path = public
as $$
  select target is not null
     and exists (select 1 from public."SchoolWebDemoConfig" d where d.id_school = target);
$$;

revoke all on function public.is_demo_school(bigint) from public;
grant execute on function public.is_demo_school(bigint) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2) ลงทะเบียนโรงเรียน 3 เป็นโรงเรียนทดลอง + เปิดเว็บโรงเรียน + ฝ่าย / ระบบงาน
-- ----------------------------------------------------------------------------
do $$
declare
  demo_school constant bigint := 3;
  real_staff  int;
  teacher_rid bigint;
  m           int;
begin
  if not exists (select 1 from public."Schools" where id_school = demo_school) then
    raise exception 'ไม่พบโรงเรียน id_school = %', demo_school;
  end if;

  select count(*) into real_staff
  from public."Teachers"
  where id_school = demo_school and coalesce(is_super_admin, false) = false;
  if real_staff > 5 and not public.is_demo_school(demo_school) then
    raise exception 'โรงเรียน % มีบุคลากร % คน — อาจเป็นโรงเรียนจริง หยุดไว้ก่อน', demo_school, real_staff;
  end if;

  -- "ครู" ของโรงเรียนทดลอง (แถว is_default_teacher ของโรงเรียนนั้น)
  select "ID_Roles" into teacher_rid
  from public.roles
  where id_school = demo_school and coalesce(is_default_teacher, false)
  order by "ID_Roles" limit 1;
  if teacher_rid is null then
    raise exception 'โรงเรียน % ยังไม่มีสิทธิ์ "ครู" ของตัวเอง (รัน teacher_role_per_school.sql ก่อน)', demo_school;
  end if;
  if teacher_rid = 22 or exists (
    select 1 from public.roles where "ID_Roles" = teacher_rid and "Accessrights" ilike '%ผู้ดูแลระบบ%'
  ) then
    raise exception 'สิทธิ์ครูของโรงเรียน % เป็นสิทธิ์ผู้ดูแลระบบ — ใช้เป็นบัญชีทดลองไม่ได้', demo_school;
  end if;

  insert into public."SchoolWebDemoConfig"(id_school, trial_role_id)
  values (demo_school, teacher_rid)
  on conflict (id_school) do update
    set trial_role_id = excluded.trial_role_id, updated_at = now();

  -- เปิดเว็บโรงเรียน (เพดานแพ็กเกจ menu_id -100) — ระบบงานที่ไม่มีแถว = อนุญาต
  insert into public."Permissions"(id_school, id_role, menu_id, status, "updatedAt")
  values (demo_school, 22, -100, '1', now())
  on conflict (id_school, id_role, menu_id) do update set status = '1', "updatedAt" = now();

  -- ฝ่าย 4 ฝ่าย + ระบบงานมาตรฐาน
  perform public.seed_school_web_divisions(demo_school);

  -- เมนูแอประบบวันลา (PC) ของ "ครู" โรงเรียนทดลอง: เปิดทุกเมนู ยกเว้น 4 จัดการระบบ
  for m in 0..10 loop
    insert into public."Permissions"(id_school, id_role, menu_id, status, "updatedAt")
    values (demo_school, teacher_rid, m, case when m = 4 then B'0' else B'1' end, now())
    on conflict (id_school, id_role, menu_id) do update
      set status = excluded.status, "updatedAt" = now();
  end loop;

  -- ครูโรงเรียนทดลองเข้าแท็บ "เว็บโรงเรียน" ได้ (ระดับสิทธิ์ยังเป็นผู้ใช้งาน)
  delete from public."Permissions"
  where id_school = demo_school and id_role = teacher_rid and menu_id in (-601, -602);
end;
$$;

-- ----------------------------------------------------------------------------
-- 3) ข้อมูลผู้ปกครอง: โรงเรียนทดลองให้ editor ฝ่ายวิชาการ (ระบบงานนักเรียน) แก้ได้
--    โรงเรียนจริงยังเป็นเฉพาะแอดมินโรงเรียนเหมือนเดิม
-- ----------------------------------------------------------------------------
create or replace function public.can_write_student_guardian(target bigint)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.can_manage_school(target)
      or (public.is_demo_school(target)
          and public.can_edit_school_web(target, 'academic', 'students-classrooms'));
$$;

revoke all on function public.can_write_student_guardian(bigint) from public, anon;
grant execute on function public.can_write_student_guardian(bigint) to authenticated;

drop policy if exists "school_web_guardians_write" on public."SchoolWebStudentGuardians";
create policy "school_web_guardians_write"
  on public."SchoolWebStudentGuardians" for all to authenticated
  using (public.can_write_student_guardian(id_school))
  with check (public.can_write_student_guardian(id_school));

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
    if auth.uid() is not null and not public.can_write_student_guardian(new.id_school) then
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

insert into public."SchemaMigrations"(name) values ('school_web_demo_setup.sql') on conflict do nothing;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- ตรวจผล
-- ----------------------------------------------------------------------------
select d.id_school, s."fullName" as school, d.trial_role_id, r."Accessrights" as trial_role,
       d.demo_signup_enabled, d.account_ttl_days
from public."SchoolWebDemoConfig" d
join public."Schools" s on s.id_school = d.id_school
left join public.roles r on r."ID_Roles" = d.trial_role_id;
