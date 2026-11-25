import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Save } from 'lucide-react';
import { supabase } from '../supabase';
import { EmptyState } from '../ui/components';
import {
  computeSgsGradeRow,
  saveSgsGradeRecords,
  SGS_GRADE_LEVELS,
  type SgsGradeLevel,
  type SgsLearningArea,
  type SgsScoreRecord,
  type SgsSubjectType,
} from './sgsGradingStore';

/**
 * งานของฉัน → กรอกคะแนนวิชาที่ฉันสอน
 * แสดงเฉพาะคู่ (ห้อง, วิชา) ที่ครูมีคาบในตารางสอน
 * ฐานข้อมูลกันซ้ำด้วย policy school_web_sgs_grades_teacher_write (school_web_teacher_grades.sql)
 */

interface CourseOption {
  key: string;
  classroomId: number;
  classroomName: string;
  gradeLevel: SgsGradeLevel;
  subjectCode: string;
  subjectName: string;
  credits: number;
}

interface StudentRow {
  id: number;
  student_code: string;
  prefix: string | null;
  first_name: string;
  last_name: string;
}

type ScoreField =
  | 'pre_mid_work'
  | 'pre_mid_notebook'
  | 'midterm_score'
  | 'post_mid_work'
  | 'post_mid_notebook'
  | 'affective_score'
  | 'final_score'
  | 'attended_hours';

const SCORE_COLUMNS: { field: ScoreField; label: string; maxField?: keyof SgsScoreRecord }[] = [
  { field: 'pre_mid_work', label: 'งานก่อนกลางภาค', maxField: 'max_pre_mid_work' },
  { field: 'pre_mid_notebook', label: 'สมุดก่อนกลางภาค', maxField: 'max_pre_mid_notebook' },
  { field: 'midterm_score', label: 'กลางภาค', maxField: 'max_midterm' },
  { field: 'post_mid_work', label: 'งานหลังกลางภาค', maxField: 'max_post_mid_work' },
  { field: 'post_mid_notebook', label: 'สมุดหลังกลางภาค', maxField: 'max_post_mid_notebook' },
  { field: 'affective_score', label: 'จิตพิสัย', maxField: 'max_affective' },
  { field: 'final_score', label: 'ปลายภาค', maxField: 'max_final' },
  { field: 'attended_hours', label: 'ชม.เรียน' },
];

/** กลุ่มสาระจากอักษรนำของรหัสวิชา (หลักสูตรแกนกลาง) */
function learningAreaFromCode(code: string): SgsLearningArea {
  const c = code.trim().charAt(0);
  if (c === 'ท') return 'ภาษาไทย';
  if (c === 'ค') return 'คณิตศาสตร์';
  if (c === 'ว') return 'วิทยาศาสตร์และเทคโนโลยี';
  if (c === 'ส') return 'สังคมศึกษา ศาสนา และวัฒนธรรม';
  if (c === 'พ') return 'สุขศึกษาและพลศึกษา';
  if (c === 'ศ') return 'ศิลปะ';
  if (c === 'ง') return 'การงานอาชีพ';
  if (c === 'ก') return 'กิจกรรมพัฒนาผู้เรียน';
  return 'ภาษาต่างประเทศ';
}

/** หลักที่ 4 ของรหัสวิชา: 1 = พื้นฐาน, 2 = เพิ่มเติม */
function subjectTypeFromCode(code: string): SgsSubjectType {
  if (code.trim().charAt(0) === 'ก') return 'กิจกรรม';
  return code.trim().charAt(3) === '2' ? 'เพิ่มเติม' : 'พื้นฐาน';
}

function toGradeLevel(raw: string): SgsGradeLevel | null {
  const m = raw.match(/[1-6]/);
  const v = m ? (`ม.${m[0]}` as SgsGradeLevel) : null;
  return v && (SGS_GRADE_LEVELS as readonly string[]).includes(v) ? v : null;
}

