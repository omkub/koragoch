-- ============================================================================
--  แอดมินโรงเรียนตั้งค่าระบบวันลาของ "โรงเรียนตัวเอง" ได้ (หน้า ② ตั้งค่าโรงเรียน ใน web)
--
--  ต้องรันก่อนแล้ว: line_per_school.sql, form_templates.sql, attendance.sql,
--                   school_web_security_fix1.sql (ใช้ public.can_manage_school)
--  รันซ้ำได้ (Idempotent) · ไม่แก้ข้อมูล · ไม่กระทบแอปวันลา (เปิดสิทธิ์เพิ่มให้แอดมินโรงเรียนเท่านั้น)
--
--  เดิมเขียนได้เฉพาะผู้ดูแลส่วนกลาง (is_super_admin) — หลังรัน:
--    can_manage_school(id_school) = ผู้ดูแลส่วนกลาง หรือ แอดมิน (id_role 22) ของโรงเรียนนั้น
--
--    SchoolLineSettings  : กลุ่ม LINE ของโรงเรียน
--    FormTemplates       : แม่แบบใบลา/ใบไปราชการของโรงเรียน (id_school ไม่ว่าง)
--                          แม่แบบกลาง (id_school ว่าง) ยังเป็นของส่วนกลางเท่านั้น
--    AttendanceSettings  : ตั้งค่าลงเวลาของโรงเรียน
--    AttendanceDevices   : เครื่องสแกนของโรงเรียน
--
--  ไม่ต้องแก้: สถานะบุคลากร (Teachers — แอดมินแก้ได้อยู่แล้ว),
--              ตำแหน่งบริหาร (assign_admin_position ตรวจ is_admin + โรงเรียนเดียวกันอยู่แล้ว)
--  ยังเฉพาะส่วนกลาง: ปุ่ม "ทดลองส่ง" LINE / สรุปลงเวลา (ตรวจใน Edge Function)
--                    และสะพานเชื่อมกลาง (Settings.webhookUrl — ใช้ร่วมทุกโรงเรียน)
-- ============================================================================

-- SchoolLineSettings
drop policy if exists school_line_super on "SchoolLineSettings";
drop policy if exists school_line_manage on "SchoolLineSettings";
create policy school_line_manage on "SchoolLineSettings"
  for all to authenticated
  using (public.can_manage_school(id_school))
  with check (public.can_manage_school(id_school));

-- FormTemplates: แม่แบบของโรงเรียน → แอดมินโรงเรียนนั้น · แม่แบบกลาง → ส่วนกลาง
drop policy if exists form_templates_insert on "FormTemplates";
create policy form_templates_insert on "FormTemplates"
  for insert to authenticated
  with check (
    public.is_super_admin()
    or (id_school is not null and public.can_manage_school(id_school))
  );

drop policy if exists form_templates_delete on "FormTemplates";
create policy form_templates_delete on "FormTemplates"
  for delete to authenticated
  using (
    public.is_super_admin()
    or (id_school is not null and public.can_manage_school(id_school))
  );

-- AttendanceSettings
drop policy if exists attendance_settings_write on "AttendanceSettings";
create policy attendance_settings_write on "AttendanceSettings"
  for all to authenticated
  using (public.can_manage_school(id_school))
  with check (public.can_manage_school(id_school));

-- AttendanceDevices
drop policy if exists attendance_devices_write on "AttendanceDevices";
create policy attendance_devices_write on "AttendanceDevices"
  for all to authenticated
  using (public.can_manage_school(id_school))
  with check (public.can_manage_school(id_school));

-- ตรวจผล
select tablename, policyname, cmd
from pg_policies
where tablename in ('SchoolLineSettings', 'FormTemplates', 'AttendanceSettings', 'AttendanceDevices')
order by tablename, policyname;
