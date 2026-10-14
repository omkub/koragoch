-- ============================================================================
--  หน้าจอมือถือรายสิทธิ์ในแต่ละโรงเรียน (โรงเรียน × สิทธิ์)
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง ต้องรัน school_mobile_ui.sql มาก่อนแล้ว
--
--  Schools.mobile_ui_by_role = { "<ID_Roles>": "new" | "old" }
--    ไม่มีคีย์ของสิทธิ์ไหน = ใช้ค่าของโรงเรียน (Schools.mobile_ui)
--    ค่าเริ่มต้น {} = ทุกสิทธิ์ตามโรงเรียน (รันไฟล์นี้แล้วยังไม่มีใครเห็นหน้าเปลี่ยน)
--
--  ตั้งค่าที่เว็บส่วนกลาง > โรงเรียน > แก้ไข — แก้ได้เฉพาะผู้ดูแลส่วนกลาง
--  แอปอ่านตอนเปิดแอป/ล็อกอิน (ตามสิทธิ์ใน Teachers.id_role)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) คอลัมน์ + ตรวจรูปแบบ
-- ----------------------------------------------------------------------------

create or replace function public.valid_mobile_ui_map(m jsonb)
returns boolean
language sql
immutable
as $$
  select jsonb_typeof(m) = 'object'
     and coalesce((select bool_and(e.value in ('new', 'old'))
                   from jsonb_each_text(m) e), true);
$$;

alter table public."Schools"
  add column if not exists mobile_ui_by_role jsonb not null default '{}'::jsonb;

alter table public."Schools"
  drop constraint if exists schools_mobile_ui_by_role_check;
alter table public."Schools"
  add constraint schools_mobile_ui_by_role_check
  check (public.valid_mobile_ui_map(mobile_ui_by_role));

comment on column public."Schools".mobile_ui_by_role is
  'หน้าจอมือถือรายสิทธิ์ {"ID_Roles": "new"|"old"} ไม่มีคีย์ = ตามโรงเรียน (mobile_ui) — แก้ได้เฉพาะผู้ดูแลส่วนกลาง';


-- ----------------------------------------------------------------------------
-- 2) กันแอดมินโรงเรียนเปลี่ยนค่าเอง (แทนที่ฟังก์ชันจาก school_mobile_ui.sql
--    ให้ตรวจทั้ง mobile_ui และ mobile_ui_by_role)
-- ----------------------------------------------------------------------------

create or replace function public.guard_school_mobile_ui()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.is_super_admin()
     and (
       (tg_op = 'INSERT' and (new.mobile_ui <> 'new'
                              or new.mobile_ui_by_role <> '{}'::jsonb))
       or (tg_op = 'UPDATE' and (new.mobile_ui is distinct from old.mobile_ui
                                 or new.mobile_ui_by_role is distinct from old.mobile_ui_by_role))
     ) then
    raise exception 'เปลี่ยนหน้าจอมือถือได้เฉพาะผู้ดูแลระบบส่วนกลาง';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_school_mobile_ui on public."Schools";
create trigger guard_school_mobile_ui
  before insert or update on public."Schools"
  for each row execute function public.guard_school_mobile_ui();


-- ----------------------------------------------------------------------------
-- 3) ตรวจผล — หลังรันครั้งแรก mobile_ui_by_role ต้องเป็น {} ทุกแถว
-- ----------------------------------------------------------------------------

select id_school, "fullName", mobile_ui, mobile_ui_by_role
from public."Schools"
order by id_school;
