-- ============================================================================
--  ลงเวลาด้วยเครื่องสแกนหน้า — พาร์ท 2: สิทธิ์
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (ค่าที่ตั้งไว้แล้วไม่ถูกทับ)
--  ต้องรันก่อนแล้ว: attendance.sql, fine_permissions.sql,
--                  official_trips_permissions.sql (ขยาย menu_id ถึง 9)
--
--  รอบนี้ "ยังไม่เปลี่ยนการทำงานของ app" — เมนูจะโผล่เมื่อพาร์ท 4
--  ใส่หน้าจอลงเวลาเข้าไปใน app และโรงเรียนนั้นเปิดใช้ระบบจาก web แล้ว
--
--  สิ่งที่ทำ:
--    1) เมนูใหม่ menu_id = 10 "ลงเวลา" ใน Permissions / MobilePermissions
--       ค่าเริ่มต้น: คัดลอกจากเมนู 3 "ประวัติการลา" (ทุกคนดูเวลาของตัวเองได้)
--    2) รายการสิทธิ์ใหม่ใน PermissionItems (web แสดงให้เองอัตโนมัติ)
--       ตั้งชื่อ attendance.view_all ไม่ใช่ view.all_* โดยตั้งใจ — กฎค่าเริ่มต้น
--       เปิด view.all_* ให้ทุกคน แต่ RLS ของ AttendanceLogs ให้ครูเห็นแค่ของ
--       ตัวเอง ถ้าเปิดในเพดานจะดูเหมือนเห็นได้ทั้งที่จริงเห็นไม่ได้
--    3) เพดานของสิทธิ์ทุกโรงเรียน — เติมเฉพาะรายการใหม่ ไม่แตะของเดิม
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ขยายช่วง menu_id ให้รับเมนู 10 (เดิม 0–9 / -1–9)
-- ----------------------------------------------------------------------------

alter table public."Permissions"
  drop constraint if exists "Permissions_menu_id_range";
alter table public."Permissions"
  add constraint "Permissions_menu_id_range" check (menu_id between 0 and 10);

alter table public."MobilePermissions"
  drop constraint if exists "MobilePermissions_menu_id_range";
alter table public."MobilePermissions"
  add constraint "MobilePermissions_menu_id_range" check (menu_id between -1 and 10);


-- ----------------------------------------------------------------------------
-- 2) เมนู 10 "ลงเวลา" — คัดลอกสถานะจากเมนู 3 "ประวัติการลา" ของแต่ละสิทธิ์
-- ----------------------------------------------------------------------------

insert into public."Permissions"(id_role, menu_id, status, "updatedAt")
select p.id_role, 10, p.status, now()
from public."Permissions" p
where p.menu_id = 3
on conflict (id_role, menu_id) do nothing;

insert into public."MobilePermissions"(id_role, menu_id, status, "updatedAt")
select p.id_role, 10, p.status, now()
from public."MobilePermissions" p
where p.menu_id = 3
on conflict (id_role, menu_id) do nothing;


-- ----------------------------------------------------------------------------
-- 3) รายการสิทธิ์ใหม่
-- ----------------------------------------------------------------------------

insert into public."PermissionItems"(key, "group", label, sort, menu_id) values
  ('menu.attendance',       'เมนู',   'ลงเวลา (สแกนหน้า)',                       19, 10),
  ('attendance.view_all',   'ลงเวลา', 'เห็นเวลาสแกนของทุกคนในโรงเรียน',            45, null),
  ('attendance.edit',       'ลงเวลา', 'นำเข้าไฟล์ / เพิ่ม-ลบเวลาแทน (ต้องมีเหตุผล)', 46, null)
on conflict (key) do update set
  "group" = excluded."group", label = excluded.label,
  sort = excluded.sort, menu_id = excluded.menu_id;


-- ----------------------------------------------------------------------------
-- 4) ค่าเริ่มต้นของเพดาน (ใช้ seed_role_permissions จาก fine_permissions.sql)
--    ผู้ดูแลระบบ = ทุกรายการ / ครู-ผู้บริหาร = เฉพาะเมนู
--    on conflict do nothing → เติมเฉพาะรายการใหม่
-- ----------------------------------------------------------------------------

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
-- 5) ตรวจผล — ผู้ดูแลระบบต้องได้ true ทุกช่อง / ครู-ผู้บริหาร ได้แค่เมนู
-- ----------------------------------------------------------------------------

select rp.id_school,
       r."Accessrights"                                                     as สิทธิ์,
       bool_or(rp.allowed) filter (where rp.item_key = 'menu.attendance')     as เมนู,
       bool_or(rp.allowed) filter (where rp.item_key = 'attendance.view_all') as เห็นทุกคน,
       bool_or(rp.allowed) filter (where rp.item_key = 'attendance.edit')     as เพิ่มลบเวลา
from public."RolePermissions" rp
join public.roles r on r."ID_Roles" = rp.id_role
where rp.item_key in ('menu.attendance', 'attendance.view_all', 'attendance.edit')
group by rp.id_school, r."Accessrights", rp.id_role
order by rp.id_school, rp.id_role;
