import { useEffect, useState } from 'react';
import { functionError, schoolName, supabase, type School } from '../supabase';
import { Field, Notice, PageHeader, SectionHeader } from '../ui/components';

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
 * ตั้งค่า LINE ของแต่ละโรงเรียน — แยกหมวดหมู่เป็น 2 ส่วน:
 * 1. สะพานเชื่อมระบบกลาง (Apps Script & ค้นหา Group ID)
 * 2. ตั้งค่ากลุ่ม LINE แยกตามโรงเรียน
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
    setMessage(error ? { text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true } : { text: 'บันทึก URL สะพานเชื่อมแล้ว' });
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
    setMessage({ text: 'บันทึกการตั้งค่า LINE ของโรงเรียนแล้ว' });
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
    row.enabled ? <span className="badge-green">เปิดใช้งาน</span> : <span className="badge-slate">ปิด</span>;
  const openEdit = (row: LineRow) => {
    setMessage(null);
    setEditing({ ...row });
  };

  const enabledCount = schools.filter((s) => rowOf(s).enabled).length;

  return (
    <>
      <PageHeader
        category="4. ระบบเชื่อมต่อและเอกสาร"
        title="ตั้งค่า LINE แจ้งเตือน"
        description="ใช้ LINE Official Account เดียวกันทั้งระบบ แต่ส่งแยกเข้ากลุ่มของแต่ละโรงเรียน"
      />
      <Notice message={message} />

      {/* หมวดที่ 1: สะพานเชื่อมระบบกลาง */}
      <div className="mb-6">
        <SectionHeader
          step="1"
          title="ตั้งค่าสะพานเชื่อมระบบกลาง (ใช้ร่วมกันทุกโรงเรียน)"
          subtitle="เชื่อมต่อกับ Google Apps Script และค้นหา Group ID ล่าสุดที่บอทถูกเชิญเข้ากลุ่ม"
        />
        <section className="card p-4 sm:p-5">
          <div className="grid gap-4 lg:grid-cols-2">
            <div className="subcard flex flex-col justify-between gap-3">
              <div>
                <div className="text-[13px] font-semibold text-ink">1.1 URL ของ Google Apps Script</div>
                <p className="mt-0.5 text-xs text-slate-500">
                  Web App URL ที่ลงท้ายด้วย <code>/exec</code> สำหรับส่งข้อความ LINE และอัปโหลดไฟล์
                </p>
              </div>
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
            </div>

            <div className="subcard flex flex-col justify-between gap-3">
              <div>
                <div className="text-[13px] font-semibold text-ink">1.2 เครื่องมือดึง Group ID ล่าสุด</div>
                <p className="mt-0.5 text-xs text-slate-500">
                  วิธีใช้: เชิญบอทเข้ากลุ่ม LINE ของโรงเรียน แล้วพิมพ์ข้อความอะไรก็ได้ในกลุ่ม 1 ครั้ง จากนั้นกดปุ่มดึงไอดี
                </p>
              </div>
              <div className="flex flex-wrap items-center justify-between gap-2">
                {latest ? (
                  <code className="select-all break-all rounded-lg border border-brand-200 bg-brand-50 px-2.5 py-1.5 font-mono text-xs font-semibold text-brand-700">
                    {latest}
                  </code>
                ) : (
                  <span className="text-xs text-slate-400">กดปุ่มเพื่อตรวจสอบ Group ID ล่าสุด</span>
                )}
                <button className="btn-secondary shrink-0" onClick={fetchLatestId}>
                  ดึง Group ID ล่าสุด
                </button>
              </div>
            </div>
          </div>
        </section>
      </div>

      {/* กล่องแก้ไขของโรงเรียนที่เลือก */}
      {editing && (
        <section className="card mb-6 overflow-hidden border-brand-200">
          <div className="card-title bg-brand-50/40">
            <div className="flex items-center gap-2">
              <span className="badge-brand">ตั้งค่ารายโรงเรียน</span>
              <span>
                {schoolName(
                  schools.find((s) => s.id_school === editing.id_school) ?? {
                    namePart1: null,
                    namePart2: null,
                    fullName: `#${editing.id_school}`,
                  },
                )}
              </span>
            </div>
            <button type="button" className="btn-ghost btn-sm" onClick={() => setEditing(null)}>
              ปิด ✕
            </button>
          </div>
          <div className="flex flex-col gap-4 p-4 sm:p-5">
            <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end">
              <Field label="LINE Group ID ของโรงเรียน" hint="รหัสกลุ่มขึ้นต้นด้วย C (กลุ่ม), U (บุคคล) หรือ R (ห้อง)">
                <input
                  className="input font-mono text-[13px]"
                  value={editing.groupId ?? ''}
                  placeholder="C1234567890abcdef..."
                  onChange={(e) => setEditing({ ...editing, groupId: e.target.value })}
                />
              </Field>
              <label className="flex cursor-pointer items-center gap-2.5 rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2.5 text-[13px] font-semibold text-ink">
                <input
                  type="checkbox"
                  className="checkbox"
                  checked={editing.enabled}
                  onChange={(e) => setEditing({ ...editing, enabled: e.target.checked })}
                />
                เปิดแจ้งเตือนเมื่อมีใบลาใหม่
              </label>
            </div>
            <Field
              label="รูปแบบข้อความแจ้งเตือน (เว้นว่าง = ใช้ข้อความมาตรฐานของระบบ)"
              hint={`ตัวแปรที่ใช้แทนค่าได้: ${TEMPLATE_HINT}`}
            >
              <textarea
                className="input min-h-[130px] resize-y"
                value={editing.template ?? ''}
                placeholder="เว้นว่างไว้เพื่อใช้รูปแบบมาตรฐาน..."
                onChange={(e) => setEditing({ ...editing, template: e.target.value })}
              />
            </Field>
          </div>
          <div className="flex flex-wrap justify-end gap-2 border-t border-line bg-slate-50/70 px-4 py-3 sm:px-5">
            <button type="button" className="btn-secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button type="button" className="btn-secondary" disabled={busy} onClick={() => sendTest(editing)}>
              ส่งข้อความทดสอบ
            </button>
            <button type="button" className="btn-primary" disabled={busy} onClick={save}>
              บันทึกการตั้งค่า
            </button>
          </div>
        </section>
      )}

      {/* หมวดที่ 2: ตารางกลุ่ม LINE รายโรงเรียน */}
      <SectionHeader
        step="2"
        title="กลุ่ม LINE แจ้งเตือนแยกตามโรงเรียน"
        subtitle="กำหนด Group ID และสถานะการเปิดแจ้งเตือนของแต่ละโรงเรียน"
        badge={<span className="badge-green">เปิดใช้งาน {enabledCount}/{schools.length} โรงเรียน</span>}
      />
      <section className="card overflow-hidden">
        <div className="hidden overflow-x-auto md:block">
          <table className="table">
            <thead>
              <tr>
                <th>โรงเรียน</th>
                <th>Group ID</th>
                <th>รูปแบบข้อความ</th>
                <th>สถานะแจ้งเตือน</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {schools.map((s) => {
                const row = rowOf(s);
                return (
                  <tr key={s.id_school}>
                    <td className="font-semibold text-ink">{schoolName(s)}</td>
                    <td>
                      {row.groupId ? (
                        <code className="rounded bg-slate-100 px-2 py-0.5 font-mono text-xs text-slate-700">
                          {row.groupId.slice(0, 12)}…
                        </code>
                      ) : (
                        <span className="text-xs text-slate-400">ยังไม่ได้ระบุ</span>
                      )}
                    </td>
                    <td className="text-xs text-slate-500">
                      {row.template?.trim() ? 'กำหนดเอง' : 'ค่ามาตรฐาน'}
                    </td>
                    <td>{statusBadge(row)}</td>
                    <td className="text-right">
                      <button className="btn-secondary btn-sm" onClick={() => openEdit(row)}>
                        ตั้งค่ากลุ่ม
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
                  <div className="truncate font-semibold text-ink">{schoolName(s)}</div>
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
