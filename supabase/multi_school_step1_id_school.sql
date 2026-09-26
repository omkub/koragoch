-- ============================================================================
--  Multi-school ชั้นที่ 1 — เพิ่ม id_school ให้ตารางที่ต้องแยกตามโรงเรียน
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--  ต้องรัน enable_rls.sql และ create_schools_table.sql มาก่อนแล้ว
--
--  ไฟล์นี้ "ไม่เปลี่ยนพฤติกรรมของแอป" — ตอนนี้มีโรงเรียนเดียว ทุกแถวจึงได้
--  id_school ของโรงเรียนนั้น แอปเดิมที่ไม่รู้จักคอลัมน์นี้ยังทำงานได้เหมือนเดิม
--  เพราะฐานข้อมูลเติมค่าให้เองตอน insert (ดูข้อ 3)
--
--  ⚠️ ไฟล์นี้ยังไม่กันการมองข้ามโรงเรียน — นั่นคือชั้นที่ 3 (แก้ RLS)
--     ห้ามเพิ่มโรงเรียนที่ 2 ที่มีข้อมูลจริงก่อนทำชั้นที่ 3 เสร็จ
--
--  ตารางที่แยกตามโรงเรียน:
--    Teachers     ครูสังกัดโรงเรียนเดียว
--    Leaves       ตามโรงเรียนของเจ้าของใบลา (ฐานข้อมูลดึงให้เอง)
--    LoginLogs    ตามโรงเรียนของผู้ล็อกอิน (ฐานข้อมูลดึงให้เอง)
--    departments  กลุ่มสาระของแต่ละโรงเรียน
--    adminroles   ตำแหน่งบริหารของแต่ละโรงเรียน
--
--  ตารางที่ใช้ร่วมกันทุกโรงเรียน (ไม่เพิ่ม id_school):
--    FiscalRounds (ตกลงกันไว้แล้ว), roles, positions, academics,
--    LeaveTypes, LeaveReasons, Permissions, MobilePermissions
--
--  ยังไม่ตัดสินใจ — ค่อยทำทีหลัง:
--    Settings              ต้องแยก LINE groupId ต่อโรงเรียน แต่ channelToken
--                          ใช้ร่วมกัน รอทำพร้อมความปลอดภัยข้อ 2
--    SpecialHolidays /     วันหยุดราชการใช้ร่วมกัน แต่วันหยุดเฉพาะโรงเรียน
--    SpecialWorkingDays    ต้องแยก (อาจใช้ id_school = null แปลว่าทุกโรงเรียน)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) เพิ่มคอลัมน์ + เติมค่าให้ข้อมูลเดิม + บังคับไม่ให้ว่าง
--
--    ข้อมูลเดิมทั้งหมดเป็นของโรงเรียนแรก (id_school น้อยที่สุดในตาราง Schools)
--    ใบลากับประวัติล็อกอินเติมตามโรงเรียนของครูเจ้าของแถว
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
  first_school bigint;
begin
  select min(id_school) into first_school from public."Schools";
  if first_school is null then
    raise exception 'ตาราง Schools ยังไม่มีข้อมูล — รัน create_schools_table.sql ก่อน';
  end if;

  foreach t in array array[
    'Teachers', 'Leaves', 'LoginLogs', 'departments', 'adminroles'
  ]
  loop
    execute format(
      'alter table public.%I add column if not exists id_school bigint '
      'references public."Schools"(id_school)', t);

    -- ครูและตารางข้อมูลหลัก → โรงเรียนแรก
    if t in ('Teachers', 'departments', 'adminroles') then
      execute format(
        'update public.%I set id_school = $1 where id_school is null', t)
        using first_school;
    end if;
  end loop;

  -- ใบลา/ประวัติล็อกอิน → ตามโรงเรียนของเจ้าของ (ถ้าหาครูไม่เจอ ใช้โรงเรียนแรก)
  update public."Leaves" l
     set id_school = coalesce(
           (select t.id_school from public."Teachers" t where t.id_user = l.id_user),
           first_school)
   where l.id_school is null;

  update public."LoginLogs" g
     set id_school = coalesce(
           (select t.id_school from public."Teachers" t where t.id_user = g.id_user),
           first_school)
   where g.id_school is null;

  foreach t in array array[
    'Teachers', 'Leaves', 'LoginLogs', 'departments', 'adminroles'
  ]
  loop
    execute format(
      'alter table public.%I alter column id_school set not null', t);
    execute format(
      'create index if not exists %I on public.%I (id_school)',
      t || '_id_school_idx', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 2) ฟังก์ชันผู้ช่วย: โรงเรียนของคนที่ล็อกอินอยู่
--
--    security definer เหตุผลเดียวกับ current_teacher_id() ใน enable_rls.sql
--    ชั้นที่ 3 (RLS) จะใช้ฟังก์ชันนี้ด้วย
--    ต้องสร้างหลังข้อ 1 เพราะ Postgres ตรวจว่าคอลัมน์ id_school มีอยู่จริง
-- ----------------------------------------------------------------------------

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
  limit 1;
$$;

grant execute on function public.current_school_id() to authenticated;


