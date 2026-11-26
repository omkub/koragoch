/**
 * Edge Function: trial-register
 * ============================================================
 * สมัครบัญชีทดลองใช้ระบบ (โรงเรียนทดลอง) โดยไม่ต้องรอแอดมินอนุมัติ
 * เรียกจากหน้า /register ของ web (central/src/pages/RegisterPage.tsx) โดยยังไม่ล็อกอิน
 *
 * สิ่งที่ทำ (ใช้ service_role ฝั่งเซิร์ฟเวอร์เท่านั้น):
 *   1. โรงเรียนเป้าหมายมาจาก SchoolWebDemoConfig — ไม่รับ id_school จากหน้าเว็บ
 *   2. ตรวจว่าส่วนกลางเปิดรับสมัคร (demo_signup_enabled)
 *   3. จำกัด 5 ครั้ง / ชั่วโมง / IP (SchoolWebDemoSignupAttempts)
 *   4. ชื่อผู้ใช้ต้องขึ้นต้นด้วย demo_ และไม่ซ้ำทั้งระบบ
 *   5. สร้างแถว Teachers (สิทธิ์ "ครู" ของโรงเรียนทดลอง, ไม่ใช่แอดมิน) + บัญชี Auth แล้วผูกกัน
 *   6. สังกัด editor ทั้ง 4 ฝ่าย (Permissions รายบุคคล — แบบเดียวกับหน้า "ฝ่ายและบุคลากร")
 *   7. ผูกคาบสอน 1 วิชา (ทุกห้องของชั้นนั้น) + ห้องที่ปรึกษา 1 ห้อง ที่ยังว่าง → หน้า "งานของฉัน" มีข้อมูล
 *   8. บันทึก SchoolWebDemoAccounts (วันหมดอายุ) · ขั้นใดล้ม ลบที่สร้างไปแล้วทิ้ง
 *
 * deploy (ไม่ตรวจ JWT เพราะผู้สมัครยังไม่ล็อกอิน):
 *   npx supabase functions deploy trial-register --no-verify-jwt --project-ref uziajblqlbrvqmxvizsi
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// ต้องตรงกับ authEmailForUsername ใน central/src/supabase.ts
const EMAIL_DOMAIN = 'leave.local';
const ADMIN_ROLE_ID = 22; // ใช้เป็น "ช่อง" เก็บสิทธิ์รายบุคคลใน Permissions (เหมือน web)
const USERNAME_PREFIX = 'demo_';
const MAX_ATTEMPTS_PER_HOUR = 5;

// ช่อง menu_id รายบุคคล (ตรงกับ USER_DIVISION_SLOT ใน roleModulePermissions.ts)
const DIVISION_SLOT: Record<string, number> = { hr: 41, academic: 42, admin: 43, finance: 44 };

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return reply(405, { error: 'method not allowed' });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch {
    return reply(400, { error: 'ข้อมูลไม่ถูกต้อง' });
  }

  // ── 1-2. โรงเรียนทดลอง + เปิดรับสมัครหรือยัง ──────────────────────
  const { data: demo } = await admin
    .from('SchoolWebDemoConfig')
    .select('id_school, demo_signup_enabled, account_ttl_days, trial_role_id')
    .order('id_school')
    .limit(1)
    .maybeSingle();
  if (!demo || !demo.trial_role_id) {
    return reply(503, { error: 'ยังไม่ได้ตั้งค่าโรงเรียนทดลอง' });
  }
  if (!demo.demo_signup_enabled) {
    return reply(403, { error: 'ปิดรับสมัครทดลองใช้ชั่วคราว' });
  }
  const idSchool = Number(demo.id_school);
  const roleId = Number(demo.trial_role_id);
  if (roleId === ADMIN_ROLE_ID) {
    return reply(500, { error: 'ตั้งค่าสิทธิ์ทดลองผิด (เป็นสิทธิ์แอดมิน)' });
  }

  // ── 3. จำกัดความถี่ต่อ IP ─────────────────────────────────────────
  const ip =
    (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim() ||
    req.headers.get('cf-connecting-ip') ||
    'unknown';
  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await admin
    .from('SchoolWebDemoSignupAttempts')
    .select('id', { count: 'exact', head: true })
    .eq('ip', ip)
    .gte('attempted_at', since);
  if ((count ?? 0) >= MAX_ATTEMPTS_PER_HOUR) {
    return reply(429, { error: 'สมัครบ่อยเกินไป กรุณารอ 1 ชั่วโมงแล้วลองใหม่' });
  }
  await admin.from('SchoolWebDemoSignupAttempts').insert({ ip });
  await admin
    .from('SchoolWebDemoSignupAttempts')
    .delete()
    .lt('attempted_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

  // ── 4. ตรวจข้อมูลที่กรอก ─────────────────────────────────────────
  const rawName = String(payload.username ?? '').trim().toLowerCase();
  const username = rawName.startsWith(USERNAME_PREFIX) ? rawName : USERNAME_PREFIX + rawName;
  const fullName = String(payload.fullName ?? '').trim();
  const password = String(payload.password ?? '');

  if (!/^demo_[a-z0-9._-]{3,30}$/.test(username)) {
    return reply(400, { error: 'ชื่อผู้ใช้ใช้ได้เฉพาะ a-z 0-9 . _ - ยาว 3–30 ตัว' });
  }
  if (fullName.length < 2 || fullName.length > 100) {
    return reply(400, { error: 'กรุณากรอกชื่อ-นามสกุล' });
  }
  if (password.length < 8 || password.length > 72) {
    return reply(400, { error: 'รหัสผ่านต้องยาว 8–72 ตัว' });
  }

  const { data: dup } = await admin
    .from('Teachers')
    .select('id_user')
    .ilike('username', username)
    .limit(1);
  if (dup && dup.length > 0) {
    return reply(409, { error: `ชื่อผู้ใช้ "${username}" ถูกใช้แล้ว กรุณาเลือกชื่ออื่น` });
  }

  // ── 5. สร้าง Teachers + Auth ────────────────────────────────────
  const nowIso = new Date().toISOString();
  const { data: inserted, error: insertError } = await admin
    .from('Teachers')
    .insert({
      username,
      fullName,
      id_role: roleId,
      id_school: idSchool,
      is_super_admin: false,
      password, // trigger ย้ายไป TeacherPasswords ให้เอง (เหมือน create_school_admin)
      created_at: nowIso,
      updated_at: nowIso,
    })
    .select('id_user')
    .single();
  if (insertError || !inserted) {
    return reply(400, { error: `สมัครไม่สำเร็จ: ${insertError?.message ?? ''}` });
  }
  const idUser = Number(inserted.id_user);

  const rollback = async (authUid?: string) => {
    await admin.from('Permissions').delete().eq('id_school', idSchool).eq('id_role', ADMIN_ROLE_ID)
      .lte('menu_id', -(100000 + idUser * 100)).gte('menu_id', -(100000 + idUser * 100 + 99));
    await admin.from('SchoolWebTeachingSchedules').update({ teacher_id: null })
      .eq('id_school', idSchool).eq('teacher_id', idUser);
    await admin.from('SchoolWebClassrooms').update({ advisor_teacher_id: null })
      .eq('id_school', idSchool).eq('advisor_teacher_id', idUser);
    await admin.from('SchoolWebDemoAccounts').delete().eq('id_user', idUser);
    await admin.from('Teachers').delete().eq('id_user', idUser);
    if (authUid) await admin.auth.admin.deleteUser(authUid);
  };

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: `${username}@${EMAIL_DOMAIN}`,
    password,
    email_confirm: true,
    user_metadata: { id_user: idUser, username, fullName, demo: true },
  });
  if (createError || !created?.user) {
    await rollback();
    return reply(400, { error: `สร้างบัญชีไม่สำเร็จ: ${createError?.message ?? ''}` });
  }
  const authUid = created.user.id;

  try {
    const { error: linkError } = await admin
      .from('Teachers')
      .update({ auth_uid: authUid })
      .eq('id_user', idUser);
    if (linkError) throw linkError;

    // ── 6. editor ทั้ง 4 ฝ่าย ──────────────────────────────────────
    const permRows = Object.values(DIVISION_SLOT).flatMap((slot) => [
      { id_school: idSchool, id_role: ADMIN_ROLE_ID, menu_id: -(100000 + idUser * 100 + slot), status: '1', updatedAt: nowIso },
      { id_school: idSchool, id_role: ADMIN_ROLE_ID, menu_id: -(100000 + idUser * 100 + 10 + slot), status: '1', updatedAt: nowIso },
    ]);
    const { error: permError } = await admin
      .from('Permissions')
      .upsert(permRows, { onConflict: 'id_school,id_role,menu_id' });
    if (permError) throw permError;

    // ── 7. คาบสอน + ห้องที่ปรึกษาตัวอย่าง (ถ้ายังมีว่าง) ────────────────
    const { data: freeSlot } = await admin
      .from('SchoolWebTeachingSchedules')
      .select('subject_id, classroom_id')
      .eq('id_school', idSchool)
      .is('teacher_id', null)
      .limit(1)
      .maybeSingle();
    if (freeSlot) {
      const { data: room } = await admin
        .from('SchoolWebClassrooms')
        .select('grade_level')
        .eq('id', freeSlot.classroom_id)
        .maybeSingle();
      const { data: sameGrade } = await admin
        .from('SchoolWebClassrooms')
        .select('id')
        .eq('id_school', idSchool)
        .eq('grade_level', room?.grade_level ?? '');
      const roomIds = (sameGrade ?? []).map((r: { id: number }) => r.id);
      if (roomIds.length > 0) {
        await admin
          .from('SchoolWebTeachingSchedules')
          .update({ teacher_id: idUser })
          .eq('id_school', idSchool)
          .eq('subject_id', freeSlot.subject_id)
          .in('classroom_id', roomIds)
          .is('teacher_id', null);
      }
    }
    const { data: freeRoom } = await admin
      .from('SchoolWebClassrooms')
      .select('id')
      .eq('id_school', idSchool)
      .is('advisor_teacher_id', null)
      .order('id')
      .limit(1)
      .maybeSingle();
    if (freeRoom) {
      await admin
        .from('SchoolWebClassrooms')
        .update({ advisor_teacher_id: idUser })
        .eq('id', freeRoom.id)
        .is('advisor_teacher_id', null);
    }

    // ── 8. บันทึกบัญชีทดลอง + วันหมดอายุ ───────────────────────────
    const ttlDays = Number(demo.account_ttl_days) || 7;
    const expiresAt = new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000).toISOString();
    const { error: accError } = await admin.from('SchoolWebDemoAccounts').insert({
      id_user: idUser,
      id_school: idSchool,
      auth_uid: authUid,
      username,
      expires_at: expiresAt,
    });
    if (accError) throw accError;

    return reply(200, { ok: true, username, expires_at: expiresAt });
  } catch (e) {
    await rollback(authUid);
    const msg = e instanceof Error ? e.message : String((e as { message?: string })?.message ?? e);
    return reply(500, { error: `สมัครไม่สำเร็จ: ${msg}` });
  }
});
