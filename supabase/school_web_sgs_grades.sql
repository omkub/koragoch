-- ============================================================================
--  ระบบข้อมูลนักเรียนฉบับสมบูรณ์ ผลการเรียนสะสมทุกชั้นปี และตารางคะแนนตามมาตรฐาน SGS (สพฐ.)
--
--  รันซ้ำได้ (Idempotent) · ไม่กระทบแอปวันลา
--  1) ตาราง SchoolWebStudentProfiles: เก็บข้อมูลส่วนตัวนักเรียนรายบุคคล (เลขบัตร 13 หลัก,
--     เลขที่ในห้อง, ชื่ออังกฤษ, วันเกิด, เพศ, หมู่เลือด, ศาสนา, แผนการเรียน, ที่อยู่, ข้อมูลบิดา-มารดา)
--  2) ตาราง SchoolWebSgsGrades: เก็บคะแนนรายช่อง เกรด (0-4 / ร / มส / ผ / มผ) เวลาเรียน
--     คะแนนอ่านคิดวิเคราะห์ และคุณลักษณะอันพึงประสงค์ ครบทุกชั้นปี (ม.1-ม.6) และทุกภาคเรียน
-- ============================================================================

create table if not exists public."SchoolWebStudentProfiles" (
  student_id          bigint primary key references public."SchoolWebStudents"(id) on delete cascade,
  id_school           bigint not null references public."Schools"(id_school) on delete cascade,
  seat_no             int,
  citizen_id          text,
  first_name_en       text,
  last_name_en        text,
  birth_date          text,
  gender              text,
  blood_group         text,
  religion            text,
  nationality         text default 'ไทย',
  ethnicity           text default 'ไทย',
  study_plan          text,
  admission_year_be   int,
  previous_school     text,
  address_registered  text,
  address_current     text,
  student_phone       text,
  father_name         text,
  father_occupation   text,
  father_phone        text,
  mother_name         text,
  mother_occupation   text,
  mother_phone        text,
  guardian_relation   text,
  guardian_occupation text,
  health_note         text,
  updated_at          timestamptz not null default now()
);

create index if not exists "SchoolWebStudentProfiles_school_idx"
  on public."SchoolWebStudentProfiles" (id_school);

alter table public."SchoolWebStudentProfiles" enable row level security;

drop policy if exists "school_web_student_profiles_read" on public."SchoolWebStudentProfiles";
-- แฟ้มมีเลขบัตรประชาชน / เบอร์ผู้ปกครอง / สุขภาพ → อ่านได้เฉพาะผู้มีสิทธิ์แก้ไขข้อมูลนักเรียน (ไม่ใช่ครูทุกคน)
create policy "school_web_student_profiles_read"
  on public."SchoolWebStudentProfiles" for select to authenticated
  using (public.can_edit_school_web(id_school, 'academic', 'students-classrooms'));

drop policy if exists "school_web_student_profiles_write" on public."SchoolWebStudentProfiles";
create policy "school_web_student_profiles_write"
  on public."SchoolWebStudentProfiles" for all to authenticated
  using (public.can_edit_school_web(id_school, 'academic', 'students-classrooms'))
  with check (public.can_edit_school_web(id_school, 'academic', 'students-classrooms'));


