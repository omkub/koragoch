-- ============================================================================
--  สถานะบุคลากรมีผลตาม "วันที่มีผล" ไม่ใช่ทันทีที่กดบันทึก
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  ต้องรันก่อนแล้ว: staff_status.sql, push_notifications.sql,
--  push_for_everyone.sql
--
--  ปัญหาเดิม: ตั้ง "ย้าย มีผล 26/10/69" ตั้งแต่วันที่ 20/10/69 แล้วคนนั้น
--    หายจากรายชื่อ + ล็อกอินไม่ได้ทันทีวันที่ 20 — ฐานข้อมูลดูแค่ว่าสถานะ
--    ไม่ใช่ active ไม่ได้ดูวันที่
--
--  หลักใหม่ (left_date = วันแรกที่ไม่ได้ปฏิบัติงาน เหมือนเดิม):
--    ยังทำงาน = สถานะ active  หรือ  ยังไม่ถึง left_date
--    มีผล 26/10/69 → วันที่ 25 ยังทำงาน ล็อกอินได้ · วันที่ 26 หายจากรายชื่อ
--    ไม่ใส่วันที่ = มีผลทันที (เหมือนเดิม)
--
--  "วันนี้" ใช้เวลาไทยเสมอ — current_date ของ Supabase เป็นเวลา UTC
--  ถ้าใช้ตรงๆ ช่วงเที่ยงคืนถึงตีเจ็ดของไทยจะยังนับเป็นวันก่อนหน้า
--  คนที่มีผลวันนี้จะยังล็อกอินได้อีกเจ็ดชั่วโมง
--
--  ⚠️ ไฟล์นี้เขียนทับฟังก์ชันจาก staff_status.sql, push_notifications.sql และ
--     push_for_everyone.sql — ไฟล์เหล่านั้นแก้ให้ตรงกันแล้ว รันซ้ำทีหลังได้
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) วันนี้ตามเวลาไทย + ตัวตัดสินว่ายังปฏิบัติงานอยู่หรือไม่
-- ----------------------------------------------------------------------------

create or replace function public.today_th()
returns date
language sql
stable
as $$
  select (now() at time zone 'Asia/Bangkok')::date;
$$;

create or replace function public.staff_is_working(status text, left_on date)
returns boolean
language sql
stable
as $$
  select coalesce(status, 'active') = 'active'
      or (left_on is not null and left_on > public.today_th());
$$;

comment on function public.staff_is_working(text, date) is
  'ยังปฏิบัติงานอยู่วันนี้ (เวลาไทย): สถานะ active หรือยังไม่ถึงวันที่พ้นสภาพ';

grant execute on function public.today_th() to anon, authenticated;
grant execute on function public.staff_is_working(text, date) to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 2) ตัวตนใน RLS — เงื่อนไขเดิมทุกตัวจาก staff_status.sql เปลี่ยนแค่การดูสถานะ
-- ----------------------------------------------------------------------------

create or replace function public.current_teacher_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select t.id_user
  from "Teachers" t
  where t.auth_uid = auth.uid()
    and public.staff_is_working(t.employment_status, t.left_date)
  limit 1;
$$;

create or replace function public.current_school_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select t.id_school
  from "Teachers" t
  where t.auth_uid = auth.uid()
    and public.staff_is_working(t.employment_status, t.left_date)
  limit 1;
$$;

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
      and public.staff_is_working(t.employment_status, t.left_date)
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
      and public.staff_is_working(t.employment_status, t.left_date)
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
      and public.staff_is_working(t.employment_status, t.left_date)
  );
$$;


-- ----------------------------------------------------------------------------
-- 3) สถานะที่หน้าล็อกอินใช้ — คืน 'active' ถ้ายังไม่ถึงวันที่มีผล
--    (หน้าล็อกอินเด้งคนที่สถานะไม่ใช่ active ออก จึงต้องคืนสถานะ "ณ วันนี้")
-- ----------------------------------------------------------------------------

create or replace function public.my_employment_status()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.staff_is_working(t.employment_status, t.left_date) then 'active'
    else t.employment_status
  end
  from "Teachers" t
  where t.auth_uid = auth.uid()
  limit 1;
$$;

grant execute on function public.my_employment_status() to authenticated;


-- ----------------------------------------------------------------------------
-- 4) แจ้งเตือนใบลาใหม่ → ผู้ดูแลระบบที่ยังปฏิบัติงานวันนี้
--    (เหมือน push_notifications.sql ทุกอย่าง เปลี่ยนแค่เงื่อนไขสถานะท้ายฟังก์ชัน)
-- ----------------------------------------------------------------------------

create or replace function public.notify_new_leave()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  leave     jsonb := to_jsonb(new);
  owner     record;
  type_name text;
  start_d   date;
  end_d     date;
  days      text;
  when_text text;
  actor     bigint := public.current_teacher_id();
