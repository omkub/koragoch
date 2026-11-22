import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type FormEvent,
} from 'react';
import {
  Award,
  BookOpen,
  Calculator,
  Check,
  Edit3,
  FileSpreadsheet,
  FileText,
  GraduationCap,
  Plus,
  Printer,
  Save,
  Search,
  Sparkles,
  Trash2,
  UserCheck,
  Users,
  X,
} from 'lucide-react';
import { supabase } from '../supabase';
import {
  buildDefaultStudentProfile,
  computeSgsGradeRow,
  computeStudentMultiYearTranscript,
  downloadSgsGradebookCsv,
  fetchSchoolSgsGrades,
  fetchSchoolStudentProfiles,
  getStandardSubjectsForGradeTerm,
  saveSgsGradeRecords,
  saveStudentPersonalProfile,
  SGS_GRADE_LEVELS,
  STUDY_PLAN_OPTIONS,
  type SgsGradeLevel,
  type SgsLearningArea,
  type SgsScoreRecord,
  type SgsSpecialStatus,
  type SgsSubjectType,
  type StudentPersonalProfile,
} from './sgsGradingStore';
import type {
  Classroom,
  Student,
  StudentStatus,
  Subject,
  TeacherOption,
} from './types';

interface StudentsPageProps {
  schoolId: number | null;
  canEdit: boolean;
}

type MainTab = 'registry' | 'sgs_gradebook' | 'transcript' | 'classrooms';

const STATUS_LABEL: Record<StudentStatus, string> = {
  enrolled: 'กำลังศึกษา',
  transferred: 'ย้ายออก',
  graduated: 'จบการศึกษา',
  dropped: 'พ้นสภาพ',
};

function inferGradeLevelFromClassroomName(name: string | undefined): SgsGradeLevel {
  if (!name) return 'ม.1';
  for (const lvl of SGS_GRADE_LEVELS) {
    if (name.includes(lvl)) return lvl;
  }
  return 'ม.1';
}

