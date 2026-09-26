-- ============================================================================
--  ความปลอดภัยข้อ 3 — ย้ายรหัสผ่านออกจากตาราง Teachers ไปตารางที่แอดมินอ่านได้คนเดียว
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--  ต้องรันก่อนแล้ว: multi_school_step3_rls.sql, admin_role_by_id.sql
--  ⚠️ deploy Edge Function clever-responder เวอร์ชันใหม่ "ก่อน" รันไฟล์นี้
--     ไม่งั้นปุ่มดูรหัสผ่าน/ลืมรหัสผ่านจะอ่านรหัสไม่เจอ
--
--  ปัญหา: Teachers เก็บ password / tempResetCode / tempPassword เป็นข้อความ
--  ธรรมดา และครูทุกคนอ่านแถว Teachers ทั้งโรงเรียนได้ (หน้าปฏิทิน/บุคลากร
--  ต้องใช้ชื่อ) → เปิด devtools ก็เห็นรหัสของทุกคน รวมถึงผู้ดูแลระบบ
--
--  ทางแก้ (ตามที่เจ้าของกำหนด: ห้ามลบคอลัมน์ password, แอดมินต้องดูได้):
--    - ตารางใหม่ TeacherPasswords อ่านได้เฉพาะผู้ดูแลระบบของโรงเรียนนั้น
--    - ย้ายค่าเดิมไปไว้ในตารางใหม่ แล้วทำให้คอลัมน์ใน Teachers ว่าง
--    - trigger: ใครเขียนรหัสลง Teachers (แอป / Edge Function / แท็บนำเข้า)
--      ระบบย้ายไปตารางใหม่ให้อัตโนมัติ คอลัมน์ใน Teachers จึงว่างเสมอ
--      โค้ดเดิมที่เขียน Teachers.password ทำงานต่อได้โดยไม่ต้องแก้
--    - เขียนค่าว่าง ('' หรือ null) ถือว่า "ไม่เปลี่ยน" กันฟอร์มที่ส่งช่องว่าง
--      มาลบรหัสเดิมทิ้ง (การล้างค่าทำที่ตาราง TeacherPasswords โดยตรง)
--
--  คอลัมน์ Teachers.password ยังอยู่ (ไม่ได้ DROP) แค่ไม่มีค่าเก็บไว้
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ตารางเก็บรหัส
--
--    FK แบบ deferrable เพราะ trigger ข้อ 3 เขียนตารางนี้ตอน BEFORE INSERT
--    ของ Teachers ซึ่งแถวครูยังไม่ถูกบันทึก
-- ----------------------------------------------------------------------------

create table if not exists public."TeacherPasswords" (
  id_user          bigint primary key
                   references public."Teachers"(id_user)
                   on delete cascade
                   deferrable initially deferred,
  password         text,
  "tempResetCode"  text,
  "tempPassword"   text,
  "updatedAt"      timestamptz default now()
);

comment on table public."TeacherPasswords" is
  'รหัสผ่านครู (สำเนาที่แอดมินดูได้) — อ่านได้เฉพาะผู้ดูแลระบบของโรงเรียนนั้น';


-- ----------------------------------------------------------------------------
-- 2) RLS: อ่านได้เฉพาะผู้ดูแลระบบ (id_role 22) ของโรงเรียนเดียวกัน
--
--    ไม่มี policy เขียนเลย — เขียนได้ทาง trigger ข้อ 3 (ผ่านสิทธิ์แก้ Teachers
--    ตาม RLS เดิม) และ Edge Function (service_role) เท่านั้น
-- ----------------------------------------------------------------------------

create or replace function public.teacher_school(target bigint)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select id_school from "Teachers" where id_user = target;
$$;

grant execute on function public.teacher_school(bigint) to authenticated;

alter table public."TeacherPasswords" enable row level security;

do $$
declare
  p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'TeacherPasswords'
  loop
    execute format('drop policy %I on public."TeacherPasswords"', p.policyname);
  end loop;
end $$;

create policy teacher_passwords_admin_select on "TeacherPasswords"
  for select to authenticated
  using (public.is_admin()
         and public.can_see_school(public.teacher_school(id_user)));


-- ----------------------------------------------------------------------------
-- 3) trigger: รหัสที่เขียนลง Teachers → ย้ายไป TeacherPasswords
-- ----------------------------------------------------------------------------