begin
  if leave ->> 'firebase_id' is not null then
    return new;
  end if;

  select id_user, id_school, coalesce(to_jsonb(t) ->> 'fullName', to_jsonb(t) ->> 'fullname', '-') as name
    into owner
  from "Teachers" t where t.id_user = new.id_user;
  if not found then
    return new;
  end if;

  select coalesce(to_jsonb(lt) ->> 'leaveName', to_jsonb(lt) ->> 'Value')
    into type_name
  from "LeaveTypes" lt
  where (to_jsonb(lt) ->> 'id_leaveType') = leave ->> 'id_leaveType'
  limit 1;

  start_d := nullif(leave ->> 'startDate', '')::date;
  end_d   := coalesce(nullif(leave ->> 'endDate', '')::date, start_d);
  days    := nullif(leave ->> 'totalDays', '');
  when_text := case
    when start_d is null then ''
    when end_d = start_d then public.thai_short_date(start_d)
    else public.thai_short_date(start_d) || ' – ' || public.thai_short_date(end_d)
  end;

  insert into "AppNotifications"
    (id_school, recipient_id, type, title, body, ref_table, ref_id, actor_id)
  select owner.id_school,
         a.id_user,
         'leave_new',
         owner.name || ' ยื่น' || coalesce(type_name, 'ใบลา'),
         concat_ws(' · ',
           nullif(when_text, ''),
           case when days is not null
                then trim_scale(days::numeric)::text || ' วัน' end,
           nullif(leave ->> 'reason', '')),
         'Leaves',
         (leave ->> 'id_leaves')::bigint,
         actor
  from "Teachers" a
  where a.id_role = 22
    and public.staff_is_working(a.employment_status, a.left_date)
    and (a.id_school = owner.id_school or a.is_super_admin)
    and a.id_user <> owner.id_user
    and a.id_user is distinct from actor;

  return new;
exception when others then
  raise warning 'notify_new_leave: %', sqlerrm;
  return new;
end;
$$;


-- ----------------------------------------------------------------------------
-- 5) แจ้งผลอนุมัติ → เจ้าของใบลาที่ยังปฏิบัติงานวันนี้
--    (เหมือน push_for_everyone.sql ทุกอย่าง เปลี่ยนแค่การดูสถานะเจ้าของ)
-- ----------------------------------------------------------------------------

create or replace function public.notify_leave_status()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  leave     jsonb := to_jsonb(new);
  new_group text  := public.leave_status_group(new.status::text);
  old_group text  := public.leave_status_group(old.status::text);
  owner     record;
  type_name text;
  start_d   date;
  end_d     date;
  when_text text;
  actor     bigint := public.current_teacher_id();
begin
  if new_group = old_group or new_group = 'pending' then
    return new;
  end if;

  select id_user, id_school, employment_status, left_date into owner
  from "Teachers" t where t.id_user = new.id_user;
  if not found
     or not public.staff_is_working(owner.employment_status, owner.left_date)
     or owner.id_user is not distinct from actor then
    return new;
  end if;

  select coalesce(to_jsonb(lt) ->> 'leaveName', to_jsonb(lt) ->> 'Value')
    into type_name
  from "LeaveTypes" lt
  where (to_jsonb(lt) ->> 'id_leaveType') = leave ->> 'id_leaveType'
  limit 1;

  start_d := nullif(leave ->> 'startDate', '')::date;
  end_d   := coalesce(nullif(leave ->> 'endDate', '')::date, start_d);
  when_text := case
    when start_d is null then ''
    when end_d = start_d then public.thai_short_date(start_d)
    else public.thai_short_date(start_d) || ' – ' || public.thai_short_date(end_d)
  end;

  insert into "AppNotifications"
    (id_school, recipient_id, type, title, body, ref_table, ref_id, actor_id)
  values (
    owner.id_school,
    owner.id_user,
    case new_group when 'approved' then 'leave_approved' else 'leave_returned' end,
    case new_group
      when 'approved' then coalesce(type_name, 'ใบลา') || 'ของคุณได้รับอนุมัติแล้ว'
      else coalesce(type_name, 'ใบลา') || 'ของคุณไม่ได้รับอนุมัติ'
    end,
    concat_ws(' · ',
      nullif(when_text, ''),
      case
        when new_group = 'approved' and nullif(leave ->> 'receiveNumber', '') is not null
          then 'เลขรับ ' || (leave ->> 'receiveNumber')
        when new_group = 'returned' then 'แก้ไขแล้วส่งใหม่ได้'
      end),
    'Leaves',
    (leave ->> 'id_leaves')::bigint,
    actor
  );

  return new;
exception when others then
  raise warning 'notify_leave_status: %', sqlerrm;
  return new;
end;
$$;


notify pgrst, 'reload schema';


-- ----------------------------------------------------------------------------
-- 6) ตรวจผล — วันนี้ (เวลาไทย) และคนที่ "ตั้งสถานะแล้วแต่ยังไม่ถึงวันที่มีผล"
--    คนกลุ่มนี้ต้องขึ้น ยังทำงาน = true (ก่อนรันไฟล์นี้ พวกเขาถูกล็อกไว้แล้ว)
-- ----------------------------------------------------------------------------

select public.today_th() as วันนี้_เวลาไทย;

select id_school, id_user,
       coalesce(to_jsonb(t) ->> 'fullName', to_jsonb(t) ->> 'fullname') as ชื่อ,
       employment_status as สถานะ,
       left_date        as มีผลตั้งแต่,
       public.staff_is_working(employment_status, left_date) as ยังทำงาน
from public."Teachers" t
where employment_status <> 'active'
order by left_date desc nulls last;
