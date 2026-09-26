import { useEffect, useState, type FormEvent } from 'react';
import { supabase, type School } from '../supabase';

type SchoolForm = Omit<School, 'id_school' | 'fullName'>;

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
  { key: 'address', label: 'ที่อยู่ (หัวใบลา)' },
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
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

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
      return;
    }
    setEditing(school.id_school);
    const next = { ...EMPTY };
    for (const f of FIELDS) next[f.key] = school[f.key] ?? '';
    setForm(next);
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
          </div>
          <p className="muted">
            ชื่อเต็มในใบลา: <b>{[form.namePart1, form.namePart2].filter((s) => s?.trim()).join(' ') || '-'}</b>
          </p>
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
              <th />
            </tr>
          </thead>
          <tbody>
            {schools.map((s) => (
              <tr key={s.id_school}>
                <td>{s.id_school}</td>
                <td>{s.fullName || s.namePart1}</td>
                <td>{s.affiliation || '-'}</td>
                <td>{[s.province, s.district, s.subdistrict].filter(Boolean).join(' / ') || '-'}</td>
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
