import { useEffect, useMemo, useState } from 'react';
import { schoolName, supabase, type Role, type School } from '../supabase';
import { EmptyState, Field, Notice, PageHeader, SectionHeader, StatCard } from '../ui/components';
import { IconClock, IconSearch, IconUserCheck, IconUsers } from '../ui/icons';
import { isWorkingToday, todayTh } from '../staffStatus';

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
  const working = (t: StaffRow) => isWorkingToday(t.employment_status, t.left_date);
  const scheduled = (t: StaffRow) => statusOf(t) !== 'active' && working(t);
  const workingCount = staff.filter((t) => working(t)).length;
  const scheduledCount = staff.filter((t) => scheduled(t)).length;
  const inactiveCount = staff.filter((t) => !working(t)).length;
  const roleName = (id: number | null) => roles.find((r) => r.ID_Roles === id)?.Accessrights ?? '-';

  const visible = useMemo(() => {
    const q = search.trim().toLowerCase();
    return staff.filter(
      (t) =>
        (showInactive || working(t)) &&
        (!q || `${t.fullName ?? ''} ${t.username ?? ''}`.toLowerCase().includes(q)),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [staff, showInactive, search]);

  async function save() {
    if (!editing) return;
    setBusy(true);
    const active = editing.status === 'active';
    const left = active ? null : editing.left || todayTh();
    const { error } = await supabase
      .from('Teachers')
      .update({ employment_status: editing.status, left_date: left })
      .eq('id_user', editing.row.id_user);
    setBusy(false);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage({
      text: active
        ? `คืนสถานะปฏิบัติงานให้ ${editing.row.fullName} แล้ว`
        : isWorkingToday(editing.status, left)
          ? `${editing.row.fullName} จะเป็น ${STATUS_LABEL[editing.status]} ตั้งแต่ ${thaiDate(left)}`
          : `ตั้ง ${editing.row.fullName} เป็น ${STATUS_LABEL[editing.status]} แล้ว`,
    });
    setEditing(null);
    if (schoolId !== null) load(schoolId);
  }

  const statusBadge = (t: StaffRow) => {
    const status = statusOf(t);
    if (status === 'active') return <span className="badge-green">ปฏิบัติงาน</span>;
    if (scheduled(t)) {
      return (
        <span className="badge-amber">
          {STATUS_LABEL[status]} (มีผล {thaiDate(t.left_date)})
        </span>
      );
    }
    return (
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
        onClick={() => {
          setEditing({ row: t, status, left: t.left_date ?? todayTh() });
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }}
      >
        {status === 'active' ? 'ตั้งพ้นสภาพ' : 'แก้ไขสถานะ'}
      </button>
    );
  };

  return (
    <>
      <PageHeader
        category="2. องค์กรและบุคลากร"
        title="จัดการสถานะบุคลากร"
        description="ตั้งสถานะ ปฏิบัติงาน / ลาออก / เกษียณ / ย้าย โดยไม่ลบรายชื่อ (ประวัติใบลาเดิมอยู่ครบ แต่ผู้พ้นสภาพจะเข้าแอปไม่ได้)"
        actions={
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-slate-500">โรงเรียน:</span>
            <select
              className="input w-auto max-w-full font-medium"
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
          </div>
        }
      />
      {!hasStatus && <div className="alert-error mb-4">ยังตั้งสถานะไม่ได้ — ต้องรัน supabase/staff_status.sql ก่อน</div>}
      <Notice message={message} />

      {/* สรุปจำนวนบุคลากรในโรงเรียนที่เลือก */}
      <div className="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-3 lg:gap-4">
        <StatCard
          icon={<IconUserCheck className="h-4 w-4" />}
          label="กำลังปฏิบัติงานวันนี้"
          value={workingCount}
          hint="เข้าระบบและนับในรายงานปกติ"
          tone="green"
        />
        <StatCard
          icon={<IconClock className="h-4 w-4" />}
          label="ตั้งพ้นสภาพล่วงหน้า"
          value={scheduledCount}
          hint="ยังปฏิบัติงานจนถึงวันที่มีผล"
          tone={scheduledCount > 0 ? 'amber' : 'slate'}
        />
        <StatCard
          icon={<IconUsers className="h-4 w-4" />}
          label="พ้นสภาพแล้ว (ลาออก/เกษียณ/ย้าย)"
          value={inactiveCount}
          hint="เก็บประวัติใบลาไว้ แต่เข้าระบบไม่ได้"
          tone="slate"
        />
      </div>

      {/* กล่องแก้ไขสถานะ */}
      {editing && (
        <div className="card mb-6 overflow-hidden border-brand-200">
          <div className="card-title bg-brand-50/40">
            <div className="flex items-center gap-2">
              <span className="badge-brand">แก้ไขสถานะ</span>
              <span>{editing.row.fullName}</span>
            </div>
            <button className="btn-ghost btn-sm" onClick={() => setEditing(null)}>
              ปิด ✕
            </button>
          </div>
          <div className="grid gap-4 p-4 sm:grid-cols-2 sm:p-5">
            <Field label="สถานะการปฏิบัติงาน">
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
              <Field
                label="วันที่มีผลพ้นสภาพ"
                hint="วันแรกที่ไม่ได้ปฏิบัติงาน เช่น เกษียณ 1 ต.ค. — ก่อนถึงวันนั้นยังเข้าระบบได้ตามปกติ"
              >
                <input
                  className="input"
                  type="date"
                  value={editing.left}
                  onChange={(e) => setEditing({ ...editing, left: e.target.value })}
                />
              </Field>
            )}
          </div>
          <div className="flex justify-end gap-2 border-t border-line bg-slate-50/70 px-4 py-3 sm:px-5">
            <button className="btn-secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button className="btn-primary" disabled={busy} onClick={save}>
              {busy ? 'กำลังบันทึก...' : 'บันทึกสถานะ'}
            </button>
          </div>
        </div>
      )}

      {/* ตารางรายชื่อบุคลากร */}
      <SectionHeader
        title="รายชื่อบุคลากรในโรงเรียน"
        subtitle="ค้นหาตามชื่อ หรือสลับดูรายชื่อผู้ที่พ้นสภาพไปแล้ว"
      />
      <section className="card overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-slate-100 p-4 sm:flex-row sm:items-center sm:justify-between sm:px-5">
          <div className="relative sm:w-72">
            <IconSearch className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className="input py-1.5 pl-9 text-[13px]"
              placeholder="ค้นหาชื่อ-สกุล หรือ username..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="seg">
            <button
              type="button"
              className={!showInactive ? 'active' : ''}
              onClick={() => setShowInactive(false)}
            >
              เฉพาะปฏิบัติงาน ({workingCount})
            </button>
            <button
              type="button"
              className={showInactive ? 'active' : ''}
              onClick={() => setShowInactive(true)}
            >
              รวมคนพ้นสภาพ ({staff.length})
            </button>
          </div>
        </div>

        {visible.length === 0 ? (
          <EmptyState>ไม่พบบุคลากรตามเงื่อนไขที่เลือก</EmptyState>
        ) : (
          <>
            <div className="hidden overflow-x-auto md:block">
              <table className="table">
                <thead>
                  <tr>
                    <th>ชื่อ - นามสกุล</th>
                    <th>ชื่อผู้ใช้ (Username)</th>
                    <th>สิทธิ์ในระบบ</th>
                    <th>สถานะการทำงาน</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {visible.map((t) => (
                    <tr key={t.id_user} className={working(t) ? '' : 'text-slate-400'}>
                      <td className="font-semibold">{t.fullName || '-'}</td>
                      <td className="font-mono text-xs">{t.username || '-'}</td>
                      <td>
                        <span className="badge-slate">{roleName(t.id_role)}</span>
                      </td>
                      <td>{statusBadge(t)}</td>
                      <td className="text-right">{editButton(t)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <ul className="divide-y divide-slate-100 md:hidden">
              {visible.map((t) => (
                <li key={t.id_user} className="flex items-center gap-3 px-4 py-3.5">
                  <div className="min-w-0 flex-1">
                    <div className={`truncate font-semibold ${working(t) ? 'text-ink' : 'text-slate-400'}`}>
                      {t.fullName || '-'}
                    </div>
                    <div className="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
                      <span className="badge-slate">{roleName(t.id_role)}</span>
                      {statusBadge(t)}
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
