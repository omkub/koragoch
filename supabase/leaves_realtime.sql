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
--  ปิด: alter publication supabase_realtime drop table public."Leaves";
-- ============================================================================

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'Leaves') then
    alter publication supabase_realtime add table public."Leaves";
  end if;
end $$;

-- ตรวจผล: ต้องขึ้น Leaves และ AppNotifications
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public'
order by tablename;
