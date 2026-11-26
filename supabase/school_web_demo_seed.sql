-- ============================================================================
--  โรงเรียนทดลองใช้ (Demo) — พาร์ท 2: ข้อมูลตั้งต้น + ปุ่มรีเซ็ต
--
--  รันซ้ำได้ · ไม่กระทบแอปวันลา · ต้องรันหลัง school_web_demo_setup.sql
--  ทำงานได้ "เฉพาะโรงเรียนใน SchoolWebDemoConfig" เท่านั้น (เรียกกับโรงเรียนจริง = error)
--
--  seed_demo_school_data(id)   เติมข้อมูลตั้งต้น (ไม่ลบของเดิม — รันซ้ำแล้วไม่ซ้ำ)
--    • ปีการศึกษา + ภาคเรียนปัจจุบัน
--    • กลุ่มสาระ 8 กลุ่ม + กิจกรรมพัฒนาผู้เรียน
--    • ห้องเรียน ม.1/1 – ม.6/5 (30 ห้อง)
--    • นักเรียน 1,200 คน (ห้องละ 40, ชาย:หญิง = 2:3) + ผู้ปกครอง + แฟ้มประวัติ
--    • รายวิชา 87 วิชา + ตารางสอนครบ 30 ห้อง (ยังไม่ระบุครูผู้สอน — ผูกตอนสมัคร พาร์ท 3)
--    • คะแนน SGS ภาคเรียน 1 ของปีการศึกษาปัจจุบัน ตามรายวิชาจริงของแต่ละชั้น
--    • ประกาศตัวอย่าง 3 รายการ
--  reset_demo_school_data(id)  ล้างข้อมูลงานของโรงเรียนทดลองแล้วเติมใหม่ (เฉพาะผู้ดูแลส่วนกลาง)
--
--  ข้อมูลทั้งหมดเป็นข้อมูลสมมุติ:
--    • เลขบัตรประชาชน 13 หลัก "หลักตรวจสอบผิดโดยตั้งใจ" → ไม่มีทางตรงกับเลขของคนจริง
--    • เบอร์โทร 000-xxx-xxxx · ที่อยู่ "ตำบลทดลอง อำเภอทดลอง"
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) เลขบัตรประชาชนสมมุติ: 12 หลักแรก + หลักตรวจสอบที่ "ผิด" เสมอ
-- ----------------------------------------------------------------------------
create or replace function public.demo_fake_citizen_id(base12 text)
returns text
language sql immutable
as $$
  with d as (
    select sum(substr(base12, i, 1)::int * (14 - i)) as s
    from generate_series(1, 12) as g(i)
  )
  select base12 || (((11 - (s % 11)) % 10 + 1) % 10)::text from d;
$$;

