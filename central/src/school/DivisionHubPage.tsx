import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowUpRight, Layers, Settings2 } from 'lucide-react';
import { navigateToLeaveApp, type Access } from '../supabase';
import AcademicsPage from './AcademicsPage';
import AnnouncementsSection from './AnnouncementsSection';
import AppointmentOrdersPage from './AppointmentOrdersPage';
import DepartmentsPage from './DepartmentsPage';
import DocumentsPage from './DocumentsPage';
import FinanceBudgetPage from './FinanceBudgetPage';
import {
  fetchSchoolLeaveSummary,
  type SchoolLeaveSummary,
} from './leaveSystemData';
import type { DivisionWithModules, ResolvedDivisionModule } from './mapping';
import PublicWebSettingsPage from './PublicWebSettingsPage';
import StudentsPage from './StudentsPage';

interface DivisionHubPageProps {
  schoolId: number | null;
  schoolName?: string;
  canEdit: boolean;
  editableDivisionIds?: number[];
  editableModuleKeys?: string[];
  access: Access;
  divisions: DivisionWithModules[];
}

export default function DivisionHubPage({
  schoolId,
  schoolName = 'โรงเรียน',
  canEdit,
  editableDivisionIds = [],
  editableModuleKeys = [],
  access,
  divisions,
}: DivisionHubPageProps) {
  const { divisionKey, moduleKey } = useParams<{
    divisionKey: string;
    moduleKey?: string;
  }>();

  const division = divisions.find(
    (d) => d.division_key === divisionKey && d.is_enabled,
  );
  const enabledModules = division
    ? division.modules.filter((m) => m.is_enabled)
    : [];

  const activeModule =
    enabledModules.find((m) => m.module_key === moduleKey) ??
    enabledModules[0] ??
    null;

  const canEditThisDivision =
    canEdit || (division ? editableDivisionIds.includes(division.id) : false);

  const canEditActiveModule =
    canEditThisDivision ||
    (activeModule && division
      ? editableModuleKeys.includes(activeModule.module_key) ||
        editableModuleKeys.includes(
          `${division.division_key}:${activeModule.module_key}`,
        )
      : false);

  if (!division) {
    return (
      <div className="surface-card p-8 text-center">
        <p className="text-base font-medium text-ink">
          ไม่พบฝ่ายงานนี้ หรือบัญชีของคุณไม่มีสิทธิ์เข้าถึงฝ่ายนี้
        </p>
        <p className="mt-1 text-sm text-slate-500">
          สามารถกลับไปที่หน้าหลักโรงเรียน หรือตั้งค่าการเปิดใช้งานฝ่ายในโหมดผู้ดูแลระบบกลาง
        </p>
        <div className="mt-5 flex justify-center gap-3">
          <Link to="/school" className="btn-secondary">
            กลับหน้าหลักโรงเรียน
          </Link>
          {canEdit && (
            <Link to="/school/settings/mapping" className="btn-primary">
              ตั้งค่าฝ่ายและระบบงาน
            </Link>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Division & Active Module Header */}
      <div className="flex flex-col gap-3 border-b border-line pb-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">{division.name}</p>
          <h1 className="mt-0.5 text-xl font-semibold tracking-tight text-ink sm:text-2xl">
            {activeModule ? activeModule.title : division.name}
          </h1>
          {(activeModule?.description || division.description) && (
            <p className="mt-1 text-xs text-slate-500 sm:text-sm">
              {activeModule?.description || division.description}
            </p>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-2 shrink-0">
          {activeModule && (
            <span
              className={`inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                canEditActiveModule
                  ? 'bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-200'
                  : 'bg-sky-50 text-sky-700 ring-1 ring-inset ring-sky-200'
              }`}
            >
              {canEditActiveModule
                ? 'สิทธิ์ของคุณในหน้านี้: แก้ไขและจัดการได้'
                : 'สิทธิ์ของคุณในหน้านี้: ดูและดาวน์โหลดอย่างเดียว'}
            </span>
          )}
          {canEdit && (
            <Link
              to="/school/settings/mapping"
              className="btn-secondary btn-sm shrink-0"
            >
              <Settings2 className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>จัดการระบบงานของฝ่ายนี้</span>
            </Link>
          )}
        </div>
      </div>

      {/* ระบบงานในฝ่าย */}
      {enabledModules.length === 0 ? (
        <div className="surface-card p-8 text-center">
          <p className="text-sm font-medium text-ink">
            ยังไม่มีระบบงานที่เปิดใช้งานใน{division.name}
          </p>
          {canEdit && (
            <div className="mt-4">
              <Link
                to="/school/settings/mapping"
                className="btn-primary btn-sm"
              >
                เพิ่มระบบงานเข้าฝ่ายนี้
              </Link>
            </div>
          )}
        </div>
      ) : (
        <>
          {/* Active Module Content */}
          {activeModule && (
            <DivisionModuleRenderer
              schoolId={schoolId}
              schoolName={schoolName}
              division={division}
              canEdit={canEditActiveModule}
              access={access}
              mod={activeModule}
            />
          )}
        </>
      )}
    </div>
  );
}

function DivisionModuleRenderer({
  schoolId,
  schoolName,
  division,
  canEdit,
  access,
  mod,
}: {
  schoolId: number | null;
  schoolName: string;
  division: DivisionWithModules;
  canEdit: boolean;
  access: Access;
  mod: ResolvedDivisionModule;
}) {
  switch (mod.module_key) {
    case 'leave-system':
      return <LeaveSystemModuleView schoolId={schoolId} access={access} mod={mod} />;
    case 'staff-registry':
    case 'departments':
      return <DepartmentsPage schoolId={schoolId} canEdit={canEdit} />;
    case 'students-classrooms':
      return <StudentsPage schoolId={schoolId} canEdit={canEdit} />;
    case 'curriculum-schedule':
      return <AcademicsPage schoolId={schoolId} canEdit={canEdit} />;
    case 'student-admissions':
      return (
        <PublicWebSettingsPage
          school={
            schoolId
              ? { id_school: schoolId, fullName: schoolName, affiliation: null }
              : null
          }
          schoolId={schoolId}
          canManage={canEdit}
          initialSection="admission"
          allowedSections={['admission', 'students']}
          customTitle="ระบบรับสมัครนักเรียนใหม่ และข้อมูลนักเรียน (เว็บสาธารณะ)"
          customSubtitle="จัดการใบสมัครออนไลน์ ม.1/ม.4 อนุมัติเอกสาร จัดห้องสอบ พิมพ์บัตรสอบ A4 และตั้งค่าข้อมูลนักเรียนของฝ่ายวิชาการ"
        />
      );
    case 'documents':
      return <DocumentsPage schoolId={schoolId} canEdit={canEdit} />;
    case 'announcements':
      return <AnnouncementsSection schoolId={schoolId} canEdit={canEdit} />;
    case 'public-web-settings':
      return (
        <PublicWebSettingsPage
          school={
            schoolId
              ? { id_school: schoolId, fullName: schoolName, affiliation: null }
              : null
          }
          schoolId={schoolId}
          canManage={canEdit}
          initialSection="home"
          allowedSections={['home', 'news', 'about', 'contact', 'media']}
          customTitle="ตั้งค่าหน้าเว็บโรงเรียนสาธารณะ (ฝ่ายบริหารทั่วไป)"
          customSubtitle="จัดการหน้าแรก สารจากผู้อำนวยการ ข่าวประชาสัมพันธ์ ข้อมูลโรงเรียน ช่องทางติดต่อ และคลังสื่อดิจิทัล"
        />
      );
    case 'finance-budget':
      return <FinanceBudgetPage schoolId={schoolId} canEdit={canEdit} mod={mod} />;
    case 'appointment-orders':
      return (
        <AppointmentOrdersPage
          schoolId={schoolId}
          schoolName={schoolName}
          division={division}
          canEdit={canEdit}
        />
      );
    default:
      return <ExternalOrCustomModuleView mod={mod} canEdit={canEdit} />;
  }
}

function LeaveSystemModuleView({
  schoolId,
  access,
  mod,
}: {
  schoolId: number | null;
  access: Access;
  mod: ResolvedDivisionModule;
}) {
  const [leaveSummary, setLeaveSummary] = useState<SchoolLeaveSummary | null>(
    null,
  );

  useEffect(() => {
    if (!schoolId) return;
    fetchSchoolLeaveSummary(schoolId).then((res) => {
      setLeaveSummary(res);
    });
  }, [schoolId]);

  return (
    <div className="space-y-6">
      <section className="surface-card p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-base font-semibold text-ink">{mod.title}</h2>
            <p className="mt-1 text-sm text-slate-600">
              {mod.description ||
                'ยื่นใบลา อนุมัติการลา ไปราชการ และลงเวลาปฏิบัติงาน'}
            </p>
            <p className="mt-2 text-xs text-slate-500">
              ใบลารอพิจารณาปัจจุบัน:{' '}
              <span className="font-semibold tabular-nums text-ink">
                {leaveSummary === null
                  ? '-'
                  : leaveSummary.pendingLeaves.toLocaleString('th-TH')}
              </span>{' '}
              รายการ · ใบลาสะสมทั้งหมด:{' '}
              <span className="font-semibold tabular-nums text-ink">
                {leaveSummary === null
                  ? '-'
                  : leaveSummary.totalLeaves.toLocaleString('th-TH')}
              </span>{' '}
              รายการ
            </p>
          </div>

          <button
            type="button"
            onClick={() => navigateToLeaveApp(mod.resolved_url || undefined)}
            className="btn-primary shrink-0"
          >
            <span>เปิดระบบวันลา</span>
            <ArrowUpRight className="h-4 w-4" strokeWidth={1.5} />
          </button>
        </div>
      </section>

      {(access.level === 'school' || access.level === 'super') && (
        <section className="surface-card p-6">
          <div className="flex items-center gap-2">
            <Settings2 className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
            <h3 className="text-base font-semibold text-ink">
              ตั้งค่าระบบวันลาของโรงเรียน
            </h3>
          </div>
          <p className="mt-1 text-sm text-slate-600">
            จัดการสิทธิ์และค่าตั้งค่าของระบบวันลาสำหรับโรงเรียนนี้
          </p>

          <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <Link
              to="/school/settings/permissions"
              className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
            >
              <p className="text-sm font-medium text-ink">สิทธิ์การใช้งาน</p>
              <p className="mt-0.5 text-xs text-slate-500">
                กำหนดสิทธิ์ตามบทบาทและสิทธิ์รายบุคคล
              </p>
            </Link>

            {access.level === 'super' && (
              <>
                <Link
                  to="/school/settings/forms"
                  className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">ออกแบบฟอร์มใบลา</p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    ปรับแต่งหัวใบลาและแบบฟอร์มไปราชการ
                  </p>
                </Link>
                <Link
                  to="/school/settings/line"
                  className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">LINE แจ้งเตือน</p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    ตั้งค่ากลุ่ม LINE แจ้งเตือนใบลาและลงเวลา
                  </p>
                </Link>
              </>
            )}
          </div>
        </section>
      )}
    </div>
  );
}

function ExternalOrCustomModuleView({
  mod,
  canEdit,
}: {
  mod: ResolvedDivisionModule;
  canEdit: boolean;
}) {
  return (
    <section className="surface-card p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Layers className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
            <h2 className="text-base font-semibold text-ink">{mod.title}</h2>
          </div>
          {mod.description && (
            <p className="mt-1 text-sm text-slate-600">{mod.description}</p>
          )}
        </div>

        {mod.resolved_url ? (
          <a
            href={mod.resolved_url}
            target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
            rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
            className="btn-primary shrink-0"
          >
            <span>เปิดลิงก์ระบบงาน</span>
            <ArrowUpRight className="h-4 w-4" strokeWidth={1.5} />
          </a>
        ) : (
          canEdit && (
            <Link
              to="/school/settings/mapping"
              className="btn-secondary btn-sm shrink-0"
            >
              ตั้งค่าลิงก์ของระบบงานนี้
            </Link>
          )
        )}
      </div>

      {!mod.resolved_url && (
        <p className="mt-4 text-xs text-slate-500">
          ยังไม่ได้ผูกลิงก์สำหรับระบบงานนี้ สามารถกำหนด URL ได้ที่เมนู "ฝ่ายและบุคลากร" ในหน้าตั้งค่าโรงเรียน
        </p>
      )}
    </section>
  );
}
