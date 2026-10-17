import { useEffect, useMemo, useState } from 'react';
import { schoolName, supabase, type Role, type School } from '../supabase';
import { EmptyState, Field, Notice, PageHeader } from '../ui/components';
import { IconSearch } from '../ui/icons';

type EmploymentStatus = 'active' | 'resigned' | 'retired' | 'transferred';

const STATUS_LABEL: Record<EmploymentStatus, string> = {
  active: 'ปฏิบัติงาน',
  resigned: 'ลาออก',
  retired: 'เกษียณ',
  transferred: 'ย้าย',
};

interface StaffRow {
  id_user: number;
  fullName: string | null;
  username: string | null;
  id_role: number | null;
  is_super_admin: boolean | null;
  employment_status?: EmploymentStatus | null;
  left_date?: string | null;
}

const BASE_COLUMNS = 'id_user, fullName, username, id_role, is_super_admin';

const today = () => new Date().toISOString().slice(0, 10);

/** 2026-09-30 → 30 ก.ย. 2569 */
function thaiDate(iso: string | null | undefined) {
  if (!iso) return '';
  const d = new Date(`${iso}T00:00:00`);
  return Number.isNaN(d.getTime())
    ? iso
    : d.toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' });
}

/**
 * บุคลากรของแต่ละโรงเรียน — ตั้งสถานะ ลาออก / เกษียณ / ย้าย (supabase/staff_status.sql)
 *
 * ไม่ลบรายชื่อ ใบลาเก่ายังอยู่ครบ คนพ้นสภาพเข้าระบบไม่ได้ ไม่ขึ้นในรายชื่อที่ใช้ทำงาน
 * และรายงานนับเฉพาะปีงบประมาณที่ยังปฏิบัติงาน — แอดมินโรงเรียนตั้งได้จากแอปเช่นกัน
 */
