export interface OrderMemberDraft {
  id?: number;
  member_no: number;
  id_user: number | null;
  full_name: string;
  admin_position?: string;
  academic_standing?: string;
  official_position: string;
  working_role: string;
}

/**
 * ชนิดของหัวข้อในคำสั่ง (ตามไฟล์ต้นฉบับคำสั่งแต่งตั้งของโรงเรียน)
 * - section   : หัวข้อกลุ่ม เช่น "กลุ่มบริหารวิชาการ" — ตัวหนากึ่งกลาง ไม่มีเลข เริ่มนับเลขข้อใหม่
 * - committee : คณะ/งาน + ตารางรายชื่อ + ให้มีหน้าที่ เช่น "๑. งานพัฒนาหลักสูตร ประกอบด้วย"
 * - person    : รายบุคคล "ชื่อ ⇥ ตำแหน่ง(หัวข้อ)" + "ให้มีหน้าที่รับผิดชอบในขอบข่ายต่อไปนี้" (ไม่มีตาราง)
 */
export type OrderGroupKind = 'section' | 'committee' | 'person';

export interface OrderGroupDraft {
  id?: number;
  group_no: number;
  group_title: string;
  duties: string[];
  members: OrderMemberDraft[];
  /** ไม่ระบุ = committee (ข้อมูลเดิมก่อนมีคอลัมน์ kind) */
  kind?: OrderGroupKind;
  /** 1 = ข้อหลัก (๖.) · 2 = ข้อย่อย (๖.๑) */
  level?: 1 | 2;
  /** แสดงเลขข้อหรือไม่ (เช่น "คณะกรรมการอำนวยการ" ไม่มีเลข) */
  numbered?: boolean;
}

export const GROUP_KIND_LABELS: Record<OrderGroupKind, string> = {
  section: 'หัวข้อกลุ่ม (กึ่งกลาง ไม่มีรายชื่อ)',
  committee: 'คณะ / งาน (ตารางรายชื่อ)',
  person: 'รายบุคคล (ชื่อ + ตำแหน่ง + หน้าที่)',
};

export const groupKind = (g: OrderGroupDraft): OrderGroupKind => g.kind ?? 'committee';
export const groupLevel = (g: OrderGroupDraft): 1 | 2 => (g.level === 2 ? 2 : 1);
export const groupNumbered = (g: OrderGroupDraft): boolean =>
  groupKind(g) === 'section' ? false : g.numbered ?? groupKind(g) === 'committee';

/**
 * เลขข้อของทุกหัวข้อ (ใช้ร่วมกันทั้งฟอร์ม / ตัวอย่างกระดาษ / พิมพ์ / .docx)
 * - นับข้อหลักใหม่ทุกครั้งที่เจอหัวข้อกลุ่ม (section)
 * - ข้อหลัก = "๖."  ข้อย่อย = "๖.๑" (ต่อจากข้อหลักล่าสุด)
 * - หัวข้อที่ไม่แสดงเลข / หัวข้อกลุ่ม = ''
 */
export function computeHeadingLabels(
  groups: OrderGroupDraft[],
  useThaiDigits: boolean,
): string[] {
  let main = 0;
  let sub = 0;
  return groups.map((g) => {
    if (groupKind(g) === 'section') {
      main = 0;
      sub = 0;
      return '';
    }
    if (!groupNumbered(g)) return '';
    if (groupLevel(g) === 2) {
      sub++;
      return `${formatDigits(Math.max(main, 1), useThaiDigits)}.${formatDigits(sub, useThaiDigits)}`;
    }
    main++;
    sub = 0;
    return `${formatDigits(main, useThaiDigits)}.`;
  });
}

/** หัวข้อรายบุคคล: บรรทัดชื่อ ⇥ ตำแหน่ง (ใช้สมาชิกคนแรก ถ้าไม่มีใช้หัวข้ออย่างเดียว) */
export function personHeading(g: OrderGroupDraft): { name: string; title: string } {
  const m = g.members[0];
  return { name: m?.full_name.trim() ?? '', title: g.group_title.trim() };
}

export const PERSON_DUTY_INTRO = 'ให้มีหน้าที่รับผิดชอบในขอบข่ายต่อไปนี้';

