-- ============================================================================
--  "ครู" เป็นสิทธิ์ของแต่ละโรงเรียน — สิทธิ์กลางเหลือ ผู้ดูแลระบบ (22) / ผู้บริหาร (24)
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  ต้องรันก่อนแล้ว: roles_per_school.sql, roles_delete_fix.sql
--  ⚠️ หลังรันไฟล์นี้ ห้ามรัน roles_per_school.sql ซ้ำ (จะได้ seed_new_role แบบเก่า)
--
--  1) ครู (23) → โรงเรียนแรกได้แถวเดิม โรงเรียนอื่นได้ "ครู" ของตัวเองคนละแถว
--     ย้ายครู / เพดาน / เมนูที่เห็น / หน้ามือถือรายสิทธิ์ ไปแถวของโรงเรียนนั้น
--     ทุกอย่างเหมือนเดิม แต่แต่ละโรงเรียนเปลี่ยนชื่อ / ลบ "ครู" ของตัวเองได้
--     (ลบได้เมื่อไม่มีบุคลากรใช้แล้ว — guard_roles)
--  2) roles.is_default_teacher = แถว "ครู" ของแต่ละโรงเรียน ใช้เป็นแม่แบบ
--     สิทธิ์ใหม่ได้เพดาน + เมนูที่เห็นเหมือนแถวนี้ ถ้าไม่มี (ลบไปแล้ว) ใช้ชุดพื้นฐาน:
--     ส่งใบลา / ประวัติการลา / ปฏิทิน / บัญชี
--  3) เมนูสรุปผล (0) ของ "ครู" ปิดไว้ — เดิมแอปซ่อนจากชื่อ "ครู" ตายตัว
--     ตอนนี้แอปดูตามหน้ากำหนดสิทธิ์อย่างเดียว เปลี่ยนชื่อได้ไม่พัง
--  4) โรงเรียนใหม่ได้ "ครู" ของตัวเองอัตโนมัติ (คัดลอกค่าจากโรงเรียนแรก)
-- ============================================================================

begin;

alter table public.roles
  add column if not exists is_default_teacher boolean not null default false;


-- ----------------------------------------------------------------------------
-- 1) แยก "ครู" ตามโรงเรียน
--    ปิด trigger ของ roles ระหว่างย้าย (guard จะมองว่าชื่อซ้ำ / seed จะใส่ค่าชน)
-- ----------------------------------------------------------------------------

alter table public.roles disable trigger guard_roles;
alter table public.roles disable trigger seed_new_role;

do $$
declare
  s record;
  first_school bigint;
  new_id bigint;
  has_id_permission boolean;
begin
  select min(id_school) into first_school from public."Schools";
  if first_school is null then
    return;
  end if;

  -- รันซ้ำ: 23 เป็นของโรงเรียนแล้ว ไม่ต้องทำอะไร
  if not exists (select 1 from public.roles where "ID_Roles" = 23 and id_school is null) then
    return;
  end if;

  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'Teachers'
                   and column_name = 'id_permission')
    into has_id_permission;

  for s in
    select id_school from public."Schools" where id_school <> first_school
  loop
    insert into public.roles ("Accessrights", id_school, is_default_teacher)
    select "Accessrights", s.id_school, true from public.roles where "ID_Roles" = 23
    returning "ID_Roles" into new_id;

    update public."Teachers" set id_role = new_id
    where id_role = 23 and id_school = s.id_school;
    if has_id_permission then
      execute 'update public."Teachers" set id_permission = $1 '
              'where id_permission = 23 and id_school = $2'
        using new_id, s.id_school;
    end if;

    update public."RolePermissions" set id_role = new_id
    where id_role = 23 and id_school = s.id_school;
    update public."Permissions" set id_role = new_id
    where id_role = 23 and id_school = s.id_school;
    update public."MobilePermissions" set id_role = new_id
    where id_role = 23 and id_school = s.id_school;

    update public."Schools"
    set mobile_ui_by_role = (mobile_ui_by_role - '23')
                            || jsonb_build_object(new_id::text, mobile_ui_by_role -> '23')
    where id_school = s.id_school and mobile_ui_by_role ? '23';
  end loop;

  update public.roles
  set id_school = first_school, is_default_teacher = true
  where "ID_Roles" = 23;
end $$;

alter table public.roles enable trigger guard_roles;
alter table public.roles enable trigger seed_new_role;


-- ----------------------------------------------------------------------------
-- 3) สรุปผล (เมนู 0) ของ "ครู" ปิด — คงพฤติกรรมเดิมที่แอปซ่อนจากชื่อ
-- ----------------------------------------------------------------------------

update public."Permissions" p set status = '0', "updatedAt" = now()
from public.roles r
where r."ID_Roles" = p.id_role and r.is_default_teacher and p.menu_id = 0;

update public."MobilePermissions" p set status = '0', "updatedAt" = now()
from public.roles r
where r."ID_Roles" = p.id_role and r.is_default_teacher and p.menu_id = 0;


