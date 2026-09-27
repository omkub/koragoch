-- ============================================================================
--  Leaves.firebase_id — จำว่าใบลาแถวนี้มาจากเอกสารไหนใน Firebase
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง  ต้องรัน "ก่อน" กดนำเข้าใบลาจากหน้าจัดการระบบ
--
--  ทำไม: การนำเข้าใบลาเดิมจับคู่ด้วย คน + ประเภทลา + วันที่ + เหตุผล
--  ถ้าแก้เหตุผลในระบบใหม่ นำเข้ารอบถัดไปจะจับคู่ไม่เจอแล้วสร้างใบซ้ำ
--  คอลัมน์นี้ทำให้นำเข้ากี่รอบก็จับคู่ได้ตรงตัว (Firebase doc id)
--
--  ใบลาที่สร้างในระบบใหม่เอง firebase_id = null (ไม่ถูกแตะตอนนำเข้า)
--  ใบลาที่นำเข้าไปก่อนหน้านี้ยังไม่มีค่า — การนำเข้ารอบแรกหลังรันไฟล์นี้
--  จะจับคู่ด้วยวิธีเดิมแล้วเติม firebase_id ให้เอง
-- ============================================================================

alter table public."Leaves" add column if not exists firebase_id text;

create unique index if not exists leaves_firebase_id_unique
  on public."Leaves" (firebase_id)
  where firebase_id is not null;

select count(*)                                   as ใบลาทั้งหมด,
       count(*) filter (where firebase_id is not null) as มี_firebase_id
from public."Leaves";
