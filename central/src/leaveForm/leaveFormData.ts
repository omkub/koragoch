/**
 * ข้อมูลที่ใบลาต้องใช้ — แปลงมาจาก app แบบบรรทัดต่อบรรทัด
 *   lib/widgets/leave_form_data.dart  (LeaveFormData)
 *   lib/services/firebase_service.dart (formatThaiDate, formatLeaveDayCount,
 *                                       parseFast, compareLeaveRecency)
 *
 * ต้องได้ผลตรงกับ app ทุกตัวอักษร (ตรวจด้วยการเทียบ HTML ที่ได้จากข้อมูลชุดเดียวกัน)
 * ถ้าแก้ตรรกะที่นี่ ต้องแก้ที่ app ด้วย หรือเปลี่ยนให้ app มาใช้แม่แบบจาก web
 *
 * จุดที่ต้องระวังเรื่องพฤติกรรมของ Dart:
 *   - DateTime.tryParse: เวลาที่มีโซน (Z / +07:00) ได้ค่าแบบ UTC แล้ว .day คืนวันแบบ UTC
 *     เวลาที่ไม่มีโซน ได้ค่าแบบเวลาเครื่อง → DartDate เก็บธงนี้ไว้
 *   - String.compareTo เทียบรหัสตัวอักษรตรง ๆ ไม่ใช่ localeCompare
 *   - num.tryParse('') = null (JS Number('') = 0)
 */

export type Row = Record<string, unknown>;

// ── ตัวช่วยแปลงค่าแบบ Dart ─────────────────────────────────────

/** Dart: value?.toString() */
const str = (v: unknown): string | null =>
  v === null || v === undefined ? null : typeof v === 'number' ? dartNumToString(v) : String(v);

/** Dart: (value ?? '').toString() */
const s = (v: unknown): string => str(v) ?? '';

/** Dart แสดง double ที่เป็นจำนวนเต็มเป็น "1.0" — แต่ค่าจาก Supabase เป็น int อยู่แล้ว จึงคืนแบบ JS */
function dartNumToString(n: number): string {
  return String(n);
}

/** Dart: num.tryParse / double.tryParse */
function tryParseNum(text: string | null): number | null {
  if (text === null) return null;
  const t = text.trim();
  if (t === '' || !/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(t)) return null;
  return Number(t);
}

/** Dart: int.parse (ไม่ยอมช่องว่าง) — คืน null แทนการ throw */
function strictInt(text: string): number | null {
  return /^[+-]?\d+$/.test(text) ? Number(text) : null;
}

/** วันที่แบบ Dart DateTime — จำว่าเป็น UTC หรือเวลาเครื่อง */
export interface DartDate {
  date: Date;
  utc: boolean;
}

const dYear = (d: DartDate) => (d.utc ? d.date.getUTCFullYear() : d.date.getFullYear());
const dMonth = (d: DartDate) => (d.utc ? d.date.getUTCMonth() + 1 : d.date.getMonth() + 1);
const dDay = (d: DartDate) => (d.utc ? d.date.getUTCDate() : d.date.getDate());
const local = (y: number, m: number, d: number): DartDate => {
  const date = new Date(y, m - 1, d);
  if (y >= 0 && y < 100) date.setFullYear(y);
  return { date, utc: false };
};

/** Dart: DateTime.tryParse (รูปแบบ ISO 8601 ที่ระบบนี้ใช้จริง) */
export function dartTryParse(text: string): DartDate | null {
  const m = text.match(
    /^([+-]?\d{4,6})-?(\d\d)-?(\d\d)(?:[T ](\d\d)(?::?(\d\d)(?::?(\d\d)(?:[.,](\d+))?)?)?\s?(Z|[+-]\d\d(?::?\d\d)?)?)?$/i,
  );
  if (!m) return null;
  const [, y, mo, d, h = '0', mi = '0', sec = '0', frac = '', zone] = m;
  const ms = Math.floor(Number(`0.${frac || '0'}`) * 1000);
  if (zone) {
    let offset = 0;
    if (zone.toUpperCase() !== 'Z') {
      const z = zone.replace(':', '');
      offset = (z[0] === '-' ? -1 : 1) * (Number(z.slice(1, 3)) * 60 + Number(z.slice(3, 5) || 0));
    }
    const t = Date.UTC(+y, +mo - 1, +d, +h, +mi, +sec, ms) - offset * 60000;
    return { date: new Date(t), utc: true };
  }
  return { date: new Date(+y, +mo - 1, +d, +h, +mi, +sec, ms), utc: false };
}