export default function StaffPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [schoolId, setSchoolId] = useState<number | null>(null);
  const [staff, setStaff] = useState<StaffRow[]>([]);
  const [hasStatus, setHasStatus] = useState(true);
  const [showInactive, setShowInactive] = useState(false);
  const [search, setSearch] = useState('');
  const [editing, setEditing] = useState<{ row: StaffRow; status: EmploymentStatus; left: string } | null>(null);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    (async () => {
      const [s, r] = await Promise.all([
        supabase.from('Schools').select('*').order('id_school'),
        supabase.from('roles').select('ID_Roles, Accessrights').order('ID_Roles'),
      ]);
      if (s.error) {
        setMessage({ text: s.error.message, error: true });
        return;
      }
      setSchools(s.data as School[]);
      if (!r.error) setRoles(r.data as Role[]);
      if (s.data?.length) setSchoolId((s.data[0] as School).id_school);
    })();
  }, []);

  const fetchStaff = (id: number, columns: string) =>
    supabase.from('Teachers').select(columns).eq('id_school', id).order('fullName');

  async function load(id: number) {
    let res = await fetchStaff(id, `${BASE_COLUMNS}, employment_status, left_date`);
    let statusColumns = true;
    if (res.error && res.error.message.includes('employment_status')) {
      // ยังไม่ได้รัน staff_status.sql — แสดงรายชื่อได้ แต่ตั้งสถานะไม่ได้
      statusColumns = false;
      res = await fetchStaff(id, BASE_COLUMNS);
    }
    if (res.error) {
      setMessage({ text: res.error.message, error: true });
      return;
    }
    setHasStatus(statusColumns);
    setStaff((res.data as unknown as StaffRow[]).filter((t) => !t.is_super_admin));
  }

  useEffect(() => {
    if (schoolId !== null) {
      setMessage(null);
      setEditing(null);
      load(schoolId);
    }
  }, [schoolId]);

  const statusOf = (t: StaffRow): EmploymentStatus => t.employment_status ?? 'active';
  const inactiveCount = staff.filter((t) => statusOf(t) !== 'active').length;
  const roleName = (id: number | null) => roles.find((r) => r.ID_Roles === id)?.Accessrights ?? '-';

  const visible = useMemo(() => {
    const q = search.trim().toLowerCase();
    return staff.filter(
      (t) =>
        (showInactive || statusOf(t) === 'active') &&
        (!q || `${t.fullName ?? ''} ${t.username ?? ''}`.toLowerCase().includes(q)),
    );
  }, [staff, showInactive, search]);

  async function save() {
    if (!editing) return;
    setBusy(true);
    const active = editing.status === 'active';
    const { error } = await supabase
      .from('Teachers')
      .update({ employment_status: editing.status, left_date: active ? null : editing.left || today() })
      .eq('id_user', editing.row.id_user);
    setBusy(false);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage({
      text: active
        ? `คืนสถานะปฏิบัติงานให้ ${editing.row.fullName} แล้ว`
        : `ตั้ง ${editing.row.fullName} เป็น ${STATUS_LABEL[editing.status]} แล้ว`,
    });
    setEditing(null);
    if (schoolId !== null) load(schoolId);
  }

  const statusBadge = (t: StaffRow) => {
    const status = statusOf(t);
    return status === 'active' ? (
      <span className="badge-green">ปฏิบัติงาน</span>
    ) : (
      <span className="badge-slate">
        {STATUS_LABEL[status]} {thaiDate(t.left_date)}
      </span>
    );
  };
  const editButton = (t: StaffRow) => {
    const status = statusOf(t);
    return (
      <button
        className="btn-secondary btn-sm"
        disabled={!hasStatus}
        onClick={() => setEditing({ row: t, status, left: t.left_date ?? today() })}
      >
        {status === 'active' ? 'พ้นสภาพ' : 'แก้สถานะ'}
      </button>
    );
  };

  return (
    <>
      <PageHeader
        title="บุคลากร"
        description="ตั้งสถานะ ลาออก / เกษียณ / ย้าย — ไม่ลบรายชื่อ ใบลาเก่ายังอยู่ครบ · คนพ้นสภาพเข้าระบบไม่ได้ และรายงานนับเฉพาะปีงบประมาณที่ยังปฏิบัติงาน"
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
      {!hasStatus && <div className="alert-error mb-4">ยังตั้งสถานะไม่ได้ — ต้องรัน supabase/staff_status.sql ก่อน</div>}
      <Notice message={message} />

      {editing && (
        <div className="card mb-5">
          <div className="card-title">สถานะ: {editing.row.fullName}</div>
          <div className="grid gap-4 px-4 pb-4 sm:grid-cols-2 sm:px-5">
            <Field label="สถานะ">
              <select
                className="input"
                value={editing.status}
                onChange={(e) => setEditing({ ...editing, status: e.target.value as EmploymentStatus })}
              >
                {(Object.keys(STATUS_LABEL) as EmploymentStatus[]).map((s) => (
                  <option key={s} value={s}>
                    {STATUS_LABEL[s]}
                  </option>
                ))}
              </select>
            </Field>
            {editing.status !== 'active' && (
              <Field label="พ้นสภาพตั้งแต่วันที่" hint="วันแรกที่ไม่ได้ปฏิบัติงาน เช่น เกษียณ 1 ต.ค.">
                <input
                  className="input"
                  type="date"
                  value={editing.left}
                  onChange={(e) => setEditing({ ...editing, left: e.target.value })}
                />
              </Field>
            )}
          </div>
          <div className="flex justify-end gap-2 border-t border-line px-4 py-3 sm:px-5">
            <button className="btn-secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button className="btn-primary" disabled={busy} onClick={save}>
              {busy ? 'กำลังบันทึก...' : 'บันทึก'}
            </button>
          </div>
        </div>
      )}

      <section className="card overflow-hidden">
        <div className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between sm:px-5">
          <div className="relative sm:w-72">
            <IconSearch className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className="input pl-9"
              placeholder="ค้นหาชื่อ หรือ username"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <label className="flex items-center gap-2 text-[13px] font-medium text-slate-600">
            <input
              type="checkbox"
              className="checkbox"
              checked={showInactive}
              onChange={(e) => setShowInactive(e.target.checked)}
            />
            แสดงคนพ้นสภาพ ({inactiveCount})
          </label>
        </div>

        {visible.length === 0 ? (
          <EmptyState>ไม่พบบุคลากร</EmptyState>
        ) : (
          <>
            <div className="hidden overflow-x-auto md:block">
              <table className="table">
                <thead>
                  <tr>
                    <th>ชื่อ-นามสกุล</th>
                    <th>Username</th>
                    <th>สิทธิ์</th>
                    <th>สถานะ</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {visible.map((t) => (
                    <tr key={t.id_user} className={statusOf(t) === 'active' ? '' : 'text-slate-400'}>
                      <td className="font-medium">{t.fullName || '-'}</td>
                      <td>{t.username || '-'}</td>
                      <td>{roleName(t.id_role)}</td>
                      <td>{statusBadge(t)}</td>
                      <td className="text-right">{editButton(t)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <ul className="divide-y divide-slate-100 md:hidden">
              {visible.map((t) => (
                <li key={t.id_user} className="flex items-center gap-3 px-4 py-3">
                  <div className="min-w-0 flex-1">
                    <div className={`truncate font-medium ${statusOf(t) === 'active' ? '' : 'text-slate-400'}`}>
                      {t.fullName || '-'}
                    </div>
                    <div className="mt-0.5 flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
                      {roleName(t.id_role)} {statusOf(t) !== 'active' && statusBadge(t)}
                    </div>
                  </div>
                  {editButton(t)}
                </li>
              ))}
            </ul>
          </>
        )}
      </section>
    </>
  );
}
