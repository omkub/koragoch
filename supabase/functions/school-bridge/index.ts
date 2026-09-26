/**
 * Edge Function: school-bridge
 * ============================================================
 * ตัวกลางระหว่างแอปกับ Google Apps Script (สะพาน LINE / Google Drive)
 *
 * ทำไมต้องมี (ความปลอดภัยข้อ 2):
 *   เดิมแอปเรียก Apps Script ตรง ๆ โดยแนบ secretKey ที่อ่านมาจากตาราง Settings
 *   ครูทุกคนที่ล็อกอินจึงอ่าน secretKey ได้ และเอาไปยิง Apps Script เองได้
 *   → ส่งข้อความ LINE อะไรก็ได้ (กินโควตาจนหมดเดือน) / อัป-ลบไฟล์ใน Drive
 *   ตอนนี้ secretKey อยู่ฝั่งเซิร์ฟเวอร์เท่านั้น (ตาราง AppSecrets) และฟังก์ชันนี้
 *   ตรวจสิทธิ์ก่อนทุกครั้ง
 *
 *   notify_new_leave  แจ้ง LINE ว่ามีใบลาใหม่ — ข้อความประกอบจากข้อมูลในฐานข้อมูล
 *                     (ไม่รับข้อความจากแอป) และส่งได้ครั้งเดียวต่อใบ
 *   line_test         ส่งข้อความทดสอบ (ผู้ดูแลระบบ)
 *   line_latest_id    ดึงไอดีกลุ่ม LINE ล่าสุด (ผู้ดูแลระบบ)
 *   drive_upload      อัปโหลดไฟล์ (โฟลเดอร์กำหนดฝั่งเซิร์ฟเวอร์)
 *   drive_delete      ลบไฟล์ — ผู้ดูแลระบบ หรือคนที่อัปโหลดไฟล์นั้นเอง
 *
 * วิธี deploy:
 *   npx supabase functions deploy school-bridge --project-ref uziajblqlbrvqmxvizsi
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

// roles.ID_Roles ของ "ผู้ดูแลระบบ" — ต้องตรงกับ is_admin() ใน admin_role_by_id.sql
const ADMIN_ROLE_ID = 22;

// ไฟล์ใหญ่สุดที่รับ (base64 ~ 1.37 เท่าของไฟล์จริง) กันคนยิงไฟล์ยักษ์ใส่ Drive
const MAX_FILE64_LENGTH = 14 * 1024 * 1024;

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

const MONTHS_TH = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

/** '2026-09-27' → '27 กันยายน 2569' */
function thaiDate(value: unknown): string {
  const text = String(value ?? '').trim();
  const m = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return text || '-';
  return `${Number(m[3])} ${MONTHS_TH[Number(m[2]) - 1]} ${Number(m[1]) + 543}`;
}

// deno-lint-ignore no-explicit-any
type Db = any;

/**
 * ค่าตั้งค่าของสะพาน: Settings (หลายแถว รวมค่าที่ไม่ว่าง) + AppSecrets
 * ถ้ายังไม่ได้รัน settings_secrets.sql secretKey จะยังอยู่ใน Settings — ใช้ได้เหมือนกัน
 */
async function loadConfig(admin: Db): Promise<Record<string, string>> {
  const merged: Record<string, string> = {};
  const { data: rows } = await admin.from('Settings').select('*');
  for (const row of rows ?? []) {
    for (const [k, v] of Object.entries(row)) {
      if (v !== null && v !== '' && typeof v !== 'object') merged[k] = String(v);
    }
  }
  const { data: secrets, error } = await admin.from('AppSecrets').select('key, value');
  if (!error) {
    for (const s of secrets ?? []) {
      if (s.value) merged[s.key] = String(s.value);
    }
  }
  return merged;
}

function bridgeUrlOf(config: Record<string, string>): string {
  const isWebApp = (u: string) =>
    /^https:\/\/script\.google\.com\/macros\/s\/[^\s/]+\/exec$/.test(u.trim());
  const saved = (config.webhookUrl ?? '').trim();
  if (isWebApp(saved)) return saved;
  const fallback = (config.appsScriptUrl ?? '').trim();
  if (isWebApp(fallback)) return fallback;
  throw new Error('ยังไม่ได้ตั้งค่า URL ของ Apps Script ในหน้าตั้งค่า LINE');
}

/** Apps Script ตอบกลับเป็น JSON (บางครั้งห่อด้วย callback) */
async function readBridgeJson(res: Response): Promise<Record<string, unknown>> {
  const text = await res.text();
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1) {
    return { status: 'error', message: `Apps Script ตอบกลับผิดรูปแบบ (${res.status})` };
  }
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return { status: 'error', message: 'Apps Script ตอบกลับผิดรูปแบบ' };
  }
}

