import { ArrowUpRight, CheckCircle2, Circle, Layers } from 'lucide-react';
import type { SchoolModuleLink } from '../types/school';

interface OverviewPlaceholderPageProps {
  modules: SchoolModuleLink[];
}

const ROADMAP_PARTS = [
  {
    part: 'พาร์ทที่ 1',
    title: 'โครงสร้างฐานข้อมูลแกนกลาง + App Shell',
    done: true,
    detail: 'สร้างตาราง AcademicYears, AcademicTerms, SchoolDepartments, SchoolModules และโครงหน้าบ้านหลัก',
  },
  {
    part: 'พาร์ทที่ 2',
    title: 'ระบบ Login (SSO) + จัดการลิงก์ระบบย่อย',
    done: true,
    detail: 'เชื่อมต่อ Supabase Auth ตัวเดียวกับระบบวันลา และจัดการลิงก์ระบบย่อยรายโรงเรียน',
  },
  {
    part: 'พาร์ทที่ 3',
    title: 'Dashboard โรงเรียน + ข้อมูลบุคลากรและฝ่ายงาน',
    done: false,
    detail: 'แสดงสรุปภาพรวมโรงเรียนและจัดการข้อมูลหลัก (ครู, ฝ่าย, กลุ่มสาระ, สิทธิ์)',
  },
  {
    part: 'พาร์ทที่ 4',
    title: 'โมดูลงานนักเรียนและงานวิชาการ',
    done: false,
    detail: 'ทะเบียนนักเรียน, ห้องเรียน, ครูที่ปรึกษา, รายวิชา และตารางสอน',
  },
  {
    part: 'พาร์ทที่ 5',
    title: 'โมดูลบริหารทั่วไปและขัดเกลา UI',
    done: false,
    detail: 'สารบรรณ, พัสดุ, แจ้งเตือนรวมศูนย์ และตรวจสอบความเรียบร้อยทั้งระบบ',
  },
];

export default function OverviewPlaceholderPage({ modules }: OverviewPlaceholderPageProps) {
  const leaveModule = modules.find((m) => m.module_key === 'leave-app');

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-ink">
            ระบบบริหารจัดการโรงเรียน
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            ศูนย์กลางข้อมูลและงานบริการของโรงเรียน เชื่อมต่อกับระบบวันลาโดยไม่กระทบการทำงานเดิม
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

      {/* Main Grid: Asymmetric split (8 + 4) */}
      <div className="grid gap-6 lg:grid-cols-12">
        {/* Left: Connected Subsystems */}
        <section className="surface-card p-6 lg:col-span-7">
          <div className="flex items-center gap-2">
            <Layers className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
            <h2 className="text-base font-semibold text-ink">
              ระบบย่อยที่เชื่อมต่อ
            </h2>
          </div>
          <p className="mt-1 text-sm text-slate-600">
            เข้าถึงระบบเฉพาะทางของโรงเรียนผ่านลิงก์กลางได้ทันที
          </p>

          <div className="mt-5 space-y-3">
            {modules
              .filter((m) => m.is_enabled)
              .map((mod) => (
                <a
                  key={mod.module_key}
                  href={mod.url}
                  target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
                  rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
                  className="group flex items-center justify-between gap-4 rounded-lg border border-line bg-canvas/60 p-4 transition-colors hover:border-brand-200 hover:bg-brand-50/40"
                >
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-ink group-hover:text-brand-700">
                      {mod.title}
                    </p>
                    <p className="mt-0.5 text-xs text-slate-500">{mod.description}</p>
                  </div>
                  <ArrowUpRight
                    className="h-4 w-4 shrink-0 text-slate-400 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5 group-hover:text-brand-600"
                    strokeWidth={1.5}
                  />
                </a>
              ))}
          </div>
        </section>

        {/* Right: Development Progress */}
        <section className="surface-card p-6 lg:col-span-5">
          <h2 className="text-base font-semibold text-ink">ความคืบหน้าโครงสร้างระบบ</h2>
          <p className="mt-1 text-sm text-slate-600">
            ลำดับการพัฒนาแบบแบ่งพาร์ท
          </p>

          <ol className="mt-5 space-y-4">
            {ROADMAP_PARTS.map((item) => (
              <li key={item.part} className="flex items-start gap-3">
                {item.done ? (
                  <CheckCircle2
                    className="mt-0.5 h-4 w-4 shrink-0 text-brand-600"
                    strokeWidth={1.75}
                  />
                ) : (
                  <Circle
                    className="mt-0.5 h-4 w-4 shrink-0 text-slate-300"
                    strokeWidth={1.5}
                  />
                )}
                <div className="min-w-0">
                  <p className="text-sm font-medium text-ink">
                    <span className="tabular-nums text-slate-500">{item.part}</span> · {item.title}
                  </p>
                  <p className="mt-0.5 text-xs text-slate-500">{item.detail}</p>
                </div>
              </li>
            ))}
          </ol>
        </section>
      </div>
    </div>
  );
}
