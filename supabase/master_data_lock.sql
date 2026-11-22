-- ============================================================================
--  F7: ข้อมูลกลาง (master data) — แอดมินโรงเรียนไหนก็แก้ได้ → ปิดช่องโหว่
--
--  ต้องรันก่อนแล้ว: school_web_security_fix1.sql (ใช้ public.can_manage_school)
--  รันซ้ำได้ (Idempotent) · ไม่แก้ข้อมูล
--
--  แตะเฉพาะ policy ชื่อ master_write (จาก enable_rls.sql) และ schools_write
--  (จาก create_schools_table.sql) ที่ยังเป็น "is_admin()" เฉยๆ:
--    - ตารางมีคอลัมน์ id_school → can_manage_school(id_school)
--        แอดมินโรงเรียนแก้ได้เฉพาะแถวโรงเรียนตัวเอง · แถวกลาง (id_school ว่าง) = ส่วนกลาง
--    - ตารางไม่มี id_school (ใช้ร่วมทุกโรงเรียน) → is_super_admin()
--  ผลต่อแอปวันลา: แอดมินโรงเรียนยังแก้ข้อมูลของโรงเรียนตัวเองได้เหมือนเดิม
--  ที่ถูกปิดคือแก้ข้อมูลโรงเรียนอื่น / ข้อมูลกลาง (เช่น เครื่องมือย้ายข้อมูลจาก Firebase
--  เขียน appconfig / UserRoles / MobilePermissions → ต้องใช้บัญชีส่วนกลาง)
-- ============================================================================

-- 0) ดูก่อนรัน: policy ที่จะถูกเปลี่ยน
select p.tablename, p.policyname, p.cmd, p.qual,
       exists (select 1 from information_schema.columns c
               where c.table_schema = 'public' and c.table_name = p.tablename
                 and c.column_name = 'id_school') as has_id_school
from pg_policies p
where p.schemaname = 'public'
  and p.policyname in ('master_write', 'schools_write')
order by p.tablename;

-- 1) เปลี่ยน
do $$
declare
  p record;
  has_school boolean;
  cond text;
begin
  for p in
    select tablename, policyname from pg_policies
    where schemaname = 'public'
      and policyname in ('master_write', 'schools_write')
      and qual ilike '%is_admin()%'
      and qual not ilike '%school%'
      -- แอปวันลาให้แอดมินโรงเรียนเพิ่ม/ลบรอบปีงบประมาณ และตารางนี้ไม่มี id_school
      -- ปิดแล้วแอปพัง → คงไว้ (ต้องเพิ่ม id_school ในแอปก่อน ซึ่งห้ามแก้แอป)
      and tablename <> 'FiscalRounds'
  loop
    select exists (select 1 from information_schema.columns
                   where table_schema = 'public' and table_name = p.tablename
                     and column_name = 'id_school')
      into has_school;

    cond := case when has_school
                 then 'public.can_manage_school(id_school)'
                 else 'public.is_super_admin()' end;

    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
    execute format('create policy %I on public.%I for all to authenticated '
                   'using (%s) with check (%s)',
                   p.policyname, p.tablename, cond, cond);
    raise notice '% . % → %', p.tablename, p.policyname, cond;
  end loop;
end $$;

-- 2) ตรวจผล: ไม่ควรเหลือ policy เขียนที่เป็น is_admin() เฉยๆ ไม่ผูกโรงเรียน
select tablename, policyname, cmd, qual
from pg_policies
where schemaname = 'public'
  and cmd in ('ALL', 'INSERT', 'UPDATE', 'DELETE')
  and coalesce(qual, with_check) ilike '%is_admin()%'
  and coalesce(qual, with_check) not ilike '%school%'
  and coalesce(qual, with_check) not ilike '%current_teacher_id%'
  and tablename <> 'FiscalRounds'
order by tablename, policyname;
