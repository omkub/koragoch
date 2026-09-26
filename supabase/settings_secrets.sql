-- ============================================================================
--  ความปลอดภัยข้อ 2 — ย้ายค่าลับออกจากตาราง Settings
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--  ⚠️ deploy Edge Function school-bridge "ก่อน" รันไฟล์นี้ และ merge แอป
--     เวอร์ชันที่เรียก school-bridge ด้วย — แอปเวอร์ชันเก่าอ่าน secretKey จาก
--     Settings เอง หลังรันไฟล์นี้จะอ่านไม่ได้ (LINE/อัปโหลดไฟล์จะใช้ไม่ได้)
--
--  ปัญหา: Settings เก็บ secretKey (กุญแจของ Apps Script) และ channelToken
--  (LINE) และแอปโหลด Settings ทั้งตาราง ครูทุกคนจึงอ่านค่าลับได้ แล้วเอาไป
--  ยิง Apps Script เอง → ส่ง LINE อะไรก็ได้ / อัป-ลบไฟล์ใน Drive
--
--  ทางแก้:
--    - ตาราง AppSecrets (key/value) ไม่มี policy เลย = อ่านได้เฉพาะ
--      service_role (Edge Function) ครูและแอดมินอ่านผ่านแอปไม่ได้
--    - ย้าย secretKey / channelToken ไปไว้ที่นั่น แล้วล้างใน Settings
--    - trigger: ใครเขียนค่าลับลง Settings ระบบย้ายไป AppSecrets ให้เอง
--    - LineNotifyLog: กันแจ้ง LINE ซ้ำ (ใบละครั้ง)
--    - DriveUploads: จำว่าใครอัปไฟล์ไหน คนอัปลบไฟล์ของตัวเองได้
--
--  หลังรันแล้ว: ควรเปลี่ยน SECRET_KEY ใหม่ทั้งใน Apps Script และ AppSecrets
--  เพราะค่าเดิมครูทุกคนเคยอ่านได้ (ดูข้อ 5)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ตารางค่าลับ — ไม่มี policy = เฉพาะ service_role
-- ----------------------------------------------------------------------------

create table if not exists public."AppSecrets" (
  key          text primary key,
  value        text,
  "updatedAt"  timestamptz default now()
);
alter table public."AppSecrets" enable row level security;

comment on table public."AppSecrets" is
  'ค่าลับของระบบ (secretKey, channelToken) — อ่านได้เฉพาะ Edge Function';


-- ----------------------------------------------------------------------------
-- 2) ย้ายค่าเดิมจาก Settings (ถ้ามีหลายแถว ใช้ค่าล่าสุดที่ไม่ว่าง)
-- ----------------------------------------------------------------------------

do $$
declare
  col text;
  v   text;
begin
  foreach col in array array['secretKey', 'channelToken']
  loop
    if not exists (select 1 from information_schema.columns
                   where table_schema = 'public' and table_name = 'Settings'
                     and column_name = col) then
      continue;
    end if;

    execute format(
      'select %1$I::text from public."Settings" '
      'where coalesce(%1$I::text, '''') <> '''' '
      'order by "id_Settings" desc limit 1', col)
      into v;

    if v is not null then
      insert into public."AppSecrets"(key, value) values (col, v)
      on conflict (key) do update set value = excluded.value, "updatedAt" = now();
    end if;

    execute format('update public."Settings" set %I = null where %I is not null', col, col);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 3) trigger: ค่าลับที่เขียนลง Settings → ย้ายไป AppSecrets
-- ----------------------------------------------------------------------------

create or replace function public.move_settings_secrets()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  col text;
  v   text;
begin
  foreach col in array array['secretKey', 'channelToken']
  loop
    v := nullif(to_jsonb(new) ->> col, '');
    if v is not null then
      insert into "AppSecrets"(key, value) values (col, v)
      on conflict (key) do update set value = excluded.value, "updatedAt" = now();
    end if;
    if to_jsonb(new) ? col then
      new := jsonb_populate_record(new, jsonb_build_object(col, null));
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists move_settings_secrets on public."Settings";
create trigger move_settings_secrets
  before insert or update on public."Settings"
  for each row execute function public.move_settings_secrets();


-- ----------------------------------------------------------------------------
-- 4) ตารางของ Edge Function school-bridge — ไม่มี policy = เฉพาะ service_role
-- ----------------------------------------------------------------------------

create table if not exists public."LineNotifyLog" (
  id_leaves  bigint not null,
  kind       text   not null,
  "sentAt"   timestamptz default now(),
  primary key (id_leaves, kind)
);
alter table public."LineNotifyLog" enable row level security;

-- ใบลาที่มีอยู่แล้วถือว่าแจ้งไปแล้ว กันการยิงย้อนหลังทั้งหมดถ้ามีบั๊กเรียกซ้ำ
insert into public."LineNotifyLog"(id_leaves, kind)
select id_leaves, 'new_leave' from public."Leaves"
on conflict do nothing;

create table if not exists public."DriveUploads" (
  file_id      text primary key,
  id_user      bigint,
  "createdAt"  timestamptz default now()
);
alter table public."DriveUploads" enable row level security;


-- ----------------------------------------------------------------------------
-- 5) ตรวจผล
--    ค่าลับที่ย้ายแล้ว: ควรมี secretKey (และ channelToken ถ้าเคยตั้งไว้)
--    ค่าลับที่ยังค้างใน_Settings ต้องเป็น 0
--
--    เปลี่ยน SECRET_KEY ใหม่ (แนะนำ):
--      1. ตั้งค่าใหม่ใน Apps Script (ตัวแปร SECRET_KEY) แล้ว Deploy ใหม่
--      2. รันคำสั่งนี้โดยใส่ค่าเดียวกัน (พิมพ์ใน SQL Editor เท่านั้น ห้าม commit):
--         update public."AppSecrets" set value = '<ค่าใหม่>', "updatedAt" = now()
--         where key = 'secretKey';
-- ----------------------------------------------------------------------------

select
  (select string_agg(key, ', ' order by key) from public."AppSecrets"
    where coalesce(value, '') <> '')                    as ค่าลับที่ย้ายแล้ว,
  (select count(*) from public."Settings" s
    where coalesce(to_jsonb(s) ->> 'secretKey', '') <> ''
       or coalesce(to_jsonb(s) ->> 'channelToken', '') <> '') as ค่าลับที่ยังค้างใน_Settings,
  (select count(*) from public."LineNotifyLog")         as ใบลาที่ถือว่าแจ้งแล้ว;
