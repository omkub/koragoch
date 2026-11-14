import { supabase } from '../supabase';

export type DivisionIconName =
  | 'users'
  | 'graduation-cap'
  | 'file-text'
  | 'wallet'
  | 'folder';

export interface ModuleCatalogItem {
  module_key: string;
  title: string;
  description: string | null;
  module_type: 'builtin' | 'external';
  default_division_key: string;
  default_url: string | null;
  sort_order: number;
  is_active: boolean;
}

export interface SchoolDivision {
  id: number;
  id_school: number;
  division_key: string;
  name: string;
  description: string | null;
  icon_name: DivisionIconName;
  sort_order: number;
  is_enabled: boolean;
}

export interface SchoolDivisionModule {
  id: number;
  id_school: number;
  division_id: number;
  module_key: string;
  custom_title: string | null;
  custom_description: string | null;
  external_url: string | null;
  open_mode: 'new_tab' | 'same_tab';
  sort_order: number;
  is_enabled: boolean;
}

export interface ResolvedDivisionModule extends SchoolDivisionModule {
  title: string;
  description: string;
  module_type: 'builtin' | 'external';
  resolved_url: string | null;
}

export interface DivisionWithModules extends SchoolDivision {
  modules: ResolvedDivisionModule[];
}

export const FALLBACK_CATALOG: ModuleCatalogItem[] = [
  {
    module_key: 'leave-system',
    title: 'ระบบวันลาและไปราชการ',
    description: 'เปิดใช้งาน Web ย่อยระบบวันลา/ไปราชการ และตั้งค่าระบบวันลา',
    module_type: 'builtin',
    default_division_key: 'hr',
    default_url: 'https://rbp-chanikarnn.web.app/',
    sort_order: 1,
    is_active: true,
  },
  {
    module_key: 'staff-registry',
    title: 'ทะเบียนบุคลากร',
    description: 'ข้อมูลรายชื่อครู บุคลากร และบทบาทภายในโรงเรียน',
    module_type: 'builtin',
    default_division_key: 'hr',
    default_url: null,
    sort_order: 2,
    is_active: true,
  },
  {
    module_key: 'departments',
    title: 'โครงสร้างฝ่ายและกลุ่มสาระ',
    description: 'จัดการหน่วยงานและกลุ่มสาระการเรียนรู้',
    module_type: 'builtin',
    default_division_key: 'hr',
    default_url: null,
    sort_order: 3,
    is_active: true,
  },
  {
    module_key: 'students-classrooms',
    title: 'ทะเบียนนักเรียนและห้องเรียน',
    description: 'จัดการข้อมูลนักเรียน ห้องเรียน และครูที่ปรึกษา',
    module_type: 'builtin',
    default_division_key: 'academic',
    default_url: null,
    sort_order: 1,
    is_active: true,
  },
  {
    module_key: 'curriculum-schedule',
    title: 'หลักสูตรและตารางสอน',
    description: 'จัดการรายวิชา หน่วยกิต และตารางสอนรายห้อง',
    module_type: 'builtin',
    default_division_key: 'academic',
    default_url: null,
    sort_order: 2,
    is_active: true,
  },
  {
    module_key: 'documents',
    title: 'สารบรรณอิเล็กทรอนิกส์',
    description: 'ทะเบียนหนังสือรับ หนังสือส่ง และบันทึกข้อความ',
    module_type: 'builtin',
    default_division_key: 'admin',
    default_url: null,
    sort_order: 1,
    is_active: true,
  },
  {
    module_key: 'announcements',
    title: 'ประกาศโรงเรียน',
    description: 'จัดการข่าวสารและประกาศประชาสัมพันธ์ภายในโรงเรียน',
    module_type: 'builtin',
    default_division_key: 'admin',
    default_url: null,
    sort_order: 2,
    is_active: true,
  },
  {
    module_key: 'finance-budget',
    title: 'งบประมาณ การเงิน และพัสดุ',
    description: 'ระบบบริหารงบประมาณ การเงิน และครุภัณฑ์ของโรงเรียน',
    module_type: 'builtin',
    default_division_key: 'finance',
    default_url: null,
    sort_order: 1,
    is_active: true,
  },
];

