import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { Plus, Search, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import type { Classroom, Student, StudentStatus, TeacherOption } from './types';

interface StudentsPageProps {
  schoolId: number | null;
  canEdit: boolean;
}

const STATUS_LABEL: Record<StudentStatus, string> = {
  enrolled: 'กำลังศึกษา',
  transferred: 'ย้ายออก',
  graduated: 'จบการศึกษา',
  dropped: 'พ้นสภาพ',
};

export default function StudentsPage({ schoolId, canEdit }: StudentsPageProps) {
  const [tab, setTab] = useState<'students' | 'classrooms'>('students');
  const [students, setStudents] = useState<Student[]>([]);
  const [classrooms, setClassrooms] = useState<Classroom[]>([]);
  const [teachers, setTeachers] = useState<TeacherOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [query, setQuery] = useState('');
  const [filterClassroom, setFilterClassroom] = useState<string>('all');

  const [studentCode, setStudentCode] = useState('');
  const [prefix, setPrefix] = useState('เด็กชาย');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [classroomId, setClassroomId] = useState<string>('');
  const [guardianName, setGuardianName] = useState('');
  const [guardianPhone, setGuardianPhone] = useState('');

  const [gradeLevel, setGradeLevel] = useState('');
  const [roomNo, setRoomNo] = useState('');
  const [advisorId, setAdvisorId] = useState<string>('');

  const loadAll = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const [stuRes, clsRes, tchRes] = await Promise.all([
      supabase
        .from('SchoolWebStudents')
        .select(
          'id, id_school, student_code, prefix, first_name, last_name, classroom_id, guardian_name, guardian_phone, status',
        )
        .eq('id_school', schoolId)
        .order('student_code', { ascending: true }),
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
    ]);

    if (stuRes.error) setError(stuRes.error.message);
    else setStudents((stuRes.data as Student[] | null) ?? []);

    if (!clsRes.error) setClassrooms((clsRes.data as Classroom[] | null) ?? []);
    if (!tchRes.error) setTeachers((tchRes.data as TeacherOption[] | null) ?? []);

    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  const classroomMap = useMemo(() => {
    const map = new Map<number, string>();
    for (const c of classrooms) map.set(c.id, c.name);
    return map;
  }, [classrooms]);

  const teacherMap = useMemo(() => {
    const map = new Map<number, string>();
    for (const t of teachers) map.set(t.id_user, t.fullName || '-');
    return map;
  }, [teachers]);

  const filteredStudents = useMemo(() => {
    const q = query.trim().toLowerCase();
    return students.filter((s) => {
      if (filterClassroom !== 'all' && String(s.classroom_id ?? '') !== filterClassroom) {
        return false;
      }
      if (!q) return true;
      const fullName = `${s.prefix ?? ''}${s.first_name} ${s.last_name}`.toLowerCase();
      return s.student_code.toLowerCase().includes(q) || fullName.includes(q);
    });
  }, [students, query, filterClassroom]);

  async function handleAddStudent(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    const { error: insErr } = await supabase.from('SchoolWebStudents').insert({
      id_school: schoolId,
      student_code: studentCode.trim(),
      prefix: prefix.trim() || null,
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      classroom_id: classroomId ? Number(classroomId) : null,
      guardian_name: guardianName.trim() || null,
      guardian_phone: guardianPhone.trim() || null,
      status: 'enrolled',
    });

    if (insErr) {
      setError(insErr.message);
    } else {
      setStudentCode('');
      setFirstName('');
      setLastName('');
      setGuardianName('');
      setGuardianPhone('');
      await loadAll();
    }
    setBusy(false);
  }

  async function updateStudentStatus(id: number, status: StudentStatus) {
    if (!canEdit) return;
    setBusy(true);
    const { error: updErr } = await supabase
      .from('SchoolWebStudents')
      .update({ status })
      .eq('id', id);
    if (updErr) setError(updErr.message);
    else await loadAll();
    setBusy(false);
  }

  async function handleAddClassroom(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    const level = gradeLevel.trim();
    const room = roomNo.trim();
    const { error: insErr } = await supabase.from('SchoolWebClassrooms').insert({
      id_school: schoolId,
      grade_level: level,
      room_no: room,
      name: `${level}/${room}`,
      advisor_teacher_id: advisorId ? Number(advisorId) : null,
      is_active: true,
    });

    if (insErr) {
      setError(insErr.message);
    } else {
      setGradeLevel('');
      setRoomNo('');
      setAdvisorId('');
      await loadAll();
    }
    setBusy(false);
  }

  async function removeClassroom(id: number) {
    if (!canEdit) return;
    setBusy(true);
    const { error: delErr } = await supabase
      .from('SchoolWebClassrooms')
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
            ทะเบียนนักเรียนและห้องเรียน
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            จัดการรายชื่อนักเรียน ห้องเรียน และครูที่ปรึกษา
          </p>
        </div>

        <div className="inline-flex rounded-lg border border-line bg-white p-1">
          <button
            type="button"
            onClick={() => setTab('students')}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              tab === 'students'
                ? 'bg-brand-50 text-brand-700'
                : 'text-slate-600 hover:text-ink'
            }`}
          >
            ทะเบียนนักเรียน
          </button>
          <button
            type="button"
            onClick={() => setTab('classrooms')}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              tab === 'classrooms'
                ? 'bg-brand-50 text-brand-700'
                : 'text-slate-600 hover:text-ink'
            }`}
          >
            ห้องเรียนและครูที่ปรึกษา
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {tab === 'students' ? (
        <>
          {canEdit && (
            <section className="surface-card p-6">
              <h2 className="text-base font-semibold text-ink">เพิ่มนักเรียนใหม่</h2>
              <form onSubmit={handleAddStudent} className="mt-4 grid gap-4 sm:grid-cols-12">
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    รหัสนักเรียน
                  </label>
                  <input
                    type="text"
                    required
                    value={studentCode}
                    onChange={(e) => setStudentCode(e.target.value)}
                    placeholder="69001"
                    className="input tabular-nums"
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    คำนำหน้า
                  </label>
                  <select
                    value={prefix}
                    onChange={(e) => setPrefix(e.target.value)}
                    className="input"
                  >
                    <option value="เด็กชาย">เด็กชาย</option>
                    <option value="เด็กหญิง">เด็กหญิง</option>
                    <option value="นาย">นาย</option>
                    <option value="นางสาว">นางสาว</option>
                  </select>
                </div>
                <div className="sm:col-span-3">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ชื่อ
                  </label>
                  <input
                    type="text"
                    required
                    value={firstName}
                    onChange={(e) => setFirstName(e.target.value)}
                    className="input"
                  />
                </div>
                <div className="sm:col-span-3">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    นามสกุล
                  </label>
                  <input
                    type="text"
                    required
                    value={lastName}
                    onChange={(e) => setLastName(e.target.value)}
                    className="input"
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ห้องเรียน
                  </label>
                  <select
                    value={classroomId}
                    onChange={(e) => setClassroomId(e.target.value)}
                    className="input"
                  >
                    <option value="">ยังไม่ระบุ</option>
                    {classrooms.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="sm:col-span-5">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ชื่อผู้ปกครอง
                  </label>
                  <input
                    type="text"
                    value={guardianName}
                    onChange={(e) => setGuardianName(e.target.value)}
                    className="input"
                  />
                </div>
                <div className="sm:col-span-5">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    เบอร์โทรผู้ปกครอง
                  </label>
                  <input
                    type="text"
                    value={guardianPhone}
                    onChange={(e) => setGuardianPhone(e.target.value)}
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
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex flex-wrap items-center gap-3">
                <div className="relative w-full sm:w-64">
                  <Search
                    className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                    strokeWidth={1.5}
                  />
                  <input
                    type="text"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="ค้นหารหัส หรือชื่อนักเรียน"
                    className="input pl-9"
                  />
                </div>
                <select
                  value={filterClassroom}
                  onChange={(e) => setFilterClassroom(e.target.value)}
                  className="input w-auto"
                >
                  <option value="all">ทุกห้องเรียน</option>
                  {classrooms.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <span className="tabular-nums text-xs text-slate-500">
                {filteredStudents.length.toLocaleString('th-TH')} คน
              </span>
            </div>

            <div className="mt-5 overflow-x-auto rounded-lg border border-line">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-line bg-canvas text-xs font-medium text-slate-500">
                  <tr>
                    <th className="px-4 py-3">รหัส</th>
                    <th className="px-4 py-3">ชื่อ-นามสกุล</th>
                    <th className="px-4 py-3">ห้องเรียน</th>
                    <th className="px-4 py-3">ผู้ปกครอง</th>
                    <th className="px-4 py-3">สถานะ</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {loading ? (
                    <tr>
                      <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                        กำลังโหลดข้อมูลนักเรียน...
                      </td>
                    </tr>
                  ) : filteredStudents.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                        ไม่พบข้อมูลนักเรียน
                      </td>
                    </tr>
                  ) : (
                    filteredStudents.map((s) => (
                      <tr key={s.id} className="hover:bg-slate-50/60">
                        <td className="px-4 py-3 tabular-nums text-slate-600">
                          {s.student_code}
                        </td>
                        <td className="px-4 py-3 font-medium text-ink">
                          {`${s.prefix ?? ''}${s.first_name} ${s.last_name}`}
                        </td>
                        <td className="px-4 py-3 text-slate-600">
                          {s.classroom_id ? classroomMap.get(s.classroom_id) || '-' : '-'}
                        </td>
                        <td className="px-4 py-3 text-slate-600">
                          {s.guardian_name || '-'}
                          {s.guardian_phone ? ` (${s.guardian_phone})` : ''}
                        </td>
                        <td className="px-4 py-3">
                          {canEdit ? (
                            <select
                              value={s.status}
                              disabled={busy}
                              onChange={(e) =>
                                updateStudentStatus(s.id, e.target.value as StudentStatus)
                              }
                              className="rounded border border-line bg-white px-2 py-1 text-xs text-ink outline-none focus:border-brand-500"
                            >
                              {Object.entries(STATUS_LABEL).map(([val, lbl]) => (
                                <option key={val} value={val}>
                                  {lbl}
                                </option>
                              ))}
                            </select>
                          ) : (
                            <span className="text-xs text-slate-600">
                              {STATUS_LABEL[s.status]}
                            </span>
                          )}
                        </td>
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
          {canEdit && (
            <section className="surface-card p-6">
              <h2 className="text-base font-semibold text-ink">สร้างห้องเรียนใหม่</h2>
              <form onSubmit={handleAddClassroom} className="mt-4 grid gap-4 sm:grid-cols-12">
                <div className="sm:col-span-3">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ระดับชั้น
                  </label>
                  <input
                    type="text"
                    required
                    value={gradeLevel}
                    onChange={(e) => setGradeLevel(e.target.value)}
                    placeholder="เช่น ม.1 หรือ ป.6"
                    className="input"
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ห้องที่
                  </label>
                  <input
                    type="text"
                    required
                    value={roomNo}
                    onChange={(e) => setRoomNo(e.target.value)}
                    placeholder="เช่น 1"
                    className="input tabular-nums"
                  />
                </div>
                <div className="sm:col-span-5">
                  <label className="mb-1.5 block text-xs font-medium text-ink">
                    ครูที่ปรึกษา
                  </label>
                  <select
                    value={advisorId}
                    onChange={(e) => setAdvisorId(e.target.value)}
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
                <div className="flex items-end sm:col-span-2">
                  <button type="submit" disabled={busy} className="btn-primary w-full">
                    <Plus className="h-4 w-4" strokeWidth={1.5} />
                    <span>สร้างห้อง</span>
                  </button>
                </div>
              </form>
            </section>
          )}

          <section className="surface-card p-6">
            <h2 className="text-base font-semibold text-ink">
              รายการห้องเรียน ({classrooms.length})
            </h2>
            <div className="mt-4 divide-y divide-line rounded-lg border border-line">
              {classrooms.length === 0 ? (
                <p className="p-6 text-center text-sm text-slate-500">
                  ยังไม่มีข้อมูลห้องเรียน
                </p>
              ) : (
                classrooms.map((c) => (
                  <div
                    key={c.id}
                    className="flex items-center justify-between gap-4 p-4"
                  >
                    <div>
                      <p className="text-sm font-medium text-ink">{c.name}</p>
                      <p className="mt-0.5 text-xs text-slate-500">
                        ครูที่ปรึกษา:{' '}
                        {c.advisor_teacher_id
                          ? teacherMap.get(c.advisor_teacher_id) || '-'
                          : 'ยังไม่ระบุ'}
                      </p>
                    </div>
                    {canEdit && (
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => removeClassroom(c.id)}
                        title="ลบห้องเรียน"
                        className="rounded-lg border border-line p-1.5 text-red-600 hover:bg-red-50"
                      >
                        <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                      </button>
                    )}
                  </div>
                ))
              )}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
