-- ============================================================================
--  สิทธิ์แบบละเอียด รอบ 1 — เพดานของสิทธิ์ต่อโรงเรียน + ปรับรายคน
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (ค่าที่ตั้งไว้แล้วไม่ถูกทับ)
--  ต้องรันก่อนแล้ว: multi_school_step3_rls.sql, admin_role_by_id.sql
--
--  รอบนี้ "ยังไม่เปลี่ยนการทำงานของแอป" — แค่สร้างตาราง + ฟังก์ชัน + ค่าเริ่มต้น
--  ให้ตั้งค่าได้จากเว็บส่วนกลาง (รอบ 2 แอปอ่านสิทธิ์ใหม่, รอบ 3 RLS ใช้สิทธิ์ใหม่)
--
--  แนวคิด:
--    PermissionItems  รายการสิทธิ์ทั้งหมด (กำหนดในระบบ)
--    RolePermissions  เพดาน: โรงเรียน × สิทธิ์ (role) × รายการ → อนุญาตไหม
--                     แก้ได้เฉพาะผู้ดูแลส่วนกลาง
--    UserPermissions  ปรับรายคน: ครู × รายการ → เปิด/ปิด (ไม่มีแถว = ตามเพดาน)
--                     แก้ได้โดยแอดมินของโรงเรียนนั้น / ผู้ดูแลส่วนกลาง
--
--  สิทธิ์ที่ใช้ได้จริง = เพดาน AND (รายคน ถ้าตั้งไว้)
--  ตั้งรายคนให้ "เปิด" เกินเพดานไม่ได้ — ฐานข้อมูลปฏิเสธ
--  ผู้ดูแลส่วนกลางได้ทุกรายการเสมอ (กันล็อกตัวเองออก)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) รายการสิทธิ์
--    menu_id = รหัสเมนูเดิมในตาราง Permissions (ใช้ตั้งค่าเริ่มต้นให้ตรงของเดิม)
-- ----------------------------------------------------------------------------

create table if not exists public."PermissionItems" (
  key        text primary key,
  "group"    text not null,
  label      text not null,
  sort       int  not null default 0,
  menu_id    int
);

insert into public."PermissionItems"(key, "group", label, sort, menu_id) values
  ('menu.dashboard',        'เมนู',        'แดชบอร์ด',                         10, 0),
  ('menu.leave_submit',     'เมนู',        'ส่งใบลา',                          11, 2),
  ('menu.leave_history',    'เมนู',        'ประวัติการลา',                      12, 3),
  ('menu.calendar',         'เมนู',        'ปฏิทินกิจกรรมส่วนกลาง',             13, 8),
  ('menu.report',           'เมนู',        'รายงานสรุปการลา',                   14, 1),
  ('menu.personnel',        'เมนู',        'บุคลากร (กลุ่มสาระ)',               15, 5),
  ('menu.login_logs',       'เมนู',        'ประวัติการเข้าใช้งาน',               16, 7),
  ('menu.admin',            'เมนู',        'จัดการระบบ',                        17, 4),
  ('view.all_leaves',       'การมองเห็น',   'เห็นใบลาของทุกคนในโรงเรียน',        20, null),
  ('leave.approve',         'ใบลา',        'อนุมัติ / เปลี่ยนสถานะใบลา',          30, null),
  ('leave.receive_number',  'ใบลา',        'กำหนดเลขรับใบลา',                   31, null),
  ('leave.edit_others',     'ใบลา',        'แก้ไขใบลาของคนอื่น',                 32, null),
  ('leave.delete_others',   'ใบลา',        'ลบใบลาของคนอื่น',                   33, null),
  ('leave.submit_for_others','ใบลา',       'ส่งใบลาแทนคนอื่น',                   34, null),
  ('staff.manage',          'บุคลากร',      'เพิ่ม / แก้ไขข้อมูลครู',              40, null),
  ('staff.reset_password',  'บุคลากร',      'รีเซ็ตรหัสผ่าน',                    41, null),
  ('staff.view_password',   'บุคลากร',      'ดูรหัสผ่าน',                       42, null),
  ('settings.master',       'ตั้งค่า',       'ข้อมูลหลัก (กลุ่มสาระ ประเภทลา ฯลฯ)', 50, null),
  ('settings.calendar',     'ตั้งค่า',       'ปฏิทิน / วันหยุด / ปีงบประมาณ',       51, null),
  ('settings.school',       'ตั้งค่า',       'ข้อมูลโรงเรียน',                     52, null),
  ('settings.import',       'ตั้งค่า',       'นำเข้าข้อมูล',                       53, null)
on conflict (key) do update set
  "group" = excluded."group", label = excluded.label,
  sort = excluded.sort, menu_id = excluded.menu_id;


