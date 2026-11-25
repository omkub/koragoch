import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Check,
  Layers,
  LayoutGrid,
  Search,
  ShieldCheck,
  Sliders,
  UserCog,
  Users,
} from 'lucide-react';
import MenuVisibilityPanel from '../pages/MenuVisibilityPanel';
import RoleListPanel from '../pages/RoleListPanel';
import {
  ADMIN_ROLE_ID,
  groupItems,
  rolesForSchool,
  supabase,
  type PermissionItem,
  type Role,
} from '../supabase';
import { EmptyState, Notice } from '../ui/components';
import PermMatrix, { SaveBar } from '../ui/PermMatrix';
import type { DivisionWithModules } from './mapping';
import {
  fetchRoleDivisionModulePermissions,
  PUBLIC_WEB_SETTINGS_MODULE_KEY,
  resolveUserModuleOverrideLevel,
  saveRoleModuleAccessLevel,
  saveUserModuleOverride,
  saveUserSchoolWebTabOverride,
  type AccessLevel,
  type RoleDivisionModulePermissions,
  type UserOverrideLevel,
  type UserTabOverride,
} from './roleModulePermissions';
import SchoolPackagePanel from './SchoolPackagePanel';
import StaffMenuPreview from './StaffMenuPreview';
import {
  fetchSchoolPackageConfig,
  isModuleAllowedForSchool,
  SCHOOL_MODULE_META,
  type SchoolPackageConfig,
} from './schoolPackage';
import {
  fetchSchoolStaffMembers,
  getStaffAssignedDivisionKeys,
  inferRoleTierFromRoleName,
  resolveInheritedModuleLevel,
  ROLE_TIER_META,
  saveRoleTierForRole,
  updateStaffRoleId,
  type SchoolRoleTier,
  type SchoolStaffMember,
} from './staffDivisionMapping';
import type { SchoolBasic } from './types';

export type PermissionsSectionTab = 'roles' | 'individual' | 'package_ceiling';

interface DivisionPermissionsPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
  isSuper?: boolean;
  divisions: DivisionWithModules[];
  hasDbMapping: boolean;
  onReload: () => Promise<void>;
  initialSection?: PermissionsSectionTab;
}

type Flags = Record<string, boolean>; // item_key → เปิด/ปิด (รายบุคคล)
type CeilingGrid = Record<string, boolean>; // `${id_role}:${item_key}` → allowed

const cellKey = (role: number, item: string) => `${role}:${item}`;

const LEVEL_LABEL: Record<AccessLevel, string> = {
  hidden: 'ซ่อน',
  view: 'ดูอย่างเดียว',
  edit: 'แก้ไขได้',
};

const USER_LEVEL_OPTIONS: {
  value: UserOverrideLevel;
  label: string;
  activeClass: string;
}[] = [
  {
    value: 'inherit',
    label: 'ตามบทบาท',
    activeClass: 'border-brand-600 bg-brand-600 text-white',
  },
  {
    value: 'hidden',
    label: 'ซ่อน',
    activeClass: 'border-slate-700 bg-slate-700 text-white',
  },
  {
    value: 'view',
    label: 'ดูอย่างเดียว',
    activeClass: 'border-sky-600 bg-sky-600 text-white',
  },
  {
    value: 'edit',
    label: 'แก้ไขได้',
    activeClass: 'border-emerald-600 bg-emerald-600 text-white',
  },
];

