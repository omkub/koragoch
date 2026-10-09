/**
 * Edge Function: attendance-ingest
 * ============================================================
 * จุดรับเวลาสแกนจากเครื่องสแกนหน้า (หรือตัวเชื่อมของเครื่อง) เข้าตาราง
 * AttendanceLogs — ดู supabase/attendance.sql
 *
 * เครื่องไม่มีบัญชีผู้ใช้ จึงยืนยันตัวด้วย "รหัสลับเครื่อง" ที่ออกจาก web
 * (หน้า ลงเวลา > เครื่องสแกน) ฐานข้อมูลเก็บแค่ sha256 ของรหัส
 *
 * ต้อง deploy แบบ "ไม่ตรวจ JWT" (เครื่องไม่มี token ของ Supabase):
 *   npx supabase functions deploy attendance-ingest --no-verify-jwt --project-ref uziajblqlbrvqmxvizsi
 *
 * ── วิธีเรียก ─────────────────────────────────────────────
 *   POST https://uziajblqlbrvqmxvizsi.supabase.co/functions/v1/attendance-ingest
 *   Header: x-device-key: <รหัสลับเครื่อง>      (หรือ ?key=<รหัส> ถ้าเครื่องตั้ง header ไม่ได้)
 *   Body:   { "logs": [ { "code": "1001", "time": "2026-10-09 07:45:12" }, ... ] }
 *
 *   - รับได้ทั้ง { logs: [...] }, [...] หรือแถวเดียว { code, time }
 *   - ชื่อช่องที่รับ: code | user_id | pin | employee_id   และ
 *                    time | datetime | timestamp | scanned_at
 *   - เวลาที่ไม่มีโซนเวลา ถือเป็นเวลาไทย (+07:00)
 *   - ครั้งละไม่เกิน 2,000 แถว / ส่งซ้ำได้ ไม่บันทึกเบิ้ล
 *
 *   ตอบกลับ: { ok, device, received, inserted, duplicates, invalid, unmatched }
 *     unmatched = รหัสที่ยังไม่ได้จับคู่กับครู (เก็บไว้ก่อน จับคู่ทีหลังได้ที่ web)
 *
 *   GET + รหัสลับ = ทดสอบการเชื่อมต่อ (ไม่บันทึกอะไร)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const MAX_ROWS = 2000;
const MAX_BODY_BYTES = 1024 * 1024;
// นาฬิกาเครื่องเร็วได้นิดหน่อย แต่เวลาในอนาคตไกล ๆ คือข้อมูลผิด
const MAX_FUTURE_MS = 10 * 60 * 1000;
const MIN_YEAR = 2020;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'x-device-key, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const pick = (row: Record<string, unknown>, keys: string[]) => {
  for (const k of keys) {
    const v = row[k];
    if (v !== undefined && v !== null && String(v).trim() !== '') return String(v).trim();
  }
  return '';
};

/**
 * เวลาสแกน → ISO (UTC)
 *   '2026-10-09 07:45:12' / '2026-10-09T07:45' → ถือเป็นเวลาไทย
 *   '2026-10-09T00:45:12Z' / '...+07:00'        → ใช้โซนที่ให้มา
 *   ตัวเลขล้วน                                  → unix time (วินาทีหรือมิลลิวินาที)
 *   ปี พ.ศ. (> 2400) แปลงเป็น ค.ศ. ให้
 */
