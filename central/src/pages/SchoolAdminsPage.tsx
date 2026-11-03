import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { ADMIN_FUNCTION, ADMIN_ROLE_ID, functionError, schoolName, supabase, type School } from '../supabase';
import { EmptyState, Field, Notice, PageHeader, SectionHeader, StatCard } from '../ui/components';
import { IconPlus, IconSchool, IconSearch, IconShield, IconUserCheck } from '../ui/icons';

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
 * สร้างผ่าน Edge Function clever-responder คำสั่ง create_school_admin
 */
export default function SchoolAdminsPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [admins, setAdmins] = useState<AdminRow[]>([]);
  const [form, setForm] = useState({ id_school: '', username: '', fullName: '', password: '' });
  const [filterSchool, setFilterSchool] = useState<string>('');
  const [search, setSearch] = useState('');
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

  const schoolsWithoutAdmin = useMemo(
    () =>
      schools.filter(
        (s) => !admins.some((a) => !a.is_super_admin && a.id_school === s.id_school),
      ),
    [schools, admins],
  );

  const visibleAdmins = useMemo(() => {
    const q = search.trim().toLowerCase();
    return admins.filter((a) => {
      if (filterSchool && String(a.id_school) !== filterSchool) return false;
      if (!q) return true;
      return `${a.fullName ?? ''} ${a.username ?? ''} ${schoolNameOf(a.id_school)}`
        .toLowerCase()
        .includes(q);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [admins, filterSchool, search, schools]);

  return (
    <>
      <PageHeader
        category="2. องค์กรและบุคลากร"
        title="ผู้ดูแลระบบประจำโรงเรียน"
        description="จัดการบัญชีผู้ดูแลระบบของแต่ละโรงเรียน (สำหรับอนุมัติใบลา จัดการบุคลากร และตั้งค่าสิทธิ์รายคน)"
      />
      <Notice message={message} />

      {/* สรุปจำนวน */}
      <div className="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-3 lg:gap-4">
        <StatCard
          icon={<IconUserCheck className="h-4 w-4" />}
          label="ผู้ดูแลระบบทั้งหมด"
          value={admins.length}
          hint={`พร้อมเข้าระบบ ${admins.filter((a) => a.auth_uid || a.is_super_admin).length} คน`}
          tone="brand"
        />
        <StatCard
          icon={<IconShield className="h-4 w-4" />}
          label="ผู้ดูแลระดับโรงเรียน"
          value={admins.filter((a) => !a.is_super_admin).length}
          hint={`ผู้ดูแลส่วนกลาง ${admins.filter((a) => a.is_super_admin).length} คน`}
          tone="green"
        />
        <StatCard
          icon={<IconSchool className="h-4 w-4" />}
          label="โรงเรียนที่ยังไม่มีผู้ดูแล"
          value={schoolsWithoutAdmin.length}
          hint={
            schoolsWithoutAdmin.length > 0
              ? schoolsWithoutAdmin.map((s) => schoolName(s)).join(', ')
              : 'ทุกโรงเรียนมีผู้ดูแลครบแล้ว'
          }
          tone={schoolsWithoutAdmin.length > 0 ? 'amber' : 'green'}
        />
      </div>

      {/* หมวดที่ 1: สร้างผู้ดูแลระบบ */}
      <div className="mb-6">
        <SectionHeader
          step="1"
          title="สร้างบัญชีผู้ดูแลระบบใหม่ให้โรงเรียน"
          subtitle="ระบบจะสร้างทั้งข้อมูลบุคลากรและบัญชีเข้าสู่ระบบให้อัตโนมัติ"
        />
        <form className="card overflow-hidden" onSubmit={create}>
          <div className="grid gap-4 p-4 sm:grid-cols-2 sm:p-5 xl:grid-cols-4">
            <Field label="โรงเรียนที่สังกัด *">
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
            <Field label="ชื่อ - นามสกุล *">
              <input
                className="input"
                placeholder="เช่น นายสมชาย ใจดี"
                value={form.fullName}
                onChange={(e) => setForm({ ...form, fullName: e.target.value })}
                required
              />
            </Field>
            <Field label="ชื่อผู้ใช้ (Username) *" hint="ห้ามซ้ำทั้งระบบ · ใช้ a-z 0-9 . _ -">
              <input
                className="input"
                placeholder="เช่น admin_rpb"
                value={form.username}
                onChange={(e) => setForm({ ...form, username: e.target.value })}
                pattern="[A-Za-z0-9._\-]+"
                title="ใช้ได้เฉพาะ a-z 0-9 . _ -"
                autoComplete="off"
                required
              />
            </Field>
            <Field label="รหัสผ่านเริ่มต้น *" hint="ความยาวอย่างน้อย 6 ตัวอักษร">
              <input
                className="input"
                type="password"
                placeholder="••••••"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                autoComplete="new-password"
                required
              />
            </Field>
          </div>
          <div className="flex items-center justify-end border-t border-line bg-slate-50/70 px-4 py-3 sm:px-5">
            <button type="submit" className="btn-primary" disabled={busy}>
              <IconPlus className="h-4 w-4" />
              {busy ? 'กำลังสร้างบัญชี...' : 'สร้างผู้ดูแลระบบ'}
            </button>
          </div>
        </form>
      </div>

      {/* หมวดที่ 2: รายชื่อผู้ดูแล */}
      <SectionHeader
        step="2"
        title="รายชื่อผู้ดูแลระบบทั้งหมด"
        subtitle="ค้นหาและกรองรายชื่อผู้ดูแลแยกตามโรงเรียน"
      />
      <section className="card overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-slate-100 p-4 sm:flex-row sm:items-center sm:justify-between sm:px-5">
          <div className="flex flex-1 flex-col gap-2.5 sm:flex-row sm:items-center">
            <div className="relative sm:w-64">
              <IconSearch className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                className="input py-1.5 pl-9 text-[13px]"
                placeholder="ค้นหาชื่อ หรือ username..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <select
              className="input w-full py-1.5 text-[13px] sm:w-60"
              value={filterSchool}
              onChange={(e) => setFilterSchool(e.target.value)}
              aria-label="กรองตามโรงเรียน"
            >
              <option value="">ทุกโรงเรียน ({admins.length} คน)</option>
              {schools.map((s) => (
                <option key={s.id_school} value={String(s.id_school)}>
                  {schoolName(s)}
                </option>
              ))}
            </select>
          </div>
          <span className="badge-slate self-start sm:self-auto">แสดง {visibleAdmins.length} คน</span>
        </div>

        {visibleAdmins.length === 0 ? (
          <EmptyState>ไม่พบรายชื่อผู้ดูแลระบบ</EmptyState>
        ) : (
          <>
            <div className="hidden overflow-x-auto md:block">
              <table className="table">
                <thead>
                  <tr>
                    <th>ชื่อ - นามสกุล</th>
                    <th>ชื่อผู้ใช้ (Username)</th>
                    <th>โรงเรียน</th>
                    <th>สถานะบัญชี</th>
                  </tr>
                </thead>
                <tbody>
                  {visibleAdmins.map((a) => (
                    <tr key={a.id_user}>
                      <td className="font-semibold text-ink">{a.fullName || '-'}</td>
                      <td className="font-mono text-xs text-slate-600">{a.username || '-'}</td>
                      <td>{schoolNameOf(a.id_school)}</td>
                      <td>{status(a)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <ul className="divide-y divide-slate-100 md:hidden">
              {visibleAdmins.map((a) => (
                <li key={a.id_user} className="px-4 py-3.5">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate font-semibold text-ink">{a.fullName || '-'}</div>
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
