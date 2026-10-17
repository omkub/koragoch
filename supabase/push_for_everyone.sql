-- ============================================================================
--  แจ้งเตือนบนเครื่อง (Web Push) สำหรับทุกคน + แจ้งผลการอนุมัติใบลาให้เจ้าของ
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  ต้องรันก่อนแล้ว: notifications.sql, push_notifications.sql
--  ต้อง deploy Edge Function push-notify ใหม่ด้วย (ปุ่มทดสอบใช้ได้ทุกคน)
--
--  ใครได้อะไร:
--    ใบลาใหม่            → ผู้ดูแลระบบของโรงเรียนนั้น + ส่วนกลาง (เหมือนเดิม)
--    ใบลาอนุมัติแล้ว      → เจ้าของใบลาคนเดียว (ทุกสิทธิ์ รวมครู / ผู้บริหาร)
--    ใบลาไม่อนุมัติ/ยกเลิก → เจ้าของใบลาคนเดียว
--    ครู / ผู้บริหาร ไม่ได้แจ้งเตือนใบลาของคนอื่น
--
--  สถานะ (ตรงกับแอป lib/screens/mobile_v2/leave_actions.dart):
--    อนุมัติ     = ส่งใบแล้ว / ส่งใบลาแล้ว / อนุมัติแล้ว / อนุญาต / มีคำว่า อนุมัติ ที่ไม่มี ไม่
--    รอพิจารณา  = มีคำว่า รอ / พิจารณา  (ไม่แจ้ง)
--    อื่น ๆ      = ไม่อนุมัติ / ส่งกลับ (ยังไม่ส่ง, ไม่อนุญาต, ยกเลิก ...)
--
--  ปิดเฉพาะแจ้งผลอนุมัติ:
--    drop trigger if exists notify_leave_status on public."Leaves";
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ทุกคนเปิดรับแจ้งเตือนบนเครื่องของตัวเองได้ (เดิมเฉพาะผู้ดูแลระบบ)
--    current_teacher_id() นับเฉพาะบุคลากรที่ยังปฏิบัติงาน (staff_status.sql)
-- ----------------------------------------------------------------------------

drop policy if exists push_insert on public."PushSubscriptions";
create policy push_insert on public."PushSubscriptions"
  for insert to authenticated
  with check (id_user = public.current_teacher_id());

drop policy if exists push_update on public."PushSubscriptions";
create policy push_update on public."PushSubscriptions"
  for update to authenticated
  using (id_user = public.current_teacher_id())
  with check (id_user = public.current_teacher_id());

comment on table public."PushSubscriptions" is
  'เครื่องที่เปิดแจ้งเตือนแบบแอป (Web Push) — ทุกคนเปิดของตัวเองได้';


-- ----------------------------------------------------------------------------
-- 2) กลุ่มของสถานะใบลา: approved / pending / returned
-- ----------------------------------------------------------------------------

create or replace function public.leave_status_group(s text)
returns text
language sql immutable
as $$
  select case
    when s is null or btrim(s) = '' then 'pending'
    when s in ('ส่งใบแล้ว', 'ส่งใบลาแล้ว', 'อนุมัติแล้ว', 'อนุญาต')
      or (s like '%อนุมัติ%' and s not like '%ไม่%') then 'approved'
    when s like '%รอ%' or s like '%พิจารณา%' then 'pending'
    else 'returned'
  end;
$$;


-- ----------------------------------------------------------------------------
-- 3) อนุมัติ / ไม่อนุมัติ → แจ้งเจ้าของใบลา (กระดิ่งในแอป + เด้งที่เครื่อง
--    ผ่าน trigger push_new_notification ที่มีอยู่แล้ว)
--    ไม่แจ้งถ้าเจ้าของเป็นคนเปลี่ยนเอง / พ้นสภาพแล้ว / ใบลานำเข้าจาก Firebase
--    สร้างแจ้งเตือนไม่สำเร็จ ใบลายังบันทึกได้ตามปกติ
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

  select id_user, id_school, employment_status into owner
  from "Teachers" t where t.id_user = new.id_user;
  if not found
     or coalesce(owner.employment_status, 'active') <> 'active'
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

drop trigger if exists notify_leave_status on public."Leaves";
create trigger notify_leave_status
  after update of status on public."Leaves"
  for each row execute function public.notify_leave_status();


notify pgrst, 'reload schema';


-- ----------------------------------------------------------------------------
-- 4) ตรวจผล — trigger = 1 / policy insert ไม่มี is_admin แล้ว
--    ลองกดอนุมัติใบลาสักใบ แล้วดู:
--      select type, title, body, recipient_id from public."AppNotifications"
--      order by id_notification desc limit 5;
-- ----------------------------------------------------------------------------

select (select count(*) from pg_trigger
         where tgname = 'notify_leave_status' and not tgisinternal)          as trigger_ผลอนุมัติ,
       (select with_check from pg_policies
         where schemaname = 'public' and tablename = 'PushSubscriptions'
           and policyname = 'push_insert')                                     as push_insert_check,
       public.leave_status_group('ส่งใบแล้ว')                                  as ส่งใบแล้ว,
       public.leave_status_group('ยังไม่ส่ง')                                  as ยังไม่ส่ง,
       public.leave_status_group('รอพิจารณา')                                  as รอพิจารณา;
