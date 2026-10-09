/**
 * ใบขออนุญาตไปราชการ — แม่แบบเริ่มต้น + ดึงข้อมูล + แปลงเป็นตัวแทนข้อมูล
 *
 * แม่แบบเริ่มต้นออกแบบตามรูปแบบ "บันทึกข้อความ" ที่โรงเรียนใช้ทั่วไป
 * แก้ได้ทุกบรรทัดที่หน้าแบบฟอร์มใน web — app ใช้วาดพรีวิวในแท็บบันทึกไปราชการ
 * และหน้าพิมพ์จากหน้าประวัติไปราชการ (tripContext ฝั่ง app: lib/forms/trip_render_context.dart)
 * ข้อมูลมาจาก OfficialTrips + OfficialTripMembers (supabase/official_trips.sql)
 */
import { supabase } from '../supabase';
import { LeaveFormData, THAI_MONTHS, schoolRecordFromRow, type Row, type SchoolRecord } from '../leaveForm/leaveFormData';
import { mapTeachers } from '../leaveForm/leaveFormSource';
import type { RenderContext } from './render';
import {
  ALWAYS_UNCHECKED,
  commonDefaults,
  FONT_CHOICES,
  type FlagOption,
  type FormTemplate,
  type Placeholder,
} from './template';

const DOTS_SIGN = 'ลงชื่อ ..................................................';
const BLANK = '..............................';

export function defaultTripTemplate(): FormTemplate {
  return {
    schema: 1,
    formType: 'trip',
    paper: {
      size: 'A4',
      widthMm: 210,
      heightMm: 297,
      orientation: 'portrait',
      margin: { top: 20, right: 20, bottom: 20, left: 30 },
      fontFamily: FONT_CHOICES[0].value,
      fontSizePt: 12,
      lineHeight: 1.6,
      fitToPage: false,
    },
    blocks: [
      {
        ...commonDefaults('หัวเรื่อง "บันทึกข้อความ"', { builtIn: true, align: 'center', fontSizePt: 20, bold: true, spaceBeforeMm: 0, spaceAfterMm: 4 }),
        type: 'textBox',
        lines: ['บันทึกข้อความ'],
        boxWidthMm: null,
        boxPosition: 'left',
        firstLineIndentMm: 0,
      },
      {
        ...commonDefaults('ส่วนราชการ', { builtIn: true }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'ส่วนราชการ', bold: true, nowrap: true },
          { kind: 'field', text: '{โรงเรียน} {ที่อยู่โรงเรียน}', widthMm: null },
        ],
      },
      {
        ...commonDefaults('ที่ / วันที่', { builtIn: true }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'ที่', bold: true, nowrap: true },
          { kind: 'field', text: '', widthMm: 60 },
          { kind: 'text', text: 'วันที่', bold: true, nowrap: true },
          { kind: 'field', text: '{วันที่ยื่น}', widthMm: null },
        ],
      },
      {
        ...commonDefaults('เรื่อง', { builtIn: true }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'เรื่อง', bold: true, nowrap: true },
          { kind: 'field', text: 'ขออนุญาตไปราชการ', widthMm: null },
        ],
      },
      {
        ...commonDefaults('เรียน', { builtIn: true, spaceBeforeMm: 4 }),
        type: 'row',
        segments: [{ kind: 'text', text: 'เรียน ผู้อำนวยการ{โรงเรียน}' }],
      },
      {
        ...commonDefaults('เนื้อความ', { builtIn: true, align: 'justify', spaceBeforeMm: 3 }),
        type: 'textBox',
        lines: [
          'ด้วย {หน่วยงานที่จัด} ได้มีหนังสือที่ {เลขที่หนังสือ} ลงวันที่ {วันที่หนังสือ} ' +
            'แจ้งให้เข้าร่วม{ประเภท} เรื่อง {เรื่อง} ณ {สถานที่} {จังหวัด} ในวันที่ {ช่วงวันที่} ' +
            '({ช่วงเวลา}) รวม {จำนวนวัน} วันทำการ',
        ],
        boxWidthMm: null,
        boxPosition: 'left',
        firstLineIndentMm: 25,
      },
      {
        ...commonDefaults('ขออนุญาต', { builtIn: true, align: 'justify' }),
        type: 'textBox',
        lines: ['ในการนี้ ข้าพเจ้าจึงขออนุญาตไปราชการดังกล่าว พร้อมด้วยผู้มีรายชื่อต่อไปนี้ รวม {จำนวนผู้ร่วมเดินทาง} คน'],
        boxWidthMm: null,
        boxPosition: 'left',
        firstLineIndentMm: 25,
      },
      {
        ...commonDefaults('ตารางผู้ร่วมเดินทาง', { builtIn: true }),
        type: 'memberTable',
        showPosition: true,
        showSignature: false,
        headers: { no: 'ที่', name: 'ชื่อ - สกุล', position: 'ตำแหน่ง', signature: 'ลายมือชื่อ' },
      },
      {
        ...commonDefaults('การเดินทาง / ค่าใช้จ่าย', { builtIn: true }),
        type: 'textBox',
        lines: ['โดยเดินทางด้วย {การเดินทาง} ค่าใช้จ่าย {แหล่งค่าใช้จ่าย} {ค่าใช้จ่าย}'],
        boxWidthMm: null,
        boxPosition: 'left',
        firstLineIndentMm: 25,
      },
      {
        ...commonDefaults('จึงเรียนมา', { builtIn: true, spaceBeforeMm: 3 }),
        type: 'textBox',
        lines: ['จึงเรียนมาเพื่อโปรดพิจารณาอนุญาต'],
        boxWidthMm: null,
        boxPosition: 'left',
        firstLineIndentMm: 25,
      },
      {
        ...commonDefaults('ลงชื่อผู้ขออนุญาต', { builtIn: true, spaceBeforeMm: 8 }),
        type: 'signature',
        lines: [DOTS_SIGN, '( {ชื่อ} )', 'ตำแหน่ง {ตำแหน่ง}'],
        boxWidthMm: 90,
        boxPosition: 'right',
      },
      {
        ...commonDefaults('ความเห็นผู้บังคับบัญชา', { builtIn: true, spaceBeforeMm: 6 }),
        type: 'textBox',
        lines: ['**ความเห็นของผู้บังคับบัญชา**', '..................................................................................................'],
        boxWidthMm: null,
        boxPosition: 'left',
        firstLineIndentMm: 0,
      },
      {
        ...commonDefaults('คำสั่ง', { builtIn: true, spaceBeforeMm: 4 }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'คำสั่ง', bold: true, nowrap: true },
          { kind: 'checkbox', label: 'อนุญาต', flag: 'อนุมัติแล้ว' },
          { kind: 'checkbox', label: 'ไม่อนุญาต', flag: 'ไม่อนุมัติ' },
        ],
      },
      {
        ...commonDefaults('ลงชื่อผู้อำนวยการ', { builtIn: true, spaceBeforeMm: 6 }),
        type: 'signature',
        lines: [DOTS_SIGN, '{ผู้อำนวยการ}', 'ผู้อำนวยการ{โรงเรียน}', '........../........../..........'],
        boxWidthMm: 90,
        boxPosition: 'right',
      },
    ],
  };
}

