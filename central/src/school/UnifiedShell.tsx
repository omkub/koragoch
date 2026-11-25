import { useEffect, useState, type ReactNode } from 'react';
import { Link, NavLink, useLocation } from 'react-router-dom';
import {
  Bell,
  Building2,
  CalendarDays,
  ChevronRight,
  ExternalLink,
  FileText,
  Folder,
  Globe,
  GraduationCap,
  Layers,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageCircle,
  Package,
  ScanFace,
  Settings,
  ShieldCheck,
  Users,
  Wallet,
  X,
} from 'lucide-react';
import { navigateToLeaveApp, supabase, type Access } from '../supabase';
import type { DivisionIconName, DivisionWithModules } from './mapping';
import type { SchoolBasic } from './types';

/**
 * โครงหน้า Left Sidebar แยกชัดเจนเป็น 2 โซน:
 *   ① school (/school/*) — บุคลากรโรงเรียนและแอดมินโรงเรียน (ไล่ลงมาเป็นหมวดหมู่ฝ่าย + โมดูลย่อย + ตั้งค่า + ชื่อเข้าสู่ระบบ)
 *   ② admin  (/admin/*)  — ศูนย์ผู้ดูแลระบบส่วนกลางทุกโรงเรียน (เฉพาะ isSuper)
 * (ส่วน /public ไม่ใช้ Shell นี้ — ใช้ Top Navbar ของเว็บสาธารณะตามเดิม)
 */
export type ShellArea = 'school' | 'admin';

const matches = (pathname: string, prefix: string) =>
  pathname === prefix || pathname.startsWith(`${prefix}/`);

export function areaOfPath(pathname: string): ShellArea {
  if (matches(pathname, '/admin')) return 'admin';
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
  canManagePublicWeb?: boolean;
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
  end?: boolean;
}

const SCHOOL_SETTINGS_ITEMS: NavItem[] = [
  { to: '/school/settings/mapping', label: 'ฝ่ายและบุคลากร', icon: Layers },
  { to: '/school/settings/permissions', label: 'สิทธิ์การใช้งาน', icon: ShieldCheck },
  { to: '/school/settings/forms', label: 'แบบฟอร์มใบลาของโรงเรียน', icon: FileText },
  { to: '/school/settings/line', label: 'LINE แจ้งเตือน', icon: MessageCircle },
  { to: '/school/settings/attendance', label: 'เครื่องสแกนลงเวลา', icon: ScanFace },
  { to: '/school/settings/general', label: 'ปีการศึกษาและลิงก์', icon: CalendarDays },
];

const ADMIN_NAV: { label: string; items: NavItem[] }[] = [
  {
    label: 'ทุกโรงเรียน',
    items: [
      { to: '/admin', label: 'ภาพรวมทุกโรงเรียน', icon: LayoutDashboard, end: true },
      { to: '/admin/schools', label: 'ข้อมูลโรงเรียน & แพ็กเกจ', icon: Building2 },
      { to: '/admin/school-admins', label: 'ผู้ดูแลโรงเรียน', icon: ShieldCheck },
      { to: '/admin/packages', label: 'เพดานสิทธิ์รายโรงเรียน', icon: Package },
    ],
  },
  {
    label: 'ใช้ร่วมทุกโรงเรียน',
    items: [
      { to: '/admin/forms', label: 'แม่แบบฟอร์มกลาง', icon: FileText },
      { to: '/admin/line', label: 'LINE (สะพานเชื่อมกลาง)', icon: MessageCircle },
    ],
  },
];

const navClass = (isActive: boolean) =>
  `flex min-h-[34px] items-center gap-2.5 rounded-lg px-3 py-1.5 text-[13px] transition-colors ${
    isActive
      ? 'bg-brand-50 font-semibold text-brand-700'
      : 'text-slate-700 hover:bg-slate-50 hover:text-ink'
  }`;

