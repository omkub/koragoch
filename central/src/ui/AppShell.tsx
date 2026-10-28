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
  icon: ReactNode;
  superOnly?: boolean;
}

/** เมนูจัดกลุ่ม — ชื่อหน้าบนแถบบนอ่านจากรายการนี้ */
const NAV: { group: string | null; items: NavItem[] }[] = [
  { group: null, items: [{ to: '/', label: 'ภาพรวม', icon: <IconDashboard />, superOnly: true }] },
  {
    group: 'โรงเรียน',
    items: [
      { to: '/schools', label: 'โรงเรียน', icon: <IconSchool />, superOnly: true },
      { to: '/admins', label: 'ผู้ดูแลโรงเรียน', icon: <IconUserCheck />, superOnly: true },
      { to: '/staff', label: 'บุคลากร', icon: <IconUsers />, superOnly: true },
      { to: '/admin-positions', label: 'ตำแหน่งบริหาร', icon: <IconStar />, superOnly: true },
    ],
  },
  {
    group: 'สิทธิ์',
    items: [
      { to: '/role-permissions', label: 'เพดานสิทธิ์', icon: <IconShield />, superOnly: true },
      { to: '/user-permissions', label: 'สิทธิ์ผู้ใช้', icon: <IconLock /> },
    ],
  },
  {
    group: 'ระบบ',
    items: [
      { to: '/line', label: 'LINE แจ้งเตือน', icon: <IconChat />, superOnly: true },
      { to: '/attendance', label: 'ลงเวลา (สแกนหน้า)', icon: <IconClock />, superOnly: true },
      { to: '/forms', label: 'แบบฟอร์ม', icon: <IconDoc />, superOnly: true },
    ],
  },
];

const navClass = ({ isActive }: { isActive: boolean }) =>
  `flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-[13.5px] font-medium transition-colors ${
    isActive ? 'bg-slate-100 font-semibold text-ink' : 'text-slate-600 hover:bg-slate-50 hover:text-ink'
  }`;

function Sidebar({ isSuper, onNavigate }: { isSuper: boolean; onNavigate?: () => void }) {
  return (
    <div className="flex h-full flex-col gap-0.5 px-3.5 py-4">
      <div className="flex items-center gap-2.5 px-2 pb-4">
        <div className="grid h-9 w-9 place-items-center rounded-[10px] bg-ink text-[15px] font-bold text-white">ลา</div>
        <div className="min-w-0">
          <div className="text-[15px] font-bold leading-tight">ระบบวันลา</div>
          <div className="truncate text-xs text-slate-500">
            {isSuper ? 'ผู้ดูแลระบบส่วนกลาง' : 'ผู้ดูแลระบบโรงเรียน'}
          </div>
        </div>
      </div>

      <nav className="flex flex-1 flex-col gap-0.5 overflow-y-auto">
        {NAV.map(({ group, items }) => {
          const visible = items.filter((i) => isSuper || !i.superOnly);
          if (!visible.length) return null;
          return (
            <div key={group ?? 'main'} className="flex flex-col gap-0.5">
              {group && (
                <div className="px-2.5 pb-1.5 pt-4 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                  {group}
                </div>
              )}
              {visible.map((i) => (
                <NavLink key={i.to} to={i.to} end={i.to === '/'} className={navClass} onClick={onNavigate}>
                  {i.icon}
                  {i.label}
                </NavLink>
              ))}
            </div>
          );
        })}
      </nav>

      <div className="mt-3 flex flex-col gap-0.5 border-t border-line pt-3">
        <a href="../" className={navClass({ isActive: false })}>
          <IconExternal />
          เปิดแอปครู
        </a>
        <button
          type="button"
          className={`${navClass({ isActive: false })} text-left`}
          onClick={() => supabase.auth.signOut()}
        >
          <IconLogout />
          ออกจากระบบ
        </button>
      </div>
    </div>
  );
}

/**
 * โครงหน้าเว็บส่วนกลาง — จอกว้าง: เมนูซ้ายติดจอ / มือถือ: เมนูเลื่อนออกจากซ้ายด้วยปุ่ม ☰
 */
export default function AppShell({ isSuper, children }: { isSuper: boolean; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const location = useLocation();

  // เปลี่ยนหน้าแล้วปิดเมนูมือถือ + เลื่อนกลับบนสุด
  useEffect(() => {
    setOpen(false);
    window.scrollTo(0, 0);
  }, [location.pathname]);

  const current =
    NAV.flatMap((g) => g.items).find((i) => (i.to === '/' ? location.pathname === '/' : location.pathname.startsWith(i.to)))
      ?.label ?? '';

  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[248px_minmax(0,1fr)]">
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
            className="absolute inset-0 bg-slate-900/30"
            onClick={() => setOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-[272px] max-w-[85vw] bg-white shadow-xl">
            <button
              type="button"
              aria-label="ปิดเมนู"
              className="absolute right-3 top-4 rounded-lg p-1.5 text-slate-500 hover:bg-slate-100"
              onClick={() => setOpen(false)}
            >
              <IconClose />
            </button>
            <Sidebar isSuper={isSuper} onNavigate={() => setOpen(false)} />
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-col">
        <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-line bg-canvas/90 px-4 backdrop-blur sm:px-7 lg:h-[60px] lg:border-b-0">
          <button
            type="button"
            aria-label="เปิดเมนู"
            className="-ml-1.5 rounded-lg p-1.5 text-slate-600 hover:bg-slate-100 lg:hidden"
            onClick={() => setOpen(true)}
          >
            <IconMenu />
          </button>
          <div className="min-w-0 flex-1 truncate text-[13px] text-slate-500">
            <span className="hidden sm:inline">{isSuper ? 'ผู้ดูแลส่วนกลาง' : 'ผู้ดูแลโรงเรียน'} / </span>
            <b className="font-semibold text-ink">{current}</b>
          </div>
        </header>
        <main className="min-w-0 flex-1 px-4 pb-10 pt-3 sm:px-7">{children}</main>
      </div>
    </div>
  );
}