export interface AppointmentOrderRecord {
  id: number;
  id_school: number;
  division_id: number | null;
  division_key: string;
  order_no: string;
  order_year: number;
  subject: string;
  preamble: string;
  effective_text: string;
  order_date: string;
  signer_name: string;
  signer_title: string;
  /** ลงนามหน้าแรก แล้วตามด้วยรายละเอียดแนบท้าย (แบบคำสั่งแต่งตั้งประจำภาคเรียน) */
  sign_first?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface AppointmentOrderFull extends AppointmentOrderRecord {
  groups: OrderGroupDraft[];
  emblem_data_url?: string;
  emblem_height_cm?: number;
}

const EMBLEM_STORAGE_PREFIX = 'school-order-emblem-v1-';

export function getSavedSchoolEmblem(schoolId: number | null): {
  dataUrl: string;
  heightCm: number;
} {
  if (!schoolId) return { dataUrl: '', heightCm: 3.0 };
  try {
    const raw = localStorage.getItem(`${EMBLEM_STORAGE_PREFIX}${schoolId}`);
    if (!raw) return { dataUrl: '', heightCm: 3.0 };
    const parsed = JSON.parse(raw) as { dataUrl?: string; heightCm?: number };
    return {
      dataUrl: parsed.dataUrl || '',
      heightCm: parsed.heightCm || 3.0,
    };
  } catch {
    return { dataUrl: '', heightCm: 3.0 };
  }
}

export function saveSchoolEmblem(
  schoolId: number | null,
  dataUrl: string,
  heightCm = 3.0,
): void {
  if (!schoolId) return;
  try {
    localStorage.setItem(
      `${EMBLEM_STORAGE_PREFIX}${schoolId}`,
      JSON.stringify({ dataUrl, heightCm }),
    );
  } catch {
    /* ignore storage quota errors */
  }
}

/**
 * แปลงไฟล์รูปที่อัปโหลด (PNG/JPG/WEBP) ให้เป็น PNG Data URL ขนาดพอเหมาะสำหรับแสดงและฝังใน .docx
 */
export function fileToPngDataUrl(
  file: File,
  maxSide = 480,
): Promise<{ dataUrl: string; width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('อ่านไฟล์รูปไม่สำเร็จ'));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error('รูปแบบไฟล์ภาพไม่ถูกต้อง'));
      img.onload = () => {
        let w = img.naturalWidth || 240;
        let h = img.naturalHeight || 240;
        if (w > maxSide || h > maxSide) {
          if (w >= h) {
            h = Math.round((h * maxSide) / w);
            w = maxSide;
          } else {
            w = Math.round((w * maxSide) / h);
            h = maxSide;
          }
        }
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('ไม่สามารถประมวลผลภาพได้'));
          return;
        }
        ctx.drawImage(img, 0, 0, w, h);
        resolve({
          dataUrl: canvas.toDataURL('image/png'),
          width: w,
          height: h,
        });
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}

export interface DigitFormatSettings {
  header: boolean;       // เลขที่คำสั่ง (ที่ ... / ...) และชื่อเรื่อง
  preamble: boolean;     // ข้อความเกริ่นนำ
  groupHeading: boolean; // เลขหัวข้อคณะทำงาน (1. คณะทำงาน...)
  memberNo: boolean;     // เลขลำดับรายชื่อ (1.1, 1.2...)
  dutyNo: boolean;       // เลขข้อหน้าที่ (1., 2....)
  orderDate: boolean;    // สั่ง ณ วันที่ ... พ.ศ. ... และข้อความท้ายคำสั่ง
}

export const ALL_ARABIC_DIGITS: DigitFormatSettings = {
  header: false,
  preamble: false,
  groupHeading: false,
  memberNo: false,
  dutyNo: false,
  orderDate: false,
};

export const ALL_THAI_DIGITS: DigitFormatSettings = {
  header: true,
  preamble: true,
  groupHeading: true,
  memberNo: true,
  dutyNo: true,
  orderDate: true,
};

export const DEFAULT_ADMIN_POSITIONS = [
  'ผู้อำนวยการโรงเรียน',
  'ผู้อำนวยการสถานศึกษา',
  'รองผู้อำนวยการโรงเรียน',
  'รองผู้อำนวยการสถานศึกษา',
  'หัวหน้าฝ่ายบริหารงานบุคคล',
  'หัวหน้าฝ่ายวิชาการ',
  'หัวหน้าฝ่ายบริหารทั่วไป',
  'หัวหน้าฝ่ายการเงินและพัสดุ',
  'หัวหน้ากลุ่มสาระการเรียนรู้',
  'ครู',
  'ครูผู้ช่วย',
  'พนักงานราชการ',
  'ครูอัตราจ้าง',
  'เจ้าหน้าที่ธุรการ',
];

