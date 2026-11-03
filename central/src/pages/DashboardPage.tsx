import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ADMIN_ROLE_ID, schoolName, supabase, type School } from '../supabase';
import { isWorkingToday } from '../staffStatus';
import { EmptyState, PageHeader, SectionHeader, StatCard } from '../ui/components';
import {
  IconAlert,
  IconChat,
  IconClock,
  IconDoc,
  IconSchool,
  IconShield,
  IconUserCheck,
  IconUsers,
} from '../ui/icons';
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

const QUICK_CATEGORIES = [
  {
    title: 'องค์กรและบุคลากร',
    desc: 'โรงเรียน ผู้ดูแล และสถานะครู',
    links: [
      { to: '/schools', label: 'โรงเรียน', icon: <IconSchool className="h-4 w-4" /> },
      { to: '/admins', label: 'ผู้ดูแลโรงเรียน', icon: <IconUserCheck className="h-4 w-4" /> },
      { to: '/staff', label: 'บุคลากร', icon: <IconUsers className="h-4 w-4" /> },
    ],
  },
  {
    title: 'สิทธิ์และการเข้าถึง',
    desc: 'เพดานสิทธิ์ การเห็นเมนู และรายบุคคล',
    links: [
      { to: '/role-permissions', label: 'เพดานสิทธิ์และเมนู', icon: <IconShield className="h-4 w-4" /> },
      { to: '/user-permissions', label: 'สิทธิ์รายบุคคล', icon: <IconUsers className="h-4 w-4" /> },
    ],
  },
  {
    title: 'ระบบเชื่อมต่อและเอกสาร',
    desc: 'แจ้งเตือน LINE สแกนหน้า และแบบฟอร์ม',
    links: [
      { to: '/line', label: 'LINE แจ้งเตือน', icon: <IconChat className="h-4 w-4" /> },
      { to: '/attendance', label: 'ลงเวลา (สแกนหน้า)', icon: <IconClock className="h-4 w-4" /> },
      { to: '/forms', label: 'ออกแบบฟอร์ม', icon: <IconDoc className="h-4 w-4" /> },
    ],
  },
];

