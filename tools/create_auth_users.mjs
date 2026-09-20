/**
 * สร้างบัญชี Supabase Auth ให้ครูทุกคนจากตาราง Teachers
 * ============================================================
 * ใช้ครั้งเดียวตอนย้ายระบบล็อกอินไปใช้ Supabase Auth (พาร์ท E ขั้นที่ 2)
 * และใช้ซ้ำได้เมื่อมีครูใหม่ที่ยังไม่มีบัญชี Auth
 *
 * วิธีใช้ (รันในโฟลเดอร์โปรเจกต์)
 * ------------------------------------------------------------
 *   npm install @supabase/supabase-js
 *
 *   # 1) ทดลองก่อน — สร้างบัญชีทดสอบ 1 ใบแล้วลบทิ้ง ไม่แตะข้อมูลจริง
 *   $env:SUPABASE_SERVICE_KEY="<service_role key จากแดชบอร์ด>"
 *   node tools/create_auth_users.mjs
 *
 *   # 2) ถ้าผ่าน ค่อยสั่งทำจริง
 *   node tools/create_auth_users.mjs --apply
 *
 * หา service_role key ได้ที่
 *   Supabase Dashboard > Project Settings > API > service_role (secret)
 * ⚠️ ห้ามใส่ key ลงในโค้ดหรือ commit ขึ้น Git เด็ดขาด ใช้ผ่าน env เท่านั้น
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://uziajblqlbrvqmxvizsi.supabase.co';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

// โดเมนอีเมลสังเคราะห์ — ครูไม่เห็นและไม่ต้องใช้ เป็นแค่ตัวระบุตัวตนให้ Auth
// ถ้า Supabase ปฏิเสธโดเมนนี้ ให้เปลี่ยนผ่าน env: $env:AUTH_EMAIL_DOMAIN="..."
const EMAIL_DOMAIN = process.env.AUTH_EMAIL_DOMAIN || 'leave.local';

const DEFAULT_PASSWORD = '123456';
const APPLY = process.argv.includes('--apply');

if (!SERVICE_KEY) {
  console.error('❌ ไม่พบ SUPABASE_SERVICE_KEY');
  console.error('   ตั้งค่าก่อน:  $env:SUPABASE_SERVICE_KEY="<service_role key>"');
  process.exit(1);
}

const db = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const emailFor = (username) =>
  `${String(username).trim().toLowerCase()}@${EMAIL_DOMAIN}`;

/** ทดลองสร้าง+ลบบัญชีทดสอบ เพื่อดูว่าโดเมนอีเมลใช้ได้จริงไหมก่อนลงมือ */
async function preflight() {
  const probeEmail = `__probe_${Date.now()}@${EMAIL_DOMAIN}`;
  const { data, error } = await db.auth.admin.createUser({
    email: probeEmail,
    password: 'Probe!23456',
    email_confirm: true,
  });

  if (error) {
    console.error(`❌ สร้างบัญชีทดสอบไม่สำเร็จ: ${error.message}`);
    console.error(`   โดเมน "${EMAIL_DOMAIN}" อาจใช้ไม่ได้`);
    console.error('   ลองเปลี่ยน:  $env:AUTH_EMAIL_DOMAIN="leave.internal"');
    return false;
  }

  await db.auth.admin.deleteUser(data.user.id);
  console.log(`✅ โดเมน "${EMAIL_DOMAIN}" ใช้ได้ (สร้างบัญชีทดสอบแล้วลบทิ้งเรียบร้อย)`);
  return true;
}

async function main() {
  console.log(APPLY ? '🚀 โหมดทำจริง (--apply)' : '🔍 โหมดทดลอง (ยังไม่แตะข้อมูลจริง)');
  console.log(`   โดเมนอีเมล: @${EMAIL_DOMAIN}\n`);

  if (!(await preflight())) process.exit(1);

  const { data: teachers, error } = await db
    .from('Teachers')
    .select('id_user, username, fullName, password, auth_uid')
    .order('id_user');

  if (error) throw new Error(`อ่านตาราง Teachers ไม่สำเร็จ: ${error.message}`);

  const todo = teachers.filter(
    (t) => !t.auth_uid && String(t.username ?? '').trim() !== '',
  );
  const noUsername = teachers.filter(
    (t) => String(t.username ?? '').trim() === '',
  );

  console.log(`ครูทั้งหมด         : ${teachers.length} คน`);
  console.log(`มีบัญชี Auth แล้ว  : ${teachers.length - todo.length - noUsername.length} คน`);
  console.log(`ไม่มี username     : ${noUsername.length} คน (ข้าม)`);
  console.log(`ต้องสร้างบัญชี     : ${todo.length} คน\n`);

  if (!APPLY) {
    console.log('ตัวอย่าง 5 รายแรกที่จะถูกสร้าง:');
    for (const t of todo.slice(0, 5)) {
      console.log(`   ${t.username} -> ${emailFor(t.username)}  (รหัส: ${t.password || DEFAULT_PASSWORD})`);
    }
    console.log('\nยังไม่ได้สร้างอะไรทั้งนั้น — สั่งทำจริงด้วย:  node tools/create_auth_users.mjs --apply');
    return;
  }

  let created = 0;
  const failed = [];

  for (const t of todo) {
    const email = emailFor(t.username);
    const password = String(t.password ?? '').trim() || DEFAULT_PASSWORD;

    const { data, error: createError } = await db.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // ไม่มีอีเมลจริง จึงยืนยันให้เลย ไม่ต้องส่งเมล
      user_metadata: {
        id_user: t.id_user,
        username: t.username,
        fullName: t.fullName,
      },
    });

    if (createError) {
      failed.push({ username: t.username, reason: createError.message });
      continue;
    }

    // ผูก auth_uid กลับเข้าตาราง Teachers เพื่อให้ RLS อ้างอิงได้
    const { error: linkError } = await db
      .from('Teachers')
      .update({ auth_uid: data.user.id })
      .eq('id_user', t.id_user);

    if (linkError) {
      failed.push({ username: t.username, reason: `ผูก auth_uid ไม่สำเร็จ: ${linkError.message}` });
      continue;
    }

    created += 1;
    process.stdout.write(`\r   สร้างแล้ว ${created}/${todo.length} ...`);
  }

  console.log(`\n\n✅ สร้างบัญชีสำเร็จ ${created} คน`);
  if (failed.length) {
    console.log(`⚠️  ไม่สำเร็จ ${failed.length} คน:`);
    for (const f of failed) console.log(`   - ${f.username}: ${f.reason}`);
  }
}

main().catch((e) => {
  console.error('\n❌ เกิดข้อผิดพลาด:', e.message);
  process.exit(1);
});
