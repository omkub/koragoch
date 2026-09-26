import { useEffect, useState, type FormEvent } from 'react';
import { ADMIN_FUNCTION, ADMIN_ROLE_ID, functionError, supabase, type School } from '../supabase';

interface AdminRow {
  id_user: number;
  username: string | null;
  fullName: string | null;
  id_school: number;
  is_super_admin: boolean | null;
  auth_uid: string | null;
}

/**
 * ผู้ดูแลระบบของแต่ละโรงเรียน (Teachers.id_role = 22)
 *
 * สร้างผ่าน Edge Function clever-responder คำสั่ง create_school_admin
 * เพราะต้องสร้างบัญชี Supabase Auth ด้วย (ทำจากเว็บตรง ๆ ไม่ได้)
 */
export default function SchoolAdminsPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [admins, setAdmins] = useState<AdminRow[]>([]);
  const [form, setForm] = useState({ id_school: '', username: '', fullName: '', password: '' });
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    const [s, a] = await Promise.all([
      supabase.from('Schools').select('*').order('id_school'),
      supabase
        .from('Teachers')
        .select('id_user, username, fullName, id_school, is_super_admin, auth_uid')
        .eq('id_role', ADMIN_ROLE_ID)
        .order('id_school'),
    ]);
    if (s.error || a.error) {
      setMessage({ text: (s.error ?? a.error)!.message, error: true });
      return;
    }
    setSchools(s.data as School[]);
    setAdmins(a.data as AdminRow[]);
  }

  useEffect(() => {
    load();
  }, []);

  async function create(e: FormEvent) {
    e.preventDefault();
    setMessage(null);
    if (form.password.length < 6) {
      setMessage({ text: 'รหัสผ่านต้องยาวอย่างน้อย 6 ตัว', error: true });
      return;
    }
    setBusy(true);
    const { data, error } = await supabase.functions.invoke(ADMIN_FUNCTION, {
      body: {
        action: 'create_school_admin',
        id_school: Number(form.id_school),
        username: form.username.trim(),
        fullName: form.fullName.trim(),
        password: form.password,
      },
    });
    setBusy(false);
    if (error) {
      setMessage({ text: `สร้างไม่สำเร็จ: ${await functionError(error)}`, error: true });
      return;
    }
    setMessage({ text: `สร้างผู้ดูแลระบบ "${form.username}" แล้ว (id_user ${data?.id_user})` });
    setForm({ ...form, username: '', fullName: '', password: '' });
    load();
  }

  const schoolName = (id: number) => {
    const s = schools.find((x) => x.id_school === id);
    return s ? s.fullName || s.namePart1 : `#${id}`;
  };

  return (
    <>
      <h1>ผู้ดูแลโรงเรียน</h1>
      {message && <div className={message.error ? 'error' : 'ok'}>{message.text}</div>}

      <form className="card form" onSubmit={create}>
        <h3>สร้างผู้ดูแลระบบให้โรงเรียน</h3>
        <div className="grid">
          <label>
            โรงเรียน
            <select
              value={form.id_school}
              onChange={(e) => setForm({ ...form, id_school: e.target.value })}
              required
            >
              <option value="">— เลือกโรงเรียน —</option>
              {schools.map((s) => (
                <option key={s.id_school} value={s.id_school}>
                  {s.fullName || s.namePart1}
                </option>
              ))}
            </select>
          </label>
          <label>
            ชื่อ-นามสกุล
            <input value={form.fullName} onChange={(e) => setForm({ ...form, fullName: e.target.value })} required />
          </label>
          <label>
            ชื่อผู้ใช้ (ห้ามซ้ำทั้งระบบ)
            <input
              value={form.username}
              onChange={(e) => setForm({ ...form, username: e.target.value })}
              pattern="[A-Za-z0-9._\-]+"
              title="ใช้ได้เฉพาะ a-z 0-9 . _ -"
              required
            />
          </label>
          <label>
            รหัสผ่านเริ่มต้น
            <input
              type="password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              required
            />
          </label>
        </div>
        <div className="row end">
          <button type="submit" disabled={busy}>{busy ? 'กำลังสร้าง...' : 'สร้างผู้ดูแลระบบ'}</button>
        </div>
      </form>

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>โรงเรียน</th>
              <th>ชื่อผู้ใช้</th>
              <th>ชื่อ-นามสกุล</th>
              <th>สถานะ</th>
            </tr>
          </thead>
          <tbody>
            {admins.map((a) => (
              <tr key={a.id_user}>
                <td>{schoolName(a.id_school)}</td>
                <td>{a.username}</td>
                <td>{a.fullName}</td>
                <td>
                  {a.is_super_admin ? (
                    <span className="badge">ส่วนกลาง</span>
                  ) : a.auth_uid ? (
                    'พร้อมใช้งาน'
                  ) : (
                    <span className="warn">ยังไม่มีบัญชีเข้าระบบ</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
