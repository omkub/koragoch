-- ============================================================================
--  แก้ลบสิทธิ์ไม่ได้: "UserRoles_id_role_fkey" on table "UserRoles"
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--
--  สาเหตุ: UserRoles เป็นตารางเก่าจาก Firebase (ระบบใหม่ไม่ได้ใช้ สิทธิ์จริงอยู่ที่
--  Teachers.id_role) — นำเข้ารอบสุดท้ายผูกแถวเหล่านี้กับ "ครู" ตัวที่นำเข้าสร้างใหม่
--  (เลข 27 ของ รร รมย์บุรีฯ เพราะ "ครู" เดิมถูกเปลี่ยนชื่อเป็น "ผู้ใช้งาน")
--  FK ไม่ cascade ฐานข้อมูลจึงไม่ให้ลบสิทธิ์นั้น
--
--  แก้:
--    1) แถว UserRoles ของสิทธิ์ที่จะลบ → ย้ายไปแม่แบบของโรงเรียนเดียวกัน (เดิมคือ "ครู")
--       เฉพาะสิทธิ์ที่ไม่มีบุคลากรใช้และไม่ใช่สิทธิ์กลาง
--    2) FK id_role ของ UserRoles → on delete cascade (ลบสิทธิ์ได้เลยในอนาคต)
--  ไม่ลบสิทธิ์ให้เอง — กดลบที่เว็บกลาง / แอปอีกครั้งหลังรันไฟล์นี้
-- ============================================================================

begin;

-- 1) ย้ายแถว UserRoles จากสิทธิ์ที่ไม่มีคนใช้ ไปแม่แบบของโรงเรียนนั้น
update public."UserRoles" ur
set id_role = tpl."ID_Roles"
from public.roles r
join public.roles tpl
  on tpl.id_school = r.id_school and tpl.is_default_teacher
where ur.id_role = r."ID_Roles"
  and r.id_school is not null
  and not r.is_default_teacher
  and not exists (select 1 from public."Teachers" t where t.id_role = r."ID_Roles");

-- 2) FK → cascade
do $$
declare
  fk record;
begin
  for fk in
    select c.conname
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
    where c.contype = 'f'
      and c.conrelid = 'public."UserRoles"'::regclass
      and c.confrelid = 'public.roles'::regclass
      and a.attname = 'id_role'
  loop
    execute format('alter table public."UserRoles" drop constraint %I', fk.conname);
  end loop;

  alter table public."UserRoles"
    add constraint "UserRoles_id_role_fkey" foreign key (id_role)
    references public.roles("ID_Roles") on delete cascade;
end $$;

commit;

-- ตรวจผล: สิทธิ์ที่ลบได้ (บุคลากร 0 และไม่ใช่สิทธิ์กลาง) ต้องมี UserRoles = 0
select r."ID_Roles", r."Accessrights" as สิทธิ์, r.id_school,
       (select count(*) from public."Teachers" t where t.id_role = r."ID_Roles") as บุคลากร,
       (select count(*) from public."UserRoles" u where u.id_role = r."ID_Roles") as "UserRoles"
from public.roles r
order by r."ID_Roles" desc;
