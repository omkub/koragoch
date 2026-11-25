import { ADMIN_ROLE_ID, supabase } from '../supabase';

/**
 * ระบบสิทธิ์ระดับบทบาท (Role) และระดับรายบุคคล (User Override)
 * สำหรับทั้ง "ฝ่ายงาน (Division)", "Module ย่อย (Sub-Module)" และแท็บ "เว็บโรงเรียน"
 * เก็บลงตาราง Permissions (id_school, id_role, menu_id, status)
 */

export type AccessLevel = 'hidden' | 'view' | 'edit';
export type UserOverrideLevel = 'inherit' | AccessLevel;
export type UserTabOverride = 'inherit' | 'visible' | 'hidden';

const DIVISION_VIEW_MENU_IDS: Record<string, number> = {
  hr: -201,
  academic: -202,
  admin: -203,
  finance: -204,
};

const DIVISION_EDIT_MENU_IDS: Record<string, number> = {
  hr: -301,
  academic: -302,
  admin: -303,
  finance: -304,
};

export const PUBLIC_WEB_SETTINGS_MODULE_KEY = 'public-web-settings';

const MODULE_VIEW_MENU_IDS: Record<string, number> = {
  'leave-system': -401,
  'staff-registry': -402,
  departments: -403,
  'students-classrooms': -404,
  'curriculum-schedule': -405,
  documents: -406,
  announcements: -407,
  'finance-budget': -408,
  'appointment-orders': -409,
  'public-web-settings': -410,
  'student-admissions': -411,
};

const MODULE_EDIT_MENU_IDS: Record<string, number> = {
  'leave-system': -501,
  'staff-registry': -502,
  departments: -503,
  'students-classrooms': -504,
  'curriculum-schedule': -505,
  documents: -506,
  announcements: -507,
  'finance-budget': -508,
  'appointment-orders': -509,
  'public-web-settings': -510,
  'student-admissions': -511,
};

const USER_MODULE_SLOT: Record<string, number> = {
  'leave-system': 1,
  'staff-registry': 2,
  departments: 3,
  'students-classrooms': 4,
  'curriculum-schedule': 5,
  documents: 6,
  announcements: 7,
  'finance-budget': 8,
  'appointment-orders': 9,
  'public-web-settings': 10,
  'student-admissions': 11,
};

const USER_DIVISION_SLOT: Record<string, number> = {
  hr: 41,
  academic: 42,
  admin: 43,
  finance: 44,
};

function stableHash(key: string): number {
  let h = 0;
  for (let i = 0; i < key.length; i++) {
    h = (h * 31 + key.charCodeAt(i)) % 900;
  }
  return Math.abs(h) + 1;
}

export function getDivisionViewMenuId(divisionKey: string): number {
  return DIVISION_VIEW_MENU_IDS[divisionKey] ?? -(2000 + stableHash(divisionKey));
}

export function getDivisionEditMenuId(divisionKey: string): number {
  return DIVISION_EDIT_MENU_IDS[divisionKey] ?? -(3000 + stableHash(divisionKey));
}

export function getModuleViewMenuId(moduleKey: string): number {
  return MODULE_VIEW_MENU_IDS[moduleKey] ?? -(4000 + stableHash(moduleKey));
}

export function getModuleEditMenuId(moduleKey: string): number {
  return MODULE_EDIT_MENU_IDS[moduleKey] ?? -(5000 + stableHash(moduleKey));
}

/** รหัส menu_id สำหรับบันทึกสิทธิ์รายบุคคล (id_user) ในตาราง Permissions */
export function getUserSchoolWebTabMenuId(idUser: number): number {
  return -(100000 + idUser * 100);
}

export function getUserModuleViewMenuId(idUser: number, moduleKey: string): number {
  const slot = USER_MODULE_SLOT[moduleKey] ?? (10 + (stableHash(moduleKey) % 10));
  return -(100000 + idUser * 100 + slot);
}

export function getUserModuleEditMenuId(idUser: number, moduleKey: string): number {
  const slot = USER_MODULE_SLOT[moduleKey] ?? (10 + (stableHash(moduleKey) % 10));
  return -(100000 + idUser * 100 + 20 + slot);
}

export function getUserDivisionViewMenuId(idUser: number, divisionKey: string): number {
  const slot = USER_DIVISION_SLOT[divisionKey] ?? (45 + (stableHash(divisionKey) % 5));
  return -(100000 + idUser * 100 + slot);
}

