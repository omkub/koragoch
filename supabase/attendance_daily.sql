-- ============================================================================
--  ลงเวลาด้วยเครื่องสแกนหน้า — พาร์ท 4–6: สถานะรายวัน / แก้เวลา / ยินยอม / LINE
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (ข้อมูล/ค่าที่ตั้งไว้แล้วไม่หาย)
--  ต้องรันก่อนแล้ว: attendance.sql, attendance_permissions.sql,
--                  official_trips.sql, fine_permissions.sql
--
--  สิ่งที่เพิ่ม:
--    1) AttendanceSettings: วันเริ่มใช้ระบบ + ตั้งค่าสรุป LINE ประจำวัน
--    2) Teachers.attendance_exempt  คนที่ไม่ต้องสแกน (เช่น บัญชีกลาง / ลูกจ้างนอกระบบ)
--    3) "ยกเลิก" การสแกนที่ผิด แทนการลบ — แถวยังอยู่ พร้อมเหตุผลและคนที่ยกเลิก
--       (แก้เวลา = ยกเลิกแถวเดิม + เพิ่มเวลาใหม่แบบ manual ซึ่งต้องมีเหตุผลอยู่แล้ว)
--    4) set_face_consent()  ครูกดยินยอม/ถอนความยินยอมใช้ข้อมูลใบหน้า (PDPA ม.26)
--    5) attendance_day_status()  สถานะของแต่ละคนในแต่ละวัน
--         มา / สาย / ลา / ไปราชการ / วันหยุด / ขาด / ยังไม่สแกน / ยังไม่ถึง /
--         ยังไม่เริ่มใช้
--       รวมข้อมูลจาก AttendanceLogs + Leaves + OfficialTrips + วันหยุด/วันทำงานพิเศษ
--       app / รายงานรายเดือน / สรุป LINE ใช้ฟังก์ชันเดียวกันนี้ทั้งหมด
--    6) attendance_summary()  นับรวมต่อคนในช่วงวันที่ (รายงานรายเดือน)
--
--  การตั้งเวลาส่ง LINE อัตโนมัติอยู่อีกไฟล์: attendance_line_cron.sql (ไม่บังคับ)
--
--  ย้อนกลับ:
--    drop function if exists public.attendance_summary(bigint, date, date),
--                            public.attendance_day_status(bigint, date, date, bigint),
--                            public.void_attendance_log(bigint, text),
--                            public.set_face_consent(boolean);
--    alter table public."AttendanceLogs" drop column if exists voided_at,
--      drop column if exists voided_by, drop column if exists void_reason;
--    alter table public."Teachers" drop column if exists attendance_exempt;
--    alter table public."AttendanceSettings" drop column if exists start_date,
--      drop column if exists line_summary_enabled, drop column if exists line_summary_time,
--      drop column if exists line_list_missing, drop column if exists line_summary_sent_on;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ตั้งค่าเพิ่ม (web ตั้ง)
--
--    start_date            วันแรกที่ใช้ระบบจริง — ก่อนวันนี้ไม่นับว่า "ขาด"
--                          ว่าง = ใช้วันที่มีการสแกนครั้งแรกของโรงเรียน
--    line_summary_enabled  ส่งสรุปประจำวันเข้ากลุ่ม LINE ของโรงเรียน
--    line_summary_time     เวลาที่ส่ง (เวลาไทย)
--    line_list_missing     แนบรายชื่อคนที่ยังไม่สแกนไปด้วย
--    line_summary_sent_on  วันที่ส่งล่าสุด (ระบบเขียนเอง กันส่งซ้ำ)
-- ----------------------------------------------------------------------------

alter table public."AttendanceSettings"
  add column if not exists start_date           date,
  add column if not exists line_summary_enabled boolean not null default false,
  add column if not exists line_summary_time    time    not null default '09:00',
  add column if not exists line_list_missing    boolean not null default true,
  add column if not exists line_summary_sent_on date;


