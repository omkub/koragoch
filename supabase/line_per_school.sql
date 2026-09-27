-- ============================================================================
--  LINE แยกตามโรงเรียน — ผู้ดูแลระบบส่วนกลางกำหนดว่าโรงเรียนไหนส่งเข้ากลุ่มไหน
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  (ต้องรัน settings_secrets.sql มาก่อนแล้ว)
--
--  ดีไซน์ (ตกลงกันไว้): LINE Official Account / channel เดียว แต่แต่ละโรงเรียน
--  ส่งเข้ากลุ่ม (groupId) ของตัวเอง
--
--  SchoolLineSettings — แถวละโรงเรียน
--    groupId   กลุ่ม LINE ที่จะแจ้งใบลาใหม่ของโรงเรียนนี้
--    enabled   เปิด/ปิดการแจ้งเตือน (ปิด = ไม่ส่งเลย)
--    template  ข้อความ (ว่าง = ใช้ template กลางใน Settings หรือแบบมาตรฐาน)
--
--  อ่าน/แก้ได้เฉพาะผู้ดูแลส่วนกลาง (แอดมินโรงเรียนแก้ไม่ได้ตามที่เจ้าของกำหนด)
--  Edge Function school-bridge อ่านด้วย service_role ตอนส่งแจ้งเตือน
--
--  ⚠️ โรงเรียนที่ไม่มีแถว หรือ enabled = false จะ "ไม่ส่ง LINE"
--     ข้อ 3 สร้างแถวให้ทุกโรงเรียนแบบปิดไว้ก่อน ไปเปิดที่เว็บส่วนกลาง
-- ============================================================================


-- 1) ตาราง ------------------------------------------------------------------

create table if not exists public."SchoolLineSettings" (
  id_school    bigint primary key
               references public."Schools"(id_school) on delete cascade,
  "groupId"    text,
  template     text,
  enabled      boolean not null default false,
  "updatedAt"  timestamptz default now()
);

comment on table public."SchoolLineSettings" is
  'กลุ่ม LINE ของแต่ละโรงเรียน — แก้ได้เฉพาะผู้ดูแลระบบส่วนกลาง';


-- 2) RLS: เฉพาะผู้ดูแลส่วนกลาง ------------------------------------------------

alter table public."SchoolLineSettings" enable row level security;

do $$
declare
  p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'SchoolLineSettings'
  loop
    execute format('drop policy %I on public."SchoolLineSettings"', p.policyname);
  end loop;
end $$;

create policy school_line_super on "SchoolLineSettings"
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());


-- 3) แถวเริ่มต้น -------------------------------------------------------------
--
--    โรงเรียนแรก: ยก groupId / template เดิมจาก Settings มาให้ (เดิมใช้กลุ่มนี้
--    กลุ่มเดียวทั้งระบบ) แต่ "ปิด" ไว้ก่อน เพราะเดิมแอปก็ปิดการแจ้งเตือนไว้
--    (สวิตช์ช่วงทดสอบ) — ไปเปิดที่เว็บส่วนกลางเมื่อพร้อม
--    โรงเรียนอื่น: แถวว่าง ปิดไว้

do $$
declare
  first_school bigint;
  old_group    text;
  old_template text;
begin
  select min(id_school) into first_school from public."Schools";

  select s."groupId" into old_group from public."Settings" s
  where coalesce(s."groupId", '') <> ''
  order by s."id_Settings" desc limit 1;

  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'Settings'
               and column_name = 'template') then
    execute 'select template from public."Settings"
             where coalesce(template, '''') <> ''''
             order by "id_Settings" desc limit 1' into old_template;
  end if;

  insert into public."SchoolLineSettings"(id_school, "groupId", template, enabled)
  values (first_school, old_group, old_template, false)
  on conflict (id_school) do nothing;

  insert into public."SchoolLineSettings"(id_school)
  select id_school from public."Schools"
  on conflict (id_school) do nothing;
end $$;

-- โรงเรียนที่เพิ่มทีหลังได้แถว (ปิดไว้) อัตโนมัติ
create or replace function public.add_school_line_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into "SchoolLineSettings"(id_school) values (new.id_school)
  on conflict (id_school) do nothing;
  return new;
end;
$$;

drop trigger if exists add_school_line_row on public."Schools";
create trigger add_school_line_row
  after insert on public."Schools"
  for each row execute function public.add_school_line_row();


-- 4) ตรวจผล — ทุกโรงเรียนต้องมี 1 แถว ------------------------------------------

select sc.id_school,
       coalesce(sc."namePart1", '') || ' ' || coalesce(sc."namePart2", '') as โรงเรียน,
       l."groupId" is not null and l."groupId" <> ''                      as มีกลุ่ม_line,
       l.enabled                                                           as เปิดแจ้งเตือน
from public."Schools" sc
left join public."SchoolLineSettings" l using (id_school)
order by sc.id_school;