export function getUserDivisionEditMenuId(idUser: number, divisionKey: string): number {
  const slot = USER_DIVISION_SLOT[divisionKey] ?? (45 + (stableHash(divisionKey) % 5));
  return -(100000 + idUser * 100 + 10 + slot);
}

function isStatusOn(status: unknown): boolean {
  return (
    status === true ||
    status === 1 ||
    String(status).trim() === '1' ||
    String(status).toUpperCase() === 'TRUE'
  );
}

export const ROLE_TIER_EXECUTIVE_MENU_ID = -601;
export const ROLE_TIER_ADMIN_MENU_ID = -602;

export interface RoleDivisionModulePermissions {
  /** key: `${id_role}:${division_key}` -> { can_view, can_edit } */
  divisionByRole: Record<string, { can_view: boolean; can_edit: boolean }>;
  /** key: `${id_role}:${module_key}` -> { can_view, can_edit } */
  moduleByRole: Record<string, { can_view: boolean; can_edit: boolean }>;
  /** key: `${id_role}` -> 'user' | 'executive' | 'school_admin' (ระดับสิทธิ์หลักที่ตั้งค่าผูกกับบทบาท) */
  roleTierByRole?: Record<number, 'user' | 'executive' | 'school_admin'>;
  /** key: `${id_user}` -> boolean (เปิด/ปิดแท็บเว็บโรงเรียนรายคน) */
  userTabOverride: Record<number, boolean>;
  /** key: `${id_user}:${division_key}` -> { can_view, can_edit } */
  divisionByUser: Record<string, { can_view: boolean; can_edit: boolean }>;
  /** key: `${id_user}:${module_key}` -> { can_view, can_edit } */
  moduleByUser: Record<string, { can_view: boolean; can_edit: boolean }>;
}