-- ----------------------------------------------------------------------------
-- ตารางเก็บคะแนนและผลการเรียนรายวิชาตามโครงสร้าง SGS (ครบทุกชั้นปี ม.1 - ม.6)
-- ----------------------------------------------------------------------------
create table if not exists public."SchoolWebSgsGrades" (
  id                         bigserial primary key,
  id_school                  bigint not null references public."Schools"(id_school) on delete cascade,
  student_id                 bigint not null references public."SchoolWebStudents"(id) on delete cascade,
  grade_level                text not null,           -- เช่น 'ม.1', 'ม.2', 'ม.3', 'ม.4', 'ม.5', 'ม.6'
  term_no                    int not null default 1,  -- 1 หรือ 2
  year_be                    int not null default 2568,
  subject_code               text not null,
  subject_name               text not null,
  learning_area              text not null default 'วิทยาศาสตร์และเทคโนโลยี',
  subject_type               text not null default 'พื้นฐาน', -- 'พื้นฐาน' | 'เพิ่มเติม' | 'กิจกรรม'
  credits                    numeric(4,2) not null default 1.0,
  -- สัดส่วนคะแนนเต็ม
  max_pre_mid_work           numeric(5,2) not null default 15,
  max_pre_mid_notebook       numeric(5,2) not null default 10,
  max_midterm                numeric(5,2) not null default 20,
  max_post_mid_work          numeric(5,2) not null default 15,
  max_post_mid_notebook      numeric(5,2) not null default 5,
  max_affective              numeric(5,2) not null default 5,
  max_final                  numeric(5,2) not null default 30,
  -- คะแนนที่นักเรียนทำได้ตามช่อง SGS
  pre_mid_work               numeric(5,2) not null default 0,
  pre_mid_notebook           numeric(5,2) not null default 0,
  midterm_score              numeric(5,2) not null default 0,
  post_mid_work              numeric(5,2) not null default 0,
  post_mid_notebook          numeric(5,2) not null default 0,
  affective_score            numeric(5,2) not null default 0,
  final_score                numeric(5,2) not null default 0,
  -- เวลาเรียนและผลการประเมินตาม ปพ.5 / SGS
  attended_hours             numeric(5,1) not null default 40,
  total_hours                numeric(5,1) not null default 40,
  reading_thinking_writing   int not null default 3,  -- 0-3
  desirable_characteristics  int not null default 3,  -- 0-3
  special_status             text not null default '', -- '', 'ร', 'มส', 'ผ', 'มผ'
  teacher_name               text,
  updated_at                 timestamptz not null default now(),
  unique (id_school, student_id, year_be, grade_level, term_no, subject_code)
);

-- ถ้าเคยรันไฟล์รุ่นแรกแล้ว: เปลี่ยน unique ให้รวมปีการศึกษา (นักเรียนซ้ำชั้นเรียนวิชาเดิมคนละปีได้)
do $$
declare c text;
begin
  for c in
    select con.conname from pg_constraint con
    where con.conrelid = 'public."SchoolWebSgsGrades"'::regclass and con.contype = 'u'
      and replace(pg_get_constraintdef(con.oid), ' ', '')
          <> 'UNIQUE(id_school,student_id,year_be,grade_level,term_no,subject_code)'
  loop
    execute format('alter table public."SchoolWebSgsGrades" drop constraint %I', c);
  end loop;
  if not exists (
    select 1 from pg_constraint con
    where con.conrelid = 'public."SchoolWebSgsGrades"'::regclass and con.contype = 'u'
  ) then
    alter table public."SchoolWebSgsGrades"
      add constraint "SchoolWebSgsGrades_unique_term"
      unique (id_school, student_id, year_be, grade_level, term_no, subject_code);
  end if;
end $$;

create index if not exists "SchoolWebSgsGrades_school_student_idx"
  on public."SchoolWebSgsGrades" (id_school, student_id);

alter table public."SchoolWebSgsGrades" enable row level security;

drop policy if exists "school_web_sgs_grades_read" on public."SchoolWebSgsGrades";
create policy "school_web_sgs_grades_read"
  on public."SchoolWebSgsGrades" for select to authenticated
  using (public.can_see_school(id_school));

drop policy if exists "school_web_sgs_grades_write" on public."SchoolWebSgsGrades";
create policy "school_web_sgs_grades_write"
  on public."SchoolWebSgsGrades" for all to authenticated
  using (
    public.can_edit_school_web(id_school, 'academic', 'students-classrooms')
    or public.can_edit_school_web(id_school, 'academic', 'curriculum-schedule')
  )
  with check (
    public.can_edit_school_web(id_school, 'academic', 'students-classrooms')
    or public.can_edit_school_web(id_school, 'academic', 'curriculum-schedule')
  );

insert into public."SchemaMigrations"(name) values ('school_web_sgs_grades.sql') on conflict do nothing;

notify pgrst, 'reload schema';
