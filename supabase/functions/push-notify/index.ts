/**
 * Edge Function: push-notify
 * ============================================================
 * ส่งแจ้งเตือนแบบแอปจริง (Web Push) ไปเครื่องของผู้รับ — ใบลาใหม่ (ผู้ดูแลระบบ)
 * และผลการอนุมัติ (เจ้าของใบลา ทุกสิทธิ์) ดู push_for_everyone.sql
 * เด้งที่มือถือ / คอม แม้ปิดแอปอยู่ (ดู supabase/push_notifications.sql)
 *
 * ── เรียกได้ 3 แบบ ─────────────────────────────────────────
 *   1) จากฐานข้อมูล (trigger push_new_notification ผ่าน pg_net)
 *        header x-push-secret = AppSecrets.push_secret   body { id }
 *        → ส่งแจ้งเตือน AppNotifications แถวนั้นไปทุกเครื่องของผู้รับ
 *   2) แอปขอกุญแจสาธารณะ    Authorization: Bearer <token>  body { action: 'public_key' }
 *        สร้างกุญแจ VAPID ให้เองครั้งแรก เก็บใน AppSecrets (ไม่ต้องตั้งค่าเอง)
 *   3) แอปกด "ทดสอบแจ้งเตือน"  Authorization: Bearer <token>
 *        body { action: 'test' } → ส่งไปทุกเครื่องของคนที่กด
 *
 * เครื่องที่เลิกรับแล้ว (ถอนแอป / ปิดสิทธิ์) ปลายทางตอบ 404/410 → ลบแถวทิ้งเอง
 *
 * deploy (ตรวจสิทธิ์เองในโค้ด เพราะ pg_net ไม่มี token ผู้ใช้):
 *   npx supabase functions deploy push-notify --no-verify-jwt --project-ref uziajblqlbrvqmxvizsi
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import webpush from 'npm:web-push@3.6.7';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ADMIN_ROLE_ID = 22;
// ผู้ติดต่อใน VAPID (sub) ต้องเป็นอีเมล / เว็บจริง — Apple (iPhone) ปฏิเสธทุกข้อความ
// ด้วย 403 BadJwtToken ถ้าเป็นโดเมนปลอม เช่น .local (Chrome ไม่เช็ก)
const CONTACT = 'https://rbp-chanikarnn.web.app/';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-push-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function secret(key: string): Promise<string | null> {
  const { data } = await admin.from('AppSecrets').select('value').eq('key', key).maybeSingle();
  return (data?.value as string | undefined) ?? null;
}

/** กุญแจ VAPID — ไม่มีก็สร้างใหม่แล้วเก็บ (ครั้งแรกครั้งเดียว) */
async function vapidKeys(): Promise<{ publicKey: string; privateKey: string }> {
  const [pub, priv] = await Promise.all([secret('vapid_public'), secret('vapid_private')]);
  if (pub && priv) return { publicKey: pub, privateKey: priv };
  const keys = webpush.generateVAPIDKeys();
  // ignoreDuplicates: สองคำขอพร้อมกันตอนแรก — คนที่มาทีหลังใช้ของคนแรก
  await admin.from('AppSecrets').upsert(
    [
      { key: 'vapid_public', value: keys.publicKey },
      { key: 'vapid_private', value: keys.privateKey },
    ],
    { onConflict: 'key', ignoreDuplicates: true },
  );
  const [p2, k2] = await Promise.all([secret('vapid_public'), secret('vapid_private')]);
  return { publicKey: p2 ?? keys.publicKey, privateKey: k2 ?? keys.privateKey };
}

interface Payload {
  title: string;
  body?: string;
  url?: string;
  tag?: string;
}

interface Failure {
  host: string;
  code?: number;
  reason: string;
}

/** ส่งไปทุกเครื่องของคนนี้ — คืนจำนวนที่ส่งสำเร็จ + เหตุผลของเครื่องที่ส่งไม่ผ่าน
 *  (เห็นได้ใน net._http_response.content ไม่ต้องเปิด log) */