export default function StudentsPage({ schoolId, canEdit }: StudentsPageProps) {
  const [tab, setTab] = useState<MainTab>('registry');
  const [students, setStudents] = useState<Student[]>([]);
  const [classrooms, setClassrooms] = useState<Classroom[]>([]);
  const [teachers, setTeachers] = useState<TeacherOption[]>([]);
  const [dbSubjects, setDbSubjects] = useState<Subject[]>([]);
  const [profilesByStudentId, setProfilesByStudentId] = useState<
    Record<number, StudentPersonalProfile>
  >({});
  const [allGrades, setAllGrades] = useState<SgsScoreRecord[]>([]);

  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // ── Filter states (Tab 1: Registry) ──
  const [query, setQuery] = useState('');
  const [filterClassroom, setFilterClassroom] = useState<string>('all');

  // ── Add Student quick form ──
  const [showAddStudentForm, setShowAddStudentForm] = useState(false);
  const [studentCode, setStudentCode] = useState('');
  const [prefix, setPrefix] = useState('นาย');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [classroomId, setClassroomId] = useState<string>('');
  const [seatNoInput, setSeatNoInput] = useState<string>('1');
  const [citizenIdInput, setCitizenIdInput] = useState('');
  const [studyPlanInput, setStudyPlanInput] = useState<string>(
    STUDY_PLAN_OPTIONS[1],
  );
  const [guardianName, setGuardianName] = useState('');
  const [guardianPhone, setGuardianPhone] = useState('');

  // ── Student Personal Profile Modal (Part 1) ──
  const [editingStudent, setEditingStudent] = useState<Student | null>(null);
  const [editingProfile, setEditingProfile] =
    useState<StudentPersonalProfile | null>(null);

  // ── SGS Gradebook states (Part 2) ──
  const [sgsClassroomId, setSgsClassroomId] = useState<string>('all');
  const [sgsGradeLevel, setSgsGradeLevel] = useState<SgsGradeLevel>('ม.1');
  const [sgsTermNo, setSgsTermNo] = useState<1 | 2>(1);
  const [sgsYearBe, setSgsYearBe] = useState<number>(2568);
  const [sgsSubjectCode, setSgsSubjectCode] = useState<string>('ท11101');
  const [sgsSubjectName, setSgsSubjectName] = useState<string>('ภาษาไทยพื้นฐาน 1');
  const [sgsLearningArea, setSgsLearningArea] =
    useState<SgsLearningArea>('ภาษาไทย');
  const [sgsSubjectType, setSgsSubjectType] =
    useState<SgsSubjectType>('พื้นฐาน');
  const [sgsCredits, setSgsCredits] = useState<number>(1.5);
  const [sgsTotalHours, setSgsTotalHours] = useState<number>(60);

  // สัดส่วนคะแนนเต็ม SGS (รวม 100 คะแนน)
  const [maxPreMidWork, setMaxPreMidWork] = useState<number>(15);
  const [maxPreMidNotebook, setMaxPreMidNotebook] = useState<number>(10);
  const [maxMidterm, setMaxMidterm] = useState<number>(20);
  const [maxPostMidWork, setMaxPostMidWork] = useState<number>(15);
  const [maxPostMidNotebook, setMaxPostMidNotebook] = useState<number>(5);
  const [maxAffective, setMaxAffective] = useState<number>(5);
  const [maxFinal, setMaxFinal] = useState<number>(30);

  // Draft rows being edited in the SGS Gradebook table
  const [gradebookDraft, setGradebookDraft] = useState<
    Record<number, SgsScoreRecord>
  >({});

  // ── Multi-Year Transcript states (Part 3) ──
  const [selectedTranscriptStudentId, setSelectedTranscriptStudentId] =
    useState<number | null>(null);
  const [transcriptFilterLevel, setTranscriptFilterLevel] = useState<
    'all' | SgsGradeLevel
  >('all');

  // ── Classroom form (Tab 4) ──
  const [gradeLevel, setGradeLevel] = useState('ม.1');
  const [roomNo, setRoomNo] = useState('1');
  const [advisorId, setAdvisorId] = useState<string>('');

  const loadAll = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    setError(null);

    const [stuRes, clsRes, tchRes, guardRes, subRes, loadedProfiles, loadedGrades] =
      await Promise.all([
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
        supabase
          .from('SchoolWebStudentGuardians')
          .select('student_id, guardian_name, guardian_phone')
          .eq('id_school', schoolId),
        supabase
          .from('SchoolWebSubjects')
          .select('id, id_school, code, name, department_id, credits, is_active')
          .eq('id_school', schoolId)
          .order('code', { ascending: true }),
        fetchSchoolStudentProfiles(schoolId),
        fetchSchoolSgsGrades(schoolId),
      ]);

    const clsList = (!clsRes.error ? (clsRes.data as Classroom[] | null) : null) ?? [];
    setClassrooms(clsList);
    if (!tchRes.error) {
      setTeachers((tchRes.data as TeacherOption[] | null) ?? []);
    }
    if (!subRes.error) {
      setDbSubjects((subRes.data as Subject[] | null) ?? []);
    }

    const clsNameById = new Map<number, string>();
    for (const c of clsList) clsNameById.set(c.id, c.name);

    let studentRows: Student[] = [];
    if (stuRes.error) {
      setError(stuRes.error.message);
    } else {
      const rows = (stuRes.data as Student[] | null) ?? [];
      const guardians = guardRes.error
        ? null
        : new Map(
            (
              (guardRes.data as
                | {
                    student_id: number;
                    guardian_name: string | null;
                    guardian_phone: string | null;
                  }[]
                | null) ?? []
            ).map((g) => [g.student_id, g]),
          );
      studentRows = guardians
        ? rows.map((r) => {
            const g = guardians.get(r.id);
            return {
              ...r,
              guardian_name: g?.guardian_name ?? r.guardian_name ?? null,
              guardian_phone: g?.guardian_phone ?? r.guardian_phone ?? null,
            };
          })
        : rows;
      setStudents(studentRows);
    }

    // สร้างข้อมูลโปรไฟล์เริ่มต้นให้นักเรียนทุกคนที่ยังไม่มีในระบบ
    const nextProfiles: Record<number, StudentPersonalProfile> = {
      ...loadedProfiles,
    };
    const roomCounter = new Map<number, number>();
    for (const stu of studentRows) {
      const cid = stu.classroom_id ?? 0;
      const nextSeat = (roomCounter.get(cid) ?? 0) + 1;
      roomCounter.set(cid, nextSeat);
      if (!nextProfiles[stu.id]) {
        const clsName = stu.classroom_id
          ? clsNameById.get(stu.classroom_id)
          : 'ม.1/1';
        nextProfiles[stu.id] = buildDefaultStudentProfile(
          stu,
          nextSeat,
          inferGradeLevelFromClassroomName(clsName),
        );
      }
    }
    setProfilesByStudentId(nextProfiles);
    setAllGrades(loadedGrades);

    if (studentRows.length > 0) {
      setSelectedTranscriptStudentId((prev) => prev ?? studentRows[0].id);
    }
    if (clsList.length > 0) {
      setSgsClassroomId((prev) =>
        prev === 'all' ? String(clsList[0].id) : prev,
      );
    }

    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

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

  // รายวิชาที่มีให้เลือกในชั้นปีและภาคเรียนที่เลือก (รวมรายวิชามาตรฐาน SGS + รายวิชาใน DB)
  const availableSubjectsForGradeTerm = useMemo(() => {
    const std = getStandardSubjectsForGradeTerm(sgsGradeLevel, sgsTermNo);
    const list = [...std];
    for (const dbSub of dbSubjects) {
      if (!list.some((x) => x.code === dbSub.code)) {
        list.push({
          code: dbSub.code,
          name: dbSub.name,
          learning_area: 'วิทยาศาสตร์และเทคโนโลยี',
          subject_type: 'พื้นฐาน',
          credits: Number(dbSub.credits) || 1.0,
          total_hours: (Number(dbSub.credits) || 1.0) * 40,
        });
      }
    }
    return list;
  }, [sgsGradeLevel, sgsTermNo, dbSubjects]);

  // เมื่อเปลี่ยนชั้นปีหรือภาคเรียนในหน้าบันทึกคะแนน SGS ให้เลือกรายวิชาแรกของชั้นปีนั้นอัตโนมัติ
  const handleSelectGradeOrTermForSgs = (
    nextGrade: SgsGradeLevel,
    nextTerm: 1 | 2,
  ) => {
    setSgsGradeLevel(nextGrade);
    setSgsTermNo(nextTerm);
    const std = getStandardSubjectsForGradeTerm(nextGrade, nextTerm);
    if (std.length > 0) {
      const first = std[0];
      setSgsSubjectCode(first.code);
      setSgsSubjectName(first.name);
      setSgsLearningArea(first.learning_area);
      setSgsSubjectType(first.subject_type);
      setSgsCredits(first.credits);
      setSgsTotalHours(first.total_hours);
    }
  };

  const handlePickStandardSubject = (code: string) => {
    const found = availableSubjectsForGradeTerm.find((s) => s.code === code);
    if (!found) {
      setSgsSubjectCode(code);
      return;
    }
    setSgsSubjectCode(found.code);
    setSgsSubjectName(found.name);
    setSgsLearningArea(found.learning_area);
    setSgsSubjectType(found.subject_type);
    setSgsCredits(found.credits);
    setSgsTotalHours(found.total_hours);
  };

  // นักเรียนในห้องที่เลือกสำหรับกรอกคะแนน SGS
  const gradebookStudents = useMemo(() => {
    const filtered = students.filter((s) => {
      if (sgsClassroomId === 'all') return true;
      return String(s.classroom_id ?? '') === sgsClassroomId;
    });
    return [...filtered].sort((a, b) => {
      const seatA = profilesByStudentId[a.id]?.seat_no ?? 999;
      const seatB = profilesByStudentId[b.id]?.seat_no ?? 999;
      if (seatA !== seatB) return seatA - seatB;
      return a.student_code.localeCompare(b.student_code);
    });
  }, [students, sgsClassroomId, profilesByStudentId]);

  // ซิงค์ gradebookDraft เมื่อเปลี่ยนห้อง/ชั้นปี/เทอม/วิชา
  useEffect(() => {
    if (!schoolId) return;
    const nextDraft: Record<number, SgsScoreRecord> = {};
    for (const stu of gradebookStudents) {
      const existing = allGrades.find(
        (g) =>
          g.student_id === stu.id &&
          g.grade_level === sgsGradeLevel &&
          g.term_no === sgsTermNo &&
          g.subject_code === sgsSubjectCode,
      );
      if (existing) {
        nextDraft[stu.id] = { ...existing };
      } else {
        nextDraft[stu.id] = {
          id_school: schoolId,
          student_id: stu.id,
          grade_level: sgsGradeLevel,
          term_no: sgsTermNo,
          year_be: sgsYearBe,
          subject_code: sgsSubjectCode,
          subject_name: sgsSubjectName,
          learning_area: sgsLearningArea,
          subject_type: sgsSubjectType,
          credits: sgsCredits,
          max_pre_mid_work: maxPreMidWork,
          max_pre_mid_notebook: maxPreMidNotebook,
          max_midterm: maxMidterm,
          max_post_mid_work: maxPostMidWork,
          max_post_mid_notebook: maxPostMidNotebook,
          max_affective: maxAffective,
          max_final: maxFinal,
          pre_mid_work: 0,
          pre_mid_notebook: 0,
          midterm_score: 0,
          post_mid_work: 0,
          post_mid_notebook: 0,
          affective_score: 0,
          final_score: 0,
          attended_hours: sgsTotalHours,
          total_hours: sgsTotalHours,
          reading_thinking_writing: 3,
          desirable_characteristics: 3,
          special_status: sgsSubjectType === 'กิจกรรม' ? 'ผ' : '',
        };
      }
    }
    setGradebookDraft(nextDraft);
  }, [
    schoolId,
    gradebookStudents,
    allGrades,
    sgsGradeLevel,
    sgsTermNo,
    sgsYearBe,
    sgsSubjectCode,
    sgsSubjectName,
    sgsLearningArea,
    sgsSubjectType,
    sgsCredits,
    sgsTotalHours,
    maxPreMidWork,
    maxPreMidNotebook,
    maxMidterm,
    maxPostMidWork,
    maxPostMidNotebook,
    maxAffective,
    maxFinal,
  ]);

  const filteredStudents = useMemo(() => {
    const q = query.trim().toLowerCase();
    return students
      .filter((s) => {
        if (
          filterClassroom !== 'all' &&
          String(s.classroom_id ?? '') !== filterClassroom
        ) {
          return false;
        }
        if (!q) return true;
        const fullName =
          `${s.prefix ?? ''}${s.first_name} ${s.last_name}`.toLowerCase();
        const cit = (
          profilesByStudentId[s.id]?.citizen_id ?? ''
        ).toLowerCase();
        return (
          s.student_code.toLowerCase().includes(q) ||
          fullName.includes(q) ||
          cit.includes(q)
        );
      })
      .sort((a, b) => {
        const seatA = profilesByStudentId[a.id]?.seat_no ?? 999;
        const seatB = profilesByStudentId[b.id]?.seat_no ?? 999;
        if (
          filterClassroom !== 'all' &&
          seatA !== seatB
        ) {
          return seatA - seatB;
        }
        return a.student_code.localeCompare(b.student_code);
      });
  }, [students, query, filterClassroom, profilesByStudentId]);

  // คำนวณ GPAX สะสมของนักเรียนแต่ละคนเพื่อแสดงในตารางทะเบียนนักเรียน
  const gpaxByStudentId = useMemo(() => {
    const byStu = new Map<number, SgsScoreRecord[]>();
    for (const r of allGrades) {
      const list = byStu.get(r.student_id) ?? [];
      list.push(r);
      byStu.set(r.student_id, list);
    }
    const result = new Map<number, { gpax: number; termsCount: number }>();
    for (const [stuId, recs] of byStu.entries()) {
      const tr = computeStudentMultiYearTranscript(recs);
      result.set(stuId, {
        gpax: tr.overallGpax,
        termsCount: tr.terms.length,
      });
    }
    return result;
  }, [allGrades]);

  // ── Handlers: Part 1 (Student Registry & Personal Profile) ──
  async function handleAddStudent(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);
    setNotice(null);

    const { data: inserted, error: insErr } = await supabase
      .from('SchoolWebStudents')
      .insert({
        id_school: schoolId,
        student_code: studentCode.trim(),
        prefix: prefix.trim() || null,
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        classroom_id: classroomId ? Number(classroomId) : null,
        guardian_name: guardianName.trim() || null,
        guardian_phone: guardianPhone.trim() || null,
        status: 'enrolled',
      })
      .select('*')
      .maybeSingle();

    if (insErr) {
      setError(insErr.message);
    } else {
      if (inserted) {
        const stu = inserted as Student;
        const clsName = stu.classroom_id
          ? classroomMap.get(stu.classroom_id)?.name
          : 'ม.1/1';
        const defaultProf = buildDefaultStudentProfile(
          stu,
          Number(seatNoInput) || 1,
          inferGradeLevelFromClassroomName(clsName),
        );
        const profileToSave: StudentPersonalProfile = {
          ...defaultProf,
          seat_no: Number(seatNoInput) || 1,
          citizen_id: citizenIdInput.trim() || defaultProf.citizen_id,
          study_plan: studyPlanInput || defaultProf.study_plan,
        };
        const res = await saveStudentPersonalProfile(profileToSave);
        if (res.error) setError(`บันทึกแฟ้มประวัติไม่สำเร็จ: ${res.error}`);
      }
      setStudentCode('');
      setFirstName('');
      setLastName('');
      setCitizenIdInput('');
      setGuardianName('');
      setGuardianPhone('');
      setShowAddStudentForm(false);
      setNotice('เพิ่มข้อมูลนักเรียนและสร้างแฟ้มประวัตินักเรียนเรียบร้อยแล้ว');
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

  function handleOpenProfileModal(student: Student) {
    const clsName = student.classroom_id
      ? classroomMap.get(student.classroom_id)?.name
      : 'ม.1/1';
    const existing =
      profilesByStudentId[student.id] ??
      buildDefaultStudentProfile(
        student,
        1,
        inferGradeLevelFromClassroomName(clsName),
      );
    setEditingStudent({ ...student });
    setEditingProfile({ ...existing });
  }

  async function handleSaveProfileModal(e: FormEvent) {
    e.preventDefault();
    if (!editingStudent || !editingProfile || !schoolId) return;
    setBusy(true);
    setError(null);
    setNotice(null);

    if (canEdit) {
      await supabase
        .from('SchoolWebStudents')
        .update({
          student_code: editingStudent.student_code.trim(),
          prefix: editingStudent.prefix?.trim() || null,
          first_name: editingStudent.first_name.trim(),
          last_name: editingStudent.last_name.trim(),
          classroom_id: editingStudent.classroom_id,
          guardian_name: editingStudent.guardian_name?.trim() || null,
          guardian_phone: editingStudent.guardian_phone?.trim() || null,
          status: editingStudent.status,
        })
        .eq('id', editingStudent.id);
    }

    const profRes = await saveStudentPersonalProfile(editingProfile);
    if (profRes.error) {
      setError(`บันทึกแฟ้มประวัติไม่สำเร็จ: ${profRes.error}`);
      setBusy(false);
      return;
    }
    setProfilesByStudentId((prev) => ({
      ...prev,
      [editingStudent.id]: editingProfile,
    }));
    setEditingStudent(null);
    setEditingProfile(null);
    setNotice(
      `บันทึกแฟ้มประวัติส่วนตัวของ ${editingStudent.prefix ?? ''}${editingStudent.first_name} ${editingStudent.last_name} เรียบร้อยแล้ว`,
    );
    await loadAll();
    setBusy(false);
  }

  // ── Handlers: Part 2 (SGS Gradebook) ──
  function updateDraftScore(
    studentId: number,
    field: keyof SgsScoreRecord,
    value: number | string,
  ) {
    setGradebookDraft((prev) => {
      const current = prev[studentId];
      if (!current) return prev;
      return {
        ...prev,
        [studentId]: {
          ...current,
          [field]: value,
        },
      };
    });
  }

  function handleAutoFillSampleScoresForRoom() {
    if (!schoolId) return;
    setGradebookDraft((prev) => {
      const next: Record<number, SgsScoreRecord> = { ...prev };
      gradebookStudents.forEach((stu, idx) => {
        const row = next[stu.id];
        if (!row) return;
        const seed = (stu.id * 13 + idx * 7) % 19;
        const preW = Math.min(
          maxPreMidWork,
          Math.round(maxPreMidWork * (0.72 + (seed % 5) * 0.06)),
        );
        const preNb = Math.min(
          maxPreMidNotebook,
          Math.round(maxPreMidNotebook * (0.75 + (seed % 4) * 0.06)),
        );
        const mid = Math.min(
          maxMidterm,
          Math.round(maxMidterm * (0.65 + (seed % 6) * 0.05)),
        );
        const postW = Math.min(
          maxPostMidWork,
          Math.round(maxPostMidWork * (0.7 + ((seed + 2) % 5) * 0.06)),
        );
        const postNb = Math.min(
          maxPostMidNotebook,
          Math.round(maxPostMidNotebook * (0.8 + (seed % 3) * 0.08)),
        );
        const aff = maxAffective;
        const fin = Math.min(
          maxFinal,
          Math.round(maxFinal * (0.62 + (seed % 7) * 0.05)),
        );

        next[stu.id] = {
          ...row,
          max_pre_mid_work: maxPreMidWork,
          max_pre_mid_notebook: maxPreMidNotebook,
          max_midterm: maxMidterm,
          max_post_mid_work: maxPostMidWork,
          max_post_mid_notebook: maxPostMidNotebook,
          max_affective: maxAffective,
          max_final: maxFinal,
          pre_mid_work: preW,
          pre_mid_notebook: preNb,
          midterm_score: mid,
          post_mid_work: postW,
          post_mid_notebook: postNb,
          affective_score: aff,
          final_score: fin,
          attended_hours: Math.max(0, sgsTotalHours - (seed % 3)),
          total_hours: sgsTotalHours,
          reading_thinking_writing: 3,
          desirable_characteristics: 3,
          special_status: sgsSubjectType === 'กิจกรรม' ? 'ผ' : '',
        };
      });
      return next;
    });
    setNotice(
      'เติมคะแนนตัวอย่าง (คะแนนเก็บ, สมุด, กลางภาค, ปลายภาค) และคำนวณเกรดอัตโนมัติเรียบร้อยแล้ว กด "บันทึกคะแนน SGS" เพื่อบันทึก',
    );
  }

  async function handleSaveGradebook() {
    if (!schoolId) return;
    setBusy(true);
    setError(null);
    setNotice(null);

    const recordsToSave: SgsScoreRecord[] = gradebookStudents
      .map((stu) => gradebookDraft[stu.id])
      .filter(Boolean)
      .map((r) => ({
        ...r,
        grade_level: sgsGradeLevel,
        term_no: sgsTermNo,
        year_be: sgsYearBe,
        subject_code: sgsSubjectCode.trim(),
        subject_name: sgsSubjectName.trim(),
        learning_area: sgsLearningArea,
        subject_type: sgsSubjectType,
        credits: Number(sgsCredits) || 0,
        max_pre_mid_work: Number(maxPreMidWork) || 0,
        max_pre_mid_notebook: Number(maxPreMidNotebook) || 0,
        max_midterm: Number(maxMidterm) || 0,
        max_post_mid_work: Number(maxPostMidWork) || 0,
        max_post_mid_notebook: Number(maxPostMidNotebook) || 0,
        max_affective: Number(maxAffective) || 0,
        max_final: Number(maxFinal) || 0,
        total_hours: Number(sgsTotalHours) || 40,
      }));

    const gradeRes = await saveSgsGradeRecords(schoolId, recordsToSave);
    if (gradeRes.error) {
      setError(`บันทึกคะแนนไม่สำเร็จ: ${gradeRes.error}`);
      setBusy(false);
      return;
    }
    const refreshed = await fetchSchoolSgsGrades(schoolId);
    setAllGrades(refreshed);
    setNotice(
      `บันทึกคะแนนและผลการเรียนวิชา "${sgsSubjectCode} ${sgsSubjectName}" (${sgsGradeLevel} ภาคเรียนที่ ${sgsTermNo}/${sgsYearBe}) จำนวน ${recordsToSave.length} คน เรียบร้อยแล้ว`,
    );
    setBusy(false);
  }

  function handleExportSgsCsv() {
    const clsName =
      sgsClassroomId === 'all'
        ? `ทุกห้อง-${sgsGradeLevel}`
        : classroomMap.get(Number(sgsClassroomId))?.name ?? sgsGradeLevel;

    const rows = gradebookStudents
      .map((stu, idx) => {
        const rec = gradebookDraft[stu.id];
        if (!rec) return null;
        return {
          seatNo: profilesByStudentId[stu.id]?.seat_no ?? idx + 1,
          studentCode: stu.student_code,
          fullName: `${stu.prefix ?? ''}${stu.first_name} ${stu.last_name}`,
          record: rec,
          computed: computeSgsGradeRow(rec),
        };
      })
      .filter(Boolean) as {
      seatNo: number;
      studentCode: string;
      fullName: string;
      record: SgsScoreRecord;
      computed: ReturnType<typeof computeSgsGradeRow>;
    }[];

    downloadSgsGradebookCsv({
      schoolName: 'โรงเรียน',
      gradeLevel: sgsGradeLevel,
      classroomName: clsName,
      termNo: sgsTermNo,
      yearBe: sgsYearBe,
      subjectCode: sgsSubjectCode,
      subjectName: sgsSubjectName,
      rows,
    });
  }

  // ── Handlers: Part 3 (Multi-Year Transcript) ──
  const selectedTranscriptStudent = useMemo(
    () =>
      students.find((s) => s.id === selectedTranscriptStudentId) ??
      students[0] ??
      null,
    [students, selectedTranscriptStudentId],
  );

  const selectedStudentGradeRecords = useMemo(() => {
    if (!selectedTranscriptStudent) return [];
    return allGrades.filter(
      (r) => r.student_id === selectedTranscriptStudent.id,
    );
  }, [allGrades, selectedTranscriptStudent]);

  const selectedStudentTranscript = useMemo(
    () => computeStudentMultiYearTranscript(selectedStudentGradeRecords),
    [selectedStudentGradeRecords],
  );

  // ── Handlers: Tab 4 (Classrooms) ──
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
      setRoomNo('');
      setAdvisorId('');
      await loadAll();
    }
    setBusy(false);
  }

  async function removeClassroom(id: number) {
    if (!canEdit) return;
    if (!window.confirm('ยืนยันลบห้องเรียนนี้?')) return;
    setBusy(true);
    const { error: delErr } = await supabase
      .from('SchoolWebClassrooms')
      .delete()
      .eq('id', id);
    if (delErr) setError(delErr.message);
    else await loadAll();
    setBusy(false);
  }

  const maxScoreSum =
    (Number(maxPreMidWork) || 0) +
    (Number(maxPreMidNotebook) || 0) +
    (Number(maxMidterm) || 0) +
    (Number(maxPostMidWork) || 0) +
    (Number(maxPostMidNotebook) || 0) +
    (Number(maxAffective) || 0) +
    (Number(maxFinal) || 0);

  return (
    <div className="space-y-6">
      {/* ── Page Header & 4 Main Tabs ────────────────────────────────────── */}
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <span className="badge-brand mb-1.5">
            <GraduationCap className="h-3.5 w-3.5" />
            ระบบสารสนเทศนักเรียน &amp; ประมวลผลการเรียนมาตรฐาน SGS (สพฐ.)
          </span>
          <h2 className="text-xl font-semibold text-ink">
            ทะเบียนประวัตินักเรียน บันทึกคะแนน SGS และผลการเรียนสะสมทุกชั้นปี
          </h2>
          <p className="mt-1 text-xs text-slate-600">
            จัดการแฟ้มข้อมูลส่วนตัวนักเรียน กรอกคะแนนเก็บ/สมุด/กลางภาค/ปลายภาค
            คำนวณเกรดอัตโนมัติ และดูใบผลการเรียนสะสม (ปพ.1 / GPAX) ครบทุกชั้นปี (ม.1 – ม.6)
          </p>
        </div>

        <div className="flex flex-wrap gap-1.5 rounded-2xl border border-line bg-white p-1.5 shadow-card">
          <button
            type="button"
            onClick={() => setTab('registry')}
            className={`inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-semibold transition-colors ${
              tab === 'registry'
                ? 'bg-brand-600 text-white shadow-sm'
                : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
            }`}
          >
            <Users className="h-3.5 w-3.5" />
            <span>1. ทะเบียนและประวัตินักเรียน ({students.length})</span>
          </button>

          <button
            type="button"
            onClick={() => setTab('sgs_gradebook')}
            className={`inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-semibold transition-colors ${
              tab === 'sgs_gradebook'
                ? 'bg-brand-600 text-white shadow-sm'
                : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
            }`}
          >
            <Calculator className="h-3.5 w-3.5" />
            <span>2. บันทึกคะแนนและตัดเกรด SGS (ปพ.5)</span>
          </button>

          <button
            type="button"
            onClick={() => setTab('transcript')}
            className={`inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-semibold transition-colors ${
              tab === 'transcript'
                ? 'bg-brand-600 text-white shadow-sm'
                : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
            }`}
          >
            <Award className="h-3.5 w-3.5" />
            <span>3. ผลการเรียนสะสมทุกชั้นปี (ปพ.1)</span>
          </button>

          <button
            type="button"
            onClick={() => setTab('classrooms')}
            className={`inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-semibold transition-colors ${
              tab === 'classrooms'
                ? 'bg-brand-600 text-white shadow-sm'
                : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
            }`}
          >
            <BookOpen className="h-3.5 w-3.5" />
            <span>4. ห้องเรียน ({classrooms.length})</span>
          </button>
        </div>
      </div>

      {error && (
        <div className="alert-error flex items-center justify-between">
          <span>{error}</span>
          <button
            type="button"
            onClick={() => setError(null)}
            className="text-xs underline"
          >
            ปิด
          </button>
        </div>
      )}

      {notice && (
        <div className="alert-ok flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Check className="h-4 w-4 shrink-0" />
            <span>{notice}</span>
          </div>
          <button
            type="button"
            onClick={() => setNotice(null)}
            className="text-xs underline shrink-0"
          >
            รับทราบ
          </button>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          TAB 1 (PART 1): ทะเบียนและแฟ้มประวัตินักเรียนฉบับสมบูรณ์
         ════════════════════════════════════════════════════════════════════ */}
      {tab === 'registry' && (
        <div className="space-y-5">
          {/* Search, Filter & Add Student Bar */}
          <div className="surface-card p-5 space-y-4">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex flex-1 flex-col gap-2.5 sm:flex-row sm:items-center">
                <div className="relative flex-1 max-w-md">
                  <Search
                    className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                    strokeWidth={1.5}
                  />
                  <input
                    type="text"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="ค้นหารหัสนักเรียน, ชื่อ-นามสกุล หรือเลขบัตรประชาชน 13 หลัก..."
                    className="input pl-9"
                  />
                </div>

                <select
                  value={filterClassroom}
                  onChange={(e) => setFilterClassroom(e.target.value)}
                  className="input sm:w-52"
                  aria-label="กรองตามห้องเรียน"
                >
                  <option value="all">ทุกห้องเรียน ({students.length} คน)</option>
                  {classrooms.map((c) => (
                    <option key={c.id} value={String(c.id)}>
                      ห้อง {c.name}
                    </option>
                  ))}
                </select>
              </div>

              {canEdit && (
                <button
                  type="button"
                  onClick={() => setShowAddStudentForm((v) => !v)}
                  className="btn-primary shrink-0"
                >
                  <Plus className="h-4 w-4" />
                  <span>
                    {showAddStudentForm
                      ? 'ซ่อนฟอร์มเพิ่มนักเรียน'
                      : 'ลงทะเบียนนักเรียนใหม่'}
                  </span>
                </button>
              )}
            </div>

            {/* Collapsible Add Student Form */}
            {canEdit && showAddStudentForm && (
              <form
                onSubmit={handleAddStudent}
                className="subcard space-y-4 border-brand-200 bg-brand-50/30"
              >
                <div className="flex items-center justify-between border-b border-line pb-2.5">
                  <h3 className="text-sm font-semibold text-ink">
                    ลงทะเบียนนักเรียนใหม่เข้าสู่ระบบโรงเรียนและระบบ SGS
                  </h3>
                  <span className="text-xs text-slate-500">
                    หลังบันทึกแล้วสามารถกด &ldquo;แฟ้มประวัติ&rdquo; เพื่อกรอกประวัติส่วนตัวเพิ่มเติมได้
                  </span>
                </div>

                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                  <label className="field">
                    <span>รหัสนักเรียน (5 หลัก) *</span>
                    <input
                      type="text"
                      required
                      value={studentCode}
                      onChange={(e) => setStudentCode(e.target.value)}
                      placeholder="เช่น 68001"
                      className="input"
                    />
                  </label>

                  <label className="field">
                    <span>เลขที่ในห้องเรียน</span>
                    <input
                      type="number"
                      min={1}
                      value={seatNoInput}
                      onChange={(e) => setSeatNoInput(e.target.value)}
                      className="input"
                    />
                  </label>

                  <label className="field">
                    <span>เลขประจำตัวประชาชน (13 หลัก)</span>
                    <input
                      type="text"
                      value={citizenIdInput}
                      onChange={(e) => setCitizenIdInput(e.target.value)}
                      placeholder="1-3104-xxxxx-xx-x"
                      className="input"
                    />
                  </label>

                  <label className="field">
                    <span>ห้องเรียนปัจจุบัน</span>
                    <select
                      value={classroomId}
                      onChange={(e) => setClassroomId(e.target.value)}
                      className="input"
                    >
                      <option value="">-- เลือกห้องเรียน --</option>
                      {classrooms.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label className="field">
                    <span>คำนำหน้า *</span>
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
                  </label>

                  <label className="field">
                    <span>ชื่อ (ภาษาไทย) *</span>
                    <input
                      type="text"
                      required
                      value={firstName}
                      onChange={(e) => setFirstName(e.target.value)}
                      placeholder="ชื่อจริง"
                      className="input"
                    />
                  </label>

                  <label className="field">
                    <span>นามสกุล (ภาษาไทย) *</span>
                    <input
                      type="text"
                      required
                      value={lastName}
                      onChange={(e) => setLastName(e.target.value)}
                      placeholder="นามสกุล"
                      className="input"
                    />
                  </label>

                  <label className="field">
                    <span>แผนการเรียน</span>
                    <select
                      value={studyPlanInput}
                      onChange={(e) => setStudyPlanInput(e.target.value)}
                      className="input"
                    >
                      {STUDY_PLAN_OPTIONS.map((p) => (
                        <option key={p} value={p}>
                          {p}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label className="field sm:col-span-2">
                    <span>ชื่อผู้ปกครอง</span>
                    <input
                      type="text"
                      value={guardianName}
                      onChange={(e) => setGuardianName(e.target.value)}
                      placeholder="ชื่อ-นามสกุลผู้ปกครอง"
                      className="input"
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>เบอร์โทรศัพท์ผู้ปกครอง</span>
                    <input
                      type="text"
                      value={guardianPhone}
                      onChange={(e) => setGuardianPhone(e.target.value)}
                      placeholder="08x-xxx-xxxx"
                      className="input"
                    />
                  </label>
                </div>

                <div className="flex justify-end gap-2 pt-1">
                  <button
                    type="button"
                    onClick={() => setShowAddStudentForm(false)}
                    className="btn-secondary"
                  >
                    ยกเลิก
                  </button>
                  <button type="submit" disabled={busy} className="btn-primary">
                    <Plus className="h-4 w-4" />
                    <span>บันทึกทะเบียนนักเรียน</span>
                  </button>
                </div>
              </form>
            )}

            {/* Student Registry Table */}
            {loading ? (
              <p className="py-10 text-center text-sm text-slate-500">
                กำลังโหลดข้อมูลทะเบียนนักเรียน...
              </p>
            ) : filteredStudents.length === 0 ? (
              <div className="py-10 text-center space-y-2">
                <p className="text-sm text-slate-500">
                  ไม่พบข้อมูลนักเรียนตามเงื่อนไขที่ค้นหา
                </p>
              </div>
            ) : (
              <div className="overflow-x-auto rounded-xl border border-line">
                <table className="table">
                  <thead>
                    <tr>
                      <th className="w-16 text-center">เลขที่</th>
                      <th>รหัสนักเรียน</th>
                      <th>ชื่อ-นามสกุล / เลขบัตรประชาชน</th>
                      <th>ชั้น/ห้อง</th>
                      <th>แผนการเรียน</th>
                      <th>ผู้ปกครอง &amp; เบอร์ติดต่อ</th>
                      <th className="text-center">GPAX สะสม</th>
                      <th>สถานะ</th>
                      <th className="text-right">จัดการข้อมูล &amp; ผลการเรียน</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredStudents.map((s, idx) => {
                      const prof = profilesByStudentId[s.id];
                      const cls = s.classroom_id
                        ? classroomMap.get(s.classroom_id)
                        : null;
                      const gpaxInfo = gpaxByStudentId.get(s.id);

                      return (
                        <tr key={s.id}>
                          <td className="text-center font-semibold text-slate-700 tabular-nums">
                            {prof?.seat_no ?? idx + 1}
                          </td>
                          <td className="font-mono text-xs font-semibold text-brand-700">
                            {s.student_code}
                          </td>
                          <td>
                            <div className="font-medium text-ink">
                              {s.prefix ?? ''}
                              {s.first_name} {s.last_name}
                            </div>
                            <div className="text-[11px] text-slate-500 font-mono">
                              บัตรประชาชน: {prof?.citizen_id || '-'} • เพศ
                              {prof?.gender || '-'} • หมู่เลือด{' '}
                              {prof?.blood_group || '-'}
                            </div>
                          </td>
                          <td>
                            <span className="badge-brand">
                              {cls?.name ?? 'ยังไม่ระบุห้อง'}
                            </span>
                          </td>
                          <td className="text-xs text-slate-600">
                            {prof?.study_plan || 'ทั่วไป'}
                          </td>
                          <td className="text-xs text-slate-600">
                            <div className="font-medium text-slate-800">
                              {s.guardian_name || prof?.father_name || '-'}
                            </div>
                            <div className="text-[11px] text-slate-500">
                              {s.guardian_phone || prof?.father_phone || '-'}
                            </div>
                          </td>
                          <td className="text-center">
                            {gpaxInfo && gpaxInfo.termsCount > 0 ? (
                              <div className="inline-flex flex-col items-center">
                                <span className="badge-green font-mono font-semibold">
                                  {gpaxInfo.gpax.toFixed(2)}
                                </span>
                                <span className="text-[10px] text-slate-500 mt-0.5">
                                  {gpaxInfo.termsCount} ภาคเรียน
                                </span>
                              </div>
                            ) : (
                              <span className="text-xs text-slate-400">
                                ยังไม่มีเกรด
                              </span>
                            )}
                          </td>
                          <td>
                            {canEdit ? (
                              <select
                                value={s.status}
                                onChange={(e) =>
                                  updateStudentStatus(
                                    s.id,
                                    e.target.value as StudentStatus,
                                  )
                                }
                                aria-label="สถานะนักเรียน"
                                className="input w-auto py-1 text-xs"
                              >
                                {(
                                  Object.keys(STATUS_LABEL) as StudentStatus[]
                                ).map((st) => (
                                  <option key={st} value={st}>
                                    {STATUS_LABEL[st]}
                                  </option>
                                ))}
                              </select>
                            ) : (
                              <span className="text-xs text-slate-600">
                                {STATUS_LABEL[s.status]}
                              </span>
                            )}
                          </td>
                          <td className="text-right">
                            <div className="inline-flex flex-wrap justify-end gap-1.5">
                              <button
                                type="button"
                                onClick={() => handleOpenProfileModal(s)}
                                className="btn-secondary btn-sm"
                                title="ดูและแก้ไขข้อมูลส่วนตัวนักเรียนฉบับเต็ม"
                              >
                                <Edit3 className="h-3.5 w-3.5 text-brand-600" />
                                <span>แฟ้มประวัติ</span>
                              </button>
                              <button
                                type="button"
                                onClick={() => {
                                  setSelectedTranscriptStudentId(s.id);
                                  setTab('transcript');
                                }}
                                className="btn-primary btn-sm"
                                title="ดูผลการเรียนสะสมทุกชั้นปี (ปพ.1 / GPAX)"
                              >
                                <Award className="h-3.5 w-3.5" />
                                <span>ผลการเรียนทุกชั้นปี</span>
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          TAB 2 (PART 2): บันทึกคะแนนและตัดเกรดตามโครงสร้าง SGS (ปพ.5)
         ════════════════════════════════════════════════════════════════════ */}
      {tab === 'sgs_gradebook' && (
        <div className="space-y-5">
          {/* 2.1 ตัวเลือกชั้นปี ภาคเรียน ห้องเรียน และรายวิชา */}
          <div className="surface-card p-5 space-y-5">
            <div className="flex flex-col gap-3 border-b border-line pb-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h3 className="text-base font-semibold text-ink">
                  ตารางบันทึกคะแนนและประมวลผลเกรดมาตรฐาน SGS (แบบ ปพ.5)
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  เลือกห้องเรียน ชั้นปี (ม.1 – ม.6) ภาคเรียน และรายวิชา
                  ระบบจะคำนวณคะแนนเก็บ คะแนนสมุด กลางภาค ปลายภาค และตัดเกรดให้อัตโนมัติทันที
                </p>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                {canEdit && (
                  <button
                    type="button"
                    onClick={handleAutoFillSampleScoresForRoom}
                    disabled={busy || gradebookStudents.length === 0}
                    className="btn-secondary btn-sm"
                  >
                    <Sparkles className="h-3.5 w-3.5 text-amber-600" />
                    <span>เติมคะแนนตัวอย่างทั้งห้อง</span>
                  </button>
                )}
                <button
                  type="button"
                  onClick={handleExportSgsCsv}
                  disabled={gradebookStudents.length === 0}
                  className="btn-secondary btn-sm"
                >
                  <FileSpreadsheet className="h-3.5 w-3.5 text-emerald-600" />
                  <span>ส่งออกไฟล์ CSV นำเข้า SGS</span>
                </button>
                {canEdit && (
                  <button
                    type="button"
                    onClick={handleSaveGradebook}
                    disabled={busy || gradebookStudents.length === 0}
                    className="btn-primary btn-sm"
                  >
                    <Save className="h-3.5 w-3.5" />
                    <span>บันทึกคะแนน SGS</span>
                  </button>
                )}
              </div>
            </div>

            {/* Filter & Subject Selector Grid */}
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-6">
              <label className="field">
                <span>ห้องเรียนที่จะกรอกคะแนน</span>
                <select
                  value={sgsClassroomId}
                  onChange={(e) => {
                    const val = e.target.value;
                    setSgsClassroomId(val);
                    if (val !== 'all') {
                      const cls = classroomMap.get(Number(val));
                      if (cls) {
                        const inferred = inferGradeLevelFromClassroomName(
                          cls.name,
                        );
                        handleSelectGradeOrTermForSgs(inferred, sgsTermNo);
                      }
                    }
                  }}
                  className="input font-semibold"
                >
                  <option value="all">นักเรียนทั้งหมดทุกห้อง</option>
                  {classrooms.map((c) => (
                    <option key={c.id} value={String(c.id)}>
                      ห้อง {c.name}
                    </option>
                  ))}
                </select>
              </label>

              <label className="field">
                <span>ระดับชั้นปีของผลการเรียน</span>
                <select
                  value={sgsGradeLevel}
                  onChange={(e) =>
                    handleSelectGradeOrTermForSgs(
                      e.target.value as SgsGradeLevel,
                      sgsTermNo,
                    )
                  }
                  className="input font-semibold text-brand-700"
                >
                  {SGS_GRADE_LEVELS.map((lvl) => (
                    <option key={lvl} value={lvl}>
                      ชั้นมัธยมศึกษาปีที่ {lvl.replace('ม.', '')} ({lvl})
                    </option>
                  ))}
                </select>
              </label>

              <label className="field">
                <span>ภาคเรียน</span>
                <select
                  value={sgsTermNo}
                  onChange={(e) =>
                    handleSelectGradeOrTermForSgs(
                      sgsGradeLevel,
                      Number(e.target.value) as 1 | 2,
                    )
                  }
                  className="input font-semibold"
                >
                  <option value={1}>ภาคเรียนที่ 1</option>
                  <option value={2}>ภาคเรียนที่ 2</option>
                </select>
              </label>

              <label className="field">
                <span>ปีการศึกษา (พ.ศ.)</span>
                <input
                  type="number"
                  value={sgsYearBe}
                  onChange={(e) =>
                    setSgsYearBe(Number(e.target.value) || 2568)
                  }
                  className="input"
                />
              </label>

              <label className="field lg:col-span-2">
                <span>เลือกรายวิชาตามโครงสร้างหลักสูตร</span>
                <select
                  value={sgsSubjectCode}
                  onChange={(e) => handlePickStandardSubject(e.target.value)}
                  className="input font-semibold"
                >
                  {availableSubjectsForGradeTerm.map((sub) => (
                    <option key={sub.code} value={sub.code}>
                      {sub.code} — {sub.name} ({sub.credits} นก.)
                    </option>
                  ))}
                </select>
              </label>
            </div>

            {/* Subject Details & Custom Score Ratio (SGS 100-Point Config) */}
            <div className="subcard space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-xs font-semibold text-ink">
                    ตั้งค่าโครงสร้างคะแนนเต็มของวิชา (มาตรฐาน SGS รวม 100 คะแนน):
                  </span>
                  <span
                    className={
                      maxScoreSum === 100
                        ? 'badge-green'
                        : 'badge-amber'
                    }
                  >
                    คะแนนเต็มรวมปัจจุบัน: {maxScoreSum} / 100 คะแนน
                  </span>
                </div>
                <div className="flex flex-wrap items-center gap-2 text-xs">
                  <button
                    type="button"
                    onClick={() => {
                      setMaxPreMidWork(15);
                      setMaxPreMidNotebook(10);
                      setMaxMidterm(20);
                      setMaxPostMidWork(15);
                      setMaxPostMidNotebook(5);
                      setMaxAffective(5);
                      setMaxFinal(30);
                    }}
                    className="btn-secondary btn-sm py-1 text-[11px]"
                  >
                    สัดส่วน 70 : 30 (มาตรฐาน)
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setMaxPreMidWork(20);
                      setMaxPreMidNotebook(10);
                      setMaxMidterm(20);
                      setMaxPostMidWork(15);
                      setMaxPostMidNotebook(10);
                      setMaxAffective(5);
                      setMaxFinal(20);
                    }}
                    className="btn-secondary btn-sm py-1 text-[11px]"
                  >
                    สัดส่วน 80 : 20
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4 lg:grid-cols-9">
                <label className="field">
                  <span className="text-[11px]">รหัสวิชา</span>
                  <input
                    className="input py-1.5 text-xs font-mono"
                    value={sgsSubjectCode}
                    onChange={(e) => setSgsSubjectCode(e.target.value)}
                  />
                </label>

                <label className="field sm:col-span-2">
                  <span className="text-[11px]">ชื่อรายวิชา</span>
                  <input
                    className="input py-1.5 text-xs"
                    value={sgsSubjectName}
                    onChange={(e) => setSgsSubjectName(e.target.value)}
                  />
                </label>

                <label className="field">
                  <span className="text-[11px]">หน่วยกิต</span>
                  <input
                    type="number"
                    step="0.5"
                    className="input py-1.5 text-xs"
                    value={sgsCredits}
                    onChange={(e) =>
                      setSgsCredits(Number(e.target.value) || 0)
                    }
                  />
                </label>

                <label className="field">
                  <span className="text-[11px]">เก็บก่อนกลาง (เต็ม)</span>
                  <input
                    type="number"
                    className="input py-1.5 text-xs"
                    value={maxPreMidWork}
                    onChange={(e) =>
                      setMaxPreMidWork(Number(e.target.value) || 0)
                    }
                  />
                </label>

                <label className="field">
                  <span className="text-[11px]">สมุดก่อนกลาง (เต็ม)</span>
                  <input
                    type="number"
                    className="input py-1.5 text-xs"
                    value={maxPreMidNotebook}
                    onChange={(e) =>
                      setMaxPreMidNotebook(Number(e.target.value) || 0)
                    }
                  />
                </label>

                <label className="field">
                  <span className="text-[11px]">สอบกลางภาค (เต็ม)</span>
                  <input
                    type="number"
                    className="input py-1.5 text-xs font-semibold text-brand-700"
                    value={maxMidterm}
                    onChange={(e) =>
                      setMaxMidterm(Number(e.target.value) || 0)
                    }
                  />
                </label>

                <label className="field">
                  <span className="text-[11px]">เก็บ+สมุดหลังกลาง</span>
                  <div className="flex gap-1">
                    <input
                      type="number"
                      title="คะแนนเก็บหลังกลางภาค"
                      className="input py-1.5 px-2 text-xs"
                      value={maxPostMidWork}
                      onChange={(e) =>
                        setMaxPostMidWork(Number(e.target.value) || 0)
                      }
                    />
                    <input
                      type="number"
                      title="คะแนนสมุดหลังกลางภาค"
                      className="input py-1.5 px-2 text-xs"
                      value={maxPostMidNotebook}
                      onChange={(e) =>
                        setMaxPostMidNotebook(Number(e.target.value) || 0)
                      }
                    />
                  </div>
                </label>

                <label className="field">
                  <span className="text-[11px]">จิตพิสัย / ปลายภาค</span>
                  <div className="flex gap-1">
                    <input
                      type="number"
                      title="คะแนนจิตพิสัย"
                      className="input py-1.5 px-2 text-xs"
                      value={maxAffective}
                      onChange={(e) =>
                        setMaxAffective(Number(e.target.value) || 0)
                      }
                    />
                    <input
                      type="number"
                      title="คะแนนสอบปลายภาค"
                      className="input py-1.5 px-2 text-xs font-semibold text-brand-700"
                      value={maxFinal}
                      onChange={(e) =>
                        setMaxFinal(Number(e.target.value) || 0)
                      }
                    />
                  </div>
                </label>
              </div>
            </div>

            {/* 2.2 ตารางกรอกคะแนน SGS รายบุคคล */}
            {gradebookStudents.length === 0 ? (
              <div className="py-10 text-center text-sm text-slate-500">
                ไม่พบรายชื่อนักเรียนในห้องที่เลือก
              </div>
            ) : (
              <div className="overflow-x-auto rounded-xl border border-line">
                <table className="table text-xs">
                  <thead>
                    <tr className="bg-slate-100/80 text-center">
                      <th className="w-12 text-center">เลขที่</th>
                      <th className="text-left">รหัส / ชื่อ-นามสกุล</th>
                      <th className="text-center bg-sky-50/70">
                        เก็บก่อนกลาง
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (เต็ม {maxPreMidWork})
                        </span>
                      </th>
                      <th className="text-center bg-sky-50/70">
                        คะแนนสมุด 1
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (เต็ม {maxPreMidNotebook})
                        </span>
                      </th>
                      <th className="text-center bg-indigo-50/80 text-brand-700">
                        สอบกลางภาค
                        <br />
                        <span className="text-[10px] font-normal">
                          (เต็ม {maxMidterm})
                        </span>
                      </th>
                      <th className="text-center bg-emerald-50/60">
                        เก็บหลังกลาง
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (เต็ม {maxPostMidWork})
                        </span>
                      </th>
                      <th className="text-center bg-emerald-50/60">
                        คะแนนสมุด 2
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (เต็ม {maxPostMidNotebook})
                        </span>
                      </th>
                      <th className="text-center bg-emerald-50/60">
                        จิตพิสัย
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (เต็ม {maxAffective})
                        </span>
                      </th>
                      <th className="text-center bg-slate-100">
                        รวมระหว่างภาค
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (เก็บ+กลางภาค)
                        </span>
                      </th>
                      <th className="text-center bg-amber-50/80 text-amber-900">
                        สอบปลายภาค
                        <br />
                        <span className="text-[10px] font-normal">
                          (เต็ม {maxFinal})
                        </span>
                      </th>
                      <th className="text-center bg-brand-50 text-brand-700">
                        คะแนนรวม
                        <br />
                        <span className="text-[10px] font-normal">(100)</span>
                      </th>
                      <th className="text-center bg-brand-50 text-brand-700">
                        เกรด
                        <br />
                        <span className="text-[10px] font-normal">
                          (คำนวณอัตโนมัติ)
                        </span>
                      </th>
                      <th className="text-center">
                        สถานะพิเศษ
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (ร / มส)
                        </span>
                      </th>
                      <th className="text-center">
                        เวลาเรียน
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (เต็ม {sgsTotalHours} ชม.)
                        </span>
                      </th>
                      <th className="text-center">
                        อ่านคิดฯ / คุณลักษณะ
                        <br />
                        <span className="text-[10px] font-normal text-slate-500">
                          (0-3)
                        </span>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {gradebookStudents.map((stu, idx) => {
                      const row = gradebookDraft[stu.id];
                      if (!row) return null;
                      const calc = computeSgsGradeRow(row);
                      const seatNo =
                        profilesByStudentId[stu.id]?.seat_no ?? idx + 1;

                      return (
                        <tr key={stu.id}>
                          <td className="text-center font-semibold text-slate-600 tabular-nums">
                            {seatNo}
                          </td>
                          <td>
                            <div className="font-medium text-ink whitespace-nowrap">
                              {stu.prefix ?? ''}
                              {stu.first_name} {stu.last_name}
                            </div>
                            <div className="font-mono text-[11px] text-slate-500">
                              รหัส {stu.student_code}
                            </div>
                          </td>

                          {/* คะแนนเก็บก่อนกลางภาค */}
                          <td className="text-center bg-sky-50/20">
                            <input
                              type="number"
                              min={0}
                              max={maxPreMidWork}
                              step="0.5"
                              disabled={!canEdit}
                              value={row.pre_mid_work}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'pre_mid_work',
                                  Number(e.target.value) || 0,
                                )
                              }
                              className="input w-16 py-1 px-2 text-center text-xs tabular-nums mx-auto"
                            />
                          </td>

                          {/* คะแนนสมุดก่อนกลางภาค */}
                          <td className="text-center bg-sky-50/20">
                            <input
                              type="number"
                              min={0}
                              max={maxPreMidNotebook}
                              step="0.5"
                              disabled={!canEdit}
                              value={row.pre_mid_notebook}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'pre_mid_notebook',
                                  Number(e.target.value) || 0,
                                )
                              }
                              className="input w-16 py-1 px-2 text-center text-xs tabular-nums mx-auto"
                            />
                          </td>

                          {/* สอบกลางภาค */}
                          <td className="text-center bg-indigo-50/30">
                            <input
                              type="number"
                              min={0}
                              max={maxMidterm}
                              step="0.5"
                              disabled={!canEdit}
                              value={row.midterm_score}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'midterm_score',
                                  Number(e.target.value) || 0,
                                )
                              }
                              className="input w-16 py-1 px-2 text-center text-xs font-semibold text-brand-700 tabular-nums mx-auto"
                            />
                          </td>

                          {/* คะแนนเก็บหลังกลางภาค */}
                          <td className="text-center bg-emerald-50/20">
                            <input
                              type="number"
                              min={0}
                              max={maxPostMidWork}
                              step="0.5"
                              disabled={!canEdit}
                              value={row.post_mid_work}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'post_mid_work',
                                  Number(e.target.value) || 0,
                                )
                              }
                              className="input w-16 py-1 px-2 text-center text-xs tabular-nums mx-auto"
                            />
                          </td>

                          {/* คะแนนสมุดหลังกลางภาค */}
                          <td className="text-center bg-emerald-50/20">
                            <input
                              type="number"
                              min={0}
                              max={maxPostMidNotebook}
                              step="0.5"
                              disabled={!canEdit}
                              value={row.post_mid_notebook}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'post_mid_notebook',
                                  Number(e.target.value) || 0,
                                )
                              }
                              className="input w-16 py-1 px-2 text-center text-xs tabular-nums mx-auto"
                            />
                          </td>

                          {/* จิตพิสัย */}
                          <td className="text-center bg-emerald-50/20">
                            <input
                              type="number"
                              min={0}
                              max={maxAffective}
                              step="0.5"
                              disabled={!canEdit}
                              value={row.affective_score}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'affective_score',
                                  Number(e.target.value) || 0,
                                )
                              }
                              className="input w-14 py-1 px-2 text-center text-xs tabular-nums mx-auto"
                            />
                          </td>

                          {/* รวมระหว่างภาค (คำนวณอัตโนมัติ) */}
                          <td className="text-center bg-slate-50 font-semibold text-slate-700 tabular-nums">
                            <div>{calc.totalDuringTerm}</div>
                            <div className="text-[10px] font-normal text-slate-500">
                              (เก็บ {calc.totalCollected} / สมุด{' '}
                              {calc.totalNotebook})
                            </div>
                          </td>

                          {/* สอบปลายภาค */}
                          <td className="text-center bg-amber-50/30">
                            <input
                              type="number"
                              min={0}
                              max={maxFinal}
                              step="0.5"
                              disabled={!canEdit}
                              value={row.final_score}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'final_score',
                                  Number(e.target.value) || 0,
                                )
                              }
                              className="input w-16 py-1 px-2 text-center text-xs font-semibold text-amber-900 tabular-nums mx-auto"
                            />
                          </td>

                          {/* คะแนนรวม 100 */}
                          <td className="text-center bg-brand-50/40 font-mono text-sm font-bold text-ink tabular-nums">
                            {calc.totalScore}
                          </td>

                          {/* เกรดที่คำนวณได้ */}
                          <td className="text-center bg-brand-50/40">
                            <span
                              className={
                                calc.gradeBadgeTone === 'emerald'
                                  ? 'badge-green text-sm font-bold px-2.5 py-0.5'
                                  : calc.gradeBadgeTone === 'blue'
                                    ? 'badge-brand text-sm font-bold px-2.5 py-0.5'
                                    : calc.gradeBadgeTone === 'amber'
                                      ? 'badge-amber text-sm font-bold px-2.5 py-0.5'
                                      : 'badge-red text-sm font-bold px-2.5 py-0.5'
                              }
                            >
                              {calc.displayGrade}
                            </span>
                          </td>

                          {/* สถานะพิเศษ (ปกติ / ร / มส / ผ / มผ) */}
                          <td className="text-center">
                            <select
                              disabled={!canEdit}
                              value={row.special_status}
                              onChange={(e) =>
                                updateDraftScore(
                                  stu.id,
                                  'special_status',
                                  e.target.value as SgsSpecialStatus,
                                )
                              }
                              className="input w-24 py-1 px-1.5 text-xs mx-auto"
                            >
                              <option value="">ปกติ (คิดเกรด)</option>
                              <option value="ร">ร (รอตัดสิน)</option>
                              <option value="มส">มส (เวลาเรียนไม่พอ)</option>
                              <option value="ผ">ผ (ผ่านกิจกรรม)</option>
                              <option value="มผ">มผ (ไม่ผ่านกิจกรรม)</option>
                            </select>
                          </td>

                          {/* เวลาเรียน */}
                          <td className="text-center">
                            <div className="flex items-center justify-center gap-1">
                              <input
                                type="number"
                                min={0}
                                max={sgsTotalHours}
                                disabled={!canEdit}
                                value={row.attended_hours}
                                onChange={(e) =>
                                  updateDraftScore(
                                    stu.id,
                                    'attended_hours',
                                    Number(e.target.value) || 0,
                                  )
                                }
                                className="input w-14 py-1 px-1.5 text-center text-xs tabular-nums"
                              />
                              <span
                                className={`text-[11px] font-semibold tabular-nums ${
                                  calc.isLowAttendance
                                    ? 'text-rose-600'
                                    : 'text-slate-500'
                                }`}
                              >
                                ({calc.attendancePercent}%)
                              </span>
                            </div>
                          </td>

                          {/* อ่านคิดวิเคราะห์ / คุณลักษณะอันพึงประสงค์ */}
                          <td className="text-center">
                            <div className="flex items-center justify-center gap-1">
                              <select
                                title="การอ่าน คิดวิเคราะห์ และเขียน (0-3)"
                                disabled={!canEdit}
                                value={row.reading_thinking_writing}
                                onChange={(e) =>
                                  updateDraftScore(
                                    stu.id,
                                    'reading_thinking_writing',
                                    Number(e.target.value) as 0 | 1 | 2 | 3,
                                  )
                                }
                                className="input w-12 py-1 px-1 text-center text-xs"
                              >
                                <option value={3}>3</option>
                                <option value={2}>2</option>
                                <option value={1}>1</option>
                                <option value={0}>0</option>
                              </select>
                              <select
                                title="คุณลักษณะอันพึงประสงค์ (0-3)"
                                disabled={!canEdit}
                                value={row.desirable_characteristics}
                                onChange={(e) =>
                                  updateDraftScore(
                                    stu.id,
                                    'desirable_characteristics',
                                    Number(e.target.value) as 0 | 1 | 2 | 3,
                                  )
                                }
                                className="input w-12 py-1 px-1 text-center text-xs"
                              >
                                <option value={3}>3</option>
                                <option value={2}>2</option>
                                <option value={1}>1</option>
                                <option value={0}>0</option>
                              </select>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          TAB 3 (PART 3): ผลการเรียนสะสมครบทุกชั้นปี (ปพ.1 / GPA & GPAX)
         ════════════════════════════════════════════════════════════════════ */}
      {tab === 'transcript' && (
        <div className="grid items-start gap-6 lg:grid-cols-[300px_minmax(0,1fr)]">
          {/* คอลัมน์ซ้าย: เลือกนักเรียน */}
          <div className="surface-card overflow-hidden">
            <div className="border-b border-line bg-slate-50/70 p-4">
              <h3 className="text-sm font-semibold text-ink">
                เลือกนักเรียนเพื่อดูผลการเรียนสะสม
              </h3>
              <p className="mt-0.5 text-xs text-slate-500">
                ดูผลการเรียนย้อนหลังครบทุกชั้นปี (ม.1 – ม.6) พร้อมคำนวณ GPA และ GPAX
              </p>
              <div className="relative mt-3">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="ค้นหารหัส หรือชื่อนักเรียน..."
                  className="input py-1.5 pl-8 text-xs"
                />
              </div>
            </div>

            <div className="max-h-[420px] divide-y divide-line overflow-y-auto lg:max-h-[72vh]">
              {filteredStudents.map((stu) => {
                const isSelected = selectedTranscriptStudent?.id === stu.id;
                const cls = stu.classroom_id
                  ? classroomMap.get(stu.classroom_id)
                  : null;
                const gpaxInfo = gpaxByStudentId.get(stu.id);

                return (
                  <button
                    key={stu.id}
                    type="button"
                    onClick={() => setSelectedTranscriptStudentId(stu.id)}
                    className={`flex w-full items-center justify-between gap-2 px-4 py-3 text-left transition-colors ${
                      isSelected
                        ? 'bg-brand-50 text-brand-700'
                        : 'bg-white hover:bg-slate-50'
                    }`}
                  >
                    <div className="min-w-0">
                      <p className="truncate text-xs font-semibold text-ink">
                        {stu.prefix ?? ''}
                        {stu.first_name} {stu.last_name}
                      </p>
                      <p className="text-[11px] text-slate-500 font-mono">
                        รหัส {stu.student_code} • ห้อง {cls?.name ?? '-'}
                      </p>
                    </div>
                    {gpaxInfo && gpaxInfo.termsCount > 0 ? (
                      <span className="badge-green font-mono text-xs font-bold shrink-0">
                        {gpaxInfo.gpax.toFixed(2)}
                      </span>
                    ) : (
                      <span className="badge-slate text-[10px] shrink-0">
                        รอข้อมูล
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* คอลัมน์ขวา: ใบรายงานผลการเรียนสะสมทุกชั้นปี (Transcript) */}
          <div className="space-y-5">
            {!selectedTranscriptStudent ? (
              <div className="surface-card p-10 text-center text-sm text-slate-500">
                กรุณาเลือกนักเรียนจากรายการทางด้านซ้าย
              </div>
            ) : (
              <>
                {/* ข้อมูลประจำตัวนักเรียน + ปุ่มสร้างผลการเรียนครบทุกชั้นปี */}
                {(() => {
                  const stu = selectedTranscriptStudent;
                  const prof = profilesByStudentId[stu.id];
                  const cls = stu.classroom_id
                    ? classroomMap.get(stu.classroom_id)
                    : null;

                  return (
                    <div className="surface-card p-6 space-y-5">
                      <div className="flex flex-col gap-4 border-b border-line pb-4 sm:flex-row sm:items-start sm:justify-between">
                        <div>
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="badge-brand">
                              ระเบียนแสดงผลการเรียนสะสม (ปพ.1 / SGS Transcript)
                            </span>
                            <span className="badge-slate font-mono">
                              รหัสประจำตัวนักเรียน: {stu.student_code}
                            </span>
                          </div>
                          <h3 className="mt-2 text-lg font-semibold text-ink">
                            {stu.prefix ?? ''}
                            {stu.first_name} {stu.last_name}
                          </h3>
                          <p className="mt-0.5 text-xs text-slate-600">
                            เลขประจำตัวประชาชน:{' '}
                            <span className="font-mono font-medium">
                              {prof?.citizen_id || '-'}
                            </span>{' '}
                            • ห้องปัจจุบัน:{' '}
                            <span className="font-semibold">
                              {cls?.name ?? '-'}
                            </span>{' '}
                            (เลขที่ {prof?.seat_no ?? 1}) • แผนการเรียน:{' '}
                            <span className="font-semibold">
                              {prof?.study_plan || 'ทั่วไป'}
                            </span>
                          </p>
                        </div>

                        <div className="flex flex-wrap items-center gap-2">
                          <button
                            type="button"
                            onClick={() => handleOpenProfileModal(stu)}
                            className="btn-secondary btn-sm"
                          >
                            <UserCheck className="h-3.5 w-3.5" />
                            <span>ดูแฟ้มประวัติส่วนตัว</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => window.print()}
                            className="btn-primary btn-sm"
                          >
                            <Printer className="h-3.5 w-3.5" />
                            <span>พิมพ์ใบรายงานผลการเรียน</span>
                          </button>
                        </div>
                      </div>

                      {/* การ์ดสรุป GPAX สะสม & หน่วยกิต */}
                      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                        <div className="rounded-xl border border-brand-200 bg-brand-50/50 p-4">
                          <p className="text-xs font-medium text-brand-700">
                            เกรดเฉลี่ยสะสมทุกชั้นปี (GPAX)
                          </p>
                          <p className="mt-1 text-2xl font-bold text-brand-700 tabular-nums">
                            {selectedStudentTranscript.overallGpax.toFixed(2)}
                          </p>
                          <p className="mt-0.5 text-[11px] text-slate-500">
                            คำนวณจากทุกชั้นปีที่เรียน
                          </p>
                        </div>

                        <div className="rounded-xl border border-line bg-slate-50/60 p-4">
                          <p className="text-xs font-medium text-slate-600">
                            หน่วยกิตที่ลงทะเบียนเรียนรวม
                          </p>
                          <p className="mt-1 text-2xl font-bold text-ink tabular-nums">
                            {selectedStudentTranscript.totalCreditsAttempted.toFixed(
                              1,
                            )}
                          </p>
                          <p className="mt-0.5 text-[11px] text-slate-500">
                            หน่วยกิตสะสมทั้งหมด
                          </p>
                        </div>

                        <div className="rounded-xl border border-emerald-200 bg-emerald-50/50 p-4">
                          <p className="text-xs font-medium text-emerald-800">
                            หน่วยกิตที่สอบผ่านสะสม
                          </p>
                          <p className="mt-1 text-2xl font-bold text-emerald-700 tabular-nums">
                            {selectedStudentTranscript.totalCreditsEarned.toFixed(
                              1,
                            )}
                          </p>
                          <p className="mt-0.5 text-[11px] text-emerald-700">
                            คิดเป็น{' '}
                            {selectedStudentTranscript.totalCreditsAttempted > 0
                              ? Math.round(
                                  (selectedStudentTranscript.totalCreditsEarned /
                                    selectedStudentTranscript.totalCreditsAttempted) *
                                    100,
                                )
                              : 0}
                            % ของที่ลงทะเบียน
                          </p>
                        </div>

                        <div className="rounded-xl border border-line bg-slate-50/60 p-4">
                          <p className="text-xs font-medium text-slate-600">
                            จำนวนภาคเรียนที่มีผลการเรียน
                          </p>
                          <p className="mt-1 text-2xl font-bold text-ink tabular-nums">
                            {selectedStudentTranscript.terms.length} ภาคเรียน
                          </p>
                          <p className="mt-0.5 text-[11px] text-slate-500">
                            รองรับครบ ม.1 – ม.6 (12 ภาคเรียน)
                          </p>
                        </div>
                      </div>

                      {/* สรุปเกรดเฉลี่ยสะสมแยกตาม 8 กลุ่มสาระการเรียนรู้ (ตามแบบ ปพ.1) */}
                      <div>
                        <h4 className="mb-2.5 text-xs font-semibold text-slate-700">
                          ผลการเรียนเฉลี่ยสะสมแยกตาม 8 กลุ่มสาระการเรียนรู้ (ตามโครงสร้างใบ ปพ.1)
                        </h4>
                        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
                          {selectedStudentTranscript.byLearningArea.map(
                            (area) => (
                              <div
                                key={area.learningArea}
                                className="rounded-xl border border-line bg-white p-3 flex items-center justify-between"
                              >
                                <div className="min-w-0 pr-2">
                                  <p className="truncate text-xs font-medium text-ink">
                                    {area.learningArea}
                                  </p>
                                  <p className="text-[11px] text-slate-500">
                                    ผ่าน {area.creditsEarned}/
                                    {area.creditsAttempted} นก.
                                  </p>
                                </div>
                                <span className="badge-brand font-mono text-xs font-bold shrink-0">
                                  {area.gpa.toFixed(2)}
                                </span>
                              </div>
                            ),
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })()}

                {/* แถบกรองระดับชั้นปี (ทั้งหมด / ม.1 / ม.2 / ม.3 / ม.4 / ม.5 / ม.6) */}
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => setTranscriptFilterLevel('all')}
                      className={`rounded-xl px-3 py-1.5 text-xs font-semibold transition-colors ${
                        transcriptFilterLevel === 'all'
                          ? 'bg-brand-600 text-white'
                          : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
                      }`}
                    >
                      ทุกชั้นปี ({selectedStudentTranscript.terms.length} เทอม)
                    </button>
                    {SGS_GRADE_LEVELS.map((lvl) => {
                      const hasLevel = selectedStudentTranscript.terms.some(
                        (t) => t.gradeLevel === lvl,
                      );
                      return (
                        <button
                          key={lvl}
                          type="button"
                          onClick={() => setTranscriptFilterLevel(lvl)}
                          className={`rounded-xl px-3 py-1.5 text-xs font-semibold transition-colors ${
                            transcriptFilterLevel === lvl
                              ? 'bg-brand-600 text-white'
                              : hasLevel
                                ? 'border border-brand-200 bg-brand-50/40 text-brand-700 hover:bg-brand-50'
                                : 'border border-line bg-white text-slate-400 hover:bg-slate-50'
                          }`}
                        >
                          {lvl} {hasLevel ? '✓' : ''}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* รายการตารางผลการเรียนแต่ละชั้นปีและภาคเรียน */}
                {selectedStudentTranscript.terms.length === 0 ? (
                  <div className="surface-card p-10 text-center space-y-3">
                    <FileText className="mx-auto h-10 w-10 text-slate-300" />
                    <p className="text-sm font-medium text-ink">
                      ยังไม่มีประวัติผลการเรียนของนักเรียนคนนี้ในระบบ
                    </p>
                    <p className="text-xs text-slate-500 max-w-md mx-auto">
                      ไปที่แท็บ &ldquo;2. บันทึกคะแนนและตัดเกรด SGS&rdquo; เพื่อกรอกคะแนนรายวิชา
                    </p>
                    </div>
                ) : (
                  <div className="space-y-5">
                    {selectedStudentTranscript.terms
                      .filter(
                        (t) =>
                          transcriptFilterLevel === 'all' ||
                          t.gradeLevel === transcriptFilterLevel,
                      )
                      .map((term) => (
                        <div
                          key={`${term.gradeLevel}-${term.termNo}`}
                          className="surface-card overflow-hidden"
                        >
                          <div className="flex flex-col gap-2 border-b border-line bg-slate-50/80 px-5 py-3.5 sm:flex-row sm:items-center sm:justify-between">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className="badge-brand text-xs font-bold">
                                ชั้นมัธยมศึกษาปีที่{' '}
                                {term.gradeLevel.replace('ม.', '')} (
                                {term.gradeLevel})
                              </span>
                              <span className="text-sm font-semibold text-ink">
                                ภาคเรียนที่ {term.termNo} / ปีการศึกษา{' '}
                                {term.yearBe}
                              </span>
                            </div>

                            <div className="flex flex-wrap items-center gap-2 text-xs">
                              <span className="badge-slate">
                                หน่วยกิตเทอมนี้: {term.termCreditsEarned} /{' '}
                                {term.termCreditsAttempted}
                              </span>
                              <span className="badge-brand font-mono">
                                GPA ประจำภาค: {term.termGpa.toFixed(2)}
                              </span>
                              <span className="badge-green font-mono">
                                GPAX สะสม: {term.cumulativeGpaxAfterTerm.toFixed(2)}
                              </span>
                              <button
                                type="button"
                                onClick={() => {
                                  handleSelectGradeOrTermForSgs(
                                    term.gradeLevel,
                                    term.termNo,
                                  );
                                  setSgsYearBe(term.yearBe);
                                  setTab('sgs_gradebook');
                                }}
                                className="btn-secondary btn-sm py-1 text-[11px]"
                              >
                                <Edit3 className="h-3 w-3" />
                                <span>แก้คะแนนเทอมนี้ใน SGS</span>
                              </button>
                            </div>
                          </div>

                          <div className="overflow-x-auto">
                            <table className="table text-xs">
                              <thead>
                                <tr>
                                  <th>รหัสวิชา</th>
                                  <th>ชื่อรายวิชา</th>
                                  <th>กลุ่มสาระฯ / ประเภท</th>
                                  <th className="text-center">หน่วยกิต</th>
                                  <th className="text-center">
                                    คะแนนเก็บ
                                    <br />
                                    <span className="text-[10px] font-normal text-slate-400">
                                      (ก่อน+หลัง+จิตพิสัย)
                                    </span>
                                  </th>
                                  <th className="text-center">
                                    คะแนนสมุด
                                    <br />
                                    <span className="text-[10px] font-normal text-slate-400">
                                      (สมุด 1+2)
                                    </span>
                                  </th>
                                  <th className="text-center">กลางภาค</th>
                                  <th className="text-center">ปลายภาค</th>
                                  <th className="text-center">รวม (100)</th>
                                  <th className="text-center">เกรด</th>
                                  <th className="text-center">เวลาเรียน</th>
                                  <th className="text-center">
                                    อ่านคิดฯ / คุณลักษณะ
                                  </th>
                                </tr>
                              </thead>
                              <tbody>
                                {term.rows.map(({ record, computed }) => (
                                  <tr key={record.subject_code}>
                                    <td className="font-mono font-semibold text-brand-700">
                                      {record.subject_code}
                                    </td>
                                    <td className="font-medium text-ink">
                                      {record.subject_name}
                                    </td>
                                    <td className="text-slate-500">
                                      {record.learning_area} ({record.subject_type})
                                    </td>
                                    <td className="text-center tabular-nums">
                                      {record.subject_type === 'กิจกรรม'
                                        ? '-'
                                        : record.credits.toFixed(1)}
                                    </td>
                                    <td className="text-center tabular-nums">
                                      {record.pre_mid_work +
                                        record.post_mid_work +
                                        record.affective_score}
                                    </td>
                                    <td className="text-center tabular-nums">
                                      {computed.totalNotebook}
                                    </td>
                                    <td className="text-center tabular-nums">
                                      {record.midterm_score}
                                    </td>
                                    <td className="text-center tabular-nums">
                                      {record.final_score}
                                    </td>
                                    <td className="text-center font-mono font-semibold text-ink tabular-nums">
                                      {computed.totalScore}
                                    </td>
                                    <td className="text-center">
                                      <span
                                        className={
                                          computed.gradeBadgeTone === 'emerald'
                                            ? 'badge-green font-bold'
                                            : computed.gradeBadgeTone === 'blue'
                                              ? 'badge-brand font-bold'
                                              : computed.gradeBadgeTone ===
                                                  'amber'
                                                ? 'badge-amber font-bold'
                                                : 'badge-red font-bold'
                                        }
                                      >
                                        {computed.displayGrade}
                                      </span>
                                    </td>
                                    <td className="text-center tabular-nums text-slate-600">
                                      {record.attended_hours}/{record.total_hours}{' '}
                                      ชม. ({computed.attendancePercent}%)
                                    </td>
                                    <td className="text-center tabular-nums text-slate-600">
                                      {record.reading_thinking_writing} /{' '}
                                      {record.desirable_characteristics}
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        </div>
                      ))}
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          TAB 4: จัดการห้องเรียนและครูที่ปรึกษา
         ════════════════════════════════════════════════════════════════════ */}
      {tab === 'classrooms' && (
        <div className="space-y-6">
          {canEdit && (
            <form
              onSubmit={handleAddClassroom}
              className="surface-card space-y-4 p-5"
            >
              <h3 className="text-sm font-semibold text-ink">
                เพิ่มห้องเรียนและกำหนดครูที่ปรึกษา
              </h3>
              <div className="grid gap-3 sm:grid-cols-4">
                <label className="field">
                  <span>ระดับชั้น *</span>
                  <select
                    value={gradeLevel}
                    onChange={(e) => setGradeLevel(e.target.value)}
                    className="input"
                  >
                    {SGS_GRADE_LEVELS.map((lvl) => (
                      <option key={lvl} value={lvl}>
                        {lvl}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span>ห้องที่ *</span>
                  <input
                    type="text"
                    required
                    value={roomNo}
                    onChange={(e) => setRoomNo(e.target.value)}
                    placeholder="เช่น 1 หรือ 2"
                    className="input"
                  />
                </label>
                <label className="field sm:col-span-2">
                  <span>ครูที่ปรึกษาประจำห้อง</span>
                  <select
                    value={advisorId}
                    onChange={(e) => setAdvisorId(e.target.value)}
                    className="input"
                  >
                    <option value="">-- เลือกครูที่ปรึกษา --</option>
                    {teachers.map((t) => (
                      <option key={t.id_user} value={t.id_user}>
                        {t.fullName}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              <div className="flex justify-end">
                <button type="submit" disabled={busy} className="btn-primary">
                  <Plus className="h-4 w-4" strokeWidth={1.75} />
                  <span>สร้างห้องเรียน</span>
                </button>
              </div>
            </form>
          )}

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {classrooms.length === 0 ? (
              <div className="surface-card col-span-full p-8 text-center text-sm text-slate-500">
                ยังไม่มีห้องเรียนในระบบ
              </div>
            ) : (
              classrooms.map((c) => {
                const count = students.filter(
                  (s) => s.classroom_id === c.id,
                ).length;
                return (
                  <div
                    key={c.id}
                    className="surface-card flex flex-col justify-between p-5"
                  >
                    <div>
                      <div className="flex items-start justify-between">
                        <div>
                          <p className="text-xs text-slate-500">ห้องเรียน</p>
                          <h4 className="mt-0.5 text-lg font-semibold text-ink">
                            {c.name}
                          </h4>
                        </div>
                        {canEdit && (
                          <button
                            type="button"
                            onClick={() => removeClassroom(c.id)}
                            aria-label={`ลบห้องเรียน ${c.name}`}
                            className="rounded-lg p-1.5 text-slate-400 hover:bg-red-50 hover:text-red-600"
                          >
                            <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                          </button>
                        )}
                      </div>
                      <p className="mt-2 text-xs text-slate-600">
                        ครูที่ปรึกษา:{' '}
                        <span className="font-medium text-ink">
                          {c.advisor_teacher_id
                            ? teacherMap.get(c.advisor_teacher_id) ?? '-'
                            : 'ยังไม่ระบุ'}
                        </span>
                      </p>
                    </div>
                    <div className="mt-4 flex items-center justify-between border-t border-line pt-3 text-xs">
                      <span className="text-slate-500">
                        นักเรียนในห้อง{' '}
                        <strong className="text-ink tabular-nums">
                          {count}
                        </strong>{' '}
                        คน
                      </span>
                      <button
                        type="button"
                        onClick={() => {
                          setSgsClassroomId(String(c.id));
                          handleSelectGradeOrTermForSgs(
                            inferGradeLevelFromClassroomName(c.name),
                            sgsTermNo,
                          );
                          setTab('sgs_gradebook');
                        }}
                        className="font-semibold text-brand-600 hover:underline"
                      >
                        กรอกคะแนน SGS ห้องนี้ →
                      </button>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          MODAL: แฟ้มข้อมูลส่วนตัวนักเรียนฉบับสมบูรณ์ (Student Personal Profile)
         ════════════════════════════════════════════════════════════════════ */}
      {editingStudent && editingProfile && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm"
          onClick={() => {
            setEditingStudent(null);
            setEditingProfile(null);
          }}
        >
          <div
            className="max-h-[90vh] w-full max-w-4xl overflow-y-auto rounded-2xl bg-white shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="sticky top-0 z-10 flex items-center justify-between border-b border-line bg-white px-6 py-4">
              <div>
                <span className="badge-brand">
                  แฟ้มประวัตินักเรียนรายบุคคล (Student Profile &amp; SGS Info)
                </span>
                <h3 className="mt-1 text-base font-semibold text-ink">
                  {editingStudent.prefix ?? ''}
                  {editingStudent.first_name} {editingStudent.last_name} (รหัส{' '}
                  {editingStudent.student_code})
                </h3>
              </div>
              <button
                type="button"
                onClick={() => {
                  setEditingStudent(null);
                  setEditingProfile(null);
                }}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-ink"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleSaveProfileModal} className="p-6 space-y-6">
              {/* หมวด 1: ข้อมูลระบุตัวตนและข้อมูลพื้นฐาน */}
              <div className="subcard space-y-3">
                <h4 className="text-xs font-semibold uppercase tracking-wider text-brand-700">
                  1. ข้อมูลส่วนตัวและข้อมูลระบุตัวตน (ตามทะเบียนราษฎร / SGS)
                </h4>
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                  <label className="field">
                    <span>รหัสนักเรียน (5 หลัก)</span>
                    <input
                      className="input font-mono"
                      disabled={!canEdit}
                      value={editingStudent.student_code}
                      onChange={(e) =>
                        setEditingStudent((p) =>
                          p ? { ...p, student_code: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>เลขประจำตัวประชาชน (13 หลัก)</span>
                    <input
                      className="input font-mono"
                      disabled={!canEdit}
                      value={editingProfile.citizen_id}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, citizen_id: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>คำนำหน้า</span>
                    <select
                      className="input"
                      disabled={!canEdit}
                      value={editingStudent.prefix ?? 'นาย'}
                      onChange={(e) =>
                        setEditingStudent((p) =>
                          p ? { ...p, prefix: e.target.value } : p,
                        )
                      }
                    >
                      <option value="เด็กชาย">เด็กชาย</option>
                      <option value="เด็กหญิง">เด็กหญิง</option>
                      <option value="นาย">นาย</option>
                      <option value="นางสาว">นางสาว</option>
                    </select>
                  </label>

                  <label className="field">
                    <span>เพศ</span>
                    <select
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.gender}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p
                            ? {
                                ...p,
                                gender: e.target.value as 'ชาย' | 'หญิง',
                              }
                            : p,
                        )
                      }
                    >
                      <option value="ชาย">ชาย</option>
                      <option value="หญิง">หญิง</option>
                    </select>
                  </label>

                  <label className="field">
                    <span>ชื่อ (ภาษาไทย)</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingStudent.first_name}
                      onChange={(e) =>
                        setEditingStudent((p) =>
                          p ? { ...p, first_name: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>นามสกุล (ภาษาไทย)</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingStudent.last_name}
                      onChange={(e) =>
                        setEditingStudent((p) =>
                          p ? { ...p, last_name: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>ชื่อ (ภาษาอังกฤษ)</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      placeholder="First Name"
                      value={editingProfile.first_name_en}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, first_name_en: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>นามสกุล (ภาษาอังกฤษ)</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      placeholder="Last Name"
                      value={editingProfile.last_name_en}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, last_name_en: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>วัน-เดือน-ปีเกิด</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      placeholder="เช่น 2554-05-12"
                      value={editingProfile.birth_date}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, birth_date: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>หมู่เลือด</span>
                    <select
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.blood_group}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p
                            ? {
                                ...p,
                                blood_group: e.target.value as
                                  | 'A'
                                  | 'B'
                                  | 'O'
                                  | 'AB'
                                  | '-',
                              }
                            : p,
                        )
                      }
                    >
                      <option value="O">O</option>
                      <option value="A">A</option>
                      <option value="B">B</option>
                      <option value="AB">AB</option>
                      <option value="-">ไม่ระบุ</option>
                    </select>
                  </label>

                  <label className="field">
                    <span>ศาสนา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.religion}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, religion: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>เชื้อชาติ / สัญชาติ</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.nationality}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p
                            ? {
                                ...p,
                                nationality: e.target.value,
                                ethnicity: e.target.value,
                              }
                            : p,
                        )
                      }
                    />
                  </label>
                </div>
              </div>

              {/* หมวด 2: ข้อมูลการศึกษา */}
              <div className="subcard space-y-3">
                <h4 className="text-xs font-semibold uppercase tracking-wider text-brand-700">
                  2. ข้อมูลการศึกษาและแผนการเรียน
                </h4>
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                  <label className="field">
                    <span>ชั้น/ห้องเรียนปัจจุบัน</span>
                    <select
                      className="input"
                      disabled={!canEdit}
                      value={editingStudent.classroom_id ?? ''}
                      onChange={(e) =>
                        setEditingStudent((p) =>
                          p
                            ? {
                                ...p,
                                classroom_id: e.target.value
                                  ? Number(e.target.value)
                                  : null,
                              }
                            : p,
                        )
                      }
                    >
                      <option value="">-- ไม่ระบุ --</option>
                      {classrooms.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label className="field">
                    <span>เลขที่ในห้องเรียน (ลำดับ SGS)</span>
                    <input
                      type="number"
                      min={1}
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.seat_no}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p
                            ? {
                                ...p,
                                seat_no: Number(e.target.value) || 1,
                              }
                            : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>แผนการเรียน</span>
                    <select
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.study_plan}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, study_plan: e.target.value } : p,
                        )
                      }
                    >
                      {STUDY_PLAN_OPTIONS.map((opt) => (
                        <option key={opt} value={opt}>
                          {opt}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label className="field">
                    <span>ปีการศึกษาที่เข้าเรียน (พ.ศ.)</span>
                    <input
                      type="number"
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.admission_year_be ?? ''}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p
                            ? {
                                ...p,
                                admission_year_be:
                                  Number(e.target.value) || 2568,
                              }
                            : p,
                        )
                      }
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>โรงเรียนเดิมก่อนเข้าศึกษา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.previous_school}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, previous_school: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>ข้อมูลสุขภาพ / โรคประจำตัว / การแพ้ยา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.health_note}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, health_note: e.target.value } : p,
                        )
                      }
                    />
                  </label>
                </div>
              </div>

              {/* หมวด 3: ที่อยู่และข้อมูลบิดา-มารดา-ผู้ปกครอง */}
              <div className="subcard space-y-3">
                <h4 className="text-xs font-semibold uppercase tracking-wider text-brand-700">
                  3. ข้อมูลที่อยู่ บิดา มารดา และผู้ปกครอง
                </h4>
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  <label className="field sm:col-span-2">
                    <span>ที่อยู่ปัจจุบันที่ติดต่อได้</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.address_current}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p
                            ? {
                                ...p,
                                address_current: e.target.value,
                                address_registered: e.target.value,
                              }
                            : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>เบอร์โทรศัพท์นักเรียน</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.student_phone}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, student_phone: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>ชื่อ-นามสกุลบิดา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.father_name}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, father_name: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>อาชีพบิดา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.father_occupation}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, father_occupation: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>เบอร์โทรศัพท์บิดา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.father_phone}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, father_phone: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>ชื่อ-นามสกุลมารดา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.mother_name}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, mother_name: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>อาชีพมารดา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.mother_occupation}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, mother_occupation: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>เบอร์โทรศัพท์มารดา</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.mother_phone}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, mother_phone: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>ชื่อผู้ปกครองหลัก</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingStudent.guardian_name ?? ''}
                      onChange={(e) =>
                        setEditingStudent((p) =>
                          p ? { ...p, guardian_name: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>ความสัมพันธ์ผู้ปกครอง</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingProfile.guardian_relation}
                      onChange={(e) =>
                        setEditingProfile((p) =>
                          p ? { ...p, guardian_relation: e.target.value } : p,
                        )
                      }
                    />
                  </label>

                  <label className="field">
                    <span>เบอร์โทรศัพท์ผู้ปกครองฉุกเฉิน</span>
                    <input
                      className="input"
                      disabled={!canEdit}
                      value={editingStudent.guardian_phone ?? ''}
                      onChange={(e) =>
                        setEditingStudent((p) =>
                          p ? { ...p, guardian_phone: e.target.value } : p,
                        )
                      }
                    />
                  </label>
                </div>
              </div>

              <div className="flex items-center justify-between border-t border-line pt-4">
                <button
                  type="button"
                  onClick={() => {
                    const id = editingStudent.id;
                    setEditingStudent(null);
                    setEditingProfile(null);
                    setSelectedTranscriptStudentId(id);
                    setTab('transcript');
                  }}
                  className="btn-secondary"
                >
                  <Award className="h-4 w-4 text-brand-600" />
                  <span>เปิดดูผลการเรียนสะสมทุกชั้นปีของนักเรียนคนนี้</span>
                </button>

                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setEditingStudent(null);
                      setEditingProfile(null);
                    }}
                    className="btn-secondary"
                  >
                    ปิดหน้าต่าง
                  </button>
                  {canEdit && (
                    <button
                      type="submit"
                      disabled={busy}
                      className="btn-primary"
                    >
                      <Save className="h-4 w-4" />
                      <span>บันทึกแฟ้มประวัตินักเรียน</span>
                    </button>
                  )}
                </div>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
