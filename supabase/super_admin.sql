-- ============================================================================
--  ผู้ดูแลระบบส่วนกลาง (ดูแลทั้งโปรแกรม ทุกโรงเรียน) — username: koragoch
--
--  ⚠️ repo นี้เป็นสาธารณะ ไฟล์นี้จึง "ไม่มีรหัสผ่าน" — ตั้งรหัสใน Dashboard เอง
--
--  วิธีทำ (ทำตามลำดับ):
--    1) Supabase Dashboard > Authentication > Users > Add user > Create new user
--         Email:    koragoch@leave.local
--         Password: (รหัสที่ต้องการ)
--         ติ๊ก Auto Confirm User
--    2) SQL Editor > วางทั้งไฟล์นี้ > Run
--    3) ดูผลท้ายไฟล์: ผูกบัญชี_auth ต้องเป็น true
--
--  รันซ้ำได้ ไม่พัง ต้องรัน multi_school_step1_id_school.sql มาก่อนแล้ว
--
--  ต่างจากผู้ดูแลระบบของโรงเรียนอย่างไร:
--    - role ยังเป็น "ผู้ดูแลระบบ" (22) เมนูทุกหน้าจึงใช้ได้เหมือนแอดมินปกติ
--    - มีธง is_super_admin = true ซึ่ง RLS ชั้นที่ 3 จะใช้ให้เห็นทุกโรงเรียน
--    - ตอนนี้ในแอปยังเห็นแค่โรงเรียนที่สังกัด (โรงเรียนแรก) ปุ่มสลับโรงเรียน
--      จะทำตอนมีโรงเรียนที่ 2
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ธงผู้ดูแลระบบส่วนกลาง
-- ----------------------------------------------------------------------------

alter table public."Teachers"
  add column if not exists is_super_admin boolean not null default false;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select t.is_super_admin from "Teachers" t
      where t.auth_uid = auth.uid() limit 1),
    false);
$$;

grant execute on function public.is_super_admin() to authenticated;


-- ----------------------------------------------------------------------------
-- 2) กันการแต่งตั้งตัวเอง
--
--    policy ปัจจุบันให้แอดมินโรงเรียนแก้แถว Teachers ได้ ถ้าไม่กันไว้
--    แอดมินโรงเรียนไหนก็ติ๊ก is_super_admin ให้ตัวเองแล้วเห็นทุกโรงเรียนได้
--    เปลี่ยนค่านี้ได้เฉพาะผู้ดูแลส่วนกลาง หรือจาก SQL Editor (ไม่มีผู้ล็อกอิน)
-- ----------------------------------------------------------------------------

create or replace function public.guard_super_admin_flag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.is_super_admin()
     and (
       (tg_op = 'INSERT' and new.is_super_admin)
       or (tg_op = 'UPDATE' and new.is_super_admin is distinct from old.is_super_admin)
     ) then
    raise exception 'ไม่มีสิทธิ์กำหนดผู้ดูแลระบบส่วนกลาง';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_super_admin_flag on public."Teachers";
create trigger guard_super_admin_flag
  before insert or update on public."Teachers"
  for each row execute function public.guard_super_admin_flag();


-- ----------------------------------------------------------------------------
-- 3) สร้าง/อัปเดตบัญชี koragoch ในตาราง Teachers แล้วผูกกับบัญชี Auth
-- ----------------------------------------------------------------------------

do $$
declare
  admin_role  bigint;
  home_school bigint;
  uid         uuid;
begin
  select "ID_Roles" into admin_role
  from public.roles where "Accessrights" = 'ผู้ดูแลระบบ' limit 1;
  if admin_role is null then
    raise exception 'ไม่พบ role "ผู้ดูแลระบบ" ในตาราง roles';
  end if;

  select min(id_school) into home_school from public."Schools";

  select id into uid from auth.users
  where lower(email) = 'koragoch@leave.local' limit 1;
  if uid is null then
    raise warning 'ยังไม่มีบัญชี Auth koragoch@leave.local — ทำขั้นที่ 1 ก่อน '
                  'แล้วรันไฟล์นี้ใหม่ (ตอนนี้สร้างแถว Teachers ไว้ก่อน)';
  end if;

  if exists (select 1 from public."Teachers"
             where lower(trim(username)) = 'koragoch') then
    update public."Teachers"
       set id_role        = admin_role,
           is_super_admin = true,
           auth_uid       = coalesce(uid, auth_uid)
     where lower(trim(username)) = 'koragoch';
  else
    insert into public."Teachers"
      (username, "fullName", id_role, id_school, is_super_admin, auth_uid)
    values
      ('koragoch', 'ผู้ดูแลระบบส่วนกลาง', admin_role, home_school, true, uid);
  end if;
end $$;


-- ----------------------------------------------------------------------------
-- 4) ตรวจผล — ผูกบัญชี_auth ต้องเป็น true, ส่วนกลาง ต้องเป็น true
-- ----------------------------------------------------------------------------

select t.id_user,
       t.username,
       t."fullName",
       r."Accessrights"          as สิทธิ์,
       t.is_super_admin          as ส่วนกลาง,
       t.id_school,
       (t.auth_uid is not null)  as ผูกบัญชี_auth
from public."Teachers" t
left join public.roles r on r."ID_Roles" = t.id_role
where lower(trim(t.username)) = 'koragoch';