export const DEFAULT_ACADEMIC_STANDINGS = [
  'ไม่มีวิทยฐานะ',
  'ครูชำนาญการ',
  'ครูชำนาญการพิเศษ',
  'ครูเชี่ยวชาญ',
  'ครูเชี่ยวชาญพิเศษ',
  'ชำนาญการ',
  'ชำนาญการพิเศษ',
  'เชี่ยวชาญ',
  'เชี่ยวชาญพิเศษ',
];

/**
 * รวม "ตำแหน่งบริหาร/ตำแหน่ง" + "วิทยฐานะ" เข้าเป็นข้อความคอลัมน์ตำแหน่งในคำสั่ง
 */
export function composeOfficialPosition(
  adminPos: string,
  academicStanding: string,
): string {
  const cleanPos = adminPos.trim();
  const cleanAcad = academicStanding.trim();
  const isNoneAcad =
    !cleanAcad ||
    cleanAcad === 'ไม่มีวิทยฐานะ' ||
    cleanAcad === 'ไม่มี' ||
    cleanAcad === '-';

  if (isNoneAcad) return cleanPos;
  if (!cleanPos || cleanPos === 'ไม่มีตำแหน่งบริหาร') return cleanAcad;
  if (cleanPos.includes(cleanAcad)) return cleanPos;
  return `${cleanPos} ${cleanAcad}`.trim();
}

/**
 * แยกข้อความ official_position เดิมออกเป็น (ตำแหน่งบริหาร/ตำแหน่ง, วิทยฐานะ)
 */
export function splitOfficialPosition(
  officialPosition: string,
  knownAcademics: string[] = DEFAULT_ACADEMIC_STANDINGS,
): { admin_position: string; academic_standing: string } {
  const raw = (officialPosition || '').trim();
  if (!raw) {
    return { admin_position: 'ครู', academic_standing: '' };
  }
  const sortedAcad = [...knownAcademics]
    .filter((a) => a && a !== 'ไม่มีวิทยฐานะ' && a !== '-')
    .sort((a, b) => b.length - a.length);

  for (const acad of sortedAcad) {
    if (raw === acad) {
      return { admin_position: '', academic_standing: acad };
    }
    if (raw.endsWith(` ${acad}`)) {
      return {
        admin_position: raw.slice(0, raw.length - acad.length).trim(),
        academic_standing: acad,
      };
    }
  }
  return { admin_position: raw, academic_standing: '' };
}

/**
 * ข้อความท้ายคำสั่ง (ก่อน "สั่ง ณ วันที่") — 1 บรรทัด = 1 ย่อหน้า
 * ตามแบบคำสั่งแต่งตั้งของโรงเรียน: ย่อหน้ากำชับการปฏิบัติ + ย่อหน้าวันที่มีผล
 */
export const DEFAULT_EFFECTIVE_TEXT =
  'ให้ผู้ที่ได้รับคำสั่งปฏิบัติหน้าที่อย่างเต็มกำลัง ความรู้ และความสามารถ เพื่อให้บังเกิดประสิทธิผล และมีประสิทธิภาพก่อเกิดประโยชน์สูงสุดแก่โรงเรียนและทางราชการสืบไป\n' +
  'ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป';

/** แยกข้อความหลายย่อหน้า (บรรทัดว่างถูกตัดทิ้ง) */
export function splitParagraphs(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((p) => p.trim())
    .filter(Boolean);
}

/** หน้าที่ในคณะ — คำที่ใช้ในคำสั่งแต่งตั้งของโรงเรียน (กรรมการ) ก่อน แล้วตามด้วยแบบคณะทำงาน */
export const WORKING_ROLE_OPTIONS = [
  'ที่ปรึกษา',
  'ประธานกรรมการ',
  'รองประธานกรรมการ',
  'กรรมการ',
  'กรรมการและเลขานุการ',
  'กรรมการและผู้ช่วยเลขานุการ',
  'ประธานคณะทำงาน',
  'รองประธานคณะทำงาน',
  'หัวหน้าคณะทำงาน',
  'คณะทำงาน',
  'คณะทำงานและเลขานุการ',
  'คณะทำงานและผู้ช่วยเลขานุการ',
];