-- ----------------------------------------------------------------------------
-- 2) เพดานของสิทธิ์ต่อโรงเรียน / ปรับรายคน
-- ----------------------------------------------------------------------------

create table if not exists public."RolePermissions" (
  id_school   bigint not null references public."Schools"(id_school) on delete cascade,
  id_role     bigint not null references public.roles("ID_Roles") on delete cascade,
  item_key    text   not null references public."PermissionItems"(key) on delete cascade,
  allowed     boolean not null default false,
  "updatedAt" timestamptz default now(),
  primary key (id_school, id_role, item_key)
);

create table if not exists public."UserPermissions" (
  id_user     bigint not null references public."Teachers"(id_user) on delete cascade,
  item_key    text   not null references public."PermissionItems"(key) on delete cascade,
  allowed     boolean not null,
  "updatedAt" timestamptz default now(),
  primary key (id_user, item_key)
);


-- ----------------------------------------------------------------------------
-- 3) ฟังก์ชันตรวจสิทธิ์ (รอบ 2/3 แอปและ RLS จะเรียกใช้)
-- ----------------------------------------------------------------------------

-- โรงเรียนของครูคนหนึ่ง (นิยามเดียวกับใน teacher_passwords.sql — ใส่ซ้ำไว้
-- เพื่อให้ไฟล์นี้รันได้โดยไม่ต้องพึ่งลำดับไฟล์อื่น)
create or replace function public.teacher_school(target bigint)
returns bigint
language sql stable security definer set search_path = public
as $$
  select id_school from "Teachers" where id_user = target;
$$;
grant execute on function public.teacher_school(bigint) to authenticated;

-- เพดานของสิทธิ์นั้นในโรงเรียนนั้นอนุญาตรายการนี้ไหม (ไม่มีแถว = ไม่อนุญาต)
create or replace function public.role_allows(p_school bigint, p_role bigint, p_key text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce((select allowed from "RolePermissions"
                   where id_school = p_school and id_role = p_role
                     and item_key = p_key), false);
$$;

-- สิทธิ์ที่ใช้ได้จริงของครูคนหนึ่ง
create or replace function public.user_has_permission(p_user bigint, p_key text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case
    when t.id_user is null then false
    when t.is_super_admin and t.id_role = 22 then true
    else public.role_allows(t.id_school, t.id_role, p_key)
         and coalesce((select u.allowed from "UserPermissions" u
                        where u.id_user = t.id_user and u.item_key = p_key), true)
  end
  from (select 1) dummy
  left join "Teachers" t on t.id_user = p_user;
$$;

-- ของคนที่ล็อกอินอยู่
create or replace function public.has_permission(p_key text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.user_has_permission(public.current_teacher_id(), p_key);
$$;

-- รายการทั้งหมดที่คนที่ล็อกอินอยู่ทำได้ (แอปโหลดครั้งเดียวตอนล็อกอิน — รอบ 2)
create or replace function public.my_permissions()
returns setof text
language sql stable security definer set search_path = public
as $$
  select p.key from "PermissionItems" p
  where public.has_permission(p.key)
  order by p.sort;
$$;

grant execute on function public.role_allows(bigint, bigint, text)  to authenticated;
grant execute on function public.user_has_permission(bigint, text) to authenticated;
grant execute on function public.has_permission(text)              to authenticated;
grant execute on function public.my_permissions()                  to authenticated;


-- ----------------------------------------------------------------------------
-- 4) RLS
-- ----------------------------------------------------------------------------

alter table public."PermissionItems" enable row level security;
alter table public."RolePermissions" enable row level security;
alter table public."UserPermissions" enable row level security;

do $$
declare
  t text;
  p record;
begin
  foreach t in array array['PermissionItems', 'RolePermissions', 'UserPermissions']
  loop
    for p in select policyname from pg_policies
             where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
  end loop;
end $$;

-- รายการสิทธิ์: ทุกคนอ่านได้ ไม่มีใครแก้ผ่านแอป
create policy permission_items_select on "PermissionItems"
  for select to authenticated using (true);

-- เพดาน: คนในโรงเรียนอ่านของโรงเรียนตัวเองได้ / แก้ได้เฉพาะส่วนกลาง
create policy role_permissions_select on "RolePermissions"
  for select to authenticated using (public.can_see_school(id_school));
create policy role_permissions_write on "RolePermissions"
  for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

-- รายคน: เจ้าตัวอ่านของตัวเองได้ / แอดมินโรงเรียนนั้นอ่าน-แก้ได้
create policy user_permissions_select on "UserPermissions"
  for select to authenticated
  using (id_user = public.current_teacher_id()
         or (public.is_admin()
             and public.can_see_school(public.teacher_school(id_user))));
create policy user_permissions_write on "UserPermissions"
  for all to authenticated
  using (public.is_admin() and public.can_see_school(public.teacher_school(id_user)))
  with check (public.is_admin() and public.can_see_school(public.teacher_school(id_user)));


-- ----------------------------------------------------------------------------
-- 5) กันตั้งรายคนเกินเพดาน / แอดมินโรงเรียนแตะสิทธิ์ผู้ดูแลส่วนกลาง
-- ----------------------------------------------------------------------------

create or replace function public.guard_user_permission()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  t record;
begin
  select id_school, id_role, is_super_admin into t
  from "Teachers" where id_user = new.id_user;

  if t.is_super_admin and auth.uid() is not null and not public.is_super_admin() then
    raise exception 'ไม่มีสิทธิ์ปรับสิทธิ์ของผู้ดูแลระบบส่วนกลาง';
  end if;

  if new.allowed and not public.role_allows(t.id_school, t.id_role, new.item_key) then
    raise exception 'เปิด "%" ให้คนนี้ไม่ได้ — เกินเพดานของสิทธิ์', new.item_key;
  end if;

  new."updatedAt" := now();
  return new;
end;
$$;

drop trigger if exists guard_user_permission on public."UserPermissions";
create trigger guard_user_permission
  before insert or update on public."UserPermissions"
  for each row execute function public.guard_user_permission();


-- ----------------------------------------------------------------------------
-- 6) ค่าเริ่มต้น — ให้ทำงานเหมือนเดิมทุกอย่าง
--
--    ผู้ดูแลระบบ (22): ทุกรายการ
--    ครู / ผู้บริหาร: เมนูตามตาราง Permissions เดิม (status = 1)
--                    + "เห็นใบลาทั้งโรงเรียน" ในเพดาน (เดิมดูจากตำแหน่งบริหาร
--                      รายคน — คนที่ไม่มีตำแหน่งบริหารปิดรายคนไว้ ข้อ 7)
--    รายการอื่น (อนุมัติ, เลขรับ, จัดการครู, ตั้งค่า): ไม่อนุญาต
--    ไม่ทับค่าที่ตั้งไว้แล้ว (on conflict do nothing)
-- ----------------------------------------------------------------------------