/** FirebaseService.parseFast — คืนปี พ.ศ. (ตามของเดิม) */
function parseFast(text: string): DartDate | null {
  const p = text.trim().replace(/ /g, '').split('/');
  if (p.length !== 3) return null;
  let year = strictInt(p[2]);
  const month = strictInt(p[1]);
  const day = strictInt(p[0]);
  if (year === null || month === null || day === null) return null;
  if (year < 2400) year += 543;
  return local(year, month, day);
}

/** LeaveFormData.parseDate */
export function parseDate(value: unknown): DartDate | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string') return null;
  const iso = dartTryParse(value.trim());
  if (iso) return iso;
  const parsed = parseFast(value);
  if (parsed) {
    return dYear(parsed) > 2400 ? local(dYear(parsed) - 543, dMonth(parsed), dDay(parsed)) : parsed;
  }
  if (value.includes('/')) {
    const parts = value.split('/');
    const y = strictInt(parts[2] ?? '');
    const mo = strictInt(parts[1] ?? '');
    const d = strictInt(parts[0] ?? '');
    if (y !== null && mo !== null && d !== null) return local(y - 543, mo, d);
  }
  return null;
}

export const THAI_MONTHS = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

/** FirebaseService.formatThaiDate — วว/ดด/ปปปป → "9 ตุลาคม 2569" */
export function formatThaiDate(value: unknown): string {
  if (value === null || value === undefined || value === '') return '-';
  if (typeof value !== 'string') return s(value);
  const parts = value.split('/');
  if (parts.length !== 3) return value;
  const day = strictInt(parts[0]);
  const month = strictInt(parts[1]);
  let year = strictInt(parts[2]);
  if (day === null || month === null || year === null) return value;
  if (year < 2100) year += 543;
  const date = local(year - 543, month, day);
  return `${dDay(date)} ${THAI_MONTHS[dMonth(date) - 1]} ${dYear(date) + 543}`;
}

/** FirebaseService.formatLeaveDayCount */
export function formatLeaveDayCount(value: unknown): string {
  const n = typeof value === 'number' ? value : tryParseNum(str(value));
  if (n === null || Number.isNaN(n)) return '-';
  return n % 1 === 0 ? String(Math.trunc(n)) : String(n);
}

/** FirebaseService.formatToThaiSlashDate — ISO / วว/ดด/ปปปป → "09/10/2569" */
export function formatToThaiSlashDate(value: unknown): string {
  if (value === null || value === undefined) return '';
  const text = s(value).trim();
  if (!text) return '';
  const p = text.split('/');
  if (p.length === 3) {
    const d = tryParseInt(p[0]);
    const m = tryParseInt(p[1]);
    let y = tryParseInt(p[2]);
    if (d !== null && m !== null && y !== null) {
      if (y < 2400) y += 543;
      return `${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}/${y}`;
    }
  }
  const date = dartTryParse(text);
  if (date) {
    const y = dYear(date) < 2400 ? dYear(date) + 543 : dYear(date);
    return `${String(dDay(date)).padStart(2, '0')}/${String(dMonth(date)).padStart(2, '0')}/${y}`;
  }
  return text;
}

/** Dart int.tryParse (ยอมช่องว่างหัวท้าย) */
function tryParseInt(text: string): number | null {
  return strictInt(text.trim());
}

/** FirebaseService.formatToThaiTime — "08:30:00" → "08:30 น." */
export function formatToThaiTime(value: unknown): string {
  if (value === null || value === undefined) return '';
  const text = s(value).trim();
  if (!text) return '';
  if (text.includes('น.')) return text;
  const p = text.split(':');
  if (p.length >= 2) {
    const h = tryParseInt(p[0]);
    const m = tryParseInt(p[1]);
    if (h !== null && m !== null) {
      return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')} น.`;
    }
  }
  return text;
}

/** Dart String.compareTo */
const cmp = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

function leaveStatusWeight(status: string): number {
  if (status.includes('รอ') || status.includes('พิจารณา')) return 0;
  if (status.includes('ส่งใบ') || status.includes('อนุมัติ') || status.includes('อนุญาต')) return 1;
  if (status.includes('ยังไม่ส่ง') || status.includes('ไม่อนุญาต')) return 2;
  return 3;
}

