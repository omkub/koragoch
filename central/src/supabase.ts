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
  /** ว่าง = สิทธิ์หลักใช้ทุกโรงเรียน / มีค่า = สิทธิ์ที่โรงเรียนนั้นเพิ่มเอง (roles_per_school.sql) */
  id_school?: number | null;
}

/** สิทธิ์ที่โรงเรียนนี้ใช้ได้: สิทธิ์หลัก + สิทธิ์ของโรงเรียนนั้น */
export function rolesForSchool(roles: Role[], schoolId: number | null): Role[] {
  return roles.filter((r) => r.id_school == null || r.id_school === schoolId);
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
  /** หน้าจอแอปบนมือถือ — ไม่มีคอลัมน์ (ยังไม่รัน school_mobile_ui.sql) = แบบใหม่ */
  mobile_ui?: MobileUi | null;
  /** หน้าจอมือถือรายสิทธิ์ { ID_Roles: new|old } ไม่มีคีย์ = ตามโรงเรียน */
  mobile_ui_by_role?: Record<string, MobileUi> | null;
  /** โลโก้โรงเรียน (data URL ≤ 256×256) — ไม่มีคอลัมน์ = ยังไม่รัน school_logo.sql */
  logo?: string | null;
}

/** new = แบบแอป (แถบล่าง 4 ปุ่ม), old = แบบเดิม (แถบล่าง 9 ปุ่ม) */
export type MobileUi = 'new' | 'old';

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


const FLUTTER_SUPABASE_STORAGE_KEY = 'sb-uziajblqlbrvqmxvizsi-auth-token';
const EMBEDDED_SESSION_KEY = 'koragoch-school-web-embedded';
const LOCKED_SCHOOL_SESSION_KEY = 'koragoch-school-web-school-id';

function parseTokensFromRawJson(raw: string | null): {
  access_token: string;
  refresh_token: string;
} | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    if (
      typeof parsed.access_token === 'string' &&
      typeof parsed.refresh_token === 'string'
    ) {
      return {
        access_token: parsed.access_token,
        refresh_token: parsed.refresh_token,
      };
    }
    const current = parsed.currentSession as Record<string, unknown> | undefined;
    if (
      current &&
      typeof current.access_token === 'string' &&
      typeof current.refresh_token === 'string'
    ) {
      return {
        access_token: current.access_token,
        refresh_token: current.refresh_token,
      };
    }
  } catch {
    /* ignore malformed storage */
  }
  return null;
}

/**
 * เชื่อม Session อัตโนมัติจากแอประบบวันลา (Single Sign-On)
 * 1) อ่าน sso_access_token / sso_refresh_token จาก URL hash หรือ query (เมื่อคลิกมาจากแท็บแอปวันลา)
 * 2) หากไม่มีใน URL ให้ตรวจ Session ของแอปวันลาใน localStorage บนโดเมนเดียวกัน
 */
export async function hydrateSsoSession(): Promise<void> {
  if (typeof window === 'undefined') return;

  try {
    const searchParams = new URLSearchParams(window.location.search);
    const rawHash = window.location.hash.startsWith('#')
      ? window.location.hash.slice(1)
      : window.location.hash;
    const isRouteHash = rawHash.startsWith('/');
    const hashParams = isRouteHash
      ? new URLSearchParams()
      : new URLSearchParams(rawHash);

    if (searchParams.get('embedded') === '1') {
      sessionStorage.setItem(EMBEDDED_SESSION_KEY, '1');
    } else if (searchParams.get('embedded') === '0') {
      sessionStorage.removeItem(EMBEDDED_SESSION_KEY);
    }

    const urlSchoolId = searchParams.get('school_id');
    if (urlSchoolId && /^\d+$/.test(urlSchoolId)) {
      sessionStorage.setItem(LOCKED_SCHOOL_SESSION_KEY, urlSchoolId);
    }

    const ssoAccess =
      hashParams.get('sso_access_token') || searchParams.get('sso_access_token');
    const ssoRefresh =
      hashParams.get('sso_refresh_token') ||
      searchParams.get('sso_refresh_token');

    if (ssoAccess && ssoRefresh) {
      await supabase.auth.setSession({
        access_token: ssoAccess,
        refresh_token: ssoRefresh,
      });

      hashParams.delete('sso_access_token');
      hashParams.delete('sso_refresh_token');
      searchParams.delete('sso_access_token');
      searchParams.delete('sso_refresh_token');

      const nextSearch = searchParams.toString();
      const nextHash = isRouteHash ? rawHash : hashParams.toString();
      const cleanUrl =
        window.location.pathname +
        (nextSearch ? `?${nextSearch}` : '') +
        (nextHash ? `#${nextHash}` : '');
      window.history.replaceState({}, document.title, cleanUrl);
      return;
    }

    const {
      data: { session: existingSession },
    } = await supabase.auth.getSession();

    const flutterTokens = parseTokensFromRawJson(
      window.localStorage.getItem(FLUTTER_SUPABASE_STORAGE_KEY),
    );

    if (flutterTokens && !existingSession) {
      await supabase.auth.setSession(flutterTokens);
    }
  } catch {
    /* หากซิงก์ไม่สำเร็จ จะแสดงหน้าล็อกอินตามปกติ */
  }
}

