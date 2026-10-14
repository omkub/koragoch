import { useEffect, useState, type FormEvent } from 'react';
import { schoolName, supabase, type MobileUi, type School } from '../supabase';
import LeaveHeaderPreview from './LeaveHeaderPreview';

type SchoolForm = Omit<School, 'id_school' | 'fullName' | 'mobile_ui'>;

const MOBILE_UI_LABEL: Record<MobileUi, string> = {
  new: 'แบบใหม่ (แถบล่าง 4 ปุ่ม)',
  old: 'แบบเดิม (แถบล่าง 9 ปุ่ม)',
};

const EMPTY: SchoolForm = {
  namePart1: '',
  namePart2: '',
  address: '',
  affiliation: '',
  localCode: '',
  province: '',
  district: '',
  subdistrict: '',
};

const FIELDS: { key: keyof SchoolForm; label: string; hint?: string }[] = [
  { key: 'namePart1', label: 'ชื่อโรงเรียน (ส่วนแรก)', hint: 'เช่น โรงเรียนรมย์บุรีพิทยาคม' },
  { key: 'namePart2', label: 'ชื่อโรงเรียน (ส่วนหลัง)', hint: 'เช่น รัชมังคลาภิเษก — ไม่มีเว้นว่าง' },
  { key: 'address', label: 'ที่อยู่ (หัวใบลา)', hint: 'เว้นว่าง = ใช้ ตำบล/อำเภอ/จังหวัด ด้านล่าง' },
  { key: 'affiliation', label: 'สังกัด' },
  { key: 'province', label: 'จังหวัด' },
  { key: 'district', label: 'อำเภอ' },
  { key: 'subdistrict', label: 'ตำบล' },
  { key: 'localCode', label: 'รหัสโรงเรียน' },
];

/**
 * เพิ่ม/แก้ข้อมูลโรงเรียน
 * fullName ฐานข้อมูลคำนวณจาก namePart1 + namePart2 เอง (ส่งไปไม่ได้)
 * เพิ่มโรงเรียนได้เฉพาะผู้ดูแลส่วนกลาง (policy schools_insert)
 */
export default function SchoolsPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [editing, setEditing] = useState<number | 'new' | null>(null);
  const [form, setForm] = useState<SchoolForm>(EMPTY);
  const [mobileUi, setMobileUi] = useState<MobileUi>('new');
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  // ยังไม่รัน school_mobile_ui.sql = ไม่มีคอลัมน์ ส่งค่าไปจะบันทึกไม่ผ่านทั้งแถว
  const hasMobileUi = schools.some((s) => 'mobile_ui' in s);

  async function load() {
    const { data, error } = await supabase.from('Schools').select('*').order('id_school');
    if (error) setMessage({ text: error.message, error: true });
    else setSchools(data as School[]);
  }

  useEffect(() => {
    load();
  }, []);

  function startEdit(school: School | null) {
    setMessage(null);
    if (!school) {
      setEditing('new');
      setForm(EMPTY);
      setMobileUi('new');
      return;
    }
    setEditing(school.id_school);
    const next = { ...EMPTY };
    for (const f of FIELDS) next[f.key] = school[f.key] ?? '';
    setForm(next);
    setMobileUi(school.mobile_ui === 'old' ? 'old' : 'new');
  }

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!form.namePart1?.trim()) {
      setMessage({ text: 'กรุณากรอกชื่อโรงเรียน', error: true });
      return;
    }
    setBusy(true);
    const record: Record<string, string | null> = { updatedAt: new Date().toISOString() };
    for (const f of FIELDS) record[f.key] = form[f.key]?.trim() || null;
    if (hasMobileUi) record.mobile_ui = mobileUi;

    const { error } =
      editing === 'new'
        ? await supabase.from('Schools').insert(record)
        : await supabase.from('Schools').update(record).eq('id_school', editing as number);
    setBusy(false);

    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage({ text: editing === 'new' ? 'เพิ่มโรงเรียนแล้ว' : 'บันทึกแล้ว' });
    setEditing(null);
    load();
  }

  return (
    <>
      <div className="row">
        <h1>โรงเรียน</h1>
        <button onClick={() => startEdit(null)}>+ เพิ่มโรงเรียน</button>
      </div>
      {message && <div className={message.error ? 'error' : 'ok'}>{message.text}</div>}

      {editing !== null && (
        <form className="card form" onSubmit={save}>
          <h3>{editing === 'new' ? 'เพิ่มโรงเรียนใหม่' : 'แก้ไขข้อมูลโรงเรียน'}</h3>
          <div className="form-preview">
            <div className="grid">
              {FIELDS.map((f) => (
                <label key={f.key}>
                  {f.label}
                  <input
                    value={form[f.key] ?? ''}
                    placeholder={f.hint}
                    onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                  />
                </label>
              ))}
              <label>
                หน้าจอแอปบนมือถือ
                <select
                  value={mobileUi}
                  disabled={!hasMobileUi}
                  onChange={(e) => setMobileUi(e.target.value as MobileUi)}
                >
                  {(Object.keys(MOBILE_UI_LABEL) as MobileUi[]).map((k) => (
                    <option key={k} value={k}>
                      {MOBILE_UI_LABEL[k]}
                    </option>
                  ))}
                </select>
                <span className="small muted">
                  {hasMobileUi
                    ? 'ครูเห็นหน้าจอที่เปลี่ยนเมื่อเปิดแอปครั้งถัดไป · จอคอมไม่เปลี่ยน'
                    : 'ต้องรัน supabase/school_mobile_ui.sql ก่อน (ตอนนี้ทุกโรงเรียนใช้แบบใหม่)'}
                </span>
              </label>
            </div>
            {/* อัปเดตทันทีที่พิมพ์ — เห็นก่อนบันทึกว่าหัวใบลาจะออกมาหน้าตาแบบไหน */}
            <LeaveHeaderPreview school={{ ...form, fullName: null }} />
          </div>
          <div className="row end">
            <button type="button" className="secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button type="submit" disabled={busy}>{busy ? 'กำลังบันทึก...' : 'บันทึก'}</button>
          </div>
        </form>
      )}

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>ชื่อโรงเรียน</th>
              <th>สังกัด</th>
              <th>จังหวัด / อำเภอ / ตำบล</th>
              <th>หน้าจอมือถือ</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {schools.map((s) => (
              <tr key={s.id_school}>
                <td>{s.id_school}</td>
                <td>{schoolName(s)}</td>
                <td>{s.affiliation || '-'}</td>
                <td>{[s.province, s.district, s.subdistrict].filter(Boolean).join(' / ') || '-'}</td>
                <td>{s.mobile_ui === 'old' ? 'แบบเดิม' : 'แบบใหม่'}</td>
                <td className="num">
                  <button className="secondary small" onClick={() => startEdit(s)}>แก้ไข</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