function parseScanTime(raw: string): Date | null {
  const text = raw.trim();
  if (/^\d{10}$/.test(text)) return new Date(Number(text) * 1000);
  if (/^\d{13}$/.test(text)) return new Date(Number(text));

  const m = text.match(
    /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?\s*(Z|[+-]\d{2}:?\d{2})?$/i,
  );
  if (!m) return null;
  let year = Number(m[1]);
  if (year > 2400) year -= 543;
  const pad = (v: string | number) => String(v).padStart(2, '0');
  const zone = m[7] ? (m[7].toUpperCase() === 'Z' ? 'Z' : m[7].replace(/^([+-]\d{2})(\d{2})$/, '$1:$2')) : '+07:00';
  const iso = `${year}-${pad(m[2])}-${pad(m[3])}T${pad(m[4])}:${m[5]}:${m[6] ?? '00'}${zone}`;
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? null : date;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST' && req.method !== 'GET') {
    return reply(405, { ok: false, error: 'รองรับเฉพาะ POST (ส่งข้อมูล) และ GET (ทดสอบ)' });
  }

  // ── ยืนยันเครื่อง ────────────────────────────────────────
  const url = new URL(req.url);
  const key = (req.headers.get('x-device-key') ?? url.searchParams.get('key') ?? '').trim();
  if (key.length < 20) return reply(401, { ok: false, error: 'ไม่มีรหัสลับเครื่อง' });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const { data: device, error: deviceError } = await admin
    .from('AttendanceDevices')
    .select('id_device, id_school, name, is_active')
    .eq('device_key_hash', await sha256Hex(key))
    .maybeSingle();
  if (deviceError) return reply(500, { ok: false, error: deviceError.message });
  if (!device) return reply(401, { ok: false, error: 'รหัสลับเครื่องไม่ถูกต้อง' });
  if (!device.is_active) {
    return reply(403, { ok: false, error: `เครื่อง "${device.name}" ถูกปิดใช้งานที่ web` });
  }

  if (req.method === 'GET') {
    await admin
      .from('AttendanceDevices')
      .update({ last_seen_at: new Date().toISOString() })
      .eq('id_device', device.id_device);
    return reply(200, { ok: true, device: device.name, message: 'เชื่อมต่อสำเร็จ' });
  }

  // ── อ่านข้อมูล ───────────────────────────────────────────
  const rawBody = await req.text();
  if (rawBody.length > MAX_BODY_BYTES) {
    return reply(413, { ok: false, error: 'ข้อมูลใหญ่เกินไป แบ่งส่งครั้งละไม่เกิน 2,000 แถว' });
  }
  let body: unknown;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return reply(400, { ok: false, error: 'ข้อมูลต้องเป็น JSON' });
  }

  const list: unknown[] = Array.isArray(body)
    ? body
    : Array.isArray((body as { logs?: unknown })?.logs)
    ? (body as { logs: unknown[] }).logs
    : body && typeof body === 'object'
    ? [body]
    : [];
  if (list.length === 0) return reply(400, { ok: false, error: 'ไม่มีรายการสแกน' });
  if (list.length > MAX_ROWS) {
    return reply(413, { ok: false, error: `ส่งได้ครั้งละไม่เกิน ${MAX_ROWS} แถว` });
  }

  const now = Date.now();
  let invalid = 0;
  const rows: Record<string, unknown>[] = [];
  const seen = new Set<string>();
  for (const item of list) {
    const row = (item ?? {}) as Record<string, unknown>;
    const code = pick(row, ['code', 'user_id', 'userId', 'pin', 'employee_id', 'employeeId']);
    const time = parseScanTime(pick(row, ['time', 'datetime', 'timestamp', 'scanned_at', 'scannedAt']));
    if (
      !code || code.length > 50 || !time ||
      time.getTime() > now + MAX_FUTURE_MS || time.getUTCFullYear() < MIN_YEAR
    ) {
      invalid++;
      continue;
    }
    const scannedAt = time.toISOString();
    const dedupe = `${code}|${scannedAt}`;
    if (seen.has(dedupe)) continue; // ซ้ำในชุดเดียวกัน
    seen.add(dedupe);
    rows.push({
      id_device: device.id_device,
      id_school: device.id_school,
      device_code: code,
      scanned_at: scannedAt,
      source: 'device',
    });
  }

  // ── บันทึก (trigger fill_attendance_log จับคู่รหัสกับครูให้) ─────
  let inserted: { id_user: number | null }[] = [];
  if (rows.length) {
    const { data, error } = await admin
      .from('AttendanceLogs')
      .upsert(rows, {
        onConflict: 'id_school,id_user,device_code,scanned_at',
        ignoreDuplicates: true,
      })
      .select('id_user');
    if (error) return reply(500, { ok: false, error: error.message });
    inserted = data ?? [];
  }

  await admin
    .from('AttendanceDevices')
    .update({ last_seen_at: new Date().toISOString() })
    .eq('id_device', device.id_device);

  return reply(200, {
    ok: true,
    device: device.name,
    received: list.length,
    inserted: inserted.length,
    duplicates: list.length - invalid - inserted.length,
    invalid,
    unmatched: inserted.filter((r) => r.id_user === null).length,
  });
});
