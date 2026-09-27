import { useEffect, useState } from 'react';
import { functionError, schoolName, supabase, type School } from '../supabase';

interface LineRow {
  id_school: number;
  groupId: string | null;
  template: string | null;
  enabled: boolean;
}

const BRIDGE_FUNCTION = 'school-bridge';

// ตัวแปรที่ใช้ในข้อความได้ — school-bridge แทนค่าให้ตอนส่ง
const TEMPLATE_HINT = '{name} {type} {startDate} {endDate} {days} {reason}';

const isLineTarget = (v: string) => /^[CUR][0-9a-fA-F]{32,}$/.test(v.trim());

/**
 * ตั้งค่า LINE ของแต่ละโรงเรียน (ตาราง SchoolLineSettings — แก้ได้เฉพาะส่วนกลาง)
 * channel เดียวกันทั้งระบบ แต่แต่ละโรงเรียนส่งเข้ากลุ่มของตัวเอง
 */
export default function LinePage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [rows, setRows] = useState<Record<number, LineRow>>({});
  const [editing, setEditing] = useState<LineRow | null>(null);
  const [bridgeUrl, setBridgeUrl] = useState('');
  const [bridgeRowId, setBridgeRowId] = useState<number | null>(null);
  const [latest, setLatest] = useState<string | null>(null);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    const [s, l, settings] = await Promise.all([
      supabase.from('Schools').select('*').order('id_school'),
      supabase.from('SchoolLineSettings').select('*'),
      supabase.from('Settings').select('*'),
    ]);
    const failed = s.error ?? l.error ?? settings.error;
    if (failed) {
      setMessage({ text: `โหลดไม่สำเร็จ: ${failed.message} (รัน line_per_school.sql แล้วหรือยัง?)`, error: true });
      return;
    }
    setSchools(s.data as School[]);
    const byId: Record<number, LineRow> = {};
    for (const r of (l.data ?? []) as LineRow[]) byId[r.id_school] = r;
    setRows(byId);

    // URL ของ Apps Script เก็บใน Settings (แถวที่มี webhookUrl) ใช้ร่วมทุกโรงเรียน
    const withUrl = (settings.data ?? []).find((r) => r.webhookUrl) ?? null;
    setBridgeRowId(withUrl ? withUrl.id_Settings : null);
    setBridgeUrl(withUrl?.webhookUrl ?? '');
  }

  useEffect(() => {
    load();
  }, []);

  async function saveBridgeUrl() {
    setMessage(null);
    const url = bridgeUrl.trim();
    if (!/^https:\/\/script\.google\.com\/macros\/s\/[^\s/]+\/exec$/.test(url)) {
      setMessage({ text: 'URL ต้องเป็นแบบ https://script.google.com/macros/s/.../exec', error: true });
      return;
    }
    const payload = { webhookUrl: url, updatedAt: new Date().toISOString() };
    const { error } = bridgeRowId
      ? await supabase.from('Settings').update(payload).eq('id_Settings', bridgeRowId)
      : await supabase.from('Settings').insert(payload);
    setMessage(error ? { text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true } : { text: 'บันทึก URL แล้ว' });
    if (!error) load();
  }

  async function fetchLatestId() {
    setMessage(null);
    const { data, error } = await supabase.functions.invoke(BRIDGE_FUNCTION, {
      body: { action: 'line_latest_id' },
    });
    if (error) {
      setMessage({ text: await functionError(error), error: true });
      return;
    }
    if (data?.status === 'success' && data.latestId) {
      setLatest(`${data.latestId}  (เห็นล่าสุด ${data.timestamp ?? '-'})`);
    } else {
      setMessage({ text: data?.message ?? 'ยังไม่พบไอดี — ส่งข้อความในกลุ่มที่มีบอทก่อน', error: true });
    }
  }

  async function save() {
    if (!editing) return;
    const groupId = (editing.groupId ?? '').trim();
    if (groupId && !isLineTarget(groupId)) {
      setMessage({ text: 'Group ID ไม่ถูกต้อง (ขึ้นต้นด้วย C, U หรือ R)', error: true });
      return;
    }
    if (editing.enabled && !groupId) {
      setMessage({ text: 'จะเปิดแจ้งเตือนต้องใส่ Group ID ก่อน', error: true });
      return;
    }
    setBusy(true);
    const { error } = await supabase.from('SchoolLineSettings').upsert({
      id_school: editing.id_school,
      groupId: groupId || null,
      template: editing.template?.trim() || null,
      enabled: editing.enabled,
      updatedAt: new Date().toISOString(),
    });
    setBusy(false);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage({ text: 'บันทึกแล้ว' });
    setEditing(null);
    load();
  }

  async function sendTest(row: LineRow) {
    const school = schools.find((s) => s.id_school === row.id_school);
    const groupId = (row.groupId ?? '').trim();
    if (!isLineTarget(groupId)) {
      setMessage({ text: 'ใส่ Group ID ให้ถูกต้องก่อนทดสอบ', error: true });
      return;
    }
    setBusy(true);
    const { data, error } = await supabase.functions.invoke(BRIDGE_FUNCTION, {
      body: {
        action: 'line_test',
        to: groupId,
        message: `🔔 ทดสอบแจ้งเตือนระบบลาออนไลน์\n🏫 ${school ? schoolName(school) : ''}\nถ้าเห็นข้อความนี้ แปลว่าตั้งค่ากลุ่มถูกต้องแล้ว`,
      },
    });
    setBusy(false);
    if (error) {
      setMessage({ text: `ส่งไม่สำเร็จ: ${await functionError(error)}`, error: true });
    } else if (data?.status !== 'success') {
      setMessage({ text: `ส่งไม่สำเร็จ: ${data?.message ?? 'LINE ตอบกลับผิดพลาด'}`, error: true });
    } else {
      setMessage({ text: 'ส่งข้อความทดสอบแล้ว ตรวจในกลุ่ม LINE ได้เลย' });
    }
  }

  return (
    <>
      <h1>LINE แจ้งเตือน</h1>
      <p className="muted" style={{ marginBottom: 16 }}>
        LINE Official Account เดียวกันทั้งระบบ แต่แต่ละโรงเรียนส่งเข้ากลุ่มของตัวเอง
        โรงเรียนที่ปิดไว้หรือยังไม่มี Group ID จะไม่ส่งแจ้งเตือน
      </p>
      {message && <div className={message.error ? 'error' : 'ok'}>{message.text}</div>}

      <div className="card form">
        <h3>สะพาน Apps Script (ใช้ร่วมทุกโรงเรียน)</h3>
        <div className="row" style={{ marginBottom: 0 }}>
          <input
            style={{ flex: 1 }}
            value={bridgeUrl}
            placeholder="https://script.google.com/macros/s/.../exec"
            onChange={(e) => setBridgeUrl(e.target.value)}
          />
          <button onClick={saveBridgeUrl}>บันทึก URL</button>
        </div>
        <div className="row" style={{ marginTop: 12, marginBottom: 0 }}>
          <span className="muted">
            หา Group ID: เชิญบอทเข้ากลุ่ม แล้วพิมพ์อะไรก็ได้ในกลุ่ม จากนั้นกดปุ่มนี้
          </span>
          <button className="secondary" onClick={fetchLatestId}>ดึง Group ID ล่าสุด</button>
        </div>
        {latest && (
          <p style={{ marginTop: 8 }}>
            ไอดีล่าสุด: <code>{latest}</code>
          </p>
        )}
      </div>

      {editing && (
        <div className="card form">
          <h3>
            ตั้งค่า LINE —{' '}
            {schoolName(schools.find((s) => s.id_school === editing.id_school) ?? {
              namePart1: null, namePart2: null, fullName: `#${editing.id_school}`,
            })}
          </h3>
          <div className="grid">
            <label>
              Group ID
              <input
                value={editing.groupId ?? ''}
                placeholder="C1234..."
                onChange={(e) => setEditing({ ...editing, groupId: e.target.value })}
              />
            </label>
            <label className="check">
              <input
                type="checkbox"
                checked={editing.enabled}
                onChange={(e) => setEditing({ ...editing, enabled: e.target.checked })}
              />
              เปิดแจ้งเตือนใบลาใหม่
            </label>
          </div>
          <label style={{ marginTop: 14 }}>
            ข้อความ (เว้นว่าง = ใช้แบบมาตรฐาน) — ใช้ได้: {TEMPLATE_HINT}
            <textarea
              rows={6}
              value={editing.template ?? ''}
              onChange={(e) => setEditing({ ...editing, template: e.target.value })}
            />
          </label>
          <div className="row end">
            <button type="button" className="secondary" onClick={() => setEditing(null)}>ยกเลิก</button>
            <button type="button" className="secondary" disabled={busy} onClick={() => sendTest(editing)}>
              ทดสอบส่ง
            </button>
            <button type="button" disabled={busy} onClick={save}>บันทึก</button>
          </div>
        </div>
      )}

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>โรงเรียน</th>
              <th>Group ID</th>
              <th>แจ้งเตือน</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {schools.map((s) => {
              const row = rows[s.id_school] ?? {
                id_school: s.id_school, groupId: null, template: null, enabled: false,
              };
              return (
                <tr key={s.id_school}>
                  <td>{schoolName(s)}</td>
                  <td><code>{row.groupId ? `${row.groupId.slice(0, 10)}…` : '-'}</code></td>
                  <td>{row.enabled ? <span className="badge on">เปิด</span> : <span className="warn">ปิด</span>}</td>
                  <td className="num">
                    <button className="secondary small" onClick={() => { setMessage(null); setEditing({ ...row }); }}>
                      ตั้งค่า
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
