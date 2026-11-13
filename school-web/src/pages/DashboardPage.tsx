import { useEffect, useState } from 'react';
import { ArrowUpRight, CheckCircle2, Layers } from 'lucide-react';
import { Link } from 'react-router-dom';
import AnnouncementsSection from '../components/AnnouncementsSection';
import { supabase } from '../lib/supabase';
import type { SchoolDepartment, SchoolInfo, SchoolModuleLink } from '../types/school';

interface DashboardPageProps {
  school: SchoolInfo | null;
  schoolId: number | null;
  canEdit: boolean;
  academicLabel: string;
  modules: SchoolModuleLink[];
}

const ROADMAP_PARTS = [
  { part: 'พาร์ทที่ 1', title: 'โครงสร้างฐานข้อมูลแกนกลาง + App Shell', done: true },
  { part: 'พาร์ทที่ 2', title: 'ระบบ Login (SSO) + จัดการลิงก์ระบบย่อย', done: true },
  { part: 'พาร์ทที่ 3', title: 'Dashboard โรงเรียน + บุคลากรและฝ่ายงาน', done: true },
  { part: 'พาร์ทที่ 4', title: 'โมดูลงานนักเรียนและงานวิชาการ', done: true },
  { part: 'พาร์ทที่ 5', title: 'สารบรรณ ประกาศโรงเรียน และขัดเกลา UI', done: true },
];