async function bridgeGet(config: Record<string, string>, params: Record<string, string>) {
  const url = new URL(bridgeUrlOf(config));
  for (const [k, v] of Object.entries({ ...params, secretKey: config.secretKey ?? '' })) {
    url.searchParams.set(k, v);
  }
  return readBridgeJson(await fetch(url.toString(), { redirect: 'follow' }));
}

async function bridgePost(config: Record<string, string>, body: Record<string, unknown>) {
  const res = await fetch(bridgeUrlOf(config), {
    method: 'POST',
    redirect: 'follow',
    body: JSON.stringify({ ...body, secretKey: config.secretKey ?? '' }),
  });
  return readBridgeJson(res);
}

function driveFileIdOf(value: string): string | null {
  const source = value.trim();
  if (/^[a-zA-Z0-9_-]{20,}$/.test(source)) return source;
  const m = source.match(/\/d\/([a-zA-Z0-9_-]{20,})/) ??
    source.match(/[?&]id=([a-zA-Z0-9_-]{20,})/);
  return m ? m[1] : null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return reply(405, { error: 'รองรับเฉพาะ POST' });

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return reply(400, { error: 'รูปแบบข้อมูลไม่ถูกต้อง' });
  }
  const action = String(payload.action ?? '');

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ── ผู้เรียกเป็นใคร ────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return reply(401, { error: 'กรุณาเข้าสู่ระบบก่อนครับ' });
  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user } } = await caller.auth.getUser();
  if (!user) return reply(401, { error: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่' });

  const { data: me } = await admin
    .from('Teachers')
    .select('id_user, id_role, id_school, is_super_admin')
    .eq('auth_uid', user.id)
    .maybeSingle();
  if (!me) return reply(403, { error: 'ไม่พบข้อมูลผู้ใช้ของคุณในระบบ' });

  const isAdmin = Number(me.id_role) === ADMIN_ROLE_ID;
  const isSuper = isAdmin && me.is_super_admin === true;

  let config: Record<string, string>;
  try {
    config = await loadConfig(admin);
  } catch (e) {
    return reply(500, { error: `อ่านค่าตั้งค่าไม่สำเร็จ: ${e}` });
  }

  try {
    // ── แจ้งใบลาใหม่ ──────────────────────────────────────────────
    if (action === 'notify_new_leave') {
      const idLeaves = Number(payload.id_leaves);
      if (!Number.isFinite(idLeaves)) return reply(400, { error: 'ต้องระบุ id_leaves' });

      const { data: leave } = await admin
        .from('Leaves')
        .select('*')
        .eq('id_leaves', idLeaves)
        .maybeSingle();
      if (!leave) return reply(404, { error: 'ไม่พบใบลา' });

      const own = leave.id_user === me.id_user;
      const sameSchool = isSuper || leave.id_school === me.id_school;
      if (!(own || (isAdmin && sameSchool))) {
        return reply(403, { error: 'ไม่มีสิทธิ์แจ้งเตือนใบลานี้' });
      }

      // ส่งได้ครั้งเดียวต่อใบ — เคยมีบั๊กยิงซ้ำ 60 ข้อความจนโควตาหมดเดือน
      const { error: dupError } = await admin
        .from('LineNotifyLog')
        .insert({ id_leaves: idLeaves, kind: 'new_leave' });
      if (dupError) {
        if (String(dupError.code) === '23505') {
          return reply(200, { ok: true, skipped: 'แจ้งเตือนใบนี้ไปแล้ว' });
        }
        throw new Error(`บันทึกประวัติแจ้งเตือนไม่สำเร็จ: ${dupError.message}`);
      }

      const to = (config.groupId ?? '').trim();
      if (!to) return reply(200, { ok: false, skipped: 'ยังไม่ได้ตั้งค่า Group ID' });

      const [{ data: teacher }, { data: leaveType }] = await Promise.all([
        admin.from('Teachers').select('fullName').eq('id_user', leave.id_user).maybeSingle(),
        admin.from('LeaveTypes').select('leaveName').eq('id_leaveType', leave.id_leaveType).maybeSingle(),
      ]);

      const fields: Record<string, string> = {
        '{name}': String(teacher?.fullName ?? '-'),
        '{type}': String(leaveType?.leaveName ?? '-'),
        '{startDate}': thaiDate(leave.startDate),
        '{endDate}': thaiDate(leave.endDate),
        '{days}': String(leave.totalDays ?? '-'),
        '{reason}': String(leave.reason ?? '-'),
      };
      let message = (config.template ?? '').trim() ||
        '📋 มีการยื่นใบลาใหม่\n👤 ชื่อ: {name}\n📅 ประเภทลา: {type}\n' +
          '🗓️ ตั้งแต่: {startDate}\n🗓️ ถึง: {endDate}\n📆 จำนวน: {days} วัน\n✍️ เหตุผล: {reason}';
      for (const [k, v] of Object.entries(fields)) message = message.split(k).join(v);

      const result = await bridgeGet(config, { action: 'line_notification', to, message });
      if (result.status !== 'success') {
        // ส่งไม่ผ่าน ลบประวัติออก จะได้ลองใหม่ได้
        await admin.from('LineNotifyLog').delete()
          .eq('id_leaves', idLeaves).eq('kind', 'new_leave');
        return reply(502, { error: String(result.message ?? 'ส่ง LINE ไม่สำเร็จ') });
      }
      return reply(200, { ok: true });
    }

    // ── อัปโหลดไฟล์ ────────────────────────────────────────────────
    if (action === 'drive_upload') {
      const file64 = String(payload.file64 ?? '');
      if (!file64) return reply(400, { error: 'ไม่มีไฟล์' });
      if (file64.length > MAX_FILE64_LENGTH) {
        return reply(413, { error: 'ไฟล์ใหญ่เกินไป (ไม่เกิน 10 MB)' });
      }
      const folderType = payload.folderType === 'profile' ? 'profile' : 'leave';
      const folderId = folderType === 'profile'
        ? config.driveProfileFolderId
        : config.driveLeaveFolderId;

      const result = await bridgePost(config, {
        action: 'upload',
        folderType,
        folderId: folderId ?? '',
        fileName: String(payload.fileName ?? 'file'),
        name: String(payload.fileName ?? 'file'),
        mimeType: String(payload.mimeType ?? 'application/octet-stream'),
        file64,
      });
      const url = String(result.url ?? '');
      if (result.status !== 'success' || !url) {
        return reply(502, { error: String(result.message ?? 'อัปโหลดไม่สำเร็จ') });
      }

      // จำว่าใครอัป — คนอัปลบไฟล์ของตัวเองได้ภายหลัง
      const fileId = driveFileIdOf(url);
      if (fileId) {
        await admin.from('DriveUploads').upsert({ file_id: fileId, id_user: me.id_user });
      }
      return reply(200, { status: 'success', url, fileId });
    }

    // ── ลบไฟล์ ─────────────────────────────────────────────────────
    if (action === 'drive_delete') {
      const fileId = driveFileIdOf(String(payload.fileId ?? ''));
      if (!fileId) return reply(400, { error: 'ไม่พบรหัสไฟล์' });

      if (!isAdmin) {
        const { data: upload } = await admin
          .from('DriveUploads').select('id_user').eq('file_id', fileId).maybeSingle();
        if (!upload || upload.id_user !== me.id_user) {
          return reply(403, { error: 'ลบได้เฉพาะไฟล์ที่คุณอัปโหลดเองครับ' });
        }
      }

      const result = await bridgePost(config, { action: 'delete', fileId });
      if (result.status !== 'success') {
        return reply(502, { error: String(result.message ?? 'ลบไฟล์ไม่สำเร็จ') });
      }
      await admin.from('DriveUploads').delete().eq('file_id', fileId);
      return reply(200, { status: 'success' });
    }

    // ── เครื่องมือหน้าตั้งค่า LINE (ผู้ดูแลระบบ) ──────────────────────
    if (action === 'line_test' || action === 'line_latest_id') {
      if (!isAdmin) return reply(403, { error: 'เฉพาะผู้ดูแลระบบเท่านั้น' });

      if (action === 'line_latest_id') {
        return reply(200, await bridgeGet(config, { action: 'get_latest_id' }));
      }

      const to = String(payload.to ?? '').trim();
      const message = String(payload.message ?? '').trim();
      if (!/^[CUR][0-9a-fA-F]{32,}$/.test(to)) {
        return reply(400, { error: 'LINE ID ไม่ถูกต้อง' });
      }
      if (!message) return reply(400, { error: 'ไม่มีข้อความ' });
      return reply(200, await bridgeGet(config, { action: 'line_notification', to, message }));
    }

    return reply(400, { error: `ไม่รู้จักคำสั่ง "${action}"` });
  } catch (e) {
    return reply(500, { error: String(e instanceof Error ? e.message : e) });
  }
});
