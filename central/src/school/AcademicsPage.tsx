import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { Plus, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
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
  { value: 1, label: 'จันทร์' },
  { value: 2, label: 'อังคาร' },
  { value: 3, label: 'พุธ' },
  { value: 4, label: 'พฤหัสบดี' },
  { value: 5, label: 'ศุกร์' },
];

export default function AcademicsPage({ schoolId, canEdit }: AcademicsPageProps) {
  const [tab, setTab] = useState<'subjects' | 'schedules'>('subjects');
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [departments, setDepartments] = useState<SchoolDepartment[]>([]);
  const [classrooms, setClassrooms] = useState<Classroom[]>([]);
  const [teachers, setTeachers] = useState<TeacherOption[]>([]);
  const [schedules, setSchedules] = useState<TeachingSchedule[]>([]);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [departmentId, setDepartmentId] = useState<string>('');
  const [credits, setCredits] = useState('1.0');

  const [selectedClassroomId, setSelectedClassroomId] = useState<string>('');
  const [schedSubjectId, setSchedSubjectId] = useState<string>('');
  const [schedTeacherId, setSchedTeacherId] = useState<string>('');
  const [schedDay, setSchedDay] = useState<string>('1');
  const [schedPeriod, setSchedPeriod] = useState<string>('1');
  const [schedRoom, setSchedRoom] = useState('');

  const loadAll = useCallback(async () => {
    if (!schoolId) return;
    const [subRes, deptRes, clsRes, tchRes, schRes] = await Promise.all([
      supabase
        .from('SchoolWebSubjects')
        .select('id, id_school, code, name, department_id, credits, is_active')
        .eq('id_school', schoolId)
        .order('code', { ascending: true }),
      supabase
        .from('SchoolDepartments')
        .select('id, id_school, code, name, category, sort_order, is_active')
        .eq('id_school', schoolId)
        .eq('is_active', true),
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
    ]);

    if (subRes.error) setError(subRes.error.message);
    else setSubjects((subRes.data as Subject[] | null) ?? []);

    if (!deptRes.error) setDepartments((deptRes.data as SchoolDepartment[] | null) ?? []);
    if (!clsRes.error) {
      const clsList = (clsRes.data as Classroom[] | null) ?? [];
      setClassrooms(clsList);
      setSelectedClassroomId((prev) => prev || (clsList[0] ? String(clsList[0].id) : ''));
    }
    if (!tchRes.error) setTeachers((tchRes.data as TeacherOption[] | null) ?? []);
    if (!schRes.error) setSchedules((schRes.data as TeachingSchedule[] | null) ?? []);
  }, [schoolId]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  const deptMap = useMemo(() => {
    const map = new Map<number, string>();
    for (const d of departments) map.set(d.id, d.name);
    return map;
  }, [departments]);

  const subjectMap = useMemo(() => {
    const map = new Map<number, Subject>();
    for (const s of subjects) map.set(s.id, s);
    return map;
  }, [subjects]);

  const teacherMap = useMemo(() => {
    const map = new Map<number, string>();
    for (const t of teachers) map.set(t.id_user, t.fullName || '-');
    return map;
  }, [teachers]);

  const classroomSchedules = useMemo(() => {
    const cid = Number(selectedClassroomId);
    if (!cid) return [];
    return schedules.filter((s) => s.classroom_id === cid);
  }, [schedules, selectedClassroomId]);

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

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-ink">
            หลักสูตรและตารางสอน
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            จัดการรายวิชา หน่วยกิต และตารางสอนประจำห้องเรียน
          </p>
        </div>

        <div className="inline-flex rounded-lg border border-line bg-white p-1">
          <button
            type="button"
            onClick={() => setTab('subjects')}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              tab === 'subjects'
                ? 'bg-brand-50 text-brand-700'
                : 'text-slate-600 hover:text-ink'
            }`}
          >
            รายวิชา
          </button>
          <button
            type="button"
            onClick={() => setTab('schedules')}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              tab === 'schedules'
                ? 'bg-brand-50 text-brand-700'
                : 'text-slate-600 hover:text-ink'
            }`}
          >
            ตารางสอน
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {tab === 'subjects' ? (
        <>
          {canEdit && (
            <section className="surface-card p-6">
              <h2 className="text-base font-semibold text-ink">เพิ่มรายวิชา</h2>
              <form onSubmit={handleAddSubject} className="mt-4 grid gap-4 sm:grid-cols-12">
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    รหัสวิชา
                  </label>
                  <input
                    type="text"
                    required
                    value={code}
                    onChange={(e) => setCode(e.target.value)}
                    placeholder="ว21101"
                    className="input"
                  />
                </div>
                <div className="sm:col-span-4">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ชื่อรายวิชา
                  </label>
                  <input
                    type="text"
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="วิทยาศาสตร์ 1"
                    className="input"
                  />
                </div>
                <div className="sm:col-span-3">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    กลุ่มสาระ
                  </label>
                  <select
                    value={departmentId}
                    onChange={(e) => setDepartmentId(e.target.value)}
                    className="input"
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
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    หน่วยกิต
                  </label>
                  <input
                    type="number"
                    step="0.5"
                    min="0.5"
                    value={credits}
                    onChange={(e) => setCredits(e.target.value)}
                    className="input tabular-nums"
                  />
                </div>
                <div className="flex items-end sm:col-span-2">
                  <button type="submit" disabled={busy} className="btn-primary w-full">
                    <Plus className="h-4 w-4" strokeWidth={1.5} />
                    <span>เพิ่ม</span>
                  </button>
                </div>
              </form>
            </section>
          )}

          <section className="surface-card p-6">
            <h2 className="text-base font-semibold text-ink">
              รายวิชาทั้งหมด ({subjects.length})
            </h2>
            <div className="mt-4 overflow-x-auto rounded-lg border border-line">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-line bg-canvas text-xs font-medium text-slate-500">
                  <tr>
                    <th className="px-4 py-3">รหัสวิชา</th>
                    <th className="px-4 py-3">ชื่อรายวิชา</th>
                    <th className="px-4 py-3">กลุ่มสาระ</th>
                    <th className="px-4 py-3 text-right">หน่วยกิต</th>
                    {canEdit && <th className="px-4 py-3 text-right">จัดการ</th>}
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {subjects.length === 0 ? (
                    <tr>
                      <td colSpan={canEdit ? 5 : 4} className="px-4 py-8 text-center text-slate-500">
                        ยังไม่มีรายวิชา
                      </td>
                    </tr>
                  ) : (
                    subjects.map((sub) => (
                      <tr key={sub.id} className="hover:bg-slate-50/60">
                        <td className="px-4 py-3 font-medium tabular-nums text-ink">
                          {sub.code}
                        </td>
                        <td className="px-4 py-3 text-ink">{sub.name}</td>
                        <td className="px-4 py-3 text-slate-600">
                          {sub.department_id ? deptMap.get(sub.department_id) || '-' : '-'}
                        </td>
                        <td className="px-4 py-3 text-right tabular-nums text-slate-600">
                          {Number(sub.credits).toFixed(1)}
                        </td>
                        {canEdit && (
                          <td className="px-4 py-3 text-right">
                            <button
                              type="button"
                              disabled={busy}
                              onClick={() => removeSubject(sub.id)}
                              className="rounded p-1 text-red-600 hover:bg-red-50"
                              title="ลบรายวิชา"
                            >
                              <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                            </button>
                          </td>
                        )}
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      ) : (
        <>
          <section className="surface-card p-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <h2 className="text-base font-semibold text-ink">เลือกห้องเรียน</h2>
              <select
                value={selectedClassroomId}
                onChange={(e) => setSelectedClassroomId(e.target.value)}
                className="input sm:w-56"
              >
                {classrooms.length === 0 ? (
                  <option value="">ยังไม่มีห้องเรียน</option>
                ) : (
                  classrooms.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))
                )}
              </select>
            </div>

            {canEdit && selectedClassroomId && (
              <form
                onSubmit={handleAddSchedule}
                className="mt-5 grid gap-4 border-t border-line pt-5 sm:grid-cols-12"
              >
                <div className="sm:col-span-3">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    รายวิชา
                  </label>
                  <select
                    required
                    value={schedSubjectId}
                    onChange={(e) => setSchedSubjectId(e.target.value)}
                    className="input"
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
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ครูผู้สอน
                  </label>
                  <select
                    value={schedTeacherId}
                    onChange={(e) => setSchedTeacherId(e.target.value)}
                    className="input"
                  >
                    <option value="">ยังไม่ระบุ</option>
                    {teachers.map((t) => (
                      <option key={t.id_user} value={t.id_user}>
                        {t.fullName || `ครู #${t.id_user}`}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    วัน
                  </label>
                  <select
                    value={schedDay}
                    onChange={(e) => setSchedDay(e.target.value)}
                    className="input"
                  >
                    {DAYS.map((d) => (
                      <option key={d.value} value={d.value}>
                        {d.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-1">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    คาบ
                  </label>
                  <select
                    value={schedPeriod}
                    onChange={(e) => setSchedPeriod(e.target.value)}
                    className="input tabular-nums"
                  >
                    {[1, 2, 3, 4, 5, 6, 7, 8].map((p) => (
                      <option key={p} value={p}>
                        {p}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-1">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ห้อง
                  </label>
                  <input
                    type="text"
                    value={schedRoom}
                    onChange={(e) => setSchedRoom(e.target.value)}
                    placeholder="201"
                    className="input"
                  />
                </div>
                <div className="flex items-end sm:col-span-2">
                  <button type="submit" disabled={busy} className="btn-primary w-full">
                    <Plus className="h-4 w-4" strokeWidth={1.5} />
                    <span>เพิ่มคาบ</span>
                  </button>
                </div>
              </form>
            )}
          </section>

          <section className="surface-card p-6">
            <h2 className="text-base font-semibold text-ink">ตารางสอนรายวัน</h2>
            <div className="mt-4 divide-y divide-line rounded-lg border border-line">
              {DAYS.map((day) => {
                const dayRows = classroomSchedules.filter(
                  (s) => s.day_of_week === day.value,
                );
                return (
                  <div key={day.value} className="p-4">
                    <p className="text-sm font-medium text-ink">{day.label}</p>
                    {dayRows.length === 0 ? (
                      <p className="mt-1 text-xs text-slate-400">ไม่มีคาบสอน</p>
                    ) : (
                      <div className="mt-2 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
                        {dayRows.map((row) => {
                          const sub = subjectMap.get(row.subject_id);
                          return (
                            <div
                              key={row.id}
                              className="flex items-start justify-between gap-2 rounded-lg border border-line bg-canvas/70 p-3"
                            >
                              <div className="min-w-0">
                                <p className="text-xs font-medium tabular-nums text-brand-700">
                                  คาบ {row.period_no}
                                  {row.room_name ? ` · ห้อง ${row.room_name}` : ''}
                                </p>
                                <p className="mt-0.5 truncate text-sm font-medium text-ink">
                                  {sub ? `${sub.code} ${sub.name}` : '-'}
                                </p>
                                <p className="mt-0.5 truncate text-xs text-slate-500">
                                  {row.teacher_id
                                    ? teacherMap.get(row.teacher_id) || '-'
                                    : '-'}
                                </p>
                              </div>
                              {canEdit && (
                                <button
                                  type="button"
                                  disabled={busy}
                                  onClick={() => removeSchedule(row.id)}
                                  className="rounded p-1 text-slate-400 hover:bg-red-50 hover:text-red-600"
                                  title="ลบคาบสอน"
                                >
                                  <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                                </button>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
