-- ============================================================================
--  ลงเวลาด้วยเครื่องสแกนหน้า — พาร์ท 1: ตาราง + RLS
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (ข้อมูล/ค่าที่ตั้งไว้แล้วไม่หาย)
--  ต้องรันก่อนแล้ว: enable_rls.sql, multi_school_step1_id_school.sql,
--                  multi_school_step3_rls.sql, admin_role_by_id.sql
--
--  รอบนี้ "ยังไม่เปลี่ยนการทำงานของ app" — แค่สร้างตารางรอไว้
--  (พาร์ท 2 web ตั้งค่า, พาร์ท 3 ทางรับข้อมูล, พาร์ท 4 หน้าจอใน app)
--
--  หลักการ:
--    - ไม่เก็บภาพ/ข้อมูลใบหน้าในฐานข้อมูลนี้ — อยู่ในเครื่องสแกนเท่านั้น
--      เก็บแค่ "ใคร สแกนเมื่อไร ที่เครื่องไหน"
--    - การสแกนดิบเก็บทุกครั้ง (เข้า/ออกตัดสินตอนคำนวณ พาร์ท 5)
--      ใช้ได้ทั้งแบบสแกนเข้าอย่างเดียว และสแกนเข้า-ออก
--    - ครูจับคู่กับเครื่องด้วย Teachers.device_code (รหัสพนักงานในเครื่อง)
--      สแกนที่ยังจับคู่ไม่ได้เก็บไว้ก่อน แล้วผูกให้อัตโนมัติเมื่อใส่รหัสทีหลัง
--
--  ตาราง:
--    AttendanceSettings  เวลาเข้างาน / เกณฑ์สาย ต่อโรงเรียน (web ตั้ง)
--    AttendanceDevices   ทะเบียนเครื่องสแกน + รหัสลับ (web ตั้ง)
--    AttendanceLogs      การสแกนทุกครั้ง (เครื่อง / นำเข้าไฟล์ / แอดมินเพิ่มให้)
--
--  สิทธิ์:
--    ครู            เห็นเฉพาะการสแกนของตัวเอง เขียนไม่ได้
--    แอดมินโรงเรียน  เห็นของทั้งโรงเรียน, นำเข้าไฟล์ / เพิ่มเวลาให้ (ต้องมี
--                   เหตุผล), ลบได้เฉพาะที่นำเข้า/เพิ่มเอง ข้อมูลจากเครื่องลบไม่ได้
--    ผู้ดูแลส่วนกลาง ตั้งค่า + ลงทะเบียนเครื่อง + ทำได้ทุกโรงเรียน
--
--  ย้อนกลับ (ลบทิ้งทั้งหมด รวมข้อมูล):
--    drop table if exists public."AttendanceLogs", public."AttendanceDevices",
--                         public."AttendanceSettings";
--    alter table public."Teachers" drop column if exists device_code,
--                                  drop column if exists face_consent_at;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0) ฟังก์ชันผู้ช่วย: โรงเรียนของครูคนหนึ่ง
--    (นิยามเดียวกับใน fine_permissions.sql — ใส่ซ้ำไว้ให้ไฟล์นี้รันได้เอง)
-- ----------------------------------------------------------------------------

create or replace function public.teacher_school(target bigint)
returns bigint
language sql stable security definer set search_path = public
as $$
  select id_school from "Teachers" where id_user = target;
$$;
grant execute on function public.teacher_school(bigint) to authenticated;


-- ----------------------------------------------------------------------------
-- 1) Teachers: รหัสในเครื่องสแกน + ความยินยอม (PDPA มาตรา 26)
--
--    device_code     รหัสพนักงานในเครื่องสแกน ห้ามซ้ำในโรงเรียนเดียวกัน
--    face_consent_at เวลาที่ครูกดยินยอมให้ใช้ข้อมูลใบหน้า (พาร์ท 4)
-- ----------------------------------------------------------------------------

alter table public."Teachers"
  add column if not exists device_code     text,
  add column if not exists face_consent_at timestamptz;

create unique index if not exists "Teachers_school_device_code_uidx"
  on public."Teachers" (id_school, device_code)
  where device_code is not null;

