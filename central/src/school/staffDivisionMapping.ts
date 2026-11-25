import { ADMIN_ROLE_ID, supabase } from '../supabase';
import type { DivisionWithModules } from './mapping';
import {
  getUserDivisionEditMenuId,
  getUserDivisionViewMenuId,
  getUserSchoolWebTabMenuId,
  ROLE_TIER_ADMIN_MENU_ID,
  ROLE_TIER_EXECUTIVE_MENU_ID,
  type AccessLevel,
  type RoleDivisionModulePermissions,
} from './roleModulePermissions';

/**
 * พาร์ทที่ 1: ระบบจัดการสังกัดฝ่ายของบุคลากร (บุคลากร <-> ฝ่าย <-> Module)
 * และระดับสิทธิ์หลัก 4 ระดับ (ผู้ใช้งาน / ผู้บริหาร / Admin โรงเรียน / Super Admin)
 */

/** ระดับสิทธิ์หลัก 4 ระดับ */
export type SchoolRoleTier =
  | 'user' // ผู้ใช้งาน (เห็นเฉพาะฝ่ายที่ตัวเองสังกัด และ Module ในฝ่ายตัวเอง)
  | 'executive' // ผู้บริหาร (เห็นทุกฝ่ายในโรงเรียน ดูรายงาน/อนุมัติ)
  | 'school_admin' // Admin โรงเรียน (เห็นและจัดการได้ทุกฝ่ายและทุก Module ในโรงเรียนตัวเอง)
  | 'super_admin'; // Super Admin (จัดการได้ทุกโรงเรียน และกำหนดเพดานสิทธิ์ระดับโรงเรียน)

/** บทบาทของบุคลากรภายในฝ่ายที่สังกัด */
export type DivisionMemberRole =
  | 'none' // ไม่ได้สังกัดฝ่ายนี้
  | 'member' // สมาชิกฝ่าย (มองเห็นฝ่ายและใช้งาน Module ในฝ่ายได้)
  | 'editor'; // เจ้าหน้าที่ประจำฝ่าย (เพิ่ม/แก้ไข/ลบข้อมูลใน Module ของฝ่ายตัวเองได้)

export interface SchoolStaffMember {
  id_user: number;
  fullName: string;
  username: string;
  id_role: number | null;
  roleName: string;
  is_super_admin: boolean;
}

export interface TabPermissionItem {
  menuId: number;
  key: string;
  label: string;
  description: string;
}

/** รายการเมนูหลักที่ใช้ควบคุมสิทธิ์เมื่อเข้าใช้งานได้แล้ว */
export const SYSTEM_TABS: TabPermissionItem[] = [
  {
    menuId: 6,
    key: 'school_web',
    label: 'เมนูเว็บโรงเรียน',
    description: 'เข้าใช้งานหน้าเว็บโรงเรียน 4 ฝ่าย คำสั่งแต่งตั้ง และระบบบริหารงานโรงเรียน',
  },
  {
    menuId: 1,
    key: 'leave_home',
    label: 'เมนูหน้าหลัก / ยื่นใบลา',
    description: 'หน้ายื่นใบลา ดูสถานะใบลา และปฏิทินการลาของตนเอง',
  },
  {
    menuId: 4,
    key: 'executive_overview',
    label: 'เมนูภาพรวมผู้บริหาร / การอนุมัติ',
    description: 'หน้าพิจารณาอนุมัติใบลาและดูสรุปภาพรวมสำหรับผู้บริหาร',
  },
  {
    menuId: 2,
    key: 'reports',
    label: 'เมนูรายงานและสถิติ',
    description: 'ดูรายงานสรุปวันลา สถิติบุคลากร และพิมพ์เอกสารรายงาน',
  },
  {
    menuId: 3,
    key: 'staff_manage',
    label: 'เมนูจัดการบุคลากรและผู้ใช้',
    description: 'เพิ่ม/แก้ไขข้อมูลบุคลากร รหัสผ่าน และโครงสร้างผู้ใช้งาน',
  },
  {
    menuId: 5,
    key: 'system_settings',
    label: 'เมนูตั้งค่าระบบ',
    description: 'ตั้งค่าข้อมูลโรงเรียน ปีการศึกษา ประเภทการลา และสิทธิ์ระบบ',
  },
];

