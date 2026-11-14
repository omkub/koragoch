export interface OrderMemberDraft {
  id?: number;
  member_no: number;
  id_user: number | null;
  full_name: string;
  official_position: string;
  working_role: string;
}

export interface OrderGroupDraft {
  id?: number;
  group_no: number;
  group_title: string;
  duties: string[];
  members: OrderMemberDraft[];
}

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
  created_at?: string;
  updated_at?: string;
}

export interface AppointmentOrderFull extends AppointmentOrderRecord {
  groups: OrderGroupDraft[];
}

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
 * แปลงวันที่ YYYY-MM-DD เป็นข้อความ "สั่ง ณ วันที่ ... เดือน ... พ.ศ. ...."
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
      fullText: 'สั่ง ณ วันที่ ... เดือน ......... พ.ศ. ....',
    };
  }
  const parts = isoDate.split('-').map(Number);
  if (parts.length !== 3 || parts.some(Number.isNaN)) {
    return {
      day: '...',
      month: '.........',
      yearBe: '....',
      fullText: 'สั่ง ณ วันที่ ... เดือน ......... พ.ศ. ....',
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
    fullText: `สั่ง ณ วันที่ ${day} เดือน ${month} พ.ศ. ${yearBe}`,
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
    effective_text: 'ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป',
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