export default function MyGradesPage({
  schoolId,
  idUser,
  userName,
}: {
  schoolId: number | null;
  idUser: number | null;
  userName: string;
}) {
  const [courses, setCourses] = useState<CourseOption[]>([]);
  const [courseKey, setCourseKey] = useState('');
  const [yearBe, setYearBe] = useState(new Date().getFullYear() + 543);
  const [termNo, setTermNo] = useState<1 | 2>(1);
  const [students, setStudents] = useState<StudentRow[]>([]);
  const [rows, setRows] = useState<Record<number, SgsScoreRecord>>({});
  const [dirty, setDirty] = useState<Set<number>>(new Set());
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ tone: 'ok' | 'error'; text: string } | null>(null);

  // 1) วิชา / ห้องที่ครูสอน (จากตารางสอน)
  useEffect(() => {
    if (!schoolId || idUser == null) {
      setLoading(false);
      return;
    }
    (async () => {
      const { data: sched } = await supabase
        .from('SchoolWebTeachingSchedules')
        .select('classroom_id, subject_id')
        .eq('id_school', schoolId)
        .eq('teacher_id', idUser);
      const pairs = (sched as { classroom_id: number; subject_id: number }[] | null) ?? [];
      const classIds = [...new Set(pairs.map((p) => p.classroom_id))];
      const subjIds = [...new Set(pairs.map((p) => p.subject_id))];
      const [cRes, sRes] = await Promise.all([
        classIds.length
          ? supabase.from('SchoolWebClassrooms').select('id, name, grade_level').in('id', classIds)
          : Promise.resolve({ data: [] }),
        subjIds.length
          ? supabase.from('SchoolWebSubjects').select('id, code, name, credits').in('id', subjIds)
          : Promise.resolve({ data: [] }),
      ]);
      const cMap = new Map(
        ((cRes.data as { id: number; name: string; grade_level: string }[] | null) ?? []).map((c) => [c.id, c]),
      );
      const sMap = new Map(
        ((sRes.data as { id: number; code: string; name: string; credits: number }[] | null) ?? []).map((s) => [
          s.id,
          s,
        ]),
      );
      const seen = new Map<string, CourseOption>();
      for (const p of pairs) {
        const c = cMap.get(p.classroom_id);
        const s = sMap.get(p.subject_id);
        const level = c ? toGradeLevel(c.grade_level || c.name) : null;
        if (!c || !s || !level) continue;
        const key = `${c.id}:${s.code}`;
        if (!seen.has(key)) {
          seen.set(key, {
            key,
            classroomId: c.id,
            classroomName: c.name,
            gradeLevel: level,
            subjectCode: s.code,
            subjectName: s.name,
            credits: Number(s.credits) || 1,
          });
        }
      }
      const list = [...seen.values()].sort((a, b) =>
        `${a.subjectCode}${a.classroomName}`.localeCompare(`${b.subjectCode}${b.classroomName}`, 'th'),
      );
      setCourses(list);
      setCourseKey((prev) => prev || list[0]?.key || '');
      setLoading(false);
    })();
  }, [schoolId, idUser]);

  const course = useMemo(() => courses.find((c) => c.key === courseKey) ?? null, [courses, courseKey]);

  const blankRecord = useCallback(
    (studentId: number, c: CourseOption): SgsScoreRecord => ({
      id_school: schoolId as number,
      student_id: studentId,
      grade_level: c.gradeLevel,
      term_no: termNo,
      year_be: yearBe,
      subject_code: c.subjectCode,
      subject_name: c.subjectName,
      learning_area: learningAreaFromCode(c.subjectCode),
      subject_type: subjectTypeFromCode(c.subjectCode),
      credits: c.credits,
      max_pre_mid_work: 15,
      max_pre_mid_notebook: 10,
      max_midterm: 20,
      max_post_mid_work: 15,
      max_post_mid_notebook: 5,
      max_affective: 5,
      max_final: 30,
      pre_mid_work: 0,
      pre_mid_notebook: 0,
      midterm_score: 0,
      post_mid_work: 0,
      post_mid_notebook: 0,
      affective_score: 0,
      final_score: 0,
      attended_hours: 0,
      total_hours: Math.round(c.credits * 40),
      reading_thinking_writing: 0,
      desirable_characteristics: 0,
      special_status: '',
      teacher_name: userName,
    }),
    [schoolId, termNo, yearBe, userName],
  );

  // 2) นักเรียนในห้อง + คะแนนเดิมของวิชานี้
  useEffect(() => {
    if (!schoolId || !course) {
      setStudents([]);
      setRows({});
      return;
    }
    let cancelled = false;
    (async () => {
      setMessage(null);
      const { data: st } = await supabase
        .from('SchoolWebStudents')
        .select('id, student_code, prefix, first_name, last_name')
        .eq('id_school', schoolId)
        .eq('classroom_id', course.classroomId)
        .eq('status', 'enrolled')
        .order('student_code');
      const list = (st as StudentRow[] | null) ?? [];
      const ids = list.map((s) => s.id);
      const { data: gr } = ids.length
        ? await supabase
            .from('SchoolWebSgsGrades')
            .select('*')
            .eq('id_school', schoolId)
            .eq('subject_code', course.subjectCode)
            .eq('year_be', yearBe)
            .eq('term_no', termNo)
            .in('student_id', ids)
        : { data: [] };
      if (cancelled) return;
      const existing = new Map(((gr as SgsScoreRecord[] | null) ?? []).map((g) => [g.student_id, g]));
      const next: Record<number, SgsScoreRecord> = {};
      for (const s of list) next[s.id] = existing.get(s.id) ?? blankRecord(s.id, course);
      setStudents(list);
      setRows(next);
      setDirty(new Set());
    })();
    return () => {
      cancelled = true;
    };
  }, [schoolId, course, yearBe, termNo, blankRecord]);

  const setScore = (studentId: number, field: ScoreField, raw: string) => {
    const value = Math.max(0, Number(raw) || 0);
    setRows((prev) => ({ ...prev, [studentId]: { ...prev[studentId], [field]: value } }));
    setDirty((prev) => new Set(prev).add(studentId));
  };

  const handleSave = async () => {
    if (!schoolId || dirty.size === 0) return;
    setSaving(true);
    const res = await saveSgsGradeRecords(
      schoolId,
      [...dirty].map((id) => rows[id]),
    );
    setSaving(false);
    if (res.savedToDb) {
      setDirty(new Set());
      setMessage({ tone: 'ok', text: `บันทึกคะแนน ${course?.subjectCode} ${course?.classroomName} แล้ว` });
    } else {
      setMessage({
        tone: 'error',
        text: `บันทึกไม่สำเร็จ: ${res.error ?? ''} (กรอกได้เฉพาะวิชาและห้องที่คุณมีคาบในตารางสอน)`,
      });
    }
  };

  return (
    <div className="space-y-5">
      <div>
        <Link to="/school/my-work" className="inline-flex items-center gap-1 text-xs text-brand-600 hover:underline">
          <ArrowLeft className="h-3.5 w-3.5" /> งานของฉัน
        </Link>
        <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">กรอกคะแนนวิชาที่ฉันสอน</h1>
        <p className="mt-1 text-sm text-slate-500">
          แสดงเฉพาะวิชาและห้องที่มีชื่อคุณในตารางสอน · เกรดคำนวณอัตโนมัติตามโครงสร้าง SGS
        </p>
      </div>

      {loading ? (
        <p className="text-sm text-slate-500">กำลังโหลด…</p>
      ) : courses.length === 0 ? (
        <div className="surface-card p-8">
          <EmptyState>ยังไม่มีวิชาที่ระบุชื่อคุณเป็นครูผู้สอนในตารางสอน — ติดต่อฝ่ายวิชาการ</EmptyState>
        </div>
      ) : (
        <>
          <div className="surface-card flex flex-wrap items-end gap-3 p-4">
            <label className="flex flex-col gap-1 text-xs font-medium text-slate-600">
              วิชา / ห้อง
              <select className="input w-auto py-1.5 text-sm" value={courseKey} onChange={(e) => setCourseKey(e.target.value)}>
                {courses.map((c) => (
                  <option key={c.key} value={c.key}>
                    {c.subjectCode} {c.subjectName} · {c.classroomName}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 text-xs font-medium text-slate-600">
              ปีการศึกษา
              <input
                type="number"
                className="input w-24 py-1.5 text-sm"
                value={yearBe}
                onChange={(e) => setYearBe(Number(e.target.value) || yearBe)}
              />
            </label>
            <label className="flex flex-col gap-1 text-xs font-medium text-slate-600">
              ภาคเรียน
              <select
                className="input w-auto py-1.5 text-sm"
                value={termNo}
                onChange={(e) => setTermNo(e.target.value === '2' ? 2 : 1)}
              >
                <option value="1">1</option>
                <option value="2">2</option>
              </select>
            </label>
            <button
              type="button"
              disabled={saving || dirty.size === 0}
              onClick={handleSave}
              className="btn-primary ml-auto"
            >
              <Save className="h-4 w-4" />
              {saving ? 'กำลังบันทึก…' : `บันทึก${dirty.size ? ` (${dirty.size})` : ''}`}
            </button>
          </div>

          {message && (
            <p
              className={`rounded-lg px-3 py-2 text-xs ${
                message.tone === 'ok' ? 'bg-emerald-50 text-emerald-800' : 'bg-red-50 text-red-700'
              }`}
            >
              {message.text}
            </p>
          )}

          <div className="surface-card overflow-x-auto">
            {students.length === 0 ? (
              <div className="p-8">
                <EmptyState>ไม่มีนักเรียนในห้องนี้</EmptyState>
              </div>
            ) : (
              <table className="w-full min-w-[900px] border-collapse text-xs">
                <thead>
                  <tr className="bg-canvas text-slate-600">
                    <th className="border-b border-line p-2 text-left">เลขประจำตัว</th>
                    <th className="border-b border-line p-2 text-left">ชื่อ - สกุล</th>
                    {SCORE_COLUMNS.map((col) => {
                      const first = students[0] ? rows[students[0].id] : undefined;
                      const max = col.maxField && first ? first[col.maxField] : first?.total_hours;
                      return (
                        <th key={col.field} className="border-b border-line p-2 text-center font-medium">
                          {col.label}
                          <span className="block text-[10px] font-normal text-slate-400">({String(max ?? '')})</span>
                        </th>
                      );
                    })}
                    <th className="border-b border-line p-2 text-center">รวม</th>
                    <th className="border-b border-line p-2 text-center">เกรด</th>
                  </tr>
                </thead>
                <tbody>
                  {students.map((s) => {
                    const r = rows[s.id];
                    if (!r) return null;
                    const computed = computeSgsGradeRow(r);
                    return (
                      <tr key={s.id} className={dirty.has(s.id) ? 'bg-amber-50/50' : ''}>
                        <td className="border-b border-line p-2 text-slate-600">{s.student_code}</td>
                        <td className="border-b border-line p-2 text-ink">
                          {s.prefix ?? ''}
                          {s.first_name} {s.last_name}
                        </td>
                        {SCORE_COLUMNS.map((col) => (
                          <td key={col.field} className="border-b border-line p-1 text-center">
                            <input
                              type="number"
                              min={0}
                              step="0.5"
                              value={Number(r[col.field]) || 0}
                              onChange={(e) => setScore(s.id, col.field, e.target.value)}
                              className="w-16 rounded border border-line px-1.5 py-1 text-center text-xs"
                              aria-label={`${col.label} ของ ${s.first_name}`}
                            />
                          </td>
                        ))}
                        <td className="border-b border-line p-2 text-center font-semibold text-ink">
                          {computed.totalScore}
                        </td>
                        <td className="border-b border-line p-2 text-center font-semibold text-brand-700">
                          {computed.displayGrade}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
    </div>
  );
}
