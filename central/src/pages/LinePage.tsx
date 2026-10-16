import { useEffect, useState } from 'react';
import { functionError, schoolName, supabase, type School } from '../supabase';
import { Field, Notice, PageHeader } from '../ui/components';

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

  const rowOf = (s: School): LineRow =>
    rows[s.id_school] ?? { id_school: s.id_school, groupId: null, template: null, enabled: false };
  const statusBadge = (row: LineRow) =>
    row.enabled ? <span className="badge-green">เปิด</span> : <span className="badge-slate">ปิด</span>;
  const openEdit = (row: LineRow) => {
    setMessage(null);
    setEditing({ ...row });
  };

  return (
    <>
      <PageHeader
        title="LINE แจ้งเตือน"
        description="LINE Official Account เดียวกันทั้งระบบ แต่แต่ละโรงเรียนส่งเข้ากลุ่มของตัวเอง · โรงเรียนที่ปิดไว้หรือยังไม่มี Group ID จะไม่ส่งแจ้งเตือน"
      />
      <Notice message={message} />

      <section className="card mb-5">
        <div className="card-title">สะพาน Apps Script (ใช้ร่วมทุกโรงเรียน)</div>
        <div className="flex flex-col gap-3 px-4 pb-4 sm:px-5">
          <div className="flex flex-col gap-2 sm:flex-row">
            <input
              className="input font-mono text-[13px]"
              value={bridgeUrl}
              placeholder="https://script.google.com/macros/s/.../exec"
              onChange={(e) => setBridgeUrl(e.target.value)}
            />
            <button className="btn-primary sm:shrink-0" onClick={saveBridgeUrl}>
              บันทึก URL
            </button>
          </div>
          <div className="flex flex-col gap-2 rounded-xl bg-slate-50 p-3 sm:flex-row sm:items-center sm:justify-between">
            <span className="text-[13px] text-slate-600">
              หา Group ID: เชิญบอทเข้ากลุ่ม แล้วพิมพ์อะไรก็ได้ในกลุ่ม จากนั้นกดปุ่มนี้
            </span>
            <button className="btn-secondary sm:shrink-0" onClick={fetchLatestId}>
              ดึง Group ID ล่าสุด
            </button>
          </div>
          {latest && (
            <p className="text-[13px]">
              ไอดีล่าสุด:{' '}
              <code className="select-all break-all rounded bg-slate-100 px-1.5 py-0.5 text-xs">{latest}</code>
            </p>
          )}
        </div>
      </section>

      {editing && (
        <section className="card mb-5">
          <div className="card-title">
            ตั้งค่า LINE —{' '}
            {schoolName(
              schools.find((s) => s.id_school === editing.id_school) ?? {
                namePart1: null,
                namePart2: null,
                fullName: `#${editing.id_school}`,
              },
            )}
          </div>
          <div className="flex flex-col gap-4 px-4 pb-4 sm:px-5">
            <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end">
              <Field label="Group ID" hint="ขึ้นต้นด้วย C (กลุ่ม), U (คน) หรือ R (ห้อง)">
                <input
                  className="input font-mono text-[13px]"
                  value={editing.groupId ?? ''}
                  placeholder="C1234..."
                  onChange={(e) => setEditing({ ...editing, groupId: e.target.value })}
                />
              </Field>
              <label className="flex items-center gap-2 pb-2 text-[13px] font-medium">
                <input
                  type="checkbox"
                  className="checkbox"
                  checked={editing.enabled}
                  onChange={(e) => setEditing({ ...editing, enabled: e.target.checked })}
                />
                เปิดแจ้งเตือนใบลาใหม่
              </label>
            </div>
            <Field label="ข้อความ (เว้นว่าง = ใช้แบบมาตรฐาน)" hint={`ใช้ได้: ${TEMPLATE_HINT}`}>
              <textarea
                className="input min-h-[140px] resize-y"
                value={editing.template ?? ''}
                onChange={(e) => setEditing({ ...editing, template: e.target.value })}
              />
            </Field>
          </div>
          <div className="flex flex-wrap justify-end gap-2 border-t border-line px-4 py-3 sm:px-5">
            <button type="button" className="btn-secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button type="button" className="btn-secondary" disabled={busy} onClick={() => sendTest(editing)}>
              ทดสอบส่ง
            </button>
            <button type="button" className="btn-primary" disabled={busy} onClick={save}>
              บันทึก
            </button>
          </div>
        </section>
      )}

      <section className="card overflow-hidden">
        <div className="card-title">กลุ่ม LINE ของแต่ละโรงเรียน</div>
        <div className="hidden overflow-x-auto md:block">
          <table className="table">
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
                const row = rowOf(s);
                return (
                  <tr key={s.id_school}>
                    <td className="font-medium">{schoolName(s)}</td>
                    <td>
                      <code className="text-xs text-slate-600">{row.groupId ? `${row.groupId.slice(0, 10)}…` : '-'}</code>
                    </td>
                    <td>{statusBadge(row)}</td>
                    <td className="text-right">
                      <button className="btn-secondary btn-sm" onClick={() => openEdit(row)}>
                        ตั้งค่า
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <ul className="divide-y divide-slate-100 md:hidden">
          {schools.map((s) => {
            const row = rowOf(s);
            return (
              <li key={s.id_school} className="flex items-center gap-3 px-4 py-3.5">
                <div className="min-w-0 flex-1">
                  <div className="truncate font-medium">{schoolName(s)}</div>
                  <div className="mt-1 flex items-center gap-2 text-xs text-slate-500">
                    {statusBadge(row)}
                    <code className="truncate">{row.groupId ? `${row.groupId.slice(0, 10)}…` : 'ยังไม่มี Group ID'}</code>
                  </div>
                </div>
                <button className="btn-secondary btn-sm" onClick={() => openEdit(row)}>
                  ตั้งค่า
                </button>
              </li>
            );
          })}
        </ul>
      </section>
    </>
  );
}
