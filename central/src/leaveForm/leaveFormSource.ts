/**
 * ดึงข้อมูลที่ใบลาต้องใช้ของโรงเรียนหนึ่ง — จัดรูปเหมือน app ทุกอย่าง
 *   ใบลา:        FirebaseService.getLeaveRequestsFromSupabase + _fromSupabaseLeave
 *   บุคลากร:      FirebaseService.getUsersFromSupabase + _fromSupabaseTeacher
 *   ประเภทการลา: FirebaseService.getLeaveTypesFromSupabase
 *   โรงเรียน:     SchoolRecord.fromRow
 *
 * web เป็นผู้ดูแลส่วนกลาง (เห็นทุกโรงเรียน) จึงต้องกรอง id_school เอง
 * ส่วน app กรองด้วยโรงเรียนของคนที่ล็อกอิน
 */
import { supabase } from '../supabase';
import {
  compareLeaveRecency,
  formatToThaiSlashDate,
  formatToThaiTime,
  schoolRecordFromRow,
  type Row,
  type SchoolRecord,
} from './leaveFormData';

export interface LeaveFormSource {
  school: SchoolRecord;
  leaves: Row[]; // ใบลาทั้งโรงเรียน ใหม่สุดก่อน
  users: Row[];
  leaveTypeNames: string[];
  fiscalYears: unknown[]; // FiscalRounds.year ใหม่สุดก่อน (ใช้กับข้อมูลตัวอย่าง)
}

const text = (v: unknown) => (v === null || v === undefined ? '' : String(v));

/** _pickValueIgnoreCase */
function pickIgnoreCase(row: Row, candidates: string[]): unknown {
  for (const key of Object.keys(row)) {
    if (candidates.includes(key.toLowerCase())) {
      const value = row[key];
      if (value !== null && value !== undefined && String(value).trim()) return value;
    }
  }
  return null;
}

/** ค่าแรกที่ไม่ใช่ null/undefined (Dart ??) */
const coalesce = (...values: unknown[]) => values.find((v) => v !== null && v !== undefined);

/** _fromSupabaseLeave */
function fromSupabaseLeave(r: Row): Row {
  const id = text(coalesce(r.id, r.id_leaves, r.requestId, r.requestid, ''));
  const academicVal = coalesce(r.academicstanding, r.academicStanding, r['วิทยฐานะ'], '');
  return {
    ...r,
    id,
    requestId: id || text(r.id),
    fullName: coalesce(r.fullname, r.fullName, ''),
    leaveType: coalesce(r.leavetype, r.leaveType, ''),
    startDate: formatToThaiSlashDate(coalesce(r.startdate, r.startDate, '')),
    endDate: formatToThaiSlashDate(coalesce(r.enddate, r.endDate, '')),
    leaveDate: formatToThaiSlashDate(coalesce(r.leavedate, r.leaveDate, '')),
    totalDays: coalesce(r.totaldays, r.totalDays, 0),
    isHalfDay: coalesce(r.ishalfday, r.isHalfDay, false),
    halfDayPeriod: coalesce(r.halfdayperiod, r.halfDayPeriod, ''),
    createdAt: coalesce(r.createdat, r.createdAt, r.timestamp, ''),
    medicalCertificate: coalesce(r.medicalcertificate, r.medicalCertificate, ''),
    academicStanding: academicVal,
    ID_Academics: coalesce(r.ID_Academics, r.id_academic, r.id_academics),
    'วิทยฐานะ': academicVal,
    receiveNumber: coalesce(r.receivenumber, r.receiveNumber),
    receiveDate: formatToThaiSlashDate(coalesce(r.receivedate, r.receiveDate, '')),
    receiveTime: formatToThaiTime(coalesce(r.receivetime, r.receiveTime, '')),
    lastUpdatedAt: coalesce(r.lastupdatedat, r.lastUpdatedAt),
  };
}

/** getUsersFromSupabase (เฉพาะช่องที่ใบลาใช้: ชื่อ ตำแหน่ง วิทยฐานะ ตำแหน่งบริหาร) */
export function mapTeachers(rows: Row[], positions: Row[], academics: Row[], adminRoles: Row[]): Row[] {
  const posMap = new Map<string, string>();
  for (const p of positions) {
    const id = text(coalesce(p.ID_Positions, p.id));
    const name = text(coalesce(p.positionName, p.name, ''));
    if (id && name) posMap.set(id, name);
  }
  const academicMap = new Map<string, string>();
  for (const a of academics) {
    const id = text(coalesce(a.ID_Academics, a.id));
    const name = text(coalesce(a.AcademicsName, a.academicsname, a.name, ''));
    if (id && name) academicMap.set(id, name);
  }
  const adminRoleMap = new Map<string, string>();
  for (const ar of adminRoles) {
    const id = text(pickIgnoreCase(ar, ['id_adminroles', 'id_adminrole', 'id']));
    const name = text(pickIgnoreCase(ar, ['adminrolesname', 'adminrolename', 'name', 'value'])).trim();
    if (id && name) adminRoleMap.set(id, name);
  }

  const list = rows.map((r) => {
    const posId = text(r.id_position);
    const academicId = text(coalesce(r.ID_Academics, r.id_academic, r.id_academics));
    const adminRoleId = text(pickIgnoreCase(r, ['id_adminrole', 'id_adminroles', 'id_admin_role']));
    const resolvedPos = text(coalesce(r.position, posMap.get(posId), ''));
    const resolvedAcademic = text(coalesce(r.academicStanding, r.academicstanding, academicMap.get(academicId), ''));
    const resolvedAdminRole = text(coalesce(r['ตำแหน่งงานบริหาร'], adminRoleMap.get(adminRoleId), '')).trim();
    const academic = resolvedAcademic || (academicMap.get(academicId) ?? '');
    return {
      ...r,
      fullName: coalesce(r.fullname, r.fullName, r.name, ''),
      position: resolvedPos,
      academicStanding: academic,
      'วิทยฐานะ': academic,
      'ตำแหน่งงานบริหาร': resolvedAdminRole,
    } as Row;
  });
  // Dart String.compareTo — เทียบรหัสตัวอักษร ไม่ใช่ localeCompare
  return list.sort((a, b) => {
    const x = text(a.fullName);
    const y = text(b.fullName);
    return x < y ? -1 : x > y ? 1 : 0;
  });
}