export const THAI_MONTHS = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

const THAI_DIGIT_MAP: Record<string, string> = {
  '0': '๐',
  '1': '๑',
  '2': '๒',
  '3': '๓',
  '4': '๔',
  '5': '๕',
  '6': '๖',
  '7': '๗',
  '8': '๘',
  '9': '๙',
};

export function formatDigits(
  value: string | number,
  useThaiDigits: boolean,
): string {
  const str = String(value ?? '');
  if (!useThaiDigits) return str;
  return str.replace(/[0-9]/g, (d) => THAI_DIGIT_MAP[d] ?? d);
}

/**
 * แปลงวันที่ YYYY-MM-DD เป็นข้อความ "สั่ง ณ วันที่ ... (เดือน) พ.ศ. ...." ตามแบบคำสั่งราชการ (ไม่มีคำว่า "เดือน")
 */
export function formatThaiOrderDate(
  isoDate: string,
  useThaiDigits = false,
): {
  day: string;
  month: string;
  yearBe: string;
  fullText: string;
} {
  if (!isoDate) {
    return {
      day: '...',
      month: '.........',
      yearBe: '....',
      fullText: 'สั่ง ณ วันที่ ... ......... พ.ศ. ....',
    };
  }
  const parts = isoDate.split('-').map(Number);
  if (parts.length !== 3 || parts.some(Number.isNaN)) {
    return {
      day: '...',
      month: '.........',
      yearBe: '....',
      fullText: 'สั่ง ณ วันที่ ... ......... พ.ศ. ....',
    };
  }
  const [y, m, d] = parts;
  const day = formatDigits(d, useThaiDigits);
  const month = THAI_MONTHS[m - 1] || '.........';
  const yearBe = formatDigits(y > 2400 ? y : y + 543, useThaiDigits);
  return {
    day,
    month,
    yearBe,
    fullText: `สั่ง ณ วันที่ ${day} ${month} พ.ศ. ${yearBe}`,
  };
}

export function createDefaultOrderDraft(
  schoolId: number,
  divisionId: number | null,
  divisionKey: string,
  divisionName: string,
  nextNo = '1',
): Omit<AppointmentOrderFull, 'id'> {
  const todayIso = new Date().toISOString().slice(0, 10);
  const currentYearBe = new Date().getFullYear() + 543;

  return {
    id_school: schoolId,
    division_id: divisionId && divisionId > 0 ? divisionId : null,
    division_key: divisionKey,
    order_no: nextNo,
    order_year: currentYearBe,
    subject: `แต่งตั้งคณะทำงานดำเนินงานของ${divisionName}`,
    preamble: `เพื่อให้การบริหารจัดการและการดำเนินงานของ${divisionName} เป็นไปด้วยความเรียบร้อย มีประสิทธิภาพ และบรรลุตามวัตถุประสงค์ของสถานศึกษา จึงแต่งตั้งคณะทำงานปฏิบัติหน้าที่ดังต่อไปนี้`,
    effective_text: DEFAULT_EFFECTIVE_TEXT,
    order_date: todayIso,
    signer_name: '',
    signer_title: 'ผู้อำนวยการสถานศึกษา',
    groups: [
      {
        group_no: 1,
        group_title: 'คณะทำงานด้านอำนวยการ',
        members: [
          {
            member_no: 1,
            id_user: null,
            full_name: '',
            admin_position: 'ผู้อำนวยการโรงเรียน',
            academic_standing: '',
            official_position: 'ผู้อำนวยการโรงเรียน',
            working_role: 'ประธานคณะทำงาน',
          },
        ],
        duties: [
          'อำนวยการ กำกับ ติดตาม และให้คำปรึกษาในการดำเนินงานให้เป็นไปด้วยความเรียบร้อย',
        ],
      },
      {
        group_no: 2,
        group_title: `คณะทำงานด้านดำเนินงาน${divisionName}`,
        members: [
          {
            member_no: 1,
            id_user: null,
            full_name: '',
            admin_position: 'ครู',
            academic_standing: '',
            official_position: 'ครู',
            working_role: 'หัวหน้าคณะทำงาน',
          },
        ],
        duties: [
          'วางแผน ประสานงาน และดำเนินการตามภารกิจที่ได้รับมอบหมายให้สำเร็จลุล่วง',
        ],
      },
    ],
  };
}
