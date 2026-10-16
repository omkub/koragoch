import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ADMIN_ROLE_ID, schoolName, supabase, type School } from '../supabase';
import { EmptyState, PageHeader, StatCard } from '../ui/components';
import { IconAlert, IconChat, IconDoc, IconSchool, IconUsers, IconClock } from '../ui/icons';
import SchoolLogo from '../ui/SchoolLogo';

interface SchoolStats {
  school: School;
  teachers: number;
  admins: number;
  leaves: number;
  pending: number;
  line: boolean | null; // null = อ่านค่าไม่ได้
}

const PENDING = ['รอพิจารณา', 'ยังไม่ส่ง'];

/** ภาพรวมทุกโรงเรียน — RLS ให้ผู้ดูแลส่วนกลางอ่านได้ทุกแถว */
export default function DashboardPage() {
  const [rows, setRows] = useState<SchoolStats[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const [schools, teachers, leaves, line] = await Promise.all([
        supabase.from('Schools').select('*').order('id_school'),
        supabase.from('Teachers').select('id_school, id_role, is_super_admin, employment_status'),
        supabase.from('Leaves').select('id_school, status'),
        supabase.from('SchoolLineSettings').select('id_school, enabled, groupId'),
      ]);
      const failed = schools.error ?? teachers.error ?? leaves.error;
      if (failed) {
        setError(failed.message);
        return;
      }
      setRows(
        (schools.data as School[]).map((school) => {
          const t = (teachers.data ?? []).filter(
            (x) =>
              x.id_school === school.id_school &&
              !x.is_super_admin &&
              (x.employment_status ?? 'active') === 'active',
          );
          const l = (leaves.data ?? []).filter((x) => x.id_school === school.id_school);
          const ln = line.error ? null : (line.data ?? []).find((x) => x.id_school === school.id_school);
          return {
            school,
            teachers: t.length,
            admins: t.filter((x) => x.id_role === ADMIN_ROLE_ID).length,
            leaves: l.length,
            pending: l.filter((x) => PENDING.includes(String(x.status ?? ''))).length,
            line: line.error ? null : Boolean(ln?.enabled && String(ln?.groupId ?? '').trim()),
          };
        }),
      );
    })();
  }, []);

  if (error) return <div className="alert-error">โหลดข้อมูลไม่สำเร็จ: {error}</div>;

  const total = (key: 'teachers' | 'leaves' | 'pending') => (rows ?? []).reduce((sum, r) => sum + r[key], 0);
  const maxLeaves = Math.max(1, ...(rows ?? []).map((r) => r.leaves));

  // สิ่งที่ควรจัดการ — ไม่มีผู้ดูแล / ใบลารอพิจารณา / ยังไม่เปิด LINE
  const todo = (rows ?? []).flatMap((r) => {
    const name = schoolName(r.school);
    const items: { key: string; text: string; to?: string }[] = [];
    if (r.admins === 0) items.push({ key: `a${r.school.id_school}`, text: `${name} ยังไม่มีผู้ดูแลระบบ`, to: '/admins' });
    if (r.pending > 0) items.push({ key: `p${r.school.id_school}`, text: `${name} มีใบลารอพิจารณา ${r.pending} ใบ (อนุมัติในแอป)` });
    if (r.line === false) items.push({ key: `l${r.school.id_school}`, text: `${name} ยังไม่ได้เปิดแจ้งเตือน LINE`, to: '/line' });
    return items;
  });

  const lineBadge = (v: boolean | null) =>
    v === null ? <span className="badge-slate">-</span> : v ? <span className="badge-green">เปิด</span> : <span className="badge-amber">ยังไม่ตั้ง</span>;
  const uiBadge = (s: School) =>
    s.mobile_ui === 'old' ? <span className="badge-brand">แบบเดิม</span> : <span className="badge-slate">แบบใหม่</span>;

  return (
    <>
      <PageHeader
        title="ภาพรวมระบบ"
        description="ทุกโรงเรียนในระบบ · บุคลากรนับเฉพาะคนที่ยังปฏิบัติงาน"
        actions={
          <Link to="/schools" className="btn-primary">
            จัดการโรงเรียน
          </Link>
        }
      />

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4 lg:gap-4">
        <StatCard icon={<IconSchool className="h-4 w-4" />} label="โรงเรียน" value={rows ? rows.length : '–'} />
        <StatCard icon={<IconUsers className="h-4 w-4" />} label="บุคลากร" value={rows ? total('teachers') : '–'} />
        <StatCard icon={<IconDoc className="h-4 w-4" />} label="ใบลาทั้งหมด" value={rows ? total('leaves') : '–'} />
        <StatCard
          icon={<IconClock className="h-4 w-4" />}
          label="รอพิจารณา"
          value={rows ? total('pending') : '–'}
          hint={rows && total('pending') > 0 ? 'มีใบลาที่ยังไม่ได้ดำเนินการ' : undefined}
          tone="amber"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
        <section className="card overflow-hidden">
          <div className="card-title">
            โรงเรียนในระบบ
            <span className="text-xs font-medium text-slate-500">{rows ? `${rows.length} แห่ง` : ''}</span>
          </div>

          {!rows ? (
            <EmptyState>กำลังโหลด...</EmptyState>
          ) : rows.length === 0 ? (
            <EmptyState>ยังไม่มีโรงเรียน</EmptyState>
          ) : (
            <>
              {/* จอกว้าง: ตาราง */}
              <div className="hidden overflow-x-auto md:block">
                <table className="table">
                  <thead>
                    <tr>
                      <th>โรงเรียน</th>
                      <th className="text-right">บุคลากร</th>
                      <th className="text-right">ผู้ดูแล</th>
                      <th>ใบลา</th>
                      <th className="text-right">รอพิจารณา</th>
                      <th>หน้าจอมือถือ</th>
                      <th>LINE</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r) => (
                      <tr key={r.school.id_school}>
                        <td>
                          <div className="flex items-center gap-3">
                            <SchoolLogo logo={r.school.logo} name={schoolName(r.school)} size={30} />
                            <div className="min-w-0">
                              <div className="font-medium">{schoolName(r.school)}</div>
                              <div className="text-xs text-slate-500">
                                {[r.school.province, r.school.district].filter(Boolean).join(' / ') || '-'}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td className="text-right tabular-nums">{r.teachers}</td>
                        <td className="text-right tabular-nums">
                          {r.admins === 0 ? <span className="badge-red">ยังไม่มี</span> : r.admins}
                        </td>
                        <td>
                          <div className="flex items-center gap-2">
                            <span className="h-1.5 w-20 overflow-hidden rounded-full bg-slate-100">
                              <span
                                className="block h-full rounded-full bg-brand-600"
                                style={{ width: `${(r.leaves / maxLeaves) * 100}%` }}
                              />
                            </span>
                            <span className="tabular-nums">{r.leaves}</span>
                          </div>
                        </td>
                        <td className="text-right tabular-nums">
                          {r.pending > 0 ? <span className="badge-amber">{r.pending}</span> : '0'}
                        </td>
                        <td>{uiBadge(r.school)}</td>
                        <td>{lineBadge(r.line)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* มือถือ: การ์ดทีละโรงเรียน */}
              <ul className="divide-y divide-slate-100 md:hidden">
                {rows.map((r) => (
                  <li key={r.school.id_school} className="px-4 py-3.5">
                    <div className="flex items-center gap-3">
                      <SchoolLogo logo={r.school.logo} name={schoolName(r.school)} size={34} />
                      <div className="min-w-0 flex-1">
                        <div className="truncate font-medium">{schoolName(r.school)}</div>
                        <div className="text-xs text-slate-500">
                          บุคลากร {r.teachers} · ผู้ดูแล {r.admins} · ใบลา {r.leaves}
                        </div>
                      </div>
                    </div>
                    <div className="mt-2.5 flex flex-wrap gap-1.5 pl-[46px]">
                      {r.admins === 0 && <span className="badge-red">ยังไม่มีผู้ดูแล</span>}
                      {r.pending > 0 && <span className="badge-amber">รอพิจารณา {r.pending}</span>}
                      {uiBadge(r.school)}
                      <span className="inline-flex items-center gap-1 text-xs text-slate-500">
                        <IconChat className="h-3.5 w-3.5" /> {lineBadge(r.line)}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>

        <section className="card h-fit">
          <div className="card-title">สิ่งที่ควรจัดการ</div>
          <div className="px-4 pb-4 sm:px-5">
            {!rows ? (
              <p className="py-4 text-sm text-slate-500">กำลังโหลด...</p>
            ) : todo.length === 0 ? (
              <p className="py-4 text-sm text-slate-500">เรียบร้อยดี ไม่มีเรื่องค้าง ✅</p>
            ) : (
              <ul className="divide-y divide-slate-100">
                {todo.map((t) => (
                  <li key={t.key}>
                    {t.to ? (
                      <Link to={t.to} className="flex items-start gap-2.5 py-3 text-[13px] hover:text-brand-700">
                        <IconAlert className="mt-0.5 h-4 w-4 text-amber-500" />
                        <span>{t.text}</span>
                      </Link>
                    ) : (
                      <div className="flex items-start gap-2.5 py-3 text-[13px]">
                        <IconAlert className="mt-0.5 h-4 w-4 text-amber-500" />
                        <span>{t.text}</span>
                      </div>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </div>
    </>
  );
}
