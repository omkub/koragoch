-- ============================================================================
--  สิทธิ์การเข้าถึงแยกตามโรงเรียน + ข้อมูลพื้นฐานที่ใช้ร่วมกันแก้ได้เฉพาะส่วนกลาง
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  ต้องรันก่อนแล้ว: multi_school_step3_rls.sql,
--  fine_permissions.sql, official_trips_permissions.sql, school_mobile_ui_by_role.sql
--  ⚠️ ถ้ารัน teacher_role_per_school.sql แล้ว ห้ามรันไฟล์นี้ซ้ำ (seed_new_role จะกลับเป็นแบบเก่า)
--
--  1) roles (สิทธิ์การเข้าถึง)
--     id_school ว่าง  = สิทธิ์หลักของระบบ ใช้ทุกโรงเรียน (ผู้ดูแลระบบ 22 / ครู 23 /
--                       ผู้บริหาร 24) — แก้ชื่อหรือลบไม่ได้ เพราะความปลอดภัยและ
--                       แอปผูกกับเลขและชื่อเหล่านี้
--     id_school มีค่า = สิทธิ์ที่โรงเรียนเพิ่มเอง (เช่น แม่บ้าน) เห็นและใช้ได้เฉพาะ
--                       โรงเรียนนั้น แอดมินโรงเรียนนั้นเพิ่ม/แก้ชื่อ/ลบได้
--     สิทธิ์ที่เพิ่มเองซึ่งมีอยู่ก่อนรันไฟล์นี้ → คัดลอกให้ทุกโรงเรียนคนละแถว
--     (ไม่มีโรงเรียนไหนเสียของที่เคยเห็น) แล้วย้ายครู/เพดาน/หน้ามือถือไปแถวใหม่
--     สิทธิ์ใหม่ได้ค่าเริ่มต้น (เพดาน + เมนูที่เห็น) เหมือน "ครู" ของโรงเรียนนั้น
--
--  2) Permissions / MobilePermissions (เมนูที่แต่ละสิทธิ์เห็น)
--     แยกตามโรงเรียน: โรงเรียน × สิทธิ์ × เมนู — ค่าเดิมคัดลอกให้ทุกโรงเรียน
--     แอดมินโรงเรียนแก้ของโรงเรียนตัวเอง ไม่กระทบโรงเรียนอื่นแล้ว
--     ⚠️ หลังรันไฟล์นี้ ห้ามรัน attendance_permissions.sql / official_trips_permissions.sql
--        ข้อ "เพิ่มเมนู" ซ้ำ (ใช้ on conflict (id_role, menu_id) แบบเดิม)
--
--  3) LeaveReasons (เหตุผลการลา) แยกตามโรงเรียน — ของเดิมคัดลอกให้ทุกโรงเรียน
--
--  4) positions / academics / LeaveTypes ยังใช้ร่วมกัน แต่แก้ได้เฉพาะผู้ดูแลส่วนกลาง
-- ============================================================================

begin;


-- ----------------------------------------------------------------------------
-- 0) ฟังก์ชันผู้ช่วย: เติม id_school ให้แถวใหม่ (ถ้าไม่ใช่ส่วนกลางและไม่ได้ระบุมา)
-- ----------------------------------------------------------------------------

create or replace function public.fill_row_school()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.id_school is null
     and auth.uid() is not null
     and not public.is_super_admin() then
    new.id_school := public.current_school_id();
  end if;
  return new;
end;
$$;

-- ลบ unique index/constraint ที่ครอบคอลัมน์ชุดนี้พอดี (ชื่อเดิมไม่แน่นอน)
create or replace function pg_temp.drop_unique_on(p_table text, p_cols text[])
returns void
language plpgsql
as $$
declare
  ix record;
begin
  for ix in
    select i.indexrelid::regclass::text as index_name,
           c.conname
    from pg_index i
    left join pg_constraint c on c.conindid = i.indexrelid
    where i.indrelid = format('public.%I', p_table)::regclass
      and i.indisunique
      and not i.indisprimary
      and (select array_agg(a.attname::text order by a.attname)
           from pg_attribute a
           where a.attrelid = i.indrelid and a.attnum = any (i.indkey))
          = (select array_agg(x order by x) from unnest(p_cols) x)
  loop
    if ix.conname is not null then
      execute format('alter table public.%I drop constraint %I', p_table, ix.conname);
    else
      execute format('drop index %s', ix.index_name);
    end if;
  end loop;
