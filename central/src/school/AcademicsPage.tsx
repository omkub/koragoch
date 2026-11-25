import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type FormEvent,
} from 'react';
import { Link } from 'react-router-dom';
import {
  BookOpen,
  Calculator,
  Calendar,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Clock,
  Layers,
  Plus,
  Search,
  Trash2,
  User,
  X,
} from 'lucide-react';
import { supabase } from '../supabase';
import {
  fetchLeaveSpecialDates,
  type LeaveSpecialDate,
} from './leaveSystemData';
import type {
  Classroom,
  SchoolDepartment,
  Subject,
  TeacherOption,
  TeachingSchedule,
} from './types';

interface AcademicsPageProps {
  schoolId: number | null;
  canEdit: boolean;
}

const DAYS = [
  { value: 1, label: 'จันทร์', short: 'จ.', headerBg: 'bg-amber-50/70 text-amber-900 border-amber-200/70' },
  { value: 2, label: 'อังคาร', short: 'อ.', headerBg: 'bg-pink-50/70 text-pink-900 border-pink-200/70' },
  { value: 3, label: 'พุธ', short: 'พ.', headerBg: 'bg-emerald-50/70 text-emerald-900 border-emerald-200/70' },
  { value: 4, label: 'พฤหัสบดี', short: 'พฤ.', headerBg: 'bg-orange-50/70 text-orange-900 border-orange-200/70' },
  { value: 5, label: 'ศุกร์', short: 'ศ.', headerBg: 'bg-sky-50/70 text-sky-900 border-sky-200/70' },
];

const PERIODS = [
  { no: 1, time: '08:30–09:20' },
  { no: 2, time: '09:20–10:10' },
  { no: 3, time: '10:10–11:00' },
  { no: 4, time: '11:00–11:50' },
  { no: 5, time: '12:40–13:30' },
  { no: 6, time: '13:30–14:20' },
  { no: 7, time: '14:20–15:10' },
  { no: 8, time: '15:10–16:00' },
];

const GRADE_FILTERS = ['all', 'ม.1', 'ม.2', 'ม.3', 'ม.4', 'ม.5', 'ม.6', 'อื่น ๆ'] as const;
type GradeFilter = (typeof GRADE_FILTERS)[number];

const THAI_SHORT_MONTHS = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

interface CategoryTheme {
  badge: string;
  cardBorder: string;
  cellBg: string;
  accentDot: string;
}

function getDepartmentTheme(deptName: string, subjectCode = ''): CategoryTheme {
  const n = deptName.toLowerCase();
  const c = subjectCode.trim();
  if (n.includes('ภาษาไทย') || c.startsWith('ท')) {
    return {
      badge: 'bg-rose-50 text-rose-700 border-rose-200',
      cardBorder: 'border-l-4 border-l-rose-400',
      cellBg: 'bg-rose-50/90 border-rose-200 text-rose-950 hover:bg-rose-100/80',
      accentDot: 'bg-rose-500',
    };
  }
  if (n.includes('คณิต') || c.startsWith('ค')) {
    return {
      badge: 'bg-blue-50 text-blue-700 border-blue-200',
      cardBorder: 'border-l-4 border-l-blue-500',
      cellBg: 'bg-blue-50/90 border-blue-200 text-blue-950 hover:bg-blue-100/80',
      accentDot: 'bg-blue-500',
    };
  }
  if (n.includes('วิทย') || c.startsWith('ว')) {
    return {
      badge: 'bg-emerald-50 text-emerald-700 border-emerald-200',
      cardBorder: 'border-l-4 border-l-emerald-500',
      cellBg: 'bg-emerald-50/90 border-emerald-200 text-emerald-950 hover:bg-emerald-100/80',
      accentDot: 'bg-emerald-500',
    };
  }
  if (n.includes('สังคม') || c.startsWith('ส')) {
    return {
      badge: 'bg-amber-50 text-amber-800 border-amber-200',
      cardBorder: 'border-l-4 border-l-amber-500',
      cellBg: 'bg-amber-50/90 border-amber-200 text-amber-950 hover:bg-amber-100/80',
      accentDot: 'bg-amber-500',
    };
  }
  if (n.includes('สุขศึกษา') || n.includes('พลศึกษา') || c.startsWith('พ')) {
    return {
      badge: 'bg-teal-50 text-teal-700 border-teal-200',
      cardBorder: 'border-l-4 border-l-teal-500',
      cellBg: 'bg-teal-50/90 border-teal-200 text-teal-950 hover:bg-teal-100/80',
      accentDot: 'bg-teal-500',
    };
  }
  if (n.includes('ศิลปะ') || c.startsWith('ศ')) {
    return {
      badge: 'bg-purple-50 text-purple-700 border-purple-200',
      cardBorder: 'border-l-4 border-l-purple-500',
      cellBg: 'bg-purple-50/90 border-purple-200 text-purple-950 hover:bg-purple-100/80',
      accentDot: 'bg-purple-500',
    };
  }
  if (n.includes('การงาน') || c.startsWith('ง')) {
    return {
      badge: 'bg-orange-50 text-orange-700 border-orange-200',
      cardBorder: 'border-l-4 border-l-orange-400',
      cellBg: 'bg-orange-50/90 border-orange-200 text-orange-950 hover:bg-orange-100/80',
      accentDot: 'bg-orange-500',
    };
  }
  if (n.includes('ต่างประเทศ') || n.includes('อังกฤษ') || c.startsWith('อ')) {
    return {
      badge: 'bg-indigo-50 text-indigo-700 border-indigo-200',
      cardBorder: 'border-l-4 border-l-indigo-500',
      cellBg: 'bg-indigo-50/90 border-indigo-200 text-indigo-950 hover:bg-indigo-100/80',
      accentDot: 'bg-indigo-500',
    };
  }
  return {
    badge: 'bg-slate-100 text-slate-700 border-slate-200',
    cardBorder: 'border-l-4 border-l-slate-400',
    cellBg: 'bg-slate-50 border-slate-200 text-slate-900 hover:bg-slate-100',
    accentDot: 'bg-slate-500',
  };
}