-- ----------------------------------------------------------------------------
-- 2) คนที่ไม่ต้องสแกน — ไม่ถูกนับในรายงาน / สรุป
-- ----------------------------------------------------------------------------

alter table public."Teachers"
  add column if not exists attendance_exempt boolean not null default false;

-- ครูแก้แถวตัวเองได้ — กันไม่ให้ตั้งรหัสเครื่องหรือยกเว้นตัวเอง
-- (แทนฟังก์ชันเดิมใน attendance.sql เพิ่มการกัน attendance_exempt)
create or replace function public.guard_teacher_device_code()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if new.device_code is distinct from old.device_code then
      raise exception 'รหัสเครื่องสแกนกำหนดได้เฉพาะผู้ดูแลระบบ';
    end if;
    if new.attendance_exempt is distinct from old.attendance_exempt then
      raise exception 'การยกเว้นไม่ต้องสแกนกำหนดได้เฉพาะผู้ดูแลระบบ';
    end if;
  end if;
  new.device_code := nullif(trim(new.device_code), '');
  return new;
end;
$$;


-- ----------------------------------------------------------------------------
-- 3) ยกเลิกการสแกน (แทนการลบ)
--
--    แอดมินโรงเรียนลบข้อมูลจากเครื่องไม่ได้ (RLS เดิม) แต่เวลาจากเครื่องอาจผิด
--    เช่น นาฬิกาเครื่องเพี้ยน / สแกนผิดคน — จึง "ยกเลิก" ได้ ต้องมีเหตุผล
--    แถวยังอยู่ให้ตรวจย้อนหลังได้ว่าใครยกเลิก เมื่อไร เพราะอะไร
-- ----------------------------------------------------------------------------

alter table public."AttendanceLogs"
  add column if not exists voided_at   timestamptz,
  add column if not exists voided_by   bigint references public."Teachers"(id_user) on delete set null,
  add column if not exists void_reason text;

create or replace function public.void_attendance_log(p_id bigint, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  log_school bigint;
begin
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'ต้องระบุเหตุผลที่ยกเลิก';
  end if;

  select id_school into log_school from "AttendanceLogs" where id_log = p_id;
  if not found then
    raise exception 'ไม่พบรายการสแกนนี้';
  end if;

  if not (public.is_super_admin()
          or (public.is_admin()
              and public.can_see_school(log_school)
              and public.has_permission('attendance.edit'))) then
    raise exception 'ไม่มีสิทธิ์แก้เวลาสแกน';
  end if;

  update "AttendanceLogs"
  set voided_at = now(),
      voided_by = public.current_teacher_id(),
      void_reason = trim(p_reason)
  where id_log = p_id and voided_at is null;
end;
$$;

revoke execute on function public.void_attendance_log(bigint, text) from public, anon;
grant  execute on function public.void_attendance_log(bigint, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 4) ความยินยอมใช้ข้อมูลใบหน้า — ครูกดเองจาก app
--    true = ยินยอม (บันทึกเวลา) / false = ถอนความยินยอม (ล้างเวลา)
-- ----------------------------------------------------------------------------

create or replace function public.set_face_consent(p_consent boolean)
returns timestamptz
language plpgsql security definer set search_path = public
as $$
declare
  me bigint := public.current_teacher_id();
  result timestamptz;
begin
  if me is null then
    raise exception 'ต้องเข้าสู่ระบบก่อน';
  end if;
  update "Teachers"
  set face_consent_at = case when p_consent then now() end
  where id_user = me
  returning face_consent_at into result;
  return result;
end;
$$;

revoke execute on function public.set_face_consent(boolean) from public, anon;
grant  execute on function public.set_face_consent(boolean) to authenticated;


-- ----------------------------------------------------------------------------
-- 5) สถานะรายวัน
--
--    ลำดับการตัดสิน (ข้อแรกที่ตรง):
--      ยังไม่ถึง     วันในอนาคต
--      วันหยุด       เสาร์-อาทิตย์ / วันหยุดพิเศษ (ยกเว้นวันทำงานพิเศษ)
--      ไปราชการ      อยู่ในรายการไปราชการเต็มวันที่ไม่ถูกปฏิเสธ
--      ลา            มีใบลาเต็มวันที่ไม่ถูกยกเลิก
--      ยังไม่เริ่มใช้  ก่อนวันเริ่มใช้ระบบของโรงเรียน
--      มา / สาย      มีการสแกน (สาย = สแกนแรกหลัง late_after)
--                    ลา/ไปราชการครึ่งวัน + มาสาย → นับ "มา" (มีเหตุผลแล้ว)
--      ลา / ไปราชการ  ครึ่งวันที่ไม่ได้สแกน
--      ยังไม่สแกน    วันนี้ ยังไม่มีการสแกน
--      ขาด           วันที่ผ่านมาแล้ว ไม่มีการสแกนและไม่มีเหตุผล
--
--    note: ชนิดการลา / ชื่อเรื่องไปราชการ / ครึ่งวัน / ไม่สแกนออก / ออกก่อนเวลา
--
--    สิทธิ์:
--      ไม่มีการล็อกอิน (service role / SQL Editor)  → ทุกคน
--      มีสิทธิ์ attendance.view_all ในโรงเรียนนั้น  → ทุกคนในโรงเรียน
--      นอกนั้น                                     → เฉพาะของตัวเอง
--    ช่วงวันที่ได้ไม่เกิน 92 วันต่อครั้ง
-- ----------------------------------------------------------------------------

