-- ============================================================================
--  โรงเรียนทดลองใช้ (Demo) — พาร์ท 3: ระบบสมัครทดลองใช้
--
--  รันซ้ำได้ · ไม่กระทบแอปวันลา · ต้องรันหลัง school_web_demo_setup.sql
--  การสมัครจริงทำใน Edge Function `trial-register` (service_role) — ไฟล์นี้เตรียมตารางให้
--
--  SchoolWebDemoAccounts       บัญชีทดลองที่สมัครเข้ามา (ใช้ลบเมื่อหมดอายุ — พาร์ท 4/5)
--  SchoolWebDemoSignupAttempts ประวัติการสมัคร (จำกัด 5 ครั้ง/ชั่วโมง/IP) ไม่มี policy = อ่านผ่าน API ไม่ได้
--  get_demo_school_info()      ข้อมูลโรงเรียนทดลองสำหรับหน้า /register (คนนอกเรียกได้)
-- ============================================================================

create table if not exists public."SchoolWebDemoAccounts" (
  id_user     bigint primary key,                 -- Teachers.id_user
  id_school   bigint not null references public."Schools"("id_school") on delete cascade,
  auth_uid    uuid,
  username    text not null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null
);

create index if not exists school_web_demo_accounts_expires_idx
  on public."SchoolWebDemoAccounts"(expires_at);

alter table public."SchoolWebDemoAccounts" enable row level security;

drop policy if exists "school_web_demo_accounts_read" on public."SchoolWebDemoAccounts";
create policy "school_web_demo_accounts_read"
  on public."SchoolWebDemoAccounts" for select to authenticated
  using (public.is_super_admin() or auth_uid = auth.uid());

create table if not exists public."SchoolWebDemoSignupAttempts" (
  id           bigint generated always as identity primary key,
  ip           text not null,
  attempted_at timestamptz not null default now()
);

create index if not exists school_web_demo_signup_attempts_idx
  on public."SchoolWebDemoSignupAttempts"(ip, attempted_at desc);

alter table public."SchoolWebDemoSignupAttempts" enable row level security;
-- ไม่มี policy: ใช้ได้เฉพาะ Edge Function (service_role)

create or replace function public.get_demo_school_info()
returns jsonb
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (select jsonb_build_object(
              'ok', true,
              'id_school', d.id_school,
              'school_name', s."fullName",
              'signup_enabled', d.demo_signup_enabled,
              'account_ttl_days', d.account_ttl_days)
     from public."SchoolWebDemoConfig" d
     join public."Schools" s on s.id_school = d.id_school
     order by d.id_school
     limit 1),
    jsonb_build_object('ok', false, 'signup_enabled', false));
$$;

revoke all on function public.get_demo_school_info() from public;
grant execute on function public.get_demo_school_info() to anon, authenticated;

insert into public."SchemaMigrations"(name) values ('school_web_demo_signup.sql') on conflict do nothing;

notify pgrst, 'reload schema';