export default function DashboardPage({
  school,
  schoolId,
  canEdit,
  academicLabel,
  modules,
}: DashboardPageProps) {
  const [staffCount, setStaffCount] = useState<number | null>(null);
  const [studentCount, setStudentCount] = useState<number | null>(null);
  const [deptList, setDeptList] = useState<SchoolDepartment[]>([]);
  const [pendingLeaves, setPendingLeaves] = useState<number | null>(null);

  useEffect(() => {
    if (!schoolId) return;
    let cancelled = false;

    (async () => {
      const [teachersRes, studentsRes, deptRes, leavesRes] = await Promise.all([
        supabase
          .from('Teachers')
          .select('id_user, employment_status', { count: 'exact' })
          .eq('id_school', schoolId),
        supabase
          .from('SchoolWebStudents')
          .select('id', { count: 'exact', head: true })
          .eq('id_school', schoolId)
          .eq('status', 'enrolled'),
        supabase
          .from('SchoolDepartments')
          .select('id, id_school, code, name, category, sort_order, is_active')
          .eq('id_school', schoolId)
          .eq('is_active', true)
          .order('sort_order', { ascending: true }),
        supabase
          .from('Leaves')
          .select('id', { count: 'exact', head: true })
          .eq('id_school', schoolId)
          .in('Status', ['รอพิจารณา', 'ยังไม่ส่ง']),
      ]);

      if (cancelled) return;

      if (!teachersRes.error && teachersRes.data) {
        const activeCount = teachersRes.data.filter(
          (t: { employment_status?: string | null }) =>
            !t.employment_status || t.employment_status === 'active',
        ).length;
        setStaffCount(activeCount);
      } else {
        setStaffCount(null);
      }

      if (!studentsRes.error && typeof studentsRes.count === 'number') {
        setStudentCount(studentsRes.count);
      } else {
        setStudentCount(null);
      }

      if (!deptRes.error && deptRes.data) {
        setDeptList(deptRes.data as SchoolDepartment[]);
      } else {
        setDeptList([]);
      }

      if (!leavesRes.error && typeof leavesRes.count === 'number') {
        setPendingLeaves(leavesRes.count);
      } else {
        setPendingLeaves(null);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [schoolId]);

  const leaveModule = modules.find((m) => m.module_key === 'leave-app');
  const enabledModules = modules.filter((m) => m.is_enabled);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-ink">
            {school?.fullName || 'ภาพรวมโรงเรียน'}
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            {academicLabel}
            {school?.affiliation ? ` · ${school.affiliation}` : ''}
          </p>
        </div>

        {leaveModule && (
          <a
            href={leaveModule.url}
            target={leaveModule.open_mode === 'new_tab' ? '_blank' : '_self'}
            rel={leaveModule.open_mode === 'new_tab' ? 'noreferrer' : undefined}
            className="btn-primary shrink-0"
          >
            <span>เปิดระบบวันลา</span>
            <ArrowUpRight className="h-4 w-4" strokeWidth={1.5} />
          </a>
        )}
      </div>

      {/* Stat Row (quiet numbers, tabular-nums, no decorative icons/charts) */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">บุคลากรที่ปฏิบัติงาน</p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {staffCount === null ? '-' : staffCount.toLocaleString('th-TH')}
          </p>
          <p className="mt-1 text-xs text-slate-500">
            <Link to="/staff" className="hover:text-brand-600">
              ดูทะเบียนบุคลากร
            </Link>
          </p>
        </div>

        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">นักเรียนกำลังศึกษา</p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {studentCount === null ? '-' : studentCount.toLocaleString('th-TH')}
          </p>
          <p className="mt-1 text-xs text-slate-500">
            <Link to="/students" className="hover:text-brand-600">
              ดูทะเบียนนักเรียน
            </Link>
          </p>
        </div>

        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">ฝ่ายและกลุ่มสาระ</p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {deptList.length.toLocaleString('th-TH')}
          </p>
          <p className="mt-1 text-xs text-slate-500">
            <Link to="/departments" className="hover:text-brand-600">
              จัดการโครงสร้างหน่วยงาน
            </Link>
          </p>
        </div>

        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">ใบลารอพิจารณา (ระบบวันลา)</p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {pendingLeaves === null ? '-' : pendingLeaves.toLocaleString('th-TH')}
          </p>
          <p className="mt-1 text-xs text-slate-500">
            ข้อมูลแบบอ่านอย่างเดียวจากระบบวันลา
          </p>
        </div>
      </div>

      {/* Asymmetric Main Grid */}
      <div className="grid gap-6 lg:grid-cols-12">
        <div className="space-y-6 lg:col-span-7">
          {/* Connected Modules */}
          <section className="surface-card p-6">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Layers className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
                <h2 className="text-base font-semibold text-ink">
                  ระบบย่อยที่เชื่อมต่อ
                </h2>
              </div>
              <Link
                to="/settings"
                className="text-xs font-medium text-brand-600 hover:text-brand-700"
              >
                จัดการลิงก์
              </Link>
            </div>

            <div className="mt-4 space-y-3">
              {enabledModules.map((mod) => (
                <a
                  key={mod.id ?? mod.module_key}
                  href={mod.url}
                  target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
                  rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
                  className="group flex items-center justify-between gap-4 rounded-lg border border-line bg-canvas/60 p-4 transition-colors hover:border-brand-200 hover:bg-brand-50/40"
                >
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-ink group-hover:text-brand-700">
                      {mod.title}
                    </p>
                    {mod.description && (
                      <p className="mt-0.5 text-xs text-slate-500">{mod.description}</p>
                    )}
                  </div>
                  <ArrowUpRight
                    className="h-4 w-4 shrink-0 text-slate-400 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5 group-hover:text-brand-600"
                    strokeWidth={1.5}
                  />
                </a>
              ))}
            </div>
          </section>

          {/* Departments Summary */}
          <section className="surface-card p-6">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-semibold text-ink">
                โครงสร้างฝ่ายและกลุ่มสาระ
              </h2>
              <Link
                to="/departments"
                className="text-xs font-medium text-brand-600 hover:text-brand-700"
              >
                ดูทั้งหมด
              </Link>
            </div>

            {deptList.length === 0 ? (
              <p className="mt-4 text-sm text-slate-500">
                ยังไม่มีข้อมูลฝ่ายหรือกลุ่มสาระ สามารถเพิ่มได้ที่หน้าฝ่ายและกลุ่มสาระ
              </p>
            ) : (
              <ul className="mt-4 divide-y divide-line">
                {deptList.slice(0, 6).map((d) => (
                  <li key={d.id} className="flex items-center justify-between py-2.5 text-sm">
                    <span className="font-medium text-ink">{d.name}</span>
                    {d.code && (
                      <span className="tabular-nums text-xs text-slate-500">{d.code}</span>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>

        {/* Right: Announcements + Development Progress */}
        <div className="space-y-6 lg:col-span-5">
          <AnnouncementsSection schoolId={schoolId} canEdit={canEdit} />

          <section className="surface-card p-6">
            <h2 className="text-base font-semibold text-ink">ความคืบหน้าโครงสร้างระบบ</h2>
            <p className="mt-1 text-sm text-slate-600">ลำดับการพัฒนาแบบแบ่งพาร์ท</p>

            <ol className="mt-5 space-y-4">
              {ROADMAP_PARTS.map((item) => (
                <li key={item.part} className="flex items-start gap-3">
                  <CheckCircle2
                    className="mt-0.5 h-4 w-4 shrink-0 text-brand-600"
                    strokeWidth={1.75}
                  />
                  <p className="text-sm font-medium text-ink">
                    <span className="tabular-nums text-slate-500">{item.part}</span> · {item.title}
                  </p>
                </li>
              ))}
            </ol>
          </section>
        </div>
      </div>
    </div>
  );
}