export async function fetchRoleDivisionModulePermissions(
  schoolId: number,
  divisionKeys: string[] = ['hr', 'academic', 'admin', 'finance'],
  moduleKeys: string[] = Object.keys(MODULE_VIEW_MENU_IDS),
): Promise<RoleDivisionModulePermissions> {
  const result: RoleDivisionModulePermissions = {
    divisionByRole: {},
    moduleByRole: {},
    roleTierByRole: {},
    userTabOverride: {},
    divisionByUser: {},
    moduleByUser: {},
  };

  try {
    // แหล่งเดียว: ตาราง Permissions (ตารางเก่า SchoolWebRoleDivisionAccess ย้ายเข้ามาแล้ว
    // ด้วย supabase/school_web_division_edit.sql)
    const permRes = await supabase
      .from('Permissions')
      .select('id_role, menu_id, status')
      .eq('id_school', schoolId)
      .lt('menu_id', -199);

    // 2. อ่านค่าจากตาราง Permissions (menu_id < -199)
    const divKeyByViewMenu = new Map<number, string>();
    const divKeyByEditMenu = new Map<number, string>();
    for (const dKey of divisionKeys) {
      divKeyByViewMenu.set(getDivisionViewMenuId(dKey), dKey);
      divKeyByEditMenu.set(getDivisionEditMenuId(dKey), dKey);
    }

    const modKeyByViewMenu = new Map<number, string>();
    const modKeyByEditMenu = new Map<number, string>();
    for (const mKey of moduleKeys) {
      modKeyByViewMenu.set(getModuleViewMenuId(mKey), mKey);
      modKeyByEditMenu.set(getModuleEditMenuId(mKey), mKey);
    }

    // แผนที่ slot รายบุคคล (รองรับทั้งฝ่ายมาตรฐานและฝ่ายที่โรงเรียนสร้างเพิ่ม)
    const modKeyBySlot = new Map<number, string>();
    for (const [mKey, slot] of Object.entries(USER_MODULE_SLOT)) {
      modKeyBySlot.set(slot, mKey);
    }
    for (const mKey of moduleKeys) {
      const slot = USER_MODULE_SLOT[mKey] ?? (10 + (stableHash(mKey) % 10));
      if (!modKeyBySlot.has(slot)) modKeyBySlot.set(slot, mKey);
    }

    const divKeyBySlot = new Map<number, string>();
    for (const [dKey, slot] of Object.entries(USER_DIVISION_SLOT)) {
      divKeyBySlot.set(slot, dKey);
    }
    for (const dKey of divisionKeys) {
      const slot = USER_DIVISION_SLOT[dKey] ?? (45 + (stableHash(dKey) % 5));
      if (!divKeyBySlot.has(slot)) divKeyBySlot.set(slot, dKey);
    }

    for (const row of (permRes.data as
      | { id_role: number; menu_id: number; status: unknown }[]
      | null) ?? []) {
      const roleId = Number(row.id_role);
      const menuId = Number(row.menu_id);
      const on = isStatusOn(row.status);

      // กรณีเป็นรหัสรายบุคคล (menu_id <= -100000)
      if (menuId <= -100000) {
        const absVal = Math.abs(menuId) - 100000;
        const idUser = Math.floor(absVal / 100);
        const slot = absVal % 100;
        if (idUser <= 0) continue;

        if (slot === 0) {
          result.userTabOverride[idUser] = on;
        } else if (slot >= 1 && slot <= 19) {
          const mKey = modKeyBySlot.get(slot);
          if (mKey) {
            const k = `${idUser}:${mKey}`;
            const prev = result.moduleByUser[k] ?? { can_view: true, can_edit: false };
            result.moduleByUser[k] = { ...prev, can_view: on };
          }
        } else if (slot >= 21 && slot <= 39) {
          const mKey = modKeyBySlot.get(slot - 20);
          if (mKey) {
            const k = `${idUser}:${mKey}`;
            const prev = result.moduleByUser[k] ?? { can_view: true, can_edit: false };
            result.moduleByUser[k] = { ...prev, can_edit: on };
          }
        } else if (slot >= 41 && slot <= 49) {
          const dKey = divKeyBySlot.get(slot);
          if (dKey) {
            const k = `${idUser}:${dKey}`;
            const prev = result.divisionByUser[k] ?? { can_view: true, can_edit: false };
            result.divisionByUser[k] = { ...prev, can_view: on };
          }
        } else if (slot >= 51 && slot <= 59) {
          const dKey = divKeyBySlot.get(slot - 10);
          if (dKey) {
            const k = `${idUser}:${dKey}`;
            const prev = result.divisionByUser[k] ?? { can_view: true, can_edit: false };
            result.divisionByUser[k] = { ...prev, can_edit: on };
          }
        }
        continue;
      }

      if (menuId === ROLE_TIER_ADMIN_MENU_ID) {
        if (on) {
          result.roleTierByRole![roleId] = 'school_admin';
        } else if (!result.roleTierByRole![roleId]) {
          result.roleTierByRole![roleId] = 'user';
        }
        continue;
      }
      if (menuId === ROLE_TIER_EXECUTIVE_MENU_ID) {
        if (on && result.roleTierByRole![roleId] !== 'school_admin') {
          result.roleTierByRole![roleId] = 'executive';
        } else if (!on && !result.roleTierByRole![roleId]) {
          result.roleTierByRole![roleId] = 'user';
        }
        continue;
      }

      if (divKeyByViewMenu.has(menuId)) {
        const dKey = divKeyByViewMenu.get(menuId)!;
        const k = `${roleId}:${dKey}`;
        const prev = result.divisionByRole[k] ?? { can_view: true, can_edit: false };
        result.divisionByRole[k] = { ...prev, can_view: on };
      } else if (divKeyByEditMenu.has(menuId)) {
        const dKey = divKeyByEditMenu.get(menuId)!;
        const k = `${roleId}:${dKey}`;
        const prev = result.divisionByRole[k] ?? { can_view: true, can_edit: false };
        result.divisionByRole[k] = { ...prev, can_edit: on };
      } else if (modKeyByViewMenu.has(menuId)) {
        const mKey = modKeyByViewMenu.get(menuId)!;
        const k = `${roleId}:${mKey}`;
        const prev = result.moduleByRole[k] ?? { can_view: true, can_edit: false };
        result.moduleByRole[k] = { ...prev, can_view: on };
      } else if (modKeyByEditMenu.has(menuId)) {
        const mKey = modKeyByEditMenu.get(menuId)!;
        const k = `${roleId}:${mKey}`;
        const prev = result.moduleByRole[k] ?? { can_view: true, can_edit: false };
        result.moduleByRole[k] = { ...prev, can_edit: on };
      }
    }
  } catch {
    /* ignore and use default */
  }

  return result;
}