export const FALLBACK_DIVISIONS: Omit<SchoolDivision, 'id_school'>[] = [
  {
    id: -1,
    division_key: 'hr',
    name: 'ฝ่ายบริหารงานบุคคล',
    description: 'งานวันลา ไปราชการ ทะเบียนบุคลากร และโครงสร้างหน่วยงาน',
    icon_name: 'users',
    sort_order: 1,
    is_enabled: true,
  },
  {
    id: -2,
    division_key: 'academic',
    name: 'ฝ่ายวิชาการและกิจการนักเรียน',
    description: 'งานทะเบียนนักเรียน ห้องเรียน หลักสูตร และตารางสอน',
    icon_name: 'graduation-cap',
    sort_order: 2,
    is_enabled: true,
  },
  {
    id: -3,
    division_key: 'admin',
    name: 'ฝ่ายบริหารทั่วไป',
    description: 'งานสารบรรณอิเล็กทรอนิกส์ และประกาศประชาสัมพันธ์',
    icon_name: 'file-text',
    sort_order: 3,
    is_enabled: true,
  },
  {
    id: -4,
    division_key: 'finance',
    name: 'ฝ่ายการเงินและพัสดุ',
    description: 'งานงบประมาณ การเงิน และพัสดุครุภัณฑ์',
    icon_name: 'wallet',
    sort_order: 4,
    is_enabled: true,
  },
];

/**
 * โหลดข้อมูล Mapping (โรงเรียน -> ฝ่าย -> Module ย่อย)
 * หากยังไม่ได้รัน SQL หรือโรงเรียนนั้นยังไม่มีข้อมูลในตาราง จะใช้ค่ามาตรฐานแทนโดยไม่พัง
 */
export async function fetchSchoolDivisionTree(schoolId: number): Promise<{
  catalog: ModuleCatalogItem[];
  divisions: DivisionWithModules[];
  hasDbMapping: boolean;
}> {
  const [catRes, divRes, modRes] = await Promise.all([
    supabase
      .from('SchoolWebModuleCatalog')
      .select('*')
      .eq('is_active', true)
      .order('sort_order', { ascending: true }),
    supabase
      .from('SchoolWebDivisions')
      .select('*')
      .eq('id_school', schoolId)
      .order('sort_order', { ascending: true })
      .order('id', { ascending: true }),
    supabase
      .from('SchoolWebDivisionModules')
      .select('*')
      .eq('id_school', schoolId)
      .order('sort_order', { ascending: true })
      .order('id', { ascending: true }),
  ]);

  const catalog =
    !catRes.error && catRes.data && catRes.data.length > 0
      ? (catRes.data as ModuleCatalogItem[])
      : FALLBACK_CATALOG;

  const catalogMap = new Map<string, ModuleCatalogItem>();
  for (const item of catalog) {
    catalogMap.set(item.module_key, item);
  }

  const dbDivisions =
    !divRes.error && divRes.data ? (divRes.data as SchoolDivision[]) : [];
  const dbModules =
    !modRes.error && modRes.data ? (modRes.data as SchoolDivisionModule[]) : [];

  if (dbDivisions.length > 0) {
    const divisions: DivisionWithModules[] = dbDivisions.map((div) => {
      const rawMods = dbModules.filter((m) => m.division_id === div.id);
      const resolved: ResolvedDivisionModule[] = rawMods.map((m) => {
        const cat = catalogMap.get(m.module_key);
        return {
          ...m,
          title: m.custom_title || cat?.title || m.module_key,
          description: m.custom_description || cat?.description || '',
          module_type: cat?.module_type || 'external',
          resolved_url: m.external_url || cat?.default_url || null,
        };
      });
      return {
        ...div,
        modules: resolved,
      };
    });

    return { catalog, divisions, hasDbMapping: true };
  }

  // Fallback tree when DB has no rows yet
  const fallbackTree: DivisionWithModules[] = FALLBACK_DIVISIONS.map((div) => {
    const defaultMods = catalog.filter(
      (c) => c.default_division_key === div.division_key,
    );
    return {
      ...div,
      id_school: schoolId,
      modules: defaultMods.map((cat, idx) => ({
        id: -(idx + 1),
        id_school: schoolId,
        division_id: div.id,
        module_key: cat.module_key,
        custom_title: null,
        custom_description: null,
        external_url: cat.default_url,
        open_mode: 'new_tab',
        sort_order: cat.sort_order,
        is_enabled: true,
        title: cat.title,
        description: cat.description || '',
        module_type: cat.module_type,
        resolved_url: cat.default_url,
      })),
    };
  });

  return { catalog, divisions: fallbackTree, hasDbMapping: false };
}