/** ภาพรวมทุกโรงเรียน — RLS ให้ผู้ดูแลส่วนกลางอ่านได้ทุกแถว */
export default function DashboardPage() {
  const [rows, setRows] = useState<SchoolStats[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const [schools, teachers, leaves, line] = await Promise.all([
        supabase.from('Schools').select('*').order('id_school'),
        supabase.from('Teachers').select('id_school, id_role, is_super_admin, employment_status, left_date'),
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
              isWorkingToday(x.employment_status, x.left_date),
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

  const total = (key: 'teachers' | 'leaves' | 'pending' | 'admins') =>
    (rows ?? []).reduce((sum, r) => sum + r[key], 0);
  const maxLeaves = Math.max(1, ...(rows ?? []).map((r) => r.leaves));

  // สิ่งที่ควรจัดการ — ไม่มีผู้ดูแล / ใบลารอพิจารณา / ยังไม่เปิด LINE
  const todo = (rows ?? []).flatMap((r) => {
    const name = schoolName(r.school);
    const items: { key: string; text: string; category: string; to?: string }[] = [];
    if (r.admins === 0)
      items.push({
        key: `a${r.school.id_school}`,
        category: 'ผู้ดูแล',
        text: `${name} ยังไม่มีผู้ดูแลระบบ`,
        to: '/admins',
      });
    if (r.pending > 0)
      items.push({
        key: `p${r.school.id_school}`,
        category: 'ใบลา',
        text: `${name} มีใบลารอพิจารณา ${r.pending} ใบ (อนุมัติในแอป)`,
      });
    if (r.line === false)
      items.push({
        key: `l${r.school.id_school}`,
        category: 'LINE',
        text: `${name} ยังไม่ได้เปิดแจ้งเตือน LINE`,
        to: '/line',
      });
    return items;
  });

  const lineBadge = (v: boolean | null) =>
    v === null ? (
      <span className="badge-slate">-</span>
    ) : v ? (
      <span className="badge-green">เชื่อมต่อแล้ว</span>
    ) : (
      <span className="badge-amber">ยังไม่ตั้งค่า</span>
    );
  const uiBadge = (s: School) =>
    s.mobile_ui === 'old' ? <span className="badge-slate">แบบเดิม</span> : <span className="badge-brand">แบบใหม่</span>;

  return (
    <>
      <PageHeader
        category="1. ภาพรวมและสถานะระบบ"
        title="ภาพรวมระบบทั้งหมด"
        description="สรุปข้อมูลทุกโรงเรียนในระบบ · บุคลากรนับเฉพาะผู้ที่กำลังปฏิบัติงานในปัจจุบัน"
        actions={
          <Link to="/schools" className="btn-primary">
            <IconSchool className="h-4 w-4" />
            จัดการโรงเรียน
          </Link>
        }
      />

      {/* หมวดที่ 1: ตัวเลขสรุปทั้งระบบ */}
      <div className="mb-6">
        <SectionHeader
          step="1"
          title="สรุปข้อมูลภาพรวมทั้งระบบ"
          subtitle="ตัวเลขรวมจากทุกโรงเรียนที่ลงทะเบียนในระบบ"
        />
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 lg:gap-4">
          <StatCard
            icon={<IconSchool className="h-4 w-4" />}
            label="โรงเรียนในระบบ"
            value={rows ? rows.length : '–'}
            hint={rows ? `ผู้ดูแลรวม ${total('admins')} คน` : undefined}
            tone="brand"
          />
          <StatCard
            icon={<IconUsers className="h-4 w-4" />}
            label="บุคลากรปฏิบัติงาน"
            value={rows ? total('teachers') : '–'}
            hint="เฉพาะสถานะปฏิบัติงานวันนี้"
            tone="green"
          />
          <StatCard
            icon={<IconDoc className="h-4 w-4" />}
            label="ใบลาสะสมทั้งหมด"
            value={rows ? total('leaves') : '–'}
            hint="รวมทุกประเภทการลา"
            tone="slate"
          />
          <StatCard
            icon={<IconClock className="h-4 w-4" />}
            label="ใบลารอพิจารณา"
            value={rows ? total('pending') : '–'}
            hint={rows && total('pending') > 0 ? 'มีใบลาที่ยังไม่ได้ดำเนินการ' : 'ไม่มีใบลาค้างพิจารณา'}
            tone={rows && total('pending') > 0 ? 'amber' : 'green'}
          />
        </div>
      </div>

      {/* หมวดที่ 2: ทางลัดแยกตามหมวดหมู่ */}
      <div className="mb-6">
        <SectionHeader
          step="2"
          title="หมวดหมู่การจัดการระบบ"
          subtitle="เลือกเมนูที่ต้องการตั้งค่าตามหมวดหมู่"
        />
        <div className="grid gap-3 md:grid-cols-3">
          {QUICK_CATEGORIES.map((cat) => (
            <div key={cat.title} className="card p-4">
              <div className="text-[13.5px] font-bold text-ink">{cat.title}</div>
              <div className="mt-0.5 text-xs text-slate-500">{cat.desc}</div>
              <div className="mt-3 flex flex-wrap gap-1.5">
                {cat.links.map((lk) => (
                  <Link key={lk.to} to={lk.to} className="btn-secondary btn-sm">
                    <span className="text-brand-600">{lk.icon}</span>
                    {lk.label}
                  </Link>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* หมวดที่ 3: ตารางสถานะรายโรงเรียน & รายการที่ควรจัดการ */}
      <SectionHeader
        step="3"
        title="สถานะรายโรงเรียนและสิ่งที่ควรจัดการ"
        subtitle="ตรวจสอบความพร้อมของแต่ละโรงเรียนในตารางเดียว"
      />
      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_340px]">
        <section className="card overflow-hidden">
          <div className="card-title">
            <span>ตารางสถานะรายโรงเรียน</span>
            <span className="badge-slate">{rows ? `${rows.length} แห่ง` : 'กำลังโหลด'}</span>
          </div>

          {!rows ? (
            <EmptyState>กำลังโหลดข้อมูลโรงเรียน...</EmptyState>
          ) : rows.length === 0 ? (
            <EmptyState>ยังไม่มีโรงเรียนในระบบ</EmptyState>
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
                      <th>สถิติใบลา</th>
                      <th className="text-right">รอพิจารณา</th>
                      <th>แอปมือถือ</th>
                      <th>แจ้งเตือน LINE</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r) => (
                      <tr key={r.school.id_school}>
                        <td>
                          <div className="flex items-center gap-3">
                            <SchoolLogo logo={r.school.logo} name={schoolName(r.school)} size={32} />
                            <div className="min-w-0">
                              <div className="font-semibold text-ink">{schoolName(r.school)}</div>
                              <div className="text-xs text-slate-500">
                                {[r.school.province, r.school.district].filter(Boolean).join(' / ') || '-'}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td className="text-right font-medium tabular-nums">{r.teachers}</td>
                        <td className="text-right tabular-nums">
                          {r.admins === 0 ? <span className="badge-red">ยังไม่มี</span> : <span className="font-medium">{r.admins}</span>}
                        </td>
                        <td>
                          <div className="flex items-center gap-2">
                            <span className="h-2 w-20 overflow-hidden rounded-full bg-slate-100">
                              <span
                                className="block h-full rounded-full bg-brand-600"
                                style={{ width: `${(r.leaves / maxLeaves) * 100}%` }}
                              />
                            </span>
                            <span className="text-xs font-medium tabular-nums text-slate-700">{r.leaves}</span>
                          </div>
                        </td>
                        <td className="text-right tabular-nums">
                          {r.pending > 0 ? <span className="badge-amber">{r.pending} ใบ</span> : <span className="text-slate-400">0</span>}
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
                      <SchoolLogo logo={r.school.logo} name={schoolName(r.school)} size={36} />
                      <div className="min-w-0 flex-1">
                        <div className="truncate font-semibold text-ink">{schoolName(r.school)}</div>
                        <div className="text-xs text-slate-500">
                          บุคลากร {r.teachers} · ผู้ดูแล {r.admins} · ใบลา {r.leaves}
                        </div>
                      </div>
                    </div>
                    <div className="mt-2.5 flex flex-wrap gap-1.5 pl-[48px]">
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

        <section className="card h-fit overflow-hidden">
          <div className="card-title">
            <span>สิ่งที่ควรจัดการ</span>
            {rows && (
              <span className={todo.length > 0 ? 'badge-amber' : 'badge-green'}>
                {todo.length > 0 ? `${todo.length} รายการ` : 'ครบถ้วน'}
              </span>
            )}
          </div>
          <div className="px-4 py-3 sm:px-5">
            {!rows ? (
              <p className="py-4 text-sm text-slate-500">กำลังตรวจสอบ...</p>
            ) : todo.length === 0 ? (
              <div className="rounded-xl bg-emerald-50/70 p-4 text-center text-[13px] font-medium text-emerald-800">
                เรียบร้อยดี ทุกโรงเรียนตั้งค่าครบถ้วน ✅
              </div>
            ) : (
              <ul className="divide-y divide-slate-100">
                {todo.map((t) => (
                  <li key={t.key} className="py-3 first:pt-1 last:pb-1">
                    {t.to ? (
                      <Link to={t.to} className="group flex items-start gap-2.5 text-[13px] hover:text-brand-700">
                        <IconAlert className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />
                        <div className="min-w-0 flex-1">
                          <span className="mr-1.5 inline-block rounded bg-amber-50 px-1.5 py-0.5 text-[11px] font-semibold text-amber-800">
                            {t.category}
                          </span>
                          <span className="group-hover:underline">{t.text}</span>
                        </div>
                      </Link>
                    ) : (
                      <div className="flex items-start gap-2.5 text-[13px]">
                        <IconAlert className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />
                        <div className="min-w-0 flex-1">
                          <span className="mr-1.5 inline-block rounded bg-slate-100 px-1.5 py-0.5 text-[11px] font-semibold text-slate-700">
                            {t.category}
                          </span>
                          <span>{t.text}</span>
                        </div>
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