-- ครูแก้แถวตัวเองได้ (เปลี่ยนรหัส/อัปรูป) — ต้องกันไม่ให้ตั้ง device_code
-- เป็นรหัสของคนอื่น ไม่งั้นจะ "รับ" เวลาสแกนของคนอื่นมาเป็นของตัวเองได้
create or replace function public.guard_teacher_device_code()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.is_admin()
     and new.device_code is distinct from old.device_code then
    raise exception 'รหัสเครื่องสแกนกำหนดได้เฉพาะผู้ดูแลระบบ';
  end if;
  new.device_code := nullif(trim(new.device_code), '');
  return new;
end;
$$;

drop trigger if exists guard_teacher_device_code on public."Teachers";
create trigger guard_teacher_device_code
  before update on public."Teachers"
  for each row execute function public.guard_teacher_device_code();


-- ----------------------------------------------------------------------------
-- 2) AttendanceSettings — 1 แถวต่อโรงเรียน
--
--    เวลาเป็นเวลาไทย (Asia/Bangkok)
--    enabled = false จนกว่าจะเปิดใช้จาก web (app ซ่อนเมนูไว้ก่อน)
-- ----------------------------------------------------------------------------

create table if not exists public."AttendanceSettings" (
  id_school         bigint primary key references public."Schools"(id_school) on delete cascade,
  enabled           boolean not null default false,
  work_start        time    not null default '08:00',
  late_after        time    not null default '08:30',  -- สแกนหลังเวลานี้ = สาย
  work_end          time    not null default '16:30',
  require_checkout  boolean not null default false,    -- ต้องสแกนออกด้วยไหม
  "updatedAt"       timestamptz not null default now(),

  constraint attendance_settings_times_ok
    check (work_start <= late_after and late_after < work_end)
);

-- ทุกโรงเรียนมีแถวตั้งค่า (ไม่ทับของเดิม) + โรงเรียนใหม่ได้อัตโนมัติ
insert into public."AttendanceSettings"(id_school)
select id_school from public."Schools"
on conflict do nothing;

create or replace function public.seed_attendance_settings()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into "AttendanceSettings"(id_school) values (new.id_school)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists seed_attendance_settings on public."Schools";
create trigger seed_attendance_settings
  after insert on public."Schools"
  for each row execute function public.seed_attendance_settings();


-- ----------------------------------------------------------------------------
-- 3) AttendanceDevices — ทะเบียนเครื่องสแกน
--
--    device_key_hash = sha256 ของรหัสลับเครื่อง (ไม่เก็บรหัสจริง)
--    web สร้างรหัสสุ่มให้ครั้งเดียวตอนลงทะเบียน (พาร์ท 2)
--    Edge Function ตรวจรหัสกับ hash นี้ก่อนรับข้อมูล (พาร์ท 3)
-- ----------------------------------------------------------------------------

create table if not exists public."AttendanceDevices" (
  id_device         bigint generated by default as identity primary key,
  id_school         bigint not null references public."Schools"(id_school) on delete cascade,
  name              text not null,                 -- เช่น เครื่องหน้าอาคาร 1
  location          text,
  brand             text,                          -- ZKTeco / Hikvision / ...
  serial_no         text,
  device_key_hash   text,
  is_active         boolean not null default true,
  last_seen_at      timestamptz,                   -- ส่งข้อมูลมาล่าสุด
  "createdAt"       timestamptz not null default now()
);

create index if not exists "AttendanceDevices_id_school_idx"
  on public."AttendanceDevices" (id_school);


-- ----------------------------------------------------------------------------
-- 4) AttendanceLogs — การสแกนทุกครั้ง
--
--    source:  device = มาจากเครื่องโดยตรง (พาร์ท 3/7)
--             import = แอดมินนำเข้าไฟล์ที่ export จากเครื่อง
--             manual = แอดมินเพิ่มให้ (เครื่องเสีย/ลืมสแกน) ต้องมีเหตุผล
--    id_user ว่างได้ = รหัสในเครื่องยังไม่ได้จับคู่กับครู
--    ซ้ำ = โรงเรียน + คน + รหัส + เวลา ตรงกันหมด (ส่งซ้ำ/นำเข้าซ้ำไม่เบิ้ล)
-- ----------------------------------------------------------------------------

