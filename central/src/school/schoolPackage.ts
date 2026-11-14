import { ADMIN_ROLE_ID, supabase } from '../supabase';

/**
 * รหัส menu_id พิเศษในตาราง Permissions (ใช้คู่กับ id_role = ADMIN_ROLE_ID = 22)
 * สำหรับเก็บ "สิทธิ์ระดับโรงเรียน (School Package & Allowed Modules)" ที่กำหนดโดย Super Admin
 * โดยไม่ต้องสร้างตาราง SQL ใหม่ และผ่าน RLS ของตาราง Permissions ได้ทันทีทุกโรงเรียน
 */
export const SCHOOL_WEB_ENABLED_MENU_ID = -100;

export const SCHOOL_DIVISION_MENU_IDS: Record<string, number> = {
  hr: -121,
  academic: -122,
  admin: -123,
  finance: -124,
};

export const SCHOOL_MODULE_MENU_IDS: Record<string, number> = {
  'leave-system': -101,
  'staff-registry': -102,
  departments: -103,
  'students-classrooms': -104,
  'curriculum-schedule': -105,
  documents: -106,
  announcements: -107,
  'finance-budget': -108,
  'appointment-orders': -109,
};

export interface SchoolPackageItemMeta {
  key: string;
  menuId: number;
  title: string;
  description: string;
  divisionKey: string;
}

export const SCHOOL_DIVISION_META: {
  key: string;
  menuId: number;
  title: string;
  description: string;
}[] = [
  {
    key: 'hr',
    menuId: -121,
    title: 'ฝ่ายบริหารงานบุคคล',
    description: 'งานวันลา ไปราชการ ทะเบียนบุคลากร โครงสร้างหน่วยงาน และคำสั่งแต่งตั้ง',
  },
  {
    key: 'academic',
    menuId: -122,
    title: 'ฝ่ายวิชาการและกิจการนักเรียน',
    description: 'งานทะเบียนนักเรียน ห้องเรียน หลักสูตร และตารางสอน',
  },
  {
    key: 'admin',
    menuId: -123,
    title: 'ฝ่ายบริหารทั่วไป',
    description: 'งานสารบรรณอิเล็กทรอนิกส์ และประกาศประชาสัมพันธ์',
  },
  {
    key: 'finance',
    menuId: -124,
    title: 'ฝ่ายการเงินและพัสดุ',
    description: 'งานงบประมาณ การเงิน และพัสดุครุภัณฑ์',
  },
];

export const SCHOOL_MODULE_META: SchoolPackageItemMeta[] = [
  {
    key: 'leave-system',
    menuId: -101,
    title: 'ระบบวันลาและไปราชการ (Web ย่อย)',
    description: 'เปิดใช้งานเชื่อมต่อไปยัง Web ย่อยระบบวันลาและไปราชการ',
    divisionKey: 'hr',
  },
  {
    key: 'staff-registry',
    menuId: -102,
    title: 'ทะเบียนบุคลากร',
    description: 'ข้อมูลรายชื่อครู บุคลากร และบทบาทภายในโรงเรียน',
    divisionKey: 'hr',
  },
  {
    key: 'departments',
    menuId: -103,
    title: 'โครงสร้างฝ่ายและกลุ่มสาระ',
    description: 'จัดการหน่วยงานและกลุ่มสาระการเรียนรู้',
    divisionKey: 'hr',
  },
  {
    key: 'appointment-orders',
    menuId: -109,
    title: 'คำสั่งแต่งตั้ง (ส่งออกไฟล์ Word)',
    description: 'จัดทำคำสั่งแต่งตั้งคณะทำงาน แสดงตัวอย่าง A4 และดาวน์โหลด .docx',
    divisionKey: 'all',
  },
  {
    key: 'students-classrooms',
    menuId: -104,
    title: 'ทะเบียนนักเรียนและห้องเรียน',
    description: 'จัดการข้อมูลนักเรียน ห้องเรียน และครูที่ปรึกษา',
    divisionKey: 'academic',
  },
  {
    key: 'curriculum-schedule',
    menuId: -105,
    title: 'หลักสูตรและตารางสอน',
    description: 'จัดการรายวิชา หน่วยกิต และตารางสอนรายห้อง',
    divisionKey: 'academic',
  },
  {
    key: 'documents',
    menuId: -106,
    title: 'สารบรรณอิเล็กทรอนิกส์',
    description: 'ทะเบียนหนังสือรับ หนังสือส่ง และบันทึกข้อความ',
    divisionKey: 'admin',
  },
  {
    key: 'announcements',
    menuId: -107,
    title: 'ประกาศโรงเรียน',
    description: 'จัดการข่าวสารและประกาศประชาสัมพันธ์ภายในโรงเรียน',
    divisionKey: 'admin',
  },
  {
    key: 'finance-budget',
    menuId: -108,
    title: 'งบประมาณ การเงิน และพัสดุ',
    description: 'ระบบบริหารงบประมาณ การเงิน และครุภัณฑ์ของโรงเรียน',
    divisionKey: 'finance',
  },
];

