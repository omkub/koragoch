-- ============================================================================
--  เชื่อมข้อมูลจริงระหว่าง เว็บกลาง / เว็บโรงเรียนภายใน / เว็บสาธารณะ และระบบ SGS Online
--
--  รันซ้ำได้ (Idempotent) · ไม่กระทบแอปวันลา
--  1) list_public_schools(): ให้หน้าเว็บสาธารณะ (#/public) ดึงชื่อโรงเรียน สังกัด โลโก้
--     รหัสสถานศึกษา และที่อยู่จริงจากตาราง Schools ได้โดยไม่ต้องล็อกอิน
--  2) get_public_school_realtime_data(target_school): ดึงข้อมูลจริงของโรงเรียนเพื่อแสดงบนเว็บสาธารณะ:
--     - ข้อมูลโรงเรียนและโลโก้จาก Schools + ปีการศึกษาปัจจุบันจาก AcademicYears
--     - จำนวนบุคลากรที่ปฏิบัติงานจริง และรายชื่อผู้บริหาร/ครูจาก Teachers + adminroles + roles
--     - สถิติจำนวนนักเรียนจริงแยกตามระดับชั้น (ม.1-ม.6 ชาย/หญิง/ห้อง) และแผนการเรียน
--       จาก SchoolWebStudents + SchoolWebClassrooms + SchoolWebStudentProfiles (ไม่มีข้อมูลส่วนบุคคล)
--     - ข่าวประกาศจริงจาก SchoolWebAnnouncements
--  3) lookup_public_student_sgs_grades(target_school, p_student_code, p_verify_code):
--     ระบบ SGS Online สำหรับนักเรียนและผู้ปกครองตรวจสอบผลการเรียนจริงทุกชั้นปีด้วยรหัสนักเรียน
--     คู่กับเลขบัตรประชาชนครบ 13 หลักเท่านั้น (ไม่มีเลขบัตรในแฟ้ม = ตรวจไม่ได้)
--     ผิดเกิน 5 ครั้งใน 15 นาที ต่อรหัสนักเรียน → ล็อก (กันไล่เดารหัส)
-- ============================================================================

-- 1) รายชื่อโรงเรียนสำหรับหน้าเว็บสาธารณะ
create or replace function public.list_public_schools()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  res jsonb;
begin
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id_school', s.id_school,
        'namePart1', s."namePart1",
        'namePart2', s."namePart2",
        'fullName', coalesce(
          nullif(trim(concat_ws(' ', nullif(trim(s."namePart1"), ''), nullif(trim(s."namePart2"), ''))), ''),
          s."fullName"
        ),
        'affiliation', s.affiliation,
        'localCode', s."localCode",
        'address', s.address,
        'subdistrict', s.subdistrict,
        'district', s.district,
        'province', s.province,
        'logo', to_jsonb(s)->>'logo'
      )
      order by s.id_school
    ),
    '[]'::jsonb
  )
  into res
  from public."Schools" s;

  return res;
end;
$$;

grant execute on function public.list_public_schools() to anon, authenticated;