export const TRIP_PLACEHOLDERS: Placeholder[] = [
  { key: 'ชื่อ', label: 'ชื่อผู้ขอ' },
  { key: 'ตำแหน่ง', label: 'ตำแหน่งผู้ขอ' },
  { key: 'เรื่อง', label: 'เรื่องที่ไป' },
  { key: 'ประเภท', label: 'ประเภท (ประชุม/อบรม/...)' },
  { key: 'หน่วยงานที่จัด', label: 'หน่วยงานที่จัด' },
  { key: 'สถานที่', label: 'สถานที่' },
  { key: 'จังหวัด', label: 'จังหวัด' },
  { key: 'เลขที่หนังสือ', label: 'เลขที่หนังสือ' },
  { key: 'วันที่หนังสือ', label: 'วันที่หนังสือ' },
  { key: 'วันที่เริ่ม', label: 'วันที่เริ่ม' },
  { key: 'วันที่สิ้นสุด', label: 'วันที่สิ้นสุด' },
  { key: 'ช่วงวันที่', label: 'ช่วงวันที่ (เริ่ม ถึง สิ้นสุด)' },
  { key: 'ช่วงเวลา', label: 'เต็มวัน / ครึ่งเช้า / ครึ่งบ่าย' },
  { key: 'จำนวนวัน', label: 'จำนวนวันทำการ' },
  { key: 'การเดินทาง', label: 'เดินทางโดย' },
  { key: 'แหล่งค่าใช้จ่าย', label: 'แหล่งค่าใช้จ่าย' },
  { key: 'ค่าใช้จ่าย', label: 'ประมาณการค่าใช้จ่าย' },
  { key: 'จำนวนผู้ร่วมเดินทาง', label: 'จำนวนคนที่ไป' },
  { key: 'หมายเหตุ', label: 'หมายเหตุ' },
  { key: 'สถานะ', label: 'สถานะ' },
  { key: 'วันที่ยื่น', label: 'วันที่บันทึก' },
  { key: 'รายงานผล', label: 'รายงานผลหลังกลับ' },
  { key: 'โรงเรียน', label: 'ชื่อโรงเรียน' },
  { key: 'ที่อยู่โรงเรียน', label: 'ที่อยู่โรงเรียน' },
  { key: 'สังกัด', label: 'สังกัด' },
  { key: 'ผู้อำนวยการ', label: '(ชื่อผู้อำนวยการ)' },
];