end;
$$;


-- ----------------------------------------------------------------------------
-- 1) Permissions / MobilePermissions → แยกตามโรงเรียน
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['Permissions', 'MobilePermissions'] loop
    execute format('alter table public.%I add column if not exists id_school bigint '
                   'references public."Schools"(id_school) on delete cascade', t);

    perform pg_temp.drop_unique_on(t, array['id_role', 'menu_id']);

    -- แถวเดิม (ใช้ร่วมกัน) → คัดลอกให้ทุกโรงเรียน แล้วลบแถวเดิม
    execute format(
      'insert into public.%1$I (id_school, id_role, menu_id, status, "updatedAt") '
      'select s.id_school, p.id_role, p.menu_id, p.status, now() '
      'from public.%1$I p cross join public."Schools" s '
      'where p.id_school is null '
      '  and not exists (select 1 from public.%1$I q where q.id_school = s.id_school '
      '                  and q.id_role = p.id_role and q.menu_id = p.menu_id)', t);
    execute format('delete from public.%I where id_school is null', t);

    execute format('create unique index if not exists %I on public.%I (id_school, id_role, menu_id)',
                   t || '_school_role_menu_uidx', t);

    execute format('drop trigger if exists fill_row_school on public.%I', t);
    execute format('create trigger fill_row_school before insert on public.%I '
                   'for each row execute function public.fill_row_school()', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 2) roles.id_school + เลขสิทธิ์ใหม่ออกโดยฐานข้อมูล
--    (แอดมินโรงเรียนมองไม่เห็นสิทธิ์ของโรงเรียนอื่น จะหาเลขถัดไปเองไม่ได้)
-- ----------------------------------------------------------------------------

alter table public.roles
  add column if not exists id_school bigint
  references public."Schools"(id_school) on delete cascade;

create index if not exists roles_id_school_idx on public.roles (id_school);

do $$
declare
  col record;
begin
  select column_default, is_identity into col
  from information_schema.columns
  where table_schema = 'public' and table_name = 'roles' and column_name = 'ID_Roles';

  if col.is_identity = 'NO' and col.column_default is null then
    create sequence if not exists public.roles_id_seq;
    alter table public.roles alter column "ID_Roles" set default nextval('public.roles_id_seq');
    alter sequence public.roles_id_seq owned by public.roles."ID_Roles";
  end if;
end $$;

-- ให้เลขถัดไปเลยเลขที่มีอยู่แล้ว (แถวเดิมนำเข้ามาพร้อมเลข)
select setval(pg_get_serial_sequence('public.roles', 'ID_Roles'),
              greatest((select max("ID_Roles") from public.roles), 24));


-- ----------------------------------------------------------------------------
-- 3) สิทธิ์ที่เพิ่มเองซึ่งมีอยู่แล้ว → ของแต่ละโรงเรียน
--    โรงเรียนแรกได้แถวเดิม โรงเรียนอื่นได้แถวใหม่ แล้วย้ายทุกอย่างที่อ้างถึง
--    (ทำก่อนสร้าง trigger ข้อ 5 ไม่งั้นแถวใหม่จะได้ค่าเริ่มต้นของครูไปชนกัน)
-- ----------------------------------------------------------------------------

do $$
declare
  r record;
  s record;
  first_school bigint;
  new_id bigint;
  has_id_permission boolean;
