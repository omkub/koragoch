import { useEffect, useState, type ReactNode } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { supabase } from '../supabase';
import {
  IconChat,
  IconClock,
  IconClose,
  IconDashboard,
  IconDoc,
  IconExternal,
  IconLock,
  IconLogout,
  IconMenu,
  IconSchool,
  IconShield,
  IconStar,
  IconUserCheck,
  IconUsers,
} from './icons';

interface NavItem {
  to: string;
  label: string;
  desc: string;
  icon: ReactNode;
  superOnly?: boolean;
}

/** เมนูจัดกลุ่มเป็น 4 หมวดหมู่ชัดเจน — ชื่อหมวดและชื่อหน้าบนแถบบนอ่านจากรายการนี้ */
const NAV: { group: string; badge: string; items: NavItem[] }[] = [
  {
    group: '1. ภาพรวมและสถานะระบบ',
    badge: 'ภาพรวม',
    items: [
      {
        to: '/',
        label: 'ภาพรวมระบบ',
        desc: 'สถิติและสิ่งที่ต้องจัดการ',
        icon: <IconDashboard />,
        superOnly: true,
      },
    ],
  },
  {
    group: '2. องค์กรและบุคลากร',
    badge: 'องค์กรและบุคลากร',
    items: [
      {
        to: '/schools',
        label: 'โรงเรียน',
        desc: 'ข้อมูลหัวใบลา โลโก้ และหน้าจอมือถือ',
        icon: <IconSchool />,
        superOnly: true,
      },
      {
        to: '/admins',
        label: 'ผู้ดูแลโรงเรียน',
        desc: 'บัญชีแอดมินประจำโรงเรียน',
        icon: <IconUserCheck />,
        superOnly: true,
      },
      {
        to: '/staff',
        label: 'บุคลากร',
        desc: 'สถานะปฏิบัติงาน ลาออก เกษียณ ย้าย',
        icon: <IconUsers />,
        superOnly: true,
      },
      {
        to: '/admin-positions',
        label: 'ตำแหน่งบริหาร',
        desc: 'ดำรงตำแหน่งวันนี้ เปลี่ยนตำแหน่ง ทำเนียบตามปีงบ',
        icon: <IconStar />,
        superOnly: true,
      },
    ],
  },
  {
    group: '3. สิทธิ์และการเข้าถึง',
    badge: 'สิทธิ์และการเข้าถึง',
    items: [
      {
        to: '/role-permissions',
        label: 'เพดานสิทธิ์และเมนู',
        desc: 'เพดานสิทธิ์ การมองเห็นเมนู รายชื่อสิทธิ์',
        icon: <IconShield />,
        superOnly: true,
      },
      {
        to: '/user-permissions',
        label: 'สิทธิ์รายบุคคล',
        desc: 'เปิด/ปิดสิทธิ์รายคนภายใต้เพดาน',
        icon: <IconLock />,
      },
    ],
  },
  {
    group: '4. ระบบเชื่อมต่อและเอกสาร',
    badge: 'ระบบเชื่อมต่อและเอกสาร',
    items: [
      {
        to: '/line',
        label: 'LINE แจ้งเตือน',
        desc: 'สะพานเชื่อมและกลุ่ม LINE รายโรงเรียน',
        icon: <IconChat />,
        superOnly: true,
      },
      {
        to: '/attendance',
        label: 'ลงเวลา (สแกนหน้า)',
        desc: 'เวลาทำงาน เครื่องสแกน และรหัสบุคลากร',
        icon: <IconClock />,
        superOnly: true,
      },
      {
        to: '/forms',
        label: 'ออกแบบฟอร์มเอกสาร',
        desc: 'แม่แบบใบลาและบันทึกไปราชการ',
        icon: <IconDoc />,
        superOnly: true,
      },
    ],
  },
];

const navClass = ({ isActive }: { isActive: boolean }) =>
  `group flex items-center gap-3 rounded-xl px-3 py-2.5 text-[13px] font-medium transition-colors ${
    isActive
      ? 'bg-brand-50 font-semibold text-brand-700 shadow-[inset_3px_0_0_0_#4f46e5]'
      : 'text-slate-600 hover:bg-slate-50 hover:text-ink'
  }`;

