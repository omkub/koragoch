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

/** รหัสยืนยัน 6 หลัก สุ่มด้วยตัวสุ่มเชิงรหัสลับ ไม่ใช่เวลาปัจจุบัน */
function generateCode(): string {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return String((buf[0] % 900000) + 100000);
}

/**
 * รวมค่าจากตาราง Settings — ข้อมูลกระจายอยู่หลายแถว ต้องหยิบค่าที่ไม่ว่าง
 * จากทุกแถวมารวมกัน (ตรรกะเดียวกับ ensureConfigLoaded ในแอป)
 */
async function loadSettings(
  // deno-lint-ignore no-explicit-any
  admin: any,
): Promise<Record<string, string>> {
  const { data } = await admin.from('Settings').select('*');
  const merged: Record<string, string> = {};
  for (const row of data ?? []) {
    for (const [key, value] of Object.entries(row ?? {})) {
      if (value === null || value === undefined) continue;
      const text = String(value).trim();
      if (text && !merged[key]) merged[key] = text;
    }
  }
  return merged;
}

/**
 * ส่งข้อความเข้ากลุ่มไลน์ผ่าน Apps Script bridge
 * ใช้เส้นทางเดียวกับการแจ้งเตือนใบลา (action=line_notification)
 * จะได้ใช้ secretKey / กลุ่ม / สคริปต์ชุดเดียวกันทั้งระบบ
 */
async function pushLine(
  settings: Record<string, string>,
  message: string,
): Promise<string | null> {
  const bridgeUrl = settings['appsScriptUrl'] ?? '';
  const secretKey = settings['secretKey'] ?? '';
  const to = settings['groupId'] ?? '';

  if (!bridgeUrl) return 'ยังไม่ได้ตั้งค่า appsScriptUrl ในหน้าตั้งค่า LINE';
  if (!to) return 'ยังไม่ได้ตั้งค่ากลุ่มไลน์ (groupId)';

  const url = new URL(bridgeUrl);
  url.searchParams.set('action', 'line_notification');
  url.searchParams.set('secretKey', secretKey);
  url.searchParams.set('to', to);
  url.searchParams.set('message', message);

  try {
    const res = await fetch(url.toString(), { method: 'GET' });
    const text = await res.text();
    if (!res.ok) return `ส่งไลน์ไม่สำเร็จ (HTTP ${res.status})`;
    // Apps Script ตอบ JSON {status: success|error}
    try {
      const parsed = JSON.parse(text);
      if (parsed.status && parsed.status !== 'success') {
        return `ส่งไลน์ไม่สำเร็จ: ${parsed.message ?? parsed.status}`;
      }
    } catch {
      // ตอบกลับไม่ใช่ JSON ถือว่าผ่านถ้า HTTP 200
    }
    return null;
  } catch (e) {
    return `เชื่อมต่อระบบส่งไลน์ไม่ได้: ${e}`;
  }
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
  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return reply(400, { error: 'รูปแบบข้อมูลไม่ถูกต้อง' });
  }

  const action = String(payload.action ?? '');
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

  // ── ขอรหัสยืนยันก่อนดูรหัสผ่านของครู (2FA ผ่านไลน์) ──────────
  if (action === 'request_view_code') {
    // 🛡️ กันยิงรัว: ถ้าเพิ่งขอรหัสสำหรับครูคนนี้ไปไม่ถึง 60 วินาที ให้ใช้ของเดิม
    // ไม่ส่งไลน์ซ้ำ ป้องกันบั๊กฝั่งหน้าจอเผาโควตาข้อความของโรงเรียน
    const recentCutoff = new Date(Date.now() - 60 * 1000).toISOString();
    const { data: recent } = await admin
      .from('AdminViewCodes')
      .select('id_code, created_at')
      .eq('requested_by', callerUser.id)
      .eq('target_id_user', target.id_user)
      .is('used_at', null)
      .gte('created_at', recentCutoff)
      .limit(1)
      .maybeSingle();

    if (recent) {
      return reply(200, {
        ok: true,
        sent: false,
        note: 'เพิ่งส่งรหัสไปเมื่อสักครู่ กรุณาตรวจในกลุ่มไลน์',
      });
    }

    const settings = await loadSettings(admin);
    const code = generateCode();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 นาที

    const { error: insertError } = await admin.from('AdminViewCodes').insert({
      code,
      requested_by: callerUser.id,
      target_id_user: target.id_user,
      expires_at: expiresAt.toISOString(),
    });
    if (insertError) {
      return reply(500, { error: `บันทึกรหัสยืนยันไม่สำเร็จ: ${insertError.message}` });
    }

    const adminName = String(me.fullName ?? '').trim() || 'ผู้ดูแลระบบ';
    const lineError = await pushLine(
      settings,
      '🔐 คำขอดูรหัสผ่าน\n' +
        `ผู้ขอ: ${adminName}\n` +
        `ต้องการดูรหัสผ่านของ: ${target.fullName ?? username}\n` +
        `รหัสยืนยัน: ${code}\n` +
        'ใช้ได้ครั้งเดียว หมดอายุใน 5 นาที\n' +
        'ถ้าไม่ได้เป็นคนขอเอง แจ้งผู้ดูแลระบบทันที',
    );

    if (lineError) return reply(502, { error: lineError });

    return reply(200, { ok: true, sent: true });
  }

  // ── ตรวจรหัสยืนยันแล้วคืนรหัสผ่านของครู ───────────────────────
  if (action === 'verify_view_code') {
    const code = String(payload.code ?? '').trim();
    if (code.length === 0) {
      return reply(400, { error: 'กรุณากรอกรหัสยืนยันครับ' });
    }

    const { data: row } = await admin
      .from('AdminViewCodes')
      .select('id_code, expires_at, used_at')
      .eq('code', code)
      .eq('requested_by', callerUser.id)
      .eq('target_id_user', target.id_user)
      .is('used_at', null)
      .order('id_code', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!row) return reply(400, { error: 'รหัสยืนยันไม่ถูกต้องครับ' });

    if (new Date(row.expires_at).getTime() < Date.now()) {
      return reply(400, { error: 'รหัสยืนยันหมดอายุแล้ว กรุณาขอรหัสใหม่' });
    }

    await admin
      .from('AdminViewCodes')
      .update({ used_at: new Date().toISOString() })
      .eq('id_code', row.id_code);

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
