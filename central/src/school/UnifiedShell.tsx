import { useEffect, useState, type ReactNode } from 'react';
import { Link, NavLink, useLocation } from 'react-router-dom';
import {
  ArrowLeft,
  Bell,
  Building2,
  CalendarDays,
  ExternalLink,
  FileText,
  Folder,
  GraduationCap,
  Layers,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageCircle,
  ScanFace,
  Settings,
  ShieldCheck,
  UserCog,
  Users,
  Wallet,
  X,
} from 'lucide-react';
import { navigateToLeaveApp, supabase, type Access } from '../supabase';
import type { DivisionIconName, DivisionWithModules } from './mapping';
import type { SchoolBasic } from './types';

/**
 * โครงหน้าของ web แยกเป็น 3 พื้นที่ (ไม่มีปุ่มสลับ "Web โรงเรียน / ผู้ดูแลระบบกลาง" แล้ว)
 *   ① school  ระบบงานโรงเรียน — บุคลากรทุกคน: หน้าหลัก, ระบบวันลา (ลิงก์ไปแอปเดิม), ฝ่าย
 *   ② manage  ตั้งค่าโรงเรียน — แอดมินโรงเรียน (เฉพาะโรงเรียนตัวเอง) / ส่วนกลางที่กำลังจัดการโรงเรียนหนึ่ง
 *   ③ hq      ศูนย์ผู้ดูแลส่วนกลาง — ผู้ดูแลส่วนกลางเท่านั้น
 * พื้นที่ตัดสินจากเส้นทาง (ไม่เปลี่ยนเส้นทางเดิม เพราะ app ลิงก์เข้ามาที่ admin/mapping ฯลฯ)
 * โรงเรียนที่กำลังทำงาน มาจากที่เดียว: ตัวเลือกในศูนย์ส่วนกลาง (เฉพาะผู้ดูแลส่วนกลาง)
 */
export type ShellArea = 'school' | 'manage' | 'hq';

const HQ_PREFIXES = ['/hq', '/schools', '/admins', '/role-permissions', '/leave-admin'];
const MANAGE_PREFIXES = [
  '/admin',
  '/user-permissions',
  '/settings',
  '/staff',
  '/admin-positions',
  '/line',
  '/attendance',
  '/forms',
];

const matches = (pathname: string, prefix: string) =>
  pathname === prefix || pathname.startsWith(`${prefix}/`);

export function areaOfPath(pathname: string): ShellArea {
  if (HQ_PREFIXES.some((p) => matches(pathname, p))) return 'hq';
  if (MANAGE_PREFIXES.some((p) => matches(pathname, p))) return 'manage';
  return 'school';
}

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
  isEmbedded?: boolean;
  children: ReactNode;
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

interface NavItem {
  to: string;
  label: string;
  icon: typeof Layers;
  /** หน้าที่ฐานข้อมูลยังให้เขียนได้เฉพาะส่วนกลาง (จะเปิดให้แอดมินโรงเรียนใน PR ถัดไป) */
  superOnly?: boolean;
}

const MANAGE_NAV: { label: string; items: NavItem[] }[] = [
  {
    label: 'บุคลากรและสิทธิ์',
    items: [
      { to: '/admin/mapping', label: 'ฝ่ายและบุคลากร', icon: Layers },
      { to: '/admin/division-permissions', label: 'สิทธิ์ตามบทบาท', icon: ShieldCheck },
      { to: '/user-permissions', label: 'สิทธิ์รายบุคคล', icon: UserCog },
    ],
  },
  {
    label: 'ระบบวันลา',
    items: [
      { to: '/staff', label: 'สถานะบุคลากร', icon: Users, superOnly: true },
      { to: '/admin-positions', label: 'ตำแหน่งบริหาร', icon: ShieldCheck, superOnly: true },
      { to: '/forms', label: 'แบบฟอร์มใบลาของโรงเรียน', icon: FileText, superOnly: true },
      { to: '/line', label: 'LINE แจ้งเตือน', icon: MessageCircle, superOnly: true },
      { to: '/attendance', label: 'เครื่องสแกนลงเวลา', icon: ScanFace, superOnly: true },
    ],
  },
  {
    label: 'โรงเรียน',
    items: [{ to: '/settings', label: 'ปีการศึกษาและลิงก์', icon: CalendarDays }],
  },
];

