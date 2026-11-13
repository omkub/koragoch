export interface SchoolInfo {
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
