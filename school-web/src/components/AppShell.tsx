import { useEffect, useState, type ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import {
  Bell,
  BookOpen,
  Building2,
  CalendarClock,
  ExternalLink,
  FileText,
  GraduationCap,
  LayoutDashboard,
  LayoutGrid,
  LogOut,
  Menu,
  Settings,
  Users,
  X,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import type { SchoolInfo, SchoolModuleLink } from '../types/school';

interface AppShellProps {
  schoolName: string;
  academicTermLabel: string;
  userName: string;
  roleLabel: string;
  schools: SchoolInfo[];
  selectedSchoolId: number | null;
  canSwitchSchool: boolean;
  onSelectSchool: (id: number) => void;
  onSignOut: () => void;
  modules: SchoolModuleLink[];
  children: ReactNode;
}

interface NavGroup {
  label: string;
  items: {
    to: string;
    label: string;
    icon: typeof LayoutDashboard;
    badge?: string;
  }[];
}

const NAV_GROUPS: NavGroup[] = [
  {
    label: 'ภาพรวม',
    items: [
      { to: '/', label: 'หน้าหลักโรงเรียน', icon: LayoutDashboard },
    ],
  },
  {
    label: 'งานบุคคล',
    items: [
      { to: '/staff', label: 'ทะเบียนบุคลากร', icon: Users },
      { to: '/departments', label: 'ฝ่ายและกลุ่มสาระ', icon: Building2 },
    ],
  },
  {
    label: 'งานวิชาการและนักเรียน',
    items: [
      { to: '/students', label: 'ทะเบียนนักเรียน', icon: GraduationCap },
      { to: '/academics', label: 'หลักสูตรและตารางสอน', icon: BookOpen },
    ],
  },
  {
    label: 'งานบริหารทั่วไป',
    items: [
      { to: '/documents', label: 'สารบรรณอิเล็กทรอนิกส์', icon: FileText },
    ],
  },
  {
    label: 'ระบบโรงเรียน',
    items: [
      { to: '/settings', label: 'ตั้งค่าโรงเรียนและลิงก์', icon: Settings },
    ],
  },
];

export default function AppShell({
  schoolName,
  academicTermLabel,
  userName,
  roleLabel,
  schools,
  selectedSchoolId,
  canSwitchSchool,
  onSelectSchool,
  onSignOut,
  modules,
  children,
}: AppShellProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [launcherOpen, setLauncherOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const [recentNotices, setRecentNotices] = useState<
    { id: number; title: string; published_at: string }[]
  >([]);

  useEffect(() => {
    if (!selectedSchoolId) return;
    supabase
      .from('SchoolWebAnnouncements')
      .select('id, title, published_at')
      .eq('id_school', selectedSchoolId)
      .order('published_at', { ascending: false })
      .limit(4)
      .then(({ data }) => {
        setRecentNotices(
          (data as { id: number; title: string; published_at: string }[] | null) ?? [],
        );
      });
  }, [selectedSchoolId]);

  const enabledModules = modules.filter((m) => m.is_enabled);

  const renderSidebarContent = () => (
    <div className="flex h-full flex-col border-r border-line bg-white">
      <div className="flex h-16 items-center justify-between border-b border-line px-4">
        <div className="min-w-0">
          <p className="truncate text-sm font-semibold text-ink">{schoolName}</p>
          <p className="truncate text-xs text-slate-500">ระบบบริหารจัดการโรงเรียน</p>
        </div>
        <button
          type="button"
          onClick={() => setSidebarOpen(false)}
          className="rounded-lg p-1.5 text-slate-500 hover:bg-slate-100 lg:hidden"
          aria-label="ปิดเมนู"
        >
          <X className="h-4 w-4" strokeWidth={1.5} />
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-4">
        {NAV_GROUPS.map((group, groupIdx) => (
          <div key={group.label} className={groupIdx > 0 ? 'mt-6' : ''}>
            <p className="mb-2 px-3 text-xs font-medium text-slate-500">
              {group.label}
            </p>
            <div className="space-y-1">
              {group.items.map((item) => {
                const Icon = item.icon;
                return (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    end={item.to === '/'}
                    onClick={() => setSidebarOpen(false)}
                    className={({ isActive }) =>
                      `flex h-9 items-center justify-between rounded-lg px-3 text-sm transition-colors ${
                        isActive
                          ? 'bg-brand-50 font-medium text-brand-700'
                          : 'text-slate-700 hover:bg-slate-50 hover:text-ink'
                      }`
                    }
                  >
                    <span className="flex min-w-0 items-center gap-2.5">
                      <Icon className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
                      <span className="truncate">{item.label}</span>
                    </span>
                    {item.badge && (
                      <span className="ml-2 shrink-0 text-[11px] text-slate-400">
                        {item.badge}
                      </span>
                    )}
                  </NavLink>
                );
              })}
            </div>
          </div>
        ))}

        {enabledModules.length > 0 && (
          <div className="mt-6">
            <p className="mb-2 px-3 text-xs font-medium text-slate-500">
              ระบบย่อยที่เชื่อมต่อ
            </p>
            <div className="space-y-1">
              {enabledModules.map((mod) => (
                <a
                  key={mod.id ?? mod.module_key}
                  href={mod.url}
                  target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
                  rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
                  className="flex h-9 items-center justify-between rounded-lg px-3 text-sm text-slate-700 transition-colors hover:bg-slate-50 hover:text-ink"
                >
                  <span className="flex min-w-0 items-center gap-2.5">
                    <CalendarClock className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
                    <span className="truncate">{mod.title}</span>
                  </span>
                  <ExternalLink className="h-3.5 w-3.5 shrink-0 text-slate-400" strokeWidth={1.5} />
                </a>
              ))}
            </div>
          </div>
        )}
      </nav>

      <div className="border-t border-line p-3">
        <div className="flex items-center justify-between gap-2 rounded-lg px-2 py-1.5">
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-ink">{userName}</p>
            <p className="truncate text-xs text-slate-500">{roleLabel}</p>
          </div>
          <button
            type="button"
            onClick={onSignOut}
            title="ออกจากระบบ"
            className="rounded-lg p-1.5 text-slate-500 transition-colors hover:bg-slate-100 hover:text-ink"
          >
            <LogOut className="h-4 w-4" strokeWidth={1.5} />
          </button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-canvas text-ink">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 lg:block">
        {renderSidebarContent()}
      </aside>

      {/* Mobile drawer */}
      {sidebarOpen && (
        <div className="fixed inset-0 z-40 flex lg:hidden">
          <div
            className="fixed inset-0 bg-slate-900/30"
            onClick={() => setSidebarOpen(false)}
          />
          <aside className="relative z-50 w-64 max-w-[80vw]">
            {renderSidebarContent()}
          </aside>
        </div>
      )}

      {/* Main area */}
      <div className="flex min-h-screen flex-col lg:pl-64">
        <header className="sticky top-0 z-20 flex h-16 items-center justify-between gap-3 border-b border-line bg-white px-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-3">
            <button
              type="button"
              onClick={() => setSidebarOpen(true)}
              className="rounded-lg p-2 text-slate-600 hover:bg-slate-100 lg:hidden"
              aria-label="เปิดเมนู"
            >
              <Menu className="h-[18px] w-[18px]" strokeWidth={1.5} />
            </button>

            {canSwitchSchool && schools.length > 1 && (
              <select
                value={selectedSchoolId ?? ''}
                onChange={(e) => onSelectSchool(Number(e.target.value))}
                aria-label="เลือกโรงเรียน"
                className="max-w-[220px] truncate rounded-lg border border-line bg-white px-3 py-1.5 text-xs font-medium text-ink outline-none focus:border-brand-500"
              >
                {schools.map((s) => (
                  <option key={s.id_school} value={s.id_school}>
                    {s.fullName || `โรงเรียน #${s.id_school}`}
                  </option>
                ))}
              </select>
            )}

            <div className="hidden items-center gap-2 rounded-lg border border-line bg-canvas px-3 py-1.5 text-xs font-medium text-slate-700 sm:flex">
              <span>{academicTermLabel}</span>
            </div>
          </div>

          <div className="relative flex items-center gap-2">
            <button
              type="button"
              onClick={() => {
                setNotifOpen((prev) => !prev);
                setLauncherOpen(false);
              }}
              className={`relative rounded-lg p-2 transition-colors ${
                notifOpen
                  ? 'bg-brand-50 text-brand-700'
                  : 'text-slate-600 hover:bg-slate-100'
              }`}
              aria-label="แจ้งเตือน"
            >
              <Bell className="h-[18px] w-[18px]" strokeWidth={1.5} />
              {recentNotices.length > 0 && (
                <span className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-brand-600" />
              )}
            </button>

            {notifOpen && (
              <div className="absolute right-12 top-12 z-30 w-80 rounded-xl border border-line bg-white p-3 shadow-lg">
                <p className="mb-2 px-1 text-xs font-medium text-slate-500">
                  ประกาศล่าสุดของโรงเรียน
                </p>
                {recentNotices.length === 0 ? (
                  <p className="px-1 py-3 text-xs text-slate-500">
                    ยังไม่มีประกาศใหม่
                  </p>
                ) : (
                  <ul className="divide-y divide-line">
                    {recentNotices.map((n) => (
                      <li key={n.id} className="px-1 py-2">
                        <p className="text-sm font-medium text-ink">{n.title}</p>
                        <p className="mt-0.5 tabular-nums text-[11px] text-slate-400">
                          {new Date(n.published_at).toLocaleDateString('th-TH', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </p>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            )}

            <button
              type="button"
              onClick={() => {
                setLauncherOpen((prev) => !prev);
                setNotifOpen(false);
              }}
              className={`flex items-center gap-2 rounded-lg border px-3 py-1.5 text-sm font-medium transition-colors ${
                launcherOpen
                  ? 'border-brand-200 bg-brand-50 text-brand-700'
                  : 'border-line bg-white text-ink hover:bg-slate-50'
              }`}
            >
              <LayoutGrid className="h-4 w-4" strokeWidth={1.5} />
              <span className="hidden sm:inline">ระบบย่อย</span>
            </button>

            {launcherOpen && (
              <div className="absolute right-0 top-12 z-30 w-80 rounded-xl border border-line bg-white p-3 shadow-lg">
                <p className="mb-2 px-1 text-xs font-medium text-slate-500">
                  เปิดใช้งานระบบที่เชื่อมต่อ
                </p>
                <div className="space-y-1">
                  {enabledModules.map((mod) => (
                    <a
                      key={mod.id ?? mod.module_key}
                      href={mod.url}
                      target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
                      rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
                      onClick={() => setLauncherOpen(false)}
                      className="flex items-start justify-between gap-3 rounded-lg p-2.5 transition-colors hover:bg-slate-50"
                    >
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-ink">{mod.title}</p>
                        <p className="mt-0.5 text-xs text-slate-500">
                          {mod.description}
                        </p>
                      </div>
                      <ExternalLink className="mt-0.5 h-4 w-4 shrink-0 text-slate-400" strokeWidth={1.5} />
                    </a>
                  ))}
                </div>
              </div>
            )}
          </div>
        </header>

        <main className="mx-auto w-full max-w-[1440px] flex-1 p-6 sm:p-8">
          {children}
        </main>
      </div>
    </div>
  );
}