create or replace function public.move_teacher_secrets()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_password text := nullif(new.password, '');
  v_reset    text := nullif(to_jsonb(new) ->> 'tempResetCode', '');
  v_temp     text := nullif(to_jsonb(new) ->> 'tempPassword', '');
begin
  if v_password is not null or v_reset is not null or v_temp is not null then
    insert into "TeacherPasswords" as tp
      (id_user, password, "tempResetCode", "tempPassword", "updatedAt")
    values (new.id_user, v_password, v_reset, v_temp, now())
    on conflict (id_user) do update set
      password        = coalesce(excluded.password, tp.password),
      "tempResetCode" = coalesce(excluded."tempResetCode", tp."tempResetCode"),
      "tempPassword"  = coalesce(excluded."tempPassword", tp."tempPassword"),
      "updatedAt"     = now();
  end if;

  -- ล้างค่าออกจาก Teachers เสมอ
  -- (สองคอลัมน์หลังใช้ jsonb_populate_record เผื่อบางคอลัมน์ไม่มีในตาราง)
  new.password := null;
  if to_jsonb(new) ? 'tempResetCode' then
    new := jsonb_populate_record(new, '{"tempResetCode": null}');
  end if;
  if to_jsonb(new) ? 'tempPassword' then
    new := jsonb_populate_record(new, '{"tempPassword": null}');
  end if;
  return new;
end;
$$;


-- ----------------------------------------------------------------------------
-- 4) ย้ายข้อมูลเดิม แล้วติด trigger
-- ----------------------------------------------------------------------------

do $$
declare
  has_reset boolean;
  has_temp  boolean;
begin
  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'Teachers'
                   and column_name = 'tempResetCode') into has_reset;
  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'Teachers'
                   and column_name = 'tempPassword') into has_temp;

  execute format($f$
    insert into public."TeacherPasswords" as tp
      (id_user, password, "tempResetCode", "tempPassword")
    select id_user,
           nullif(password, ''),
           %s,
           %s
    from public."Teachers"
    where coalesce(password, '') <> '' %s %s
    on conflict (id_user) do update set
      password        = coalesce(excluded.password, tp.password),
      "tempResetCode" = coalesce(excluded."tempResetCode", tp."tempResetCode"),
      "tempPassword"  = coalesce(excluded."tempPassword", tp."tempPassword"),
      "updatedAt"     = now()
  $f$,
    case when has_reset then 'nullif("tempResetCode", '''')' else 'null' end,
    case when has_temp  then 'nullif("tempPassword", '''')'  else 'null' end,
    case when has_reset then 'or coalesce("tempResetCode", '''') <> ''''' else '' end,
    case when has_temp  then 'or coalesce("tempPassword", '''') <> '''''  else '' end);

  -- ล้างค่าใน Teachers (ปิด trigger อื่นชั่วคราวไม่ได้ใน SQL Editor
  -- แต่ไม่จำเป็น: trigger ทุกตัวปล่อยผ่านเมื่อไม่มีผู้ล็อกอิน)
  execute 'update public."Teachers" set password = null where password is not null';
  if has_reset then
    execute 'update public."Teachers" set "tempResetCode" = null where "tempResetCode" is not null';
  end if;
  if has_temp then
    execute 'update public."Teachers" set "tempPassword" = null where "tempPassword" is not null';
  end if;
end $$;

drop trigger if exists move_teacher_secrets on public."Teachers";
create trigger move_teacher_secrets
  before insert or update on public."Teachers"
  for each row execute function public.move_teacher_secrets();


-- ----------------------------------------------------------------------------
-- 5) ตรวจผล
--    รหัสที่ย้ายแล้ว ควรเท่ากับจำนวนครูที่เคยมีรหัส (ประมาณ 68)
--    รหัสที่ยังค้างใน_Teachers ต้องเป็น 0
-- ----------------------------------------------------------------------------

select
  (select count(*) from public."TeacherPasswords"
    where password is not null)                         as รหัสที่ย้ายแล้ว,
  (select count(*) from public."Teachers"
    where coalesce(password, '') <> '')                 as รหัสที่ยังค้างใน_Teachers,
  (select rowsecurity from pg_tables
    where schemaname = 'public' and tablename = 'TeacherPasswords') as เปิด_rls;
