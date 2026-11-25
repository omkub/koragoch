import { supabase } from '../supabase';

/**
 * ตัวดึงข้อมูลจากตารางของ "ระบบวันลา" แบบ Read-Only 100%
 * (ห้าม INSERT / UPDATE / DELETE ตารางของระบบวันลาจากไฟล์นี้เด็ดขาด)
 */

export interface LeaveFiscalRound {
  id_year: number;
  year: string;
  round: string;
  startDate: string; // DD/MM/YYYY (พ.ศ.)
  endDate: string;   // DD/MM/YYYY (พ.ศ.)
  isActive: boolean;
  isCurrentByDate: boolean;
}

export interface LeaveSpecialDate {
  id: number;
  id_holiday: number;
  id_SpecialWorkingDays: number;
  date: string; // YYYY-MM-DD (ค.ศ.)
  thaiDateLabel: string;
  title: string;
  note: string;
  id_school: number | null; // null = วันหยุดกลางทุกโรงเรียน
  kind: 'holiday' | 'working_day';
}

export type LeaveSpecialHoliday = LeaveSpecialDate;
export type LeaveSpecialWorkingDay = LeaveSpecialDate;

export interface LeaveSummaryStats {
  totalLeaves: number;
  pendingLeaves: number;
  approvedLeaves: number;
  byType: { typeName: string; count: number }[];
}

export type SchoolLeaveSummary = LeaveSummaryStats;

function parseThaiSlashDateToAd(s: string): Date | null {
  const clean = String(s ?? '').trim();
  if (!clean) return null;

  if (clean.includes('/')) {
    const parts = clean.split('/');
    if (parts.length === 3) {
      const d = Number(parts[0]);
      const m = Number(parts[1]);
      let y = Number(parts[2]);
      if (!d || !m || !y) return null;
      if (y > 2400) y -= 543;
      return new Date(y, m - 1, d);
    }
  }

  const iso = new Date(clean);
  if (!Number.isNaN(iso.getTime())) {
    let y = iso.getFullYear();
    if (y > 2400) y -= 543;
    return new Date(y, iso.getMonth(), iso.getDate());
  }
  return null;
}

export function formatToThaiSlashDate(value: unknown): string {
  const s = String(value ?? '').trim();
  if (!s) return '-';
  const d = parseThaiSlashDateToAd(s);
  if (!d) return s;
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyyBe = d.getFullYear() + 543;
  return `${dd}/${mm}/${yyyyBe}`;
}

export const formatThaiDateShort = formatToThaiSlashDate;

function isTodayInRange(startStr: string, endStr: string): boolean {
  const s = parseThaiSlashDateToAd(startStr);
  const e = parseThaiSlashDateToAd(endStr);
  if (!s || !e) return false;
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return today >= s && today <= e;
}

/** ดึงรอบปีงบประมาณทั้งหมดจากตาราง FiscalRounds ของระบบวันลา (Read-Only) */
export async function fetchLeaveFiscalRounds(): Promise<{
  rounds: LeaveFiscalRound[];
  activeRound: LeaveFiscalRound | null;
  activeYearBe: number;
}> {
  const fallbackYear = new Date().getFullYear() + 543;
  try {
    const { data, error } = await supabase
      .from('FiscalRounds')
      .select('*')
      .order('year', { ascending: false });

    if (error || !Array.isArray(data) || data.length === 0) {
      return { rounds: [], activeRound: null, activeYearBe: fallbackYear };
    }

    const rounds: LeaveFiscalRound[] = (data as Record<string, unknown>[]).map(
      (r, idx) => {
        const rawStart = String(r.startDate ?? r.startdate ?? '');
        const rawEnd = String(r.endDate ?? r.enddate ?? '');
        const startDate = formatToThaiSlashDate(rawStart);
        const endDate = formatToThaiSlashDate(rawEnd);
        const isCurrentByDate = isTodayInRange(rawStart, rawEnd);
        return {
          id_year: Number(r.id_year ?? r.id_Year ?? r.id ?? idx + 1),
          year: String(r.year ?? fallbackYear).trim(),
          round: String(r.round ?? '1').trim(),
          startDate,
          endDate,
          isActive: Boolean(r.isActive ?? r.isactive ?? false),
          isCurrentByDate,
        };
      },
    );

    const activeRound =
      rounds.find((r) => r.isCurrentByDate) ??
      rounds.find((r) => r.isActive) ??
      rounds[0] ??
      null;

    const parsedYear = Number(activeRound?.year);
    const activeYearBe =
      Number.isFinite(parsedYear) && parsedYear > 2400
        ? parsedYear
        : fallbackYear;

    return { rounds, activeRound, activeYearBe };
  } catch {
    return { rounds: [], activeRound: null, activeYearBe: fallbackYear };
  }
}