-- ----------------------------------------------------------------------------
-- 3) เติม id_school ให้อัตโนมัติตอน insert/update
--
--    แอปตอนนี้ (รวมถึงแท็บนำเข้าข้อมูลที่ห้ามแตะ) ไม่ได้ส่ง id_school มา
--    trigger นี้ทำให้แอปเดิมทำงานต่อได้โดยไม่ต้องแก้โค้ดสักบรรทัด
--
--    Leaves / LoginLogs: ใช้โรงเรียนของครูเจ้าของแถว "เสมอ" ไม่เชื่อค่าที่
--      ส่งมาจากแอป — กันการยื่นใบลาไปโผล่ในโรงเรียนอื่น
--    Teachers / departments / adminroles: ถ้าไม่ส่งมา ใช้โรงเรียนของ
--      คนที่กำลังล็อกอิน (แอดมินเพิ่มครู = ครูเข้าโรงเรียนของแอดมิน)
--      ถ้าไม่มีคนล็อกอิน (SQL Editor / Edge Function) และมีโรงเรียนเดียว
--      ใช้โรงเรียนนั้น
-- ----------------------------------------------------------------------------

create or replace function public.fill_id_school()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_school bigint;
  only_school  bigint;
begin
  if tg_table_name in ('Leaves', 'LoginLogs') then
    select t.id_school into owner_school
    from "Teachers" t where t.id_user = new.id_user;
    if owner_school is not null then
      new.id_school := owner_school;
    end if;
  end if;

  if new.id_school is null then
    new.id_school := public.current_school_id();
  end if;

  if new.id_school is null then
    select min(id_school) into only_school
    from "Schools"
    having count(*) = 1;
    new.id_school := only_school;
  end if;

  -- ครูที่ไม่ใช่แอดมินย้ายโรงเรียนตัวเองไม่ได้ (policy teachers_update_self
  -- อนุญาตให้แก้แถวตัวเอง ถ้าไม่กันไว้ ชั้นที่ 3 จะถูกเลี่ยงได้)
  if tg_op = 'UPDATE'
     and tg_table_name = 'Teachers'
     and new.id_school is distinct from old.id_school
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'ไม่มีสิทธิ์ย้ายโรงเรียน';
  end if;

  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'Teachers', 'Leaves', 'LoginLogs', 'departments', 'adminroles'
  ]
  loop
    execute format('drop trigger if exists fill_id_school on public.%I', t);
    execute format(
      'create trigger fill_id_school before insert or update on public.%I '
      'for each row execute function public.fill_id_school()', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 4) username ห้ามซ้ำทั้งระบบ (ล็อกอินไม่ต้องเลือกโรงเรียน)
--
--    ไม่สนตัวพิมพ์เล็ก/ใหญ่ เพราะอีเมลสังเคราะห์ username@leave.local
--    ของ Supabase Auth ก็ไม่สนเหมือนกัน
--    ถ้ามีซ้ำอยู่แล้ว จะไม่สร้าง index แต่แจ้งชื่อที่ซ้ำให้ไปแก้ก่อน
-- ----------------------------------------------------------------------------

do $$
declare
  dup text;
begin
  select string_agg(u, ', ') into dup
  from (
    select lower(trim(username)) as u
    from public."Teachers"
    where username is not null and trim(username) <> ''
    group by 1 having count(*) > 1
  ) d;

  if dup is not null then
    raise warning 'username ซ้ำกัน: % — แก้ให้ไม่ซ้ำแล้วรันไฟล์นี้ใหม่', dup;
  else
    create unique index if not exists teachers_username_unique
      on public."Teachers" (lower(trim(username)))
      where username is not null and trim(username) <> '';
  end if;
end $$;


-- ----------------------------------------------------------------------------
-- 5) ตรวจผล
--    ทุกแถว: ไม่มีแถวไหน id_school ว่าง (แถว_ว่าง = 0)
--    มี trigger ครบ 5 ตาราง และ index username (ถ้าไม่มีชื่อซ้ำ)
-- ----------------------------------------------------------------------------

select 'Teachers' as ตาราง, count(*) as ทั้งหมด,
       count(*) filter (where id_school is null) as แถว_ว่าง
  from public."Teachers"
union all
select 'Leaves', count(*), count(*) filter (where id_school is null)
  from public."Leaves"
union all
select 'LoginLogs', count(*), count(*) filter (where id_school is null)
  from public."LoginLogs"
union all
select 'departments', count(*), count(*) filter (where id_school is null)
  from public.departments
union all
select 'adminroles', count(*), count(*) filter (where id_school is null)
  from public.adminroles
union all
select 'trigger fill_id_school', count(*), null
  from pg_trigger where tgname = 'fill_id_school'
union all
select 'index username ไม่ซ้ำ', count(*), null
  from pg_indexes where indexname = 'teachers_username_unique';


-- ----------------------------------------------------------------------------
-- ย้อนกลับ (ถ้าจำเป็น) — ลบ comment แล้วรันเฉพาะส่วนนี้
-- ----------------------------------------------------------------------------
-- do $$
-- declare t text;
-- begin
--   foreach t in array array['Teachers','Leaves','LoginLogs','departments','adminroles']
--   loop
--     execute format('drop trigger if exists fill_id_school on public.%I', t);
--     execute format('alter table public.%I drop column if exists id_school', t);
--   end loop;
-- end $$;
-- drop index if exists public.teachers_username_unique;
-- drop function if exists public.fill_id_school();
-- drop function if exists public.current_school_id();
