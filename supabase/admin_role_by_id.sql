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
--    22 = ผู้ดูแลระบบ   คนเดียวที่แก้ข้อมูลได้ — ข้อมูลหลัก + อนุมัติ/แก้ใบลาทุกใบ
--    24 = ผู้บริหาร     ดูได้ แต่อนุมัติหรือแก้ใบลาของคนอื่นไม่ได้
--    23 = ครู           ยื่นใบลาของตัวเอง แก้/ลบได้เฉพาะใบที่ยังไม่อนุมัติ
--
--  ครูและผู้บริหาร "อนุมัติใบลาเองไม่ได้" (ข้อ 2) — เดิม policy ให้เจ้าของแก้
--  ใบลาของตัวเองได้ทุกคอลัมน์ จึงเปิด devtools ตั้งสถานะ "ส่งใบแล้ว" +
--  เลขรับให้ตัวเองได้
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
    where t.auth_uid = auth.uid() and t.id_role = 22
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
-- 2) อนุมัติใบลาได้เฉพาะผู้ดูแลระบบ
--
--    คนอื่น (เจ้าของใบลา):
--      ยื่นใหม่ได้เฉพาะสถานะรอพิจารณา/ยังไม่ส่ง และห้ามใส่เลขรับเอง
--      แก้ได้เฉพาะใบที่ยังไม่อนุมัติ และห้ามเปลี่ยนสถานะหรือเลขรับ
--      ลบได้เฉพาะใบที่ยังไม่อนุมัติ
--    ใช้ to_jsonb เทียบ เผื่อบางคอลัมน์ไม่มีในตาราง
-- ----------------------------------------------------------------------------

create or replace function public.guard_leave_approval()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pending constant text[] := array['รอพิจารณา', 'ยังไม่ส่ง'];
  row_status text;
  col text;
begin
  if auth.uid() is null or public.is_admin() then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    row_status := to_jsonb(new) ->> 'status';
    if row_status is not null and not (row_status = any (pending)) then
      raise exception 'สถานะ "%" ตั้งได้เฉพาะผู้ดูแลระบบ', row_status;
    end if;
    foreach col in array array['receiveNumber', 'receiveDate', 'receiveTime'] loop
      if coalesce(to_jsonb(new) ->> col, '') <> '' then
        raise exception 'เลขรับใบลากำหนดได้เฉพาะผู้ดูแลระบบ';
      end if;
    end loop;
    return new;
  end if;

  -- UPDATE / DELETE: ใบที่อนุมัติแล้วแตะไม่ได้
  row_status := to_jsonb(old) ->> 'status';
  if row_status is not null and not (row_status = any (pending)) then
    raise exception 'ใบลาที่ดำเนินการแล้ว แก้ไขหรือลบได้เฉพาะผู้ดูแลระบบ';
  end if;

  if tg_op = 'UPDATE' then
    foreach col in array array['status', 'receiveNumber', 'receiveDate', 'receiveTime'] loop
      if (to_jsonb(new) -> col) is distinct from (to_jsonb(old) -> col) then
        raise exception 'อนุมัติหรือเปลี่ยนสถานะใบลาได้เฉพาะผู้ดูแลระบบ';
      end if;
    end loop;
    return new;
  end if;

  return old;
end;
$$;

drop trigger if exists guard_leave_approval on public."Leaves";
create trigger guard_leave_approval
  before insert or update or delete on public."Leaves"
  for each row execute function public.guard_leave_approval();


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
