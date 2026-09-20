/**
 * Edge Function: admin-users
 * ============================================================
 * งานที่ต้องใช้สิทธิ์ระดับแอดมินของ Supabase Auth ซึ่งเรียกจากเว็บตรง ๆ ไม่ได้
 * เพราะต้องใช้ service_role key ที่ห้ามฝังในโค้ดฝั่งผู้ใช้
 *
 *   create_auth    สร้างบัญชี Auth ให้ครูที่มีแถวใน Teachers แล้ว
 *   reset_password ตั้งรหัสผ่านใหม่ให้ครูคนอื่น (กรณีลืมรหัส)
 *
 * ความปลอดภัย: ตรวจ token ของผู้เรียกทุกครั้ง และอนุญาตเฉพาะผู้ที่มีสิทธิ์
 * "ผู้ดูแลระบบ" ในตาราง Teachers เท่านั้น service_role ไม่เคยออกจากเซิร์ฟเวอร์
 *
 * วิธี deploy: ดู supabase/functions/README.md
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

// ต้องตรงกับ FirebaseService.authEmailDomain ในแอป และ tools/create_auth_users.mjs
const EMAIL_DOMAIN = 'leave.local';
const DEFAULT_PASSWORD = '123456';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

const emailFor = (username: string) =>
  `${username.trim().toLowerCase()}@${EMAIL_DOMAIN}`;

/**
 * ตรวจว่ารหัสผ่านที่ผู้เรียกกรอกมาเป็นของตัวเองจริง
 *
 * ใช้ signInWithPassword กับอีเมลของผู้เรียกเอง ถ้าผ่านแปลว่ารู้รหัสจริง
 * ไม่ได้เอา session ที่ได้ไปใช้ต่อ แค่ยืนยันตัวตนเท่านั้น
 */
