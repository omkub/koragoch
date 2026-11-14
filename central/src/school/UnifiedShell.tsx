import { useEffect, useState, type ReactNode } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import {
  Bell,
  Building2,
  FileText,
  Folder,
  GraduationCap,
  Layers,
  LayoutDashboard,
  LogOut,
  Menu,
  Settings,
  ShieldCheck,
  Users,
  Wallet,
  X,
} from 'lucide-react';
import { supabase, type Access } from '../supabase';
import type { DivisionIconName, DivisionWithModules } from './mapping';
import type { SchoolBasic } from './types';

interface UnifiedShellProps {
  schoolName: string;
  academicTermLabel: string;
  userName: string;
  roleLabel: string;
  access: Access;
  schools: SchoolBasic[];
  selectedSchoolId: number | null;
  canSwitchSchool: boolean;
  onSelectSchool: (id: number) => void;
  onSignOut: () => void;
  divisions: DivisionWithModules[];
  children: ReactNode;
}

const ADMIN_PATH_PREFIXES = [
  '/admin',
  '/leave-admin',
  '/schools',
  '/admins',
  '/staff',
  '/admin-positions',
  '/line',
  '/role-permissions',
  '/user-permissions',
  '/attendance',
  '/forms',
  '/settings',
];

function isAdminPath(pathname: string): boolean {
  return ADMIN_PATH_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  );
}

function getDivisionIcon(iconName: DivisionIconName) {
  switch (iconName) {
    case 'users':
      return Users;
    case 'graduation-cap':
      return GraduationCap;
    case 'file-text':
      return FileText;
    case 'wallet':
      return Wallet;
    default:
      return Folder;
  }
}

interface AdminNavGroup {
  label: string;
  items: {
    to: string;
    label: string;
    icon: typeof Layers;
    superOnly?: boolean;
  }[];
}

const ADMIN_NAV_GROUPS: AdminNavGroup[] = [
  {
    label: 'โครงสร้างโรงเรียนและ Mapping',
    items: [
      { to: '/admin/mapping', label: 'จัดการฝ่ายและ Module', icon: Layers },
      { to: '/admin/division-permissions', label: 'สิทธิ์เข้าถึงแต่ละฝ่าย', icon: ShieldCheck },
      { to: '/settings', label: 'ปีการศึกษาและลิงก์', icon: Settings },
      { to: '/schools', label: 'ข้อมูลโรงเรียน', icon: Building2, superOnly: true },
      { to: '/admins', label: 'ผู้ดูแลโรงเรียน', icon: ShieldCheck, superOnly: true },
    ],
  },
  {
    label: 'ตั้งค่าระบบวันลาส่วนกลาง',
    items: [
      { to: '/user-permissions', label: 'สิทธิ์รายบุคคล (วันลา)', icon: Users },
      {
        to: '/leave-admin',
        label: 'ภาพรวมระบบวันลา',
        icon: LayoutDashboard,
        superOnly: true,
      },
      { to: '/staff', label: 'สถานะบุคลากร', icon: Users, superOnly: true },
      {
        to: '/admin-positions',
        label: 'ตำแหน่งบริหาร',
        icon: ShieldCheck,
        superOnly: true,
      },
      {
        to: '/role-permissions',
        label: 'เพดานสิทธิ์และเมนู',
        icon: ShieldCheck,
        superOnly: true,
      },
      { to: '/line', label: 'LINE แจ้งเตือน', icon: Bell, superOnly: true },
      {
        to: '/attendance',
        label: 'ลงเวลาสแกนหน้า',
        icon: Layers,
        superOnly: true,
      },
      { to: '/forms', label: 'ออกแบบฟอร์มใบลา', icon: FileText, superOnly: true },
    ],
  },
];