-- 2) ข้อมูลจริงของโรงเรียนสำหรับหน้าเว็บสาธารณะ (บุคลากร, สถิตินักเรียน, ข่าวประกาศ, ข้อมูลโรงเรียน)
create or replace function public.get_public_school_realtime_data(target_school bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  s_id bigint := target_school;
  school_obj jsonb := null;
  current_year_be int := null;
  current_year_label text := null;
  staff_list jsonb := '[]'::jsonb;
  staff_count int := 0;
  student_count int := 0;
  classroom_count int := 0;
  grade_stats jsonb := '[]'::jsonb;
  plan_stats jsonb := '[]'::jsonb;
  announcements_list jsonb := '[]'::jsonb;
begin
  if s_id is null then
    return jsonb_build_object('ok', false);
  end if;

  -- 2.1 ข้อมูลโรงเรียนจากตาราง Schools
  select jsonb_build_object(
    'id_school', s.id_school,
    'namePart1', s."namePart1",
    'namePart2', s."namePart2",
    'fullName', coalesce(
      nullif(trim(concat_ws(' ', nullif(trim(s."namePart1"), ''), nullif(trim(s."namePart2"), ''))), ''),
      s."fullName"
    ),
    'affiliation', s.affiliation,
    'localCode', s."localCode",
    'address', s.address,
    'subdistrict', s.subdistrict,
    'district', s.district,
    'province', s.province,
    'logo', to_jsonb(s)->>'logo'
  )
  into school_obj
  from public."Schools" s
  where s.id_school = s_id;

  -- 2.2 ปีการศึกษาปัจจุบัน
  if to_regclass('public."AcademicYears"') is not null then
    select y.year_be, y.label
    into current_year_be, current_year_label
    from public."AcademicYears" y
    where y.id_school = s_id
    order by y.is_current desc, y.year_be desc
    limit 1;
  end if;

  -- 2.3 รายชื่อบุคลากรและผู้บริหารที่ปฏิบัติงานจริง
  if to_regclass('public."Teachers"') is not null then
    select
      count(*)::int,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id_user', t.id_user,
            'fullName', t."fullName",
            'roleName', coalesce(r."Accessrights", 'ข้าราชการครูและบุคลากร'),
            'adminRoleName', ar."AdminRolesName",
            'profileImage', to_jsonb(t)->>'profileImage'
          )
          order by
            case
              when ar."AdminRolesName" ilike '%ผู้อำนวยการ%' and ar."AdminRolesName" not ilike '%รอง%' then 1
              when ar."AdminRolesName" ilike '%รองผู้อำนวยการ%' then 2
              when r."Accessrights" ilike '%ผู้อำนวยการ%' and r."Accessrights" not ilike '%รอง%' then 1
              when r."Accessrights" ilike '%รองผู้อำนวยการ%' then 2
              else 3
            end,
            t."fullName"
        ),
        '[]'::jsonb
      )
    into staff_count, staff_list
    from public."Teachers" t
    left join public."roles" r on r."ID_Roles" = t.id_role
    left join public."adminroles" ar on ar."ID_AdminRoles" = t.id_adminrole
    where t.id_school = s_id
      and coalesce(t.is_super_admin, false) = false
      and coalesce(to_jsonb(t)->>'employment_status', 'active') = 'active';
  end if;

  -- 2.4 สถิติจำนวนนักเรียนและห้องเรียนจริง
  if to_regclass('public."SchoolWebClassrooms"') is not null then
    select count(*)::int
    into classroom_count
    from public."SchoolWebClassrooms" c
    where c.id_school = s_id and coalesce(c.is_active, true) = true;
  end if;

  if to_regclass('public."SchoolWebStudents"') is not null then
    select count(*)::int
    into student_count
    from public."SchoolWebStudents" st
    where st.id_school = s_id and st.status = 'enrolled';

    -- สรุปจำนวนนักเรียนแยกตามระดับชั้น (ม.1 - ม.6)
    with lvl_list as (
      select unnest(array['ม.1', 'ม.2', 'ม.3', 'ม.4', 'ม.5', 'ม.6']) as badge,
             generate_series(1, 6) as lvl_no
    ),
    room_counts as (
      select c.grade_level, count(*)::int as rooms_count
      from public."SchoolWebClassrooms" c
      where c.id_school = s_id and coalesce(c.is_active, true) = true
      group by c.grade_level
    ),
    stu_joined as (
      select
        coalesce(c.grade_level, 'ม.1') as grade_level,
        case
          when coalesce(p.gender, '') in ('ชาย', 'หญิง') then p.gender
          when coalesce(st.prefix, '') ilike '%หญิง%' or coalesce(st.prefix, '') ilike '%นางสาว%' then 'หญิง'
          else 'ชาย'
        end as gender,
        coalesce(nullif(trim(p.study_plan), ''), 'ทั่วไป') as study_plan
      from public."SchoolWebStudents" st
      left join public."SchoolWebClassrooms" c on c.id = st.classroom_id
      left join public."SchoolWebStudentProfiles" p on p.student_id = st.id
      where st.id_school = s_id and st.status = 'enrolled'
    ),
    stu_by_grade as (
      select
        grade_level,
        count(*) filter (where gender = 'ชาย')::int as male_count,
        count(*) filter (where gender = 'หญิง')::int as female_count
      from stu_joined
      group by grade_level
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'badge', l.badge,
          'title', 'ชั้นมัธยมศึกษาปีที่ ' || l.lvl_no,
          'roomsCount', coalesce(rc.rooms_count, 0),
          'male', coalesce(sg.male_count, 0),
          'female', coalesce(sg.female_count, 0),
          'isSenior', (l.lvl_no >= 4)
        )
        order by l.lvl_no
      ),
      '[]'::jsonb
    )
    into grade_stats
    from lvl_list l
    left join room_counts rc on rc.grade_level = l.badge
    left join stu_by_grade sg on sg.grade_level = l.badge;

    -- สรุปจำนวนนักเรียนแยกตามแผนการเรียน
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', 'plan-' || row_no,
          'label', study_plan,
          'countLabel', cnt::text || ' คน'
        )
        order by cnt desc
      ),
      '[]'::jsonb
    )
    into plan_stats
    from (
      select
        coalesce(nullif(trim(p.study_plan), ''), 'ทั่วไป (มัธยมศึกษา)') as study_plan,
        count(*)::int as cnt,
        row_number() over (order by count(*) desc) as row_no
      from public."SchoolWebStudents" st
      left join public."SchoolWebStudentProfiles" p on p.student_id = st.id
      where st.id_school = s_id and st.status = 'enrolled'
      group by coalesce(nullif(trim(p.study_plan), ''), 'ทั่วไป (มัธยมศึกษา)')
    ) t;
  end if;

  -- 2.5 ข่าวประกาศจริงจาก SchoolWebAnnouncements
  if to_regclass('public."SchoolWebAnnouncements"') is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'title', a.title,
          'content', a.content,
          'category', a.category,
          'is_pinned', a.is_pinned,
          'published_at', a.published_at
        )
        order by a.is_pinned desc, a.published_at desc
      ),
      '[]'::jsonb
    )
    into announcements_list
    from (
      select id, title, content, category, is_pinned, published_at
      from public."SchoolWebAnnouncements"
      where id_school = s_id
      order by is_pinned desc, published_at desc
      limit 12
    ) a;
  end if;

  return jsonb_build_object(
    'ok', true,
    'school', school_obj,
    'academicYearBe', current_year_be,
    'academicYearLabel', current_year_label,
    'staffCount', staff_count,
    'staffList', staff_list,
    'studentCount', student_count,
    'classroomCount', classroom_count,
    'gradeStats', grade_stats,
    'planStats', plan_stats,
    'announcements', announcements_list
  );
