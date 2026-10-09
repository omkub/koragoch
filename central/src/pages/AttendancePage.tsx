import { useEffect, useMemo, useState } from 'react';
import { schoolName, supabase, type School } from '../supabase';

interface Settings {
  id_school: number;
  enabled: boolean;
  work_start: string;
  late_after: string;
  work_end: string;
  require_checkout: boolean;
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
        .select('id_user, fullName, username, device_code')
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
    const { error } = await supabase.from('AttendanceSettings').upsert({
      ...settings,
      updatedAt: new Date().toISOString(),
    });
    setBusy(false);
    setMessage(error ? { text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true } : { text: 'บันทึกการตั้งค่าเวลาแล้ว' });
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
    setMessage({ text: `บันทึกรหัส ${changed.length} คนแล้ว (สแกนที่ค้างอยู่ถูกผูกให้อัตโนมัติ)` });
    if (schoolId !== null) load(schoolId);
  }

  const visibleTeachers = teachers.filter((t) => {
    const q = search.trim().toLowerCase();
    return !q || `${t.fullName ?? ''} ${t.username ?? ''} ${codes[t.id_user] ?? ''}`.toLowerCase().includes(q);
  });

  const pendingCodes = Object.entries(unmatched).filter(([code]) => !assignedCodes.has(code));

  return (
    <>
      <div className="row">
        <h1>ลงเวลา (สแกนหน้า)</h1>
        <select value={schoolId ?? ''} onChange={(e) => setSchoolId(Number(e.target.value))}>
          {schools.map((s) => (
            <option key={s.id_school} value={s.id_school}>
              {schoolName(s)}
            </option>
          ))}
        </select>
      </div>
      <p className="muted" style={{ marginBottom: 16 }}>
        ระบบเก็บแค่ "ใคร สแกนเมื่อไร ที่เครื่องไหน" — ไม่เก็บภาพหรือข้อมูลใบหน้า (อยู่ในเครื่องสแกนเท่านั้น)
      </p>

      {message && <div className={message.error ? 'error' : 'ok'}>{message.text}</div>}

      {newKey && (
        <div className="card form key-card">
          <h3>รหัสลับของเครื่อง "{newKey.device}"</h3>
          <p className="muted">
            คัดลอกเก็บไว้ตอนนี้ — <b>รหัสนี้แสดงครั้งเดียว</b> ระบบเก็บแบบเข้ารหัสทางเดียว ดูย้อนหลังไม่ได้
            ถ้าทำหายให้กด "ออกรหัสใหม่"
          </p>
          <div className="row" style={{ marginTop: 12, marginBottom: 0 }}>
            <code className="secret">{newKey.key}</code>
            <button
              className="secondary"
              onClick={() =>
                navigator.clipboard
                  .writeText(newKey.key)
                  .then(() => setMessage({ text: 'คัดลอกรหัสแล้ว' }))
              }
            >
              คัดลอก
            </button>
            <button onClick={() => setNewKey(null)}>เก็บแล้ว ปิด</button>
          </div>
        </div>
      )}

      {/* 1) ตั้งค่าเวลา */}
      {settings && (
        <div className="card form">
          <h3>เวลาปฏิบัติราชการ</h3>
          <div className="grid">
            <label className="check">
              <input
                type="checkbox"
                checked={settings.enabled}
                onChange={(e) => setSettings({ ...settings, enabled: e.target.checked })}
              />
              เปิดใช้ระบบลงเวลาของโรงเรียนนี้
            </label>
            <label>
              เวลาเข้างาน
              <input
                type="time"
                value={hhmm(settings.work_start)}
                onChange={(e) => setSettings({ ...settings, work_start: e.target.value })}
              />
            </label>
            <label>
              สแกนหลังเวลานี้ = สาย
              <input
                type="time"
                value={hhmm(settings.late_after)}
                onChange={(e) => setSettings({ ...settings, late_after: e.target.value })}
              />
            </label>
            <label>
              เวลาเลิกงาน
              <input
                type="time"
                value={hhmm(settings.work_end)}
                onChange={(e) => setSettings({ ...settings, work_end: e.target.value })}
              />
            </label>
            <label className="check">
              <input
                type="checkbox"
                checked={settings.require_checkout}
                onChange={(e) => setSettings({ ...settings, require_checkout: e.target.checked })}
              />
              ต้องสแกนออกด้วย
            </label>
          </div>
          <p className="muted">
            ปิดไว้ = ครูยังไม่เห็นเมนูลงเวลาใน app แต่เครื่องยังส่งข้อมูลเข้ามาเก็บได้ (ใช้ทดลองก่อนเปิดจริง)
          </p>
          <div className="row end">
            <button disabled={busy} onClick={saveSettings}>บันทึกการตั้งค่าเวลา</button>
          </div>
        </div>
      )}

      {/* 2) เครื่องสแกน */}
      <div className="card">
        <div className="row">
          <h3 style={{ margin: 0 }}>เครื่องสแกน ({devices.length})</h3>
          <button className="secondary small" onClick={() => { setMessage(null); setEditingDevice({ ...NEW_DEVICE }); }}>
            + ลงทะเบียนเครื่อง
          </button>
        </div>

        {editingDevice && (
          <div className="form sub-form">
            <div className="grid">
              <label>
                ชื่อเครื่อง *
                <input
                  value={editingDevice.name ?? ''}
                  placeholder="เช่น หน้าอาคาร 1"
                  onChange={(e) => setEditingDevice({ ...editingDevice, name: e.target.value })}
                />
              </label>
              <label>
                ตำแหน่งที่ติดตั้ง
                <input
                  value={editingDevice.location ?? ''}
                  onChange={(e) => setEditingDevice({ ...editingDevice, location: e.target.value })}
                />
              </label>
              <label>
                ยี่ห้อ / รุ่น
                <input
                  value={editingDevice.brand ?? ''}
                  placeholder="เช่น ZKTeco SpeedFace"
                  onChange={(e) => setEditingDevice({ ...editingDevice, brand: e.target.value })}
                />
              </label>
              <label>
                Serial No.
                <input
                  value={editingDevice.serial_no ?? ''}
                  onChange={(e) => setEditingDevice({ ...editingDevice, serial_no: e.target.value })}
                />
              </label>
              <label className="check">
                <input
                  type="checkbox"
                  checked={editingDevice.is_active ?? true}
                  onChange={(e) => setEditingDevice({ ...editingDevice, is_active: e.target.checked })}
                />
                ใช้งานอยู่ (ปิด = ไม่รับข้อมูลจากเครื่องนี้)
              </label>
            </div>
            <div className="row end">
              <button className="secondary" onClick={() => setEditingDevice(null)}>ยกเลิก</button>
              <button disabled={busy} onClick={saveDevice}>
                {editingDevice.id_device ? 'บันทึก' : 'ลงทะเบียน + ออกรหัส'}
              </button>
            </div>
          </div>
        )}

        {devices.length === 0 ? (
          <p className="muted">ยังไม่มีเครื่อง — ระหว่างนี้ใช้ "นำเข้าไฟล์" จาก app ได้</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>ชื่อเครื่อง</th>
                <th>ตำแหน่ง</th>
                <th>ยี่ห้อ</th>
                <th>รหัสลับ</th>
                <th>สถานะ</th>
                <th>ส่งข้อมูลล่าสุด</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {devices.map((d) => (
                <tr key={d.id_device}>
                  <td><b>{d.name}</b></td>
                  <td>{d.location ?? '-'}</td>
                  <td>{d.brand ?? '-'}</td>
                  <td>{d.device_key_hash ? <span className="badge on">ออกแล้ว</span> : <span className="warn">ยังไม่มี</span>}</td>
                  <td>{d.is_active ? <span className="badge on">ใช้งาน</span> : <span className="warn">ปิด</span>}</td>
                  <td>{thaiDateTime(d.last_seen_at)}</td>
                  <td className="num actions">
                    <button className="secondary small" onClick={() => { setMessage(null); setEditingDevice({ ...d }); }}>
                      แก้ไข
                    </button>
                    <button className="secondary small" disabled={busy} onClick={() => issueKey(d)}>
                      {d.device_key_hash ? 'ออกรหัสใหม่' : 'ออกรหัส'}
                    </button>
                    <button className="secondary small danger" onClick={() => deleteDevice(d)}>ลบ</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 3) จับคู่ครูกับรหัสในเครื่อง */}
      <div className="card">
        <div className="row">
          <h3 style={{ margin: 0 }}>
            รหัสในเครื่องสแกน ({teachers.filter((t) => t.device_code).length}/{teachers.length} คน)
          </h3>
          <div className="row" style={{ margin: 0 }}>
            <input placeholder="ค้นหาชื่อ / รหัส" value={search} onChange={(e) => setSearch(e.target.value)} />
            <button disabled={busy || changed.length === 0} onClick={saveCodes}>
              บันทึก{changed.length ? ` (${changed.length})` : ''}
            </button>
          </div>
        </div>
        <p className="muted" style={{ marginBottom: 12 }}>
          ใส่ "รหัสพนักงาน / User ID" ที่ตั้งไว้ในเครื่องสแกนให้ตรงกับครูแต่ละคน
        </p>

        {pendingCodes.length > 0 && (
          <div className="error">
            มีสแกนจากรหัสที่ยังไม่จับคู่:{' '}
            {pendingCodes.map(([code, n]) => `${code} (${n} ครั้ง)`).join(', ')}
            {' '}— ใส่รหัสให้ครูแล้วบันทึก ระบบจะผูกสแกนเหล่านี้ให้อัตโนมัติ
          </div>
        )}

        <table>
          <thead>
            <tr>
              <th>ชื่อ - สกุล</th>
              <th>ชื่อผู้ใช้</th>
              <th style={{ width: 200 }}>รหัสในเครื่อง</th>
            </tr>
          </thead>
          <tbody>
            {visibleTeachers.map((t) => {
              const code = codes[t.id_user] ?? '';
              const dirty = code.trim() !== (t.device_code ?? '');
              const dup = duplicateCodes.has(code.trim());
              return (
                <tr key={t.id_user} className={dirty ? 'dirty' : undefined}>
                  <td>{t.fullName ?? '-'}</td>
                  <td className="muted">{t.username ?? '-'}</td>
                  <td>
                    <input
                      className={dup ? 'invalid' : undefined}
                      value={code}
                      placeholder="-"
                      onChange={(e) => setCodes({ ...codes, [t.id_user]: e.target.value })}
                    />
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