begin
  select min(id_school) into first_school from public."Schools";
  if first_school is null then
    return;
  end if;

  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'Teachers'
                   and column_name = 'id_permission')
    into has_id_permission;

  for r in
    select "ID_Roles" as id, "Accessrights" as name
    from public.roles
    where id_school is null and "ID_Roles" not in (22, 23, 24)
  loop
    for s in
      select id_school from public."Schools" where id_school <> first_school
    loop
      insert into public.roles ("Accessrights", id_school)
      values (r.name, s.id_school)
      returning "ID_Roles" into new_id;

      update public."Teachers" set id_role = new_id
      where id_role = r.id and id_school = s.id_school;
      if has_id_permission then
        execute 'update public."Teachers" set id_permission = $1 '
                'where id_permission = $2 and id_school = $3'
          using new_id, r.id, s.id_school;
      end if;

      update public."RolePermissions" set id_role = new_id
      where id_role = r.id and id_school = s.id_school;
      update public."Permissions" set id_role = new_id
      where id_role = r.id and id_school = s.id_school;
      update public."MobilePermissions" set id_role = new_id
      where id_role = r.id and id_school = s.id_school;

      update public."Schools"
      set mobile_ui_by_role = (mobile_ui_by_role - r.id::text)
                              || jsonb_build_object(new_id::text, mobile_ui_by_role -> r.id::text)
      where id_school = s.id_school and mobile_ui_by_role ? r.id::text;
    end loop;

    update public.roles set id_school = first_school where "ID_Roles" = r.id;
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 4) RLS ของ roles
--    อ่าน: สิทธิ์หลัก + ของโรงเรียนตัวเอง (ส่วนกลางเห็นทุกโรงเรียน)
--    เขียน: แอดมินโรงเรียน = เฉพาะของโรงเรียนตัวเอง / ส่วนกลาง = ทุกแถว
--    (สิทธิ์หลักแก้ไม่ได้เลย — trigger ข้อ 5)
-- ----------------------------------------------------------------------------

alter table public.roles enable row level security;

do $$
declare
  p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'public' and tablename = 'roles'
  loop
    execute format('drop policy %I on public.roles', p.policyname);
  end loop;
end $$;

create policy roles_select on public.roles
  for select to authenticated
  using (id_school is null or public.can_see_school(id_school));

create policy roles_write on public.roles
  for all to authenticated
  using (public.is_super_admin()
         or (public.is_admin() and id_school is not null
             and id_school = public.current_school_id()))
  with check (public.is_super_admin()
              or (public.is_admin() and id_school is not null
                  and id_school = public.current_school_id()));


-- ----------------------------------------------------------------------------
-- 5) กฎของ roles
--    - สิทธิ์หลัก (id_school ว่าง) แก้ชื่อ/ลบไม่ได้ เพิ่มใหม่ได้เฉพาะส่วนกลาง
--    - ชื่อห้ามซ้ำกับสิทธิ์หลักหรือสิทธิ์อื่นในโรงเรียนเดียวกัน
--    - ลบไม่ได้ถ้ายังมีบุคลากรใช้สิทธิ์นี้อยู่
--    - สิทธิ์ใหม่ได้เพดาน + เมนูที่เห็น เหมือน "ครู" (23) ของโรงเรียนนั้น
--    auth.uid() ว่าง = รันจาก SQL Editor / ระบบ → ข้ามการตรวจ
-- ----------------------------------------------------------------------------

create or replace function public.guard_roles()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  users_count int;
begin
  if tg_op in ('UPDATE', 'DELETE') and old.id_school is null and auth.uid() is not null then
    raise exception 'สิทธิ์ "%" เป็นสิทธิ์หลักของระบบ ใช้ทุกโรงเรียน แก้ไขหรือลบไม่ได้',
      old."Accessrights";
  end if;

  if tg_op = 'DELETE' then
    select count(*) into users_count from "Teachers" where id_role = old."ID_Roles";
    if users_count > 0 then
      raise exception 'ยังมีบุคลากร % คนใช้สิทธิ์ "%" อยู่ — เปลี่ยนสิทธิ์ของคนเหล่านั้นก่อนแล้วค่อยลบ',
        users_count, old."Accessrights";
    end if;
    -- เมนูที่เห็นของสิทธิ์นี้ ลบก่อนตัวสิทธิ์ — FK ของสองตารางนี้เดิมไม่ cascade
    -- (ดู roles_delete_fix.sql)
    delete from "Permissions" where id_role = old."ID_Roles";
    delete from "MobilePermissions" where id_role = old."ID_Roles";
    return old;
  end if;

  if new.id_school is null and auth.uid() is not null and not public.is_super_admin() then
    new.id_school := public.current_school_id();
  end if;

  new."Accessrights" := btrim(coalesce(new."Accessrights", ''));
  if new."Accessrights" = '' then
    raise exception 'กรุณาใส่ชื่อสิทธิ์';
  end if;

  if exists (
    select 1 from roles r
    where lower(r."Accessrights") = lower(new."Accessrights")
      and r."ID_Roles" is distinct from new."ID_Roles"
      and (r.id_school is null or new.id_school is null or r.id_school = new.id_school)
  ) then
    raise exception 'มีสิทธิ์ชื่อ "%" อยู่แล้ว', new."Accessrights";
  end if;

  return new;
