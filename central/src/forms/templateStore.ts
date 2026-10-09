/**
 * อ่าน / บันทึกแม่แบบในตาราง FormTemplates (supabase/form_templates.sql)
 *
 * 1 แถว = 1 เวอร์ชัน (ฐานข้อมูลตั้งเลขเวอร์ชันให้เอง) ไม่มีการแก้ทับ
 * schoolId = null คือแม่แบบกลาง
 */
import { supabase } from '../supabase';
import { defaultLeaveTemplate } from './leaveTemplate';
import { defaultTripTemplate } from './tripTemplate';
import { normalizeTemplate, type FormTemplate, type FormType } from './template';

export interface TemplateVersion {
  id_template: number;
  form_type: FormType;
  id_school: number | null;
  version: number;
  template: unknown;
  uses_default: boolean;
  note: string | null;
  created_by: number | null;
  createdAt: string;
}

export const builtInTemplate = (type: FormType): FormTemplate =>
  type === 'leave' ? defaultLeaveTemplate() : defaultTripTemplate();

/** ประวัติเวอร์ชัน ใหม่สุดก่อน */
export async function listVersions(type: FormType, schoolId: number | null): Promise<TemplateVersion[]> {
  let q = supabase.from('FormTemplates').select('*').eq('form_type', type);
  q = schoolId === null ? q.is('id_school', null) : q.eq('id_school', schoolId);
  const { data, error } = await q.order('version', { ascending: false }).limit(100);
  if (error) throw new Error(error.message);
  return data as TemplateVersion[];
}

export type TemplateSource = 'school' | 'global' | 'builtin';

export interface ResolvedTemplate {
  template: FormTemplate;
  source: TemplateSource;
  version: number | null;
}

/**
 * แม่แบบที่ใช้จริง — ของโรงเรียน → แม่แบบกลาง → ค่าเริ่มต้นในโค้ด
 * (ลำดับเดียวกับฟังก์ชัน current_form_template ในฐานข้อมูล)
 */
export async function resolveTemplate(type: FormType, schoolId: number | null): Promise<ResolvedTemplate> {
  const fallback = builtInTemplate(type);
  if (schoolId !== null) {
    const [own] = await listVersions(type, schoolId);
    if (own && !own.uses_default) {
      return { template: normalizeTemplate(own.template, fallback), source: 'school', version: own.version };
    }
  }
  const [global] = await listVersions(type, null);
  if (global) return { template: normalizeTemplate(global.template, fallback), source: 'global', version: global.version };
  return { template: fallback, source: 'builtin', version: null };
}

/** บันทึกเป็นเวอร์ชันใหม่ */
export async function saveVersion(
  type: FormType,
  schoolId: number | null,
  template: FormTemplate,
  note: string,
): Promise<TemplateVersion> {
  const { data, error } = await supabase
    .from('FormTemplates')
    .insert({ form_type: type, id_school: schoolId, version: 0, template, uses_default: false, note: note.trim() || null })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as TemplateVersion;
}

/** ให้โรงเรียนกลับไปใช้แม่แบบกลาง (บันทึกเป็นเวอร์ชันหนึ่ง ย้อนกลับได้) */
export async function setSchoolUsesGlobal(type: FormType, schoolId: number, note: string): Promise<void> {
  const { error } = await supabase
    .from('FormTemplates')
    .insert({ form_type: type, id_school: schoolId, version: 0, template: null, uses_default: true, note: note.trim() || null });
  if (error) throw new Error(error.message);
}
