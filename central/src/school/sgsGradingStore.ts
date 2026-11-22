import { supabase } from '../supabase';
import type { Student } from './types';

export const SGS_GRADE_LEVELS = [
  'ม.1',
  'ม.2',
  'ม.3',
  'ม.4',
  'ม.5',
  'ม.6',
] as const;

export type SgsGradeLevel = (typeof SGS_GRADE_LEVELS)[number];

export const SGS_LEARNING_AREAS = [
  'ภาษาไทย',
  'คณิตศาสตร์',
  'วิทยาศาสตร์และเทคโนโลยี',
  'สังคมศึกษา ศาสนา และวัฒนธรรม',
  'สุขศึกษาและพลศึกษา',
  'ศิลปะ',
  'การงานอาชีพ',
  'ภาษาต่างประเทศ',
  'กิจกรรมพัฒนาผู้เรียน',
] as const;

export type SgsLearningArea = (typeof SGS_LEARNING_AREAS)[number];

export type SgsSubjectType = 'พื้นฐาน' | 'เพิ่มเติม' | 'กิจกรรม';
export type SgsSpecialStatus = '' | 'ร' | 'มส' | 'ผ' | 'มผ';

export const STUDY_PLAN_OPTIONS = [
  'ทั่วไป (มัธยมศึกษาตอนต้น)',
  'วิทยาศาสตร์ - คณิตศาสตร์',
  'ศิลป์ - คำนวณ',
  'ศิลป์ - ภาษาต่างประเทศ',
  'ทวิศึกษา / อาชีพ',
] as const;

export interface StudentPersonalProfile {
  student_id: number;
  id_school: number;
  seat_no: number;
  citizen_id: string;
  first_name_en: string;
  last_name_en: string;
  birth_date: string;
  gender: 'ชาย' | 'หญิง' | '';
  blood_group: 'A' | 'B' | 'O' | 'AB' | '-';
  religion: string;
  nationality: string;
  ethnicity: string;
  study_plan: string;
  admission_year_be: number | null;
  previous_school: string;
  address_registered: string;
  address_current: string;
  student_phone: string;
  father_name: string;
  father_occupation: string;
  father_phone: string;
  mother_name: string;
  mother_occupation: string;
  mother_phone: string;
  guardian_relation: string;
  guardian_occupation: string;
  health_note: string;
}

export interface SgsScoreRecord {
  id?: number;
  id_school: number;
  student_id: number;
  grade_level: SgsGradeLevel;
  term_no: 1 | 2;
  year_be: number;
  subject_code: string;
  subject_name: string;
  learning_area: SgsLearningArea;
  subject_type: SgsSubjectType;
  credits: number;
  // คะแนนเต็มของแต่ละช่อง (รวม 100 คะแนน)
  max_pre_mid_work: number;
  max_pre_mid_notebook: number;
  max_midterm: number;
  max_post_mid_work: number;
  max_post_mid_notebook: number;
  max_affective: number;
  max_final: number;
  // คะแนนที่นักเรียนทำได้
  pre_mid_work: number;
  pre_mid_notebook: number;
  midterm_score: number;
  post_mid_work: number;
  post_mid_notebook: number;
  affective_score: number;
  final_score: number;
  // เวลาเรียนและการประเมินตาม ปพ.5 / SGS
  attended_hours: number;
  total_hours: number;
  reading_thinking_writing: 0 | 1 | 2 | 3;
  desirable_characteristics: 0 | 1 | 2 | 3;
  special_status: SgsSpecialStatus;
  teacher_name?: string;
}

export interface ComputedSgsScore {
  totalPreMid: number;
  totalPostMid: number;
  totalNotebook: number;
  totalCollected: number;
  totalDuringTerm: number;
  totalScore: number;
  maxTotalScore: number;
  attendancePercent: number;
  isLowAttendance: boolean;
  numericGrade: number | null;
  displayGrade: string;
  gradePoints: number;
  isEarnedCredit: boolean;
  gradeBadgeTone: 'emerald' | 'blue' | 'amber' | 'rose' | 'slate';
}