async function sendToUser(
  idUser: number,
  payload: Payload,
): Promise<{ sent: number; removed: number; failed: Failure[] }> {
  const { data: subs } = await admin
    .from('PushSubscriptions')
    .select('id_subscription, endpoint, p256dh, auth')
    .eq('id_user', idUser);
  if (!subs?.length) return { sent: 0, removed: 0, failed: [] };

  const keys = await vapidKeys();
  webpush.setVapidDetails(CONTACT, keys.publicKey, keys.privateKey);

  let sent = 0;
  const dead: number[] = [];
  const failed: Failure[] = [];
  await Promise.all(
    subs.map(async (s) => {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          JSON.stringify(payload),
          { TTL: 60 * 60 * 24, urgency: 'high' },
        );
        sent++;
      } catch (e) {
        const err = e as { statusCode?: number; body?: string; message?: string };
        const code = err.statusCode;
        if (code === 404 || code === 410) {
          dead.push(s.id_subscription);
        } else {
          // Apple / Google ส่งเหตุผลมาใน body เช่น {"reason":"BadJwtToken"}
          const reason = (err.body || err.message || '').toString().slice(0, 300);
          failed.push({ host: new URL(s.endpoint).host, code, reason });
          console.warn('push failed', code, reason);
        }
      }
    }),
  );
  if (dead.length) await admin.from('PushSubscriptions').delete().in('id_subscription', dead);
  return { sent, removed: dead.length, failed };
}

/** ผู้เรียกจาก token — ต้องเป็นบุคลากรที่ยังปฏิบัติงาน */
async function caller(req: Request) {
  const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  if (!data?.user) return null;
  const { data: t } = await admin
    .from('Teachers')
    .select('id_user, id_role, employment_status, left_date')
    .eq('auth_uid', data.user.id)
    .maybeSingle();
  if (!t || !isWorkingToday(t.employment_status, t.left_date)) return null;
  return t as { id_user: number; id_role: number };
}

/**
 * ยังปฏิบัติงานวันนี้ — ตรงกับ staff_is_working() ในฐานข้อมูล
 * สถานะพ้นสภาพมีผลตั้งแต่ left_date ก่อนวันนั้นยังทำงานตามปกติ
 */
function isWorkingToday(status: string | null, leftDate: string | null): boolean {
  if ((status ?? 'active') === 'active') return true;
  if (!leftDate) return false;
  // วันนี้ตามเวลาไทย (YYYY-MM-DD) — เซิร์ฟเวอร์ Edge Function เป็นเวลา UTC
  const todayTh = new Date(Date.now() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
  return leftDate.slice(0, 10) > todayTh;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return reply(405, { error: 'POST only' });

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    /* ไม่มี body */
  }

  // 1) จากฐานข้อมูล
  const pushSecret = req.headers.get('x-push-secret');
  if (pushSecret) {
    if (pushSecret !== (await secret('push_secret'))) return reply(403, { error: 'รหัสลับไม่ถูกต้อง' });
    const id = Number(body.id);
    if (!id) return reply(400, { error: 'ต้องมี id' });
    const { data: n } = await admin
      .from('AppNotifications')
      .select('id_notification, recipient_id, title, body, ref_table')
      .eq('id_notification', id)
      .maybeSingle();
    if (!n) return reply(404, { error: 'ไม่พบแจ้งเตือน' });
    const result = await sendToUser(n.recipient_id, {
      title: n.title,
      body: n.body ?? undefined,
      url: './',
      tag: `n${n.id_notification}`,
    });
    return reply(200, result);
  }

  // 2) / 3) จากแอป
  const me = await caller(req);
  if (!me) return reply(401, { error: 'ต้องเข้าสู่ระบบ' });

  if (body.action === 'public_key') {
    return reply(200, { publicKey: (await vapidKeys()).publicKey });
  }

  if (body.action === 'test') {
    const result = await sendToUser(me.id_user, {
      title: 'ทดสอบแจ้งเตือน ✅',
      body:
        me.id_role === ADMIN_ROLE_ID
          ? 'เครื่องนี้จะได้รับแจ้งเตือนใบลาใหม่ และผลการอนุมัติใบลาของคุณ'
          : 'เครื่องนี้จะได้รับแจ้งเตือนผลการอนุมัติใบลาของคุณ',
      tag: 'test',
    });
    return reply(200, result);
  }

  return reply(400, { error: 'ไม่รู้จักคำสั่ง' });
});
