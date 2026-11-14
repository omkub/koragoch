import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Check,
  Layers,
  LayoutGrid,
  Search,
  ShieldCheck,
  Sliders,
  Users,
} from 'lucide-react';
import MenuVisibilityPanel from '../pages/MenuVisibilityPanel';
import { rolesForSchool, supabase, type Role } from '../supabase';
import type { DivisionWithModules } from './mapping';
import {
  fetchRoleDivisionModulePermissions,
  saveUserSchoolWebTabOverride,
  type RoleDivisionModulePermissions,
  type UserTabOverride,
} from './roleModulePermissions';
import SchoolPackagePanel from './SchoolPackagePanel';
import {
  fetchSchoolStaffMembers,
  getStaffAssignedDivisionKeys,
  inferRoleTierFromRoleName,
  ROLE_TIER_META,
  updateStaffRoleId,
  type SchoolRoleTier,
  type SchoolStaffMember,
} from './staffDivisionMapping';
import type { SchoolBasic } from './types';

interface DivisionPermissionsPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
  isSuper?: boolean;
  divisions: DivisionWithModules[];
  hasDbMapping: boolean;
  onReload: () => Promise<void>;
}

type MainSectionTab = 'web_access' | 'tabs_access' | 'leave_ceiling';

export default function DivisionPermissionsPage({
  school,
  schoolId,
  canEdit,
  isSuper = false,
  divisions,
  onReload,
}: DivisionPermissionsPageProps) {
  const [activeSection, setActiveSection] =
    useState<MainSectionTab>('web_access');
  const [roles, setRoles] = useState<Role[]>([]);
  const [staffList, setStaffList] = useState<SchoolStaffMember[]>([]);
  const [tabVisibleByRole, setTabVisibleByRole] = useState<
    Record<number, boolean>
  >({});
  const [permState, setPermState] = useState<RoleDivisionModulePermissions>({
    divisionByRole: {},
    moduleByRole: {},
    userTabOverride: {},
    divisionByUser: {},
    moduleByUser: {},
  });
  const [loading, setLoading] = useState(true);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [staffSearch, setStaffSearch] = useState('');
  const [tierFilter, setTierFilter] = useState<'all' | SchoolRoleTier>('all');
  const [message, setMessage] = useState<{
    type: 'ok' | 'err';
    text: string;
  } | null>(null);

  const allDivisionKeys = useMemo(
    () => divisions.map((d) => d.division_key),
    [divisions],
  );
  const allModuleKeys = useMemo(() => {
    const set = new Set<string>();
    for (const d of divisions) {
      for (const m of d.modules) set.add(m.module_key);
    }
    return [...set];
  }, [divisions]);

  const divisionNameByKey = useMemo(() => {
    const map = new Map<string, string>();
    for (const d of divisions) map.set(d.division_key, d.name);
    return map;
  }, [divisions]);

  const loadData = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const [rolesRes, permRes, staff, roleDivModPerms] = await Promise.all([
      supabase
        .from('roles')
        .select('ID_Roles, Accessrights, id_school')
        .order('ID_Roles', { ascending: true }),
      supabase
        .from('Permissions')
        .select('id_role, menu_id, status')
        .eq('id_school', schoolId)
        .eq('menu_id', 6),
      fetchSchoolStaffMembers(schoolId),
      fetchRoleDivisionModulePermissions(
        schoolId,
        allDivisionKeys.length > 0
          ? allDivisionKeys
          : ['hr', 'academic', 'admin', 'finance'],
        allModuleKeys.length > 0 ? allModuleKeys : undefined,
      ),
    ]);

    const allRoles = (rolesRes.data as Role[] | null) ?? [];
    const schoolRoles = rolesForSchool(allRoles, schoolId);
    setRoles(schoolRoles);
    setStaffList(staff);

    const tabMap: Record<number, boolean> = {};
    for (const r of schoolRoles) {
      tabMap[r.ID_Roles] = true;
    }
    for (const row of (permRes.data as
      | { id_role: number; menu_id: number; status: unknown }[]
      | null) ?? []) {
      const st = row.status;
      tabMap[row.id_role] =
        st === true ||
        st === 1 ||
        String(st) === '1' ||
        String(st).toUpperCase() === 'TRUE';
    }
    setTabVisibleByRole(tabMap);
    setPermState(roleDivModPerms);
    setLoading(false);
  }, [schoolId, allDivisionKeys, allModuleKeys]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function toggleRoleSchoolWebAccess(roleId: number, nextVisible: boolean) {
    if (!schoolId || !canEdit) return;
    const key = `tab:${roleId}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await supabase.from('Permissions').upsert(
      {
        id_school: schoolId,
        id_role: roleId,
        menu_id: 6,
        status: nextVisible ? '1' : '0',
        updatedAt: new Date().toISOString(),
      },
      { onConflict: 'id_school,id_role,menu_id' },
    );

    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `บันทึกสิทธิ์เข้าถึง Web โรงเรียนไม่สำเร็จ: ${error.message}`,
      });
      return;
    }

    setTabVisibleByRole((prev) => ({
      ...prev,
      [roleId]: nextVisible,
    }));
    setMessage({
      type: 'ok',
      text: 'อัปเดตสิทธิ์การเข้าถึง Web โรงเรียนตามกลุ่มบทบาทเรียบร้อยแล้ว',
    });
  }

  async function handleChangeStaffRole(staff: SchoolStaffMember, nextRoleId: number) {
    if (!schoolId || !canEdit) return;
    const key = `role:${staff.id_user}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await updateStaffRoleId({
      schoolId,
      idUser: staff.id_user,
      roleId: nextRoleId,
    });

    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `เปลี่ยนระดับสิทธิ์ไม่สำเร็จ: ${error}`,
      });
      return;
    }

    const roleObj = roles.find((r) => r.ID_Roles === nextRoleId);
    const nextRoleName = roleObj?.Accessrights ?? 'ผู้ใช้งาน';
    setStaffList((prev) =>
      prev.map((s) =>
        s.id_user === staff.id_user
          ? { ...s, id_role: nextRoleId, roleName: nextRoleName }
          : s,
      ),
    );
    setMessage({
      type: 'ok',
      text: `เปลี่ยนบทบาทของ "${staff.fullName}" เป็น "${nextRoleName}" เรียบร้อยแล้ว`,
    });
  }

  async function handleChangeUserWebAccess(
    staff: SchoolStaffMember,
    override: UserTabOverride,
  ) {
    if (!schoolId || !canEdit) return;
    const key = `uweb:${staff.id_user}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await saveUserSchoolWebTabOverride({
      schoolId,
      idUser: staff.id_user,
      override,
    });

    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `บันทึกสิทธิ์เข้าถึง Web โรงเรียนรายบุคคลไม่สำเร็จ: ${error}`,
      });
      return;
    }

    setPermState((prev) => {
      const next = { ...prev.userTabOverride };
      if (override === 'inherit') {
        delete next[staff.id_user];
      } else {
        next[staff.id_user] = override === 'visible';
      }
      return {
        ...prev,
        userTabOverride: next,
      };
    });
    setMessage({
      type: 'ok',
      text: `อัปเดตสิทธิ์เข้าถึง Web โรงเรียนของ "${staff.fullName}" เรียบร้อยแล้ว`,
    });
    await onReload();
  }

  const filteredStaff = useMemo(() => {
    const q = staffSearch.trim().toLowerCase();
    return staffList.filter((s) => {
      const tier = inferRoleTierFromRoleName(s.roleName, s.is_super_admin);
      if (tierFilter !== 'all' && tier !== tierFilter) return false;
      if (!q) return true;
      return (
        s.fullName.toLowerCase().includes(q) ||
        s.username.toLowerCase().includes(q) ||
        s.roleName.toLowerCase().includes(q)
      );
    });
  }, [staffList, staffSearch, tierFilter]);

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">
            ศูนย์รวมการจัดการสิทธิ์ (รวมศูนย์ในจุดเดียว)
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            สิทธิ์เข้าถึง Web โรงเรียน, การใช้ Tab และระดับสิทธิ์ 4 ระดับ
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            กำหนดว่าใครสามารถเข้าใช้ Web โรงเรียนของ{' '}
            <span className="font-medium text-ink">
              {school?.fullName || 'โรงเรียน'}
            </span>{' '}
            ได้บ้าง เมื่อเข้าได้แล้วมีสิทธิ์ใช้ Tab ไหน และจัดการระดับสิทธิ์ (ผู้ใช้งาน / ผู้บริหาร / Admin / Super Admin)
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Link to="/admin/mapping" className="btn-primary btn-sm shrink-0">
            <Users className="h-3.5 w-3.5" strokeWidth={1.75} />
            <span>ไปหน้าจัดสังกัดบุคลากรเข้าฝ่าย</span>
          </Link>
        </div>
      </div>

      {/* แถบเลือกหมวดหมู่หลัก 3 ขั้นตอนในหน้าเดียว */}
      <div className="flex flex-wrap gap-2 border-b border-line pb-3">
        <button
          type="button"
          onClick={() => setActiveSection('web_access')}
          className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
            activeSection === 'web_access'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          <ShieldCheck className="h-4 w-4" strokeWidth={1.75} />
          <span>1. สิทธิ์เข้าถึง Web โรงเรียน & ระดับสิทธิ์ผู้ใช้งาน</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveSection('tabs_access')}
          className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
            activeSection === 'tabs_access'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          <LayoutGrid className="h-4 w-4" strokeWidth={1.75} />
          <span>2. สิทธิ์การใช้ Tab เมนูต่างๆ (เมื่อเข้าใช้ได้แล้ว)</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveSection('leave_ceiling')}
          className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
            activeSection === 'leave_ceiling'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          <Sliders className="h-4 w-4" strokeWidth={1.75} />
          <span>3. ตั้งค่าสิทธิ์ย่อยระบบวันลา (เพิ่มเติม)</span>
        </button>
      </div>

      {message && (
        <div
          className={`rounded-xl border px-4 py-3 text-xs font-medium ${
            message.type === 'ok'
              ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
              : 'border-rose-200 bg-rose-50 text-rose-700'
          }`}
        >
          {message.text}
        </div>
      )}

      {activeSection === 'web_access' && (
        <div className="space-y-6">
          {/* 1.1 สิทธิ์ระดับโรงเรียน: เปิด/ปิดเว็บโรงเรียน และเลือก Module ย่อยที่อนุญาตให้โรงเรียนนี้เห็น */}
          {isSuper && (
            <SchoolPackagePanel
              schoolId={schoolId}
              schoolName={school?.fullName || `โรงเรียน #${schoolId ?? '-'}`}
              canManage={isSuper}
              onUpdated={onReload}
            />
          )}

          {/* 1.2 สรุประดับสิทธิ์มาตรฐาน 4 ระดับ + ความเชื่อมโยงกับสังกัดฝ่าย */}
          <div className="surface-card p-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-base font-semibold text-ink">
                  โครงสร้างระดับสิทธิ์ 4 ระดับ และการมองเห็น Module ตามฝ่ายของตัวเอง
                </h2>
                <p className="mt-0.5 text-xs text-slate-500">
                  ไม่ต้องตั้งค่าสิทธิ์ราย Module ซ้ำซ้อน — บุคลากรอยู่ฝ่ายไหนจะมองเห็น Module ที่ผูกกับฝ่ายนั้นโดยอัตโนมัติ
                </p>
              </div>
              <Link
                to="/admin/mapping"
                className="btn-secondary btn-sm shrink-0"
              >
                <Layers className="h-3.5 w-3.5" strokeWidth={1.5} />
                <span>จัดการฝ่าย / ผูกบุคลากรเข้าฝ่าย</span>
              </Link>
            </div>

            <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {(
                ['user', 'executive', 'school_admin', 'super_admin'] as SchoolRoleTier[]
              ).map((tierKey) => {
                const meta = ROLE_TIER_META[tierKey];
                return (
                  <div
                    key={tierKey}
                    className="rounded-xl border border-line bg-canvas/50 p-3.5"
                  >
                    <span
                      className={`inline-block rounded-full px-2.5 py-0.5 text-xs font-semibold ${meta.badgeClass}`}
                    >
                      {meta.label}
                    </span>
                    <p className="mt-2 text-xs leading-relaxed text-slate-600">
                      {meta.description}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>

          {/* 1.3 สิทธิ์เข้าถึง Web โรงเรียนตามกลุ่มบทบาท */}
          <div className="surface-card p-6">
            <div className="mb-4">
              <h2 className="text-base font-semibold text-ink">
                ขั้นที่ 1: สิทธิ์เข้าถึง Web โรงเรียน ตามกลุ่มบทบาท (สามารถเข้าใช้ได้หรือไม่)
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                กำหนดว่ากลุ่มบทบาทใดในโรงเรียนสามารถเข้าใช้งาน &ldquo;Web โรงเรียน&rdquo; ได้บ้าง (เมื่อเปิดแล้ว จึงกำหนดสิทธิ์การใช้แต่ละ Tab ในหัวข้อที่ 2)
              </p>
            </div>

            {loading ? (
              <p className="py-4 text-sm text-slate-500">กำลังโหลดข้อมูล...</p>
            ) : (
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                {roles.map((role) => {
                  const isAdminRole = role.Accessrights.includes('ผู้ดูแลระบบ');
                  const isVisible = isAdminRole
                    ? true
                    : (tabVisibleByRole[role.ID_Roles] ?? true);
                  const isBusy = busyKey === `tab:${role.ID_Roles}`;
                  const tier = inferRoleTierFromRoleName(role.Accessrights, false);

                  return (
                    <div
                      key={role.ID_Roles}
                      className={`flex items-center justify-between gap-3 rounded-xl border p-3.5 transition-colors ${
                        isVisible
                          ? 'border-brand-200 bg-brand-50/40'
                          : 'border-line bg-canvas/50'
                      }`}
                    >
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5">
                          <p className="truncate text-sm font-semibold text-ink">
                            {role.Accessrights}
                          </p>
                          <span
                            className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${ROLE_TIER_META[tier].badgeClass}`}
                          >
                            {ROLE_TIER_META[tier].shortLabel}
                          </span>
                        </div>
                        <p className="mt-0.5 text-[11px] text-slate-500">
                          {isVisible
                            ? 'เข้าใช้ Web โรงเรียนได้'
                            : 'ไม่อนุญาตให้เข้า Web โรงเรียน'}
                        </p>
                      </div>

                      <button
                        type="button"
                        disabled={!canEdit || isAdminRole || isBusy}
                        onClick={() =>
                          toggleRoleSchoolWebAccess(role.ID_Roles, !isVisible)
                        }
                        className={`inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-md border transition-colors ${
                          isVisible
                            ? 'border-brand-600 bg-brand-600 text-white'
                            : 'border-slate-300 bg-white text-transparent hover:border-slate-400'
                        } disabled:opacity-50`}
                        aria-label={`เปิดหรือปิดสิทธิ์เข้าใช้เว็บโรงเรียนสำหรับ ${role.Accessrights}`}
                      >
                        <Check className="h-3.5 w-3.5" strokeWidth={2} />
                      </button>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* 1.4 ตารางกำหนดระดับสิทธิ์ & สิทธิ์เข้าใช้ Web โรงเรียนรายบุคลากร */}
          <div className="surface-card p-6">
            <div className="flex flex-col gap-3 border-b border-line pb-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-base font-semibold text-ink">
                  กำหนดระดับสิทธิ์และสิทธิ์เข้าถึง Web โรงเรียนรายบุคลากร ({staffList.length} คน)
                </h2>
                <p className="mt-0.5 text-xs text-slate-500">
                  ปรับระดับสิทธิ์ของบุคลากรแต่ละคน (ผู้ใช้งาน / ผู้บริหาร / Admin) และกำหนดสิทธิ์เข้าถึง Web โรงเรียนรายบุคคลได้ในตารางเดียว
                </p>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                <div className="relative min-w-[220px]">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    value={staffSearch}
                    onChange={(e) => setStaffSearch(e.target.value)}
                    placeholder="ค้นหาชื่อบุคลากร หรือชื่อผู้ใช้..."
                    className="input pl-9 py-1.5 text-xs"
                  />
                </div>

                <select
                  value={tierFilter}
                  onChange={(e) =>
                    setTierFilter(e.target.value as 'all' | SchoolRoleTier)
                  }
                  className="input w-auto py-1.5 text-xs"
                  aria-label="กรองตามระดับสิทธิ์"
                >
                  <option value="all">ทุกระดับสิทธิ์</option>
                  <option value="user">เฉพาะผู้ใช้งาน</option>
                  <option value="executive">เฉพาะผู้บริหาร</option>
                  <option value="school_admin">เฉพาะ Admin โรงเรียน</option>
                </select>
              </div>
            </div>

            {loading ? (
              <p className="py-8 text-center text-sm text-slate-500">
                กำลังโหลดรายชื่อบุคลากร...
              </p>
            ) : filteredStaff.length === 0 ? (
              <p className="py-8 text-center text-sm text-slate-500">
                ไม่พบบุคลากรตามเงื่อนไขที่ค้นหา
              </p>
            ) : (
              <div className="mt-4 divide-y divide-line rounded-xl border border-line">
                {filteredStaff.map((staff) => {
                  const tier = inferRoleTierFromRoleName(
                    staff.roleName,
                    staff.is_super_admin,
                  );
                  const tierMeta = ROLE_TIER_META[tier];
                  const assignedDivKeys = getStaffAssignedDivisionKeys(
                    permState,
                    staff.id_user,
                    allDivisionKeys,
                  );

                  const rawOverride = permState.userTabOverride[staff.id_user];
                  const currentOverride: UserTabOverride =
                    rawOverride === undefined
                      ? 'inherit'
                      : rawOverride
                        ? 'visible'
                        : 'hidden';

                  const roleDefaultAccess =
                    staff.id_role != null
                      ? (tabVisibleByRole[staff.id_role] ?? true)
                      : true;

                  return (
                    <div
                      key={staff.id_user}
                      className="flex flex-col gap-3 p-4 lg:flex-row lg:items-center lg:justify-between"
                    >
                      <div className="min-w-0 space-y-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-semibold text-ink">
                            {staff.fullName}
                          </span>
                          {staff.username && (
                            <span className="text-xs text-slate-400">
                              @{staff.username}
                            </span>
                          )}
                          <span
                            className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${tierMeta.badgeClass}`}
                          >
                            {tierMeta.shortLabel}
                          </span>
                        </div>

                        {/* แสดงสังกัดฝ่ายของบุคลากร */}
                        {tier === 'super_admin' || tier === 'school_admin' ? (
                          <p className="text-xs text-emerald-700">
                            เห็นและแก้ไขได้ทุกฝ่าย/ทุก Module ในโรงเรียน
                          </p>
                        ) : tier === 'executive' ? (
                          <p className="text-xs text-amber-700">
                            เห็นข้อมูลครบทุกฝ่ายของโรงเรียน (ระดับผู้บริหาร)
                          </p>
                        ) : assignedDivKeys.length > 0 ? (
                          <div className="flex flex-wrap items-center gap-1 pt-0.5">
                            <span className="text-[11px] text-slate-500">
                              สังกัดฝ่าย (เห็น Module ตามฝ่ายนี้):
                            </span>
                            {assignedDivKeys.map((dk) => (
                              <span
                                key={dk}
                                className="rounded-md bg-brand-50 px-2 py-0.5 text-[11px] font-medium text-brand-700 ring-1 ring-inset ring-brand-200"
                              >
                                {divisionNameByKey.get(dk) || dk}
                              </span>
                            ))}
                          </div>
                        ) : (
                          <p className="text-xs text-slate-400">
                            ยังไม่ได้ระบุสังกัดฝ่าย (ตั้งค่าได้ที่หน้าจัดการฝ่าย & บุคลากร)
                          </p>
                        )}
                      </div>

                      <div className="flex flex-wrap items-center gap-3">
                        {/* เปลี่ยนบทบาท / ระดับสิทธิ์ */}
                        <div className="flex items-center gap-1.5">
                          <span className="text-xs text-slate-500">ระดับสิทธิ์:</span>
                          <select
                            disabled={
                              !canEdit ||
                              staff.is_super_admin ||
                              busyKey === `role:${staff.id_user}`
                            }
                            value={staff.id_role ?? ''}
                            onChange={(e) =>
                              handleChangeStaffRole(
                                staff,
                                Number(e.target.value),
                              )
                            }
                            className="input w-auto py-1 text-xs font-medium"
                            aria-label={`ระดับสิทธิ์ของ ${staff.fullName}`}
                          >
                            {roles.map((r) => (
                              <option key={r.ID_Roles} value={r.ID_Roles}>
                                {r.Accessrights}
                              </option>
                            ))}
                          </select>
                        </div>

                        {/* สิทธิ์เข้าถึง Web โรงเรียนรายบุคคล */}
                        <div className="inline-flex items-center gap-1 rounded-lg border border-line bg-canvas p-0.5">
                          {(
                            [
                              {
                                value: 'inherit',
                                label: `ตามบทบาท (${roleDefaultAccess ? 'เข้าได้' : 'ปิด'})`,
                              },
                              { value: 'visible', label: 'เข้า Web รร. ได้' },
                              { value: 'hidden', label: 'ไม่อนุญาต' },
                            ] as const
                          ).map((opt) => {
                            const active = currentOverride === opt.value;
                            return (
                              <button
                                key={opt.value}
                                type="button"
                                disabled={
                                  !canEdit ||
                                  staff.is_super_admin ||
                                  busyKey === `uweb:${staff.id_user}`
                                }
                                onClick={() =>
                                  handleChangeUserWebAccess(staff, opt.value)
                                }
                                className={`rounded-md px-2.5 py-1 text-[11px] font-medium transition-colors ${
                                  active
                                    ? opt.value === 'hidden'
                                      ? 'bg-slate-700 text-white'
                                      : 'bg-brand-600 text-white'
                                    : 'text-slate-600 hover:text-ink'
                                } disabled:opacity-50`}
                              >
                                {opt.label}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {activeSection === 'tabs_access' && schoolId !== null && (
        <div className="space-y-4">
          <div className="surface-card p-6">
            <h2 className="text-base font-semibold text-ink">
              ขั้นที่ 2: เมื่อมีสิทธิ์เข้าใช้งานแล้ว → มีสิทธิ์ใช้ Tab เมนูไหนได้บ้าง
            </h2>
            <p className="mt-1 mb-4 text-xs text-slate-500">
              กำหนดว่าแต่ละกลุ่มสิทธิ์สามารถมองเห็นและกดใช้งาน Tab เมนูใดได้บ้าง ทั้งบนหน้าจอคอมพิวเตอร์ (PC) และบนมือถือ
            </p>
            <MenuVisibilityPanel roles={roles} schoolId={schoolId} />
          </div>
        </div>
      )}

      {activeSection === 'leave_ceiling' && (
        <div className="surface-card p-6 space-y-4">
          <h2 className="text-base font-semibold text-ink">
            ขั้นที่ 3: การตั้งค่าเพดานสิทธิ์ย่อยของระบบวันลา (เพิ่มเติม)
          </h2>
          <p className="text-xs text-slate-600">
            สำหรับการตั้งค่าปลีกย่อยภายในระบบวันลา (เช่น สิทธิ์การอนุมัติใบลาแต่ละขั้น หรือการเปิด/ปิดฟีเจอร์ย่อยของระบบวันลารายคน) สามารถจัดการได้จากหน้าตั้งค่าเชิงลึกด้านล่างนี้:
          </p>
          <div className="flex flex-wrap gap-3 pt-2">
            <Link to="/user-permissions" className="btn-secondary">
              เปิดหน้าตั้งค่าสิทธิ์ย่อยรายบุคคล (ระบบวันลา)
            </Link>
            {isSuper && (
              <Link to="/role-permissions" className="btn-secondary">
                เปิดหน้าเพดานสิทธิ์ระบบวันลาและจัดการรายชื่อบทบาท
              </Link>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
