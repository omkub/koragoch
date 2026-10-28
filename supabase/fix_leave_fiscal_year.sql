-- ============================================================================
--  แก้ปีงบประมาณของใบลาที่บันทึกผิด
--
--  วิธีรัน: Supabase Dashboard > SQL Editor > วางทั้งไฟล์ > Run
--  รันซ้ำได้ ไม่พัง (รอบที่สองจะไม่เหลืออะไรให้แก้)
--
--  ปัญหา: ฟอร์มใบลารุ่นเก่าใส่ปีงบ = ปี พ.ศ. ของ "วันที่ยื่น" ไม่ใช่ปีงบของ
--    "วันเริ่มลา" ใบลาที่ยื่นช่วง 1 ต.ค. – 31 ธ.ค. จึงได้ปีงบก่อนหน้า
--    เช่น ลา 30 ต.ค. 2569 (ปีงบ 2570) ถูกบันทึกเป็นปีงบ 2569
--    แอปแก้แล้ว (ใบใหม่คิดจากวันเริ่มลา) ไฟล์นี้แก้ใบที่บันทึกไปแล้ว
--
--  ปีงบ = ปีของวันเริ่มลา + 543 และ +1 ถ้าเป็นเดือน ต.ค. ขึ้นไป
--  เลือกแถว FiscalRounds ของปีนั้นแบบเดียวกับที่แอปเลือกตอนบันทึก
--  (id_year ที่น้อยที่สุดของปีนั้น) — รายงานสรุปกรองด้วยช่วงวันที่ของรอบ
--  อยู่แล้ว จึงไม่ได้รับผลจากการเลือกรอบ
--
--  ⚠️ ถ้าขั้น 1 ขึ้น "ยังไม่มีรอบงบประมาณ" ให้เพิ่มรอบปีงบนั้นในแอปก่อน
--     (ตั้งค่าปฏิทิน > รอบงบประมาณ) แล้วรันไฟล์นี้ใหม่ — ใบลาเหล่านั้นจะ
--     ยังไม่ถูกแก้จนกว่าจะมีรอบให้ชี้ไป
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) ดูก่อน: ใบลาที่ปีงบไม่ตรงกับวันเริ่มลา แยกตาม ปีงบเดิม → ปีงบที่ถูก
-- ----------------------------------------------------------------------------

with leave_fy as (
  select l.id_leaves,
         l.id_year as old_id,
         extract(year from l."startDate")::int + 543
           + case when extract(month from l."startDate") >= 10 then 1 else 0 end as fy
  from public."Leaves" l
  where l."startDate" is not null
)
select fr_old.year                                  as ปีงบเดิม,
       lf.fy                                        as ปีงบที่ถูก,
       count(*)                                     as จำนวนใบลา,
       case when exists (select 1 from public."FiscalRounds" f where f.year::text = lf.fy::text)
            then 'แก้ได้' else 'ยังไม่มีรอบงบประมาณปีนี้' end as หมายเหตุ
from leave_fy lf
left join public."FiscalRounds" fr_old on fr_old.id_year = lf.old_id
where fr_old.year is null or fr_old.year::text <> lf.fy::text
group by fr_old.year, lf.fy
order by lf.fy, fr_old.year;


-- ----------------------------------------------------------------------------
-- 2) แก้: ชี้ใบลาไปที่รอบงบประมาณของปีงบที่ถูก
-- ----------------------------------------------------------------------------

with leave_fy as (
  select l.id_leaves,
         l.id_year as old_id,
         extract(year from l."startDate")::int + 543
           + case when extract(month from l."startDate") >= 10 then 1 else 0 end as fy
  from public."Leaves" l
  where l."startDate" is not null
),
target as (
  select lf.id_leaves,
         (select f.id_year from public."FiscalRounds" f
           where f.year::text = lf.fy::text
           order by f.id_year
           limit 1) as new_id
  from leave_fy lf
  left join public."FiscalRounds" fr_old on fr_old.id_year = lf.old_id
  where fr_old.year is null or fr_old.year::text <> lf.fy::text
)
update public."Leaves" l
set id_year = t.new_id
from target t
where l.id_leaves = t.id_leaves
  and t.new_id is not null;


-- ----------------------------------------------------------------------------
-- 3) ตรวจผล — ต้องเหลือ 0 แถวที่ "แก้ได้"
--    (แถว "ยังไม่มีรอบงบประมาณปีนี้" = ต้องเพิ่มรอบก่อน ดูหมายเหตุบนสุด)
-- ----------------------------------------------------------------------------

with leave_fy as (
  select l.id_leaves,
         l.id_year as old_id,
         extract(year from l."startDate")::int + 543
           + case when extract(month from l."startDate") >= 10 then 1 else 0 end as fy
  from public."Leaves" l
  where l."startDate" is not null
)
select lf.fy as ปีงบที่ถูก,
       count(*) as ยังไม่ตรง,
       case when exists (select 1 from public."FiscalRounds" f where f.year::text = lf.fy::text)
            then '⚠️ ยังแก้ไม่ได้ — แจ้งผู้พัฒนา' else 'ยังไม่มีรอบงบประมาณปีนี้' end as หมายเหตุ
from leave_fy lf
left join public."FiscalRounds" fr_old on fr_old.id_year = lf.old_id
where fr_old.year is null or fr_old.year::text <> lf.fy::text
group by lf.fy
order by lf.fy;