create table if not exists public."AttendanceLogs" (
  id_log        bigint generated by default as identity primary key,
  id_school     bigint references public."Schools"(id_school) on delete cascade,
  id_user       bigint references public."Teachers"(id_user) on delete cascade,
  device_code   text,
  scanned_at    timestamptz not null,
  id_device     bigint references public."AttendanceDevices"(id_device) on delete set null,
  source        text not null default 'device',
  note          text,
  created_by    bigint references public."Teachers"(id_user) on delete set null,
  "createdAt"   timestamptz not null default now(),

  constraint attendance_logs_source_ok
    check (source in ('device', 'import', 'manual')),
  constraint attendance_logs_who_ok
    check (id_user is not null or device_code is not null),
  constraint attendance_logs_manual_note
    check (source <> 'manual' or length(trim(coalesce(note, ''))) > 0),
  constraint attendance_logs_no_duplicate
    unique nulls not distinct (id_school, id_user, device_code, scanned_at)
);

create index if not exists "AttendanceLogs_school_time_idx"
  on public."AttendanceLogs" (id_school, scanned_at);
create index if not exists "AttendanceLogs_user_time_idx"
  on public."AttendanceLogs" (id_user, scanned_at);
create index if not exists "AttendanceLogs_unmatched_idx"
  on public."AttendanceLogs" (id_school, device_code)
  where id_user is null;


-- ----------------------------------------------------------------------------
-- 5) trigger: เติมข้อมูลการสแกนให้ครบ
--
--    - มีครู → โรงเรียน = โรงเรียนของครูเสมอ, เติมรหัสจากครูถ้าไม่ได้ส่งมา
--    - มีแต่รหัส → หาครูที่มีรหัสนี้ในโรงเรียนเดียวกัน
--    - มีเครื่อง → โรงเรียน = โรงเรียนของเครื่อง
--    - ไม่มีอะไรบอกโรงเรียน → ใช้โรงเรียนของคนที่ล็อกอิน
--    - created_by = คนที่ล็อกอิน (ไม่เชื่อค่าจาก app)
-- ----------------------------------------------------------------------------

create or replace function public.fill_attendance_log()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  t record;
begin
  new.device_code := nullif(trim(new.device_code), '');

  if new.id_device is not null then
    select id_school into new.id_school
    from "AttendanceDevices" where id_device = new.id_device;
  end if;

  if new.id_user is not null then
    select id_school, device_code into t
    from "Teachers" where id_user = new.id_user;
    new.id_school := t.id_school;
    new.device_code := coalesce(new.device_code, t.device_code);
  end if;

  if new.id_school is null and auth.uid() is not null then
    new.id_school := public.current_school_id();
  end if;

  if new.id_user is null and new.device_code is not null then
    select id_user into new.id_user
    from "Teachers"
    where id_school = new.id_school and device_code = new.device_code;
  end if;

  if new.id_school is null then
    raise exception 'ไม่ทราบโรงเรียนของการสแกนนี้';
  end if;

  if auth.uid() is not null then
    new.created_by := public.current_teacher_id();
  end if;

  return new;
end;
$$;

drop trigger if exists fill_attendance_log on public."AttendanceLogs";
create trigger fill_attendance_log
  before insert on public."AttendanceLogs"
  for each row execute function public.fill_attendance_log();


-- ----------------------------------------------------------------------------
-- 6) trigger: ใส่/เปลี่ยนรหัสเครื่องให้ครู → ผูกการสแกนที่ค้างอยู่ให้
--
--    เฉพาะสแกนที่ยังไม่มีเจ้าของ (id_user ว่าง) ของโรงเรียนเดียวกัน
--    สแกนที่ผูกไปแล้วไม่ย้าย (กันประวัติเก่าเปลี่ยนเจ้าของเมื่อสลับรหัส)
-- ----------------------------------------------------------------------------

