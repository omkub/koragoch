-- ============================================================================
--  ตั้งโฟลเดอร์เก็บโลโก้โรงเรียนใน Google Drive (LogoRPB) — ไม่ต้องแก้ Apps Script
--
--  1) เปิด Google Drive ด้วยบัญชีเดียวกับที่เก็บใบรับรองแพทย์ / รูปโปรไฟล์
--  2) สร้างโฟลเดอร์ชื่อ LogoRPB (ไว้ที่ไหนก็ได้ แนะนำข้างโฟลเดอร์รูปโปรไฟล์)
--  3) เปิดโฟลเดอร์นั้น → คัดลอกรหัสท้ายลิงก์
--       https://drive.google.com/drive/folders/<<รหัสโฟลเดอร์>>
--  4) วางรหัสแทน <<รหัสโฟลเดอร์>> ด้านล่าง แล้ว Run
--
--  รันซ้ำได้ (เปลี่ยนโฟลเดอร์ = รันใหม่ด้วยรหัสใหม่)
--  ต้องรัน settings_secrets.sql มาก่อนแล้ว (ตาราง AppSecrets)
-- ============================================================================

insert into public."AppSecrets"(key, value)
values ('driveLogoFolderId', '<<รหัสโฟลเดอร์>>')
on conflict (key) do update set value = excluded.value, "updatedAt" = now();

-- ตรวจผล — ต้องไม่ใช่ <<รหัสโฟลเดอร์>>
select key, value from public."AppSecrets" where key = 'driveLogoFolderId';