create or replace function public.attendance_day_status(
  p_school bigint,
  p_from   date,
  p_to     date,
  p_user   bigint default null
)
returns table (
  id_user      bigint,
  full_name    text,
  day          date,
  status       text,
  first_scan   timestamptz,
  last_scan    timestamptz,
  scan_count   integer,
  late_minutes integer,
  note         text
)
language plpgsql stable security definer set search_path = public
as $$
declare
  cfg        "AttendanceSettings";
  only_user  bigint := p_user;
  today      date := (now() at time zone 'Asia/Bangkok')::date;
  now_local  time := (now() at time zone 'Asia/Bangkok')::time;
  first_day  date;
begin
  if p_school is null or p_from is null or p_to is null then
    raise exception 'ต้องระบุโรงเรียนและช่วงวันที่';
  end if;
  if p_to < p_from then
    raise exception 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม';
  end if;
  if p_to - p_from > 92 then
    raise exception 'ดูได้ครั้งละไม่เกิน 3 เดือน';
  end if;

  if auth.uid() is not null then
    if not public.can_see_school(p_school) then
      raise exception 'ไม่มีสิทธิ์ดูข้อมูลของโรงเรียนนี้';
    end if;
    if not public.has_permission('attendance.view_all') then
      only_user := public.current_teacher_id();
    end if;
  end if;

  select * into cfg from "AttendanceSettings" s where s.id_school = p_school;
  if not found then
    cfg.late_after := '08:30';
    cfg.work_end := '16:30';
    cfg.require_checkout := false;
  end if;

  first_day := coalesce(
    cfg.start_date,
    (select min((l.scanned_at at time zone 'Asia/Bangkok')::date)
     from "AttendanceLogs" l
     where l.id_school = p_school and l.voided_at is null));

  return query
  with days as (
    select g::date as d
    from generate_series(p_from, p_to, interval '1 day') g
  ),
  people as (
    select t.id_user as uid, coalesce(t."fullName", '') as name
    from "Teachers" t
    where t.id_school = p_school
      and not t.attendance_exempt
      and not coalesce(t.is_super_admin, false)
      and (only_user is null or t.id_user = only_user)
  ),
  holidays as (
    select distinct h.date as d from "SpecialHolidays" h
    where h.date between p_from and p_to
      and (h.id_school is null or h.id_school = p_school)
  ),
  workdays as (
    select distinct w.date as d from "SpecialWorkingDays" w
    where w.date between p_from and p_to
      and (w.id_school is null or w.id_school = p_school)
  ),
  scans as (
    select l.id_user as uid,
           (l.scanned_at at time zone 'Asia/Bangkok')::date as d,
           min(l.scanned_at) as first_at,
           max(l.scanned_at) as last_at,
           count(*)::int as n
    from "AttendanceLogs" l
    where l.id_school = p_school
      and l.id_user is not null
      and l.voided_at is null
      and l.scanned_at >= (p_from::timestamp at time zone 'Asia/Bangkok')
      and l.scanned_at <  ((p_to + 1)::timestamp at time zone 'Asia/Bangkok')
    group by 1, 2
  ),
  -- เต็มวันมาก่อนครึ่งวัน (ถ้าวันเดียวกันมีทั้งสองแบบ)
  leaves as (
    select distinct on (lv.id_user, dd.d)
           lv.id_user as uid, dd.d,
           coalesce(nullif(trim(lt."leaveName"), ''), 'ลา') as label,
           coalesce(lv."isHalfDay", false) as half
    from "Leaves" lv
    join days dd on dd.d between lv."startDate" and coalesce(lv."endDate", lv."startDate")
    left join "LeaveTypes" lt on lt."id_leaveType" = lv."id_leaveType"
    where lv.id_school = p_school
      and lv."startDate" is not null
      and coalesce(lv.status, '') not like '%ยกเลิก%'
      and coalesce(lv.status, '') not like '%ไม่อนุมัติ%'
    order by lv.id_user, dd.d, coalesce(lv."isHalfDay", false)
  ),
  trips as (
    select distinct on (m.id_user, dd.d)
           m.id_user as uid, dd.d,
           t.title as label,
           coalesce(t."isHalfDay", false) as half
    from "OfficialTrips" t
    join "OfficialTripMembers" m on m.id_trip = t.id_trip
    join days dd on dd.d between t."startDate" and t."endDate"
    where t.id_school = p_school
      and coalesce(t.status, '') <> 'ไม่อนุมัติ'
    order by m.id_user, dd.d, coalesce(t."isHalfDay", false)
  ),
  joined as (
    select p.uid, p.name, dd.d,
           ((extract(isodow from dd.d) < 6 and hd.d is null) or wd.d is not null) as working,
           s.first_at, s.last_at, coalesce(s.n, 0) as n,
           (s.first_at at time zone 'Asia/Bangkok')::time as first_local,
           (s.last_at  at time zone 'Asia/Bangkok')::time as last_local,
           lv.label as leave_label, lv.half as leave_half,
           tr.label as trip_label, tr.half as trip_half
    from people p
    cross join days dd
    left join holidays hd on hd.d = dd.d
    left join workdays wd on wd.d = dd.d
    left join scans  s  on s.uid  = p.uid and s.d  = dd.d
    left join leaves lv on lv.uid = p.uid and lv.d = dd.d
    left join trips  tr on tr.uid = p.uid and tr.d = dd.d
  ),
  decided as (
    select j.*,
      case
        when j.d > today                                   then 'ยังไม่ถึง'
        when not j.working                                 then 'วันหยุด'
        when j.trip_label is not null and not j.trip_half  then 'ไปราชการ'
        when j.leave_label is not null and not j.leave_half then 'ลา'
        when first_day is null or j.d < first_day          then 'ยังไม่เริ่มใช้'
        when j.n > 0 and j.first_local > cfg.late_after
             and j.leave_label is null and j.trip_label is null then 'สาย'
        when j.n > 0                                       then 'มา'
        when j.trip_label is not null                      then 'ไปราชการ'
        when j.leave_label is not null                     then 'ลา'
        when j.d = today                                   then 'ยังไม่สแกน'
        else 'ขาด'
      end as st
    from joined j
  )
  select x.uid,
         x.name,
         x.d,
         x.st,
         x.first_at,
         x.last_at,
         x.n,
         case when x.st = 'สาย'
              then ceil(extract(epoch from (x.first_local - cfg.late_after)) / 60)::int
              else 0 end,
         nullif(concat_ws(' · ',
           case when x.st in ('ลา', 'มา', 'สาย') and x.leave_label is not null
                then x.leave_label || case when x.leave_half then ' (ครึ่งวัน)' else '' end end,
           case when x.st in ('ไปราชการ', 'มา', 'สาย') and x.trip_label is not null
                then 'ไปราชการ: ' || x.trip_label
                     || case when x.trip_half then ' (ครึ่งวัน)' else '' end end,
           case when cfg.require_checkout and x.st in ('มา', 'สาย')
                     and (x.d < today or now_local >= cfg.work_end)
                then case when x.n < 2 then 'ไม่สแกนออก'
                          when x.last_local < cfg.work_end then 'ออกก่อนเวลา'
                     end end
         ), '')
  from decided x
  order by x.d, x.name;