create or replace function public.seed_role_permissions(p_school bigint)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into "RolePermissions"(id_school, id_role, item_key, allowed)
  select p_school, r."ID_Roles", i.key,
         case
           when r."ID_Roles" = 22 then true
           when i.menu_id is not null then exists (
             select 1 from "Permissions" pm
             where pm.id_role = r."ID_Roles" and pm.menu_id = i.menu_id
               and pm.status::text = '1')
           when i.key = 'view.all_leaves' then true
           else false
         end
  from roles r cross join "PermissionItems" i
  on conflict do nothing;
end;
$$;

do $$
declare
  s record;
begin
  for s in select id_school from public."Schools" loop
    perform public.seed_role_permissions(s.id_school);
  end loop;
end $$;

-- โรงเรียนใหม่ได้ค่าเริ่มต้นอัตโนมัติ
create or replace function public.seed_new_school_permissions()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  perform public.seed_role_permissions(new.id_school);
  return new;
end;
$$;

drop trigger if exists seed_new_school_permissions on public."Schools";
create trigger seed_new_school_permissions
  after insert on public."Schools"
  for each row execute function public.seed_new_school_permissions();


-- ----------------------------------------------------------------------------
-- 7) ค่าเริ่มต้นรายคน: "เห็นใบลาทั้งโรงเรียน" เดิมดูจากตำแหน่งบริหาร
--    ครู/ผู้บริหารที่ไม่มีตำแหน่งบริหาร → ปิดรายคนไว้ (ทำครั้งแรกครั้งเดียว)
-- ----------------------------------------------------------------------------

insert into public."UserPermissions"(id_user, item_key, allowed)
select t.id_user, 'view.all_leaves', false
from public."Teachers" t
where t.id_role <> 22 and t.id_adminrole is null
on conflict do nothing;


-- ----------------------------------------------------------------------------
-- 8) ตรวจผล — จำนวนรายการที่อนุญาตในเพดาน แยกโรงเรียน × สิทธิ์
-- ----------------------------------------------------------------------------

select rp.id_school,
       r."Accessrights"                         as สิทธิ์,
       count(*) filter (where rp.allowed)        as อนุญาต,
       count(*)                                  as ทั้งหมด
from public."RolePermissions" rp
join public.roles r on r."ID_Roles" = rp.id_role
group by rp.id_school, r."Accessrights", rp.id_role
order by rp.id_school, rp.id_role;