/** ตรวจสอบว่าเว็บโรงเรียนกำลังเปิดแบบฝังอยู่ในแท็บของแอประบบวันลาหรือไม่ */
export function isEmbeddedInLeaveApp(): boolean {
  if (typeof window === 'undefined') return false;
  const searchParams = new URLSearchParams(window.location.search);
  if (searchParams.get('embedded') === '1') return true;
  if (searchParams.get('embedded') === '0') return false;
  return sessionStorage.getItem(EMBEDDED_SESSION_KEY) === '1';
}

/** ดึงรหัสโรงเรียนที่ส่งมาจากแอประบบวันลา (ถ้ามี) */
export function getTargetSchoolIdFromLeaveApp(): number | null {
  if (typeof window === 'undefined') return null;
  const searchParams = new URLSearchParams(window.location.search);
  const raw =
    searchParams.get('school_id') ||
    sessionStorage.getItem(LOCKED_SCHOOL_SESSION_KEY);
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  return Number.isNaN(parsed) ? null : parsed;
}


/**
 * ซิงก์ Session ขากลับจากเว็บโรงเรียน (/central/) ไปยังแอประบบวันลา (Flutter Web)
 * เพื่อให้เมื่อกดปุ่ม "เปิด Web ย่อยระบบวันลา" หรือ "กลับระบบวันลา" สามารถเข้าใช้งานได้ทันทีโดยไม่ติดหน้า Login
 */
export function syncSessionToLeaveApp(
  session: { access_token: string; refresh_token: string } | null,
  userProfile?: { fullName?: string; roleName?: string },
): void {
  if (typeof window === 'undefined' || !session) return;
  try {
    // 1) ซิงก์คีย์ของ supabase_flutter บนโดเมนเดียวกัน
    const existingRaw = window.localStorage.getItem(FLUTTER_SUPABASE_STORAGE_KEY);
    if (!existingRaw) {
      window.localStorage.setItem(
        FLUTTER_SUPABASE_STORAGE_KEY,
        JSON.stringify(session),
      );
    }

    // 2) ตั้งค่าสถานะการล็อกอินเบื้องต้นใน SharedPreferences ของ Flutter Web (คีย์ขึ้นต้นด้วย flutter.)
    window.localStorage.setItem('flutter.isLoggedIn', 'true');
    window.localStorage.setItem('flutter.loginAt', String(Date.now()));
    if (userProfile?.fullName) {
      window.localStorage.setItem(
        'flutter.currentUser',
        JSON.stringify(userProfile.fullName),
      );
    }
    if (userProfile?.roleName) {
      window.localStorage.setItem(
        'flutter.userRole',
        JSON.stringify(userProfile.roleName),
      );
    }
  } catch {
    /* ignore storage errors */
  }
}

/**
 * ล้าง Session ทั้งฝั่งเว็บโรงเรียนและฝั่งแอประบบวันลาเมื่อกดออกจากระบบ
 */
export function clearAllSsoSessions(): void {
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.removeItem(FLUTTER_SUPABASE_STORAGE_KEY);
    window.localStorage.removeItem('koragoch-central-auth');
    window.localStorage.removeItem('flutter.isLoggedIn');
    window.localStorage.removeItem('flutter.loginAt');
    window.localStorage.removeItem('flutter.currentUser');
    window.localStorage.removeItem('flutter.userRole');
    window.localStorage.removeItem('flutter.userFullDataJson');
  } catch {
    /* ignore */
  }
}

/**
 * สลับไปยังหน้าระบบวันลาในแท็บเบราว์เซอร์เดิม (ไม่เด้งเปิดแท็บใหม่) พร้อมส่งต่อ Session อัตโนมัติ
 */
export async function navigateToLeaveApp(customUrl?: string): Promise<void> {
  if (typeof window === 'undefined') return;

  try {
    const {
      data: { session },
    } = await supabase.auth.getSession();

    if (session) {
      syncSessionToLeaveApp(session);
    }

    // หากอยู่บนโดเมนจริง (หรือไม่ได้ระบุ URL นอกโดเมน) ให้สลับไปที่ราก (/) ของโดเมนปัจจุบัน
    let baseTarget = `${window.location.origin}/`;
    if (
      customUrl &&
      customUrl.startsWith('http') &&
      !customUrl.includes('rbp-chanikarnn.web.app')
    ) {
      baseTarget = customUrl;
    }

    let finalUrl = baseTarget;
    if (session?.access_token && session?.refresh_token) {
      const sep = baseTarget.includes('?') ? '&' : '?';
      finalUrl = `${baseTarget}${sep}sso_access_token=${encodeURIComponent(
        session.access_token,
      )}&sso_refresh_token=${encodeURIComponent(session.refresh_token)}`;
    }

    // สลับหน้าในแท็บเดิม (หากอยู่ใน iframe ของระบบวันลาอยู่แล้ว ให้สั่งหน้าต่างหลัก)
    if (window.top && window.top !== window.self) {
      window.top.location.href = finalUrl;
    } else {
      window.location.href = finalUrl;
    }
  } catch {
    window.location.href = '/';
  }
}
