-- ============================================================================
--  ใบลาแบบ realtime — หน้าประวัติการลาอัปเดตเองเมื่อมีการส่ง / แก้ / อนุมัติ / ลบ
--  จากเครื่องไหนก็ได้ ไม่ต้องกดรีเฟรช
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง
--
--  แอปฟังตาราง Leaves ผ่าน FirebaseService.onLeavesChanged แล้วโหลดรายการใหม่
--  Realtime ส่งให้เฉพาะแถวที่ RLS อนุญาตให้ผู้ใช้คนนั้นเห็น (โรงเรียนตัวเอง)
--  ยังไม่รันไฟล์นี้: หน้ายังใช้ได้ปกติ แค่ไม่อัปเดตเองจากเครื่องอื่น
--
--  หาตารางจาก pg_class เอง (ไม่พิมพ์ชื่อตรง ๆ) — รอบแรกขึ้น
--  relation "public.Leaves" does not exist ทั้งที่แอปใช้ตารางนี้อยู่
--
--  ปิด: alter publication supabase_realtime drop table <ชื่อที่ข้อ 1 แสดง>;
-- ============================================================================

-- 1) ตารางใบลาจริงในฐานข้อมูล (ดูชื่อ / schema / ชนิด)
select n.nspname                       as schema,
       c.relname                       as ชื่อตาราง,
       c.relkind                       as ชนิด,   -- r = ตาราง, v = view, p = ตารางแบ่งส่วน
       format('%I.%I', n.nspname, c.relname) as ชื่อเต็ม
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where lower(c.relname) = 'leaves'
  and n.nspname not in ('pg_catalog', 'information_schema');

-- 2) เพิ่มเข้า realtime (เฉพาะตารางจริงใน public)
do $$
declare
  target regclass;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'ไม่พบ publication supabase_realtime — เปิด Realtime ในโปรเจกต์ก่อน';
    return;
  end if;

  select c.oid::regclass into target
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and lower(c.relname) = 'leaves'
    and c.relkind in ('r', 'p')
  order by (c.relname = 'Leaves') desc
  limit 1;

  if target is null then
    raise notice 'ไม่พบตารางใบลาใน public — ดูผลข้อ 1';
    return;
  end if;

  if exists (select 1 from pg_publication_rel pr
             join pg_publication p on p.oid = pr.prpubid
             where p.pubname = 'supabase_realtime' and pr.prrelid = target) then
    raise notice '% อยู่ใน realtime แล้ว', target;
    return;
  end if;

  execute format('alter publication supabase_realtime add table %s', target);
  raise notice 'เพิ่ม % เข้า realtime แล้ว', target;
end $$;

-- 3) ตรวจผล: ต้องขึ้นตารางใบลา และ AppNotifications
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by schemaname, tablename;
