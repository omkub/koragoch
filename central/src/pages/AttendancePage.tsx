import { useEffect, useMemo, useState } from 'react';
import { schoolName, supabase, type School } from '../supabase';
import { EmptyState, Field, Notice, PageHeader } from '../ui/components';
import { IconPlus, IconSearch } from '../ui/icons';
import { SaveBar } from '../ui/PermMatrix';

interface Settings {
  id_school: number;
  enabled: boolean;
  work_start: string;
  late_after: string;
  work_end: string;
  require_checkout: boolean;
  // attendance_daily.sql
  start_date?: string | null;
  line_summary_enabled?: boolean;
  line_summary_time?: string;
  line_list_missing?: boolean;
  line_summary_sent_on?: string | null;
}

interface Device {
  id_device: number;
  id_school: number;
  name: string;
  location: string | null;
  brand: string | null;
  serial_no: string | null;
  device_key_hash: string | null;
  is_active: boolean;
  last_seen_at: string | null;
}

interface TeacherRow {
  id_user: number;
  fullName: string | null;
  username: string | null;
  device_code: string | null;
  attendance_exempt?: boolean;
}

type Message = { text: string; error?: boolean } | null;

const NEW_DEVICE: Omit<Device, 'id_device' | 'id_school'> = {
  name: '',
  location: null,
  brand: null,
  serial_no: null,
  device_key_hash: null,
  is_active: true,
  last_seen_at: null,
};

/** '08:00:00' → '08:00' (ช่อง <input type="time"> ต้องการแบบนี้) */
const hhmm = (t: string | null | undefined) => (t ?? '').slice(0, 5);

/** รหัสลับเครื่อง: สุ่ม 32 ไบต์ เข้ารหัส base64url (ยาว 43 ตัว) */
function randomDeviceKey(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/** sha256 เป็นเลขฐาน 16 — ต้องตรงกับที่ Edge Function attendance-ingest คำนวณ */
async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function thaiDateTime(iso: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleString('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Bangkok',
  });
}

/**
 * ลงเวลา (สแกนหน้า) — ตั้งค่าต่อโรงเรียน (เฉพาะผู้ดูแลส่วนกลาง)
 *
 *   1) เวลาเข้างาน / เกณฑ์สาย / เปิด-ปิดระบบ   → AttendanceSettings
 *   2) ทะเบียนเครื่องสแกน + ออกรหัสลับ           → AttendanceDevices
 *   3) จับคู่ครูกับรหัสในเครื่อง                   → Teachers.device_code
 *
 * สิทธิ์จริงคุมด้วย RLS (ดู supabase/attendance.sql)
 * รหัสลับเครื่องเก็บเป็น sha256 เท่านั้น แสดงรหัสจริงครั้งเดียวตอนออก
 */
