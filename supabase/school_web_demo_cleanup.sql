-- ============================================================================
--  โรงเรียนทดลองใช้ (Demo) — พาร์ท 5: ลบบัญชีหมดอายุอัตโนมัติ + กันแจ้งเตือนรั่ว
--
--  รันซ้ำได้ · ไม่กระทบแอปวันลา · ต้องรันหลัง school_web_demo_signup.sql
--  ⚠️ ต้องเปิดส่วนขยาย pg_cron ก่อน (Dashboard → Database → Extensions → pg_cron)
--     ถ้ายังไม่เปิด ไฟล์นี้ยังรันผ่าน แต่จะไม่ตั้งเวลาให้ (มีข้อความแจ้ง)
--
--  cleanup_expired_demo_accounts()  ลบบัญชีทดลองที่หมดอายุ: สิทธิ์ฝ่าย, คืนคาบสอน/ห้องที่ปรึกษา,
--                                   แถว Teachers, บัญชีล็อกอิน (auth.users), SchoolWebDemoAccounts
--                                   ลบได้เฉพาะบัญชีในโรงเรียนทดลองเท่านั้น
--  ตั้งเวลา: ทุกวัน 03:00 น. (ไทย) = 20:00 UTC
--  ปิด LINE ของโรงเรียนทดลอง (กันใบลาทดลองไปโผล่กลุ่ม LINE จริง)
-- ============================================================================

create or replace function public.cleanup_expired_demo_accounts()
returns int
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  r       record;
  n       int := 0;
  base    bigint;
begin
  for r in
    select a.id_user, a.id_school, a.auth_uid
    from public."SchoolWebDemoAccounts" a
    where a.expires_at < now()
      and public.is_demo_school(a.id_school)
  loop
    base := -(100000 + r.id_user * 100);

    delete from public."Permissions"
    where id_school = r.id_school and id_role = 22
      and menu_id between base - 99 and base;

    update public."SchoolWebTeachingSchedules" set teacher_id = null
    where id_school = r.id_school and teacher_id = r.id_user;
    update public."SchoolWebClassrooms" set advisor_teacher_id = null
    where id_school = r.id_school and advisor_teacher_id = r.id_user;

    begin
      delete from public."Teachers" where id_user = r.id_user and id_school = r.id_school;
    exception when foreign_key_violation then
      -- มีข้อมูลอื่นอ้างถึง (เช่น ใบลา) → เก็บแถวไว้ แต่ตัดบัญชีล็อกอิน
      update public."Teachers" set auth_uid = null where id_user = r.id_user;
    end;

    if r.auth_uid is not null then
      delete from auth.users where id = r.auth_uid;
    end if;

    delete from public."SchoolWebDemoAccounts" where id_user = r.id_user;
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- เรียกได้เฉพาะ postgres / pg_cron (ไม่เปิดให้ผู้ใช้เรียกผ่าน API)
revoke all on function public.cleanup_expired_demo_accounts() from public, anon, authenticated;

-- ปิด LINE ของโรงเรียนทดลอง
update public."SchoolLineSettings" l
set enabled = false
where public.is_demo_school(l.id_school) and l.enabled;

-- ตั้งเวลาทุกวัน 03:00 น. ไทย (20:00 UTC)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'demo-cleanup';
    perform cron.schedule('demo-cleanup', '0 20 * * *', 'select public.cleanup_expired_demo_accounts()');
    raise notice 'ตั้งเวลาลบบัญชีทดลองหมดอายุแล้ว (ทุกวัน 03:00 น.)';
  else
    raise notice 'ยังไม่ได้เปิด pg_cron — เปิดที่ Database → Extensions แล้วรันไฟล์นี้ซ้ำ';
  end if;
end;
$$;

insert into public."SchemaMigrations"(name) values ('school_web_demo_cleanup.sql') on conflict do nothing;

