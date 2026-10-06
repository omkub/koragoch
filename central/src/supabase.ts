import { createClient } from '@supabase/supabase-js';

// ค่าชุดเดียวกับแอป Flutter (lib/main.dart) — anon key เป็นค่าสาธารณะ
// สิทธิ์จริงคุมด้วย RLS ในฐานข้อมูล (ผู้ดูแลส่วนกลางเห็นทุกโรงเรียนผ่าน can_see_school)
const SUPABASE_URL = 'https://uziajblqlbrvqmxvizsi.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV6aWFqYmxxbGJydnFteHZpenNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2Njc1MzIsImV4cCI6MjA5OTI0MzUzMn0.cpnt8uctNacuJWNelYx5C_oP0xEPtUhzvNDgyWkg0ZA';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    // แยก session จากแอป Flutter (ต่าง path แต่ localStorage ใช้ร่วมกันทั้งโดเมน)
    storageKey: 'koragoch-central-auth',
  },
});

/** อีเมลสังเคราะห์ — ต้องตรงกับ FirebaseService.authEmailForUsername ในแอป */
export const authEmailForUsername = (username: string) =>
  `${username.trim().toLowerCase()}@leave.local`;

/** Edge Function งานแอดมิน (slug จริงคือ clever-responder) */
export const ADMIN_FUNCTION = 'clever-responder';

export const ADMIN_ROLE_ID = 22;

/** ระดับผู้ใช้เว็บนี้ — super = ผู้ดูแลส่วนกลาง, school = แอดมินโรงเรียน */
export interface Access {
  level: 'super' | 'school' | 'none';
  schoolId: number | null;
}

/** รายการสิทธิ์ (ตาราง PermissionItems) */
export interface PermissionItem {
  key: string;
  group: string;
  label: string;
  sort: number;
}

export interface Role {
  ID_Roles: number;
  Accessrights: string;
}

/** จัดกลุ่มรายการสิทธิ์ตามหมวด เรียงตาม sort */
export function groupItems(items: PermissionItem[]): [string, PermissionItem[]][] {
  const groups = new Map<string, PermissionItem[]>();
  for (const item of [...items].sort((a, b) => a.sort - b.sort)) {
    if (!groups.has(item.group)) groups.set(item.group, []);
    groups.get(item.group)!.push(item);
  }
  return [...groups.entries()];
}

export interface School {
  id_school: number;
  namePart1: string | null;
  namePart2: string | null;
  fullName: string | null;
  address: string | null;
  affiliation: string | null;
  localCode: string | null;
  province: string | null;
  district: string | null;
  subdistrict: string | null;
}

/**
 * ชื่อเต็มของโรงเรียน = namePart1 + namePart2 (เหมือน SchoolRecord ในแอป Flutter)
 * ไม่พึ่งคอลัมน์ fullName เพราะถ้าฐานข้อมูลยังไม่ได้ทำให้เป็นคอลัมน์คำนวณ
 * (schools_fullname_generated.sql) ค่าในนั้นอาจไม่ตรงกับสองท่อน
 */
export const schoolName = (s: Pick<School, 'namePart1' | 'namePart2' | 'fullName'>) =>
  [s.namePart1, s.namePart2].filter((x) => x?.trim()).join(' ') || s.fullName || '-';

/**
 * ประกอบที่อยู่จาก ตำบล / อำเภอ / จังหวัด — ต้องตรงกับ
 * SchoolRecord.composeAddress ในแอป Flutter (lib/utils/school_info.dart)
 */
export function composeAddress(subdistrict = '', district = '', province = ''): string {
  const strip = (value: string, prefix: string) => {
    const v = value.trim();
    return v.startsWith(prefix) ? v.slice(prefix.length).trim() : v;
  };
  const sub = strip(subdistrict, 'ตำบล');
  const prov = strip(province, 'จังหวัด');
  let dist = strip(district, 'อำเภอ');
  if (dist === 'เมือง' && prov) dist = `เมือง${prov}`;
  return [sub && `ตำบล${sub}`, dist && `อำเภอ${dist}`, prov && `จังหวัด${prov}`]
    .filter(Boolean)
    .join(' ');
}

/** ที่อยู่ที่ขึ้นหัวใบลาจริง: ช่อง address ถ้ากรอก ไม่งั้นประกอบจาก ตำบล/อำเภอ/จังหวัด */
export const schoolAddress = (
  s: Pick<School, 'address' | 'subdistrict' | 'district' | 'province'>,
) =>
  s.address?.trim() ||
  composeAddress(s.subdistrict ?? '', s.district ?? '', s.province ?? '');

/** ข้อความ error ที่อ่านรู้เรื่องจาก Edge Function */
export async function functionError(error: unknown): Promise<string> {
  const context = (error as { context?: Response })?.context;
  if (context && typeof context.json === 'function') {
    try {
      const body = await context.json();
      if (body?.error) return String(body.error);
    } catch {
      /* ไม่ใช่ JSON */
    }
  }
  return error instanceof Error ? error.message : String(error);
}