export default function AttendancePage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [schoolId, setSchoolId] = useState<number | null>(null);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [devices, setDevices] = useState<Device[]>([]);
  const [teachers, setTeachers] = useState<TeacherRow[]>([]);
  const [codes, setCodes] = useState<Record<number, string>>({}); // id_user → รหัสที่กำลังแก้
  const [exempt, setExempt] = useState<Record<number, boolean>>({}); // id_user → ไม่ต้องสแกน
  const [unmatched, setUnmatched] = useState<Record<string, number>>({}); // รหัส → จำนวนสแกน
  const [editingDevice, setEditingDevice] = useState<Partial<Device> | null>(null);
  const [newKey, setNewKey] = useState<{ device: string; key: string } | null>(null);
  const [search, setSearch] = useState('');
  const [message, setMessage] = useState<Message>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    (async () => {
      const { data, error } = await supabase.from('Schools').select('*').order('id_school');
      if (error) {
        setMessage({ text: `โหลดไม่สำเร็จ: ${error.message}`, error: true });
        return;
      }
      setSchools(data as School[]);
      if (data?.length) setSchoolId((data[0] as School).id_school);
    })();
  }, []);

  async function load(id: number) {
    const [s, d, t, u] = await Promise.all([
      supabase.from('AttendanceSettings').select('*').eq('id_school', id).maybeSingle(),
      supabase.from('AttendanceDevices').select('*').eq('id_school', id).order('id_device'),
      supabase
        .from('Teachers')
        .select('*')
        .eq('id_school', id)
        .order('fullName'),
      supabase
        .from('AttendanceLogs')
        .select('device_code')
        .eq('id_school', id)
        .is('id_user', null)
        .limit(5000),
    ]);
    const failed = s.error ?? d.error ?? t.error ?? u.error;
    if (failed) {
      setMessage({ text: `โหลดไม่สำเร็จ: ${failed.message} (รัน attendance.sql แล้วหรือยัง?)`, error: true });
      return;
    }
    setSettings(
      (s.data as Settings | null) ?? {
        id_school: id,
        enabled: false,
        work_start: '08:00',
        late_after: '08:30',
        work_end: '16:30',
        require_checkout: false,
      },
    );
    setDevices(d.data as Device[]);
    const rows = t.data as TeacherRow[];
    setTeachers(rows);
    setCodes(Object.fromEntries(rows.map((r) => [r.id_user, r.device_code ?? ''])));
    setExempt(Object.fromEntries(rows.map((r) => [r.id_user, !!r.attendance_exempt])));
    const counts: Record<string, number> = {};
    for (const row of (u.data ?? []) as { device_code: string | null }[]) {
      if (row.device_code) counts[row.device_code] = (counts[row.device_code] ?? 0) + 1;
    }
    setUnmatched(counts);
  }

  useEffect(() => {
    if (schoolId === null) return;
    setMessage(null);
    setEditingDevice(null);
    setNewKey(null);
    load(schoolId);
  }, [schoolId]);

  // ─── 1) ตั้งค่าเวลา ─────────────────────────────────────────

  async function saveSettings() {
    if (!settings) return;
    const { work_start, late_after, work_end } = settings;
    if (!(hhmm(work_start) <= hhmm(late_after) && hhmm(late_after) < hhmm(work_end))) {
      setMessage({ text: 'เวลาต้องเรียงเป็น เข้างาน ≤ เริ่มนับสาย < เลิกงาน', error: true });
      return;
    }
    setBusy(true);
    // line_summary_sent_on ระบบเขียนเอง — ไม่ส่งทับ
    const values: Partial<Settings> = { ...settings };
    delete values.line_summary_sent_on;
    const { error } = await supabase.from('AttendanceSettings').upsert({
      ...values,
      start_date: values.start_date || null,
      updatedAt: new Date().toISOString(),
    });
    setBusy(false);
    setMessage(error ? { text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true } : { text: 'บันทึกการตั้งค่าแล้ว' });
  }

  /** ส่งสรุปของวันนี้เข้ากลุ่ม LINE ทันที (ไม่สนเวลาที่ตั้งไว้ / ไม่นับเป็นการส่งประจำวัน) */
  async function sendLineTest() {
    if (schoolId === null) return;
    setBusy(true);
    const { data, error } = await supabase.functions.invoke('attendance-daily-line', {
      body: { school: schoolId, test: true },
    });
    setBusy(false);
    const result = (data ?? {}) as { ok?: boolean; error?: string; message?: string };
    if (error || !result.ok) {
      setMessage({ text: `ส่งไม่สำเร็จ: ${result.error ?? error?.message ?? 'ไม่ทราบสาเหตุ'}`, error: true });
    } else {
      setMessage({ text: `ส่งเข้ากลุ่ม LINE แล้ว: ${result.message ?? ''}` });
    }
  }

  // ─── 2) เครื่องสแกน ─────────────────────────────────────────

  async function saveDevice() {
    if (!editingDevice || schoolId === null) return;
    const name = (editingDevice.name ?? '').trim();
    if (!name) {
      setMessage({ text: 'กรุณาตั้งชื่อเครื่อง', error: true });
      return;
    }
    const payload = {
      id_school: schoolId,
      name,
      location: editingDevice.location?.trim() || null,
      brand: editingDevice.brand?.trim() || null,
      serial_no: editingDevice.serial_no?.trim() || null,
      is_active: editingDevice.is_active ?? true,
    };
    setBusy(true);
    const isNew = !editingDevice.id_device;
    const { data, error } = isNew
      ? await supabase.from('AttendanceDevices').insert(payload).select().single()
      : await supabase
          .from('AttendanceDevices')
          .update(payload)
          .eq('id_device', editingDevice.id_device!)
          .select()
          .single();
    setBusy(false);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setEditingDevice(null);
    await load(schoolId);
    // เครื่องใหม่ออกรหัสให้เลย จะได้ไม่ลืม
    if (isNew) await issueKey(data as Device);
    else setMessage({ text: 'บันทึกข้อมูลเครื่องแล้ว' });
  }

  async function issueKey(device: Device) {
    if (
      device.device_key_hash &&
      !window.confirm(
        `ออกรหัสใหม่ให้ "${device.name}"?\nรหัสเดิมจะใช้ไม่ได้ทันที ต้องไปเปลี่ยนที่เครื่อง/ตัวเชื่อมด้วย`,
      )
    ) {
      return;
    }
    const key = randomDeviceKey();
    setBusy(true);
    const { error } = await supabase
      .from('AttendanceDevices')
      .update({ device_key_hash: await sha256Hex(key) })
      .eq('id_device', device.id_device);
    setBusy(false);
    if (error) {
      setMessage({ text: `ออกรหัสไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage(null);
    setNewKey({ device: device.name, key });
    if (schoolId !== null) load(schoolId);
  }

  async function deleteDevice(device: Device) {
    if (!window.confirm(`ลบเครื่อง "${device.name}"?\nประวัติการสแกนยังอยู่ครบ แต่เครื่องนี้จะส่งข้อมูลเข้าไม่ได้อีก`)) {
      return;
    }
    const { error } = await supabase.from('AttendanceDevices').delete().eq('id_device', device.id_device);
    setMessage(error ? { text: `ลบไม่สำเร็จ: ${error.message}`, error: true } : { text: 'ลบเครื่องแล้ว' });
    if (!error && schoolId !== null) load(schoolId);
  }

  // ─── 3) จับคู่ครูกับรหัสในเครื่อง ─────────────────────────────

  const changed = useMemo(
    () => teachers.filter((t) => (codes[t.id_user] ?? '').trim() !== (t.device_code ?? '')),
    [teachers, codes],
  );
  const exemptChanged = useMemo(
    () => teachers.filter((t) => !!exempt[t.id_user] !== !!t.attendance_exempt),
    [teachers, exempt],
  );

  const duplicateCodes = useMemo(() => {
    const seen = new Map<string, number>();
    for (const t of teachers) {
      const c = (codes[t.id_user] ?? '').trim();
      if (c) seen.set(c, (seen.get(c) ?? 0) + 1);
    }
    return new Set([...seen].filter(([, n]) => n > 1).map(([c]) => c));
  }, [teachers, codes]);

  const assignedCodes = useMemo(
    () => new Set(teachers.map((t) => (codes[t.id_user] ?? '').trim()).filter(Boolean)),
    [teachers, codes],
  );

  async function saveCodes() {
    if (duplicateCodes.size) {
      setMessage({ text: `รหัสซ้ำกัน: ${[...duplicateCodes].join(', ')}`, error: true });
      return;
    }
    setBusy(true);
    // ล้างรหัสที่ถูกย้าย/ลบก่อน แล้วค่อยใส่ใหม่ — กันชน unique ตอนสลับรหัสกันสองคน
    const cleared = changed.filter((t) => t.device_code);
    for (const t of cleared) {
      const { error } = await supabase.from('Teachers').update({ device_code: null }).eq('id_user', t.id_user);
      if (error) {
        setBusy(false);
        setMessage({ text: `บันทึก ${t.fullName} ไม่สำเร็จ: ${error.message}`, error: true });
        return;
      }
    }
    for (const t of exemptChanged) {
      const { error } = await supabase
        .from('Teachers')
        .update({ attendance_exempt: !!exempt[t.id_user] })
        .eq('id_user', t.id_user);
      if (error) {
        setBusy(false);
        setMessage({ text: `บันทึก ${t.fullName} ไม่สำเร็จ: ${error.message} (รัน attendance_daily.sql แล้วหรือยัง?)`, error: true });
        return;
      }
    }
    for (const t of changed) {
      const code = (codes[t.id_user] ?? '').trim();
      if (!code) continue;
      const { error } = await supabase.from('Teachers').update({ device_code: code }).eq('id_user', t.id_user);
      if (error) {
        setBusy(false);
        setMessage({ text: `บันทึก ${t.fullName} ไม่สำเร็จ: ${error.message}`, error: true });
        if (schoolId !== null) load(schoolId);
        return;
      }
    }
    setBusy(false);
    const dirtyCount = new Set([...changed, ...exemptChanged].map((t) => t.id_user)).size;
    setMessage({ text: `บันทึก ${dirtyCount} คนแล้ว (สแกนที่ค้างอยู่ถูกผูกให้อัตโนมัติ)` });
    if (schoolId !== null) load(schoolId);
  }

  const visibleTeachers = teachers.filter((t) => {
    const q = search.trim().toLowerCase();
    return !q || `${t.fullName ?? ''} ${t.username ?? ''} ${codes[t.id_user] ?? ''}`.toLowerCase().includes(q);
  });

  const pendingCodes = Object.entries(unmatched).filter(([code]) => !assignedCodes.has(code));

  const dirtyCount = changed.length + exemptChanged.length;
  const check = (checked: boolean, onChange: (v: boolean) => void, label: string) => (
    <label className="flex items-start gap-2.5 rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-[13px] font-medium">
      <input type="checkbox" className="checkbox mt-0.5" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span>{label}</span>
    </label>
  );
  const deviceBadges = (d: Device) => (
    <>
      {d.device_key_hash ? <span className="badge-green">มีรหัสแล้ว</span> : <span className="badge-amber">ยังไม่มีรหัส</span>}
      {d.is_active ? <span className="badge-green">ใช้งาน</span> : <span className="badge-slate">ปิด</span>}
    </>
  );
  const deviceActions = (d: Device) => (
    <div className="flex flex-wrap justify-end gap-1.5">
      <button
        className="btn-secondary btn-sm"
        onClick={() => {
          setMessage(null);
          setEditingDevice({ ...d });
        }}
      >
        แก้ไข
      </button>
      <button className="btn-secondary btn-sm" disabled={busy} onClick={() => issueKey(d)}>
        {d.device_key_hash ? 'ออกรหัสใหม่' : 'ออกรหัส'}
      </button>
      <button className="btn-danger btn-sm" onClick={() => deleteDevice(d)}>
        ลบ
      </button>
    </div>
  );

  return (
    <>
      <PageHeader
        title="ลงเวลา (สแกนหน้า)"
        description={'ระบบเก็บแค่ "ใคร สแกนเมื่อไร ที่เครื่องไหน" — ไม่เก็บภาพหรือข้อมูลใบหน้า (อยู่ในเครื่องสแกนเท่านั้น)'}
        actions={
          <select
            className="input w-auto max-w-full"
            value={schoolId ?? ''}
            onChange={(e) => setSchoolId(Number(e.target.value))}
            aria-label="เลือกโรงเรียน"
          >
            {schools.map((s) => (
              <option key={s.id_school} value={s.id_school}>
                {schoolName(s)}
              </option>
            ))}
          </select>
        }
      />
      <Notice message={message} />

      {newKey && (
        <section className="card mb-5 border-2 border-brand-500">
          <div className="card-title">รหัสลับของเครื่อง "{newKey.device}"</div>
          <div className="flex flex-col gap-3 px-4 pb-4 sm:px-5">
            <p className="text-[13px] text-slate-600">
              คัดลอกเก็บไว้ตอนนี้ — <b>รหัสนี้แสดงครั้งเดียว</b> ระบบเก็บแบบเข้ารหัสทางเดียว ดูย้อนหลังไม่ได้
              ถ้าทำหายให้กด "ออกรหัสใหม่"
            </p>
            <code className="select-all break-all rounded-lg bg-slate-100 px-3 py-2.5 font-mono text-[15px]">
              {newKey.key}
            </code>
            <div className="flex flex-wrap justify-end gap-2">
              <button
                className="btn-secondary"
                onClick={() =>
                  navigator.clipboard.writeText(newKey.key).then(() => setMessage({ text: 'คัดลอกรหัสแล้ว' }))
                }
              >
                คัดลอก
              </button>
              <button className="btn-primary" onClick={() => setNewKey(null)}>
                เก็บแล้ว ปิด
              </button>
            </div>
          </div>
        </section>
      )}

      {/* 1) ตั้งค่าเวลา + สรุป LINE */}
      {settings && (
        <section className="card mb-5">
          <div className="card-title">เวลาปฏิบัติราชการ</div>
          <div className="flex flex-col gap-4 px-4 pb-4 sm:px-5">
            {check(settings.enabled, (v) => setSettings({ ...settings, enabled: v }), 'เปิดใช้ระบบลงเวลาของโรงเรียนนี้')}
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <Field label="เวลาเข้างาน">
                <input
                  className="input"
                  type="time"
                  value={hhmm(settings.work_start)}
                  onChange={(e) => setSettings({ ...settings, work_start: e.target.value })}
                />
              </Field>
              <Field label="สแกนหลังเวลานี้ = สาย">
                <input
                  className="input"
                  type="time"
                  value={hhmm(settings.late_after)}
                  onChange={(e) => setSettings({ ...settings, late_after: e.target.value })}
                />
              </Field>
              <Field label="เวลาเลิกงาน">
                <input
                  className="input"
                  type="time"
                  value={hhmm(settings.work_end)}
                  onChange={(e) => setSettings({ ...settings, work_end: e.target.value })}
                />
              </Field>
              <Field label="วันเริ่มใช้ระบบจริง">
                <input
                  className="input"
                  type="date"
                  value={settings.start_date ?? ''}
                  onChange={(e) => setSettings({ ...settings, start_date: e.target.value || null })}
                />
              </Field>
            </div>
            {check(settings.require_checkout, (v) => setSettings({ ...settings, require_checkout: v }), 'ต้องสแกนออกด้วย')}
            <p className="field-hint">
              ปิดไว้ = ครูยังไม่เห็นเมนูลงเวลาใน app แต่เครื่องยังส่งข้อมูลเข้ามาเก็บได้ (ใช้ทดลองก่อนเปิดจริง) ·
              วันเริ่มใช้: ก่อนวันนี้ไม่นับว่า "ขาด" — เว้นว่าง = นับจากวันที่มีการสแกนครั้งแรก
            </p>

            <h4 className="mt-2 text-[13px] font-semibold text-slate-500">สรุปประจำวันทาง LINE</h4>
            <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_200px]">
              {check(
                !!settings.line_summary_enabled,
                (v) => setSettings({ ...settings, line_summary_enabled: v }),
                'ส่งสรุปเข้ากลุ่ม LINE ของโรงเรียนทุกวันทำการ',
              )}
              <Field label="เวลาที่ส่ง">
                <input
                  className="input"
                  type="time"
                  value={hhmm(settings.line_summary_time ?? '09:00')}
                  onChange={(e) => setSettings({ ...settings, line_summary_time: e.target.value })}
                />
              </Field>
            </div>
            {check(
              settings.line_list_missing ?? true,
              (v) => setSettings({ ...settings, line_list_missing: v }),
              'แนบรายชื่อคนที่ยังไม่สแกน',
            )}
            <p className="field-hint">
              ส่งเข้ากลุ่มที่ตั้งไว้ในหน้า "LINE แจ้งเตือน" เช่น "มา 45 · สาย 3 · ลา 2 · ไปราชการ 1 · ยังไม่สแกน 4" ·
              การส่งอัตโนมัติต้องรัน <code className="rounded bg-slate-100 px-1">attendance_line_cron.sql</code> ครั้งเดียว
              {settings.line_summary_sent_on ? ` · ส่งล่าสุด ${settings.line_summary_sent_on}` : ''}
            </p>
          </div>
          <div className="flex flex-wrap justify-end gap-2 border-t border-line px-4 py-3 sm:px-5">
            <button className="btn-secondary" disabled={busy} onClick={sendLineTest}>
              ทดลองส่งสรุปวันนี้
            </button>
            <button className="btn-primary" disabled={busy} onClick={saveSettings}>
              บันทึกการตั้งค่า
            </button>
          </div>
        </section>
      )}

      {/* 2) เครื่องสแกน */}
      <section className="card mb-5 overflow-hidden">
        <div className="card-title">
          เครื่องสแกน ({devices.length})
          <button
            className="btn-secondary btn-sm"
            onClick={() => {
              setMessage(null);
              setEditingDevice({ ...NEW_DEVICE });
            }}
          >
            <IconPlus className="h-3.5 w-3.5" /> ลงทะเบียนเครื่อง
          </button>
        </div>

        {editingDevice && (
          <div className="mx-4 mb-4 rounded-xl border border-slate-200 bg-slate-50 p-4 sm:mx-5">
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="ชื่อเครื่อง *">
                <input
                  className="input"
                  value={editingDevice.name ?? ''}
                  placeholder="เช่น หน้าอาคาร 1"
                  onChange={(e) => setEditingDevice({ ...editingDevice, name: e.target.value })}
                />
              </Field>
              <Field label="ตำแหน่งที่ติดตั้ง">
                <input
                  className="input"
                  value={editingDevice.location ?? ''}
                  onChange={(e) => setEditingDevice({ ...editingDevice, location: e.target.value })}
                />
              </Field>
              <Field label="ยี่ห้อ / รุ่น">
                <input
                  className="input"
                  value={editingDevice.brand ?? ''}
                  placeholder="เช่น ZKTeco SpeedFace"
                  onChange={(e) => setEditingDevice({ ...editingDevice, brand: e.target.value })}
                />
              </Field>
              <Field label="Serial No.">
                <input
                  className="input"
                  value={editingDevice.serial_no ?? ''}
                  onChange={(e) => setEditingDevice({ ...editingDevice, serial_no: e.target.value })}
                />
              </Field>
            </div>
            <div className="mt-4">
              {check(
                editingDevice.is_active ?? true,
                (v) => setEditingDevice({ ...editingDevice, is_active: v }),
                'ใช้งานอยู่ (ปิด = ไม่รับข้อมูลจากเครื่องนี้)',
              )}
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button className="btn-secondary" onClick={() => setEditingDevice(null)}>
                ยกเลิก
              </button>
              <button className="btn-primary" disabled={busy} onClick={saveDevice}>
                {editingDevice.id_device ? 'บันทึก' : 'ลงทะเบียน + ออกรหัส'}
              </button>
            </div>
          </div>
        )}

        {devices.length === 0 ? (
          <EmptyState>ยังไม่มีเครื่อง — ระหว่างนี้ใช้ "นำเข้าไฟล์" จาก app ได้</EmptyState>
        ) : (
          <>
            <div className="hidden overflow-x-auto lg:block">
              <table className="table">
                <thead>
                  <tr>
                    <th>ชื่อเครื่อง</th>
                    <th>ตำแหน่ง</th>
                    <th>ยี่ห้อ</th>
                    <th>สถานะ</th>
                    <th>ส่งข้อมูลล่าสุด</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {devices.map((d) => (
                    <tr key={d.id_device}>
                      <td className="font-semibold">{d.name}</td>
                      <td>{d.location ?? '-'}</td>
                      <td>{d.brand ?? '-'}</td>
                      <td>
                        <div className="flex flex-wrap gap-1">{deviceBadges(d)}</div>
                      </td>
                      <td className="whitespace-nowrap">{thaiDateTime(d.last_seen_at)}</td>
                      <td>{deviceActions(d)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <ul className="divide-y divide-slate-100 lg:hidden">
              {devices.map((d) => (
                <li key={d.id_device} className="flex flex-col gap-2 px-4 py-3.5">
                  <div>
                    <div className="font-semibold">{d.name}</div>
                    <div className="text-xs text-slate-500">
                      {[d.location, d.brand].filter(Boolean).join(' · ') || '-'} · ล่าสุด {thaiDateTime(d.last_seen_at)}
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-1">{deviceBadges(d)}</div>
                  {deviceActions(d)}
                </li>
              ))}
            </ul>
          </>
        )}
      </section>

      {/* 3) จับคู่ครูกับรหัสในเครื่อง */}
      <section className="card overflow-hidden">
        <div className="card-title flex-wrap">
          รหัสในเครื่องสแกน ({teachers.filter((t) => t.device_code).length}/{teachers.length} คน)
        </div>
        <div className="flex flex-col gap-3 px-4 pb-3 sm:px-5">
          <p className="field-hint">
            ใส่ "รหัสพนักงาน / User ID" ที่ตั้งไว้ในเครื่องสแกนให้ตรงกับครูแต่ละคน · ติ๊ก "ไม่ต้องสแกน"
            ให้บัญชีที่ไม่ใช่บุคลากรจริง (เช่น บัญชีกลาง) จะไม่ถูกนับในรายงาน
          </p>
          {pendingCodes.length > 0 && (
            <div className="alert-error text-[13px]">
              มีสแกนจากรหัสที่ยังไม่จับคู่: {pendingCodes.map(([code, n]) => `${code} (${n} ครั้ง)`).join(', ')} —
              ใส่รหัสให้ครูแล้วบันทึก ระบบจะผูกสแกนเหล่านี้ให้อัตโนมัติ
            </div>
          )}
          <div className="relative sm:w-72">
            <IconSearch className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className="input pl-9"
              placeholder="ค้นหาชื่อ / รหัส"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th>ชื่อ - สกุล</th>
                <th className="hidden sm:table-cell">ชื่อผู้ใช้</th>
                <th className="w-[140px] sm:w-[200px]">รหัสในเครื่อง</th>
                <th className="w-[90px] text-center">ไม่ต้องสแกน</th>
              </tr>
            </thead>
            <tbody>
              {visibleTeachers.map((t) => {
                const code = codes[t.id_user] ?? '';
                const dirty = code.trim() !== (t.device_code ?? '') || !!exempt[t.id_user] !== !!t.attendance_exempt;
                const dup = duplicateCodes.has(code.trim());
                return (
                  <tr key={t.id_user} className={dirty ? '[&>td]:!bg-amber-50' : undefined}>
                    <td className="min-w-[140px]">{t.fullName ?? '-'}</td>
                    <td className="hidden text-slate-500 sm:table-cell">{t.username ?? '-'}</td>
                    <td>
                      <input
                        className={`input py-1.5 ${dup ? '!border-red-400 !bg-red-50' : ''}`}
                        value={code}
                        placeholder="-"
                        onChange={(e) => setCodes({ ...codes, [t.id_user]: e.target.value })}
                      />
                    </td>
                    <td className="text-center">
                      <input
                        type="checkbox"
                        className="checkbox"
                        checked={!!exempt[t.id_user]}
                        onChange={(e) => setExempt({ ...exempt, [t.id_user]: e.target.checked })}
                      />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <SaveBar
          changed={dirtyCount}
          busy={busy}
          onReset={() => schoolId !== null && load(schoolId)}
          onSave={saveCodes}
        />
      </section>
    </>
  );
}
