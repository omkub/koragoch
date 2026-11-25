-- ============================================================================
--  ระบบรับสมัครนักเรียนใหม่ออนไลน์ (หน้าเว็บโรงเรียนสาธารณะ #/public)
--
--  รันซ้ำได้ (Idempotent) · ไม่กระทบแอปวันลา
--  - สร้างตาราง SchoolPublicWebAdmissions เก็บใบสมัครนักเรียนใหม่แยกตามโรงเรียน
--  - คุ้มครองข้อมูลส่วนบุคคล (PDPA): บุคคลภายนอก (anon) อ่านตารางตรงไม่ได้
--    ต้องผ่าน RPC ที่ปลอดภัย 3 ตัว:
--      1. submit_public_admission(...) — ส่งใบสมัครและออกเลขที่ใบสมัครอัตโนมัติ
--      2. get_public_admission_stats(target_school) — นับยอดผู้สมัคร ม.1 / ม.4 / รวม
--      3. check_public_admission_status(target_school, p_query) — ค้นหาสถานะเฉพาะผู้สมัครรายนั้น
--  - แอดมินโรงเรียน / ผู้ดูแลส่วนกลาง / ครูผู้ดูแลเว็บสาธารณะ (can_manage_public_school_web)
--    สามารถดู แก้ไขสถานะ กำหนดห้องสอบ/เลขที่นั่งสอบ และลบใบสมัครได้
-- ============================================================================

create table if not exists public."SchoolPublicWebAdmissions" (
  id                  bigint generated always as identity primary key,
  id_school           bigint not null references public."Schools"("id_school") on delete cascade,
  application_code    text not null,
  academic_year       text not null default '2568',
  grade_level         text not null check (grade_level in ('m1', 'm4')),
  program_id          text not null,
  program_label       text not null,
  national_id         text not null check (char_length(national_id) between 1 and 20),
  prefix              text not null default 'เด็กชาย',
  full_name           text not null check (char_length(full_name) between 1 and 200),
  birth_date          date,
  previous_school     text not null check (char_length(previous_school) between 1 and 200),
  gpax                numeric(4,2),
  parent_name         text not null check (char_length(parent_name) between 1 and 200),
  parent_relation     text not null default 'ผู้ปกครอง',
  parent_phone        text not null check (char_length(parent_phone) between 1 and 50),
  doc_transcript_name text,
  doc_photo_name      text,
  doc_house_reg_name  text,
  doc_transcript_data text,
  doc_photo_data      text,
  doc_house_reg_data  text,
  status              text not null default 'pending'
    check (status in ('pending', 'verified', 'needs_fix', 'passed', 'enrolled', 'rejected')),
  status_note         text,
  exam_seat_no        text,
  exam_room           text,
  exam_date_label     text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (id_school, application_code)
);

create index if not exists school_public_web_admissions_school_idx
  on public."SchoolPublicWebAdmissions"(id_school, created_at desc);

create index if not exists school_public_web_admissions_nid_idx
  on public."SchoolPublicWebAdmissions"(id_school, national_id);

alter table public."SchoolPublicWebAdmissions" enable row level security;

drop policy if exists "school_public_web_admissions_manage_select" on public."SchoolPublicWebAdmissions";
create policy "school_public_web_admissions_manage_select"
  on public."SchoolPublicWebAdmissions"
  for select
  to authenticated
  using (public.can_manage_public_school_web(id_school));

drop policy if exists "school_public_web_admissions_manage_write" on public."SchoolPublicWebAdmissions";
create policy "school_public_web_admissions_manage_write"
  on public."SchoolPublicWebAdmissions"
  for all
  to authenticated
  using (public.can_manage_public_school_web(id_school))
  with check (public.can_manage_public_school_web(id_school));

-- ----------------------------------------------------------------------------
--  1) RPC: ส่งใบสมัครนักเรียนใหม่ออนไลน์ (anon + authenticated)
-- ----------------------------------------------------------------------------
create or replace function public.submit_public_admission(
  p_school_id           bigint,
  p_code_prefix         text default 'ADM',
  p_academic_year       text default '2568',
  p_grade_level         text default 'm1',
  p_program_id          text default 'm1-normal',
  p_program_label       text default 'ห้องเรียนทั่วไป',
  p_national_id         text default '',
  p_prefix              text default 'เด็กชาย',
  p_full_name           text default '',
  p_birth_date          text default null,
  p_previous_school     text default '',
  p_gpax                numeric default null,
  p_parent_name         text default '',
  p_parent_relation     text default 'ผู้ปกครอง',
  p_parent_phone        text default '',
  p_doc_transcript_name text default null,
  p_doc_photo_name      text default null,
  p_doc_house_reg_name  text default null,
  p_doc_transcript_data text default null,
  p_doc_photo_data      text default null,
  p_doc_house_reg_data  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_clean_nid   text;
  v_prefix      text;
  v_year_short  text;
  v_seq         int;
  v_app_code    text;
  v_birth_date  date;
  v_inserted_id bigint;
  v_created_at  timestamptz;
begin
  if p_school_id is null then
    return jsonb_build_object('ok', false, 'error', 'ไม่พบรหัสโรงเรียน');
  end if;

  if not exists (select 1 from public."Schools" where "id_school" = p_school_id) then
    return jsonb_build_object('ok', false, 'error', 'ไม่พบข้อมูลโรงเรียนในระบบ');
  end if;

  v_clean_nid := regexp_replace(coalesce(p_national_id, ''), '[^0-9]', '', 'g');
  if char_length(v_clean_nid) <> 13 then
    return jsonb_build_object('ok', false, 'error', 'กรุณากรอกเลขประจำตัวประชาชนให้ครบ 13 หลัก');
  end if;

  if btrim(coalesce(p_full_name, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'กรุณาระบุชื่อ-นามสกุลผู้สมัคร');
  end if;

  if p_grade_level not in ('m1', 'm4') then
    return jsonb_build_object('ok', false, 'error', 'ระดับชั้นไม่ถูกต้อง');
  end if;

  begin
    if p_birth_date is not null and btrim(p_birth_date) <> '' then
      v_birth_date := p_birth_date::date;
    end if;
  exception when others then
    v_birth_date := null;
  end;

  v_prefix := upper(regexp_replace(coalesce(nullif(btrim(p_code_prefix), ''), 'ADM'), '[^A-Za-z0-9]', '', 'g'));
  if v_prefix = '' then v_prefix := 'ADM'; end if;
  v_year_short := right(regexp_replace(coalesce(p_academic_year, '2568'), '[^0-9]', '', 'g'), 2);
  if v_year_short = '' then v_year_short := '68'; end if;

  select count(*)::int + 1 into v_seq
  from public."SchoolPublicWebAdmissions"
  where id_school = p_school_id
    and academic_year = coalesce(nullif(btrim(p_academic_year), ''), '2568');

  v_app_code := v_prefix || '-' || v_year_short || '-' || lpad(v_seq::text, 5, '0');
  while exists (
    select 1 from public."SchoolPublicWebAdmissions"
    where id_school = p_school_id and application_code = v_app_code
  ) loop
    v_seq := v_seq + 1;
    v_app_code := v_prefix || '-' || v_year_short || '-' || lpad(v_seq::text, 5, '0');
  end loop;

  insert into public."SchoolPublicWebAdmissions" (
    id_school,
    application_code,
    academic_year,
    grade_level,
    program_id,
    program_label,
    national_id,
    prefix,
    full_name,
    birth_date,
    previous_school,
    gpax,
    parent_name,
    parent_relation,
    parent_phone,
    doc_transcript_name,
    doc_photo_name,
    doc_house_reg_name,
    doc_transcript_data,
    doc_photo_data,
    doc_house_reg_data
  )
  values (
    p_school_id,
    v_app_code,
    coalesce(nullif(btrim(p_academic_year), ''), '2568'),
    p_grade_level,
    coalesce(nullif(btrim(p_program_id), ''), p_grade_level || '-normal'),
    coalesce(nullif(btrim(p_program_label), ''), 'ห้องเรียนทั่วไป'),
    v_clean_nid,
    coalesce(nullif(btrim(p_prefix), ''), 'เด็กชาย'),
    btrim(p_full_name),
    v_birth_date,
    coalesce(nullif(btrim(p_previous_school), ''), '-'),
    p_gpax,
    coalesce(nullif(btrim(p_parent_name), ''), '-'),
    coalesce(nullif(btrim(p_parent_relation), ''), 'ผู้ปกครอง'),
    coalesce(nullif(btrim(p_parent_phone), ''), '-'),
    p_doc_transcript_name,
    p_doc_photo_name,
    p_doc_house_reg_name,
    p_doc_transcript_data,
    p_doc_photo_data,
    p_doc_house_reg_data
  )
  returning id, created_at into v_inserted_id, v_created_at;

  return jsonb_build_object(
    'ok', true,
    'id', v_inserted_id,
    'application_code', v_app_code,
    'status', 'pending',
    'created_at', v_created_at
  );
end;
$$;

grant execute on function public.submit_public_admission(
  bigint, text, text, text, text, text, text, text, text, text, text, numeric,
  text, text, text, text, text, text, text, text, text
) to anon, authenticated;

-- ----------------------------------------------------------------------------
--  2) RPC: นับยอดผู้สมัคร ม.1 / ม.4 / รวม (ไม่เปิดเผยข้อมูลส่วนบุคคล)
-- ----------------------------------------------------------------------------
create or replace function public.get_public_admission_stats(target_school bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_m1 int := 0;
  v_m4 int := 0;
begin
  if target_school is null then
    return jsonb_build_object('m1_count', 0, 'm4_count', 0, 'total_count', 0);
  end if;

  select
    count(*) filter (where grade_level = 'm1')::int,
    count(*) filter (where grade_level = 'm4')::int
  into v_m1, v_m4
  from public."SchoolPublicWebAdmissions"
  where id_school = target_school;

  return jsonb_build_object(
    'm1_count', coalesce(v_m1, 0),
    'm4_count', coalesce(v_m4, 0),
    'total_count', coalesce(v_m1, 0) + coalesce(v_m4, 0)
  );
end;
$$;

grant execute on function public.get_public_admission_stats(bigint) to anon, authenticated;

-- ----------------------------------------------------------------------------
--  3) RPC: ตรวจสอบสถานะการสมัคร & ข้อมูลพิมพ์บัตรสอบ (ค้นด้วยเลข ปชช. หรือเลขที่ใบสมัคร)
-- ----------------------------------------------------------------------------
-- ตรวจสถานะการสมัคร: ต้องใช้ "เลขที่ใบสมัคร" คู่กับ "เลขประจำตัวประชาชน 13 หลัก" เสมอ
-- (เลขที่ใบสมัครเป็นเลขเรียง เดาได้ จึงห้ามใช้อย่างเดียว) · ผิด 5 ครั้ง / 15 นาที ล็อก
create table if not exists public."SchoolPublicAdmissionLookupAttempts" (
  id               bigint generated always as identity primary key,
  id_school        bigint not null,
  application_code text not null,
  attempted_at     timestamptz not null default now()
);
create index if not exists school_public_admission_attempts_idx
  on public."SchoolPublicAdmissionLookupAttempts"(id_school, application_code, attempted_at desc);
alter table public."SchoolPublicAdmissionLookupAttempts" enable row level security;
-- ไม่มี policy = เข้าถึงได้เฉพาะผ่านฟังก์ชัน security definer

drop function if exists public.check_public_admission_status(bigint, text);
drop function if exists public.check_public_admission_status(bigint, text, text);
create function public.check_public_admission_status(
  target_school      bigint,
  p_application_code text,
  p_national_id      text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_code       text;
  v_nid        text;
  v_fails      int;
  v_rec        record;
  generic_fail constant text := 'ไม่พบข้อมูลการสมัคร หรือข้อมูลยืนยันไม่ถูกต้อง';
begin
  v_code := upper(btrim(coalesce(p_application_code, '')));
  v_nid  := regexp_replace(coalesce(p_national_id, ''), '[^0-9]', '', 'g');

  if target_school is null or v_code = '' or char_length(v_nid) <> 13 then
    return jsonb_build_object('found', false, 'error', 'กรุณากรอกเลขที่ใบสมัคร และเลขประจำตัวประชาชน 13 หลัก');
  end if;

  select count(*) into v_fails
  from public."SchoolPublicAdmissionLookupAttempts" a
  where a.id_school = target_school
    and a.application_code = v_code
    and a.attempted_at > now() - interval '15 minutes';
  if v_fails >= 5 then
    return jsonb_build_object('found', false, 'error', 'ลองผิดหลายครั้งเกินไป กรุณารอ 15 นาทีแล้วลองใหม่');
  end if;

  select id, application_code, academic_year, grade_level, program_id, program_label,
         prefix, full_name, previous_school, gpax, status, status_note,
         exam_seat_no, exam_room, exam_date_label, doc_photo_data, created_at
  into v_rec
  from public."SchoolPublicWebAdmissions"
  where id_school = target_school
    and upper(application_code) = v_code
    and national_id = v_nid
  limit 1;

  if not found then
    insert into public."SchoolPublicAdmissionLookupAttempts"(id_school, application_code)
    values (target_school, v_code);
    delete from public."SchoolPublicAdmissionLookupAttempts" where attempted_at < now() - interval '1 day';
    return jsonb_build_object('found', false, 'error', generic_fail);
  end if;

  return jsonb_build_object(
    'found', true,
    'application', jsonb_build_object(
      'id', v_rec.id,
      'application_code', v_rec.application_code,
      'academic_year', v_rec.academic_year,
      'grade_level', v_rec.grade_level,
      'program_id', v_rec.program_id,
      'program_label', v_rec.program_label,
      'prefix', v_rec.prefix,
      'full_name', v_rec.full_name,
      'previous_school', v_rec.previous_school,
      'gpax', v_rec.gpax,
      'status', v_rec.status,
      'status_note', v_rec.status_note,
      'exam_seat_no', v_rec.exam_seat_no,
      'exam_room', v_rec.exam_room,
      'exam_date_label', v_rec.exam_date_label,
      'doc_photo_data', v_rec.doc_photo_data,
      'created_at', v_rec.created_at
    )
  );
end;
$$;

revoke all on function public.check_public_admission_status(bigint, text, text) from public;
grant execute on function public.check_public_admission_status(bigint, text, text) to anon, authenticated;

insert into public."SchemaMigrations"(name)
  values ('school_public_web_admissions.sql')
  on conflict do nothing;

notify pgrst, 'reload schema';