end;
$$;

drop trigger if exists guard_roles on public.roles;
create trigger guard_roles
  before insert or update or delete on public.roles
  for each row execute function public.guard_roles();

create or replace function public.seed_new_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    delete from "Permissions" where id_role = old."ID_Roles";
    delete from "MobilePermissions" where id_role = old."ID_Roles";
    return old;
  end if;

  insert into "RolePermissions"(id_school, id_role, item_key, allowed)
  select rp.id_school, new."ID_Roles", rp.item_key, rp.allowed
  from "RolePermissions" rp
  where rp.id_role = 23
    and (new.id_school is null or rp.id_school = new.id_school)
  on conflict do nothing;

  insert into "Permissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p.id_school, new."ID_Roles", p.menu_id, p.status, now()
  from "Permissions" p
  where p.id_role = 23
    and (new.id_school is null or p.id_school = new.id_school)
  on conflict do nothing;

  insert into "MobilePermissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p.id_school, new."ID_Roles", p.menu_id, p.status, now()
  from "MobilePermissions" p
  where p.id_role = 23
    and (new.id_school is null or p.id_school = new.id_school)
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists seed_new_role on public.roles;
create trigger seed_new_role
  after insert or delete on public.roles
  for each row execute function public.seed_new_role();


-- ----------------------------------------------------------------------------
-- 6) บุคลากรใช้ได้เฉพาะสิทธิ์หลัก หรือสิทธิ์ของโรงเรียนตัวเอง
--    (ชื่อ trigger ขึ้นต้น t ให้ทำงานหลัง fill_id_school ที่เติมโรงเรียนให้)
-- ----------------------------------------------------------------------------

create or replace function public.teacher_role_in_school()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.id_role is not null and exists (
    select 1 from roles r
    where r."ID_Roles" = new.id_role
      and r.id_school is not null
      and r.id_school is distinct from new.id_school
  ) then
    raise exception 'สิทธิ์นี้เป็นของโรงเรียนอื่น ใช้กับบุคลากรโรงเรียนนี้ไม่ได้';
  end if;
  return new;
end;
$$;

drop trigger if exists teacher_role_in_school on public."Teachers";
create trigger teacher_role_in_school
  before insert or update of id_role, id_school on public."Teachers"
  for each row execute function public.teacher_role_in_school();


-- ----------------------------------------------------------------------------
-- 7) RLS ของ Permissions / MobilePermissions — ของโรงเรียนใครโรงเรียนมัน
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
  p record;
begin
  foreach t in array array['Permissions', 'MobilePermissions'] loop
    for p in select policyname from pg_policies
             where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;

    execute format(
      'create policy menu_select on public.%I for select to authenticated '
      'using (public.can_see_school(id_school))', t);
    execute format(
      'create policy menu_write on public.%I for all to authenticated '
      'using (public.is_admin() and public.can_see_school(id_school)) '
      'with check (public.is_admin() and public.can_see_school(id_school))', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 8) ค่าเริ่มต้นของโรงเรียน (ใหม่)
--    เมนูที่เห็น: คัดลอกของสิทธิ์หลักจากโรงเรียนแรก
--    เพดาน: เหมือนเดิม แต่เฉพาะสิทธิ์หลัก + สิทธิ์ของโรงเรียนนั้น
--    (นิยาม seed_role_permissions ต้องตรงกับ official_trips_permissions.sql
--     ยกเว้นเงื่อนไขโรงเรียนที่เพิ่มในไฟล์นี้)
-- ----------------------------------------------------------------------------

create or replace function public.seed_school_menus(p_school bigint)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  template bigint;
begin
  select min(id_school) into template
  from "Schools" where id_school <> p_school;
  if template is null then
    return;
  end if;

  insert into "Permissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p_school, p.id_role, p.menu_id, p.status, now()
  from "Permissions" p join roles r on r."ID_Roles" = p.id_role
  where p.id_school = template and r.id_school is null
  on conflict do nothing;

  insert into "MobilePermissions"(id_school, id_role, menu_id, status, "updatedAt")
  select p_school, p.id_role, p.menu_id, p.status, now()
  from "MobilePermissions" p join roles r on r."ID_Roles" = p.id_role
  where p.id_school = template and r.id_school is null
  on conflict do nothing;
