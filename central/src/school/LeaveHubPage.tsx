import { useEffect, useState } from 'react';
import { ArrowUpRight, Settings2 } from 'lucide-react';
import { Link } from 'react-router-dom';
import { supabase, type Access } from '../supabase';
import type { SchoolModuleLink } from './types';

interface LeaveHubPageProps {
  schoolId: number | null;
  access: Access;
  modules: SchoolModuleLink[];
}

export default function LeaveHubPage({
  schoolId,
  access,
  modules,
}: LeaveHubPageProps) {
  const [pendingLeaves, setPendingLeaves] = useState<number | null>(null);

  useEffect(() => {
    if (!schoolId) return;
    supabase
      .from('Leaves')
      .select('id', { count: 'exact', head: true })
      .eq('id_school', schoolId)
      .in('Status', ['รอพิจารณา', 'ยังไม่ส่ง'])
      .then(({ count, error }) => {
        if (!error && typeof count === 'number') setPendingLeaves(count);
      });
  }, [schoolId]);

  // ลิงก์ระบบย่อยที่อยู่ในหมวดงานบุคคล/วันลา (ไม่แยกไปอยู่ใน Navbar)
  const hrModules = modules.filter(
    (m) => m.is_enabled && (m.category === 'hr' || m.module_key === 'leave-app'),
  );

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-ink">
          ระบบวันลาและงานบุคคล
        </h1>
        <p className="mt-1 text-sm text-slate-600">
          เปิดใช้งานแอปวันลา ดูข้อมูลบุคลากร และตั้งค่าระบบวันลาสำหรับผู้ดูแล
        </p>
      </div>

      {/* ลิงก์แอปวันลา (อยู่ในหมวดหมู่ของตัวเอง) */}
      <section className="surface-card p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-base font-semibold text-ink">
              เข้าใช้งานระบบวันลาและไปราชการ
            </h2>
            <p className="mt-1 text-sm text-slate-600">
              ใบลารอพิจารณาปัจจุบัน:{' '}
              <span className="font-semibold tabular-nums text-ink">
                {pendingLeaves === null ? '-' : pendingLeaves.toLocaleString('th-TH')}
              </span>{' '}
              รายการ
            </p>
          </div>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          {hrModules.map((mod) => (
            <a
              key={mod.id ?? mod.module_key}
              href={mod.url}
              target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
              rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
              className="group flex items-center justify-between gap-4 rounded-xl border border-line bg-canvas/60 p-4 transition-colors hover:border-brand-200 hover:bg-brand-50/40"
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
                className="h-4 w-4 shrink-0 text-slate-400 group-hover:text-brand-600"
                strokeWidth={1.5}
              />
            </a>
          ))}
        </div>
      </section>

      {/* ส่วนตั้งค่าระบบวันลา (สำหรับ Admin / Super Admin) */}
      {(access.level === 'school' || access.level === 'super') && (
        <section className="surface-card p-6">
          <div className="flex items-center gap-2">
            <Settings2 className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
            <h2 className="text-base font-semibold text-ink">
              ตั้งค่าระบบวันลา (ส่วนผู้ดูแลระบบ)
            </h2>
          </div>
          <p className="mt-1 text-sm text-slate-600">
            เลือกเมนูย่อยจากแถบด้านบน หรือเข้าสู่หน้าตั้งค่าที่ต้องการได้ทันที
          </p>

          <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <Link
              to="/user-permissions"
              className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
            >
              <p className="text-sm font-medium text-ink">สิทธิ์รายบุคคล</p>
              <p className="mt-0.5 text-xs text-slate-500">
                กำหนดสิทธิ์การใช้งานระบบวันลาของบุคลากรในโรงเรียน
              </p>
            </Link>

            {access.level === 'super' && (
              <>
                <Link
                  to="/leave-admin"
                  className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">ภาพรวมตั้งค่าวันลา</p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    สถิติและสถานะของระบบวันลาทุกโรงเรียน
                  </p>
                </Link>
                <Link
                  to="/forms"
                  className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">ออกแบบฟอร์มใบลา</p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    ปรับแต่งหัวใบลาและแบบฟอร์มไปราชการ
                  </p>
                </Link>
                <Link
                  to="/line"
                  className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">LINE แจ้งเตือน</p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    ตั้งค่ากลุ่ม LINE แจ้งเตือนใบลาและลงเวลา
                  </p>
                </Link>
                <Link
                  to="/role-permissions"
                  className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">เพดานสิทธิ์และเมนู</p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    กำหนดสิทธิ์ตามบทบาทและการมองเห็นเมนู
                  </p>
                </Link>
                <Link
                  to="/schools"
                  className="rounded-xl border border-line p-4 transition-colors hover:border-brand-200 hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">จัดการโรงเรียน</p>
                  <p className="mt-0.5 text-xs text-slate-500">
                    ข้อมูลหัวใบลา โลโก้ และหน้าจอมือถือ
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