export const ROLE_TIER_META: Record<
  SchoolRoleTier,
  {
    label: string;
    shortLabel: string;
    description: string;
    badgeClass: string;
  }
> = {
  user: {
    label: 'ผู้ใช้งาน (ครู/บุคลากร)',
    shortLabel: 'ผู้ใช้งาน',
    description: 'มองเห็นเฉพาะฝ่ายที่ตัวเองสังกัด และใช้งานระบบงานตามฝ่ายของตัวเอง',
    badgeClass: 'bg-slate-100 text-slate-700 ring-1 ring-inset ring-slate-200',
  },
  executive: {
    label: 'ผู้บริหาร (ผอ./รอง ผอ.)',
    shortLabel: 'ผู้บริหาร',
    description: 'มองเห็นข้อมูลครบทุกฝ่ายของโรงเรียน เพื่อดูรายงานและพิจารณาอนุมัติ',
    badgeClass: 'bg-amber-50 text-amber-800 ring-1 ring-inset ring-amber-200',
  },
  school_admin: {
    label: 'แอดมินโรงเรียน',
    shortLabel: 'แอดมินโรงเรียน',
    description: 'เข้าถึงและแก้ไขได้ทุกฝ่ายและทุกระบบงานในโรงเรียน และจัดบุคลากรเข้าฝ่ายได้',
    badgeClass: 'bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-200',
  },
  super_admin: {
    label: 'ผู้ดูแลส่วนกลาง',
    shortLabel: 'ผู้ดูแลส่วนกลาง',
    description: 'ดูแลทุกโรงเรียน เปิด/ปิดเว็บโรงเรียน และกำหนดระบบงานที่แต่ละโรงเรียนใช้ได้',
    badgeClass: 'bg-brand-50 text-brand-700 ring-1 ring-inset ring-brand-200',
  },
};

/**
 * หาค่าเริ่มต้นของระดับสิทธิ์ 4 ระดับจากรหัสบทบาท (id_role = 22), ค่าที่บันทึกไว้ในฐานข้อมูล (roleTierByRole),
 * หรือชื่อบทบาท (สำหรับกรณีที่ยังไม่ได้บันทึกค่าเฉพาะเจาะจง)
 */
export function inferRoleTierFromRoleName(
  roleName: string | null | undefined,
  isSuperAdmin = false,
  roleId?: number | null,
  perms?: RoleDivisionModulePermissions | null,
): SchoolRoleTier {
  if (isSuperAdmin) return 'super_admin';
  if (roleId != null && perms?.roleTierByRole?.[roleId]) {
    return perms.roleTierByRole[roleId];
  }
  if (roleId === ADMIN_ROLE_ID) return 'school_admin';
  const text = (roleName ?? '').trim();
  if (
    text.includes('ผู้ดูแลระบบ') ||
    text.toLowerCase().includes('admin')
  ) {
    return 'school_admin';
  }
  if (
    text.includes('ผู้บริหาร') ||
    text.includes('ผู้อำนวยการ') ||
    text.includes('รองผู้อำนวยการ')
  ) {
    return 'executive';
  }
  return 'user';
}

/**
 * บันทึกระดับสิทธิ์หลัก (ผู้ใช้งาน / ผู้บริหาร / แอดมินโรงเรียน) ผูกกับบทบาท (id_role) ลงฐานข้อมูล
 * ทำให้โรงเรียนที่เพิ่มบทบาทใหม่สามารถเลือกระดับสิทธิ์ได้โดยไม่ต้องพึ่งการเดาจากชื่อบทบาท
 */
export async function saveRoleTierForRole(params: {
  schoolId: number;
  roleId: number;
  tier: 'user' | 'executive' | 'school_admin';
}): Promise<{ error: string | null }> {
  const { schoolId, roleId, tier } = params;
  const now = new Date().toISOString();
  const isAdminTier = tier === 'school_admin';
  const isExecTier = tier === 'executive';

  const { error } = await supabase.from('Permissions').upsert(
    [
      {
        id_school: schoolId,
        id_role: roleId,
        menu_id: ROLE_TIER_EXECUTIVE_MENU_ID,
        status: isExecTier ? '1' : '0',
        updatedAt: now,
      },
      {
        id_school: schoolId,
        id_role: roleId,
        menu_id: ROLE_TIER_ADMIN_MENU_ID,
        status: isAdminTier ? '1' : '0',
        updatedAt: now,
      },
    ],
    { onConflict: 'id_school,id_role,menu_id' },
  );
  return { error: error ? error.message : null };
}