function inferGradeFromSubject(sub: Subject): string {
  const code = sub.code.trim();
  const m = code.match(/(\d{2})/);
  if (m) {
    switch (m[1]) {
      case '21':
        return 'ม.1';
      case '22':
        return 'ม.2';
      case '23':
        return 'ม.3';
      case '31':
        return 'ม.4';
      case '32':
        return 'ม.5';
      case '33':
        return 'ม.6';
    }
  }
  const nameMatch = sub.name.match(/ม\.[1-6]/);
  if (nameMatch) return nameMatch[0];
  return 'อื่น ๆ';
}

function getMondayOfWeek(baseDate: Date, weekOffset: number): Date {
  const d = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate());
  const day = d.getDay(); // 0=Sun .. 6=Sat
  const diffToMon = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diffToMon + weekOffset * 7);
  return d;
}

function toIsoDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function formatThaiDayLabel(d: Date): string {
  return `${d.getDate()} ${THAI_SHORT_MONTHS[d.getMonth()]}`;
}

export default function AcademicsPage({ schoolId, canEdit }: AcademicsPageProps) {
  const [tab, setTab] = useState<'subjects' | 'schedules'>('subjects');
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [departments, setDepartments] = useState<SchoolDepartment[]>([]);
  const [classrooms, setClassrooms] = useState<Classroom[]>([]);
  const [teachers, setTeachers] = useState<TeacherOption[]>([]);
  const [schedules, setSchedules] = useState<TeachingSchedule[]>([]);
  const [holidays, setHolidays] = useState<LeaveSpecialDate[]>([]);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // ── Tab 1: Curriculum / Subjects states ──
  const [showAddSubjectForm, setShowAddSubjectForm] = useState(false);
  const [subjectQuery, setSubjectQuery] = useState('');
  const [gradeFilter, setGradeFilter] = useState<GradeFilter>('all');
  const [deptFilter, setDeptFilter] = useState<string>('all');
  const [collapsedDeptKeys, setCollapsedDeptKeys] = useState<Set<string>>(new Set());

  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [departmentId, setDepartmentId] = useState<string>('');
  const [credits, setCredits] = useState('1.0');

  // ── Tab 2: Calendar Schedule states ──
  const [calendarViewBy, setCalendarViewBy] = useState<'classroom' | 'teacher'>('classroom');
  const [selectedClassroomId, setSelectedClassroomId] = useState<string>('');
  const [selectedTeacherId, setSelectedTeacherId] = useState<string>('');
  const [weekOffset, setWeekOffset] = useState<number>(0);
  const [showAddScheduleForm, setShowAddScheduleForm] = useState(false);

  const [schedSubjectId, setSchedSubjectId] = useState<string>('');
  const [schedTeacherId, setSchedTeacherId] = useState<string>('');
  const [schedDay, setSchedDay] = useState<string>('1');
  const [schedPeriod, setSchedPeriod] = useState<string>('1');
  const [schedRoom, setSchedRoom] = useState('');

  const loadAll = useCallback(async () => {
    if (!schoolId) return;
    const [subRes, deptRes, clsRes, tchRes, schRes, specialDatesRes] =
      await Promise.all([
        supabase
          .from('SchoolWebSubjects')
          .select('id, id_school, code, name, department_id, credits, is_active')
          .eq('id_school', schoolId)
          .order('code', { ascending: true }),
        supabase
          .from('SchoolDepartments')
          .select('id, id_school, code, name, category, sort_order, is_active')
          .eq('id_school', schoolId)
          .eq('is_active', true)
          .order('sort_order', { ascending: true }),
        supabase
          .from('SchoolWebClassrooms')
          .select(
            'id, id_school, academic_year_id, grade_level, room_no, name, advisor_teacher_id, is_active',
          )
          .eq('id_school', schoolId)
          .order('name', { ascending: true }),
        supabase
          .from('Teachers')
          .select('id_user, fullName')
          .eq('id_school', schoolId)
          .order('fullName', { ascending: true }),
        supabase
          .from('SchoolWebTeachingSchedules')
          .select(
            'id, id_school, academic_term_id, classroom_id, subject_id, teacher_id, day_of_week, period_no, room_name',
          )
          .eq('id_school', schoolId)
          .order('day_of_week', { ascending: true })
          .order('period_no', { ascending: true }),
        fetchLeaveSpecialDates(schoolId),
      ]);

    if (subRes.error) setError(subRes.error.message);
    else setSubjects((subRes.data as Subject[] | null) ?? []);

    if (!deptRes.error) {
      setDepartments((deptRes.data as SchoolDepartment[] | null) ?? []);
    }
    if (!clsRes.error) {
      const clsList = (clsRes.data as Classroom[] | null) ?? [];
      setClassrooms(clsList);
      setSelectedClassroomId((prev) => prev || (clsList[0] ? String(clsList[0].id) : ''));
    }
    if (!tchRes.error) {
      const tchList = (tchRes.data as TeacherOption[] | null) ?? [];
      setTeachers(tchList);
      setSelectedTeacherId((prev) => prev || (tchList[0] ? String(tchList[0].id_user) : ''));
    }
    if (!schRes.error) {
      setSchedules((schRes.data as TeachingSchedule[] | null) ?? []);
    }
    setHolidays(specialDatesRes.holidays);
  }, [schoolId]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  const deptMap = useMemo(() => {
    const map = new Map<number, SchoolDepartment>();
    for (const d of departments) map.set(d.id, d);
    return map;
  }, [departments]);

  const subjectMap = useMemo(() => {
    const map = new Map<number, Subject>();
    for (const s of subjects) map.set(s.id, s);
    return map;
  }, [subjects]);

  const classroomMap = useMemo(() => {
    const map = new Map<number, Classroom>();
    for (const c of classrooms) map.set(c.id, c);
    return map;
  }, [classrooms]);

  const teacherMap = useMemo(() => {
    const map = new Map<number, string>();
    for (const t of teachers) map.set(t.id_user, t.fullName || '-');
    return map;
  }, [teachers]);

  const holidayByIso = useMemo(() => {
    const map = new Map<string, LeaveSpecialDate>();
    for (const h of holidays) {
      if (!map.has(h.date)) map.set(h.date, h);
    }
    return map;
  }, [holidays]);

  // ── Tab 1: Grouped Subjects by Department / Learning Area ──
  const { groupedSubjects, filteredSubjectCount, filteredTotalCredits } = useMemo(() => {
    const q = subjectQuery.trim().toLowerCase();
    const filtered = subjects.filter((s) => {
      if (deptFilter !== 'all') {
        if (deptFilter === 'none') {
          if (s.department_id) return false;
        } else if (String(s.department_id ?? '') !== deptFilter) {
          return false;
        }
      }
      if (gradeFilter !== 'all' && inferGradeFromSubject(s) !== gradeFilter) {
        return false;
      }
      if (q) {
        const dName = s.department_id ? deptMap.get(s.department_id)?.name ?? '' : '';
        if (
          !s.code.toLowerCase().includes(q) &&
          !s.name.toLowerCase().includes(q) &&
          !dName.toLowerCase().includes(q)
        ) {
          return false;
        }
      }
      return true;
    });

    const buckets = new Map<
      string,
      { key: string; title: string; sortOrder: number; items: Subject[]; totalCredits: number }
    >();

    for (const s of filtered) {
      const dept = s.department_id ? deptMap.get(s.department_id) : undefined;
      const key = dept ? `dept-${dept.id}` : 'dept-none';
      const title = dept?.name || 'ยังไม่ระบุกลุ่มสาระการเรียนรู้';
      const sortOrder = dept ? dept.sort_order : 9999;

      const existing = buckets.get(key);
      if (existing) {
        existing.items.push(s);
        existing.totalCredits += Number(s.credits) || 0;
      } else {
        buckets.set(key, {
          key,
          title,
          sortOrder,
          items: [s],
          totalCredits: Number(s.credits) || 0,
        });
      }
    }

    const groups = Array.from(buckets.values()).sort(
      (a, b) => a.sortOrder - b.sortOrder || a.title.localeCompare(b.title, 'th'),
    );

    const totalCredits = filtered.reduce((acc, s) => acc + (Number(s.credits) || 0), 0);

    return {
      groupedSubjects: groups,
      filteredSubjectCount: filtered.length,
      filteredTotalCredits: totalCredits,
    };
  }, [subjects, deptMap, subjectQuery, gradeFilter, deptFilter]);

  const toggleDeptCollapse = (key: string) => {
    setCollapsedDeptKeys((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  // ── Tab 2: Calendar Timetable Data ──
  const weekDaysWithDate = useMemo(() => {
    const monday = getMondayOfWeek(new Date(), weekOffset);
    const todayIso = toIsoDate(new Date());
    return DAYS.map((d, idx) => {
      const dt = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + idx);
      const iso = toIsoDate(dt);
      return {
        ...d,
        dateObj: dt,
        iso,
        thaiLabel: formatThaiDayLabel(dt),
        isToday: iso === todayIso,
        holiday: holidayByIso.get(iso) ?? null,
      };
    });
  }, [weekOffset, holidayByIso]);

  const weekRangeLabel = useMemo(() => {
    const first = weekDaysWithDate[0];
    const last = weekDaysWithDate[weekDaysWithDate.length - 1];
    if (!first || !last) return '';
    const yearBe = last.dateObj.getFullYear() + 543;
    return `${first.thaiLabel} – ${last.thaiLabel} ${yearBe}`;
  }, [weekDaysWithDate]);

  const activeSchedules = useMemo(() => {
    if (calendarViewBy === 'classroom') {
      const cid = Number(selectedClassroomId);
      if (!cid) return [];
      return schedules.filter((s) => s.classroom_id === cid);
    }
    const tid = Number(selectedTeacherId);
    if (!tid) return [];
    return schedules.filter((s) => s.teacher_id === tid);
  }, [schedules, calendarViewBy, selectedClassroomId, selectedTeacherId]);

  // Map day_of_week -> period_no -> TeachingSchedule[]
  const calendarCellMap = useMemo(() => {
    const map = new Map<string, TeachingSchedule[]>();
    for (const s of activeSchedules) {
      const k = `${s.day_of_week}-${s.period_no}`;
      const list = map.get(k) ?? [];
      list.push(s);
      map.set(k, list);
    }
    return map;
  }, [activeSchedules]);

  // ── Handlers ──
  async function handleAddSubject(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    const { error: insErr } = await supabase.from('SchoolWebSubjects').insert({
      id_school: schoolId,
      code: code.trim(),
      name: name.trim(),
      department_id: departmentId ? Number(departmentId) : null,
      credits: Number(credits) || 1.0,
      is_active: true,
    });

    if (insErr) {
      setError(insErr.message);
    } else {
      setCode('');
      setName('');
      await loadAll();
    }
    setBusy(false);
  }

  async function removeSubject(id: number) {
    if (!canEdit) return;
    setBusy(true);
    const { error: delErr } = await supabase
      .from('SchoolWebSubjects')
      .delete()
      .eq('id', id);
    if (delErr) setError(delErr.message);
    else await loadAll();
    setBusy(false);
  }

  async function handleAddSchedule(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit || !selectedClassroomId || !schedSubjectId) return;
    setBusy(true);
    setError(null);

    const { error: insErr } = await supabase.from('SchoolWebTeachingSchedules').insert({
      id_school: schoolId,
      classroom_id: Number(selectedClassroomId),
      subject_id: Number(schedSubjectId),
      teacher_id: schedTeacherId ? Number(schedTeacherId) : null,
      day_of_week: Number(schedDay),
      period_no: Number(schedPeriod),
      room_name: schedRoom.trim() || null,
    });

    if (insErr) {
      setError(insErr.message);
    } else {
      setSchedRoom('');
      setShowAddScheduleForm(false);
      await loadAll();
    }
    setBusy(false);
  }

  async function removeSchedule(id: number) {
    if (!canEdit) return;
    setBusy(true);
    const { error: delErr } = await supabase
      .from('SchoolWebTeachingSchedules')
      .delete()
      .eq('id', id);
    if (delErr) setError(delErr.message);
    else await loadAll();
    setBusy(false);
  }

  const openQuickAddSlot = (dayVal: number, periodNo: number) => {
    if (!canEdit) return;
    setSchedDay(String(dayVal));
    setSchedPeriod(String(periodNo));
    if (calendarViewBy === 'teacher' && selectedTeacherId) {
      setSchedTeacherId(selectedTeacherId);
    }
    setShowAddScheduleForm(true);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-ink">
            หลักสูตรและตารางสอน
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            จัดการรายวิชาแยกตามหมวดหมู่กลุ่มสาระการเรียนรู้ และตารางสอนในรูปแบบปฏิทินรายสัปดาห์
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Link
            to="/school/division/academic/students-classrooms"
            className="btn-secondary btn-sm"
          >
            <Calculator className="h-3.5 w-3.5 text-brand-600" />
            <span>ไปหน้าบันทึกคะแนนและผลการเรียน SGS</span>
          </Link>

          <div className="inline-flex rounded-xl border border-line bg-white p-1 shadow-2xs">
            <button
              type="button"
              onClick={() => setTab('subjects')}
              className={`inline-flex items-center gap-1.5 rounded-lg px-3.5 py-1.5 text-sm font-medium transition-colors ${
                tab === 'subjects'
                  ? 'bg-brand-600 text-white shadow-xs'
                  : 'text-slate-600 hover:text-ink'
              }`}
            >
              <BookOpen className="h-4 w-4" />
              <span>หลักสูตรและรายวิชา ({subjects.length})</span>
            </button>
            <button
              type="button"
              onClick={() => setTab('schedules')}
              className={`inline-flex items-center gap-1.5 rounded-lg px-3.5 py-1.5 text-sm font-medium transition-colors ${
                tab === 'schedules'
                  ? 'bg-brand-600 text-white shadow-xs'
                  : 'text-slate-600 hover:text-ink'
              }`}
            >
              <Calendar className="h-4 w-4" />
              <span>ปฏิทินตารางสอน</span>
            </button>
          </div>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {tab === 'subjects' ? (
        /* =====================================================================
           TAB 1: หลักสูตรและรายวิชา (แยกเป็นหมวดหมู่ตามกลุ่มสาระการเรียนรู้)
           ===================================================================== */
        <div className="space-y-5">
          {/* Summary + Filter Toolbar */}
          <section className="surface-card p-5 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex flex-wrap items-center gap-3">
                <div className="relative min-w-[240px] flex-1 sm:w-72">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    value={subjectQuery}
                    onChange={(e) => setSubjectQuery(e.target.value)}
                    placeholder="ค้นหารหัสวิชา ชื่อวิชา หรือกลุ่มสาระ..."
                    className="input pl-9"
                  />
                </div>
                <select
                  value={deptFilter}
                  onChange={(e) => setDeptFilter(e.target.value)}
                  className="input w-full sm:w-64"
                >
                  <option value="all">ทุกหมวดหมู่ / กลุ่มสาระ ({departments.length})</option>
                  {departments.map((d) => (
                    <option key={d.id} value={String(d.id)}>
                      {d.name}
                    </option>
                  ))}
                  <option value="none">ยังไม่ระบุกลุ่มสาระ</option>
                </select>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-lg bg-brand-50 px-2.5 py-1.5 text-xs font-semibold text-brand-700 tabular-nums">
                  {filteredSubjectCount} วิชา · {groupedSubjects.length} หมวดหมู่ ·{' '}
                  {filteredTotalCredits.toFixed(1)} หน่วยกิต
                </span>
                <button
                  type="button"
                  onClick={() => setCollapsedDeptKeys(new Set())}
                  className="btn-secondary btn-sm"
                >
                  ขยายทั้งหมด
                </button>
                <button
                  type="button"
                  onClick={() =>
                    setCollapsedDeptKeys(new Set(groupedSubjects.map((g) => g.key)))
                  }
                  className="btn-secondary btn-sm"
                >
                  ยุบทั้งหมด
                </button>
                {canEdit && (
                  <button
                    type="button"
                    onClick={() => setShowAddSubjectForm((v) => !v)}
                    className="btn-primary btn-sm"
                  >
                    {showAddSubjectForm ? (
                      <>
                        <X className="h-3.5 w-3.5" />
                        <span>ปิดฟอร์ม</span>
                      </>
                    ) : (
                      <>
                        <Plus className="h-3.5 w-3.5" />
                        <span>เพิ่มรายวิชา</span>
                      </>
                    )}
                  </button>
                )}
              </div>
            </div>

            {/* Grade Level Filter Pills */}
            <div className="flex flex-wrap items-center gap-1.5 border-t border-line pt-3">
              <span className="mr-1 text-xs font-medium text-slate-500">ระดับชั้น:</span>
              {GRADE_FILTERS.map((g) => (
                <button
                  key={g}
                  type="button"
                  onClick={() => setGradeFilter(g)}
                  className={`rounded-lg border px-2.5 py-1 text-xs font-medium transition-colors ${
                    gradeFilter === g
                      ? 'border-brand-300 bg-brand-50 text-brand-700'
                      : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                  }`}
                >
                  {g === 'all' ? 'ทุกระดับชั้น' : g}
                </button>
              ))}
            </div>

            {/* Collapsible Add Subject Form */}
            {canEdit && showAddSubjectForm && (
              <form
                onSubmit={handleAddSubject}
                className="grid gap-3 rounded-xl border border-brand-200 bg-brand-50/30 p-4 sm:grid-cols-12"
              >
                <div className="sm:col-span-2">
                  <label className="mb-1 block text-xs font-medium text-ink">
                    รหัสวิชา *
                  </label>
                  <input
                    type="text"
                    required
                    value={code}
                    onChange={(e) => setCode(e.target.value)}
                    placeholder="ว21101"
                    className="input bg-white"
                  />
                </div>
                <div className="sm:col-span-4">
                  <label className="mb-1 block text-xs font-medium text-ink">
                    ชื่อรายวิชา *
                  </label>
                  <input
                    type="text"
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="วิทยาศาสตร์พื้นฐาน 1"
                    className="input bg-white"
                  />
                </div>
                <div className="sm:col-span-3">
                  <label className="mb-1 block text-xs font-medium text-ink">
                    หมวดหมู่ / กลุ่มสาระ
                  </label>
                  <select
                    value={departmentId}
                    onChange={(e) => setDepartmentId(e.target.value)}
                    className="input bg-white"
                  >
                    <option value="">ไม่ระบุ</option>
                    {departments.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-1">
                  <label className="mb-1 block text-xs font-medium text-ink">
                    หน่วยกิต
                  </label>
                  <input
                    type="number"
                    step="0.5"
                    min="0.5"
                    value={credits}
                    onChange={(e) => setCredits(e.target.value)}
                    className="input bg-white tabular-nums"
                  />
                </div>
                <div className="flex items-end sm:col-span-2">
                  <button type="submit" disabled={busy} className="btn-primary w-full">
                    <Plus className="h-4 w-4" strokeWidth={1.5} />
                    <span>บันทึกวิชา</span>
                  </button>
                </div>
              </form>
            )}
          </section>

          {/* Categorized Subject Cards */}
          {groupedSubjects.length === 0 ? (
            <div className="surface-card p-10 text-center text-sm text-slate-500">
              ไม่พบรายวิชาที่ตรงกับเงื่อนไขการค้นหา
            </div>
          ) : (
            <div className="space-y-4">
              {groupedSubjects.map((group) => {
                const isCollapsed =
                  collapsedDeptKeys.has(group.key) && !subjectQuery.trim();
                const theme = getDepartmentTheme(group.title);

                return (
                  <section
                    key={group.key}
                    className={`surface-card overflow-hidden ${theme.cardBorder}`}
                  >
                    <button
                      type="button"
                      onClick={() => toggleDeptCollapse(group.key)}
                      className="flex w-full flex-wrap items-center justify-between gap-3 border-b border-line bg-slate-50/70 px-5 py-3.5 text-left hover:bg-slate-100/60 transition-colors"
                    >
                      <div className="flex items-center gap-2.5">
                        {isCollapsed ? (
                          <ChevronRight className="h-4 w-4 text-slate-500" />
                        ) : (
                          <ChevronDown className="h-4 w-4 text-slate-500" />
                        )}
                        <span className={`h-2.5 w-2.5 rounded-full ${theme.accentDot}`} />
                        <h2 className="text-sm font-semibold text-ink">{group.title}</h2>
                        <span
                          className={`rounded-full border px-2.5 py-0.5 text-[11px] font-semibold tabular-nums ${theme.badge}`}
                        >
                          {group.items.length} รายวิชา
                        </span>
                      </div>
                      <span className="text-xs font-medium text-slate-500 tabular-nums">
                        รวม {group.totalCredits.toFixed(1)} หน่วยกิต
                      </span>
                    </button>

                    {!isCollapsed && (
                      <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm">
                          <thead className="border-b border-line bg-white text-xs font-medium text-slate-500">
                            <tr>
                              <th className="w-28 px-5 py-2.5">รหัสวิชา</th>
                              <th className="px-4 py-2.5">ชื่อรายวิชา</th>
                              <th className="w-24 px-4 py-2.5 text-center">ระดับชั้น</th>
                              <th className="w-24 px-4 py-2.5 text-right">หน่วยกิต</th>
                              {canEdit && (
                                <th className="w-20 px-4 py-2.5 text-right">จัดการ</th>
                              )}
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-line">
                            {group.items.map((sub) => {
                              const gradeTag = inferGradeFromSubject(sub);
                              return (
                                <tr key={sub.id} className="hover:bg-slate-50/60">
                                  <td className="px-5 py-2.5 font-semibold tabular-nums text-brand-700">
                                    {sub.code}
                                  </td>
                                  <td className="px-4 py-2.5 font-medium text-ink">
                                    {sub.name}
                                  </td>
                                  <td className="px-4 py-2.5 text-center">
                                    <span className="inline-flex rounded bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">
                                      {gradeTag}
                                    </span>
                                  </td>
                                  <td className="px-4 py-2.5 text-right font-medium tabular-nums text-slate-600">
                                    {Number(sub.credits).toFixed(1)}
                                  </td>
                                  {canEdit && (
                                    <td className="px-4 py-2.5 text-right">
                                      <button
                                        type="button"
                                        disabled={busy}
                                        onClick={() => removeSubject(sub.id)}
                                        className="rounded p-1 text-slate-400 hover:bg-red-50 hover:text-red-600"
                                        title="ลบรายวิชา"
                                      >
                                        <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                                      </button>
                                    </td>
                                  )}
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </section>
                );
              })}
            </div>
          )}
        </div>
      ) : (
        /* =====================================================================
           TAB 2: ปฏิทินตารางสอนรายสัปดาห์ (Weekly Calendar Timetable Grid)
           ===================================================================== */
        <div className="space-y-5">
          {/* Calendar Toolbar */}
          <section className="surface-card p-5 space-y-4">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              {/* Left: View Mode (Classroom / Teacher) + Selector */}
              <div className="flex flex-wrap items-center gap-2.5">
                <div className="inline-flex rounded-lg border border-line bg-slate-50 p-0.5">
                  <button
                    type="button"
                    onClick={() => setCalendarViewBy('classroom')}
                    className={`inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium transition-colors ${
                      calendarViewBy === 'classroom'
                        ? 'bg-white text-brand-700 shadow-2xs'
                        : 'text-slate-600 hover:text-ink'
                    }`}
                  >
                    <Layers className="h-3.5 w-3.5" />
                    <span>ตารางตามห้องเรียน</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setCalendarViewBy('teacher')}
                    className={`inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium transition-colors ${
                      calendarViewBy === 'teacher'
                        ? 'bg-white text-brand-700 shadow-2xs'
                        : 'text-slate-600 hover:text-ink'
                    }`}
                  >
                    <User className="h-3.5 w-3.5" />
                    <span>ตารางตามครูผู้สอน</span>
                  </button>
                </div>

                {calendarViewBy === 'classroom' ? (
                  <select
                    value={selectedClassroomId}
                    onChange={(e) => setSelectedClassroomId(e.target.value)}
                    className="input w-48 font-medium"
                  >
                    {classrooms.length === 0 ? (
                      <option value="">ยังไม่มีห้องเรียน</option>
                    ) : (
                      classrooms.map((c) => (
                        <option key={c.id} value={c.id}>
                          ห้อง {c.name}
                        </option>
                      ))
                    )}
                  </select>
                ) : (
                  <select
                    value={selectedTeacherId}
                    onChange={(e) => setSelectedTeacherId(e.target.value)}
                    className="input w-64 font-medium"
                  >
                    {teachers.length === 0 ? (
                      <option value="">ยังไม่มีข้อมูลครู</option>
                    ) : (
                      teachers.map((t) => (
                        <option key={t.id_user} value={t.id_user}>
                          {t.fullName || `ครู #${t.id_user}`}
                        </option>
                      ))
                    )}
                  </select>
                )}

                <span className="rounded-lg bg-brand-50 px-2.5 py-1.5 text-xs font-semibold text-brand-700 tabular-nums">
                  {activeSchedules.length} คาบ / สัปดาห์
                </span>
              </div>

              {/* Right: Week Navigation + Add Slot */}
              <div className="flex flex-wrap items-center gap-2">
                <div className="inline-flex items-center rounded-lg border border-line bg-white">
                  <button
                    type="button"
                    onClick={() => setWeekOffset((w) => w - 1)}
                    className="p-1.5 text-slate-600 hover:bg-slate-50 hover:text-ink"
                    title="สัปดาห์ก่อนหน้า"
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </button>
                  <button
                    type="button"
                    onClick={() => setWeekOffset(0)}
                    className="border-x border-line px-3 py-1.5 text-xs font-semibold text-ink hover:bg-slate-50 tabular-nums"
                    title="กลับไปสัปดาห์ปัจจุบัน"
                  >
                    {weekRangeLabel}
                  </button>
                  <button
                    type="button"
                    onClick={() => setWeekOffset((w) => w + 1)}
                    className="p-1.5 text-slate-600 hover:bg-slate-50 hover:text-ink"
                    title="สัปดาห์ถัดไป"
                  >
                    <ChevronRight className="h-4 w-4" />
                  </button>
                </div>

                {canEdit && (
                  <button
                    type="button"
                    onClick={() => setShowAddScheduleForm((v) => !v)}
                    className="btn-primary btn-sm"
                  >
                    {showAddScheduleForm ? (
                      <>
                        <X className="h-3.5 w-3.5" />
                        <span>ปิดฟอร์ม</span>
                      </>
                    ) : (
                      <>
                        <Plus className="h-3.5 w-3.5" />
                        <span>เพิ่มคาบสอน</span>
                      </>
                    )}
                  </button>
                )}
              </div>
            </div>

            {/* Quick Add Schedule Form */}
            {canEdit && showAddScheduleForm && (
              <form
                onSubmit={handleAddSchedule}
                className="grid gap-3 rounded-xl border border-brand-200 bg-brand-50/30 p-4 sm:grid-cols-12"
              >
                {calendarViewBy === 'teacher' && (
                  <div className="sm:col-span-2">
                    <label className="mb-1 block text-xs font-medium text-ink">
                      ห้องเรียน *
                    </label>
                    <select
                      required
                      value={selectedClassroomId}
                      onChange={(e) => setSelectedClassroomId(e.target.value)}
                      className="input bg-white"
                    >
                      <option value="">เลือกห้อง</option>
                      {classrooms.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}
                <div className={calendarViewBy === 'teacher' ? 'sm:col-span-3' : 'sm:col-span-4'}>
                  <label className="mb-1 block text-xs font-medium text-ink">
                    รายวิชา *
                  </label>
                  <select
                    required
                    value={schedSubjectId}
                    onChange={(e) => setSchedSubjectId(e.target.value)}
                    className="input bg-white"
                  >
                    <option value="">เลือกรายวิชา</option>
                    {subjects.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.code} {s.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-3">
                  <label className="mb-1 block text-xs font-medium text-ink">
                    ครูผู้สอน
                  </label>
                  <select
                    value={schedTeacherId}
                    onChange={(e) => setSchedTeacherId(e.target.value)}
                    className="input bg-white"
                  >
                    <option value="">ยังไม่ระบุ</option>
                    {teachers.map((t) => (
                      <option key={t.id_user} value={t.id_user}>
                        {t.fullName || `ครู #${t.id_user}`}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-1">
                  <label className="mb-1 block text-xs font-medium text-ink">
                    วัน
                  </label>
                  <select
                    value={schedDay}
                    onChange={(e) => setSchedDay(e.target.value)}
                    className="input bg-white"
                  >
                    {DAYS.map((d) => (
                      <option key={d.value} value={d.value}>
                        {d.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-1">
                  <label className="mb-1 block text-xs font-medium text-ink">
                    คาบ
                  </label>
                  <select
                    value={schedPeriod}
                    onChange={(e) => setSchedPeriod(e.target.value)}
                    className="input bg-white tabular-nums"
                  >
                    {PERIODS.map((p) => (
                      <option key={p.no} value={p.no}>
                        {p.no}
                      </option>
                    ))}
                  </select>
                </div>
                <div className={calendarViewBy === 'teacher' ? 'sm:col-span-1' : 'sm:col-span-1'}>
                  <label className="mb-1 block text-xs font-medium text-ink">
                    ห้อง
                  </label>
                  <input
                    type="text"
                    value={schedRoom}
                    onChange={(e) => setSchedRoom(e.target.value)}
                    placeholder="211"
                    className="input bg-white"
                  />
                </div>
                <div className={calendarViewBy === 'teacher' ? 'flex items-end sm:col-span-1' : 'flex items-end sm:col-span-2'}>
                  <button type="submit" disabled={busy} className="btn-primary w-full">
                    <Plus className="h-4 w-4" strokeWidth={1.5} />
                    <span>บันทึก</span>
                  </button>
                </div>
              </form>
            )}
          </section>

          {/* Calendar Grid Table */}
          <section className="surface-card overflow-hidden">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b border-line bg-slate-50/70 px-5 py-3">
              <div className="flex items-center gap-2 text-sm font-semibold text-ink">
                <Calendar className="h-4 w-4 text-brand-600" />
                <span>
                  ปฏิทินตารางสอนประจำสัปดาห์ ·{' '}
                  {calendarViewBy === 'classroom'
                    ? `ห้อง ${classroomMap.get(Number(selectedClassroomId))?.name || '-'}`
                    : teacherMap.get(Number(selectedTeacherId)) || '-'}
                </span>
              </div>
              <div className="flex items-center gap-2 text-[11px] text-slate-500">
                <Clock className="h-3.5 w-3.5" />
                <span>คลิกช่องว่างเพื่อเพิ่มคาบสอน · ซิงค์วันหยุดจากระบบวันลาอัตโนมัติ</span>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full min-w-[980px] border-collapse text-left">
                <thead>
                  <tr className="border-b border-line bg-canvas text-xs text-slate-600">
                    <th className="w-32 border-r border-line px-3 py-3 font-semibold text-ink">
                      วัน / วันที่
                    </th>
                    {PERIODS.slice(0, 4).map((p) => (
                      <th
                        key={p.no}
                        className="border-r border-line px-2 py-2.5 text-center"
                      >
                        <div className="font-semibold text-ink">คาบที่ {p.no}</div>
                        <div className="mt-0.5 text-[10px] font-normal text-slate-500 tabular-nums">
                          {p.time}
                        </div>
                      </th>
                    ))}
                    <th className="w-10 border-r border-line bg-slate-100/80 px-1 py-2.5 text-center text-[10px] font-semibold text-slate-500">
                      พัก
                      <div className="font-normal">11:50</div>
                    </th>
                    {PERIODS.slice(4).map((p) => (
                      <th
                        key={p.no}
                        className="border-r border-line px-2 py-2.5 text-center last:border-r-0"
                      >
                        <div className="font-semibold text-ink">คาบที่ {p.no}</div>
                        <div className="mt-0.5 text-[10px] font-normal text-slate-500 tabular-nums">
                          {p.time}
                        </div>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {weekDaysWithDate.map((day) => (
                    <tr
                      key={day.value}
                      className={day.holiday ? 'bg-red-50/20' : 'bg-white'}
                    >
                      {/* Day + Date Cell */}
                      <td
                        className={`border-r border-line px-3 py-3 align-top ${day.headerBg}`}
                      >
                        <div className="flex items-center justify-between gap-1">
                          <span className="text-sm font-bold">{day.label}</span>
                          {day.isToday && (
                            <span className="rounded bg-brand-600 px-1.5 py-0.5 text-[10px] font-semibold text-white">
                              วันนี้
                            </span>
                          )}
                        </div>
                        <div className="mt-0.5 text-xs opacity-80 tabular-nums">
                          {day.thaiLabel}
                        </div>
                        {day.holiday && (
                          <div className="mt-1.5 rounded bg-red-100 px-1.5 py-0.5 text-[10px] font-semibold text-red-700">
                            วันหยุด: {day.holiday.title}
                          </div>
                        )}
                      </td>

                      {/* Periods 1..4 */}
                      {PERIODS.slice(0, 4).map((p) => {
                        const cellItems =
                          calendarCellMap.get(`${day.value}-${p.no}`) ?? [];
                        return (
                          <td
                            key={p.no}
                            className="h-24 w-[11%] border-r border-line p-1.5 align-top"
                          >
                            {cellItems.length === 0 ? (
                              canEdit ? (
                                <button
                                  type="button"
                                  onClick={() => openQuickAddSlot(day.value, p.no)}
                                  className="flex h-full min-h-[76px] w-full items-center justify-center rounded-lg border border-dashed border-transparent text-slate-300 transition-colors hover:border-brand-300 hover:bg-brand-50/40 hover:text-brand-600"
                                  title={`เพิ่มคาบสอน วัน${day.label} คาบที่ ${p.no}`}
                                >
                                  <Plus className="h-4 w-4" />
                                </button>
                              ) : (
                                <div className="h-full min-h-[76px]" />
                              )
                            ) : (
                              <div className="space-y-1">
                                {cellItems.map((item) => {
                                  const sub = subjectMap.get(item.subject_id);
                                  const deptName = sub?.department_id
                                    ? deptMap.get(sub.department_id)?.name ?? ''
                                    : '';
                                  const theme = getDepartmentTheme(
                                    deptName,
                                    sub?.code ?? '',
                                  );
                                  const roomCls = classroomMap.get(item.classroom_id);
                                  return (
                                    <div
                                      key={item.id}
                                      className={`group relative rounded-lg border p-2 text-xs transition-colors ${theme.cellBg}`}
                                    >
                                      {canEdit && (
                                        <button
                                          type="button"
                                          disabled={busy}
                                          onClick={() => removeSchedule(item.id)}
                                          className="absolute right-1 top-1 hidden rounded bg-white/90 p-0.5 text-red-600 shadow-2xs hover:bg-red-50 group-hover:block"
                                          title="ลบคาบสอนนี้"
                                        >
                                          <Trash2 className="h-3 w-3" />
                                        </button>
                                      )}
                                      <div className="font-bold tabular-nums leading-tight">
                                        {sub?.code || '-'}
                                      </div>
                                      <div
                                        className="mt-0.5 line-clamp-2 text-[11px] font-medium leading-snug"
                                        title={sub?.name}
                                      >
                                        {sub?.name || '-'}
                                      </div>
                                      <div className="mt-1 truncate text-[10px] opacity-75">
                                        {calendarViewBy === 'classroom'
                                          ? item.teacher_id
                                            ? teacherMap.get(item.teacher_id) || '-'
                                            : '-'
                                          : `ห้อง ${roomCls?.name || '-'}`}
                                      </div>
                                      {item.room_name && (
                                        <div className="truncate text-[10px] font-medium opacity-70">
                                          {item.room_name}
                                        </div>
                                      )}
                                    </div>
                                  );
                                })}
                              </div>
                            )}
                          </td>
                        );
                      })}

                      {/* Lunch Break Column */}
                      <td className="border-r border-line bg-slate-100/60 text-center align-middle">
                        <span className="inline-block -rotate-90 whitespace-nowrap text-[10px] font-medium tracking-wider text-slate-400">
                          พักกลางวัน
                        </span>
                      </td>

                      {/* Periods 5..8 */}
                      {PERIODS.slice(4).map((p) => {
                        const cellItems =
                          calendarCellMap.get(`${day.value}-${p.no}`) ?? [];
                        return (
                          <td
                            key={p.no}
                            className="h-24 w-[11%] border-r border-line p-1.5 align-top last:border-r-0"
                          >
                            {cellItems.length === 0 ? (
                              canEdit ? (
                                <button
                                  type="button"
                                  onClick={() => openQuickAddSlot(day.value, p.no)}
                                  className="flex h-full min-h-[76px] w-full items-center justify-center rounded-lg border border-dashed border-transparent text-slate-300 transition-colors hover:border-brand-300 hover:bg-brand-50/40 hover:text-brand-600"
                                  title={`เพิ่มคาบสอน วัน${day.label} คาบที่ ${p.no}`}
                                >
                                  <Plus className="h-4 w-4" />
                                </button>
                              ) : (
                                <div className="h-full min-h-[76px]" />
                              )
                            ) : (
                              <div className="space-y-1">
                                {cellItems.map((item) => {
                                  const sub = subjectMap.get(item.subject_id);
                                  const deptName = sub?.department_id
                                    ? deptMap.get(sub.department_id)?.name ?? ''
                                    : '';
                                  const theme = getDepartmentTheme(
                                    deptName,
                                    sub?.code ?? '',
                                  );
                                  const roomCls = classroomMap.get(item.classroom_id);
                                  return (
                                    <div
                                      key={item.id}
                                      className={`group relative rounded-lg border p-2 text-xs transition-colors ${theme.cellBg}`}
                                    >
                                      {canEdit && (
                                        <button
                                          type="button"
                                          disabled={busy}
                                          onClick={() => removeSchedule(item.id)}
                                          className="absolute right-1 top-1 hidden rounded bg-white/90 p-0.5 text-red-600 shadow-2xs hover:bg-red-50 group-hover:block"
                                          title="ลบคาบสอนนี้"
                                        >
                                          <Trash2 className="h-3 w-3" />
                                        </button>
                                      )}
                                      <div className="font-bold tabular-nums leading-tight">
                                        {sub?.code || '-'}
                                      </div>
                                      <div
                                        className="mt-0.5 line-clamp-2 text-[11px] font-medium leading-snug"
                                        title={sub?.name}
                                      >
                                        {sub?.name || '-'}
                                      </div>
                                      <div className="mt-1 truncate text-[10px] opacity-75">
                                        {calendarViewBy === 'classroom'
                                          ? item.teacher_id
                                            ? teacherMap.get(item.teacher_id) || '-'
                                            : '-'
                                          : `ห้อง ${roomCls?.name || '-'}`}
                                      </div>
                                      {item.room_name && (
                                        <div className="truncate text-[10px] font-medium opacity-70">
                                          {item.room_name}
                                        </div>
                                      )}
                                    </div>
                                  );
                                })}
                              </div>
                            )}
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