-- ----------------------------------------------------------------------------
-- 1) เติมข้อมูลตั้งต้น
-- ----------------------------------------------------------------------------
create or replace function public.seed_demo_school_data(target bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_year    int := extract(year from now())::int + 543
                   - case when extract(month from now()) < 5 then 1 else 0 end;
  v_year_id bigint;
  v_term_id bigint;
  n_students int;
  n_subjects int;
  n_slots    int;
  n_grades   int;
begin
  if not public.is_demo_school(target) then
    raise exception 'โรงเรียน % ไม่ใช่โรงเรียนทดลอง (SchoolWebDemoConfig)', target using errcode = '42501';
  end if;
  if auth.uid() is not null and not public.is_super_admin() then
    raise exception 'เฉพาะผู้ดูแลส่วนกลาง' using errcode = '42501';
  end if;

  -- ปีการศึกษา / ภาคเรียนปัจจุบัน
  insert into "AcademicYears"(id_school, year_be, label, is_current)
  values (target, v_year, 'ปีการศึกษา ' || v_year, true)
  on conflict (id_school, year_be) do update set is_current = true, updated_at = now()
  returning id into v_year_id;
  update "AcademicYears" set is_current = false where id_school = target and id <> v_year_id;

  insert into "AcademicTerms"(id_school, academic_year_id, term_no, label, is_current)
  values (target, v_year_id, 1, 'ภาคเรียนที่ 1/' || v_year, true),
         (target, v_year_id, 2, 'ภาคเรียนที่ 2/' || v_year, false)
  on conflict (academic_year_id, term_no) do nothing;
  select id into v_term_id from "AcademicTerms"
  where academic_year_id = v_year_id and term_no = 1;
  update "AcademicTerms" set is_current = (id = v_term_id) where id_school = target;

  -- กลุ่มสาระ
  insert into "SchoolDepartments"(id_school, code, name, category, sort_order, is_active)
  select target, d.code, d.name, 'academic', d.sort_order, true
  from (values
    ('TH', 'กลุ่มสาระการเรียนรู้ภาษาไทย', 1),
    ('MA', 'กลุ่มสาระการเรียนรู้คณิตศาสตร์', 2),
    ('SC', 'กลุ่มสาระการเรียนรู้วิทยาศาสตร์และเทคโนโลยี', 3),
    ('SO', 'กลุ่มสาระการเรียนรู้สังคมศึกษา ศาสนา และวัฒนธรรม', 4),
    ('HP', 'กลุ่มสาระการเรียนรู้สุขศึกษาและพลศึกษา', 5),
    ('AR', 'กลุ่มสาระการเรียนรู้ศิลปะ', 6),
    ('OC', 'กลุ่มสาระการเรียนรู้การงานอาชีพ', 7),
    ('EN', 'กลุ่มสาระการเรียนรู้ภาษาต่างประเทศ', 8),
    ('AC', 'กิจกรรมพัฒนาผู้เรียน', 9)
  ) as d(code, name, sort_order)
  where not exists (
    select 1 from "SchoolDepartments" sd where sd.id_school = target and sd.code = d.code
  );

  -- ห้องเรียน
  insert into "SchoolWebClassrooms"(id_school, academic_year_id, grade_level, room_no, name, is_active)
  select target, v_year_id, 'ม.' || g.lvl, r.rm::text, 'ม.' || g.lvl || '/' || r.rm, true
  from generate_series(1, 6) g(lvl) cross join generate_series(1, 5) r(rm)
  where not exists (
    select 1 from "SchoolWebClassrooms" c
    where c.id_school = target and c.name = 'ม.' || g.lvl || '/' || r.rm
  );

  -- นักเรียน 1,200 คน (รหัส D + ชั้น + ห้อง + เลขที่ เช่น D1101) · ห้องชื่อซ้ำใช้ห้องแรก
  with pools as (
    select
      array['กิตติพงศ์','ธนกฤต','ณัฐวุฒิ','ภูมิภัทร','วรภัทร','ศุภณัฐ','ธีรภัทร','พงศกร','ชยพล','อภิวัฒน์',
            'จิรภัทร','พีรพัฒน์','กฤตภาส','ปุณณวิช','ธนดล','สิรวิชญ์','ภานุวัฒน์','เตชินท์','พชร','กันตพงศ์'] as m,
      array['กมลชนก','ณัฐณิชา','พิมพ์ชนก','สุพิชชา','กัญญาณัฐ','ชนิกานต์','นันท์นภัส','ปภาวรินท์','รัตติกาล','อภิชญา',
            'ธัญชนก','แพรวา','วรัญญา','สุภัสสรา','กานต์ธิดา','ชลธิชา','ปาลิตา','ลลิตา','ศุภิสรา','จิดาภา'] as f,
      array['ทดลองดี','สมมุติชัย','ตัวอย่างงาม','ทดสอบศรี','จำลองวงศ์','สาธิตกุล','ทดลองพงศ์','ตัวอย่างสุข',
            'สมมุติวัฒน์','ทดสอบเจริญ','จำลองทอง','สาธิตมณี'] as l,
      array['สมชาย','ประเสริฐ','วิชัย','สุรชัย','วิไล','สุภาพร','ประนอม','รัตนา','มาลี','สมหมาย'] as p
  ),
  rooms as (
    select distinct on (c.name) c.id, replace(c.grade_level, 'ม.', '')::int as lvl, c.room_no::int as rm
    from "SchoolWebClassrooms" c
    where c.id_school = target and c.room_no ~ '^[1-5]$' and c.grade_level ~ '^ม\.[1-6]$'
    order by c.name, c.id
  ),
  gen as (
    select r.id as classroom_id, r.lvl, r.rm, s.seat,
           'D' || r.lvl || r.rm || lpad(s.seat::text, 2, '0') as code,
           ((s.seat - 1) % 5) < 2 as male,
           (r.lvl - 1) * 200 + (r.rm - 1) * 40 + s.seat as k
    from rooms r cross join generate_series(1, 40) s(seat)
  )
  insert into "SchoolWebStudents"(id_school, student_code, prefix, first_name, last_name,
                                  classroom_id, status)
  select target, g.code,
         case when g.lvl <= 3 then (case when g.male then 'เด็กชาย' else 'เด็กหญิง' end)
              else (case when g.male then 'นาย' else 'นางสาว' end) end,
         case when g.male then p.m[1 + (g.k * 7) % array_length(p.m, 1)]
              else p.f[1 + (g.k * 11) % array_length(p.f, 1)] end,
         p.l[1 + (g.k * 13) % array_length(p.l, 1)],
         g.classroom_id,
         'enrolled'
  from gen g cross join pools p
  where not exists (
    select 1 from "SchoolWebStudents" x where x.id_school = target and x.student_code = g.code
  );

  -- ผู้ปกครอง: เติมตารางแยกตรงๆ (ไม่ส่งผ่าน SchoolWebStudents เพราะ trigger จะสร้างแถวผู้ปกครอง
  -- ให้แม้แถวนักเรียนถูกข้าม → ชน foreign key)
  insert into "SchoolWebStudentGuardians"(student_id, id_school, guardian_name, guardian_phone)
  select st.id, target,
         (case when st.id % 2 = 0 then 'นาย' else 'นาง' end) || 'สมมุติ ' || st.last_name,
         '000-' || lpad((st.id % 1000)::text, 3, '0') || '-' || lpad(((st.id * 37) % 10000)::text, 4, '0')
  from "SchoolWebStudents" st
  where st.id_school = target and st.student_code ~ '^D[1-6][1-5][0-9]{2}$'
  on conflict (student_id) do nothing;

  -- แฟ้มประวัติ
  insert into "SchoolWebStudentProfiles"(student_id, id_school, seat_no, citizen_id, birth_date, gender,
    blood_group, religion, nationality, ethnicity, study_plan, admission_year_be, previous_school,
    address_registered, address_current, father_name, father_occupation, mother_name, mother_occupation,
    guardian_relation, guardian_occupation, updated_at)
  select st.id, target,
         right(st.student_code, 2)::int,
         public.demo_fake_citizen_id('99' || lpad(st.id::text, 10, '0')),
         (2014 - substr(st.student_code, 2, 1)::int)::text || '-'
           || lpad((1 + st.id % 12)::text, 2, '0') || '-' || lpad((1 + st.id % 28)::text, 2, '0'),
         case when st.prefix in ('เด็กชาย', 'นาย') then 'ชาย' else 'หญิง' end,
         (array['O','A','B','AB'])[1 + st.id % 4], 'พุทธ', 'ไทย', 'ไทย',
         case when substr(st.student_code, 2, 1)::int <= 3 then 'ทั่วไป (มัธยมศึกษาตอนต้น)'
              when substr(st.student_code, 3, 1) in ('1', '2') then 'วิทยาศาสตร์ - คณิตศาสตร์'
              when substr(st.student_code, 3, 1) = '3' then 'ศิลป์ - คำนวณ'
              else 'ศิลป์ - ภาษา' end,
         v_year - substr(st.student_code, 2, 1)::int + 1,
         'โรงเรียนทดลองประถม',
         'หมู่ที่ ' || (1 + st.id % 12) || ' ตำบลทดลอง อำเภอทดลอง จังหวัดทดลอง 00000',
         'หมู่ที่ ' || (1 + st.id % 12) || ' ตำบลทดลอง อำเภอทดลอง จังหวัดทดลอง 00000',
         'นายสมมุติ ' || st.last_name, 'เกษตรกร',
         'นางสมมุติ ' || st.last_name, 'ค้าขาย',
         'บิดา-มารดา', 'เกษตรกร', now()
  from "SchoolWebStudents" st
  where st.id_school = target and st.student_code ~ '^D[1-6][1-5][0-9]{2}$'
  on conflict (student_id) do nothing;

  -- รายวิชา 87 วิชา
  insert into "SchoolWebSubjects"(id_school, code, name, department_id, credits, is_active)
  select target, s.code, s.name,
         (select id from "SchoolDepartments" d where d.id_school = target and d.code = s.dept order by id limit 1),
         s.credits, true
  from (values
    ('ท21101','ภาษาไทยพื้นฐาน 1','TH',1.5),('ค21101','คณิตศาสตร์พื้นฐาน 1','MA',1.5),('ค21201','คณิตศาสตร์เพิ่มเติม 1','MA',1.0),
    ('ว21101','วิทยาศาสตร์พื้นฐาน 1','SC',1.5),('ว21103','วิทยาการคำนวณ 1','SC',0.5),('ส21101','สังคมศึกษา ศาสนา และวัฒนธรรม 1','SO',1.5),
    ('ส21102','ประวัติศาสตร์ 1','SO',0.5),('พ21101','สุขศึกษาและพลศึกษา 1','HP',1.0),('ศ21101','ศิลปะ 1','AR',1.0),
    ('ง21101','การงานอาชีพ 1','OC',0.5),('อ21101','ภาษาอังกฤษพื้นฐาน 1','EN',1.5),('อ21201','ภาษาอังกฤษเพื่อการสื่อสาร 1','EN',1.0),
    ('ก21901','แนะแนว / ลูกเสือ-เนตรนารี / ชุมนุม ม.1','AC',0.5),
    ('ท22101','ภาษาไทยพื้นฐาน 3','TH',1.5),('ค22101','คณิตศาสตร์พื้นฐาน 3','MA',1.5),('ค22201','คณิตศาสตร์เพิ่มเติม 3','MA',1.0),
    ('ว22101','วิทยาศาสตร์พื้นฐาน 3','SC',1.5),('ว22103','วิทยาการคำนวณ 2','SC',0.5),('ส22101','สังคมศึกษา ศาสนา และวัฒนธรรม 3','SO',1.5),
    ('ส22102','ประวัติศาสตร์ 3','SO',0.5),('พ22101','สุขศึกษาและพลศึกษา 3','HP',1.0),('ศ22101','ศิลปะ 3','AR',1.0),
    ('ง22101','การงานอาชีพ 3','OC',0.5),('อ22101','ภาษาอังกฤษพื้นฐาน 3','EN',1.5),('อ22201','ภาษาอังกฤษเพื่อการสื่อสาร 3','EN',1.0),
    ('ก22901','แนะแนว / ลูกเสือ-เนตรนารี / ชุมนุม ม.2','AC',0.5),
    ('ท23101','ภาษาไทยพื้นฐาน 5','TH',1.5),('ค23101','คณิตศาสตร์พื้นฐาน 5','MA',1.5),('ค23201','คณิตศาสตร์เพิ่มเติม 5','MA',1.0),
    ('ว23101','วิทยาศาสตร์พื้นฐาน 5','SC',1.5),('ว23103','วิทยาการคำนวณ 3','SC',0.5),('ส23101','สังคมศึกษา ศาสนา และวัฒนธรรม 5','SO',1.5),
    ('ส23102','ประวัติศาสตร์ 5','SO',0.5),('พ23101','สุขศึกษาและพลศึกษา 5','HP',1.0),('ศ23101','ศิลปะ 5','AR',1.0),
    ('ง23101','การงานอาชีพ 5','OC',0.5),('อ23101','ภาษาอังกฤษพื้นฐาน 5','EN',1.5),('อ23201','ภาษาอังกฤษเพื่อการสื่อสาร 5','EN',1.0),
    ('ก23901','แนะแนว / ลูกเสือ-เนตรนารี / ชุมนุม ม.3','AC',0.5),
    ('ท31101','ภาษาไทยพื้นฐาน ม.4','TH',1.0),('ค31101','คณิตศาสตร์พื้นฐาน ม.4','MA',1.0),('ค31201','คณิตศาสตร์เพิ่มเติม 1','MA',1.5),
    ('ว31101','วิทยาศาสตร์ชีวภาพ ม.4','SC',1.5),('ว31201','ฟิสิกส์ 1','SC',1.5),('ว31221','เคมี 1','SC',1.5),
    ('ว31241','ชีววิทยา 1','SC',1.5),('ว31181','วิทยาการคำนวณและเทคโนโลยี ม.4','SC',1.0),('ส31101','สังคมศึกษา ม.4','SO',1.0),
    ('ส31102','ประวัติศาสตร์ไทย ม.4','SO',0.5),('พ31101','สุขศึกษาและพลศึกษา ม.4','HP',0.5),('ศ31101','ศิลปะ ม.4','AR',0.5),
    ('ง31101','การงานอาชีพ ม.4','OC',0.5),('อ31101','ภาษาอังกฤษพื้นฐาน ม.4','EN',1.0),('อ31201','ภาษาอังกฤษอ่าน-เขียน 1','EN',1.0),
    ('ก31901','แนะแนว / ชุมนุม / รด. ม.4','AC',0.5),
    ('ท32101','ภาษาไทยพื้นฐาน ม.5','TH',1.0),('ค32101','คณิตศาสตร์พื้นฐาน ม.5','MA',1.0),('ค32201','คณิตศาสตร์เพิ่มเติม 3','MA',1.5),
    ('ว32101','วิทยาศาสตร์กายภาพ ม.5','SC',1.5),('ว32201','ฟิสิกส์ 3','SC',1.5),('ว32221','เคมี 3','SC',1.5),
    ('ว32241','ชีววิทยา 3','SC',1.5),('ว32181','วิทยาการคำนวณและเทคโนโลยี ม.5','SC',1.0),('ส32101','สังคมศึกษา ม.5','SO',1.0),
    ('ส32102','ประวัติศาสตร์สากล ม.5','SO',0.5),('พ32101','สุขศึกษาและพลศึกษา ม.5','HP',0.5),('ศ32101','ศิลปะ ม.5','AR',0.5),
    ('ง32101','การงานอาชีพ ม.5','OC',0.5),('อ32101','ภาษาอังกฤษพื้นฐาน ม.5','EN',1.0),('อ32201','ภาษาอังกฤษอ่าน-เขียน 3','EN',1.0),
    ('ก32901','แนะแนว / ชุมนุม / รด. ม.5','AC',0.5),
    ('ท33101','ภาษาไทยพื้นฐาน ม.6','TH',1.0),('ค33101','คณิตศาสตร์พื้นฐาน ม.6','MA',1.0),('ค33201','คณิตศาสตร์เพิ่มเติม 5','MA',1.5),
    ('ว33101','วิทยาศาสตร์โลกและอวกาศ ม.6','SC',1.5),('ว33201','ฟิสิกส์ 5','SC',1.5),('ว33221','เคมี 5','SC',1.5),
    ('ว33241','ชีววิทยา 5','SC',1.5),('ว33181','วิทยาการคำนวณและโครงงาน ม.6','SC',1.0),('ส33101','สังคมศึกษาและเศรษฐศาสตร์ ม.6','SO',1.0),
    ('ส33102','หน้าที่พลเมืองและกฎหมาย ม.6','SO',0.5),('พ33101','สุขศึกษาและพลศึกษา ม.6','HP',0.5),('ศ33101','ศิลปะและนาฏศิลป์ ม.6','AR',0.5),
    ('ง33101','การงานอาชีพและโครงงานอาชีพ ม.6','OC',0.5),('อ33101','ภาษาอังกฤษพื้นฐาน ม.6','EN',1.0),('อ33201','ภาษาอังกฤษเพื่อการศึกษาต่อ ม.6','EN',1.0),
    ('ก33901','แนะแนวศึกษาต่อ / ชุมนุม ม.6','AC',0.5)
  ) as s(code, name, dept, credits)
  on conflict (id_school, code) do nothing;

  -- ตารางสอน (จ.–ศ. คาบ 1–7) เติมเฉพาะห้องที่ยังไม่มีคาบ · ครูผู้สอนผูกตอนสมัคร (พาร์ท 3)
  with cls as (
    select c.id, c.room_no::int as rm,
           case c.grade_level when 'ม.1' then '21' when 'ม.2' then '22' when 'ม.3' then '23'
                              when 'ม.4' then '31' when 'ม.5' then '32' else '33' end as pre
    from "SchoolWebClassrooms" c
    where c.id_school = target and c.is_active and c.room_no ~ '^[1-5]$'
      and not exists (select 1 from "SchoolWebTeachingSchedules" t where t.classroom_id = c.id)
  ),
  sub as (
    select s.id, s.code, substr(s.code, 2, 2) as pre,
           row_number() over (partition by substr(s.code, 2, 2) order by s.code) as rn,
           count(*) over (partition by substr(s.code, 2, 2)) as total
    from "SchoolWebSubjects" s
    where s.id_school = target and s.is_active
  ),
  slots as (
    select d.dw, p.pn, (d.dw - 1) * 7 + (p.pn - 1) as idx
    from generate_series(1, 5) d(dw) cross join generate_series(1, 7) p(pn)
  )
  insert into "SchoolWebTeachingSchedules"(id_school, academic_term_id, classroom_id, subject_id,
                                          teacher_id, day_of_week, period_no, room_name)
  select target, v_term_id, c.id, s.id, null, sl.dw, sl.pn,
         case when s.code like 'ว%' then 'ห้องปฏิบัติการวิทย์'
              when s.code like 'พ%' then 'สนามกีฬา'
              when s.code like 'ก%' then 'หอประชุม'
              else 'ห้อง ' || c.pre || c.rm end
  from cls c cross join slots sl
  join sub s on s.pre = c.pre and s.rn = 1 + ((sl.idx + (c.rm - 1) * 3) % s.total);

  -- คะแนน SGS ภาคเรียน 1 ตามรายวิชาของแต่ละชั้น (เติมเฉพาะที่ยังไม่มี)
  with st as (
    select s.id, substr(s.student_code, 2, 1)::int as lvl, right(s.student_code, 2)::int as seat,
           substr(s.student_code, 3, 1)::int as rm
    from "SchoolWebStudents" s
    where s.id_school = target and s.student_code ~ '^D[1-6][1-5][0-9]{2}$'
  ),
  sj as (
    select s.code, s.name, s.credits, substr(s.code, 2, 2) as pre, left(s.code, 1) as ch,
           row_number() over (order by s.code) as k
    from "SchoolWebSubjects" s where s.id_school = target and s.is_active
  ),
  grid as (
    select st.id as student_id, 'ม.' || st.lvl as grade_level, sj.*,
           (st.seat * 17 + st.rm * 13 + st.lvl * 7 + sj.k * 19) % 100 as seed
    from st
    join sj on sj.pre = case st.lvl when 1 then '21' when 2 then '22' when 3 then '23'
                                    when 4 then '31' when 5 then '32' else '33' end
  )
  insert into "SchoolWebSgsGrades"(id_school, student_id, grade_level, term_no, year_be, subject_code,
    subject_name, learning_area, subject_type, credits,
    max_pre_mid_work, max_pre_mid_notebook, max_midterm, max_post_mid_work, max_post_mid_notebook,
    max_affective, max_final,
    pre_mid_work, pre_mid_notebook, midterm_score, post_mid_work, post_mid_notebook, affective_score,
    final_score, attended_hours, total_hours, reading_thinking_writing, desirable_characteristics,
    special_status, teacher_name, updated_at)
  select target, g.student_id, g.grade_level, 1, v_year, g.code, g.name,
         case g.ch when 'ท' then 'ภาษาไทย' when 'ค' then 'คณิตศาสตร์'
                   when 'ว' then 'วิทยาศาสตร์และเทคโนโลยี' when 'ส' then 'สังคมศึกษา ศาสนา และวัฒนธรรม'
                   when 'พ' then 'สุขศึกษาและพลศึกษา' when 'ศ' then 'ศิลปะ' when 'ง' then 'การงานอาชีพ'
                   when 'ก' then 'กิจกรรมพัฒนาผู้เรียน' else 'ภาษาต่างประเทศ' end,
         case when g.ch = 'ก' then 'กิจกรรม' when substr(g.code, 4, 1) = '2' then 'เพิ่มเติม' else 'พื้นฐาน' end,
         g.credits,
         15, 10, 20, 15, 5, 5, 30,
         case when g.seed >= 75 then 14 when g.seed >= 50 then 12 when g.seed >= 25 then 10 else 7 end,
         case when g.seed >= 60 then 9 when g.seed >= 30 then 7 else 5 end,
         case when g.seed >= 80 then 18 when g.seed >= 55 then 15 when g.seed >= 30 then 12 else 8 end,
         case when g.seed >= 75 then 14 when g.seed >= 50 then 12 when g.seed >= 25 then 10 else 7 end,
         case when g.seed >= 50 then 5 else 4 end,
         case when g.seed >= 30 then 5 else 4 end,
         case when g.seed >= 85 then 27 when g.seed >= 65 then 23 when g.seed >= 45 then 19
              when g.seed >= 25 then 15 when g.seed >= 8 then 11 else 6 end,
         round(g.credits * 40) - (g.seed % 3), round(g.credits * 40),
         case when g.seed >= 40 then 3 else 2 end, 3,
         case when g.seed = 3 then 'ร' else '' end,
         null, now()
  from grid g
  where not exists (
    select 1 from "SchoolWebSgsGrades" x
    where x.id_school = target and x.student_id = g.student_id and x.year_be = v_year
      and x.grade_level = g.grade_level and x.term_no = 1 and x.subject_code = g.code
  );

  -- ประกาศตัวอย่าง
  insert into "SchoolWebAnnouncements"(id_school, title, content, category, is_pinned)
  select target, a.title, a.content, a.category, a.pinned
  from (values
    ('ยินดีต้อนรับสู่โรงเรียนทดลองใช้', 'ข้อมูลในโรงเรียนนี้เป็นข้อมูลสมมุติทั้งหมด เพิ่ม แก้ไข หรือลบได้อิสระ ผู้ดูแลส่วนกลางรีเซ็ตกลับเป็นค่าตั้งต้นได้', 'general', true),
    ('กำหนดสอบกลางภาคเรียนที่ 1', 'สอบกลางภาคตามตารางสอบของแต่ละระดับชั้น', 'academic', false),
    ('ประชุมครูประจำเดือน', 'ประชุมครูทุกคน ณ หอประชุม หลังเลิกเรียน', 'hr', false)
  ) as a(title, content, category, pinned)
  where not exists (
    select 1 from "SchoolWebAnnouncements" x where x.id_school = target and x.title = a.title
  );

  select count(*) into n_students from "SchoolWebStudents" where id_school = target;
  select count(*) into n_subjects from "SchoolWebSubjects" where id_school = target;
  select count(*) into n_slots    from "SchoolWebTeachingSchedules" where id_school = target;
  select count(*) into n_grades   from "SchoolWebSgsGrades" where id_school = target;

  return jsonb_build_object('ok', true, 'id_school', target, 'year_be', v_year,
    'students', n_students, 'subjects', n_subjects, 'schedule_slots', n_slots, 'grades', n_grades);
end;
$$;

revoke all on function public.seed_demo_school_data(bigint) from public, anon;
grant execute on function public.seed_demo_school_data(bigint) to authenticated;

-- ----------------------------------------------------------------------------
-- 2) รีเซ็ต: ล้างข้อมูลงานของโรงเรียนทดลอง แล้วเติมใหม่ (บัญชีผู้ทดลองไม่ถูกลบ)
-- ----------------------------------------------------------------------------
create or replace function public.reset_demo_school_data(target bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_demo_school(target) then
    raise exception 'โรงเรียน % ไม่ใช่โรงเรียนทดลอง (SchoolWebDemoConfig)', target using errcode = '42501';
  end if;
  if auth.uid() is not null and not public.is_super_admin() then
    raise exception 'เฉพาะผู้ดูแลส่วนกลาง' using errcode = '42501';
  end if;

  delete from "SchoolWebSgsGrades"         where id_school = target;
  delete from "SchoolWebTeachingSchedules" where id_school = target;
  delete from "SchoolWebStudents"          where id_school = target;   -- แฟ้มประวัติ / ผู้ปกครอง ลบตาม (cascade)
  delete from "SchoolWebSubjects"          where id_school = target;
  delete from "SchoolWebClassrooms"        where id_school = target;
  delete from "SchoolWebAnnouncements"     where id_school = target;
  delete from "SchoolDepartments"          where id_school = target and category = 'academic';

  return public.seed_demo_school_data(target);
end;
$$;

revoke all on function public.reset_demo_school_data(bigint) from public, anon;
grant execute on function public.reset_demo_school_data(bigint) to authenticated;

insert into public."SchemaMigrations"(name) values ('school_web_demo_seed.sql') on conflict do nothing;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- เติมข้อมูลโรงเรียนทดลองทันที (รันซ้ำได้ ไม่ซ้ำ)
-- ----------------------------------------------------------------------------
select public.seed_demo_school_data(d.id_school) from public."SchoolWebDemoConfig" d;