export interface StandardCurriculumSubject {
  code: string;
  name: string;
  learning_area: SgsLearningArea;
  subject_type: SgsSubjectType;
  credits: number;
  total_hours: number;
}

/**
 * โครงสร้างรายวิชามาตรฐานครบทั้ง 6 ชั้นปี (ม.1 - ม.6) สำหรับสร้างตารางคะแนน SGS
 */
export function getStandardSubjectsForGradeTerm(
  gradeLevel: SgsGradeLevel,
  termNo: 1 | 2,
): StandardCurriculumSubject[] {
  const levelNum = Number(gradeLevel.replace('ม.', '')) || 1;
  const isSenior = levelNum >= 4;
  const codeSuffix = `${levelNum}${termNo}101`;
  const addSuffix = `${levelNum}${termNo}201`;

  return [
    {
      code: `ท${codeSuffix}`,
      name: `ภาษาไทยพื้นฐาน ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'ภาษาไทย',
      subject_type: 'พื้นฐาน',
      credits: 1.5,
      total_hours: 60,
    },
    {
      code: `ค${codeSuffix}`,
      name: `คณิตศาสตร์พื้นฐาน ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'คณิตศาสตร์',
      subject_type: 'พื้นฐาน',
      credits: 1.5,
      total_hours: 60,
    },
    {
      code: `ว${codeSuffix}`,
      name: isSenior
        ? `วิทยาศาสตร์กายภาพ ${levelNum - 3}.${termNo}`
        : `วิทยาศาสตร์และเทคโนโลยี ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'วิทยาศาสตร์และเทคโนโลยี',
      subject_type: 'พื้นฐาน',
      credits: 1.5,
      total_hours: 60,
    },
    {
      code: `ว${addSuffix}`,
      name: isSenior
        ? `ฟิสิกส์และนวัตกรรม ${levelNum - 3}.${termNo}`
        : `วิทยาการคำนวณและคอมพิวเตอร์ ${levelNum}.${termNo}`,
      learning_area: 'วิทยาศาสตร์และเทคโนโลยี',
      subject_type: 'เพิ่มเติม',
      credits: 1.0,
      total_hours: 40,
    },
    {
      code: `ส${codeSuffix}`,
      name: `สังคมศึกษา ศาสนา และวัฒนธรรม ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'สังคมศึกษา ศาสนา และวัฒนธรรม',
      subject_type: 'พื้นฐาน',
      credits: 1.5,
      total_hours: 60,
    },
    {
      code: `พ${codeSuffix}`,
      name: `สุขศึกษาและพลศึกษา ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'สุขศึกษาและพลศึกษา',
      subject_type: 'พื้นฐาน',
      credits: 0.5,
      total_hours: 20,
    },
    {
      code: `ศ${codeSuffix}`,
      name: `ศิลปะ ดนตรี และนาฏศิลป์ ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'ศิลปะ',
      subject_type: 'พื้นฐาน',
      credits: 0.5,
      total_hours: 20,
    },
    {
      code: `ง${codeSuffix}`,
      name: `การงานอาชีพและพื้นฐานธุรกิจ ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'การงานอาชีพ',
      subject_type: 'พื้นฐาน',
      credits: 0.5,
      total_hours: 20,
    },
    {
      code: `อ${codeSuffix}`,
      name: `ภาษาอังกฤษพื้นฐาน ${levelNum * 2 - (2 - termNo)}`,
      learning_area: 'ภาษาต่างประเทศ',
      subject_type: 'พื้นฐาน',
      credits: 1.5,
      total_hours: 60,
    },
    {
      code: `อ${addSuffix}`,
      name: `ภาษาอังกฤษเพื่อการสื่อสาร ${levelNum}.${termNo}`,
      learning_area: 'ภาษาต่างประเทศ',
      subject_type: 'เพิ่มเติม',
      credits: 1.0,
      total_hours: 40,
    },
    {
      code: `ก${codeSuffix}`,
      name: `กิจกรรมพัฒนาผู้เรียน (แนะแนว / ชุมนุม / ลูกเสือ-รด.)`,
      learning_area: 'กิจกรรมพัฒนาผู้เรียน',
      subject_type: 'กิจกรรม',
      credits: 0,
      total_hours: 60,
    },
  ];
}

/**
 * คำนวณคะแนนรวม คะแนนสมุด คะแนนเก็บ เวลาเรียน และตัดเกรด 8 ระดับตามเกณฑ์ สพฐ. (SGS)
 */
export function computeSgsGradeRow(row: SgsScoreRecord): ComputedSgsScore {
  const preWork = Math.max(0, Number(row.pre_mid_work) || 0);
  const preNb = Math.max(0, Number(row.pre_mid_notebook) || 0);
  const mid = Math.max(0, Number(row.midterm_score) || 0);
  const postWork = Math.max(0, Number(row.post_mid_work) || 0);
  const postNb = Math.max(0, Number(row.post_mid_notebook) || 0);
  const aff = Math.max(0, Number(row.affective_score) || 0);
  const fin = Math.max(0, Number(row.final_score) || 0);

  const totalPreMid = Number((preWork + preNb).toFixed(2));
  const totalPostMid = Number((postWork + postNb + aff).toFixed(2));
  const totalNotebook = Number((preNb + postNb).toFixed(2));
  const totalCollected = Number((totalPreMid + totalPostMid).toFixed(2));
  const totalDuringTerm = Number((totalCollected + mid).toFixed(2));
  const totalScore = Math.min(100, Number((totalDuringTerm + fin).toFixed(2)));

  const maxTotalScore = Number(
    (
      (Number(row.max_pre_mid_work) || 0) +
      (Number(row.max_pre_mid_notebook) || 0) +
      (Number(row.max_midterm) || 0) +
      (Number(row.max_post_mid_work) || 0) +
      (Number(row.max_post_mid_notebook) || 0) +
      (Number(row.max_affective) || 0) +
      (Number(row.max_final) || 0)
    ).toFixed(0),
  );

  const totalHours = Math.max(1, Number(row.total_hours) || 40);
  const attendedHours = Math.min(
    totalHours,
    Math.max(0, Number(row.attended_hours) || 0),
  );
  const attendancePercent = Number(
    ((attendedHours / totalHours) * 100).toFixed(1),
  );
  const isLowAttendance = attendancePercent < 80;

  // กรณีวิชากิจกรรมพัฒนาผู้เรียน (ตัดสินเป็น ผ / มผ)
  if (row.subject_type === 'กิจกรรม') {
    const passed =
      row.special_status === 'มผ'
        ? false
        : row.special_status === 'ผ'
          ? true
          : !isLowAttendance && totalScore >= 50;
    return {
      totalPreMid,
      totalPostMid,
      totalNotebook,
      totalCollected,
      totalDuringTerm,
      totalScore,
      maxTotalScore,
      attendancePercent,
      isLowAttendance,
      numericGrade: null,
      displayGrade: passed ? 'ผ' : 'มผ',
      gradePoints: 0,
      isEarnedCredit: passed,
      gradeBadgeTone: passed ? 'emerald' : 'rose',
    };
  }

  // กรณีติดสถานะพิเศษ ร หรือ มส
  if (row.special_status === 'ร' || row.special_status === 'มส') {
    return {
      totalPreMid,
      totalPostMid,
      totalNotebook,
      totalCollected,
      totalDuringTerm,
      totalScore,
      maxTotalScore,
      attendancePercent,
      isLowAttendance,
      numericGrade: null,
      displayGrade: row.special_status,
      gradePoints: 0,
      isEarnedCredit: false,
      gradeBadgeTone: 'amber',
    };
  }

  // เกณฑ์ตัดเกรด 8 ระดับมาตรฐาน สพฐ. (SGS)
  let numericGrade = 0;
  if (totalScore >= 80) numericGrade = 4;
  else if (totalScore >= 75) numericGrade = 3.5;
  else if (totalScore >= 70) numericGrade = 3;
  else if (totalScore >= 65) numericGrade = 2.5;
  else if (totalScore >= 60) numericGrade = 2;
  else if (totalScore >= 55) numericGrade = 1.5;
  else if (totalScore >= 50) numericGrade = 1;
  else numericGrade = 0;

  const displayGrade = Number.isInteger(numericGrade)
    ? String(numericGrade)
    : numericGrade.toFixed(1);

  const credits = Number(row.credits) || 0;
  const gradePoints = Number((credits * numericGrade).toFixed(2));
  const isEarnedCredit = numericGrade > 0;

  const gradeBadgeTone: ComputedSgsScore['gradeBadgeTone'] =
    numericGrade >= 3.5
      ? 'emerald'
      : numericGrade >= 2.5
        ? 'blue'
        : numericGrade >= 1
          ? 'amber'
          : 'rose';

  return {
    totalPreMid,
    totalPostMid,
    totalNotebook,
    totalCollected,
    totalDuringTerm,
    totalScore,
    maxTotalScore,
    attendancePercent,
    isLowAttendance,
    numericGrade,
    displayGrade,
    gradePoints,
    isEarnedCredit,
    gradeBadgeTone,
  };
}

export interface TermTranscriptSummary {
  gradeLevel: SgsGradeLevel;
  termNo: 1 | 2;
  yearBe: number;
  rows: { record: SgsScoreRecord; computed: ComputedSgsScore }[];
  termCreditsAttempted: number;
  termCreditsEarned: number;
  termGradePoints: number;
  termGpa: number;
  cumulativeCreditsAfterTerm: number;
  cumulativeGpaxAfterTerm: number;
  hasPendingSpecialStatus: boolean;
}

export interface LearningAreaGpaItem {
  learningArea: SgsLearningArea;
  creditsAttempted: number;
  creditsEarned: number;
  gpa: number;
}

export interface StudentMultiYearTranscript {
  terms: TermTranscriptSummary[];
  totalCreditsAttempted: number;
  totalCreditsEarned: number;
  overallGpax: number;
  byLearningArea: LearningAreaGpaItem[];
}

/**
 * คำนวณผลการเรียนสะสมครบทุกชั้นปี (GPA รายเทอม, GPAX สะสม และ GPA แยกตาม 8 กลุ่มสาระการเรียนรู้)
 */
export function computeStudentMultiYearTranscript(
  records: SgsScoreRecord[],
): StudentMultiYearTranscript {
  const levelOrder: Record<string, number> = {
    'ม.1': 1,
    'ม.2': 2,
    'ม.3': 3,
    'ม.4': 4,
    'ม.5': 5,
    'ม.6': 6,
  };

  // จัดกลุ่มตาม (grade_level, term_no)
  const grouped = new Map<string, SgsScoreRecord[]>();
  for (const r of records) {
    const key = `${r.grade_level}::${r.term_no}`;
    const list = grouped.get(key) ?? [];
    list.push(r);
    grouped.set(key, list);
  }

  const sortedKeys = [...grouped.keys()].sort((a, b) => {
    const [gA, tA] = a.split('::');
    const [gB, tB] = b.split('::');
    const diffG = (levelOrder[gA] ?? 99) - (levelOrder[gB] ?? 99);
    if (diffG !== 0) return diffG;
    return Number(tA) - Number(tB);
  });

  let runningCreditsForGpax = 0;
  let runningGradePoints = 0;
  let totalCreditsAttempted = 0;
  let totalCreditsEarned = 0;

  const areaStats = new Map<
    SgsLearningArea,
    { attempted: number; earned: number; points: number }
  >();

  const terms: TermTranscriptSummary[] = [];

  for (const key of sortedKeys) {
    const list = grouped.get(key) ?? [];
    if (list.length === 0) continue;

    const first = list[0];
    let termCreditsAttempted = 0;
    let termCreditsEarned = 0;
    let termCreditsForGpa = 0;
    let termGradePoints = 0;
    let hasPendingSpecialStatus = false;

    const rows = list
      .sort((a, b) => a.subject_code.localeCompare(b.subject_code, 'th'))
      .map((record) => {
        const computed = computeSgsGradeRow(record);
        const cr = Number(record.credits) || 0;

        if (record.subject_type !== 'กิจกรรม') {
          termCreditsAttempted += cr;
          totalCreditsAttempted += cr;

          if (computed.isEarnedCredit) {
            termCreditsEarned += cr;
            totalCreditsEarned += cr;
          }

          if (computed.numericGrade !== null) {
            termCreditsForGpa += cr;
            termGradePoints += cr * computed.numericGrade;
            runningCreditsForGpax += cr;
            runningGradePoints += cr * computed.numericGrade;

            const prevArea = areaStats.get(record.learning_area) ?? {
              attempted: 0,
              earned: 0,
              points: 0,
            };
            prevArea.attempted += cr;
            if (computed.isEarnedCredit) prevArea.earned += cr;
            prevArea.points += cr * computed.numericGrade;
            areaStats.set(record.learning_area, prevArea);
          } else {
            hasPendingSpecialStatus = true;
          }
        } else if (computed.displayGrade === 'มผ') {
          hasPendingSpecialStatus = true;
        }

        return { record, computed };
      });

    const termGpa =
      termCreditsForGpa > 0
        ? Number((termGradePoints / termCreditsForGpa).toFixed(2))
        : 0;
    const cumulativeGpaxAfterTerm =
      runningCreditsForGpax > 0
        ? Number((runningGradePoints / runningCreditsForGpax).toFixed(2))
        : 0;

    terms.push({
      gradeLevel: first.grade_level,
      termNo: first.term_no,
      yearBe: first.year_be,
      rows,
      termCreditsAttempted: Number(termCreditsAttempted.toFixed(1)),
      termCreditsEarned: Number(termCreditsEarned.toFixed(1)),
      termGradePoints: Number(termGradePoints.toFixed(2)),
      termGpa,
      cumulativeCreditsAfterTerm: Number(runningCreditsForGpax.toFixed(1)),
      cumulativeGpaxAfterTerm,
      hasPendingSpecialStatus,
    });
  }

  const overallGpax =
    runningCreditsForGpax > 0
      ? Number((runningGradePoints / runningCreditsForGpax).toFixed(2))
      : 0;

  const byLearningArea: LearningAreaGpaItem[] = SGS_LEARNING_AREAS.filter(
    (area) => area !== 'กิจกรรมพัฒนาผู้เรียน',
  ).map((area) => {
    const st = areaStats.get(area) ?? { attempted: 0, earned: 0, points: 0 };
    return {
      learningArea: area,
      creditsAttempted: Number(st.attempted.toFixed(1)),
      creditsEarned: Number(st.earned.toFixed(1)),
      gpa: st.attempted > 0 ? Number((st.points / st.attempted).toFixed(2)) : 0,
    };
  });

  return {
    terms,
    totalCreditsAttempted: Number(totalCreditsAttempted.toFixed(1)),
    totalCreditsEarned: Number(totalCreditsEarned.toFixed(1)),
    overallGpax,
    byLearningArea,
  };
}

// ============================================================================
// Persistence Layer (Supabase เท่านั้น — ไม่เก็บข้อมูลนักเรียนในเบราว์เซอร์)
// ============================================================================

/** แฟ้มเปล่า: กรอกเฉพาะที่รู้จริงจากทะเบียน ห้ามเติมข้อมูลสมมติ */
export function buildDefaultStudentProfile(
  student: Student,
  indexInRoom = 1,
  gradeLevelLabel = 'ม.1',
): StudentPersonalProfile {
  const prefix = student.prefix ?? '';
  const gender = /นางสาว|เด็กหญิง|หญิง|นาง/.test(prefix)
    ? 'หญิง'
    : /นาย|เด็กชาย/.test(prefix)
      ? 'ชาย'
      : '';
  const levelNum = Number(gradeLevelLabel.replace(/[^0-9]/g, '')) || 1;
  return {
    student_id: student.id,
    id_school: student.id_school,
    seat_no: indexInRoom,
    citizen_id: '',
    first_name_en: '',
    last_name_en: '',
    birth_date: '',
    gender,
    blood_group: '-',
    religion: '',
    nationality: '',
    ethnicity: '',
    study_plan: levelNum >= 4 ? '' : STUDY_PLAN_OPTIONS[0],
    admission_year_be: null,
    previous_school: '',
    address_registered: '',
    address_current: '',
    student_phone: '',
    father_name: '',
    father_occupation: '',
    father_phone: '',
    mother_name: '',
    mother_occupation: '',
    mother_phone: '',
    guardian_relation: '',
    guardian_occupation: '',
    health_note: '',
  };
}

export async function fetchSchoolStudentProfiles(
  schoolId: number,
): Promise<Record<number, StudentPersonalProfile>> {
  const map: Record<number, StudentPersonalProfile> = {};
  // RLS: เฉพาะผู้มีสิทธิ์แก้ไขข้อมูลนักเรียนเท่านั้นที่อ่านแฟ้มได้
  const { data, error } = await supabase
    .from('SchoolWebStudentProfiles')
    .select('*')
    .eq('id_school', schoolId);
  if (!error && data) {
    for (const row of data as StudentPersonalProfile[]) map[row.student_id] = row;
  }
  return map;
}

export async function saveStudentPersonalProfile(
  profile: StudentPersonalProfile,
): Promise<{ savedToDb: boolean; error?: string }> {
  const { error } = await supabase.from('SchoolWebStudentProfiles').upsert(
    { ...profile, updated_at: new Date().toISOString() },
    { onConflict: 'student_id' },
  );
  return error ? { savedToDb: false, error: error.message } : { savedToDb: true };
}

export async function fetchSchoolSgsGrades(
  schoolId: number,
): Promise<SgsScoreRecord[]> {
  const { data, error } = await supabase
    .from('SchoolWebSgsGrades')
    .select('*')
    .eq('id_school', schoolId);
  return !error && data ? (data as SgsScoreRecord[]) : [];
}

export async function saveSgsGradeRecords(
  schoolId: number,
  recordsToSave: SgsScoreRecord[],
): Promise<{ savedToDb: boolean; error?: string }> {
  if (recordsToSave.length === 0) return { savedToDb: true };
  const payload = recordsToSave.map((r) => ({
    id_school: schoolId,
    student_id: r.student_id,
    grade_level: r.grade_level,
    term_no: r.term_no,
    year_be: r.year_be,
    subject_code: r.subject_code,
    subject_name: r.subject_name,
    learning_area: r.learning_area,
    subject_type: r.subject_type,
    credits: r.credits,
    max_pre_mid_work: r.max_pre_mid_work,
    max_pre_mid_notebook: r.max_pre_mid_notebook,
    max_midterm: r.max_midterm,
    max_post_mid_work: r.max_post_mid_work,
    max_post_mid_notebook: r.max_post_mid_notebook,
    max_affective: r.max_affective,
    max_final: r.max_final,
    pre_mid_work: r.pre_mid_work,
    pre_mid_notebook: r.pre_mid_notebook,
    midterm_score: r.midterm_score,
    post_mid_work: r.post_mid_work,
    post_mid_notebook: r.post_mid_notebook,
    affective_score: r.affective_score,
    final_score: r.final_score,
    attended_hours: r.attended_hours,
    total_hours: r.total_hours,
    reading_thinking_writing: r.reading_thinking_writing,
    desirable_characteristics: r.desirable_characteristics,
    special_status: r.special_status,
    teacher_name: r.teacher_name ?? null,
    updated_at: new Date().toISOString(),
  }));
  const { error } = await supabase.from('SchoolWebSgsGrades').upsert(payload, {
    onConflict: 'id_school,student_id,year_be,grade_level,term_no,subject_code',
  });
  return error ? { savedToDb: false, error: error.message } : { savedToDb: true };
}

/**
 * ส่งออกตารางคะแนนของรายวิชาเป็นไฟล์ CSV มาตรฐานสำหรับนำเข้าระบบ SGS (UTF-8 with BOM)
 */
export function downloadSgsGradebookCsv(params: {
  schoolName: string;
  gradeLevel: SgsGradeLevel;
  classroomName: string;
  termNo: 1 | 2;
  yearBe: number;
  subjectCode: string;
  subjectName: string;
  rows: {
    seatNo: number;
    studentCode: string;
    fullName: string;
    record: SgsScoreRecord;
    computed: ComputedSgsScore;
  }[];
}) {
  const headers = [
    'เลขที่',
    'รหัสนักเรียน',
    'ชื่อ-นามสกุล',
    'ชั้น/ห้อง',
    'ปีการศึกษา',
    'ภาคเรียน',
    'รหัสวิชา',
    'ชื่อรายวิชา',
    'หน่วยกิต',
    `คะแนนเก็บก่อนกลางภาค (${params.rows[0]?.record.max_pre_mid_work ?? 15})`,
    `คะแนนสมุดก่อนกลางภาค (${params.rows[0]?.record.max_pre_mid_notebook ?? 10})`,
    `สอบกลางภาค (${params.rows[0]?.record.max_midterm ?? 20})`,
    `คะแนนเก็บหลังกลางภาค (${params.rows[0]?.record.max_post_mid_work ?? 15})`,
    `คะแนนสมุดหลังกลางภาค (${params.rows[0]?.record.max_post_mid_notebook ?? 5})`,
    `คะแนนจิตพิสัย (${params.rows[0]?.record.max_affective ?? 5})`,
    'รวมคะแนนเก็บทั้งหมด',
    'รวมคะแนนระหว่างภาค',
    `สอบปลายภาค (${params.rows[0]?.record.max_final ?? 30})`,
    'คะแนนรวม (100)',
    'ระดับผลการเรียน (เกรด)',
    'เวลาเรียน (ชม.)',
    'เวลาเรียนเต็ม (ชม.)',
    'ร้อยละเวลาเรียน (%)',
    'อ่าน คิดวิเคราะห์ เขียน (0-3)',
    'คุณลักษณะอันพึงประสงค์ (0-3)',
  ];

  const escapeCsv = (val: unknown) => {
    const str = String(val ?? '');
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  const lines = [
    headers.map(escapeCsv).join(','),
    ...params.rows.map((r) =>
      [
        r.seatNo,
        r.studentCode,
        r.fullName,
        params.classroomName,
        params.yearBe,
        params.termNo,
        params.subjectCode,
        params.subjectName,
        r.record.credits,
        r.record.pre_mid_work,
        r.record.pre_mid_notebook,
        r.record.midterm_score,
        r.record.post_mid_work,
        r.record.post_mid_notebook,
        r.record.affective_score,
        r.computed.totalCollected,
        r.computed.totalDuringTerm,
        r.record.final_score,
        r.computed.totalScore,
        r.computed.displayGrade,
        r.record.attended_hours,
        r.record.total_hours,
        r.computed.attendancePercent,
        r.record.reading_thinking_writing,
        r.record.desirable_characteristics,
      ]
        .map(escapeCsv)
        .join(','),
    ),
  ];

  const csvContent = '\uFEFF' + lines.join('\r\n');
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `SGS_${params.subjectCode}_${params.classroomName.replace('/', '-')}_เทอม${params.termNo}-${params.yearBe}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export interface PublicSgsStudentInfo {
  id: number;
  id_school: number;
  student_code: string;
  prefix: string | null;
  first_name: string;
  last_name: string;
  classroom_name: string;
  grade_level: string;
  seat_no: number | null;
  study_plan: string;
}

export async function lookupPublicStudentSgsTranscript(params: {
  schoolId: number | null;
  studentCode: string;
  verifyCode: string;
}): Promise<{
  ok: boolean;
  error?: string;
  student?: PublicSgsStudentInfo;
  transcript?: StudentMultiYearTranscript;
}> {
  const cleanCode = params.studentCode.trim();
  const cleanVerify = params.verifyCode.trim();
  if (!cleanCode) {
    return { ok: false, error: 'กรุณากรอกรหัสประจำตัวนักเรียน' };
  }

  // 1) เรียกผ่าน RPC lookup_public_student_sgs_grades (รองรับทั้งคนนอกที่ไม่ล็อกอินและบุคลากร)
  try {
    const rpcRes = await supabase.rpc('lookup_public_student_sgs_grades', {
      target_school: params.schoolId,
      p_student_code: cleanCode,
      p_verify_code: cleanVerify,
    });
    if (!rpcRes.error && rpcRes.data) {
      const payload = rpcRes.data as {
        ok?: boolean;
        error?: string;
        student?: PublicSgsStudentInfo;
        grades?: SgsScoreRecord[];
      };
      if (!payload.ok) {
        return {
          ok: false,
          error: payload.error || 'ไม่พบข้อมูลนักเรียนตามรหัสที่ระบุ',
        };
      }
      const grades = Array.isArray(payload.grades) ? payload.grades : [];
      return {
        ok: true,
        student: payload.student,
        transcript: computeStudentMultiYearTranscript(grades),
      };
    }
  } catch {
    // fallback ด้านล่างหากยังไม่ได้รัน school_web_realtime_public.sql
  }

  // 2) Fallback ค้นหาจากตารางโดยตรง (กรณีล็อกอินอยู่)
  try {
    let q = supabase
      .from('SchoolWebStudents')
      .select('id, id_school, student_code, prefix, first_name, last_name, classroom_id')
      .ilike('student_code', cleanCode)
      .limit(1);
    if (params.schoolId) {
      q = q.eq('id_school', params.schoolId);
    }
    const { data: stuData, error: stuErr } = await q.maybeSingle();
    if (stuErr || !stuData) {
      return {
        ok: false,
        error: 'ไม่พบรหัสนักเรียนนี้ในระบบโรงเรียน',
      };
    }

    const stu = stuData as {
      id: number;
      id_school: number;
      student_code: string;
      prefix: string | null;
      first_name: string;
      last_name: string;
      classroom_id: number | null;
    };

    const [clsRes, profRes, gradesRes] = await Promise.all([
      stu.classroom_id
        ? supabase
            .from('SchoolWebClassrooms')
            .select('name, grade_level')
            .eq('id', stu.classroom_id)
            .maybeSingle()
        : Promise.resolve({ data: null }),
      supabase
        .from('SchoolWebStudentProfiles')
        .select('seat_no, citizen_id, study_plan')
        .eq('student_id', stu.id)
        .maybeSingle(),
      supabase
        .from('SchoolWebSgsGrades')
        .select('*')
        .eq('student_id', stu.id),
    ]);

    const prof = profRes.data as {
      seat_no?: number;
      citizen_id?: string | null;
      study_plan?: string | null;
    } | null;

    const storedCitizen = (prof?.citizen_id ?? '').replace(/[^0-9]/g, '');
    const userVerifyDigits = cleanVerify.replace(/[^0-9A-Za-z]/g, '');
    if (storedCitizen && userVerifyDigits) {
      if (
        userVerifyDigits !== storedCitizen &&
        storedCitizen.slice(-4) !== userVerifyDigits.slice(-4) &&
        userVerifyDigits.toLowerCase() !== cleanCode.toLowerCase()
      ) {
        return {
          ok: false,
          error:
            'รหัสยืนยัน (เลขบัตรประชาชน 13 หลัก หรือ 4 ตัวท้าย) ไม่ตรงกับข้อมูลในระบบ',
        };
      }
    }

    const cls = clsRes.data as { name?: string; grade_level?: string } | null;
    const grades = (gradesRes.data as SgsScoreRecord[] | null) ?? [];

    return {
      ok: true,
      student: {
        id: stu.id,
        id_school: stu.id_school,
        student_code: stu.student_code,
        prefix: stu.prefix,
        first_name: stu.first_name,
        last_name: stu.last_name,
        classroom_name: cls?.name || 'ยังไม่ระบุห้อง',
        grade_level: cls?.grade_level || 'ม.1',
        seat_no: prof?.seat_no ?? 1,
        study_plan: prof?.study_plan || 'ทั่วไป',
      },
      transcript: computeStudentMultiYearTranscript(grades),
    };
  } catch {
    return {
      ok: false,
      error: 'ไม่สามารถเชื่อมต่อระบบตรวจสอบผลการเรียนได้ในขณะนี้',
    };
  }
}