/**
 * ดึงรายชื่อบุคลากรทั้งหมดของโรงเรียนจากตาราง Teachers พร้อมชื่อบทบาทและระดับสิทธิ์ 4 ระดับ
 */
export async function fetchSchoolStaffMembers(
  schoolId: number,
): Promise<SchoolStaffMember[]> {
  const [usersRes, rolesRes] = await Promise.all([
    supabase
      .from('Teachers')
      .select('id_user, fullName, username, id_role, is_super_admin')
      .eq('id_school', schoolId)
      .order('fullName', { ascending: true }),
    supabase
      .from('roles')
      .select('ID_Roles, Accessrights')
      .order('ID_Roles', { ascending: true }),
  ]);

  const roleMap = new Map<number, string>();
  for (const r of (rolesRes.data as { ID_Roles: number; Accessrights: string }[] | null) ?? []) {
    roleMap.set(r.ID_Roles, r.Accessrights);
  }

  const rows =
    (usersRes.data as {
      id_user: number;
      fullName: string | null;
      username: string | null;
      id_role: number | null;
      is_super_admin: boolean | null;
    }[] | null) ?? [];

  return rows.map((u) => {
    const roleName = (u.id_role != null ? roleMap.get(u.id_role) : null) ?? 'ผู้ใช้งาน';
    return {
      id_user: u.id_user,
      fullName: u.fullName?.trim() || u.username?.trim() || `ผู้ใช้ #${u.id_user}`,
      username: u.username?.trim() || '',
      id_role: u.id_role,
      roleName,
      is_super_admin: Boolean(u.is_super_admin),
    };
  });
}

/**
 * ตรวจสอบสถานะการสังกัดฝ่ายของบุคลากรรายคน (none | member | editor)
 */
export function getStaffDivisionMemberRole(
  perms: RoleDivisionModulePermissions,
  idUser: number,
  divisionKey: string,
): DivisionMemberRole {
  const entry = perms.divisionByUser[`${idUser}:${divisionKey}`];
  if (!entry || !entry.can_view) return 'none';
  return entry.can_edit ? 'editor' : 'member';
}

/**
 * ดึงรายการ division_key ทั้งหมดที่บุคลากรคนนี้สังกัดอยู่
 */
export function getStaffAssignedDivisionKeys(
  perms: RoleDivisionModulePermissions,
  idUser: number,
  allDivisionKeys: string[],
): string[] {
  return allDivisionKeys.filter(
    (divKey) => getStaffDivisionMemberRole(perms, idUser, divKey) !== 'none',
  );
}

/**
 * ตรวจสอบว่าในโรงเรียนนี้มีการตั้งค่าผูกบุคลากรเข้ากับฝ่ายไว้แล้วหรือยัง
 */
export function hasAnyStaffDivisionMappings(
  perms: RoleDivisionModulePermissions,
): boolean {
  return Object.values(perms.divisionByUser).some((v) => v.can_view);
}

/**
 * บันทึกการ Map บุคลากรเข้ากับฝ่ายงาน
 * - role = 'none'   -> เอาออกจากฝ่าย (ลบแถวใน Permissions)
 * - role = 'member' -> สังกัดฝ่ายนี้ (ดูและใช้งาน Module ของฝ่ายนี้ได้)
 * - role = 'editor' -> เจ้าหน้าที่ประจำฝ่าย (เพิ่ม/แก้ไขข้อมูลใน Module ของฝ่ายนี้ได้)
 */