create or replace function public.link_attendance_to_teacher()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.device_code is not null
     and new.device_code is distinct from old.device_code then
    update "AttendanceLogs"
    set id_user = new.id_user
    where id_user is null
      and id_school = new.id_school
      and device_code = new.device_code;
  end if;
  return new;
end;
$$;

drop trigger if exists link_attendance_to_teacher on public."Teachers";
create trigger link_attendance_to_teacher
  after update of device_code on public."Teachers"
  for each row execute function public.link_attendance_to_teacher();


-- ----------------------------------------------------------------------------
-- 7) RLS
-- ----------------------------------------------------------------------------

alter table public."AttendanceSettings" enable row level security;
alter table public."AttendanceDevices"  enable row level security;
alter table public."AttendanceLogs"     enable row level security;

do $$
declare
  t text;
  p record;
begin
  foreach t in array array['AttendanceSettings', 'AttendanceDevices', 'AttendanceLogs']
  loop
    for p in select policyname from pg_policies
             where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
  end loop;
end $$;

-- ตั้งค่า: ทุกคนในโรงเรียนอ่านได้ (app ต้องรู้ว่าเปิดใช้ไหม / เวลาเข้างาน)
--         แก้ได้เฉพาะผู้ดูแลส่วนกลาง (ตั้งจาก web)
create policy attendance_settings_select on "AttendanceSettings"
  for select to authenticated
  using (public.can_see_school(id_school));
create policy attendance_settings_write on "AttendanceSettings"
  for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

-- เครื่องสแกน: แอดมินโรงเรียนดูของโรงเรียนตัวเองได้ / ลงทะเบียนได้เฉพาะส่วนกลาง
create policy attendance_devices_select on "AttendanceDevices"
  for select to authenticated
  using (public.is_admin() and public.can_see_school(id_school));
create policy attendance_devices_write on "AttendanceDevices"
  for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

-- การสแกน
create policy attendance_logs_select on "AttendanceLogs"
  for select to authenticated
  using ((id_user is not null and id_user = public.current_teacher_id())
         or (public.is_admin() and public.can_see_school(id_school)));

-- เพิ่มผ่าน app ได้เฉพาะแอดมิน และเฉพาะนำเข้าไฟล์ / เพิ่มให้
-- (source = device มาทาง Edge Function ด้วย service role เท่านั้น)
create policy attendance_logs_insert on "AttendanceLogs"
  for insert to authenticated
  with check (public.is_admin()
              and public.can_see_school(id_school)
              and source in ('import', 'manual'));

-- ลบได้เฉพาะที่นำเข้า/เพิ่มเอง ข้อมูลจากเครื่องลบได้เฉพาะส่วนกลาง
create policy attendance_logs_delete on "AttendanceLogs"
  for delete to authenticated
  using (public.is_super_admin()
         or (public.is_admin()
             and public.can_see_school(id_school)
             and source in ('import', 'manual')));

-- ไม่มี policy update — การสแกนแก้ไม่ได้ (ผิดให้ลบแล้วเพิ่มใหม่ มีประวัติ)


-- ให้ PostgREST รีโหลด schema เพื่อให้ app มองเห็นตารางใหม่ทันที
notify pgrst, 'reload schema';


-- ----------------------------------------------------------------------------
-- 8) ตรวจผล
--    ทุกตารางต้อง rowsecurity = true
--    policy: AttendanceSettings 2 / AttendanceDevices 2 / AttendanceLogs 3
--    trigger: AttendanceLogs 1
--    แถวตั้งค่า = จำนวนโรงเรียน
-- ----------------------------------------------------------------------------

select c.tablename,
       c.rowsecurity,
       (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = c.tablename) as policies,
       (select count(*) from pg_trigger g
         where g.tgrelid = format('public.%I', c.tablename)::regclass
           and not g.tgisinternal)                                      as triggers
from pg_tables c
where c.schemaname = 'public'
  and c.tablename in ('AttendanceSettings', 'AttendanceDevices', 'AttendanceLogs')
union all
select 'แถวตั้งค่า / โรงเรียน',
       (select count(*) from public."AttendanceSettings")
         = (select count(*) from public."Schools"),
       (select count(*) from public."AttendanceSettings"),
       (select count(*) from public."Schools")
order by 1;
