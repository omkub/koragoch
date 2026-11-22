-- ============================================================================
--  หน้าเว็บโรงเรียนสำหรับบุคคลภายนอก (Public Web) และสิทธิ์ตั้งค่าเว็บสาธารณะ
--
--  รันซ้ำได้ (Idempotent) · ไม่กระทบแอปวันลา
--  สร้างตาราง SchoolPublicWebConfigs เก็บข้อมูลตั้งค่าหน้าเว็บสาธารณะของแต่ละโรงเรียน
--  - อ่าน (SELECT): เปิดให้ทุกคน (anon + authenticated) เข้าดูหน้าเว็บสาธารณะได้โดยไม่ต้องล็อกอิน
--  - เขียน (INSERT / UPDATE / DELETE): อนุญาตเฉพาะ 3 กลุ่ม:
--      1. ผู้ดูแลระบบส่วนกลาง (is_super_admin)
--      2. แอดมินโรงเรียน (can_manage_school หรือ บทบาทระดับแอดมินโรงเรียน menu_id -602)
--      3. ครูที่ได้รับมอบหมายหน้าที่ตั้งค่าเว็บสาธารณะ (menu_id รายบุคคล -(100000 + uid*100 + 30)
--         หรือ menu_id ตามบทบาท -510)
-- ============================================================================

create table if not exists public."SchoolPublicWebConfigs" (
  id_school bigint primary key references public."Schools"("id_school") on delete cascade,
  config_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public."SchoolPublicWebConfigs" enable row level security;

create or replace function public.can_manage_public_school_web(target_school bigint)
returns boolean
language plpgsql stable security definer set search_path = public
as $$
declare
  uid bigint;
  rid bigint;
  v boolean;
begin
  if target_school is null then
    return public.is_super_admin();
  end if;
  if public.can_manage_school(target_school) then
    return true;
  end if;
  if target_school is distinct from public.current_school_id() then
    return false;
  end if;

  select t.id_user, t.id_role into uid, rid
  from public."Teachers" t where t.auth_uid = auth.uid() limit 1;
  if uid is null then
    return false;
  end if;

  -- บทบาทระดับ "แอดมินโรงเรียน" ใน web (menu_id -602)
  if rid is not null and coalesce(public.school_web_perm(target_school, rid, -602), false) then
    return true;
  end if;

  -- สิทธิ์รายบุคคล: ครูที่ได้รับมอบหมายให้ตั้งค่าเว็บสาธารณะ (slot 10 -> edit = 20 + 10 = 30)
  v := public.school_web_perm(target_school, 22, -(100000 + uid * 100 + 30));
  if v is not null then
    return v;
  end if;

  -- สิทธิ์ตามบทบาท: บทบาทที่เปิดสิทธิ์ตั้งค่าเว็บสาธารณะ (menu_id -510)
  if rid is not null then
    v := public.school_web_perm(target_school, rid, -510);
    if v is not null then
      return v;
    end if;
  end if;

  return false;
end;
$$;

revoke all on function public.can_manage_public_school_web(bigint) from public, anon;
grant execute on function public.can_manage_public_school_web(bigint) to authenticated;

drop policy if exists "school_public_web_configs_read" on public."SchoolPublicWebConfigs";
create policy "school_public_web_configs_read"
  on public."SchoolPublicWebConfigs"
  for select
  to anon, authenticated
  using (true);

drop policy if exists "school_public_web_configs_write" on public."SchoolPublicWebConfigs";
create policy "school_public_web_configs_write"
  on public."SchoolPublicWebConfigs"
  for all
  to authenticated
  using (public.can_manage_public_school_web(id_school))
  with check (public.can_manage_public_school_web(id_school));

-- ----------------------------------------------------------------------------
--  กล่องข้อความ "ติดต่อโรงเรียน" จากหน้าเว็บสาธารณะ
--  แยกจาก SchoolPublicWebConfigs เพราะตารางนั้นทุกคนอ่านได้
--  - คนนอก (anon) ส่งข้อความได้อย่างเดียว อ่านไม่ได้
--  - อ่าน / ลบ ได้เฉพาะผู้มีสิทธิ์ตั้งค่าเว็บสาธารณะของโรงเรียนนั้น
-- ----------------------------------------------------------------------------
create table if not exists public."SchoolPublicWebMessages" (
  id             bigint generated always as identity primary key,
  id_school      bigint not null references public."Schools"("id_school") on delete cascade,
  name           text not null check (char_length(name) between 1 and 200),
  email_or_phone text check (char_length(email_or_phone) <= 200),
  subject        text check (char_length(subject) <= 200),
  message        text not null check (char_length(message) between 1 and 5000),
  created_at     timestamptz not null default now()
);

create index if not exists school_public_web_messages_school_idx
  on public."SchoolPublicWebMessages"(id_school, created_at desc);

alter table public."SchoolPublicWebMessages" enable row level security;

drop policy if exists "school_public_web_messages_insert" on public."SchoolPublicWebMessages";
create policy "school_public_web_messages_insert"
  on public."SchoolPublicWebMessages"
  for insert
  to anon, authenticated
  with check (true);

drop policy if exists "school_public_web_messages_manage" on public."SchoolPublicWebMessages";
create policy "school_public_web_messages_manage"
  on public."SchoolPublicWebMessages"
  for select
  to authenticated
  using (public.can_manage_public_school_web(id_school));

drop policy if exists "school_public_web_messages_delete" on public."SchoolPublicWebMessages";
create policy "school_public_web_messages_delete"
  on public."SchoolPublicWebMessages"
  for delete
  to authenticated
  using (public.can_manage_public_school_web(id_school));

grant insert on public."SchoolPublicWebMessages" to anon;

-- ----------------------------------------------------------------------------
--  ลงทะเบียนระบบงานใหม่ในทะเบียนกลาง (ให้โผล่ในฝ่ายบริหารทั่วไป)
-- ----------------------------------------------------------------------------
insert into public."SchoolWebModuleCatalog"
  (module_key, title, description, module_type, default_division_key, default_url, sort_order)
values
  (
    'public-web-settings',
    'ตั้งค่าหน้าเว็บโรงเรียนสาธารณะ',
    'จัดการข่าวประชาสัมพันธ์ ทำเนียบบุคลากร ข้อมูลนักเรียน ข้อมูลโรงเรียน และช่องทางติดต่อบนหน้าเว็บสำหรับคนนอกดู',
    'builtin',
    'admin',
    null,
    3
  )
on conflict (module_key) do nothing;

insert into public."SchemaMigrations"(name) values ('school_public_web.sql') on conflict do nothing;

notify pgrst, 'reload schema';