async function verifyOwnPassword(
  email: string,
  password: string,
): Promise<boolean> {
  const verifier = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await verifier.auth.signInWithPassword({
    email,
    password,
  });
  return !error && !!data.user;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return reply(405, { error: 'รองรับเฉพาะ POST' });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return reply(400, { error: 'รูปแบบข้อมูลไม่ถูกต้อง' });
  }
  const action = String(payload.action ?? '');

  // ═══════════════════════════════════════════════════════════════
  // คำสั่งที่ "ยังไม่ได้ล็อกอิน" ก็เรียกได้ — ใช้กับการกู้รหัสผ่าน
  //
  // ครูที่ลืมรหัสย่อมล็อกอินไม่ได้ จึงตรวจสิทธิ์ด้วยรหัสชั่วคราวที่แอดมิน
  // ออกให้แทน (สุ่ม 6 หลัก + หมดอายุ 24 ชม. + ใช้ได้เมื่อแอดมินกดอนุมัติแล้ว)
  // ═══════════════════════════════════════════════════════════════
  // ครูกดปุ่ม "แจ้งแอดมิน" ตอนลืมรหัส — ยังล็อกอินไม่ได้จึงต้องไม่ต้องยืนยันตัวตน
  // ผลกระทบจำกัดมาก: ทำได้แค่ตั้งสถานะเป็น waiting ให้แอดมินเห็นเท่านั้น
  if (action === 'request_password_reset') {
    const username = String(payload.username ?? '').trim();
    if (!username) return reply(400, { error: 'กรุณากรอกชื่อผู้ใช้ครับ' });

    const { data: row } = await admin
      .from('Teachers')
      .select('id_user, fullName')
      .eq('username', username)
      .maybeSingle();

    if (!row) return reply(404, { error: 'ไม่พบชื่อผู้ใช้งานนี้ในระบบครับ' });

    const { error: updateError } = await admin
      .from('Teachers')
      .update({
        forgotPasswordStatus: 'waiting',
        updated_at: new Date().toISOString(),
      })
      .eq('id_user', row.id_user);

    if (updateError) {
      return reply(500, { error: `ส่งคำขอไม่สำเร็จ: ${updateError.message}` });
    }

    return reply(200, { ok: true, fullName: row.fullName ?? username });
  }

  if (action === 'check_reset_status' || action === 'complete_password_reset') {
    const username = String(payload.username ?? '').trim();
    const code = String(payload.code ?? '').trim();
    if (!username || !code) {
      return reply(400, { error: 'กรุณากรอกชื่อผู้ใช้และรหัสจากแอดมินครับ' });
    }

    const { data: row } = await admin
      .from('Teachers')
      .select(
        'id_user, username, fullName, auth_uid, tempResetCode, resetAllowedUntil, forgotPasswordStatus',
      )
      .eq('username', username)
      .maybeSingle();

    if (!row) {
      return reply(404, { error: 'ไม่พบชื่อผู้ใช้งานนี้ในระบบครับ' });
    }
    if (row.forgotPasswordStatus !== 'reset_by_admin') {
      return reply(403, {
        error:
            'แอดมินยังไม่ได้อนุมัติการกู้รหัสของคุณครับ\nกรุณากด "แจ้งแอดมิน" แล้วรอสักครู่',
      });
    }
    if (!row.resetAllowedUntil ||
        new Date(String(row.resetAllowedUntil)).getTime() < Date.now()) {
      return reply(403, {
        error: 'สิทธิ์การกู้รหัสหมดอายุแล้วครับ กรุณาให้แอดมินเปิดสิทธิ์ใหม่',
      });
    }
    if (String(row.tempResetCode ?? '') !== code) {
      return reply(401, { error: 'รหัสจากแอดมินไม่ถูกต้องครับ' });
    }

    if (action === 'check_reset_status') {
      return reply(200, { ok: true, fullName: row.fullName ?? username });
    }

    // ── ตั้งรหัสผ่านใหม่จริง ──
    const newPassword = String(payload.new_password ?? '').trim();
    if (newPassword.length < 6) {
      return reply(400, { error: 'รหัสผ่านใหม่ต้องยาวอย่างน้อย 6 ตัวครับ' });
    }

    if (row.auth_uid) {
      const { error: updateError } = await admin.auth.admin.updateUserById(
        String(row.auth_uid),
        { password: newPassword },
      );
      if (updateError) {
        return reply(400, {
          error: `ตั้งรหัสผ่านใหม่ไม่สำเร็จ: ${updateError.message}`,
        });
      }
    } else {
      // ยังไม่มีบัญชี Auth (ข้อมูลเก่าที่ตกหล่น) สร้างให้เลย
      const { data: created, error: createError } =
        await admin.auth.admin.createUser({
          email: emailFor(String(row.username)),
          password: newPassword,
          email_confirm: true,
          user_metadata: {
            id_user: row.id_user,
            username: row.username,
            fullName: row.fullName,
          },
        });
      if (createError) {
        return reply(400, {
          error: `สร้างบัญชีเข้าสู่ระบบไม่สำเร็จ: ${createError.message}`,
        });
      }
      await admin
        .from('Teachers')
        .update({ auth_uid: created.user.id })
        .eq('id_user', row.id_user);
    }

    // ล้างสถานะกู้รหัส และซิงก์สำเนารหัสที่แอดมินใช้ดู
    await admin
      .from('Teachers')
      .update({
        password: newPassword,
        forgotPasswordStatus: null,
        resetAllowedUntil: null,
        tempResetCode: null,
        tempPassword: null,
        updated_at: new Date().toISOString(),
      })
      .eq('id_user', row.id_user);

    return reply(200, { ok: true });
  }

  // ── 1. ผู้เรียกเป็นใคร ────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return reply(401, { error: 'กรุณาเข้าสู่ระบบก่อนครับ' });

  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const {
    data: { user: callerUser },
  } = await caller.auth.getUser();
  if (!callerUser) return reply(401, { error: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่' });

  // ── 2. ผู้เรียกเป็นผู้ดูแลระบบหรือไม่ ──────────────────────────
  const { data: me } = await admin
    .from('Teachers')
    .select('id_user, id_role, role, permission, fullName')
    .eq('auth_uid', callerUser.id)
    .maybeSingle();

  if (!me) return reply(403, { error: 'ไม่พบข้อมูลผู้ใช้ของคุณในระบบ' });

  let roleName = String(me.role ?? me.permission ?? '').trim();
  if (!roleName && me.id_role) {
    const { data: roleRow } = await admin
      .from('roles')
      .select('Accessrights')
      .eq('ID_Roles', me.id_role)
      .maybeSingle();
    roleName = String(roleRow?.Accessrights ?? '').trim();
  }

  if (!roleName.includes('ผู้ดูแลระบบ')) {
    return reply(403, { error: 'เฉพาะผู้ดูแลระบบเท่านั้นที่ทำรายการนี้ได้' });
  }

  // ── 3. ลงมือทำตาม action ──────────────────────────────────────
  const targetIdUser = Number(payload.id_user);
  if (!Number.isFinite(targetIdUser)) {
    return reply(400, { error: 'ต้องระบุ id_user ของครูที่ต้องการดำเนินการ' });
  }

  const { data: target } = await admin
    .from('Teachers')
    .select('id_user, username, fullName, auth_uid')
    .eq('id_user', targetIdUser)
    .maybeSingle();

  if (!target) return reply(404, { error: 'ไม่พบครูคนนี้ในระบบ' });

  const username = String(target.username ?? '').trim();
  if (!username) {
    return reply(400, { error: 'ครูคนนี้ยังไม่มีชื่อผู้ใช้ (username)' });
  }

  const password = String(payload.password ?? '').trim() || DEFAULT_PASSWORD;

  if (action === 'create_auth') {
    if (target.auth_uid) {
      return reply(200, {
        ok: true,
        auth_uid: target.auth_uid,
        note: 'มีบัญชีอยู่แล้ว ไม่ได้สร้างซ้ำ',
      });
    }

    const { data: created, error: createError } =
      await admin.auth.admin.createUser({
        email: emailFor(username),
        password,
        email_confirm: true,
        user_metadata: {
          id_user: target.id_user,
          username,
          fullName: target.fullName,
        },
      });

    if (createError) {
      return reply(400, { error: `สร้างบัญชีไม่สำเร็จ: ${createError.message}` });
    }

    const { error: linkError } = await admin
      .from('Teachers')
      .update({ auth_uid: created.user.id })
      .eq('id_user', target.id_user);

    if (linkError) {
      return reply(500, { error: `ผูกบัญชีไม่สำเร็จ: ${linkError.message}` });
    }

    return reply(200, { ok: true, auth_uid: created.user.id });
  }

  if (action === 'reset_password') {
    // ยังไม่มีบัญชี Auth ก็สร้างให้เลยด้วยรหัสใหม่นี้
    if (!target.auth_uid) {
      const { data: created, error: createError } =
        await admin.auth.admin.createUser({
          email: emailFor(username),
          password,
          email_confirm: true,
          user_metadata: {
            id_user: target.id_user,
            username,
            fullName: target.fullName,
          },
        });
      if (createError) {
        return reply(400, {
          error: `สร้างบัญชีไม่สำเร็จ: ${createError.message}`,
        });
      }
      await admin
        .from('Teachers')
        .update({ auth_uid: created.user.id })
        .eq('id_user', target.id_user);
      return reply(200, { ok: true, auth_uid: created.user.id, created: true });
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      String(target.auth_uid),
      { password },
    );

    if (updateError) {
      return reply(400, {
        error: `ตั้งรหัสผ่านใหม่ไม่สำเร็จ: ${updateError.message}`,
      });
    }

    return reply(200, { ok: true, auth_uid: target.auth_uid });
  }

  // ── ดูรหัสผ่านของครู (ยืนยันด้วยรหัสผ่านของแอดมินเอง) ──────────
  //
  // เดิมใช้รหัสยืนยัน 6 หลักส่งเข้าไลน์ แต่แพ็กเกจ LINE จำกัดจำนวนข้อความ
  // ต่อเดือน และต้องแบ่งโควตากับงานหลักคือแจ้งเตือนใบลา จึงเปลี่ยนมายืนยัน
  // ด้วยรหัสผ่านของแอดมินเองแทน ไม่กินโควตาเลย
  if (action === 'view_password') {
    const ownPassword = String(payload.admin_password ?? '');
    if (ownPassword.length === 0) {
      return reply(400, { error: 'กรุณากรอกรหัสผ่านของคุณเพื่อยืนยันตัวตนครับ' });
    }

    const callerEmail = String(callerUser.email ?? '');
    if (!callerEmail) {
      return reply(400, { error: 'บัญชีของคุณไม่มีอีเมลสำหรับยืนยันตัวตน' });
    }

    const verified = await verifyOwnPassword(callerEmail, ownPassword);
    if (!verified) {
      return reply(401, { error: 'รหัสผ่านของคุณไม่ถูกต้องครับ' });
    }

    const { data: secret } = await admin
      .from('Teachers')
      .select('password')
      .eq('id_user', target.id_user)
      .maybeSingle();

    return reply(200, {
      ok: true,
      password: String(secret?.password ?? ''),
      fullName: target.fullName ?? username,
    });
  }

  return reply(400, { error: `ไม่รู้จักคำสั่ง "${action}"` });
});