const subNavClass = (isActive: boolean) =>
  `flex min-h-[32px] items-center gap-2 rounded-lg pl-7 pr-3 py-1.5 text-[13px] transition-colors ${
    isActive
      ? 'bg-brand-50 font-semibold text-brand-700'
      : 'text-slate-600 hover:bg-slate-50 hover:text-ink'
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
  canManagePublicWeb = false,
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
          (data as { id: number; title: string; published_at: string }[] | null) ??
            [],
        );
      });
  }, [selectedSchoolId]);

  const enabledDivisions = divisions.filter((d) => d.is_enabled);
  const hasPublicWebModuleInDivisions = enabledDivisions.some((d) =>
    d.modules.some(
      (m) => m.is_enabled && m.module_key === 'public-web-settings',
    ),
  );

  // ── โซน 1: Sidebar เว็บบุคลากรและแอดมินโรงเรียน (/school/*) ──
  const schoolNav = (
    <div className="space-y-4">
      {/* ลิงก์หลักด้านบน */}
      <div className="space-y-0.5">
        <NavLink to="/school" end className={({ isActive }) => navClass(isActive)}>
          <LayoutDashboard
            className="h-[17px] w-[17px] shrink-0 text-slate-500"
            strokeWidth={1.6}
          />
          <span className="truncate">หน้าหลักโรงเรียน</span>
        </NavLink>
        <Link
          to={selectedSchoolId ? `/public/${selectedSchoolId}` : '/public'}
          className={navClass(false)}
        >
          <Globe
            className="h-[17px] w-[17px] shrink-0 text-brand-600"
            strokeWidth={1.6}
          />
          <span className="truncate">เว็บโรงเรียน (สาธารณะ)</span>
        </Link>
        {canManagePublicWeb && !hasPublicWebModuleInDivisions && (
          <NavLink
            to="/school/public-web-settings"
            className={({ isActive }) => navClass(isActive)}
          >
            <Settings
              className="h-[17px] w-[17px] shrink-0 text-emerald-600"
              strokeWidth={1.6}
            />
            <span className="truncate">ตั้งค่าเว็บสาธารณะ</span>
          </NavLink>
        )}
      </div>

      {/* เส้นคั่น + หมวดหมู่แยกตามฝ่ายของตัวเองพร้อมโมดูลย่อยไล่ลงมา */}
      <div className="border-t border-line pt-3 space-y-4">
        {enabledDivisions.length === 0 ? (
          <p className="px-3 py-2 text-xs leading-relaxed text-slate-500">
            ยังไม่ได้รับสิทธิ์ฝ่าย — รอแอดมินโรงเรียนกำหนด
          </p>
        ) : (
          enabledDivisions.map((div) => {
            const DivIcon = getDivisionIcon(div.icon_name);
            const rawMods = div.modules.filter((m) => m.is_enabled);
            // รวม "ทะเบียนบุคลากร" + "โครงสร้างฝ่ายและกลุ่มสาระ" เป็นเมนูเดียวไม่ให้ซ้ำกันใน Sidebar
            const hasStaffAndDept =
              rawMods.some((m) => m.module_key === 'staff-registry') &&
              rawMods.some((m) => m.module_key === 'departments');
            const mods = hasStaffAndDept
              ? rawMods
                  .filter((m) => m.module_key !== 'departments')
                  .map((m) =>
                    m.module_key === 'staff-registry'
                      ? { ...m, title: 'ทะเบียนบุคลากรและกลุ่มสาระ' }
                      : m,
                  )
              : rawMods;
            const divBase = `/school/division/${div.division_key}`;
            const isDivExact = pathname === divBase;

            return (
              <div key={div.id} className="space-y-0.5">
                {/* หัวข้อฝ่าย */}
                <Link
                  to={divBase}
                  className="flex items-center gap-2 px-3 py-1 text-xs font-semibold text-slate-500 hover:text-brand-700 transition-colors"
                >
                  <DivIcon
                    className="h-3.5 w-3.5 shrink-0 text-brand-600"
                    strokeWidth={1.8}
                  />
                  <span className="truncate">{div.name}</span>
                </Link>

                {/* รายการโมดูลใต้ฝ่าย */}
                {mods.length === 0 ? (
                  <p className="pl-7 pr-3 py-1 text-[11px] text-slate-400">
                    ยังไม่มีโมดูลในฝ่ายนี้
                  </p>
                ) : (
                  <div className="space-y-0.5">
                    {mods.map((mod, idx) => {
                      const modPath = `${divBase}/${mod.module_key}`;
                      const isActive =
                        pathname === modPath || (isDivExact && idx === 0);

                      if (
                        mod.module_type === 'external' &&
                        mod.resolved_url &&
                        mod.open_mode === 'new_tab'
                      ) {
                        return (
                          <a
                            key={mod.id}
                            href={mod.resolved_url}
                            target="_blank"
                            rel="noreferrer"
                            className={`${subNavClass(false)} justify-between`}
                          >
                            <span className="flex min-w-0 items-center gap-1.5">
                              <span className="h-1 w-1 rounded-full bg-slate-300 shrink-0" />
                              <span className="truncate">{mod.title}</span>
                            </span>
                            <ExternalLink className="h-3 w-3 shrink-0 text-slate-400" />
                          </a>
                        );
                      }

                      return (
                        <NavLink
                          key={mod.id}
                          to={modPath}
                          className={subNavClass(isActive)}
                        >
                          <span
                            className={`h-1.5 w-1.5 rounded-full shrink-0 ${
                              isActive ? 'bg-brand-600' : 'bg-slate-300'
                            }`}
                          />
                          <span className="truncate">{mod.title}</span>
                        </NavLink>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* เส้นคั่น + หมวดตั้งค่า (เฉพาะแอดมินโรงเรียน / ผู้ดูแลส่วนกลาง) */}
      {canManageSchool && (
        <div className="border-t border-line pt-3 space-y-1">
          <p className="flex items-center gap-2 px-3 py-1 text-xs font-semibold text-slate-500">
            <Settings className="h-3.5 w-3.5 shrink-0 text-slate-500" strokeWidth={1.8} />
            <span>ตั้งค่าโรงเรียน</span>
          </p>
          <div className="space-y-0.5">
            {SCHOOL_SETTINGS_ITEMS.map((item) => {
              const Icon = item.icon;
              const isPermAlias =
                item.to === '/school/settings/permissions' &&
                matches(pathname, '/school/settings/user-permissions');
              return (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={({ isActive }) => navClass(isActive || isPermAlias)}
                >
                  <Icon
                    className="h-4 w-4 shrink-0 text-slate-400"
                    strokeWidth={1.6}
                  />
                  <span className="truncate">{item.label}</span>
                </NavLink>
              );
            })}
          </div>

          {isSuper && (
            <div className="pt-2">
              <Link
                to="/admin"
                className="flex items-center justify-between gap-2 rounded-lg border border-brand-200 bg-brand-50/70 px-3 py-2 text-xs font-semibold text-brand-700 hover:bg-brand-100/70 transition-colors"
              >
                <span className="flex items-center gap-2 truncate">
                  <Building2 className="h-4 w-4 shrink-0" strokeWidth={1.7} />
                  <span className="truncate">ศูนย์ผู้ดูแลส่วนกลาง</span>
                </span>
                <ChevronRight className="h-3.5 w-3.5 shrink-0" />
              </Link>
            </div>
          )}
        </div>
      )}
    </div>
  );

  // ── โซน 2: Sidebar ศูนย์ผู้ดูแลระบบส่วนกลาง (/admin/*) ──
  const adminNav = (
    <div className="space-y-5">
      {ADMIN_NAV.map((group) => (
        <div key={group.label} className="space-y-1">
          <p className="px-3 text-xs font-semibold text-slate-500">
            {group.label}
          </p>
          <div className="space-y-0.5">
            {group.items.map((item) => {
              const Icon = item.icon;
              return (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.end}
                  className={({ isActive }) => navClass(isActive)}
                >
                  <Icon
                    className="h-[17px] w-[17px] shrink-0 text-slate-500"
                    strokeWidth={1.6}
                  />
                  <span className="truncate">{item.label}</span>
                </NavLink>
              );
            })}
          </div>
        </div>
      ))}

      {/* ตัวเลือกสลับเข้าไปจัดการ/ดูเว็บโรงเรียน */}
      <div className="space-y-2 border-t border-line pt-4">
        <label className="flex flex-col gap-1 px-3 text-xs font-semibold text-slate-500">
          โรงเรียนที่จะเข้าจัดการ
          <select
            value={selectedSchoolId ?? ''}
            onChange={(e) => onSelectSchool(Number(e.target.value))}
            disabled={!canSwitchSchool}
            className="input py-1.5 text-xs font-medium text-ink"
          >
            {schools.map((s) => (
              <option key={s.id_school} value={s.id_school}>
                {s.fullName || `โรงเรียน #${s.id_school}`}
              </option>
            ))}
          </select>
        </label>
        <div className="space-y-0.5">
          <Link to="/school" className={navClass(false)}>
            <LayoutDashboard
              className="h-[17px] w-[17px] shrink-0 text-brand-600"
              strokeWidth={1.6}
            />
            <span className="truncate">เข้าเว็บโรงเรียนนี้</span>
          </Link>
          <Link to="/school/settings/mapping" className={navClass(false)}>
            <Settings
              className="h-[17px] w-[17px] shrink-0 text-slate-500"
              strokeWidth={1.6}
            />
            <span className="truncate">ตั้งค่าโรงเรียนนี้</span>
          </Link>
          <Link
            to={selectedSchoolId ? `/public/${selectedSchoolId}` : '/public'}
            className={navClass(false)}
          >
            <Globe
              className="h-[17px] w-[17px] shrink-0 text-emerald-600"
              strokeWidth={1.6}
            />
            <span className="truncate">ดูเว็บสาธารณะ (คนนอกดู)</span>
          </Link>
        </div>
      </div>
    </div>
  );

  const isSchoolSettingsPath = matches(pathname, '/school/settings');

  const renderSidebarContent = () => (
    <div className="flex h-full flex-col border-r border-line bg-white">
      {/* หัว Sidebar: ชื่อโรงเรียน หรือ ศูนย์ผู้ดูแลส่วนกลาง */}
      <div
        className={`flex h-16 items-center justify-between border-b px-4 ${
          area === 'admin'
            ? 'border-brand-700 bg-brand-700 text-white'
            : 'border-line bg-white'
        }`}
      >
        <div className="min-w-0">
          <p
            className={`truncate text-sm font-semibold ${
              area === 'admin' ? 'text-white' : 'text-ink'
            }`}
          >
            {area === 'admin' ? 'ศูนย์ผู้ดูแลส่วนกลาง' : schoolName}
          </p>
          <p
            className={`truncate text-xs ${
              area === 'admin' ? 'text-white/80' : 'text-slate-500'
            }`}
          >
            {area === 'admin' ? 'ผู้ดูแลระบบทุกโรงเรียน' : 'ระบบงานโรงเรียน'}
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

      {/* เมนูหลักเลื่อนขึ้นลงได้ */}
      <nav className="flex-1 overflow-y-auto px-3 py-3.5">
        {area === 'admin' ? adminNav : schoolNav}
      </nav>

      {/* ล่างสุด: ชื่อผู้เข้าสู่ระบบ + บทบาท + ปุ่มออกจากระบบ */}
      <div className="border-t border-line p-3">
        <div className="flex items-center justify-between gap-2 rounded-lg bg-slate-50/70 px-2.5 py-2">
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-ink">{userName}</p>
            <p className="truncate text-xs text-slate-500">{roleLabel}</p>
          </div>
          <button
            type="button"
            onClick={onSignOut}
            title="ออกจากระบบ"
            aria-label="ออกจากระบบ"
            className="rounded-lg p-1.5 text-slate-500 transition-colors hover:bg-white hover:text-ink"
          >
            <LogOut className="h-4 w-4" strokeWidth={1.6} />
          </button>
        </div>
      </div>
    </div>
  );

  // ป้ายบอกพื้นที่บนแถบหัวด้านบน
  const contextBadge =
    area === 'admin' ? (
      <span className="rounded-md border border-white/70 px-2 py-0.5 text-xs font-semibold text-white">
        ส่วนกลาง (ทุกโรงเรียน)
      </span>
    ) : isSchoolSettingsPath ? (
      <span className="truncate rounded-md bg-brand-50 px-2.5 py-1 text-xs font-semibold text-brand-700">
        {isSuper
          ? `ตั้งค่า: ${schoolName} · ในฐานะผู้ดูแลส่วนกลาง`
          : `ตั้งค่าโรงเรียน · ${schoolName}`}
      </span>
    ) : isSuper ? (
      <span className="truncate rounded-md bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-800">
        กำลังดู {schoolName} ในฐานะผู้ดูแลส่วนกลาง
      </span>
    ) : (
      <span className="hidden truncate text-sm font-semibold text-ink sm:inline">
        {schoolName}
      </span>
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
        <header
          className={`sticky top-0 z-20 flex h-16 items-center justify-between gap-3 border-b px-4 sm:px-6 ${
            area === 'admin'
              ? 'border-brand-700 bg-brand-700'
              : 'border-line bg-white'
          }`}
        >
          <div className="flex min-w-0 items-center gap-3">
            <button
              type="button"
              onClick={() => setSidebarOpen(true)}
              className={`rounded-lg p-2 lg:hidden ${
                area === 'admin'
                  ? 'text-white hover:bg-white/10'
                  : 'text-slate-600 hover:bg-slate-100'
              }`}
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
                  href={`${window.location.pathname}?embedded=0${
                    selectedSchoolId ? `&school_id=${selectedSchoolId}` : ''
                  }`}
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
                    notifOpen
                      ? 'bg-brand-50 text-brand-700'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                  aria-label="ประกาศล่าสุด"
                >
                  <Bell className="h-[18px] w-[18px]" strokeWidth={1.5} />
                  {recentNotices.length > 0 && (
                    <span className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-brand-600" />
                  )}
                </button>

                {notifOpen && (
                  <div className="absolute right-0 top-12 z-30 w-[calc(100vw-2rem)] max-w-80 rounded-xl border border-line bg-white p-3 shadow-lg">
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
                            <p className="text-sm font-medium text-ink">
                              {n.title}
                            </p>
                            <p className="mt-0.5 tabular-nums text-[11px] text-slate-400">
                              {new Date(n.published_at).toLocaleDateString(
                                'th-TH',
                                {
                                  day: 'numeric',
                                  month: 'short',
                                  year: 'numeric',
                                },
                              )}
                            </p>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                )}
              </>
            )}

            {area === 'admin' && (
              <Link
                to="/school"
                className="btn-sm rounded-lg border border-white/70 px-3 text-white hover:bg-white/10"
              >
                เข้าเว็บโรงเรียนนี้
              </Link>
            )}
          </div>
        </header>

        <main className="w-full min-w-0 flex-1 px-4 py-5 sm:px-6 sm:py-6">
          {children}
        </main>
      </div>
    </div>
  );
}