/** ดึงวันหยุดราชการ / วันหยุดกำหนดเอง (SpecialHolidays) และวันทำงานพิเศษ (SpecialWorkingDays) จากระบบวันลา (Read-Only) */
export async function fetchLeaveSpecialDates(
  schoolId?: number | null,
): Promise<{
  holidays: LeaveSpecialDate[];
  workingDays: LeaveSpecialDate[];
  upcomingHolidays: LeaveSpecialDate[];
}> {
  try {
    const [holRes, workRes] = await Promise.all([
      supabase
        .from('SpecialHolidays')
        .select('*')
        .order('date', { ascending: false }),
      supabase
        .from('SpecialWorkingDays')
        .select('*')
        .order('date', { ascending: false }),
    ]);

    const filterForSchool = (rows: Record<string, unknown>[]) =>
      rows.filter((r) => {
        if (schoolId === undefined || schoolId === null) return true;
        const sid =
          r.id_school !== undefined && r.id_school !== null
            ? Number(r.id_school)
            : null;
        return sid === null || sid === schoolId;
      });

    const mapRow = (
      r: Record<string, unknown>,
      kind: 'holiday' | 'working_day',
      idx: number,
    ): LeaveSpecialDate => {
      const rawDate = String(r.date ?? r.dateValue ?? '').slice(0, 10);
      const sid =
        r.id_school !== undefined && r.id_school !== null
          ? Number(r.id_school)
          : null;
      const title = String(r.title ?? r.note ?? '-').trim() || '-';
      const pk = Number(
        r.id_holiday ?? r.id_SpecialWorkingDays ?? r.id ?? idx + 1,
      );
      return {
        id: pk,
        id_holiday: pk,
        id_SpecialWorkingDays: pk,
        date: rawDate,
        thaiDateLabel: formatToThaiSlashDate(rawDate),
        title,
        note: String(r.note ?? title).trim(),
        id_school: sid,
        kind,
      };
    };

    const rawHolidays = filterForSchool(
      (holRes.data as Record<string, unknown>[] | null) ?? [],
    );
    const rawWorking = filterForSchool(
      (workRes.data as Record<string, unknown>[] | null) ?? [],
    );

    const holidays = rawHolidays.map((r, i) => mapRow(r, 'holiday', i));
    const workingDays = rawWorking.map((r, i) => mapRow(r, 'working_day', i));

    const todayIso = new Date().toISOString().slice(0, 10);
    const upcomingFromToday = holidays
      .filter((h) => h.date >= todayIso)
      .sort((a, b) => a.date.localeCompare(b.date));
    const upcomingHolidays =
      upcomingFromToday.length > 0 ? upcomingFromToday : holidays.slice(0, 6);

    return {
      holidays,
      workingDays,
      upcomingHolidays,
    };
  } catch {
    return { holidays: [], workingDays: [], upcomingHolidays: [] };
  }
}

/** ดึงสถิติใบลาจริงจากตาราง Leaves และ LeaveTypes ของระบบวันลา (Read-Only, ใช้ PK id_leaves และคอลัมน์ status ตัวเล็ก) */
export async function fetchSchoolLeaveSummary(
  schoolId: number,
): Promise<LeaveSummaryStats> {
  try {
    const [leavesRes, typesRes] = await Promise.all([
      supabase
        .from('Leaves')
        .select('id_leaves, status, id_leaveType')
        .eq('id_school', schoolId),
      supabase.from('LeaveTypes').select('*'),
    ]);

    const typeMap = new Map<number, string>();
    for (const t of (typesRes.data as Record<string, unknown>[] | null) ?? []) {
      const tid = Number(t.id_leaveType ?? t.ID_LeaveTypes ?? t.id ?? 0);
      const tname = String(
        t.leaveName ?? t.leavename ?? t.value ?? t.Value ?? t.name ?? '',
      ).trim();
      if (tid && tname) typeMap.set(tid, tname);
    }

    const rows =
      (leavesRes.data as {
        id_leaves?: number;
        status?: string | null;
        id_leaveType?: number | null;
      }[] | null) ?? [];

    let pendingLeaves = 0;
    let approvedLeaves = 0;
    const countByType = new Map<string, number>();

    for (const r of rows) {
      const st = String(r.status ?? '').trim();
      if (st === 'รอพิจารณา' || st === 'ยังไม่ส่ง') {
        pendingLeaves += 1;
      } else if (st === 'อนุมัติ' || st === 'อนุญาต' || st.includes('อนุมัติ')) {
        approvedLeaves += 1;
      }
      const tName =
        (r.id_leaveType && typeMap.get(Number(r.id_leaveType))) || 'ลาอื่น ๆ';
      countByType.set(tName, (countByType.get(tName) ?? 0) + 1);
    }

    const byType = Array.from(countByType.entries())
      .map(([typeName, count]) => ({ typeName, count }))
      .sort((a, b) => b.count - a.count);

    return {
      totalLeaves: rows.length,
      pendingLeaves,
      approvedLeaves,
      byType,
    };
  } catch {
    return {
      totalLeaves: 0,
      pendingLeaves: 0,
      approvedLeaves: 0,
      byType: [],
    };
  }
}