export const TRIP_FLAGS: FlagOption[] = [
  { key: 'อนุมัติแล้ว', label: 'อนุมัติแล้ว' },
  { key: 'ไม่อนุมัติ', label: 'ไม่อนุมัติ' },
  { key: 'ครึ่งวัน', label: 'ไปครึ่งวัน' },
  { key: 'มีค่าใช้จ่าย', label: 'มีประมาณการค่าใช้จ่าย' },
  { key: ALWAYS_UNCHECKED, label: 'ว่างไว้เสมอ (ให้ติ๊กด้วยมือ)' },
];

// ── ข้อมูล ─────────────────────────────────────────────────────

export interface TripSource {
  school: SchoolRecord;
  trips: Row[]; // ใหม่สุดก่อน + members: id_user[]
  users: Row[];
}

const text = (v: unknown) => (v === null || v === undefined ? '' : String(v));

export async function loadTripSource(schoolId: number): Promise<TripSource> {
  const [school, trips, teachers, positions, academics, adminRoles] = await Promise.all([
    supabase.from('Schools').select('*').eq('id_school', schoolId).maybeSingle(),
    supabase
      .from('OfficialTrips')
      .select('*, OfficialTripMembers(id_user)')
      .eq('id_school', schoolId)
      .order('startDate', { ascending: false })
      .limit(300),
    supabase.from('Teachers').select('*').eq('id_school', schoolId),
    supabase.from('positions').select('*'),
    supabase.from('academics').select('*'),
    supabase.from('adminroles').select('*').eq('id_school', schoolId),
  ]);
  const failed = [school, trips, teachers, positions, academics, adminRoles].map((r) => r.error).find(Boolean);
  if (failed) throw new Error(failed.message);
  return {
    school: schoolRecordFromRow((school.data ?? {}) as Row),
    trips: ((trips.data ?? []) as Row[]).map((t) => {
      const { OfficialTripMembers: m, ...rest } = t as Row & { OfficialTripMembers?: { id_user: number }[] };
      return { ...rest, members: (m ?? []).map((x) => x.id_user) };
    }),
    users: mapTeachers(
      (teachers.data ?? []) as Row[],
      (positions.data ?? []) as Row[],
      (academics.data ?? []) as Row[],
      (adminRoles.data ?? []) as Row[],
    ),
  };
}

export function sampleTrip(source: TripSource): Row {
  const named = source.users.filter((u) => text(u.fullName).trim());
  const today = new Date();
  const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const tomorrow = new Date(today.getTime() + 86400000);
  return {
    id_trip: 'sample',
    id_user: named[0]?.id_user ?? null,
    members: named.slice(0, 3).map((u) => u.id_user),
    title: 'ประชุมเชิงปฏิบัติการพัฒนาหลักสูตรสถานศึกษา',
    tripType: 'ประชุม',
    organizer: 'สำนักงานเขตพื้นที่การศึกษามัธยมศึกษา',
    location: 'หอประชุมสำนักงานเขต',
    province: 'บุรีรัมย์',
    docNumber: 'ศธ 04xxx/1234',
    docDate: iso(today),
    startDate: iso(today),
    endDate: iso(tomorrow),
    isHalfDay: false,
    totalDays: 2,
    travelMode: 'รถยนต์ราชการ',
    budgetSource: 'เบิกจากต้นสังกัด',
    estimatedCost: 1500,
    status: 'รอพิจารณา',
    createdAt: today.toISOString(),
  };
}

