/**
 * Edge Function: attendance-daily-line
 * ============================================================
 * ส่งสรุปการลงเวลาประจำวันเข้ากลุ่ม LINE ของแต่ละโรงเรียน (พาร์ท 6)
 * เช่น "มา 45 · สาย 3 · ลา 2 · ไปราชการ 1 · ยังไม่สแกน 4" + รายชื่อคนที่ยังไม่สแกน
 *
 * สถานะคำนวณด้วย attendance_day_status() ตัวเดียวกับ app / รายงาน
 * (supabase/attendance_daily.sql) ส่งผ่าน Apps Script แบบเดียวกับ school-bridge
 *
 * ── เรียกได้ 2 แบบ ─────────────────────────────────────────
 *   1) ตั้งเวลา (pg_cron ใน attendance_line_cron.sql เรียกทุก 10 นาที)
 *        header x-cron-secret = AppSecrets.attendance_cron_secret
 *        ส่งให้ทุกโรงเรียนที่ เปิดระบบ + เปิดสรุป LINE + ถึงเวลาที่ตั้ง +
 *        วันนี้ยังไม่ได้ส่ง + วันนี้เป็นวันทำการ
 *   2) ทดลองส่งจาก web (ผู้ดูแลส่วนกลาง)
 *        Authorization: Bearer <token ผู้ใช้>   body { school, test: true }
 *        ส่งทันที ไม่สนเวลา ไม่บันทึกว่าส่งแล้ว
 *
 * deploy (ตรวจ token เองในโค้ด เพราะ pg_cron ไม่มี token ผู้ใช้):
 *   npx supabase functions deploy attendance-daily-line --no-verify-jwt --project-ref uziajblqlbrvqmxvizsi
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ADMIN_ROLE_ID = 22;
const MAX_NAMES = 40;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

// deno-lint-ignore no-explicit-any
type Db = any;

interface DayRow {
  id_user: number;
  full_name: string;
  status: string;
  first_scan: string | null;
  late_minutes: number;
}

const WEEKDAYS = ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'];
const MONTHS = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

/** เวลาไทยตอนนี้ → { date: 'YYYY-MM-DD', time: 'HH:MM', label } */
function bangkokNow() {
  const t = new Date(Date.now() + 7 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return {
    date: `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`,
    time: `${pad(t.getUTCHours())}:${pad(t.getUTCMinutes())}`,
    label: `${WEEKDAYS[t.getUTCDay()]} ${t.getUTCDate()} ${MONTHS[t.getUTCMonth()]} ${t.getUTCFullYear() + 543}`,
  };
}

const hm = (iso: string | null) => {
  if (!iso) return '';
  const t = new Date(new Date(iso).getTime() + 7 * 3600 * 1000);
  return `${String(t.getUTCHours()).padStart(2, '0')}:${String(t.getUTCMinutes()).padStart(2, '0')}`;
};

const shortName = (full: string) => full.replace(/^(นาย|นางสาว|นาง|น\.ส\.|ว่าที่ร้อยตรี|ว่าที่ ร\.ต\.)\s*/, '').trim() || full;

const nameList = (names: string[]) =>
  names.length <= MAX_NAMES
    ? names.join(', ')
    : `${names.slice(0, MAX_NAMES).join(', ')} และอีก ${names.length - MAX_NAMES} คน`;

/** ข้อความสรุป — แยกออกมาให้ทดสอบได้ */
export function buildSummary(
  schoolLabel: string,
  dateLabel: string,
  timeLabel: string,
  rows: DayRow[],
  listMissing: boolean,
): string {
  const count = (s: string) => rows.filter((r) => r.status === s).length;
  const missing = rows.filter((r) => r.status === 'ยังไม่สแกน' || r.status === 'ขาด');
  const late = rows
    .filter((r) => r.status === 'สาย')
    .sort((a, b) => (a.first_scan ?? '').localeCompare(b.first_scan ?? ''));

  const lines = [
    `🕗 สรุปลงเวลา ${schoolLabel}`,
    `${dateLabel} (ข้อมูล ณ ${timeLabel} น.)`,
    `บุคลากร ${rows.length} คน`,
    `✅ มา ${count('มา')}  ⏰ สาย ${late.length}`,
    `📝 ลา ${count('ลา')}  💼 ไปราชการ ${count('ไปราชการ')}`,
    `❓ ยังไม่สแกน ${missing.length}`,
  ];
  if (late.length) {
    lines.push('', '⏰ สาย: ' + nameList(late.map((r) => `${shortName(r.full_name)} (${hm(r.first_scan)})`)));
  }
  if (listMissing && missing.length) {
    lines.push('', '❓ ยังไม่สแกน: ' + nameList(missing.map((r) => shortName(r.full_name))));
  }
  return lines.join('\n');
}

// ── ส่งผ่าน Apps Script (เหมือน school-bridge) ─────────────────

async function loadConfig(admin: Db): Promise<Record<string, string>> {
  const merged: Record<string, string> = {};
  const { data: rows } = await admin.from('Settings').select('*');
  for (const row of rows ?? []) {
    for (const [k, v] of Object.entries(row)) {
      if (v !== null && v !== '' && typeof v !== 'object') merged[k] = String(v);
    }
  }
  const { data: secrets } = await admin.from('AppSecrets').select('key, value');
  for (const s of secrets ?? []) if (s.value) merged[s.key] = String(s.value);
  return merged;
}

function bridgeUrlOf(config: Record<string, string>): string {
  const isWebApp = (u: string) => /^https:\/\/script\.google\.com\/macros\/s\/[^\s/]+\/exec$/.test(u.trim());
  const saved = (config.webhookUrl ?? '').trim();
  if (isWebApp(saved)) return saved;
  const fallback = (config.appsScriptUrl ?? '').trim();
  if (isWebApp(fallback)) return fallback;
  throw new Error('ยังไม่ได้ตั้งค่า URL ของ Apps Script ในหน้าตั้งค่า LINE');
}

async function sendLine(config: Record<string, string>, to: string, message: string) {
  const url = new URL(bridgeUrlOf(config));
  for (const [k, v] of Object.entries({ action: 'line_notification', to, message, secretKey: config.secretKey ?? '' })) {
    url.searchParams.set(k, v);
  }
  const text = await (await fetch(url.toString(), { redirect: 'follow' })).text();
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  let result: Record<string, unknown> = {};
  try {
    result = JSON.parse(text.slice(start, end + 1));
  } catch {
    // ตกไปด้านล่าง
  }
  if (result.status !== 'success') throw new Error(String(result.message ?? 'Apps Script ตอบกลับผิดรูปแบบ'));
}

// ── สรุป 1 โรงเรียน ────────────────────────────────────────────

async function summarize(admin: Db, config: Record<string, string>, schoolId: number, opts: {
  test: boolean;
  listMissing: boolean;
}): Promise<{ ok: boolean; skipped?: string; message?: string }> {
  const now = bangkokNow();

  const { data: line } = await admin
    .from('SchoolLineSettings')
    .select('groupId, enabled')
    .eq('id_school', schoolId)
    .maybeSingle();
  const to = String(line?.groupId ?? '').trim();
  if (!line?.enabled || !to) return { ok: false, skipped: 'โรงเรียนนี้ยังไม่ได้ตั้งกลุ่ม LINE (หน้าตั้งค่า LINE)' };

  const { data: rows, error } = await admin.rpc('attendance_day_status', {
    p_school: schoolId,
    p_from: now.date,
    p_to: now.date,
  });
  if (error) throw new Error(error.message);
  const list = (rows ?? []) as DayRow[];
  if (list.length === 0) return { ok: false, skipped: 'ไม่มีรายชื่อบุคลากรที่ต้องสแกน' };
  if (list.every((r) => r.status === 'วันหยุด')) return { ok: false, skipped: 'วันนี้เป็นวันหยุด' };
  if (list.every((r) => r.status === 'ยังไม่เริ่มใช้')) return { ok: false, skipped: 'ยังไม่ถึงวันเริ่มใช้ระบบ' };

  const { data: school } = await admin.from('Schools').select('*').eq('id_school', schoolId).maybeSingle();
  const label = [school?.namePart1, school?.namePart2].filter((x: unknown) => String(x ?? '').trim()).join(' ') ||
    school?.fullName || '';

  const message = (opts.test ? '[ทดลองส่ง]\n' : '') +
    buildSummary(label, now.label, now.time, list, opts.listMissing);
  await sendLine(config, to, message);
  return { ok: true, message };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return reply(405, { ok: false, error: 'รองรับเฉพาะ POST' });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch {
    // body ว่างได้ (cron)
  }

  let config: Record<string, string>;
  try {
    config = await loadConfig(admin);
  } catch (e) {
    return reply(500, { ok: false, error: `อ่านค่าตั้งค่าไม่สำเร็จ: ${e}` });
  }

  // ── 1) ตั้งเวลา ───────────────────────────────────────────────
  const cronSecret = req.headers.get('x-cron-secret') ?? '';
  if (cronSecret) {
    const expected = config.attendance_cron_secret ?? '';
    if (expected.length < 20 || cronSecret !== expected) {
      return reply(401, { ok: false, error: 'รหัสตั้งเวลาไม่ถูกต้อง' });
    }

    const now = bangkokNow();
    const { data: due, error } = await admin
      .from('AttendanceSettings')
      .select('id_school, line_summary_time, line_list_missing, line_summary_sent_on')
      .eq('enabled', true)
      .eq('line_summary_enabled', true);
    if (error) return reply(500, { ok: false, error: error.message });

    const results: Record<string, unknown>[] = [];
    for (const s of due ?? []) {
      if (s.line_summary_sent_on === now.date) continue;
      if (String(s.line_summary_time ?? '09:00').slice(0, 5) > now.time) continue;

      // จองก่อนส่ง กันสองรอบของ cron ส่งซ้ำ (ถ้าอีกรอบจองไปแล้ว update ได้ 0 แถว)
      const { data: claimed } = await admin
        .from('AttendanceSettings')
        .update({ line_summary_sent_on: now.date })
        .eq('id_school', s.id_school)
        .or(`line_summary_sent_on.is.null,line_summary_sent_on.neq.${now.date}`)
        .select('id_school');
      if (!claimed?.length) continue;

      try {
        const r = await summarize(admin, config, s.id_school, { test: false, listMissing: s.line_list_missing !== false });
        results.push({ school: s.id_school, ...r });
      } catch (e) {
        // ส่งไม่ผ่าน คืนการจอง ให้รอบถัดไปลองใหม่
        await admin
          .from('AttendanceSettings')
          .update({ line_summary_sent_on: s.line_summary_sent_on ?? null })
          .eq('id_school', s.id_school);
        results.push({ school: s.id_school, ok: false, error: String(e instanceof Error ? e.message : e) });
      }
    }
    return reply(200, { ok: true, at: `${now.date} ${now.time}`, results });
  }

  // ── 2) ทดลองส่งจาก web — เฉพาะผู้ดูแลส่วนกลาง ───────────────────
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return reply(401, { ok: false, error: 'กรุณาเข้าสู่ระบบก่อน' });
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return reply(401, { ok: false, error: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่' });
  const { data: me } = await admin
    .from('Teachers')
    .select('id_role, is_super_admin')
    .eq('auth_uid', user.id)
    .maybeSingle();
  if (!(me && Number(me.id_role) === ADMIN_ROLE_ID && me.is_super_admin === true)) {
    return reply(403, { ok: false, error: 'เฉพาะผู้ดูแลส่วนกลาง' });
  }

  const schoolId = Number(payload.school);
  if (!Number.isFinite(schoolId)) return reply(400, { ok: false, error: 'ต้องระบุโรงเรียน' });
  const { data: settings } = await admin
    .from('AttendanceSettings')
    .select('line_list_missing')
    .eq('id_school', schoolId)
    .maybeSingle();

  try {
    const r = await summarize(admin, config, schoolId, {
      test: true,
      listMissing: settings?.line_list_missing !== false,
    });
    return reply(200, r.ok ? r : { ok: false, error: r.skipped });
  } catch (e) {
    return reply(502, { ok: false, error: String(e instanceof Error ? e.message : e) });
  }
});