export default function UnifiedShell({
  schoolName,
  academicTermLabel,
  userName,
  roleLabel,
  access,
  schools,
  selectedSchoolId,
  canSwitchSchool,
  onSelectSchool,
  onSignOut,
  divisions,
  children,
}: UnifiedShellProps) {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const canAccessAdminMode =
    access.level === 'super' || access.level === 'school';
  const isSuper = access.level === 'super';

  const [mode, setMode] = useState<'school' | 'admin'>(() =>
    canAccessAdminMode && isAdminPath(pathname) ? 'admin' : 'school',
  );
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const [recentNotices, setRecentNotices] = useState<
    { id: number; title: string; published_at: string }[]
  >([]);

  useEffect(() => {
    if (!canAccessAdminMode) {
      setMode('school');
      return;
    }
    if (isAdminPath(pathname)) {
      setMode('admin');
    } else if (pathname === '/' || pathname.startsWith('/division/')) {
      setMode('school');
    }
  }, [pathname, canAccessAdminMode]);

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

  const enabledDivisions = divisions.filter((d) => d.is_enabled);

  function switchToMode(nextMode: 'school' | 'admin') {
    setMode(nextMode);
    if (nextMode === 'admin' && !isAdminPath(pathname)) {
      navigate('/admin/mapping');
    } else if (nextMode === 'school' && isAdminPath(pathname)) {
      navigate('/');
    }
  }

  const renderSidebarContent = () => (
    <div className="flex h-full flex-col border-r border-line bg-white">
      <div className="flex h-16 items-center justify-between border-b border-line px-4">
        <div className="min-w-0">
          <p className="truncate text-sm font-semibold text-ink">{schoolName}</p>
          <p className="truncate text-xs text-slate-500">
            {mode === 'admin'
              ? 'Web หลัก · ผู้ดูแลระบบกลาง'
              : 'Web โรงเรียน · แยกตามฝ่าย'}
          </p>
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

      {/* Mode Switcher for Admin / Super Admin */}
      {canAccessAdminMode && (
        <div className="border-b border-line p-3">
          <div className="grid grid-cols-2 rounded-lg bg-canvas p-1">
            <button
              type="button"
              onClick={() => switchToMode('school')}
              className={`rounded-md py-1.5 text-xs font-medium transition-colors ${
                mode === 'school'
                  ? 'bg-white text-ink shadow-sm'
                  : 'text-slate-500 hover:text-ink'
              }`}
            >
              Web โรงเรียน
            </button>
            <button
              type="button"
              onClick={() => switchToMode('admin')}
              className={`rounded-md py-1.5 text-xs font-medium transition-colors ${
                mode === 'admin'
                  ? 'bg-white text-brand-700 shadow-sm'
                  : 'text-slate-500 hover:text-ink'
              }`}
            >
              ผู้ดูแลระบบกลาง
            </button>
          </div>
        </div>
      )}

      <nav className="flex-1 overflow-y-auto px-3 py-4">
        {mode === 'school' ? (
          <>
            <div>
              <p className="mb-2 px-3 text-xs font-medium text-slate-500">
                ภาพรวมโรงเรียน
              </p>
              <NavLink
                to="/"
                end
                onClick={() => setSidebarOpen(false)}
                className={({ isActive }) =>
                  `flex h-9 items-center gap-2.5 rounded-lg px-3 text-sm transition-colors ${
                    isActive
                      ? 'bg-brand-50 font-medium text-brand-700'
                      : 'text-slate-700 hover:bg-slate-50 hover:text-ink'
                  }`
                }
              >
                <LayoutDashboard
                  className="h-[18px] w-[18px] shrink-0 text-slate-500"
                  strokeWidth={1.5}
                />
                <span className="truncate">หน้าหลักโรงเรียน</span>
              </NavLink>
            </div>

            <div className="mt-6">
              <p className="mb-2 px-3 text-xs font-medium text-slate-500">
                ฝ่ายของโรงเรียน
              </p>
              {enabledDivisions.length === 0 ? (
                <p className="px-3 py-2 text-xs text-slate-400">
                  ยังไม่ได้เปิดใช้งานฝ่ายใด
                </p>
              ) : (
                <div className="space-y-1">
                  {enabledDivisions.map((div) => {
                    const Icon = getDivisionIcon(div.icon_name);
                    const targetPath = `/division/${div.division_key}`;
                    const active =
                      pathname === targetPath ||
                      pathname.startsWith(`${targetPath}/`);
                    const activeModCount = div.modules.filter(
                      (m) => m.is_enabled,
                    ).length;

                    return (
                      <NavLink
                        key={div.id}
                        to={targetPath}
                        onClick={() => setSidebarOpen(false)}
                        className={`flex h-9 items-center justify-between rounded-lg px-3 text-sm transition-colors ${
                          active
                            ? 'bg-brand-50 font-medium text-brand-700'
                            : 'text-slate-700 hover:bg-slate-50 hover:text-ink'
                        }`}
                      >
                        <span className="flex min-w-0 items-center gap-2.5">
                          <Icon
                            className={`h-[18px] w-[18px] shrink-0 ${
                              active ? 'text-brand-600' : 'text-slate-500'
                            }`}
                            strokeWidth={1.5}
                          />
                          <span className="truncate">{div.name}</span>
                        </span>
                        <span className="ml-2 shrink-0 tabular-nums text-[11px] text-slate-400">
                          {activeModCount}
                        </span>
                      </NavLink>
                    );
                  })}
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="space-y-6">
            {ADMIN_NAV_GROUPS.map((group) => {
              const visibleItems = group.items.filter(
                (item) => !item.superOnly || isSuper,
              );
              if (visibleItems.length === 0) return null;
              return (
                <div key={group.label}>
                  <p className="mb-2 px-3 text-xs font-medium text-slate-500">
                    {group.label}
                  </p>
                  <div className="space-y-1">
                    {visibleItems.map((item) => {
                      const Icon = item.icon;
                      return (
                        <NavLink
                          key={item.to}
                          to={item.to}
                          onClick={() => setSidebarOpen(false)}
                          className={({ isActive }) =>
                            `flex h-9 items-center gap-2.5 rounded-lg px-3 text-sm transition-colors ${
                              isActive
                                ? 'bg-brand-50 font-medium text-brand-700'
                                : 'text-slate-700 hover:bg-slate-50 hover:text-ink'
                            }`
                          }
                        >
                          <Icon
                            className="h-[18px] w-[18px] shrink-0 text-slate-500"
                            strokeWidth={1.5}
                          />
                          <span className="truncate">{item.label}</span>
                        </NavLink>
                      );
                    })}
                  </div>
                </div>
              );
            })}
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
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 lg:block">
        {renderSidebarContent()}
      </aside>

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
                className="max-w-[240px] truncate rounded-lg border border-line bg-white px-3 py-1.5 text-xs font-medium text-ink outline-none focus:border-brand-500"
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
              onClick={() => setNotifOpen((prev) => !prev)}
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
              <div className="absolute right-0 top-12 z-30 w-80 rounded-xl border border-line bg-white p-3 shadow-lg">
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
          </div>
        </header>

        <main className="mx-auto w-full max-w-[1440px] flex-1 p-6 sm:p-8">
          {children}
        </main>
      </div>
    </div>
  );
}