end;
$$;

revoke execute on function public.attendance_day_status(bigint, date, date, bigint) from public, anon;
grant  execute on function public.attendance_day_status(bigint, date, date, bigint) to authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 6) สรุปต่อคน (รายงานรายเดือน) — สิทธิ์เหมือนข้อ 5
-- ----------------------------------------------------------------------------

create or replace function public.attendance_summary(
  p_school bigint,
  p_from   date,
  p_to     date
)
returns table (
  id_user        bigint,
  full_name      text,
  work_days      integer,
  present        integer,
  late           integer,
  late_minutes   integer,
  on_leave       integer,
  on_trip        integer,
  absent         integer,
  missing_out    integer
)
language sql stable security definer set search_path = public
as $$
  select s.id_user,
         s.full_name,
         count(*) filter (where s.status not in ('วันหยุด', 'ยังไม่ถึง', 'ยังไม่เริ่มใช้'))::int,
         count(*) filter (where s.status = 'มา')::int,
         count(*) filter (where s.status = 'สาย')::int,
         coalesce(sum(s.late_minutes), 0)::int,
         count(*) filter (where s.status = 'ลา')::int,
         count(*) filter (where s.status = 'ไปราชการ')::int,
         count(*) filter (where s.status = 'ขาด')::int,
         count(*) filter (where s.note like '%ไม่สแกนออก%' or s.note like '%ออกก่อนเวลา%')::int
  from public.attendance_day_status(p_school, p_from, p_to) s
  group by s.id_user, s.full_name
  order by s.full_name;
