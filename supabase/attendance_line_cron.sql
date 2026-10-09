-- ============================================================================
--  ลงเวลา — พาร์ท 6: ตั้งเวลาส่งสรุป LINE ประจำวันอัตโนมัติ (ไม่บังคับ)
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (รหัสเดิมไม่เปลี่ยน / งานเดิมถูกแทนที่)
--  ต้องรันก่อนแล้ว: attendance_daily.sql, settings_secrets.sql (ตาราง AppSecrets)
--  ต้อง deploy ก่อน: Edge Function attendance-daily-line (ดู supabase/functions/README.md)
--
--  ทำอะไร:
--    1) เปิด pg_cron + pg_net (ส่วนขยายของ Supabase ใช้ฟรี)
--    2) สร้างรหัสลับสำหรับงานตั้งเวลา เก็บใน AppSecrets (แอป/ครูอ่านไม่ได้)
--    3) ตั้งงาน "ทุก 10 นาที ช่วง 06:00–13:59 เวลาไทย" ให้เรียก Edge Function
--       ฟังก์ชันเลือกเองว่าโรงเรียนไหนถึงเวลาส่ง (ตั้งเวลาที่ web ต่อโรงเรียน)
--       และส่งวันละครั้งต่อโรงเรียน เฉพาะวันทำการ
--
--  ปิดการส่งอัตโนมัติทั้งหมด:
--    select cron.unschedule('attendance-daily-line');
--  (ปิดรายโรงเรียน: web > ลงเวลา > ติ๊กออก "ส่งสรุปเข้ากลุ่ม LINE")
-- ============================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- รหัสลับ (สร้างครั้งเดียว รันซ้ำไม่เปลี่ยน)
insert into public."AppSecrets"(key, value)
values ('attendance_cron_secret', encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (key) do nothing;

-- งานเดิม (ถ้ามี) → แทนที่
do $$
begin
  perform cron.unschedule('attendance-daily-line');
exception when others then
  null;
end $$;

-- pg_cron ใช้เวลา UTC: 06:00–13:59 ไทย = 23:00–06:59 UTC
select cron.schedule(
  'attendance-daily-line',
  '*/10 0-6,23 * * *',
  $job$
    select net.http_post(
      url     := 'https://uziajblqlbrvqmxvizsi.supabase.co/functions/v1/attendance-daily-line',
      headers := jsonb_build_object(
                   'content-type', 'application/json',
                   'x-cron-secret', (select value from public."AppSecrets"
                                     where key = 'attendance_cron_secret')),
      body    := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $job$
);


-- ----------------------------------------------------------------------------
-- ตรวจผล — ต้องได้ 1 แถว active = true
-- ดูผลการเรียกแต่ละรอบ (หลังผ่านไป 10 นาที):
--   select status_code, content, created
--   from net._http_response order by created desc limit 5;
-- ----------------------------------------------------------------------------

select jobname, schedule, active,
       exists (select 1 from public."AppSecrets"
               where key = 'attendance_cron_secret') as มีรหัสลับ
from cron.job
where jobname = 'attendance-daily-line';