export async function saveRoleDivisionAccessLevel(params: {
  schoolId: number;
  roleId: number;
  divisionKey: string;
  divisionId?: number;
  level: AccessLevel;
}): Promise<{ error: string | null }> {
  const { schoolId, roleId, divisionKey, level } = params;
  const canView = level !== 'hidden';
  const canEdit = level === 'edit';
  const now = new Date().toISOString();

  const rows = [
    {
      id_school: schoolId,
      id_role: roleId,
      menu_id: getDivisionViewMenuId(divisionKey),
      status: canView ? '1' : '0',
      updatedAt: now,
    },
    {
      id_school: schoolId,
      id_role: roleId,
      menu_id: getDivisionEditMenuId(divisionKey),
      status: canEdit ? '1' : '0',
      updatedAt: now,
    },
  ];

  const { error } = await supabase
    .from('Permissions')
    .upsert(rows, { onConflict: 'id_school,id_role,menu_id' });


  return { error: error ? error.message : null };
}

export async function saveRoleModuleAccessLevel(params: {
  schoolId: number;
  roleId: number;
  moduleKey: string;
  level: AccessLevel;
}): Promise<{ error: string | null }> {
  const { schoolId, roleId, moduleKey, level } = params;
  const canView = level !== 'hidden';
  const canEdit = level === 'edit';
  const now = new Date().toISOString();

  const rows = [
    {
      id_school: schoolId,
      id_role: roleId,
      menu_id: getModuleViewMenuId(moduleKey),
      status: canView ? '1' : '0',
      updatedAt: now,
    },
    {
      id_school: schoolId,
      id_role: roleId,
      menu_id: getModuleEditMenuId(moduleKey),
      status: canEdit ? '1' : '0',
      updatedAt: now,
    },
  ];

  const { error } = await supabase
    .from('Permissions')
    .upsert(rows, { onConflict: 'id_school,id_role,menu_id' });

  return { error: error ? error.message : null };
}

/** บันทึกสิทธิ์การเห็นแท็บ "เว็บโรงเรียน" รายบุคคล */
export async function saveUserSchoolWebTabOverride(params: {
  schoolId: number;
  idUser: number;
  override: UserTabOverride;
}): Promise<{ error: string | null }> {
  const { schoolId, idUser, override } = params;
  const menuId = getUserSchoolWebTabMenuId(idUser);

  if (override === 'inherit') {
    const { error } = await supabase
      .from('Permissions')
      .delete()
      .eq('id_school', schoolId)
      .eq('id_role', ADMIN_ROLE_ID)
      .eq('menu_id', menuId);
    return { error: error ? error.message : null };
  }

  const { error } = await supabase.from('Permissions').upsert(
    {
      id_school: schoolId,
      id_role: ADMIN_ROLE_ID,
      menu_id: menuId,
      status: override === 'visible' ? '1' : '0',
      updatedAt: new Date().toISOString(),
    },
    { onConflict: 'id_school,id_role,menu_id' },
  );
  return { error: error ? error.message : null };
}

/** บันทึกสิทธิ์เข้าถึง Module ย่อยรายบุคคล (inherit = ใช้ตามบทบาท) */
export async function saveUserModuleOverride(params: {
  schoolId: number;
  idUser: number;
  moduleKey: string;
  level: UserOverrideLevel;
}): Promise<{ error: string | null }> {
  const { schoolId, idUser, moduleKey, level } = params;
  const viewMenuId = getUserModuleViewMenuId(idUser, moduleKey);
  const editMenuId = getUserModuleEditMenuId(idUser, moduleKey);

  if (level === 'inherit') {
    const { error } = await supabase
      .from('Permissions')
      .delete()
      .eq('id_school', schoolId)
      .eq('id_role', ADMIN_ROLE_ID)
      .in('menu_id', [viewMenuId, editMenuId]);
    return { error: error ? error.message : null };
  }

  const canView = level !== 'hidden';
  const canEdit = level === 'edit';
  const now = new Date().toISOString();

  const { error } = await supabase.from('Permissions').upsert(
    [
      {
        id_school: schoolId,
        id_role: ADMIN_ROLE_ID,
        menu_id: viewMenuId,
        status: canView ? '1' : '0',
        updatedAt: now,
      },
      {
        id_school: schoolId,
        id_role: ADMIN_ROLE_ID,
        menu_id: editMenuId,
        status: canEdit ? '1' : '0',
        updatedAt: now,
      },
    ],
    { onConflict: 'id_school,id_role,menu_id' },
  );

  return { error: error ? error.message : null };
}

