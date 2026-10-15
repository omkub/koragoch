/**
 * Edge Function: push-notify
 * ============================================================
 * ส่งแจ้งเตือนแบบแอปจริง (Web Push) ไปเครื่องของผู้ดูแลระบบ / ผู้ดูแลส่วนกลาง
 * เด้งที่มือถือ / คอม แม้ปิดแอปอยู่ (ดู supabase/push_notifications.sql)
 *
 * ── เรียกได้ 3 แบบ ─────────────────────────────────────────
 *   1) จากฐานข้อมูล (trigger push_new_notification ผ่าน pg_net)
 *        header x-push-secret = AppSecrets.push_secret   body { id }
 *        → ส่งแจ้งเตือน AppNotifications แถวนั้นไปทุกเครื่องของผู้รับ
 *   2) แอปขอกุญแจสาธารณะ    Authorization: Bearer <token>  body { action: 'public_key' }
 *        สร้างกุญแจ VAPID ให้เองครั้งแรก เก็บใน AppSecrets (ไม่ต้องตั้งค่าเอง)
 *   3) แอปกด "ทดสอบแจ้งเตือน"  Authorization: Bearer <token ผู้ดูแลระบบ>
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
const CONTACT = 'mailto:koragoch@leave.local';

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

/** ส่งไปทุกเครื่องของคนนี้ — คืนจำนวนที่ส่งสำเร็จ */
async function sendToUser(idUser: number, payload: Payload): Promise<{ sent: number; removed: number }> {
  const { data: subs } = await admin
    .from('PushSubscriptions')
    .select('id_subscription, endpoint, p256dh, auth')
    .eq('id_user', idUser);
  if (!subs?.length) return { sent: 0, removed: 0 };

  const keys = await vapidKeys();
  webpush.setVapidDetails(CONTACT, keys.publicKey, keys.privateKey);

  let sent = 0;
  const dead: number[] = [];
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
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) dead.push(s.id_subscription);
        else console.warn('push failed', code, (e as Error).message);
      }
    }),
  );
  if (dead.length) await admin.from('PushSubscriptions').delete().in('id_subscription', dead);
  return { sent, removed: dead.length };
}

/** ผู้เรียกจาก token — ต้องเป็นบุคลากรที่ยังปฏิบัติงาน */
async function caller(req: Request) {
  const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  if (!data?.user) return null;
  const { data: t } = await admin
    .from('Teachers')
    .select('id_user, id_role, employment_status')
    .eq('auth_uid', data.user.id)
    .maybeSingle();
  if (!t || (t.employment_status ?? 'active') !== 'active') return null;
  return t as { id_user: number; id_role: number };
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
    if (me.id_role !== ADMIN_ROLE_ID) return reply(403, { error: 'เฉพาะผู้ดูแลระบบ' });
    const result = await sendToUser(me.id_user, {
      title: 'ทดสอบแจ้งเตือน ✅',
      body: 'เครื่องนี้จะได้รับแจ้งเตือนเมื่อมีใบลาใหม่',
      tag: 'test',
    });
    return reply(200, result);
  }

  return reply(400, { error: 'ไม่รู้จักคำสั่ง' });
});
