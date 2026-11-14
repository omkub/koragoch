import { ADMIN_ROLE_ID, supabase } from '../supabase';
import type { DivisionWithModules } from './mapping';
import {
  getUserDivisionEditMenuId,
  getUserDivisionViewMenuId,
  getUserSchoolWebTabMenuId,
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

/** รายการ Tab เมนูหลักที่ใช้ควบคุมสิทธิ์เมื่อเข้าใช้งานได้แล้ว */
export const SYSTEM_TABS: TabPermissionItem[] = [
  {
    menuId: 6,
    key: 'school_web',
    label: 'แท็บเว็บโรงเรียน (School Web)',
    description: 'เข้าใช้งานหน้าเว็บโรงเรียน 4 ฝ่าย คำสั่งแต่งตั้ง และระบบบริหารงานโรงเรียน',
  },
  {
    menuId: 1,
    key: 'leave_home',
    label: 'แท็บหน้าหลัก / ยื่นใบลา',
    description: 'หน้ายื่นใบลา ดูสถานะใบลา และปฏิทินการลาของตนเอง',
  },
  {
    menuId: 4,
    key: 'executive_overview',
    label: 'แท็บภาพรวมผู้บริหาร / การอนุมัติ',
    description: 'หน้าพิจารณาอนุมัติใบลาและดูสรุปภาพรวมสำหรับผู้บริหาร',
  },
  {
    menuId: 2,
    key: 'reports',
    label: 'แท็บรายงานและสถิติ',
    description: 'ดูรายงานสรุปวันลา สถิติบุคลากร และพิมพ์เอกสารรายงาน',
  },
  {
    menuId: 3,
    key: 'staff_manage',
    label: 'แท็บจัดการบุคลากรและผู้ใช้',
    description: 'เพิ่ม/แก้ไขข้อมูลบุคลากร รหัสผ่าน และโครงสร้างผู้ใช้งาน',
  },
  {
    menuId: 5,
    key: 'system_settings',
    label: 'แท็บตั้งค่าระบบ',
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
    description: 'มองเห็นเฉพาะฝ่ายที่ตัวเองสังกัด และใช้งาน Module ตามฝ่ายของตัวเอง',
    badgeClass: 'bg-slate-100 text-slate-700 ring-1 ring-inset ring-slate-200',
  },
  executive: {
    label: 'ผู้บริหาร (ผอ./รอง ผอ.)',
    shortLabel: 'ผู้บริหาร',
    description: 'มองเห็นข้อมูลครบทุกฝ่ายของโรงเรียน เพื่อดูรายงานและพิจารณาอนุมัติ',
    badgeClass: 'bg-amber-50 text-amber-800 ring-1 ring-inset ring-amber-200',
  },
  school_admin: {
    label: 'Admin โรงเรียน',
    shortLabel: 'Admin โรงเรียน',
    description: 'เข้าถึงและแก้ไขได้ทุกฝ่าย/ทุก Module ในโรงเรียน และจัดบุคลากรเข้าฝ่ายได้',
    badgeClass: 'bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-200',
  },
  super_admin: {
    label: 'Super Admin (ส่วนกลาง)',
    shortLabel: 'Super Admin',
    description: 'ดูแลทุกโรงเรียน เปิด/ปิด Web โรงเรียน และกำหนด Module ที่แต่ละโรงเรียนใช้ได้',
    badgeClass: 'bg-brand-50 text-brand-700 ring-1 ring-inset ring-brand-200',
  },
};

/**
 * แปลงชื่อบทบาท (roles.Accessrights) และสถานะ is_super_admin ให้เป็นระดับสิทธิ์ 4 ระดับ
 */
export function inferRoleTierFromRoleName(
  roleName: string | null | undefined,
  isSuperAdmin = false,
): SchoolRoleTier {
  if (isSuperAdmin) return 'super_admin';
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

/**
 * คำนวณสิทธิ์การมองเห็นและแก้ไขของ "ฝ่ายงาน" สำหรับผู้ใช้ปัจจุบัน
 * ตามแนวคิดใหม่:
 * 1) Super Admin / Admin โรงเรียน -> เห็นทุกฝ่าย และแก้ไขได้ทุกฝ่าย ('edit')
 * 2) ผู้บริหาร (Executive) -> เห็นทุกฝ่าย ('view' หรือ 'edit' หากเป็นเจ้าหน้าที่ฝ่ายนั้นด้วย)
 * 3) ผู้ใช้งาน (User) ->
 *    - หากบุคลากรคนนี้ถูก Map เข้ากับฝ่ายไว้แล้ว: จะเห็นเฉพาะฝ่ายที่ตัวเองสังกัดเท่านั้น!
 *      ('member' -> 'view', 'editor' -> 'edit', ไม่ได้สังกัด -> 'hidden')
 *    - หากบุคลากรคนนี้ยังไม่ได้ถูก Map เข้ากับฝ่ายใดเลย: ใช้ค่าเริ่มต้นตามบทบาท (Role)
 */
export function resolveEffectiveDivisionAccessForUser(params: {
  perms: RoleDivisionModulePermissions;
  roleTier: SchoolRoleTier;
  roleId: number | null;
  idUser: number | null;
  divisionKey: string;
  allDivisionKeys: string[];
}): AccessLevel {
  const { perms, roleTier, roleId, idUser, divisionKey, allDivisionKeys } = params;

  if (roleTier === 'super_admin' || roleTier === 'school_admin') {
    return 'edit';
  }

  if (roleTier === 'executive') {
    if (idUser != null) {
      const memberRole = getStaffDivisionMemberRole(perms, idUser, divisionKey);
      if (memberRole === 'editor') return 'edit';
    }
    const roleEntry =
      roleId != null ? perms.divisionByRole[`${roleId}:${divisionKey}`] : undefined;
    if (roleEntry?.can_edit) return 'edit';
    return 'view';
  }

  // กรณีเป็น "ผู้ใช้งาน (user)"
  if (idUser != null) {
    const assignedKeys = getStaffAssignedDivisionKeys(
      perms,
      idUser,
      allDivisionKeys,
    );
    // ถ้าผู้ใช้คนนี้ถูก Map สังกัดฝ่ายไว้ (อย่างน้อย 1 ฝ่าย) -> ให้เห็นเฉพาะฝ่ายที่ตัวเองอยู่!
    if (assignedKeys.length > 0) {
      const memberRole = getStaffDivisionMemberRole(perms, idUser, divisionKey);
      if (memberRole === 'editor') return 'edit';
      if (memberRole === 'member') return 'view';
      return 'hidden';
    }
  }

  // Fallback กรณียังไม่ได้ Map สังกัดฝ่ายรายบุคคล: ใช้ค่าตาม Role
  if (roleId != null) {
    const roleEntry = perms.divisionByRole[`${roleId}:${divisionKey}`];
    if (roleEntry) {
      if (!roleEntry.can_view) return 'hidden';
      return roleEntry.can_edit ? 'edit' : 'view';
    }
  }
  return 'view';
}

/**
 * กรองโครงสร้างฝ่ายและ Module ของโรงเรียนตามสังกัดฝ่ายและระดับสิทธิ์ของผู้ใช้
 * - Module ผูกกับฝ่ายอยู่แล้ว -> เมื่อบุคลากรเห็นฝ่ายไหน ก็จะเห็น Module ตามฝ่ายตัวเองโดยอัตโนมัติ
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
  const { divisions, perms, roleTier, roleId, idUser } = params;
  const allDivisionKeys = divisions.map((d) => d.division_key);
  const editableDivisionKeys = new Set<string>();
  const editableModuleKeys = new Set<string>();

  const visibleDivisions = divisions
    .map((div) => {
      const divAccess = resolveEffectiveDivisionAccessForUser({
        perms,
        roleTier,
        roleId,
        idUser,
        divisionKey: div.division_key,
        allDivisionKeys,
      });

      if (divAccess === 'hidden') return null;
      if (divAccess === 'edit') {
        editableDivisionKeys.add(div.division_key);
      }

      // Module ที่ผูกกับฝ่ายนี้จะแสดงตามฝ่ายโดยอัตโนมัติ (ยกเว้นถูกสั่งซ่อนเฉพาะกิจ)
      const visibleModules = div.modules.filter((mod) => {
        if (!mod.is_enabled) return false;
        if (roleTier === 'super_admin' || roleTier === 'school_admin') {
          editableModuleKeys.add(mod.module_key);
          return true;
        }

        // ตรวจการตั้งค่าเฉพาะรายบุคคล (ถ้ามี)
        if (idUser != null) {
          const userMod = perms.moduleByUser[`${idUser}:${mod.module_key}`];
          if (userMod) {
            if (!userMod.can_view) return false;
            if (userMod.can_edit) editableModuleKeys.add(mod.module_key);
            return true;
          }
        }

        // ถ้ามีสิทธิ์แก้ไขระดับฝ่าย (เช่น เป็นเจ้าหน้าที่ประจำฝ่าย) -> แก้ไข Module ในฝ่ายตัวเองได้ทันที
        if (divAccess === 'edit') {
          editableModuleKeys.add(mod.module_key);
        }
        return true;
      });

      return {
        ...div,
        modules: visibleModules,
      };
    })
    .filter((d): d is DivisionWithModules => d !== null);

  return {
    visibleDivisions,
    editableDivisionKeys,
    editableModuleKeys,
  };
}