export function resolveUserModuleOverrideLevel(
  perms: RoleDivisionModulePermissions,
  idUser: number,
  moduleKey: string,
): UserOverrideLevel {
  const entry = perms.moduleByUser[`${idUser}:${moduleKey}`];
  if (!entry) return 'inherit';
  if (!entry.can_view) return 'hidden';
  return entry.can_edit ? 'edit' : 'view';
}

export function resolveDivisionAccessLevel(
  perms: RoleDivisionModulePermissions,
  roleId: number | null,
  divisionKey: string,
  isAdminRole = false,
  idUser?: number | null,
): AccessLevel {
  if (isAdminRole) return 'edit';

  if (idUser != null) {
    const userDiv = perms.divisionByUser[`${idUser}:${divisionKey}`];
    if (userDiv) {
      if (!userDiv.can_view) return 'hidden';
      return userDiv.can_edit ? 'edit' : 'view';
    }
  }

  if (roleId === null) return 'view';
  const entry = perms.divisionByRole[`${roleId}:${divisionKey}`];
  if (!entry) return 'view';
  if (!entry.can_view) return 'hidden';
  return entry.can_edit ? 'edit' : 'view';
}

export function resolveModuleAccessLevel(
  perms: RoleDivisionModulePermissions,
  roleId: number | null,
  divisionKey: string,
  moduleKey: string,
  isAdminRole = false,
  idUser?: number | null,
): AccessLevel {
  if (isAdminRole) return 'edit';

  // 1. ตรวจสิทธิ์เจาะจงรายบุคคล (User Override) ก่อนเสมอ
  if (idUser != null) {
    const userMod = perms.moduleByUser[`${idUser}:${moduleKey}`];
    if (userMod) {
      if (!userMod.can_view) return 'hidden';
      return userMod.can_edit ? 'edit' : 'view';
    }
  }

  if (roleId === null) return 'view';

  // 2. หากไม่มี User Override ให้ตรวจตามสิทธิ์ของบทบาท (Role)
  const divLevel = resolveDivisionAccessLevel(
    perms,
    roleId,
    divisionKey,
    false,
    idUser,
  );
  if (divLevel === 'hidden') return 'hidden';

  const modEntry = perms.moduleByRole[`${roleId}:${moduleKey}`];
  if (!modEntry) {
    return divLevel;
  }
  if (!modEntry.can_view) return 'hidden';
  return modEntry.can_edit ? 'edit' : 'view';
}

/**
 * ตรวจสอบว่าผู้ใช้มีสิทธิ์ตั้งค่าหน้าเว็บโรงเรียนสาธารณะ (Public Web) หรือไม่
 * อนุญาต 3 กลุ่ม:
 * 1) ผู้ดูแลระบบส่วนกลาง (isSuper)
 * 2) แอดมินโรงเรียน (isAdminRole / roleTier === 'school_admin')
 * 3) ครูที่ได้รับมอบหมายหน้าที่ตั้งค่าเว็บโรงเรียนสาธารณะ (รายบุคคล หรือตามบทบาท)
 */
export function canUserManagePublicSchoolWeb(params: {
  perms: RoleDivisionModulePermissions;
  roleId: number | null;
  idUser?: number | null;
  isSuper?: boolean;
  isAdminRole?: boolean;
}): boolean {
  const { perms, roleId, idUser, isSuper = false, isAdminRole = false } = params;
  if (isSuper) return true;

  // 1. ตรวจสิทธิ์รายบุคคล (User Override) ก่อนเสมอ
  if (idUser != null) {
    const userEntry =
      perms.moduleByUser[`${idUser}:${PUBLIC_WEB_SETTINGS_MODULE_KEY}`];
    if (userEntry !== undefined) {
      return Boolean(userEntry.can_view && userEntry.can_edit);
    }
  }

  // 2. ตรวจสิทธิ์ตามบทบาท (Role) — หากผู้ดูแลส่วนกลางกำหนดไว้ชัดเจนให้ยึดค่านั้น
  if (roleId != null) {
    const roleEntry =
      perms.moduleByRole[`${roleId}:${PUBLIC_WEB_SETTINGS_MODULE_KEY}`];
    if (roleEntry !== undefined) {
      return Boolean(roleEntry.can_view && roleEntry.can_edit);
    }
  }

  return isAdminRole;
}
