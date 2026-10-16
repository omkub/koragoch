import { useEffect, useState, type FormEvent } from 'react';
import { ADMIN_FUNCTION, ADMIN_ROLE_ID, functionError, schoolName, supabase, type School } from '../supabase';
import { EmptyState, Field, Notice, PageHeader } from '../ui/components';

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

  const schoolNameOf = (id: number) => {
    const s = schools.find((x) => x.id_school === id);
    return s ? schoolName(s) : `#${id}`;
  };

  const status = (a: AdminRow) =>
    a.is_super_admin ? (
      <span className="badge-brand">ส่วนกลาง</span>
    ) : a.auth_uid ? (
      <span className="badge-green">พร้อมใช้งาน</span>
    ) : (
      <span className="badge-amber">ยังไม่มีบัญชีเข้าระบบ</span>
    );

  return (
    <>
      <PageHeader title="ผู้ดูแลโรงเรียน" description="บัญชีผู้ดูแลระบบของแต่ละโรงเรียน (อนุมัติใบลา / จัดการบุคลากรในแอป)" />
      <Notice message={message} />

      <form className="card mb-5" onSubmit={create}>
        <div className="card-title">สร้างผู้ดูแลระบบให้โรงเรียน</div>
        <div className="grid gap-4 px-4 pb-4 sm:grid-cols-2 sm:px-5 xl:grid-cols-4">
          <Field label="โรงเรียน">
            <select
              className="input"
              value={form.id_school}
              onChange={(e) => setForm({ ...form, id_school: e.target.value })}
              required
            >
              <option value="">— เลือกโรงเรียน —</option>
              {schools.map((s) => (
                <option key={s.id_school} value={s.id_school}>
                  {schoolName(s)}
                </option>
              ))}
            </select>
          </Field>
          <Field label="ชื่อ-นามสกุล">
            <input
              className="input"
              value={form.fullName}
              onChange={(e) => setForm({ ...form, fullName: e.target.value })}
              required
            />
          </Field>
          <Field label="ชื่อผู้ใช้" hint="ห้ามซ้ำทั้งระบบ · a-z 0-9 . _ -">
            <input
              className="input"
              value={form.username}
              onChange={(e) => setForm({ ...form, username: e.target.value })}
              pattern="[A-Za-z0-9._\-]+"
              title="ใช้ได้เฉพาะ a-z 0-9 . _ -"
              autoComplete="off"
              required
            />
          </Field>
          <Field label="รหัสผ่านเริ่มต้น" hint="อย่างน้อย 6 ตัว">
            <input
              className="input"
              type="password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              autoComplete="new-password"
              required
            />
          </Field>
        </div>
        <div className="flex justify-end border-t border-line px-4 py-3 sm:px-5">
          <button type="submit" className="btn-primary" disabled={busy}>
            {busy ? 'กำลังสร้าง...' : 'สร้างผู้ดูแลระบบ'}
          </button>
        </div>
      </form>

      <section className="card overflow-hidden">
        <div className="card-title">
          ผู้ดูแลระบบทั้งหมด
          <span className="text-xs font-medium text-slate-500">{admins.length} คน</span>
        </div>
        {admins.length === 0 ? (
          <EmptyState>ยังไม่มีผู้ดูแลระบบ</EmptyState>
        ) : (
          <>
            <div className="hidden overflow-x-auto md:block">
              <table className="table">
                <thead>
                  <tr>
                    <th>ชื่อ-นามสกุล</th>
                    <th>ชื่อผู้ใช้</th>
                    <th>โรงเรียน</th>
                    <th>สถานะ</th>
                  </tr>
                </thead>
                <tbody>
                  {admins.map((a) => (
                    <tr key={a.id_user}>
                      <td className="font-medium">{a.fullName}</td>
                      <td className="text-slate-600">{a.username}</td>
                      <td>{schoolNameOf(a.id_school)}</td>
                      <td>{status(a)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <ul className="divide-y divide-slate-100 md:hidden">
              {admins.map((a) => (
                <li key={a.id_user} className="px-4 py-3.5">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate font-medium">{a.fullName}</div>
                      <div className="truncate text-xs text-slate-500">
                        {a.username} · {schoolNameOf(a.id_school)}
                      </div>
                    </div>
                    {status(a)}
                  </div>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>
    </>
  );
}