export default function DivisionPermissionsPage({
  school,
  schoolId,
  canEdit,
  isSuper = false,
  divisions,
  onReload,
  initialSection = 'roles',
}: DivisionPermissionsPageProps) {
  const [activeSection, setActiveSection] = useState<PermissionsSectionTab>(
    initialSection === 'package_ceiling' && !isSuper ? 'roles' : initialSection,
  );

  useEffect(() => {
    setActiveSection(
      initialSection === 'package_ceiling' && !isSuper ? 'roles' : initialSection,
    );
  }, [initialSection, isSuper]);

  const [roles, setRoles] = useState<Role[]>([]);
  const [staffList, setStaffList] = useState<SchoolStaffMember[]>([]);
  const [items, setItems] = useState<PermissionItem[]>([]);
  const [schoolPackage, setSchoolPackage] =
    useState<SchoolPackageConfig | null>(null);
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

  // เพดานสิทธิ์ตามบทบาท (RolePermissions)
  const [savedCeiling, setSavedCeiling] = useState<CeilingGrid>({});
  const [ceilingGrid, setCeilingGrid] = useState<CeilingGrid>({});
  const [savingCeiling, setSavingCeiling] = useState(false);

  // สิทธิ์รายบุคคล (UserPermissions + สิทธิ์ระบบงานในเว็บโรงเรียน)
  const [selectedStaff, setSelectedStaff] = useState<SchoolStaffMember | null>(
    null,
  );
  const [savedUserFlags, setSavedUserFlags] = useState<Flags>({});
  const [userFlags, setUserFlags] = useState<Flags>({});
  const [savingUserFlags, setSavingUserFlags] = useState(false);
  const detailRef = useRef<HTMLDivElement>(null);

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
    const set = new Set<string>([PUBLIC_WEB_SETTINGS_MODULE_KEY]);
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
    const [
      rolesRes,
      permRes,
      staff,
      roleDivModPerms,
      itemsRes,
      ceilingRes,
      pkgConfig,
    ] = await Promise.all([
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
      supabase
        .from('PermissionItems')
        .select('key, group, label, sort')
        .order('sort', { ascending: true }),
      supabase
        .from('RolePermissions')
        .select('id_role, item_key, allowed')
        .eq('id_school', schoolId),
      fetchSchoolPackageConfig(schoolId),
    ]);

    const allRoles = (rolesRes.data as Role[] | null) ?? [];
    const schoolRoles = rolesForSchool(allRoles, schoolId);
    setRoles(schoolRoles);
    setStaffList(staff);
    setItems((itemsRes.data as PermissionItem[] | null) ?? []);
    setSchoolPackage(pkgConfig);

    const nextCeiling: CeilingGrid = {};
    for (const row of (ceilingRes.data as
      | { id_role: number; item_key: string; allowed: boolean }[]
      | null) ?? []) {
      nextCeiling[cellKey(row.id_role, row.item_key)] = row.allowed;
    }
    setSavedCeiling(nextCeiling);
    setCeilingGrid(nextCeiling);

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
    setSelectedStaff(null);
    loadData();
  }, [loadData]);

  const inCeiling = useCallback(
    (staff: SchoolStaffMember, itemKey: string) =>
      staff.id_role != null &&
      ceilingGrid[cellKey(staff.id_role, itemKey)] === true,
    [ceilingGrid],
  );

  const openStaffPermissions = useCallback(
    async (staff: SchoolStaffMember) => {
      setMessage(null);
      setSelectedStaff(staff);
      const { data, error } = await supabase
        .from('UserPermissions')
        .select('item_key, allowed')
        .eq('id_user', staff.id_user);
      if (error) {
        setMessage({ type: 'err', text: error.message });
        return;
      }
      const overrides: Flags = {};
      for (const row of (data as { item_key: string; allowed: boolean }[] | null) ?? []) {
        overrides[row.item_key] = row.allowed;
      }
      const effective: Flags = {};
      for (const item of items) {
        effective[item.key] =
          inCeiling(staff, item.key) && (overrides[item.key] ?? true);
      }
      setSavedUserFlags(effective);
      setUserFlags(effective);
    },
    [items, inCeiling],
  );

  function pickStaff(staff: SchoolStaffMember) {
    openStaffPermissions(staff);
    if (window.matchMedia('(max-width: 1023px)').matches) {
      setTimeout(
        () =>
          detailRef.current?.scrollIntoView({
            behavior: 'smooth',
            block: 'start',
          }),
        50,
      );
    }
  }

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
        text: `บันทึกสิทธิ์เข้าใช้เว็บโรงเรียนไม่สำเร็จ: ${error.message}`,
      });
      return;
    }

    setTabVisibleByRole((prev) => ({
      ...prev,
      [roleId]: nextVisible,
    }));
    setMessage({
      type: 'ok',
      text: 'อัปเดตสิทธิ์การเข้าใช้เว็บโรงเรียนตามบทบาทเรียบร้อยแล้ว',
    });
  }

  async function handleChangeRoleTier(
    role: Role,
    nextTier: 'user' | 'executive' | 'school_admin',
  ) {
    if (!schoolId || !canEdit || (role.ID_Roles === ADMIN_ROLE_ID && !isSuper))
      return;
    const key = `roletier:${role.ID_Roles}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await saveRoleTierForRole({
      schoolId,
      roleId: role.ID_Roles,
      tier: nextTier,
    });

    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `บันทึกระดับสิทธิ์ของบทบาทไม่สำเร็จ: ${error}`,
      });
      return;
    }

    setPermState((prev) => ({
      ...prev,
      roleTierByRole: {
        ...(prev.roleTierByRole ?? {}),
        [role.ID_Roles]: nextTier,
      },
    }));
    setMessage({
      type: 'ok',
      text: `ตั้งค่าระดับสิทธิ์ของบทบาท "${role.Accessrights}" เป็น "${ROLE_TIER_META[nextTier].shortLabel}" เรียบร้อยแล้ว`,
    });
    await onReload();
  }

  async function handleToggleRolePublicWebSettings(
    role: Role,
    canManagePublicWeb: boolean,
  ) {
    if (!schoolId || !canEdit || (role.ID_Roles === ADMIN_ROLE_ID && !isSuper))
      return;
    const key = `pubweb:${role.ID_Roles}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await saveRoleModuleAccessLevel({
      schoolId,
      roleId: role.ID_Roles,
      moduleKey: PUBLIC_WEB_SETTINGS_MODULE_KEY,
      level: canManagePublicWeb ? 'edit' : 'hidden',
    });

    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `บันทึกสิทธิ์ตั้งค่าเว็บสาธารณะของบทบาทไม่สำเร็จ: ${error}`,
      });
      return;
    }

    setPermState((prev) => ({
      ...prev,
      moduleByRole: {
        ...prev.moduleByRole,
        [`${role.ID_Roles}:${PUBLIC_WEB_SETTINGS_MODULE_KEY}`]: {
          can_view: canManagePublicWeb,
          can_edit: canManagePublicWeb,
        },
      },
    }));
    setMessage({
      type: 'ok',
      text: `${canManagePublicWeb ? 'เปิด' : 'ปิด'}สิทธิ์ตั้งค่าเว็บสาธารณะสำหรับบทบาท "${role.Accessrights}" เรียบร้อยแล้ว`,
    });
    await onReload();
  }

  async function handleChangeStaffRole(
    staff: SchoolStaffMember,
    nextRoleId: number,
  ) {
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
        text: `เปลี่ยนบทบาทไม่สำเร็จ: ${error}`,
      });
      return;
    }

    const roleObj = roles.find((r) => r.ID_Roles === nextRoleId);
    const nextRoleName = roleObj?.Accessrights ?? 'ผู้ใช้งาน';
    const updatedStaff = {
      ...staff,
      id_role: nextRoleId,
      roleName: nextRoleName,
    };
    setStaffList((prev) =>
      prev.map((s) => (s.id_user === staff.id_user ? updatedStaff : s)),
    );
    if (selectedStaff?.id_user === staff.id_user) {
      openStaffPermissions(updatedStaff);
    }
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
        text: `บันทึกสิทธิ์เข้าใช้เว็บโรงเรียนรายบุคคลไม่สำเร็จ: ${error}`,
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
      text: `อัปเดตสิทธิ์เข้าใช้เว็บโรงเรียนของ "${staff.fullName}" เรียบร้อยแล้ว`,
    });
    await onReload();
  }

  async function handleSaveUserSystemLevel(
    staff: SchoolStaffMember,
    systemKey: string,
    systemTitle: string,
    level: UserOverrideLevel,
  ) {
    if (!schoolId || !canEdit) return;
    setBusyKey(`mod:${systemKey}`);
    setMessage(null);

    const { error } = await saveUserModuleOverride({
      schoolId,
      idUser: staff.id_user,
      moduleKey: systemKey,
      level,
    });

    if (error) {
      setBusyKey(null);
      setMessage({ type: 'err', text: `บันทึกไม่สำเร็จ: ${error}` });
      return;
    }

    const updated = await fetchRoleDivisionModulePermissions(
      schoolId,
      allDivisionKeys.length > 0
        ? allDivisionKeys
        : ['hr', 'academic', 'admin', 'finance'],
      allModuleKeys.length > 0 ? allModuleKeys : undefined,
    );
    setPermState(updated);
    setBusyKey(null);
    setMessage({
      type: 'ok',
      text: `อัปเดตสิทธิ์ระบบงาน "${systemTitle}" ของ ${staff.fullName} เรียบร้อยแล้ว`,
    });
    await onReload();
  }

  const changedUserFlagKeys = useMemo(
    () =>
      items
        .filter((i) => userFlags[i.key] !== savedUserFlags[i.key])
        .map((i) => i.key),
    [userFlags, savedUserFlags, items],
  );

  async function saveSelectedUserLeaveFlags() {
    if (!selectedStaff || changedUserFlagKeys.length === 0) return;
    setSavingUserFlags(true);
    const toDisable = changedUserFlagKeys.filter((k) => !userFlags[k]);
    const toEnable = changedUserFlagKeys.filter((k) => userFlags[k]);
    const results = await Promise.all([
      toDisable.length
        ? supabase.from('UserPermissions').upsert(
            toDisable.map((k) => ({
              id_user: selectedStaff.id_user,
              item_key: k,
              allowed: false,
            })),
          )
        : Promise.resolve({ error: null }),
      toEnable.length
        ? supabase
            .from('UserPermissions')
            .delete()
            .eq('id_user', selectedStaff.id_user)
            .in('item_key', toEnable)
        : Promise.resolve({ error: null }),
    ]);
    setSavingUserFlags(false);
    const failed = results.find((r) => r.error)?.error;
    if (failed) {
      setMessage({ type: 'err', text: `บันทึกไม่สำเร็จ: ${failed.message}` });
      return;
    }
    setMessage({
      type: 'ok',
      text: `บันทึกสิทธิ์ระบบวันลาของ "${selectedStaff.fullName}" เรียบร้อยแล้ว`,
    });
    openStaffPermissions(selectedStaff);
  }

  // เพดานสิทธิ์ตามบทบาท (เฉพาะผู้ดูแลส่วนกลาง)
  const changedCeilingKeys = useMemo(
    () =>
      Object.keys(ceilingGrid).filter(
        (k) => ceilingGrid[k] !== (savedCeiling[k] ?? false),
      ),
    [ceilingGrid, savedCeiling],
  );

  async function saveCeilingGrid() {
    if (!schoolId || changedCeilingKeys.length === 0) return;
    setSavingCeiling(true);
    const rows = changedCeilingKeys.map((k) => {
      const [role, ...rest] = k.split(':');
      return {
        id_school: schoolId,
        id_role: Number(role),
        item_key: rest.join(':'),
        allowed: ceilingGrid[k],
        updatedAt: new Date().toISOString(),
      };
    });
    const { error } = await supabase.from('RolePermissions').upsert(rows);
    setSavingCeiling(false);
    if (error) {
      setMessage({
        type: 'err',
        text: `บันทึกเพดานสิทธิ์ไม่สำเร็จ: ${error.message}`,
      });
      return;
    }
    setSavedCeiling(ceilingGrid);
    setMessage({
      type: 'ok',
      text: `บันทึกเพดานสิทธิ์แล้ว ${rows.length} รายการ`,
    });
  }

  const toggleCeilingCell = (roleId: number, itemKey: string) => {
    const k = cellKey(roleId, itemKey);
    setCeilingGrid((prev) => ({
      ...prev,
      [k]: !(prev[k] ?? false),
    }));
  };

  const countCeilingForRole = (roleId: number) =>
    items.filter((i) => ceilingGrid[cellKey(roleId, i.key)]).length;

  const filteredStaff = useMemo(() => {
    const q = staffSearch.trim().toLowerCase();
    return staffList.filter((s) => {
      const tier = inferRoleTierFromRoleName(
        s.roleName,
        s.is_super_admin,
        s.id_role,
        permState,
      );
      if (tierFilter !== 'all' && tier !== tierFilter) return false;
      if (!q) return true;
      return (
        s.fullName.toLowerCase().includes(q) ||
        s.username.toLowerCase().includes(q) ||
        s.roleName.toLowerCase().includes(q)
      );
    });
  }, [staffList, staffSearch, tierFilter, permState]);

  const allowedSchoolSystems = useMemo(
    () =>
      SCHOOL_MODULE_META.filter((m) =>
        isModuleAllowedForSchool(schoolPackage, m.key),
      ),
    [schoolPackage],
  );

  const selectedStaffWebOverride: UserTabOverride = useMemo(() => {
    if (!selectedStaff) return 'inherit';
    if (selectedStaff.id_user in permState.userTabOverride) {
      return permState.userTabOverride[selectedStaff.id_user]
        ? 'visible'
        : 'hidden';
    }
    return 'inherit';
  }, [selectedStaff, permState]);

  const ceilingCountForStaff = (staff: SchoolStaffMember) =>
    items.filter((i) => inCeiling(staff, i.key)).length;

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">
            ตั้งค่าโรงเรียน · จัดการสิทธิ์การใช้งานทั้งหมดในหน้าเดียว
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            สิทธิ์การใช้งาน ({school?.fullName || 'โรงเรียน'})
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            กำหนดสิทธิ์ตามบทบาท เมนูที่แสดงในแอป และปรับสิทธิ์รายบุคคลได้ครบในหน้าเดียว
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Link to="/school/settings/mapping" className="btn-secondary btn-sm shrink-0">
            <Users className="h-3.5 w-3.5" strokeWidth={1.75} />
            <span>ไปหน้าฝ่ายและบุคลากร</span>
          </Link>
        </div>
      </div>

      {/* แถบเลือกหมวดในหน้าเดียว */}
      <div className="flex flex-wrap gap-2 border-b border-line pb-3">
        <button
          type="button"
          onClick={() => setActiveSection('roles')}
          className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
            activeSection === 'roles'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          <ShieldCheck className="h-4 w-4" strokeWidth={1.75} />
          <span>1. สิทธิ์ตามบทบาทและเมนูที่แสดง</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveSection('individual')}
          className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
            activeSection === 'individual'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          <UserCog className="h-4 w-4" strokeWidth={1.75} />
          <span>2. สิทธิ์รายบุคคล ({staffList.length} คน)</span>
        </button>

        {isSuper && (
          <button
            type="button"
            onClick={() => setActiveSection('package_ceiling')}
            className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
              activeSection === 'package_ceiling'
                ? 'bg-brand-600 text-white shadow-sm'
                : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
            }`}
          >
            <Sliders className="h-4 w-4" strokeWidth={1.75} />
            <span>3. ขอบเขตโรงเรียนและเพดานสิทธิ์ (ส่วนกลาง)</span>
          </button>
        )}
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

      {/* ─── หมวดที่ 1: สิทธิ์ตามบทบาทและเมนูที่แสดง ───────────────────────── */}
      {activeSection === 'roles' && (
        <div className="space-y-6">
          {/* 1.1 สรุประดับสิทธิ์ 4 ระดับ + ความเชื่อมโยงกับสังกัดฝ่าย */}
          <div className="surface-card p-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-base font-semibold text-ink">
                  ระดับสิทธิ์หลัก 4 ระดับ และการเห็นระบบงานตามฝ่ายที่สังกัด
                </h2>
                <p className="mt-0.5 text-xs text-slate-500">
                  บุคลากรอยู่ฝ่ายไหนจะมองเห็นระบบงานของฝ่ายนั้นโดยอัตโนมัติ (จัดสังกัดฝ่ายได้ที่หน้า &ldquo;ฝ่ายและบุคลากร&rdquo;)
                </p>
              </div>
              <Link
                to="/school/settings/mapping"
                className="btn-secondary btn-sm shrink-0"
              >
                <Layers className="h-3.5 w-3.5" strokeWidth={1.5} />
                <span>จัดบุคลากรเข้าฝ่าย</span>
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

          {/* 1.2 การเข้าใช้เว็บโรงเรียนตามบทบาท */}
          <div className="surface-card p-6">
            <div className="mb-4">
              <h2 className="text-base font-semibold text-ink">
                การเข้าใช้งานเว็บโรงเรียนตามบทบาท
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                เลือกว่าบทบาทใดในโรงเรียนสามารถเข้าใช้งาน &ldquo;เว็บโรงเรียน&rdquo; ได้บ้าง
              </p>
            </div>

            {loading ? (
              <p className="py-4 text-sm text-slate-500">กำลังโหลดข้อมูล...</p>
            ) : (
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {roles.map((role) => {
                  const isAdminRole =
                    role.ID_Roles === ADMIN_ROLE_ID ||
                    role.Accessrights.includes('ผู้ดูแลระบบ');
                  const isVisible = tabVisibleByRole[role.ID_Roles] ?? true;
                  const isBusy = busyKey === `tab:${role.ID_Roles}`;
                  const tier = inferRoleTierFromRoleName(
                    role.Accessrights,
                    false,
                    role.ID_Roles,
                    permState,
                  );

                  return (
                    <div
                      key={role.ID_Roles}
                      className={`flex flex-col justify-between gap-3 rounded-xl border p-3.5 transition-colors ${
                        isVisible
                          ? 'border-brand-200 bg-brand-50/40'
                          : 'border-line bg-canvas/50'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <div className="flex flex-wrap items-center gap-1.5">
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
                              ? 'เข้าใช้เว็บโรงเรียนได้'
                              : 'ไม่อนุญาตให้เข้าเว็บโรงเรียน'}
                          </p>
                        </div>

                        <button
                          type="button"
                          disabled={!canEdit || (isAdminRole && !isSuper) || isBusy}
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

                      <div className="flex items-center justify-between gap-2 border-t border-line/70 pt-2.5">
                        <span className="text-[11px] text-slate-500">
                          ขอบเขตการมองเห็นฝ่าย:
                        </span>
                        <select
                          disabled={
                            !canEdit ||
                            (role.ID_Roles === ADMIN_ROLE_ID && !isSuper) ||
                            busyKey === `roletier:${role.ID_Roles}`
                          }
                          value={tier === 'super_admin' ? 'school_admin' : tier}
                          onChange={(e) =>
                            handleChangeRoleTier(
                              role,
                              e.target.value as
                                | 'user'
                                | 'executive'
                                | 'school_admin',
                            )
                          }
                          aria-label={`ขอบเขตการมองเห็นฝ่ายของ ${role.Accessrights}`}
                          className="input w-auto py-1 text-[11px] font-medium"
                        >
                          <option value="user">
                            ผู้ใช้งาน (เห็นเฉพาะฝ่ายตัวเอง)
                          </option>
                          <option value="executive">
                            ผู้บริหาร (เห็นครบทุกฝ่าย)
                          </option>
                          <option value="school_admin">
                            แอดมินโรงเรียน (จัดการได้ทุกฝ่าย)
                          </option>
                        </select>
                      </div>

                      <div className="flex items-center justify-between gap-2 border-t border-line/70 pt-2">
                        <span className="text-[11px] text-slate-500">
                          ตั้งค่าเว็บสาธารณะของโรงเรียน:
                        </span>
                        {(() => {
                          const explicitRolePublicWeb =
                            permState.moduleByRole[
                              `${role.ID_Roles}:${PUBLIC_WEB_SETTINGS_MODULE_KEY}`
                            ];
                          const rolePublicWeb =
                            explicitRolePublicWeb !== undefined
                              ? Boolean(explicitRolePublicWeb.can_edit)
                              : tier === 'school_admin' || tier === 'super_admin';
                          const isLockedByAdminTier =
                            !isSuper &&
                            (tier === 'school_admin' ||
                              tier === 'super_admin' ||
                              isAdminRole);
                          return (
                            <button
                              type="button"
                              disabled={
                                !canEdit ||
                                isLockedByAdminTier ||
                                busyKey === `pubweb:${role.ID_Roles}`
                              }
                              onClick={() =>
                                handleToggleRolePublicWebSettings(
                                  role,
                                  !rolePublicWeb,
                                )
                              }
                              className={`inline-flex items-center gap-1 rounded-lg border px-2.5 py-1 text-[11px] font-medium transition-colors ${
                                rolePublicWeb
                                  ? 'border-emerald-600 bg-emerald-50 text-emerald-700'
                                  : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
                              } disabled:opacity-60`}
                            >
                              {rolePublicWeb ? 'ตั้งค่าได้' : 'ไม่ได้'}
                            </button>
                          );
                        })()}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* 1.3 เมนูที่แสดงในแอประบบวันลา (จอคอม / มือถือ) */}
          {schoolId !== null && (
            <div className="surface-card p-6">
              <div className="mb-4 flex items-center gap-2">
                <LayoutGrid className="h-4 w-4 text-brand-600" />
                <div>
                  <h2 className="text-base font-semibold text-ink">
                    เมนูที่แสดงในแอประบบวันลา (จอคอม / มือถือ)
                  </h2>
                  <p className="mt-0.5 text-xs text-slate-500">
                    เลือกว่าแต่ละบทบาทจะมองเห็นเมนูใดบ้างเมื่อเปิดใช้งานแอประบบวันลาบนจอคอมและบนมือถือ
                  </p>
                </div>
              </div>
              <MenuVisibilityPanel roles={roles} schoolId={schoolId} />
            </div>
          )}
        </div>
      )}

      {/* ─── หมวดที่ 2: สิทธิ์รายบุคคล (รวมเว็บโรงเรียน + ระบบวันลา) ─────────── */}
      {activeSection === 'individual' && (
        <div className="grid items-start gap-6 lg:grid-cols-[340px_minmax(0,1fr)]">
          {/* คอลัมน์ซ้าย: ค้นหาและเลือกบุคลากร */}
          <div className="surface-card overflow-hidden">
            <div className="border-b border-line bg-slate-50/60 p-4">
              <h2 className="text-sm font-semibold text-ink">
                1. เลือกบุคลากร ({filteredStaff.length} คน)
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                คลิกเลือกชื่อบุคลากรเพื่อปรับบทบาทหรือกำหนดสิทธิ์เฉพาะบุคคล
              </p>

              <div className="mt-3 space-y-2">
                <div className="relative">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    value={staffSearch}
                    onChange={(e) => setStaffSearch(e.target.value)}
                    placeholder="ค้นหาชื่อ หรือชื่อผู้ใช้..."
                    className="input py-1.5 pl-9 text-xs"
                  />
                </div>

                <select
                  value={tierFilter}
                  onChange={(e) =>
                    setTierFilter(e.target.value as 'all' | SchoolRoleTier)
                  }
                  className="input py-1.5 text-xs"
                  aria-label="กรองตามระดับสิทธิ์"
                >
                  <option value="all">ทุกระดับสิทธิ์</option>
                  <option value="user">เฉพาะผู้ใช้งาน</option>
                  <option value="executive">เฉพาะผู้บริหาร</option>
                  <option value="school_admin">เฉพาะแอดมินโรงเรียน</option>
                </select>
              </div>
            </div>

            <div className="max-h-[340px] divide-y divide-line overflow-y-auto lg:max-h-[70vh]">
              {loading ? (
                <p className="p-6 text-center text-xs text-slate-500">
                  กำลังโหลดรายชื่อบุคลากร...
                </p>
              ) : filteredStaff.length === 0 ? (
                <p className="p-6 text-center text-xs text-slate-500">
                  ไม่พบบุคลากรตามเงื่อนไขที่ค้นหา
                </p>
              ) : (
                filteredStaff.map((staff) => {
                  const active = selectedStaff?.id_user === staff.id_user;
                  const tier = inferRoleTierFromRoleName(
                    staff.roleName,
                    staff.is_super_admin,
                    staff.id_role,
                    permState,
                  );
                  const tierMeta = ROLE_TIER_META[tier];
                  const assignedDivKeys = getStaffAssignedDivisionKeys(
                    permState,
                    staff.id_user,
                    allDivisionKeys,
                  );
                  const hasCustomSystem = Object.keys(
                    permState.moduleByUser,
                  ).some((k) => k.startsWith(`${staff.id_user}:`));

                  return (
                    <button
                      key={staff.id_user}
                      type="button"
                      onClick={() => pickStaff(staff)}
                      className={`flex w-full flex-col items-start gap-1 px-4 py-3 text-left transition-colors ${
                        active
                          ? 'bg-brand-50/70 text-brand-700'
                          : 'bg-white hover:bg-slate-50'
                      }`}
                    >
                      <div className="flex w-full items-center justify-between gap-2">
                        <span className="truncate text-sm font-semibold text-ink">
                          {staff.fullName}
                        </span>
                        <span
                          className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-semibold ${tierMeta.badgeClass}`}
                        >
                          {tierMeta.shortLabel}
                        </span>
                      </div>

                      <div className="flex flex-wrap items-center gap-1.5 text-[11px] text-slate-500">
                        <span>{staff.roleName}</span>
                        {assignedDivKeys.length > 0 && (
                          <span>
                            ·{' '}
                            {assignedDivKeys
                              .map((dk) => divisionNameByKey.get(dk) || dk)
                              .join(', ')}
                          </span>
                        )}
                        {hasCustomSystem && (
                          <span className="rounded bg-emerald-100 px-1.5 py-0.5 text-[10px] font-semibold text-emerald-700">
                            ตั้งค่าเฉพาะคน
                          </span>
                        )}
                      </div>
                    </button>
                  );
                })
              )}
            </div>
          </div>

          {/* คอลัมน์ขวา: รายละเอียดสิทธิ์ของบุคลากรที่เลือก */}
          <div ref={detailRef} className="scroll-mt-20 space-y-6">
            {!selectedStaff ? (
              <div className="surface-card p-10 text-center">
                <p className="text-sm font-medium text-ink">
                  เลือกรายชื่อบุคลากรทางด้านซ้าย
                </p>
                <p className="mt-1 text-xs text-slate-500">
                  เพื่อปรับบทบาทหลัก การเข้าใช้เว็บโรงเรียน สิทธิ์แต่ละระบบงาน และสิทธิ์ในระบบวันลา
                </p>
              </div>
            ) : selectedStaff.is_super_admin ? (
              <div className="surface-card p-8 text-center">
                <EmptyState>
                  ผู้ดูแลส่วนกลางได้รับสิทธิ์ทุกรายการโดยอัตโนมัติ (ไม่สามารถปิดรายรายการได้)
                </EmptyState>
              </div>
            ) : (
              <>
                <StaffMenuPreview
                  staff={selectedStaff}
                  divisions={divisions}
                  perms={permState}
                />

                {/* กล่องที่ 1: บทบาทหลัก, สังกัดฝ่าย และการเข้าใช้เว็บโรงเรียน */}
                <div className="surface-card p-6 space-y-5">
                  <div className="flex flex-col gap-3 border-b border-line pb-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <h2 className="text-base font-semibold text-ink">
                        2.1 บทบาทและการเข้าใช้เว็บโรงเรียนของ: {selectedStaff.fullName}
                      </h2>
                      <p className="mt-0.5 text-xs text-slate-500">
                        ชื่อผู้ใช้: @{selectedStaff.username || '-'}
                      </p>
                    </div>

                    {/* เปลี่ยนบทบาทหลัก */}
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-medium text-slate-600">
                        บทบาทหลัก:
                      </span>
                      <select
                        disabled={
                          !canEdit || busyKey === `role:${selectedStaff.id_user}`
                        }
                        value={selectedStaff.id_role ?? ''}
                        onChange={(e) =>
                          handleChangeStaffRole(
                            selectedStaff,
                            Number(e.target.value),
                          )
                        }
                        className="input w-auto py-1.5 text-xs font-semibold"
                        aria-label={`บทบาทหลักของ ${selectedStaff.fullName}`}
                      >
                        {roles.map((r) => (
                          <option key={r.ID_Roles} value={r.ID_Roles}>
                            {r.Accessrights}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>

                  {/* การเข้าใช้เว็บโรงเรียนเฉพาะคน */}
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p className="text-sm font-semibold text-ink">
                        สิทธิ์เข้าใช้งาน &ldquo;เว็บโรงเรียน&rdquo;
                      </p>
                      <p className="mt-0.5 text-xs text-slate-500">
                        เปิดหรือปิดการเข้าใช้เว็บโรงเรียนเฉพาะบุคคลนี้ (แม้บทบาทหลักจะถูกปิดไว้)
                      </p>
                    </div>

                    <div className="inline-flex flex-wrap items-center gap-1.5">
                      {(
                        [
                          { val: 'inherit', label: 'ตามบทบาท' },
                          { val: 'visible', label: 'อนุญาตให้เข้าใช้' },
                          { val: 'hidden', label: 'ไม่อนุญาต' },
                        ] as { val: UserTabOverride; label: string }[]
                      ).map((opt) => {
                        const active = selectedStaffWebOverride === opt.val;
                        return (
                          <button
                            key={opt.val}
                            type="button"
                            disabled={
                              !canEdit ||
                              busyKey === `uweb:${selectedStaff.id_user}`
                            }
                            onClick={() =>
                              handleChangeUserWebAccess(selectedStaff, opt.val)
                            }
                            className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors ${
                              active
                                ? opt.val === 'hidden'
                                  ? 'border-slate-700 bg-slate-700 text-white'
                                  : 'border-brand-600 bg-brand-600 text-white'
                                : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                            } disabled:opacity-50`}
                          >
                            {opt.label}
                          </button>
                        );
                      })}
                    </div>
                  </div>

                  {/* หน้าที่ตั้งค่าหน้าเว็บโรงเรียนสาธารณะ (สำหรับครูผู้รับผิดชอบเว็บโรงเรียน) */}
                  <div className="flex flex-col gap-3 border-t border-line pt-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p className="text-sm font-semibold text-ink">
                        หน้าที่ตั้งค่า &ldquo;หน้าเว็บโรงเรียนสาธารณะ (Public Web)&rdquo;
                      </p>
                      <p className="mt-0.5 text-xs text-slate-500">
                        มอบหมายให้ครูท่านนี้สามารถแก้ไขข่าวประชาสัมพันธ์ ทำเนียบบุคลากร และข้อมูลบนหน้าเว็บโรงเรียนที่คนนอกดูได้
                      </p>
                    </div>

                    {(() => {
                      const pubWebOverride = resolveUserModuleOverrideLevel(
                        permState,
                        selectedStaff.id_user,
                        PUBLIC_WEB_SETTINGS_MODULE_KEY,
                      );
                      return (
                        <div className="inline-flex flex-wrap items-center gap-1.5">
                          {(
                            [
                              { val: 'inherit', label: 'ตามบทบาท' },
                              {
                                val: 'edit',
                                label: 'มอบหมายให้ตั้งค่าเว็บสาธารณะได้',
                              },
                              { val: 'hidden', label: 'ไม่อนุญาต' },
                            ] as { val: UserOverrideLevel; label: string }[]
                          ).map((opt) => {
                            const active =
                              pubWebOverride === opt.val ||
                              (opt.val === 'edit' && pubWebOverride === 'view');
                            return (
                              <button
                                key={opt.val}
                                type="button"
                                disabled={
                                  !canEdit ||
                                  busyKey ===
                                    `mod:${PUBLIC_WEB_SETTINGS_MODULE_KEY}`
                                }
                                onClick={() =>
                                  handleSaveUserSystemLevel(
                                    selectedStaff,
                                    PUBLIC_WEB_SETTINGS_MODULE_KEY,
                                    'ตั้งค่าหน้าเว็บโรงเรียนสาธารณะ',
                                    opt.val,
                                  )
                                }
                                className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors ${
                                  active
                                    ? opt.val === 'hidden'
                                      ? 'border-slate-700 bg-slate-700 text-white'
                                      : 'border-emerald-600 bg-emerald-600 text-white'
                                    : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                } disabled:opacity-50`}
                              >
                                {opt.label}
                              </button>
                            );
                          })}
                        </div>
                      );
                    })()}
                  </div>

                  {/* สิทธิ์รายระบบงานในเว็บโรงเรียนเฉพาะคน */}
                  <div className="border-t border-line pt-4">
                    <p className="mb-3 text-xs font-semibold text-slate-600">
                      กำหนดสิทธิ์แต่ละระบบงานในเว็บโรงเรียนเฉพาะบุคคลนี้ ({allowedSchoolSystems.length} ระบบงาน)
                    </p>

                    <div className="grid gap-3 sm:grid-cols-2">
                      {allowedSchoolSystems.map((sys) => {
                        const userOverride = resolveUserModuleOverrideLevel(
                          permState,
                          selectedStaff.id_user,
                          sys.key,
                        );
                        const allDivKeys = divisions.map((d) => d.division_key);
                        const roleDefaultLevel = resolveInheritedModuleLevel({
                          perms: permState,
                          roleTier: inferRoleTierFromRoleName(
                            selectedStaff.roleName,
                            selectedStaff.is_super_admin,
                            selectedStaff.id_role,
                            permState,
                          ),
                          roleId: selectedStaff.id_role,
                          idUser: selectedStaff.id_user,
                          moduleKey: sys.key,
                          divisionKeys:
                            sys.divisionKey === 'all' ? allDivKeys : [sys.divisionKey],
                          allDivisionKeys: allDivKeys,
                        });
                        const effectiveLevel =
                          userOverride === 'inherit'
                            ? roleDefaultLevel
                            : userOverride;
                        const isBusy = busyKey === `mod:${sys.key}`;

                        return (
                          <div
                            key={sys.key}
                            className="flex flex-col justify-between gap-2.5 rounded-xl border border-line bg-slate-50/40 p-3.5"
                          >
                            <div>
                              <div className="flex items-center justify-between gap-2">
                                <span className="text-xs font-semibold text-ink">
                                  {sys.title}
                                </span>
                                <span className="rounded-full bg-white px-2 py-0.5 text-[10px] font-semibold text-slate-600 ring-1 ring-line">
                                  ผลลัพธ์: {LEVEL_LABEL[effectiveLevel]}
                                </span>
                              </div>
                              <p className="mt-0.5 text-[11px] text-slate-500">
                                ค่าตั้งต้น (บทบาท + สังกัดฝ่าย):{' '}
                                <strong>{LEVEL_LABEL[roleDefaultLevel]}</strong>
                              </p>
                            </div>

                            <div className="grid grid-cols-4 gap-1">
                              {USER_LEVEL_OPTIONS.map((opt) => {
                                const active = userOverride === opt.value;
                                return (
                                  <button
                                    key={opt.value}
                                    type="button"
                                    disabled={!canEdit || isBusy}
                                    onClick={() =>
                                      handleSaveUserSystemLevel(
                                        selectedStaff,
                                        sys.key,
                                        sys.title,
                                        opt.value,
                                      )
                                    }
                                    className={`rounded-md border px-1.5 py-1 text-[11px] font-medium transition-colors ${
                                      active
                                        ? opt.activeClass
                                        : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                    } disabled:opacity-50`}
                                  >
                                    {opt.label}
                                  </button>
                                );
                              })}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                </div>

                {/* กล่องที่ 2: สิทธิ์การปฏิบัติงานในระบบวันลารายบุคคล */}
                <div className="card overflow-hidden">
                  <div className="card-title flex-wrap bg-slate-50/50">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-ink">
                        2.2 สิทธิ์การปฏิบัติงานในระบบวันลา ({selectedStaff.fullName})
                      </span>
                    </div>
                    <span className="badge-green">
                      เปิดใช้งาน {items.filter((i) => userFlags[i.key]).length} / เพดาน{' '}
                      {ceilingCountForStaff(selectedStaff)} รายการ
                    </span>
                  </div>

                  <PermMatrix
                    firstHeader="หมวดหมู่และรายการสิทธิ์ในระบบวันลา"
                    groups={groupItems(items).map(([group, list]) => ({
                      group,
                      rows: list.map((item) => {
                        const allowedByRole = inCeiling(selectedStaff, item.key);
                        return {
                          key: item.key,
                          label: item.label,
                          note: allowedByRole ? undefined : 'อยู่นอกเพดานสิทธิ์ของบทบาท',
                          muted: !allowedByRole,
                          cells: [
                            {
                              key: item.key,
                              checked: userFlags[item.key] ?? false,
                              dirty:
                                userFlags[item.key] !== savedUserFlags[item.key],
                              disabled: !allowedByRole || !canEdit,
                              onChange: () =>
                                setUserFlags((prev) => ({
                                  ...prev,
                                  [item.key]: !prev[item.key],
                                })),
                            },
                          ],
                        };
                      }),
                    }))}
                  />
                  <SaveBar
                    changed={changedUserFlagKeys.length}
                    busy={savingUserFlags}
                    onReset={() => setUserFlags(savedUserFlags)}
                    onSave={saveSelectedUserLeaveFlags}
                  />
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {/* ─── หมวดที่ 3: ขอบเขตโรงเรียนและเพดานสิทธิ์ (เฉพาะผู้ดูแลส่วนกลาง) ──── */}
      {activeSection === 'package_ceiling' && isSuper && (
        <div className="space-y-6">
          {/* 3.1 ขอบเขตระบบงานของโรงเรียน (SchoolPackagePanel) */}
          <SchoolPackagePanel
            schoolId={schoolId}
            schoolName={school?.fullName || `โรงเรียน #${schoolId ?? '-'}`}
            canManage={isSuper}
            onUpdated={async () => {
              await loadData();
              await onReload();
            }}
          />

          {/* 3.2 เพดานสิทธิ์สูงสุดตามบทบาท (RolePermissions) */}
          <div className="surface-card overflow-hidden">
            <div className="border-b border-line bg-slate-50/60 px-6 py-4">
              <h2 className="text-base font-semibold text-ink">
                เพดานสิทธิ์สูงสุดตามบทบาท (ระบบวันลา)
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                กำหนดว่าแต่ละบทบาททำอะไรได้มากที่สุดในโรงเรียนนี้ — แอดมินโรงเรียนปรับสิทธิ์รายบุคคลได้ไม่เกินเพดานนี้
              </p>
            </div>

            <PermMatrix
              firstHeader="รายการสิทธิ์การทำงาน"
              roles={roles}
              countLabel={(r) => `${countCeilingForRole(r.ID_Roles)}/${items.length}`}
              groups={groupItems(items).map(([group, list]) => ({
                group,
                rows: list.map((item) => ({
                  key: item.key,
                  label: item.label,
                  cells: roles.map((r) => {
                    const k = cellKey(r.ID_Roles, item.key);
                    return {
                      key: k,
                      checked: ceilingGrid[k] ?? false,
                      dirty: (ceilingGrid[k] ?? false) !== (savedCeiling[k] ?? false),
                      onChange: () => toggleCeilingCell(r.ID_Roles, item.key),
                    };
                  }),
                })),
              }))}
            />
            <SaveBar
              changed={changedCeilingKeys.length}
              busy={savingCeiling}
              onSave={saveCeilingGrid}
              onReset={() => setCeilingGrid(savedCeiling)}
            />
          </div>

          {/* 3.3 รายชื่อบทบาทเพิ่มเติมของโรงเรียน (RoleListPanel) */}
          {schoolId !== null && (
            <div className="surface-card p-6">
              <div className="mb-4">
                <h2 className="text-base font-semibold text-ink">
                  รายชื่อบทบาทของโรงเรียน ({roles.length} บทบาท)
                </h2>
                <p className="mt-0.5 text-xs text-slate-500">
                  จัดการรายชื่อบทบาทเพิ่มเติมที่ใช้เฉพาะโรงเรียนนี้ (บทบาทหลักของระบบใช้ร่วมกันทุกโรงเรียน)
                </p>
              </div>
              <Notice message={ null } />
              <RoleListPanel
                roles={roles}
                schoolId={schoolId}
                onChanged={loadData}
              />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
