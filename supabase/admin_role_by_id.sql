-- ============================================================================
--  สิทธิ์แก้ไขข้อมูล = ผู้ดูแลระบบ ตัดสินจาก Teachers.id_role = 22 เท่านั้น
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  (ต้องรัน super_admin.sql มาก่อนแล้ว)
--
--  เดิม is_admin() เทียบ "ชื่อ" สิทธิ์ roles.Accessrights = 'ผู้ดูแลระบบ'
--  และถ้า id_role ว่าง จะไปใช้คอลัมน์ข้อความ Teachers.role แทน
--  → เปลี่ยนชื่อ role ในตารางแล้วแอดมินหายสิทธิ์ทั้งระบบ
--  → ครูที่ id_role ว่างแต่ช่อง role เขียนว่า "ผู้ดูแลระบบ" ได้สิทธิ์แอดมิน
--
--  ตอนนี้ยึดเลข id_role อย่างเดียว:
--    22 = ผู้ดูแลระบบ   แก้ข้อมูลหลักได้ (ครู, กลุ่มสาระ, ปีงบ, ประเภทลา ฯลฯ)
--    24 = ผู้บริหาร     อนุมัติ/แก้ใบลาได้เหมือนเดิม (is_approver)
--    23 = ครู           แก้ได้แค่ข้อมูลตัวเองและใบลาของตัวเอง
--
--  ผู้ดูแลส่วนกลาง (is_super_admin) ต้องมี id_role = 22 ด้วย
--  ถ้าถูกลดสิทธิ์เป็นอย่างอื่น ธงส่วนกลางจะไม่มีผลทันที
--
--  policy ทุกตัวเรียกฟังก์ชันเหล่านี้อยู่แล้ว จึงไม่ต้องแก้ policy
-- ============================================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from "Teachers" t
    where t.auth_uid = auth.uid() and t.id_role = 22
  );
$$;

create or replace function public.is_approver()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from "Teachers" t
    where t.auth_uid = auth.uid() and t.id_role in (22, 24)
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from "Teachers" t
    where t.auth_uid = auth.uid()
      and t.id_role = 22
      and t.is_super_admin
  );
$$;


-- ----------------------------------------------------------------------------
-- ตรวจผล — รายชื่อคนที่เป็นผู้ดูแลระบบ (id_role = 22) ตอนนี้
-- ถ้ามีคนที่ไม่ควรเป็นแอดมินอยู่ในรายการ ให้แก้ id_role ของคนนั้น
-- ----------------------------------------------------------------------------

select t.id_user,
       t.username,
       t."fullName",
       t.id_school,
       t.is_super_admin  as ส่วนกลาง
from public."Teachers" t
where t.id_role = 22
order by t.id_school, t.id_user;