export async function loadLeaveFormSource(schoolId: number): Promise<LeaveFormSource> {
  const [school, leaves, teachers, teachersFull, positions, academics, adminRoles, leaveTypes, rounds] =
    await Promise.all([
      supabase.from('Schools').select('*').eq('id_school', schoolId).maybeSingle(),
      supabase.from('Leaves').select('*').eq('id_school', schoolId),
      supabase.from('Teachers').select('id_user, fullName').eq('id_school', schoolId),
      supabase.from('Teachers').select('*').eq('id_school', schoolId),
      supabase.from('positions').select('*'),
      supabase.from('academics').select('*'),
      supabase.from('adminroles').select('*').eq('id_school', schoolId),
      supabase.from('LeaveTypes').select('*'),
      supabase.from('FiscalRounds').select('*').order('year', { ascending: false }),
    ]);
  const failed = [school, leaves, teachers, teachersFull, positions, academics, adminRoles, leaveTypes, rounds]
    .map((r) => r.error)
    .find(Boolean);
  if (failed) throw new Error(failed.message);

  // ประเภทการลา (ชื่อสำหรับช่องติ๊ก) — getLeaveTypesFromSupabase
  const leaveTypeNames: string[] = [];
  for (const r of (leaveTypes.data ?? []) as Row[]) {
    const v = text(coalesce(r.leaveName, r.value, r.Value, r.name, r.typename, r.leavetypename, '')).trim();
    if (v && !leaveTypeNames.includes(v)) leaveTypeNames.push(v);
  }

  // ใบลา — getLeaveRequestsFromSupabase
  const userMap = new Map<string, Row>();
  for (const t of (teachers.data ?? []) as Row[]) {
    const uid = text(t.id_user);
    if (uid) userMap.set(uid, t);
  }
  const typeMap = new Map<string, string>();
  for (const t of (leaveTypes.data ?? []) as Row[]) {
    const tid = text(coalesce(t.id_leaveType, t.id));
    const valueName = text(coalesce(t.value, t.Value, t.name, '')).trim(); // getLeaveTypesRaw ใส่เป็น 'Value'
    const name = text(coalesce(t.leaveName, t.name, valueName));
    if (tid && name) typeMap.set(tid, name);
  }
  const yearMap = new Map<string, unknown>();
  for (const fr of (rounds.data ?? []) as Row[]) {
    const id = text(coalesce(fr.id_year, fr.id));
    if (id) yearMap.set(id, fr.year);
  }
  const mappedLeaves = ((leaves.data ?? []) as Row[])
    .map((r) => {
      const teacher = userMap.get(text(r.id_user)) ?? {};
      return fromSupabaseLeave({
        ...r,
        fullName: text(coalesce(r.fullname, r.fullName, teacher.fullName, teacher.name, '')),
        leaveType: text(coalesce(r.leavetype, r.leaveType, typeMap.get(text(r.id_leaveType)), '')),
        year: coalesce(yearMap.get(text(r.id_year)), r.year, r.id_year),
        department: coalesce(teacher.department, ''),
        position: coalesce(teacher.position, ''),
        academicStanding: coalesce(teacher.academicStanding, teacher['วิทยฐานะ'], ''),
        ID_Academics: teacher.ID_Academics,
        'วิทยฐานะ': coalesce(teacher.academicStanding, teacher['วิทยฐานะ'], ''),
      });
    })
    .sort(compareLeaveRecency);

  return {
    school: schoolRecordFromRow((school.data ?? {}) as Row),
    leaves: mappedLeaves,
    users: mapTeachers(
      (teachersFull.data ?? []) as Row[],
      (positions.data ?? []) as Row[],
      (academics.data ?? []) as Row[],
      (adminRoles.data ?? []) as Row[],
    ),
    leaveTypeNames,
    fiscalYears: ((rounds.data ?? []) as Row[]).map((r) => r.year),
  };
}

/** ใบลาตัวอย่าง — ใช้ดูหน้าตาเมื่อโรงเรียนยังไม่มีใบลาจริง */
export function sampleLeaf(source: LeaveFormSource): Row {
  const user = source.users.find((u) => text(u.fullName).trim()) ?? {};
  const today = new Date();
  const d = `${String(today.getDate()).padStart(2, '0')}/${String(today.getMonth() + 1).padStart(2, '0')}/${today.getFullYear() + 543}`;
  return {
    requestId: 'sample',
    fullName: text(user.fullName) || 'นางสาวตัวอย่าง ทดสอบระบบ',
    leaveType: source.leaveTypeNames[0] ?? 'ลาป่วย',
    reason: 'ตัวอย่างเหตุผลการลา',
    phone: '08x-xxx-xxxx',
    startDate: d,
    endDate: d,
    totalDays: 1,
    year: source.fiscalYears[0] ?? today.getFullYear() + 543,
    timestamp: today.toISOString(),
    createdAt: today.toISOString(),
    status: 'รอพิจารณา',
    position: '',
    academicStanding: '',
  };
}