end;
$$;

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
             where pm.id_school = p_school
               and pm.id_role = r."ID_Roles" and pm.menu_id = i.menu_id
               and pm.status::text = '1')
           when i.key like 'view.all\_%' then true
           else false
         end
  from roles r cross join "PermissionItems" i
  where r.id_school is null or r.id_school = p_school
  on conflict do nothing;
end;
$$;

create or replace function public.seed_new_school_permissions()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  perform public.seed_school_menus(new.id_school);
  perform public.seed_role_permissions(new.id_school);
  return new;
end;
$$;

-- เพดานที่สร้างเกินไว้ก่อนหน้า (สิทธิ์ของโรงเรียนอื่น) — ลบทิ้ง
delete from public."RolePermissions" rp
using public.roles r
where r."ID_Roles" = rp.id_role
  and r.id_school is not null
  and r.id_school <> rp.id_school;


-- ----------------------------------------------------------------------------
-- 9) LeaveReasons → แยกตามโรงเรียน
-- ----------------------------------------------------------------------------

alter table public."LeaveReasons"
  add column if not exists id_school bigint
  references public."Schools"(id_school) on delete cascade;

select pg_temp.drop_unique_on('LeaveReasons', array['reasonName']);

do $$
declare
  first_school bigint;
begin
  select min(id_school) into first_school from public."Schools";
  if first_school is null then
    return;
  end if;

  insert into public."LeaveReasons" ("reasonName", id_school)
  select lr."reasonName", s.id_school
  from public."LeaveReasons" lr
  cross join public."Schools" s
  where lr.id_school is null
    and s.id_school <> first_school
    and not exists (select 1 from public."LeaveReasons" x
                    where x.id_school = s.id_school
                      and x."reasonName" = lr."reasonName");

  update public."LeaveReasons" set id_school = first_school
  where id_school is null;
end $$;

create unique index if not exists "LeaveReasons_school_reason_uidx"
  on public."LeaveReasons" (id_school, "reasonName");

drop trigger if exists fill_row_school on public."LeaveReasons";
create trigger fill_row_school
  before insert on public."LeaveReasons"
  for each row execute function public.fill_row_school();

do $$
declare
  p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'public' and tablename = 'LeaveReasons'
  loop
    execute format('drop policy %I on public."LeaveReasons"', p.policyname);
  end loop;
end $$;

create policy school_master_select on public."LeaveReasons"
  for select to authenticated using (public.can_see_school(id_school));
create policy school_master_write on public."LeaveReasons"
  for all to authenticated
  using (public.is_admin() and public.can_see_school(id_school))
  with check (public.is_admin() and public.can_see_school(id_school));


-- ----------------------------------------------------------------------------
-- 10) ข้อมูลที่ใช้ร่วมกันทุกโรงเรียน — ทุกคนอ่านได้ แก้ได้เฉพาะผู้ดูแลส่วนกลาง
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
  p record;
begin
  foreach t in array array['positions', 'academics', 'LeaveTypes'] loop
    for p in select policyname from pg_policies
             where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;

    execute format('create policy master_select on public.%I '
                   'for select to authenticated using (true)', t);
    execute format('create policy master_write on public.%I for all to authenticated '
                   'using (public.is_super_admin()) with check (public.is_super_admin())', t);
  end loop;
end $$;


notify pgrst, 'reload schema';

commit;


-- ----------------------------------------------------------------------------
-- 11) ตรวจผล
--     สิทธิ์: สิทธิ์หลัก (ทุกโรงเรียน) 3 แถว + สิทธิ์ของแต่ละโรงเรียน
-- ----------------------------------------------------------------------------

select r."ID_Roles",
       r."Accessrights"                                   as สิทธิ์,
       coalesce(s."fullName", 'ทุกโรงเรียน (สิทธิ์หลัก)')   as โรงเรียน,
       (select count(*) from public."Teachers" t where t.id_role = r."ID_Roles") as บุคลากร
from public.roles r
left join public."Schools" s on s.id_school = r.id_school
order by r.id_school nulls first, r."ID_Roles";
