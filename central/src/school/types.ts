export interface SchoolBasic {
  id_school: number;
  fullName: string | null;
  affiliation: string | null;
}

export interface AcademicYear {
  id: number;
  id_school: number;
  year_be: number;
  label: string;
  is_current: boolean;
}

export interface AcademicTerm {
  id: number;
  id_school: number;
  academic_year_id: number;
  term_no: number;
  label: string;
  is_current: boolean;
}

export interface SchoolDepartment {
  id: number;
  id_school: number;
  code: string | null;
  name: string;
  category: 'management' | 'academic' | 'support' | 'department';
  sort_order: number;
  is_active: boolean;
}

export interface SchoolModuleLink {
  id?: number;
  module_key: string;
  title: string;
  description: string;
  url: string;
  open_mode: 'new_tab' | 'same_tab';
  category: 'hr' | 'academic' | 'admin' | 'other';
  is_enabled: boolean;
}

export interface Classroom {
  id: number;
  id_school: number;
  academic_year_id: number | null;
  grade_level: string;
  room_no: string;
  name: string;
  advisor_teacher_id: number | null;
  is_active: boolean;
}

export type StudentStatus = 'enrolled' | 'transferred' | 'graduated' | 'dropped';

export interface Student {
  id: number;
  id_school: number;
  student_code: string;
  prefix: string | null;
  first_name: string;
  last_name: string;
  classroom_id: number | null;
  guardian_name: string | null;
  guardian_phone: string | null;
  status: StudentStatus;
}

export interface Subject {
  id: number;
  id_school: number;
  code: string;
  name: string;
  department_id: number | null;
  credits: number;
  is_active: boolean;
}

export interface TeachingSchedule {
  id: number;
  id_school: number;
  academic_term_id: number | null;
  classroom_id: number;
  subject_id: number;
  teacher_id: number | null;
  day_of_week: number;
  period_no: number;
  room_name: string | null;
}

export interface TeacherOption {
  id_user: number;
  fullName: string | null;
}