$$;

revoke execute on function public.attendance_summary(bigint, date, date) from public, anon;
grant  execute on function public.attendance_summary(bigint, date, date) to authenticated, service_role;


notify pgrst, 'reload schema';


-- ----------------------------------------------------------------------------
-- 7) ตรวจผล — ต้องได้ true ทุกแถว
-- ----------------------------------------------------------------------------

select 'คอลัมน์ตั้งค่าใหม่' as รายการ,
       (select count(*) from information_schema.columns
        where table_schema = 'public' and table_name = 'AttendanceSettings'
          and column_name in ('start_date', 'line_summary_enabled', 'line_summary_time',
                              'line_list_missing', 'line_summary_sent_on')) = 5 as ผ่าน
union all
select 'Teachers.attendance_exempt',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'Teachers'
                 and column_name = 'attendance_exempt')
union all
select 'ยกเลิกการสแกนได้',
       (select count(*) from information_schema.columns
        where table_schema = 'public' and table_name = 'AttendanceLogs'
          and column_name in ('voided_at', 'voided_by', 'void_reason')) = 3
union all
select 'ฟังก์ชันครบ 4 ตัว',
       (select count(distinct proname) from pg_proc
        where pronamespace = 'public'::regnamespace
          and proname in ('attendance_day_status', 'attendance_summary',
                          'void_attendance_log', 'set_face_consent')) = 4;