-- ----------------------------------------------------------------------------
-- 2) ค่าเริ่มต้นของสิทธิ์ใหม่
-- ----------------------------------------------------------------------------

-- ชุดพื้นฐาน (ไม่มี "ครู" ของโรงเรียนให้คัดลอก)
create or replace function public.seed_basic_role(p_role bigint, p_school bigint)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into "RolePermissions"(id_school, id_role, item_key, allowed)
  select p_school, p_role, i.key,
         i.key in ('menu.leave_submit', 'menu.leave_history', 'menu.calendar')
           or i.key like 'view.all\_%'
  from "PermissionItems" i
  on conflict do nothing;

  insert into "Permissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p_school, p_role, m, '1', now() from unnest(array[2, 3, 8]) m
  on conflict do nothing;

  insert into "MobilePermissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p_school, p_role, m, '1', now() from unnest(array[-1, 2, 3, 8]) m
  on conflict do nothing;
end;
$$;

-- คัดลอกเพดาน + เมนูที่เห็นจากสิทธิ์หนึ่งไปอีกสิทธิ์ (ข้ามโรงเรียนได้)
create or replace function public.copy_role_settings(
  p_from_role bigint, p_from_school bigint, p_to_role bigint, p_to_school bigint)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into "RolePermissions"(id_school, id_role, item_key, allowed)
  select p_to_school, p_to_role, rp.item_key, rp.allowed
  from "RolePermissions" rp
  where rp.id_role = p_from_role and rp.id_school = p_from_school
  on conflict do nothing;

  insert into "Permissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p_to_school, p_to_role, p.menu_id, p.status, now()
  from "Permissions" p
  where p.id_role = p_from_role and p.id_school = p_from_school
  on conflict do nothing;

  insert into "MobilePermissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p_to_school, p_to_role, p.menu_id, p.status, now()
  from "MobilePermissions" p
  where p.id_role = p_from_role and p.id_school = p_from_school
  on conflict do nothing;
end;
$$;

create or replace function public.seed_new_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  template bigint;
  s record;
begin
  if tg_op = 'DELETE' then
    return old;
  end if;

  for s in
    select id_school from "Schools"
    where new.id_school is null or id_school = new.id_school
  loop
    select "ID_Roles" into template
    from roles
    where id_school = s.id_school and is_default_teacher
      and "ID_Roles" <> new."ID_Roles"
    order by "ID_Roles"
    limit 1;

    if template is null then
      perform public.seed_basic_role(new."ID_Roles", s.id_school);
    else
      perform public.copy_role_settings(template, s.id_school, new."ID_Roles", s.id_school);
    end if;
  end loop;

  return new;
end;
$$;


-- ----------------------------------------------------------------------------
-- 4) โรงเรียนใหม่ได้ "ครู" ของตัวเอง (ค่าเหมือน "ครู" ของโรงเรียนแรก)
-- ----------------------------------------------------------------------------

create or replace function public.seed_new_school_permissions()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  template_school bigint;
  template_role bigint;
  new_role bigint;
begin
  perform public.seed_school_menus(new.id_school);

  select min(id_school) into template_school
  from "Schools" where id_school <> new.id_school;

  select "ID_Roles" into template_role
  from roles
  where id_school = template_school and is_default_teacher
  order by "ID_Roles" limit 1;

  -- seed_new_role ใส่ชุดพื้นฐานให้ก่อน (โรงเรียนใหม่ยังไม่มีครู) แล้วทับด้วยของครูโรงเรียนแรก
  insert into roles ("Accessrights", id_school, is_default_teacher)
  values ('ครู', new.id_school, true)
  returning "ID_Roles" into new_role;

  if template_role is not null then
    delete from "RolePermissions" where id_role = new_role;
    delete from "Permissions" where id_role = new_role;
    delete from "MobilePermissions" where id_role = new_role;
    perform public.copy_role_settings(template_role, template_school, new_role, new.id_school);
  end if;

  perform public.seed_role_permissions(new.id_school);
  return new;
end;
$$;


notify pgrst, 'reload schema';

commit;


-- ----------------------------------------------------------------------------
-- 5) ตรวจผล — สิทธิ์กลาง 2 แถว (ผู้ดูแลระบบ / ผู้บริหาร) + "ครู" ของทุกโรงเรียน
-- ----------------------------------------------------------------------------

select r."ID_Roles",
       r."Accessrights"                                    as สิทธิ์,
       coalesce(s."fullName", 'ทุกโรงเรียน (สิทธิ์กลาง)')    as โรงเรียน,
       r.is_default_teacher                                as แม่แบบสิทธิ์ใหม่,
       (select count(*) from public."Teachers" t where t.id_role = r."ID_Roles") as บุคลากร
from public.roles r
left join public."Schools" s on s.id_school = r.id_school
order by r.id_school nulls first, r."ID_Roles";
