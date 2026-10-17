-- ============================================================================
--  แก้ลบสิทธิ์ที่โรงเรียนเพิ่มเองไม่ได้
--  (MobilePermissions_id_role_fkey / Permissions_id_role_fkey)
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  ต้องรัน roles_per_school.sql มาก่อนแล้ว
--
--  สาเหตุ: roles_per_school.sql ลบแถวเมนูของสิทธิ์ "หลัง" ลบสิทธิ์ (after delete)
--  แต่ FK ของ Permissions / MobilePermissions ไม่ cascade ฐานข้อมูลจึงปฏิเสธ
--  ตั้งแต่ตอนลบสิทธิ์
--
--  แก้: FK id_role ของสองตารางนี้ → on delete cascade
--       + ลบแถวเมนูใน guard_roles ก่อนลบสิทธิ์ (กันกรณีมี FK อื่นที่ไม่รู้ชื่อ)
-- ============================================================================

begin;

do $$
declare
  t text;
  fk record;
begin
  foreach t in array array['Permissions', 'MobilePermissions'] loop
    for fk in
      select c.conname
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
      where c.contype = 'f'
        and c.conrelid = format('public.%I', t)::regclass
        and c.confrelid = 'public.roles'::regclass
        and a.attname = 'id_role'
    loop
      execute format('alter table public.%I drop constraint %I', t, fk.conname);
    end loop;

    execute format(
      'alter table public.%I add constraint %I foreign key (id_role) '
      'references public.roles("ID_Roles") on delete cascade',
      t, t || '_id_role_fkey');
  end loop;
end $$;

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
    -- เมนูที่เห็นของสิทธิ์นี้ ลบก่อนตัวสิทธิ์ (เพดาน RolePermissions cascade อยู่แล้ว)
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

commit;

-- ตรวจผล: ต้องขึ้น 2 แถว delete_rule = CASCADE
select tc.table_name, tc.constraint_name, rc.delete_rule
from information_schema.table_constraints tc
join information_schema.referential_constraints rc
  on rc.constraint_name = tc.constraint_name and rc.constraint_schema = tc.constraint_schema
where tc.table_schema = 'public'
  and tc.table_name in ('Permissions', 'MobilePermissions')
  and tc.constraint_type = 'FOREIGN KEY'
  and tc.constraint_name like '%id_role%';