const HQ_NAV: { label: string; items: NavItem[] }[] = [
  {
    label: 'ทุกโรงเรียน',
    items: [
      { to: '/hq', label: 'ภาพรวมทุกโรงเรียน', icon: LayoutDashboard },
      { to: '/schools', label: 'ข้อมูลโรงเรียน', icon: Building2 },
      { to: '/admins', label: 'ผู้ดูแลโรงเรียน', icon: ShieldCheck },
    ],
  },
  {
    label: 'ใช้ร่วมทุกโรงเรียน',
    items: [
      { to: '/hq/forms', label: 'แม่แบบฟอร์มกลาง', icon: FileText },
      { to: '/hq/line', label: 'LINE (สะพานเชื่อมกลาง)', icon: MessageCircle },
    ],
  },
  {
    label: 'โรงเรียนที่เลือก',
    items: [{ to: '/role-permissions', label: 'แพ็กเกจและเพดานสิทธิ์', icon: Settings }],
  },
];

const navClass = (isActive: boolean) =>
  `flex h-9 items-center gap-2.5 rounded-lg px-3 text-sm transition-colors ${
    isActive
      ? 'bg-brand-50 font-medium text-brand-700'
      : 'text-slate-700 hover:bg-slate-50 hover:text-ink'
  }`;

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
  isEmbedded = false,
  children,
}: UnifiedShellProps) {
  const { pathname } = useLocation();
  const isSuper = access.level === 'super';
  const canManageSchool = isSuper || access.level === 'school';
  const area = areaOfPath(pathname);

  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const [recentNotices, setRecentNotices] = useState<
    { id: number; title: string; published_at: string }[]
  >([]);

  useEffect(() => {
    setSidebarOpen(false);
  }, [pathname]);

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

  const renderNavGroups = (groups: { label: string; items: NavItem[] }[]) => (
    <div className="space-y-6">
      {groups.map((group) => {
        const items = group.items.filter((i) => !i.superOnly || isSuper);
        if (items.length === 0) return null;
        return (
          <div key={group.label}>
            <p className="mb-2 px-3 text-xs font-medium text-slate-500">{group.label}</p>
            <div className="space-y-1">
              {items.map((item) => {
                const Icon = item.icon;
                return (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    end={item.to === '/hq'}
                    className={({ isActive }) => navClass(isActive)}
                  >
                    <Icon className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
                    <span className="truncate">{item.label}</span>
                  </NavLink>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );

  // ── ① ระบบงานโรงเรียน ──
  const schoolNav = (
    <div className="space-y-6">
      <div className="space-y-1">
        <NavLink to="/" end className={({ isActive }) => navClass(isActive)}>
          <LayoutDashboard className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
          <span className="truncate">หน้าหลักโรงเรียน</span>
        </NavLink>
        <button
          type="button"
          onClick={() => navigateToLeaveApp()}
          className={`${navClass(false)} w-full justify-between`}
        >
          <span className="flex min-w-0 items-center gap-2.5">
            <CalendarDays className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
            <span className="truncate">ระบบวันลา</span>
          </span>
          <ExternalLink className="h-3.5 w-3.5 shrink-0 text-slate-400" strokeWidth={1.5} />
        </button>
      </div>

      <div>
        <p className="mb-2 px-3 text-xs font-medium text-slate-500">ฝ่ายของฉัน</p>
        {enabledDivisions.length === 0 ? (
          <p className="px-3 py-2 text-xs leading-relaxed text-slate-500">
            ยังไม่ได้รับสิทธิ์ฝ่าย — รอแอดมินโรงเรียนกำหนด
          </p>
        ) : (
          <div className="space-y-1">
            {enabledDivisions.map((div) => {
              const Icon = getDivisionIcon(div.icon_name);
              const targetPath = `/division/${div.division_key}`;
              const active = matches(pathname, targetPath);
              return (
                <NavLink key={div.id} to={targetPath} className={navClass(active)}>
                  <Icon
                    className={`h-[18px] w-[18px] shrink-0 ${active ? 'text-brand-600' : 'text-slate-500'}`}
                    strokeWidth={1.5}
                  />
                  <span className="truncate">{div.name}</span>
                </NavLink>
              );
            })}
          </div>
        )}
      </div>

      {canManageSchool && (
        <div className="border-t border-line pt-4">
          <Link to="/admin/mapping" className={navClass(false)}>
            <Settings className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
            <span className="truncate">ตั้งค่าโรงเรียน</span>
          </Link>
          {isSuper && (
            <Link to="/hq" className={navClass(false)}>
              <Building2 className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
              <span className="truncate">ศูนย์ผู้ดูแลส่วนกลาง</span>
            </Link>
          )}
        </div>
      )}
    </div>
  );

  // ── ③ ศูนย์ส่วนกลาง: ตัวเลือกโรงเรียนอยู่ที่นี่ที่เดียว ──
  const hqNav = (
    <div className="space-y-6">
      {renderNavGroups(HQ_NAV)}
      <div className="space-y-2 border-t border-line pt-4">
        <label className="flex flex-col gap-1 px-3 text-xs font-medium text-slate-500">
          โรงเรียนที่จะจัดการ
          <select
            value={selectedSchoolId ?? ''}
            onChange={(e) => onSelectSchool(Number(e.target.value))}
            disabled={!canSwitchSchool}
            className="input py-1.5 text-sm text-ink"
          >
            {schools.map((s) => (
              <option key={s.id_school} value={s.id_school}>
                {s.fullName || `โรงเรียน #${s.id_school}`}
              </option>
            ))}
          </select>
        </label>
        <Link to="/admin/mapping" className={navClass(false)}>
          <Settings className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
          <span className="truncate">ตั้งค่าโรงเรียนนี้</span>
        </Link>
        <Link to="/" className={navClass(false)}>
          <LayoutDashboard className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
          <span className="truncate">ดูหน้าโรงเรียนนี้</span>
        </Link>
      </div>
    </div>
  );

  const manageNav = (
    <div className="space-y-6">
      <Link to="/" className={navClass(false)}>
        <ArrowLeft className="h-[18px] w-[18px] shrink-0 text-slate-500" strokeWidth={1.5} />
        <span className="truncate">กลับหน้าโรงเรียน</span>
      </Link>
      {renderNavGroups(MANAGE_NAV)}
    </div>
  );

  const areaSubtitle =
    area === 'hq'
      ? 'ศูนย์ผู้ดูแลส่วนกลาง'
      : area === 'manage'
        ? 'ตั้งค่าโรงเรียน'
        : 'ระบบงานโรงเรียน';

  const renderSidebarContent = () => (
    <div className="flex h-full flex-col border-r border-line bg-white">
      <div
        className={`flex h-16 items-center justify-between border-b px-4 ${
          area === 'hq' ? 'border-brand-700 bg-brand-700 text-white' : 'border-line'
        }`}
      >
        <div className="min-w-0">
          <p className={`truncate text-sm font-semibold ${area === 'hq' ? 'text-white' : 'text-ink'}`}>
            {area === 'hq' ? 'ศูนย์ผู้ดูแลส่วนกลาง' : schoolName}
          </p>
          <p className={`truncate text-xs ${area === 'hq' ? 'text-white/80' : 'text-slate-500'}`}>
            {area === 'hq' ? 'ดูแลทุกโรงเรียน' : areaSubtitle}
          </p>
        </div>
        <button
          type="button"
          onClick={() => setSidebarOpen(false)}
          className="rounded-lg p-1.5 hover:bg-black/5 lg:hidden"
          aria-label="ปิดเมนู"
        >
          <X className="h-4 w-4" strokeWidth={1.5} />
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-4">
        {area === 'hq' ? hqNav : area === 'manage' ? manageNav : schoolNav}
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
            aria-label="ออกจากระบบ"
            className="rounded-lg p-1.5 text-slate-500 transition-colors hover:bg-slate-100 hover:text-ink"
          >
            <LogOut className="h-4 w-4" strokeWidth={1.5} />
          </button>
        </div>
      </div>
    </div>
  );

  // ป้ายบอกพื้นที่และขอบเขตบนแถบหัว
  const contextBadge =
    area === 'hq' ? (
      <span className="rounded-md border border-white/70 px-2 py-0.5 text-xs font-semibold text-white">
        ส่วนกลาง
      </span>
    ) : area === 'manage' ? (
      <span className="truncate rounded-md bg-brand-50 px-2.5 py-1 text-xs font-semibold text-brand-700">
        {isSuper
          ? `กำลังจัดการ: ${schoolName} · ในฐานะผู้ดูแลส่วนกลาง`
          : `ตั้งค่า · มีผลเฉพาะ${schoolName}`}
      </span>
    ) : isSuper ? (
      <span className="truncate rounded-md bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-800">
        กำลังดู {schoolName} ในฐานะผู้ดูแลส่วนกลาง
      </span>
    ) : (
      <span className="hidden truncate text-sm font-semibold text-ink sm:inline">{schoolName}</span>
    );

  return (
    <div className="min-h-screen bg-canvas text-ink">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 lg:block">
        {renderSidebarContent()}
      </aside>

      {sidebarOpen && (
        <div className="fixed inset-0 z-40 flex lg:hidden">
          <div className="fixed inset-0 bg-slate-900/30" onClick={() => setSidebarOpen(false)} />
          <aside className="relative z-50 w-64 max-w-[80vw]">{renderSidebarContent()}</aside>
        </div>
      )}

      <div className="flex min-h-screen flex-col lg:pl-64">
        <header
          className={`sticky top-0 z-20 flex h-16 items-center justify-between gap-3 border-b px-4 sm:px-6 ${
            area === 'hq' ? 'border-brand-700 bg-brand-700' : 'border-line bg-white'
          }`}
        >
          <div className="flex min-w-0 items-center gap-3">
            <button
              type="button"
              onClick={() => setSidebarOpen(true)}
              className={`rounded-lg p-2 lg:hidden ${area === 'hq' ? 'text-white hover:bg-white/10' : 'text-slate-600 hover:bg-slate-100'}`}
              aria-label="เปิดเมนู"
            >
              <Menu className="h-[18px] w-[18px]" strokeWidth={1.5} />
            </button>
            {contextBadge}
            {area === 'school' && (
              <span className="hidden rounded-lg border border-line bg-canvas px-3 py-1.5 text-xs font-medium text-slate-700 md:inline">
                {academicTermLabel}
              </span>
            )}
          </div>

          <div className="relative flex items-center gap-2">
            {area === 'school' &&
              (isEmbedded ? (
                <a
                  href={`${window.location.pathname}?embedded=0${selectedSchoolId ? `&school_id=${selectedSchoolId}` : ''}`}
                  target="_blank"
                  rel="noreferrer"
                  className="btn-secondary btn-sm"
                  title="เปิดเว็บโรงเรียนเต็มหน้าจอในแท็บใหม่"
                >
                  <ExternalLink className="h-3.5 w-3.5" strokeWidth={1.5} />
                  <span className="hidden sm:inline">เปิดเต็มจอ</span>
                </a>
              ) : (
                <button
                  type="button"
                  onClick={() => navigateToLeaveApp()}
                  className="btn-secondary btn-sm"
                  title="เปิดระบบวันลา"
                >
                  <span>ระบบวันลา</span>
                  <ExternalLink className="h-3.5 w-3.5" strokeWidth={1.5} />
                </button>
              ))}

            {area === 'school' && (
              <>
                <button
                  type="button"
                  onClick={() => setNotifOpen((prev) => !prev)}
                  className={`relative rounded-lg p-2 transition-colors ${
                    notifOpen ? 'bg-brand-50 text-brand-700' : 'text-slate-600 hover:bg-slate-100'
                  }`}
                  aria-label="ประกาศล่าสุด"
                >
                  <Bell className="h-[18px] w-[18px]" strokeWidth={1.5} />
                  {recentNotices.length > 0 && (
                    <span className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-brand-600" />
                  )}
                </button>

                {notifOpen && (
                  <div className="absolute right-0 top-12 z-30 w-80 rounded-xl border border-line bg-white p-3 shadow-lg">
                    <p className="mb-2 px-1 text-xs font-medium text-slate-500">ประกาศล่าสุดของโรงเรียน</p>
                    {recentNotices.length === 0 ? (
                      <p className="px-1 py-3 text-xs text-slate-500">ยังไม่มีประกาศใหม่</p>
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
              </>
            )}

            {area !== 'school' && (
              <Link
                to="/"
                className={area === 'hq' ? 'btn-sm rounded-lg border border-white/70 px-3 text-white hover:bg-white/10' : 'btn-secondary btn-sm'}
              >
                {area === 'hq' ? 'ดูหน้าโรงเรียน' : 'กลับหน้าโรงเรียน'}
              </Link>
            )}
          </div>
        </header>

        <main className="mx-auto w-full max-w-[1440px] flex-1 p-6 sm:p-8">{children}</main>
      </div>
    </div>
  );
}
