-- ============================================================================
--  ครูกรอกคะแนนได้เฉพาะวิชา / ห้องที่ตัวเองสอน (งานของฉัน → กรอกคะแนน)
--
--  รันซ้ำได้ · ไม่กระทบแอปวันลา · ต้องรันหลัง school_web_academic.sql และ school_web_sgs_grades.sql
--  - เพิ่ม policy เขียน SchoolWebSgsGrades ให้ครูผู้สอน (ต่อจาก policy เดิมของฝ่ายวิชาการ — ทำงานแบบ OR)
--  - ครูผู้สอน = มีคาบใน SchoolWebTeachingSchedules ที่ teacher_id = ตัวเอง
--    ห้องตรงกับห้องปัจจุบันของนักเรียน และรหัสวิชาตรงกับ subject_code
-- ============================================================================

create or replace function public.is_teacher_of_student_subject(
  target_school bigint, p_student_id bigint, p_subject_code text
) returns boolean
language sql stable security definer set search_path = public
as $$
  select target_school = public.current_school_id()
     and exists (
       select 1
       from public."Teachers" t
       join public."SchoolWebTeachingSchedules" ts
         on ts.teacher_id = t.id_user and ts.id_school = target_school
       join public."SchoolWebSubjects" sj
         on sj.id = ts.subject_id and sj.id_school = target_school
       join public."SchoolWebStudents" st
         on st.classroom_id = ts.classroom_id and st.id_school = target_school
       where t.auth_uid = auth.uid()
         and st.id = p_student_id
         and sj.code = p_subject_code
     );
$$;

revoke all on function public.is_teacher_of_student_subject(bigint, bigint, text) from public, anon;
grant execute on function public.is_teacher_of_student_subject(bigint, bigint, text) to authenticated;

drop policy if exists "school_web_sgs_grades_teacher_write" on public."SchoolWebSgsGrades";
create policy "school_web_sgs_grades_teacher_write"
  on public."SchoolWebSgsGrades" for all to authenticated
  using (public.is_teacher_of_student_subject(id_school, student_id, subject_code))
  with check (public.is_teacher_of_student_subject(id_school, student_id, subject_code));

insert into public."SchemaMigrations"(name) values ('school_web_teacher_grades.sql') on conflict do nothing;

notify pgrst, 'reload schema';