export async function saveStaffDivisionMembership(params: {
  schoolId: number;
  idUser: number;
  divisionKey: string;
  memberRole: DivisionMemberRole;
}): Promise<{ error: string | null }> {
  const { schoolId, idUser, divisionKey, memberRole } = params;
  const viewMenuId = getUserDivisionViewMenuId(idUser, divisionKey);
  const editMenuId = getUserDivisionEditMenuId(idUser, divisionKey);

  if (memberRole === 'none') {
    const { error } = await supabase
      .from('Permissions')
      .delete()
      .eq('id_school', schoolId)
      .eq('id_role', ADMIN_ROLE_ID)
      .in('menu_id', [viewMenuId, editMenuId]);
    return { error: error ? error.message : null };
  }

  const now = new Date().toISOString();
  const canEdit = memberRole === 'editor';

  const { error } = await supabase.from('Permissions').upsert(
    [
      {
        id_school: schoolId,
        id_role: ADMIN_ROLE_ID,
        menu_id: viewMenuId,
        status: '1',
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

/**
 * อัปเดตบทบาท (id_role) ของบุคลากรในตาราง Teachers
 */
export async function updateStaffRoleId(params: {
  schoolId: number;
  idUser: number;
  roleId: number;
}): Promise<{ error: string | null }> {
  const { schoolId, idUser, roleId } = params;
  const { error } = await supabase
    .from('Teachers')
    .update({ id_role: roleId })
    .eq('id_user', idUser)
    .eq('id_school', schoolId);
  return { error: error ? error.message : null };
}

/**
 * บันทึกสิทธิ์การเข้าถึง Web โรงเรียนของบุคลากรรายคน (เปิด/ปิด/ตามบทบาท)
 */
export async function saveStaffWebAccess(params: {
  schoolId: number;
  idUser: number;
  canAccess: boolean | null; // null = ตามบทบาท
}): Promise<{ error: string | null }> {
  const { schoolId, idUser, canAccess } = params;
  const menuId = getUserSchoolWebTabMenuId(idUser);

  if (canAccess === null) {
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
      status: canAccess ? '1' : '0',
      updatedAt: new Date().toISOString(),
    },
    { onConflict: 'id_school,id_role,menu_id' },
  );
  return { error: error ? error.message : null };
}

/** แหล่งที่มาของสิทธิ์ (ใช้แสดงในหน้า "ดูตัวอย่างเมนู" ให้แอดมินตรวจ) */
export type AccessSource =
  | 'admin_tier' // ระดับแอดมินโรงเรียน / ส่วนกลาง
  | 'user_override' // ตั้งค่ารายบุคคล
  | 'staff_mapping' // สังกัดฝ่าย (member / editor)
  | 'not_mapped' // ผูกฝ่ายอื่นไว้ แต่ไม่ได้สังกัดฝ่ายนี้
  | 'role' // ตั้งค่าตามบทบาท
  | 'executive_default' // ผู้บริหารเห็นทุกฝ่าย
  | 'inherit_division' // ระบบงานใช้ระดับเดียวกับฝ่าย
  | 'default_hidden'; // ไม่ได้รับสิทธิ์ (ค่าเริ่มต้น)

export const ACCESS_SOURCE_LABEL: Record<AccessSource, string> = {
  admin_tier: 'ระดับแอดมิน',
  user_override: 'ตั้งรายบุคคล',
  staff_mapping: 'สังกัดฝ่าย',
  not_mapped: 'ไม่ได้สังกัดฝ่ายนี้',
  role: 'ตามบทบาท',
  executive_default: 'ผู้บริหารเห็นทุกฝ่าย',
  inherit_division: 'ตามฝ่าย',
  default_hidden: 'ยังไม่ได้รับสิทธิ์',
};

export interface AccessDecision {
  level: AccessLevel;
  source: AccessSource;
}

/**
 * ตัวตัดสินสิทธิ์ "ฝ่าย" ชุดเดียวของ web (ใช้ทั้งเมนูซ้ายและหน้าตั้งค่า)
 * ลำดับ: แอดมิน → สังกัดฝ่ายรายบุคคล → ตามบทบาท → ผู้บริหารเห็นทุกฝ่าย → ไม่เห็น
 * (เพดานแพ็กเกจกรองไว้แล้วตอนโหลดโครงฝ่าย — mapping.ts)
 * ฐานข้อมูลตัดสินสิทธิ์ "แก้ไข" ลำดับเดียวกันที่ can_edit_school_web
 */
export function resolveDivisionAccess(params: {
  perms: RoleDivisionModulePermissions;
  roleTier: SchoolRoleTier;
  roleId: number | null;
  idUser: number | null;
  divisionKey: string;
  allDivisionKeys: string[];
}): AccessDecision {
  const { perms, roleTier, roleId, idUser, divisionKey, allDivisionKeys } = params;

  if (roleTier === 'super_admin' || roleTier === 'school_admin') {
    return { level: 'edit', source: 'admin_tier' };
  }

  // 1. สังกัดฝ่ายรายบุคคล: ผูกไว้อย่างน้อย 1 ฝ่าย = เห็นเฉพาะฝ่ายที่ผูก
  if (idUser != null) {
    const assignedKeys = getStaffAssignedDivisionKeys(perms, idUser, allDivisionKeys);
    if (assignedKeys.length > 0) {
      const memberRole = getStaffDivisionMemberRole(perms, idUser, divisionKey);
      if (memberRole === 'editor') return { level: 'edit', source: 'staff_mapping' };
      if (memberRole === 'member') return { level: 'view', source: 'staff_mapping' };
      if (roleTier !== 'executive') return { level: 'hidden', source: 'not_mapped' };
      // ผู้บริหารยังเห็นฝ่ายอื่นได้แบบดูอย่างเดียว (ฐานข้อมูลไม่ให้แก้ฝ่ายที่ไม่ได้สังกัด) เว้นแต่บทบาทสั่งปิด
      const execRole =
        roleId != null ? perms.divisionByRole[`${roleId}:${divisionKey}`] : undefined;
      if (execRole && !execRole.can_view) return { level: 'hidden', source: 'role' };
      return { level: 'view', source: 'executive_default' };
    }
  }

  // 2. ตามบทบาท
  const roleEntry =
    roleId != null ? perms.divisionByRole[`${roleId}:${divisionKey}`] : undefined;
  if (roleEntry) {
    if (!roleEntry.can_view) return { level: 'hidden', source: 'role' };
    return { level: roleEntry.can_edit ? 'edit' : 'view', source: 'role' };
  }

  // 3. ผู้บริหารเห็นทุกฝ่าย (ดู / อนุมัติ)
  if (roleTier === 'executive') {
    return { level: 'view', source: 'executive_default' };
  }

  // 4. ค่าเริ่มต้น: ครูที่ไม่ได้สังกัดฝ่าย = ครูผู้สอน ไม่เห็นงานของฝ่าย
  return { level: 'hidden', source: 'default_hidden' };
}

/** ตัวตัดสินสิทธิ์ "ระบบงาน" ภายในฝ่ายที่เห็นแล้ว */
export function resolveModuleAccess(params: {
  perms: RoleDivisionModulePermissions;
  roleTier: SchoolRoleTier;
  roleId: number | null;
  idUser: number | null;
  moduleKey: string;
  division: AccessDecision;
}): AccessDecision {
  const { perms, roleTier, roleId, idUser, moduleKey, division } = params;
  if (roleTier === 'super_admin' || roleTier === 'school_admin') {
    return { level: 'edit', source: 'admin_tier' };
  }

  // 1. รายบุคคล (มาก่อนเสมอ — ตรงกับฐานข้อมูล)
  if (idUser != null) {
    const userMod = perms.moduleByUser[`${idUser}:${moduleKey}`];
    if (userMod) {
      if (!userMod.can_view) return { level: 'hidden', source: 'user_override' };
      return { level: userMod.can_edit ? 'edit' : 'view', source: 'user_override' };
    }
  }

  if (division.level === 'hidden') return division;

  // 2. ตามบทบาท
  const roleMod = roleId != null ? perms.moduleByRole[`${roleId}:${moduleKey}`] : undefined;
  if (roleMod) {
    if (!roleMod.can_view) return { level: 'hidden', source: 'role' };
    // คนที่สังกัดฝ่ายแล้ว สิทธิ์แก้ไขมาจากสังกัดฝ่ายเท่านั้น (ตรงกับ can_edit_school_web)
    const mapped =
      division.source === 'staff_mapping' ||
      division.source === 'not_mapped' ||
      (idUser != null &&
        Object.entries(perms.divisionByUser).some(
          ([k, v]) => k.startsWith(`${idUser}:`) && v.can_view,
        ));
    if (roleMod.can_edit && !mapped) return { level: 'edit', source: 'role' };
    return { level: division.level, source: 'role' };
  }

  // 3. ตามฝ่าย
  return { level: division.level, source: 'inherit_division' };
}

/** คงชื่อเดิมไว้ให้โค้ดที่เรียกอยู่ */
export function resolveEffectiveDivisionAccessForUser(
  params: Parameters<typeof resolveDivisionAccess>[0],
): AccessLevel {
  return resolveDivisionAccess(params).level;
}

export interface DivisionAccessExplain {
  division: DivisionWithModules;
  access: AccessDecision;
  modules: { module: DivisionWithModules['modules'][number]; access: AccessDecision }[];
}

/** คำนวณสิทธิ์ทุกฝ่าย / ระบบงานพร้อมที่มา (ใช้ทั้งเมนูจริงและหน้าดูตัวอย่าง) */
export function explainDivisionAccess(params: {
  divisions: DivisionWithModules[];
  perms: RoleDivisionModulePermissions;
  roleTier: SchoolRoleTier;
  roleId: number | null;
  idUser: number | null;
}): DivisionAccessExplain[] {
  const { divisions, perms, roleTier, roleId, idUser } = params;
  const allDivisionKeys = divisions.map((d) => d.division_key);
  return divisions.map((div) => {
    const access = resolveDivisionAccess({
      perms,
      roleTier,
      roleId,
      idUser,
      divisionKey: div.division_key,
      allDivisionKeys,
    });
    const modules = div.modules
      .filter((m) => m.is_enabled)
      .map((m) => ({
        module: m,
        access: resolveModuleAccess({
          perms,
          roleTier,
          roleId,
          idUser,
          moduleKey: m.module_key,
          division: access,
        }),
      }));
    return { division: div, access, modules };
  });
}

/**
 * กรองโครงสร้างฝ่ายและ Module ของโรงเรียนตามสิทธิ์ของผู้ใช้ (เมนูซ้ายใช้ฟังก์ชันนี้)
 * ฝ่ายที่ไม่มีระบบงานให้เห็นเลยจะถูกซ่อนด้วย
 */
export function filterDivisionsByStaffMapping(params: {
  divisions: DivisionWithModules[];
  perms: RoleDivisionModulePermissions;
  roleTier: SchoolRoleTier;
  roleId: number | null;
  idUser: number | null;
}): {
  visibleDivisions: DivisionWithModules[];
  editableDivisionKeys: Set<string>;
  editableModuleKeys: Set<string>;
} {
  const editableDivisionKeys = new Set<string>();
  const editableModuleKeys = new Set<string>();
  const visibleDivisions: DivisionWithModules[] = [];

  for (const row of explainDivisionAccess(params)) {
    const mods = row.modules.filter((m) => m.access.level !== 'hidden');
    if (row.access.level === 'hidden' && mods.length === 0) continue;
    if (row.access.level === 'edit') editableDivisionKeys.add(row.division.division_key);
    for (const m of mods) {
      if (m.access.level === 'edit') editableModuleKeys.add(m.module.module_key);
    }
    visibleDivisions.push({ ...row.division, modules: mods.map((m) => m.module) });
  }

  return { visibleDivisions, editableDivisionKeys, editableModuleKeys };
}

/**
 * ระดับสิทธิ์ระบบงานของบุคลากร "ถ้าไม่ได้ตั้งรายบุคคล" (ใช้แสดงค่าตั้งต้นในหน้าสิทธิ์รายบุคคล)
 * divisionKeys = ฝ่ายที่ระบบงานนี้อยู่ (ระบบงานที่อยู่ทุกฝ่ายใช้ระดับสูงสุด)
 */
export function resolveInheritedModuleLevel(params: {
  perms: RoleDivisionModulePermissions;
  roleTier: SchoolRoleTier;
  roleId: number | null;
  idUser: number | null;
  moduleKey: string;
  divisionKeys: string[];
  allDivisionKeys: string[];
}): AccessLevel {
  const { moduleKey, divisionKeys, allDivisionKeys, ...rest } = params;
  const perms = { ...rest.perms, moduleByUser: {} };
  const rank: Record<AccessLevel, number> = { hidden: 0, view: 1, edit: 2 };
  let best: AccessLevel = 'hidden';
  for (const divisionKey of divisionKeys) {
    const division = resolveDivisionAccess({ ...rest, perms, divisionKey, allDivisionKeys });
    const lvl = resolveModuleAccess({ ...rest, perms, moduleKey, division }).level;
    if (rank[lvl] > rank[best]) best = lvl;
  }
  return best;
}
