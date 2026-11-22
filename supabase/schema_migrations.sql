-- ============================================================================
--  F9: บันทึกว่า SQL ไฟล์ไหนรันในฐานข้อมูลแล้ว (แทนการจำเอง)
--
--  รันครั้งเดียวก่อนไฟล์อื่น (รันซ้ำได้) · ไม่แตะตารางของระบบวันลา
--  ไฟล์ SQL ใหม่ทุกไฟล์ต้องจบด้วย:
--    insert into public."SchemaMigrations"(name) values ('<ชื่อไฟล์>.sql') on conflict do nothing;
--  ดูว่ารันอะไรไปแล้ว: select * from public."SchemaMigrations" order by applied_at;
-- ============================================================================

create table if not exists public."SchemaMigrations" (
  name        text primary key,
  applied_at  timestamptz not null default now(),
  applied_by  uuid default auth.uid()
);

alter table public."SchemaMigrations" enable row level security;

drop policy if exists schema_migrations_super on public."SchemaMigrations";
create policy schema_migrations_super on public."SchemaMigrations"
  for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

-- ไฟล์ที่รันไปแล้วก่อนมีตารางนี้ (ตามลำดับรันใน README)
insert into public."SchemaMigrations"(name, applied_at) values
  ('school_web_core.sql',                      '2026-01-01'),
  ('school_web_academic.sql',                  '2026-01-01'),
  ('school_web_admin.sql',                     '2026-01-01'),
  ('school_web_part4_permissions_finance.sql', '2026-01-01'),
  ('school_web_appointment_orders.sql',        '2026-01-01'),
  ('school_web_appointment_orders_part2.sql',  '2026-01-01'),
  ('school_web_security_fix1.sql',             '2026-01-01'),
  ('school_admin_leave_settings.sql',          '2026-01-01'),
  ('master_data_lock.sql',                     '2026-01-01'),
  ('schema_migrations.sql',                    now())
on conflict do nothing;

select * from public."SchemaMigrations" order by applied_at, name;