function leaveCreatedDate(leave: Row): DartDate | null {
  const v = leave.createdAt;
  return typeof v === 'string' && v.trim() ? dartTryParse(v.trim()) : null;
}

/** FirebaseService.compareLeaveRecency — ใหม่สุดก่อน */
export function compareLeaveRecency(a: Row, b: Row): number {
  const dateA = leaveCreatedDate(a);
  const dateB = leaveCreatedDate(b);
  if (dateA && dateB) {
    const c = Math.sign(dateB.date.getTime() - dateA.date.getTime());
    if (c !== 0) return c;
  } else if (dateA) {
    return -1;
  } else if (dateB) {
    return 1;
  }
  const statusCompare = leaveStatusWeight(s(a.status)) - leaveStatusWeight(s(b.status));
  if (statusCompare !== 0) return Math.sign(statusCompare);
  return cmp(s(b.requestId ?? b.id), s(a.requestId ?? a.id));
}

/** Dart List.sort เป็น stable สำหรับรายการเล็ก — JS Array.sort ก็ stable */
export const sortedByRecency = (list: Row[]) => [...list].sort(compareLeaveRecency);

// ── ข้อมูลโรงเรียน (SchoolRecord ใน lib/utils/school_info.dart) ─────────

export interface SchoolRecord {
  fullName: string;
  namePart1: string;
  namePart2: string;
  address: string;
  affiliation: string;
}

export const FALLBACK_SCHOOL: SchoolRecord = {
  fullName: 'โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก',
  namePart1: 'โรงเรียนรมย์บุรีพิทยาคม',
  namePart2: 'รัชมังคลาภิเษก',
  address: 'อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000',
  affiliation: 'สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์ กระทรวงศึกษาธิการ',
};