function Sidebar({ isSuper, onNavigate }: { isSuper: boolean; onNavigate?: () => void }) {
  return (
    <div className="flex h-full flex-col justify-between px-3.5 py-4">
      {/* ส่วนหัวแบรนด์ */}
      <div className="mb-3 flex items-center gap-3 rounded-2xl border border-slate-100 bg-slate-50/70 p-3">
        <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-brand-600 text-[15px] font-semibold text-white shadow-sm">
          ลา
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-semibold leading-tight text-ink">ระบบบริหารการลา</div>
          <div className="mt-0.5 inline-flex items-center gap-1 text-xs font-medium text-brand-700">
            <span className="h-1.5 w-1.5 rounded-full bg-brand-600" />
            {isSuper ? 'ผู้ดูแลระบบส่วนกลาง' : 'ผู้ดูแลระบบโรงเรียน'}
          </div>
        </div>
      </div>

      {/* รายการเมนูแยกตามหมวดหมู่ */}
      <nav className="flex flex-1 flex-col gap-3 overflow-y-auto pr-0.5">
        {NAV.map(({ group, items }) => {
          const visible = items.filter((i) => isSuper || !i.superOnly);
          if (!visible.length) return null;
          return (
            <div key={group} className="flex flex-col gap-0.5">
              <div className="px-2.5 pb-1 pt-1 text-[11px] font-semibold text-slate-400">
                {group}
              </div>
              {visible.map((i) => (
                <NavLink key={i.to} to={i.to} end={i.to === '/'} className={navClass} onClick={onNavigate}>
                  <span className="shrink-0">{i.icon}</span>
                  <span className="min-w-0 flex-1 truncate">{i.label}</span>
                </NavLink>
              ))}
            </div>
          );
        })}
      </nav>

      {/* ส่วนท้ายเมนู */}
      <div className="mt-3 flex flex-col gap-1 border-t border-line pt-3">
        <a
          href="../"
          className="flex items-center gap-3 rounded-xl px-3 py-2 text-[13px] font-medium text-slate-600 transition-colors hover:bg-slate-50 hover:text-ink"
        >
          <IconExternal />
          <span>สลับไปหน้าแอปสำหรับครู</span>
        </a>
        <button
          type="button"
          className="flex items-center gap-3 rounded-xl px-3 py-2 text-left text-[13px] font-medium text-red-600 transition-colors hover:bg-red-50"
          onClick={() => supabase.auth.signOut()}
        >
          <IconLogout />
          <span>ออกจากระบบ</span>
        </button>
      </div>
    </div>
  );
}

/**
 * โครงหน้าเว็บส่วนกลาง — จอกว้าง: เมนูซ้ายติดจอแยกหมวดหมู่ / มือถือ: เมนูเลื่อนออกจากซ้ายด้วยปุ่ม
 */
export default function AppShell({ isSuper, children }: { isSuper: boolean; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const location = useLocation();

  // เปลี่ยนหน้าแล้วปิดเมนูมือถือ + เลื่อนกลับบนสุด
  useEffect(() => {
    setOpen(false);
    window.scrollTo(0, 0);
  }, [location.pathname]);

  const activeGroup = NAV.find((g) =>
    g.items.some((i) => (i.to === '/' ? location.pathname === '/' : location.pathname.startsWith(i.to))),
  );
  const activeItem = activeGroup?.items.find((i) =>
    i.to === '/' ? location.pathname === '/' : location.pathname.startsWith(i.to),
  );

  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[264px_minmax(0,1fr)]">
      {/* เมนูจอกว้าง */}
      <aside className="sticky top-0 hidden h-screen border-r border-line bg-white lg:block">
        <Sidebar isSuper={isSuper} />
      </aside>

      {/* เมนูมือถือ */}
      {open && (
        <div className="fixed inset-0 z-40 lg:hidden" role="dialog" aria-modal="true">
          <button
            type="button"
            aria-label="ปิดเมนู"
            className="absolute inset-0 bg-slate-900/35 backdrop-blur-[1px]"
            onClick={() => setOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-[280px] max-w-[85vw] bg-white shadow-2xl">
            <button
              type="button"
              aria-label="ปิดเมนู"
              className="absolute right-3 top-4 z-10 rounded-lg p-1.5 text-slate-500 hover:bg-slate-100"
              onClick={() => setOpen(false)}
            >
              <IconClose />
            </button>
            <Sidebar isSuper={isSuper} onNavigate={() => setOpen(false)} />
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-col">
        <header className="sticky top-0 z-30 flex h-14 items-center justify-between gap-3 border-b border-line bg-white/90 px-4 backdrop-blur sm:px-7 lg:h-[60px]">
          <div className="flex min-w-0 items-center gap-2.5">
            <button
              type="button"
              aria-label="เปิดเมนู"
              className="-ml-1.5 rounded-lg p-1.5 text-slate-600 hover:bg-slate-100 lg:hidden"
              onClick={() => setOpen(true)}
            >
              <IconMenu />
            </button>
            <div className="flex min-w-0 items-center gap-2 text-[13px] text-slate-500">
              {activeGroup && (
                <>
                  <span className="hidden rounded-md bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600 sm:inline">
                    {activeGroup.badge}
                  </span>
                  <span className="hidden text-slate-300 sm:inline">/</span>
                </>
              )}
              <b className="truncate font-semibold text-ink">{activeItem?.label ?? ''}</b>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <span className="hidden rounded-full bg-brand-50 px-2.5 py-1 text-xs font-semibold text-brand-700 sm:inline-flex">
              {isSuper ? 'ส่วนกลาง (Super Admin)' : 'ผู้ดูแลโรงเรียน'}
            </span>
            <a href="../" className="btn-secondary btn-sm">
              <IconExternal className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">เปิดแอปครู</span>
            </a>
          </div>
        </header>
        <main className="mx-auto w-full max-w-[1440px] min-w-0 flex-1 px-4 pb-12 pt-5 sm:px-7">{children}</main>
      </div>
    </div>
  );
}