/** 2026-10-09 → "9 ตุลาคม 2569" */
function thaiDate(value: unknown): string {
  const raw = text(value);
  // เวลาเต็ม (createdAt) → ใช้วันตามเวลาเครื่อง ไม่ใช่วัน UTC
  if (raw.includes('T')) {
    const d = new Date(raw);
    if (!Number.isNaN(d.getTime())) return `${d.getDate()} ${THAI_MONTHS[d.getMonth()]} ${d.getFullYear() + 543}`;
  }
  const m = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return '';
  return `${Number(m[3])} ${THAI_MONTHS[Number(m[2]) - 1]} ${Number(m[1]) + 543}`;
}

function positionWithStanding(u: Row | undefined): string {
  if (!u) return '';
  const pos = text(u.position).trim();
  const rank = text(u.academicStanding).trim();
  const r = rank && rank !== 'ไม่มีวิทยฐานะ' && !rank.includes('เลือก') && rank !== '-' ? rank : '';
  const p = pos && pos !== '-' && !pos.includes('เลือก') ? pos : '';
  return [p, r].filter(Boolean).join(' ');
}

export function tripContext(trip: Row, source: TripSource): RenderContext {
  const byId = new Map(source.users.map((u) => [text(u.id_user), u]));
  const owner = byId.get(text(trip.id_user));
  const ownerId = text(trip.id_user);
  const memberIds = (trip.members as unknown[] | undefined) ?? [];
  const ordered = [ownerId, ...memberIds.map(text).filter((id) => id !== ownerId)].filter(Boolean);
  const members = ordered.map((id) => {
    const u = byId.get(id);
    return { name: text(u?.fullName) || '-', position: positionWithStanding(u) };
  });
  const director = new LeaveFormData({ leaf: {}, allUsers: source.users, allLeaveRequests: [], school: source.school }).directorName;
  const start = thaiDate(trip.startDate);
  const end = thaiDate(trip.endDate);
  const half = trip.isHalfDay === true;
  const cost = Number(trip.estimatedCost);
  const or = (v: unknown) => text(v).trim() || BLANK;
  const school = source.school;
  return {
    title: `OfficialTrip-${text(trip.title)}`,
    values: {
      ชื่อ: text(owner?.fullName) || BLANK,
      ตำแหน่ง: positionWithStanding(owner) || BLANK,
      เรื่อง: or(trip.title),
      ประเภท: text(trip.tripType) || 'ประชุม',
      หน่วยงานที่จัด: or(trip.organizer),
      สถานที่: or(trip.location),
      จังหวัด: text(trip.province).trim() ? `จังหวัด${text(trip.province).replace(/^จังหวัด/, '')}` : '',
      เลขที่หนังสือ: or(trip.docNumber),
      วันที่หนังสือ: thaiDate(trip.docDate) || BLANK,
      วันที่เริ่ม: start || BLANK,
      วันที่สิ้นสุด: end || BLANK,
      ช่วงวันที่: !start ? BLANK : start === end || !end ? start : `${start} ถึงวันที่ ${end}`,
      ช่วงเวลา: !half ? 'เต็มวัน' : trip.halfDayPeriod === 'afternoon' ? 'ครึ่งวันบ่าย' : 'ครึ่งวันเช้า',
      จำนวนวัน: trip.totalDays === null || trip.totalDays === undefined ? BLANK : text(Number(trip.totalDays)),
      การเดินทาง: or(trip.travelMode),
      แหล่งค่าใช้จ่าย: or(trip.budgetSource),
      ค่าใช้จ่าย: cost > 0 ? `ประมาณ ${cost.toLocaleString('th-TH')} บาท` : '',
      จำนวนผู้ร่วมเดินทาง: String(members.length),
      หมายเหตุ: text(trip.note),
      สถานะ: text(trip.status),
      วันที่ยื่น: thaiDate(trip.createdAt) || BLANK,
      รายงานผล: text(trip.reportSummary),
      โรงเรียน: school.fullName,
      ที่อยู่โรงเรียน: school.address,
      สังกัด: school.affiliation,
      ผู้อำนวยการ: director,
    },
    flags: {
      อนุมัติแล้ว: trip.status === 'อนุมัติ',
      ไม่อนุมัติ: trip.status === 'ไม่อนุมัติ',
      ครึ่งวัน: half,
      มีค่าใช้จ่าย: cost > 0,
    },
    members,
  };
}