end;
$$;

grant execute on function public.get_public_school_realtime_data(bigint) to anon, authenticated;


-- 3) ฟังก์ชันตรวจสอบผลการเรียนออนไลน์ (SGS Online Portal) บนหน้าเว็บสาธารณะ
--    ต้องระบุโรงเรียน + รหัสนักเรียน + เลขบัตรประชาชนครบ 13 หลักที่ตรงกับแฟ้มประวัติ
--    บันทึกการลองผิด และล็อกเมื่อผิดเกิน 5 ครั้งใน 15 นาที
create table if not exists public."SchoolPublicSgsLookupAttempts" (
  id            bigint generated always as identity primary key,
  id_school     bigint not null,
  student_code  text not null,
  attempted_at  timestamptz not null default now()
);
create index if not exists school_public_sgs_attempts_idx
  on public."SchoolPublicSgsLookupAttempts"(id_school, student_code, attempted_at desc);
alter table public."SchoolPublicSgsLookupAttempts" enable row level security;
-- ไม่มี policy = เข้าถึงได้เฉพาะผ่านฟังก์ชัน security definer

drop function if exists public.lookup_public_student_sgs_grades(bigint, text, text);
create function public.lookup_public_student_sgs_grades(
  target_school bigint,
  p_student_code text,
  p_verify_code text default ''
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  clean_code text := lower(trim(coalesce(p_student_code, '')));
  clean_verify text := regexp_replace(coalesce(p_verify_code, ''), '[^0-9]', '', 'g');
  generic_fail constant text := 'รหัสนักเรียนหรือเลขบัตรประชาชนไม่ถูกต้อง หรือโรงเรียนยังไม่ได้บันทึกเลขบัตรประชาชนของนักเรียน';
  recent_fails int;
  stu_row record;
  stored_citizen text;
  grades_list jsonb := '[]'::jsonb;
begin
  if target_school is null or clean_code = '' or length(clean_verify) <> 13 then
    return jsonb_build_object('ok', false, 'error', 'กรุณากรอกรหัสนักเรียน และเลขบัตรประชาชน 13 หลัก');
  end if;

  select count(*) into recent_fails
  from public."SchoolPublicSgsLookupAttempts" a
  where a.id_school = target_school
    and a.student_code = clean_code
    and a.attempted_at > now() - interval '15 minutes';
  if recent_fails >= 5 then
    return jsonb_build_object('ok', false, 'error', 'ลองผิดหลายครั้งเกินไป กรุณารอ 15 นาทีแล้วลองใหม่');
  end if;

  select st.id, st.id_school, st.student_code, st.prefix, st.first_name, st.last_name,
         c.name as classroom_name, c.grade_level, p.seat_no, p.citizen_id, p.study_plan
  into stu_row
  from public."SchoolWebStudents" st
  left join public."SchoolWebClassrooms" c on c.id = st.classroom_id
  left join public."SchoolWebStudentProfiles" p on p.student_id = st.id
  where st.id_school = target_school
    and lower(trim(st.student_code)) = clean_code
  limit 1;

  stored_citizen := regexp_replace(coalesce(stu_row.citizen_id, ''), '[^0-9]', '', 'g');

  -- ไม่บอกว่าผิดที่รหัสนักเรียนหรือเลขบัตร (กันใช้ตรวจว่ารหัสไหนมีอยู่จริง)
  if stu_row.id is null or length(stored_citizen) <> 13 or stored_citizen <> clean_verify then
    insert into public."SchoolPublicSgsLookupAttempts"(id_school, student_code)
    values (target_school, clean_code);
    delete from public."SchoolPublicSgsLookupAttempts" where attempted_at < now() - interval '1 day';
    return jsonb_build_object('ok', false, 'error', generic_fail);
  end if;

  if to_regclass('public."SchoolWebSgsGrades"') is not null then
    select coalesce(jsonb_agg(to_jsonb(g) order by g.year_be, g.term_no, g.subject_code), '[]'::jsonb)
    into grades_list
    from public."SchoolWebSgsGrades" g
    where g.student_id = stu_row.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'student', jsonb_build_object(
      'id', stu_row.id,
      'id_school', stu_row.id_school,
      'student_code', stu_row.student_code,
      'prefix', stu_row.prefix,
      'first_name', stu_row.first_name,
      'last_name', stu_row.last_name,
      'classroom_name', coalesce(stu_row.classroom_name, 'ยังไม่ระบุห้อง'),
      'grade_level', coalesce(stu_row.grade_level, '-'),
      'seat_no', stu_row.seat_no,
      'study_plan', coalesce(stu_row.study_plan, '')
    ),
    'grades', grades_list
  );
end;
$$;

revoke all on function public.lookup_public_student_sgs_grades(bigint, text, text) from public;
grant execute on function public.lookup_public_student_sgs_grades(bigint, text, text) to anon, authenticated;

insert into public."SchemaMigrations"(name) values ('school_web_realtime_public.sql') on conflict do nothing;

notify pgrst, 'reload schema';