export interface SchoolPackageConfig {
  schoolId: number;
  /** เปิดให้โรงเรียนนี้ใช้งาน "เว็บโรงเรียน (/central/)" หรือไม่ (หากปิด = ใช้ได้เฉพาะ Web ย่อยระบบวันลา) */
  schoolWebEnabled: boolean;
  /** ฝ่ายงานที่อนุญาตให้โรงเรียนนี้มองเห็น */
  allowedDivisions: Record<string, boolean>;
  /** Module ย่อยที่อนุญาตให้โรงเรียนนี้มองเห็น */
  allowedModules: Record<string, boolean>;
}

function isStatusOn(status: unknown): boolean {
  return (
    status === true ||
    status === 1 ||
    String(status).trim() === '1' ||
    String(status).toUpperCase() === 'TRUE'
  );
}

export function createDefaultSchoolPackageConfig(
  schoolId: number,
): SchoolPackageConfig {
  const allowedDivisions: Record<string, boolean> = {};
  for (const d of SCHOOL_DIVISION_META) {
    allowedDivisions[d.key] = true;
  }
  const allowedModules: Record<string, boolean> = {};
  for (const m of SCHOOL_MODULE_META) {
    allowedModules[m.key] = true;
  }
  return {
    schoolId,
    schoolWebEnabled: true,
    allowedDivisions,
    allowedModules,
  };
}

export async function fetchSchoolPackageConfig(
  schoolId: number,
): Promise<SchoolPackageConfig> {
  const config = createDefaultSchoolPackageConfig(schoolId);
  try {
    const allMenuIds = [
      SCHOOL_WEB_ENABLED_MENU_ID,
      ...Object.values(SCHOOL_DIVISION_MENU_IDS),
      ...Object.values(SCHOOL_MODULE_MENU_IDS),
    ];

    const { data, error } = await supabase
      .from('Permissions')
      .select('menu_id, status')
      .eq('id_school', schoolId)
      .eq('id_role', ADMIN_ROLE_ID)
      .in('menu_id', allMenuIds);

    if (error || !data) return config;

    const statusByMenuId = new Map<number, boolean>();
    for (const row of data as { menu_id: number; status: unknown }[]) {
      statusByMenuId.set(Number(row.menu_id), isStatusOn(row.status));
    }

    if (statusByMenuId.has(SCHOOL_WEB_ENABLED_MENU_ID)) {
      config.schoolWebEnabled =
        statusByMenuId.get(SCHOOL_WEB_ENABLED_MENU_ID) ?? true;
    }

    for (const [divKey, menuId] of Object.entries(SCHOOL_DIVISION_MENU_IDS)) {
      if (statusByMenuId.has(menuId)) {
        config.allowedDivisions[divKey] = statusByMenuId.get(menuId) ?? true;
      }
    }

    for (const [modKey, menuId] of Object.entries(SCHOOL_MODULE_MENU_IDS)) {
      if (statusByMenuId.has(menuId)) {
        config.allowedModules[modKey] = statusByMenuId.get(menuId) ?? true;
      }
    }
  } catch {
    /* fallback to default all-enabled */
  }
  return config;
}

export async function saveSchoolPackageEntries(
  schoolId: number,
  entries: { menuId: number; enabled: boolean }[],
): Promise<{ error: string | null }> {
  if (entries.length === 0) return { error: null };
  const now = new Date().toISOString();
  const rows = entries.map((item) => ({
    id_school: schoolId,
    id_role: ADMIN_ROLE_ID,
    menu_id: item.menuId,
    status: item.enabled ? '1' : '0',
    updatedAt: now,
  }));

  const { error } = await supabase
    .from('Permissions')
    .upsert(rows, { onConflict: 'id_school,id_role,menu_id' });

  return { error: error ? error.message : null };
}

/** ตรวจสอบว่าฝ่ายงานนี้ได้รับอนุญาตในระดับโรงเรียนหรือไม่ */
export function isDivisionAllowedForSchool(
  pkg: SchoolPackageConfig | null | undefined,
  divisionKey: string,
): boolean {
  if (!pkg) return true;
  if (divisionKey in pkg.allowedDivisions) {
    return pkg.allowedDivisions[divisionKey] !== false;
  }
  return true;
}

/** ตรวจสอบว่า Module ย่อยนี้ได้รับอนุญาตในระดับโรงเรียนหรือไม่ */
export function isModuleAllowedForSchool(
  pkg: SchoolPackageConfig | null | undefined,
  moduleKey: string,
): boolean {
  if (!pkg) return true;
  if (moduleKey in pkg.allowedModules) {
    return pkg.allowedModules[moduleKey] !== false;
  }
  return true;
}
