import { useEffect, useState } from 'react';
import { ArrowRight, ExternalLink, Layers, ShieldCheck } from 'lucide-react';
import { Link } from 'react-router-dom';
import { supabase } from '../supabase';
import AnnouncementsSection from './AnnouncementsSection';
import type { DivisionWithModules } from './mapping';
import type { SchoolBasic } from './types';

interface SchoolDashboardPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
  academicLabel: string;
  divisions: DivisionWithModules[];
}

export default function SchoolDashboardPage({
  school,
  schoolId,
  canEdit,
  academicLabel,
  divisions,
}: SchoolDashboardPageProps) {
  const [staffCount, setStaffCount] = useState<number | null>(null);
  const [studentCount, setStudentCount] = useState<number | null>(null);
  const [pendingLeaves, setPendingLeaves] = useState<number | null>(null);

  useEffect(() => {
    if (!schoolId) return;
    let cancelled = false;

    (async () => {
      const [teachersRes, studentsRes, leavesRes] = await Promise.all([
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
      }

      if (!studentsRes.error && typeof studentsRes.count === 'number') {
        setStudentCount(studentsRes.count);
      }

      if (!leavesRes.error && typeof leavesRes.count === 'number') {
        setPendingLeaves(leavesRes.count);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [schoolId]);

  const enabledDivisions = divisions.filter((d) => d.is_enabled);
  const totalEnabledModules = enabledDivisions.reduce(
    (sum, d) => sum + d.modules.filter((m) => m.is_enabled).length,
    0,
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">
            Web โรงเรียน · โครงสร้างแยกตามฝ่ายงาน
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            {school?.fullName || 'ภาพรวมโรงเรียน'}
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            {academicLabel}
            {school?.affiliation ? ` · ${school.affiliation}` : ''}
          </p>
        </div>

        {canEdit && (
          <div className="flex flex-wrap items-center gap-2">
            <Link
              to="/admin/division-permissions"
              className="btn-secondary btn-sm"
            >
              <ShieldCheck className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>สิทธิ์เข้าถึงแต่ละฝ่าย</span>
            </Link>
            <Link to="/admin/mapping" className="btn-secondary btn-sm">
              <Layers className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>จัดการฝ่ายและ Module</span>
            </Link>
          </div>
        )}
      </div>

      {/* Stat Row */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">บุคลากรที่ปฏิบัติงาน</p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {staffCount === null ? '-' : staffCount.toLocaleString('th-TH')}
          </p>
          <p className="mt-1 text-xs text-slate-500">คน</p>
        </div>

        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">นักเรียนกำลังศึกษา</p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {studentCount === null ? '-' : studentCount.toLocaleString('th-TH')}
          </p>
          <p className="mt-1 text-xs text-slate-500">คน</p>
        </div>

        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">
            ฝ่ายที่เปิดใช้งาน / Module ย่อย
          </p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {enabledDivisions.length.toLocaleString('th-TH')}{' '}
            <span className="text-sm font-normal text-slate-400">
              / {totalEnabledModules.toLocaleString('th-TH')}
            </span>
          </p>
          <p className="mt-1 text-xs text-slate-500">ฝ่าย / ระบบย่อย</p>
        </div>

        <div className="surface-card p-5">
          <p className="text-xs font-medium text-slate-500">ใบลารอพิจารณา</p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">
            {pendingLeaves === null ? '-' : pendingLeaves.toLocaleString('th-TH')}
          </p>
          <p className="mt-1 text-xs text-slate-500">รายการ</p>
        </div>
      </div>

      {/* Main Content: Dynamic Divisions + Announcements */}
      <div className="grid gap-6 lg:grid-cols-12">
        <div className="space-y-6 lg:col-span-7">
          <section className="surface-card p-6">
            <h2 className="text-base font-semibold text-ink">
              ฝ่ายงานของโรงเรียน ({enabledDivisions.length})
            </h2>
            <p className="mt-1 text-sm text-slate-600">
              คลิกที่ชื่อฝ่าย หรือเลือก Module ย่อยภายในฝ่ายเพื่อเข้าใช้งานได้ทันที
            </p>

            {enabledDivisions.length === 0 ? (
              <p className="mt-4 text-sm text-slate-500">
                ยังไม่มีฝ่ายที่เปิดใช้งานสำหรับโรงเรียนนี้
              </p>
            ) : (
              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                {enabledDivisions.map((div) => {
                  const activeMods = div.modules.filter((m) => m.is_enabled);
                  return (
                    <div
                      key={div.id}
                      className="flex flex-col justify-between rounded-xl border border-line bg-canvas/60 p-4 transition-colors hover:border-slate-300"
                    >
                      <div>
                        <Link
                          to={`/division/${div.division_key}`}
                          className="group flex items-center justify-between gap-2"
                        >
                          <p className="text-sm font-semibold text-ink group-hover:text-brand-700">
                            {div.name}
                          </p>
                          <ArrowRight
                            className="h-4 w-4 shrink-0 text-slate-400 transition-transform group-hover:translate-x-0.5 group-hover:text-brand-600"
                            strokeWidth={1.5}
                          />
                        </Link>
                        {div.description && (
                          <p className="mt-1 text-xs text-slate-500">
                            {div.description}
                          </p>
                        )}
                      </div>

                      <div className="mt-3 flex flex-wrap gap-1.5 border-t border-line/70 pt-3">
                        {activeMods.length === 0 ? (
                          <span className="text-[11px] text-slate-400">
                            ยังไม่มี Module ในฝ่ายนี้
                          </span>
                        ) : (
                          activeMods.map((m) => (
                            <Link
                              key={m.id}
                              to={`/division/${div.division_key}/${m.module_key}`}
                              className="inline-flex items-center gap-1 rounded-md bg-white px-2 py-1 text-[11px] font-medium text-slate-700 ring-1 ring-line transition-colors hover:bg-brand-50 hover:text-brand-700 hover:ring-brand-200"
                            >
                              <span>{m.title}</span>
                              {m.module_type === 'external' && (
                                <ExternalLink
                                  className="h-2.5 w-2.5 opacity-70"
                                  strokeWidth={1.5}
                                />
                              )}
                            </Link>
                          ))
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </section>
        </div>

        <div className="lg:col-span-5">
          <AnnouncementsSection schoolId={schoolId} canEdit={canEdit} />
        </div>
      </div>
    </div>
  );
}