function composeAddress(subdistrict = '', district = '', province = ''): string {
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

/** SchoolRecord.fromRow */
export function schoolRecordFromRow(row: Row): SchoolRecord {
  const pick = (key: string, fallback: string) => {
    const v = s(row[key]).trim();
    return v || fallback;
  };
  const rawPart1 = s(row.namePart1).trim();
  const rawPart2 = s(row.namePart2).trim();
  const hasAnyPart = !!rawPart1 || !!rawPart2;
  const part1 = hasAnyPart ? rawPart1 : FALLBACK_SCHOOL.namePart1;
  const part2 = hasAnyPart ? rawPart2 : FALLBACK_SCHOOL.namePart2;
  const joined = [part1, part2].filter((x) => x.trim()).join(' ');
  return {
    fullName: joined || pick('fullName', FALLBACK_SCHOOL.fullName),
    namePart1: part1,
    namePart2: part2,
    address: hasAnyPart
      ? pick('address', composeAddress(s(row.subdistrict), s(row.district), s(row.province)))
      : pick('address', FALLBACK_SCHOOL.address),
    affiliation: pick('affiliation', hasAnyPart ? '' : FALLBACK_SCHOOL.affiliation),
  };
}

// ── LeaveFormData ───────────────────────────────────────────────

export interface LeaveStatRow {
  label: string;
  previousTimes: string;
  previousDays: string;
  currentTimes: string;
  currentDays: string;
  totalTimes: string;
  totalDays: string;
}

export const BLANK_SIGNATURE = '(................................)';
const BLANK_DATE = '....................';

const isBlankChoice = (value: string) => {
  const v = value.trim();
  return v === '' || v === '-' || v.includes('เลือก');
};
const hasNoAcademicStanding = (value: string) => value.trim() === 'ไม่มีวิทยฐานะ';

function sequenceDate(leave: Row): DartDate | null {
  return parseDate(leave.startDateValue) ?? parseDate(leave.startDate) ?? parseDate(leave.timestamp);
}

export class LeaveFormData {
  readonly leaf: Row;
  readonly allUsers: Row[];
  readonly allLeaveRequests: Row[];
  readonly leaveTypeNames: string[];
  readonly school: SchoolRecord;

  constructor(args: {
    leaf: Row;
    allUsers: Row[];
    allLeaveRequests: Row[];
    leaveTypeNames?: string[];
    school: SchoolRecord;
  }) {
    this.leaf = args.leaf;
    this.allUsers = args.allUsers;
    this.allLeaveRequests = args.allLeaveRequests;
    this.leaveTypeNames = args.leaveTypeNames ?? [];
    this.school = args.school;
  }

  // ── ค่าที่อ่านตรงจากใบลา ──
  get fullName() { return s(this.leaf.fullName); }
  get leaveTypeRaw() { return s(this.leaf.leaveType); }
  get reason() { return s(this.leaf.reason); }
  get phone() { return s(this.leaf.phone); }
  get receiveNumber() { return str(this.leaf.receiveNumber); }
  get receiveDate() { return str(this.leaf.receiveDate); }
  get receiveTime() { return str(this.leaf.receiveTime); }
  get subject() { return this.leaveTypeRaw === '---เลือก---' ? '' : `ขอ${this.leaveTypeRaw}`; }
  get totalDays(): number { return tryParseNum(str(this.leaf.totalDays) ?? '1') ?? 1; }
  get totalDaysText() { return formatLeaveDayCount(this.totalDays); }
  get startDateText() { return formatThaiDate(this.leaf.startDate); }
  get endDateText() { return formatThaiDate(this.leaf.endDate); }

  // ── วันที่เขียนใบลา ──
  get requestDay() { const d = parseDate(this.leaf.timestamp); return d ? String(dDay(d)) : BLANK_DATE; }
  get requestMonth() { const d = parseDate(this.leaf.timestamp); return d ? THAI_MONTHS[dMonth(d) - 1] : BLANK_DATE; }
  get requestYear() { const d = parseDate(this.leaf.timestamp); return d ? String(dYear(d) + 543) : BLANK_DATE; }
  get hasRequestDate() { return parseDate(this.leaf.timestamp) !== null; }

  // ── ตำแหน่งและวิทยฐานะ ──
  private userForLeaf(): Row {
    const name = this.fullName.trim();
    if (!name) return {};
    return this.allUsers.find((u) => s(u.fullName ?? u.name).trim() === name) ?? {};
  }

  get position(): string {
    const direct = s(this.leaf.position);
    if (!isBlankChoice(direct)) return direct;
    const user = this.userForLeaf();
    const fromUser = s(user.position ?? user['ตำแหน่ง']);
    return isBlankChoice(fromUser) ? '' : fromUser;
  }

  get academicStanding(): string {
    const direct = s(this.leaf.academicStanding).trim();
    if (hasNoAcademicStanding(direct)) return '';
    if (!isBlankChoice(direct)) return direct;
    const user = this.userForLeaf();
    const fromUser = s(user.academicStanding ?? user.rank ?? user['วิทยฐานะ']).trim();
    return isBlankChoice(fromUser) || hasNoAcademicStanding(fromUser) ? '' : fromUser;
  }

  get positionWithStanding(): string {
    const pos = this.position;
    const rank = this.academicStanding;
    if (!rank) return pos;
    return pos ? `${pos} ${rank}` : rank;
  }

  // ── ประเภทการลาที่แสดงเป็นช่องติ๊ก ──
  get printableLeaveTypes(): string[] {
    const names = this.leaveTypeNames.filter((t) => t.trim() && !t.includes('เลือก'));
    return names.length ? names : ['ลาป่วย', 'ลากิจส่วนตัว', 'ลาคลอดบุตร'];
  }

  isSelectedLeaveType(candidate: string): boolean {
    const a = this.leaveTypeRaw.trim();
    const b = candidate.trim();
    return !!a && !!b && a === b;
  }

  // ── การลาครั้งล่าสุดก่อนหน้าใบนี้ ──
  private latestComputed = false;
  private latestCache: Row | null = null;

  get latestLeave(): Row | null {
    if (this.latestComputed) return this.latestCache;
    this.latestComputed = true;
    const name = this.fullName.trim();
    const fiscalYear = s(this.leaf.year).trim();
    if (!name || !fiscalYear) return null;
    const candidates = this.allLeaveRequests
      .filter(
        (leave) =>
          s(leave.fullName).trim() === name &&
          s(leave.year).trim() === fiscalYear &&
          this.isBeforeCurrent(leave),
      )
      .sort(compareLeaveRecency);
    this.latestCache = candidates[0] ?? null;
    return this.latestCache;
  }

  get latestLeaveLabel(): string | null {
    const leave = this.latestLeave;
    if (!leave) return null;
    const t = s(leave.leaveType);
    if (t.includes('ป่วย')) return 'ป่วย';
    if (t.includes('กิจ')) return 'ลากิจส่วนตัว';
    if (t.includes('คลอด')) return 'ลาคลอดบุตร';
    return null;
  }

  get latestStartText() { const l = this.latestLeave; return l ? formatThaiDate(l.startDate) : ''; }
  get latestEndText() { const l = this.latestLeave; return l ? formatThaiDate(l.endDate) : ''; }
  get latestDaysText() { const l = this.latestLeave; return l ? formatLeaveDayCount(l.totalDays) : ''; }

  // ── ชื่อผู้บริหารสำหรับช่องเซ็น ──
  managerName(adminTitle: string): string {
    if (!this.allUsers.length) return BLANK_SIGNATURE;
    const norm = (v: string) => v.replace(/\s+/g, '').trim();
    const target = norm(adminTitle);
    const find = (match: (v: string) => boolean) =>
      this.allUsers.find((u) => {
        const value = str(u['ตำแหน่งงานบริหาร']) ?? '';
        if (!value) return false;
        return match(norm(value));
      }) ?? {};
    let manager = find((v) => v === target);
    if (!Object.keys(manager).length) manager = find((v) => v.includes(target) || target.includes(v));
    const name = (str(manager.fullName) ?? '').trim();
    return name ? `(${name})` : BLANK_SIGNATURE;
  }

  get hrName() { return this.managerName('หัวหน้ากลุ่มบริหารงานบุคคล'); }
  get deputyName() { return this.managerName('รองผู้อำนวยการกลุ่มบริหารงานบุคคล'); }
  get directorName() { return this.managerName('ผู้อำนวยการโรงเรียน'); }

  // ── ตารางสถิติวันลา ──
  private statCache: LeaveStatRow[] | null = null;

  get statRows(): LeaveStatRow[] {
    return (this.statCache ??= [
      this.statRow('ป่วย', 'ป่วย'),
      this.statRow('ลากิจส่วนตัว', 'กิจ'),
      this.statRow('ลาคลอดบุตร', 'คลอด'),
    ]);
  }

  private statRow(label: string, keyword: string): LeaveStatRow {
    const currentYear = s(this.leaf.year);
    const history = this.allLeaveRequests.filter(
      (req) =>
        s(req.fullName) === this.fullName &&
        s(req.leaveType).includes(keyword) &&
        s(req.year) === currentYear &&
        this.isBeforeCurrent(req),
    );
    const prevTimes = history.length;
    const prevDays = history.reduce((sum, req) => sum + (tryParseNum(str(req.totalDays) ?? '0') ?? 0), 0);
    const currentMatch = this.leaveTypeRaw.includes(keyword);
    const totalTimes = prevTimes + (currentMatch ? 1 : 0);
    const totalDaysCalc = prevDays + (currentMatch ? this.totalDays : 0);
    return {
      label,
      previousTimes: prevTimes > 0 ? String(prevTimes) : '-',
      previousDays: prevTimes > 0 ? formatLeaveDayCount(prevDays) : '-',
      currentTimes: currentMatch ? '1' : '-',
      currentDays: currentMatch ? this.totalDaysText : '-',
      totalTimes: totalTimes > 0 ? String(totalTimes) : '-',
      totalDays: totalTimes > 0 ? formatLeaveDayCount(totalDaysCalc) : '-',
    };
  }

  // ── ตัวช่วยเรื่องวันที่ ──
  private isBeforeCurrent(leave: Row): boolean {
    if (leave.requestId === this.leaf.requestId) return false;
    const leaveDate = sequenceDate(leave);
    const currentDate = sequenceDate(this.leaf);
    if (!leaveDate || !currentDate) return false;
    const leaveDay = local(dYear(leaveDate), dMonth(leaveDate), dDay(leaveDate)).date.getTime();
    const currentDay = local(dYear(currentDate), dMonth(currentDate), dDay(currentDate)).date.getTime();
    if (leaveDay < currentDay) return true;
    if (leaveDay > currentDay) return false;
    const leaveTs = parseDate(leave.timestamp);
    const currentTs = parseDate(this.leaf.timestamp);
    if (leaveTs && currentTs) return leaveTs.date.getTime() < currentTs.date.getTime();
    return cmp(s(leave.requestId), s(this.leaf.requestId)) < 0;
  }
}
