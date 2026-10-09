-- ============================================================================
--  ประชุมราชการ / ไปราชการ — พาร์ท 2: สิทธิ์
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (ค่าที่ตั้งไว้แล้วไม่ถูกทับ)
--  ต้องรันก่อนแล้ว: official_trips.sql, fine_permissions.sql,
--                  permissions_menu_id.sql, mobile_permissions_menu_id.sql
--
--  รอบนี้ "ยังไม่เปลี่ยนการทำงานของแอป" — เมนูใหม่จะโผล่เมื่อพาร์ท 3
--  ใส่หน้าจอเข้าไปในแอป แต่ตั้งสิทธิ์จากเว็บส่วนกลางได้ตั้งแต่ตอนนี้
--
--  สิ่งที่ทำ:
--    1) เมนูใหม่ menu_id = 9 "ไปราชการ" ในตาราง Permissions / MobilePermissions
--       ค่าเริ่มต้น: เปิดให้สิทธิ์เดียวกับคนที่เห็นเมนู "ส่งใบลา" (menu 2)
--    2) รายการสิทธิ์ใหม่ใน PermissionItems (เว็บส่วนกลางแสดงให้เองอัตโนมัติ)
--    3) เพดานของสิทธิ์ทุกโรงเรียน — เติมเฉพาะรายการใหม่ ไม่แตะของเดิม
--
--  หมายเหตุ: ตอนนี้ RLS ของ OfficialTrips ยังตัดสินจาก id_role = 22 เหมือน
--  ใบลา (เหมือน fine_permissions รอบ 1) — รายการ trip.* จะมีผลจริงเมื่อ
--  แอป/RLS เปลี่ยนมาอ่านสิทธิ์แบบละเอียด (รอบ 2/3 ของ fine_permissions)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ขยายช่วง menu_id ให้รับเมนู 9
--
--    เดิม permissions_menu_id.sql สร้าง check แบบไม่ตั้งชื่อ (0–8 / -1–8)
--    หาจากนิยามแล้วลบทิ้ง แล้วสร้างใหม่แบบมีชื่อ รันซ้ำได้
-- ----------------------------------------------------------------------------

do $$
declare
  t text;
  c record;
begin
  foreach t in array array['Permissions', 'MobilePermissions']
  loop
    for c in
      select conname from pg_constraint
      where conrelid = format('public.%I', t)::regclass
        and contype = 'c'
        and pg_get_constraintdef(oid) like '%menu_id%'
    loop
      execute format('alter table public.%I drop constraint %I', t, c.conname);
    end loop;
  end loop;
end $$;

alter table public."Permissions"
  add constraint "Permissions_menu_id_range" check (menu_id between 0 and 9);
alter table public."MobilePermissions"
  add constraint "MobilePermissions_menu_id_range" check (menu_id between -1 and 9);


-- ----------------------------------------------------------------------------
-- 2) เมนู 9 "ไปราชการ" — คัดลอกสถานะจากเมนู 2 "ส่งใบลา" ของแต่ละสิทธิ์
--    (ใครส่งใบลาได้ ก็บันทึกไปราชการได้) ถ้ามีแถวเมนู 9 อยู่แล้วไม่ทับ
-- ----------------------------------------------------------------------------

insert into public."Permissions"(id_role, menu_id, status, "updatedAt")
select p.id_role, 9, p.status, now()
from public."Permissions" p
where p.menu_id = 2
on conflict (id_role, menu_id) do nothing;

insert into public."MobilePermissions"(id_role, menu_id, status, "updatedAt")
select p.id_role, 9, p.status, now()
from public."MobilePermissions" p
where p.menu_id = 2
on conflict (id_role, menu_id) do nothing;


-- ----------------------------------------------------------------------------
-- 3) รายการสิทธิ์ใหม่
-- ----------------------------------------------------------------------------

insert into public."PermissionItems"(key, "group", label, sort, menu_id) values
  ('menu.official_trip',  'เมนู',        'ไปราชการ / ประชุม',                  18, 9),
  ('view.all_trips',      'การมองเห็น',   'เห็นการไปราชการของทุกคนในโรงเรียน',    21, null),
  ('trip.approve',        'ไปราชการ',    'อนุมัติ / เปลี่ยนสถานะการไปราชการ',     36, null),
  ('trip.edit_others',    'ไปราชการ',    'แก้ไขรายการไปราชการของคนอื่น',         37, null),
  ('trip.delete_others',  'ไปราชการ',    'ลบรายการไปราชการของคนอื่น',           38, null)
on conflict (key) do update set
  "group" = excluded."group", label = excluded.label,
  sort = excluded.sort, menu_id = excluded.menu_id;


-- ----------------------------------------------------------------------------
-- 4) ค่าเริ่มต้นของเพดาน
--
--    ปรับกฎใน seed_role_permissions: รายการกลุ่ม "การมองเห็น" (view.all_*)
--    เปิดในเพดานทุกตัว (เดิมเขียนไว้เฉพาะ view.all_leaves)
--    นิยามนี้ต้องตรงกับใน fine_permissions.sql — แก้ที่หนึ่งให้แก้อีกที่ด้วย
--
--    ผล: ผู้ดูแลระบบ = ทุกรายการ / ครู-ผู้บริหาร = เมนูตามข้อ 2 + เห็นทั้ง
--    โรงเรียน / อนุมัติ-แก้-ลบของคนอื่น = ไม่อนุญาต
--    on conflict do nothing → เติมเฉพาะรายการใหม่ ของที่ตั้งไว้แล้วไม่ถูกทับ
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
           when i.key like 'view.all\_%' then true
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


notify pgrst, 'reload schema';


-- ----------------------------------------------------------------------------
-- 5) ตรวจผล — รายการใหม่ในเพดาน แยกโรงเรียน × สิทธิ์
--    ผู้ดูแลระบบต้องได้ ✔ ทุกช่อง / ครู-ผู้บริหาร ได้เมนู + เห็นทั้งโรงเรียน
-- ----------------------------------------------------------------------------

select rp.id_school,
       r."Accessrights"                                                   as สิทธิ์,
       bool_or(rp.allowed) filter (where rp.item_key = 'menu.official_trip') as เมนู,
       bool_or(rp.allowed) filter (where rp.item_key = 'view.all_trips')     as เห็นทั้งโรงเรียน,
       bool_or(rp.allowed) filter (where rp.item_key = 'trip.approve')       as อนุมัติ,
       bool_or(rp.allowed) filter (where rp.item_key = 'trip.edit_others')   as แก้ของคนอื่น,
       bool_or(rp.allowed) filter (where rp.item_key = 'trip.delete_others') as ลบของคนอื่น
from public."RolePermissions" rp
join public.roles r on r."ID_Roles" = rp.id_role
where rp.item_key in ('menu.official_trip', 'view.all_trips', 'trip.approve',
                      'trip.edit_others', 'trip.delete_others')
group by rp.id_school, r."Accessrights", rp.id_role
order by rp.id_school, rp.id_role;
