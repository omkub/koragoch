import { useState } from 'react';
import {
  Award,
  CheckCircle2,
  Lock,
  Plus,
  Printer,
  Send,
  SlidersHorizontal,
  Trash2,
  X,
} from 'lucide-react';
import {
  SGS_GRADE_BUCKETS,
  type SgsCourseGradeStats,
  type SgsCourseScoreStructure,
  type SgsCourseSubmissionRecord,
  type SgsGradeLevel,
  type SgsIndicatorItem,
  type SgsLearningArea,
} from './sgsGradingStore';

// ════════════════════════════════════════════════════════════════════════════
// 1) MODAL: ตั้งค่าโครงสร้างสัดส่วนคะแนนและตัวชี้วัด (Score Structure Setup)
// ════════════════════════════════════════════════════════════════════════════
interface SgsScoreStructureModalProps {
  subjectCode: string;
  subjectName: string;
  initial: SgsCourseScoreStructure;
  onClose: () => void;
  onSave: (next: SgsCourseScoreStructure) => void;
}

export function SgsScoreStructureModal({
  subjectCode,
  subjectName,
  initial,
  onClose,
  onSave,
}: SgsScoreStructureModalProps) {
  const [form, setForm] = useState<SgsCourseScoreStructure>(() => ({
    ...initial,
    indicators: initial.indicators.map((it) => ({ ...it })),
  }));

  const total =
    form.max_pre_mid_work +
    form.max_pre_mid_notebook +
    form.max_midterm +
    form.max_post_mid_work +
    form.max_post_mid_notebook +
    form.max_affective +
    form.max_final;

  const duringTerm = total - form.max_final;

  const applyPreset = (preset: '70-30' | '80-20' | '60-40') => {
    if (preset === '70-30') {
      setForm((p) => ({
        ...p,
        max_pre_mid_work: 15,
        max_pre_mid_notebook: 10,
        max_midterm: 20,
        max_post_mid_work: 15,
        max_post_mid_notebook: 5,
        max_affective: 5,
        max_final: 30,
      }));
    } else if (preset === '80-20') {
      setForm((p) => ({
        ...p,
        max_pre_mid_work: 20,
        max_pre_mid_notebook: 10,
        max_midterm: 20,
        max_post_mid_work: 20,
        max_post_mid_notebook: 5,
        max_affective: 5,
        max_final: 20,
      }));
    } else {
      setForm((p) => ({
        ...p,
        max_pre_mid_work: 15,
        max_pre_mid_notebook: 5,
        max_midterm: 20,
        max_post_mid_work: 15,
        max_post_mid_notebook: 0,
        max_affective: 5,
        max_final: 40,
      }));
    }
  };

  const addIndicator = () => {
    const nextItem: SgsIndicatorItem = {
      id: `ind-${Date.now()}`,
      code: `${subjectCode.slice(0, 2)} ${(form.indicators.length + 1).toString()}`,
      description: '',
      maxScore: 10,
    };
    setForm((p) => ({ ...p, indicators: [...p.indicators, nextItem] }));
  };

  const updateIndicator = (idx: number, patch: Partial<SgsIndicatorItem>) => {
    setForm((p) => ({
      ...p,
      indicators: p.indicators.map((it, i) =>
        i === idx ? { ...it, ...patch } : it,
      ),
    }));
  };

  const removeIndicator = (idx: number) => {
    setForm((p) => ({
      ...p,
      indicators: p.indicators.filter((_, i) => i !== idx),
    }));
  };

  return (
    <div
      className="fixed inset-0 z-50 bg-slate-950/50 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto"
      onClick={onClose}
    >
      <div
        className="w-full max-w-3xl rounded-2xl bg-white shadow-2xl border border-slate-200 overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-slate-200 px-6 py-4">
          <div className="flex items-center gap-2.5">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
              <SlidersHorizontal className="h-4 w-4" />
            </div>
            <div>
              <h3 className="text-base font-bold text-ink">
                ตั้งค่าโครงสร้างสัดส่วนคะแนนและตัวชี้วัด (SGS)
              </h3>
              <p className="text-xs text-slate-500">
                รายวิชา {subjectCode} {subjectName}
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="p-6 space-y-5 max-h-[75vh] overflow-y-auto">
          {/* Presets & Total */}
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-slate-50 border border-slate-200 px-4 py-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-semibold text-slate-600">
                สูตรสัดส่วนมาตรฐาน:
              </span>
              <button
                type="button"
                onClick={() => applyPreset('70-30')}
                className="btn-secondary btn-sm"
              >
                70 : 30 (มาตรฐาน)
              </button>
              <button
                type="button"
                onClick={() => applyPreset('80-20')}
                className="btn-secondary btn-sm"
              >
                80 : 20 (เน้นปฏิบัติ)
              </button>
              <button
                type="button"
                onClick={() => applyPreset('60-40')}
                className="btn-secondary btn-sm"
              >
                60 : 40 (เน้นสอบ)
              </button>
            </div>
            <div
              className={`rounded-full px-3 py-1 text-xs font-bold tabular-nums ${
                total === 100
                  ? 'bg-emerald-100 text-emerald-800'
                  : 'bg-rose-100 text-rose-800'
              }`}
            >
              รวม {total} / 100 คะแนน (ระหว่างภาค {duringTerm} : ปลายภาค{' '}
              {form.max_final})
            </div>
          </div>

          {/* 7 Score Weight Fields */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {(
              [
                ['max_pre_mid_work', 'เก็บก่อนกลางภาค'],
                ['max_pre_mid_notebook', 'สมุด/ใบงานก่อนกลางภาค'],
                ['max_midterm', 'สอบกลางภาค'],
                ['max_post_mid_work', 'เก็บหลังกลางภาค'],
                ['max_post_mid_notebook', 'สมุด/ใบงานหลังกลางภาค'],
                ['max_affective', 'จิตพิสัย/คุณลักษณะ'],
                ['max_final', 'สอบปลายภาค'],
              ] as const
            ).map(([fieldKey, label]) => (
              <label key={fieldKey} className="field">
                <span className="text-xs">{label}</span>
                <input
                  type="number"
                  min={0}
                  max={100}
                  value={form[fieldKey]}
                  onChange={(e) =>
                    setForm((p) => ({
                      ...p,
                      [fieldKey]: Math.max(0, Number(e.target.value) || 0),
                    }))
                  }
                  className="input font-semibold text-center tabular-nums"
                />
              </label>
            ))}
          </div>

          {total !== 100 && (
            <div className="alert-error text-xs">
              ผลรวมคะแนนเต็มทุกช่องต้องเท่ากับ <strong>100 คะแนน</strong> พอดี
              (ตอนนี้รวมได้ {total} คะแนน)
            </div>
          )}

          {/* Indicators / Learning Outcomes */}
          <div className="space-y-3 pt-2 border-t border-slate-200">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-bold text-ink">
                  รายการตัวชี้วัด / ผลการเรียนรู้ ({form.indicators.length} ข้อ)
                </h4>
                <p className="text-xs text-slate-500">
                  จะนำไปแสดงประกอบบนใบรับรองการส่งมอบผลการเรียน (ปพ.5 / SGS)
                </p>
              </div>
              <button
                type="button"
                onClick={addIndicator}
                className="btn-secondary btn-sm"
              >
                <Plus className="h-3.5 w-3.5" />
                <span>เพิ่มตัวชี้วัด</span>
              </button>
            </div>

            {form.indicators.length === 0 ? (
              <div className="rounded-xl border border-dashed border-slate-200 p-5 text-center text-xs text-slate-500">
                ยังไม่ได้กำหนดรายการตัวชี้วัด (กด &ldquo;เพิ่มตัวชี้วัด&rdquo; เพื่อระบุรหัสและคะแนน)
              </div>
            ) : (
              <div className="space-y-2">
                {form.indicators.map((ind, idx) => (
                  <div
                    key={ind.id}
                    className="grid grid-cols-1 sm:grid-cols-12 gap-2 items-center rounded-xl border border-slate-200 bg-slate-50/50 p-2.5"
                  >
                    <input
                      value={ind.code}
                      onChange={(e) =>
                        updateIndicator(idx, { code: e.target.value })
                      }
                      placeholder="รหัส เช่น ว 4.2 ม.4/1"
                      className="input text-xs sm:col-span-3"
                    />
                    <input
                      value={ind.description}
                      onChange={(e) =>
                        updateIndicator(idx, { description: e.target.value })
                      }
                      placeholder="คำอธิบายตัวชี้วัด / ผลการเรียนรู้"
                      className="input text-xs sm:col-span-6"
                    />
                    <input
                      type="number"
                      min={0}
                      max={100}
                      value={ind.maxScore}
                      onChange={(e) =>
                        updateIndicator(idx, {
                          maxScore: Math.max(0, Number(e.target.value) || 0),
                        })
                      }
                      placeholder="คะแนน"
                      className="input text-xs text-center tabular-nums sm:col-span-2"
                    />
                    <div className="sm:col-span-1 flex justify-end">
                      <button
                        type="button"
                        onClick={() => removeIndicator(idx)}
                        className="rounded-lg p-1.5 text-rose-600 hover:bg-rose-50"
                        title="ลบตัวชี้วัด"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="flex items-center justify-end gap-2.5 border-t border-slate-200 bg-slate-50 px-6 py-3.5">
          <button type="button" onClick={onClose} className="btn-secondary">
            ยกเลิก
          </button>
          <button
            type="button"
            disabled={total !== 100}
            onClick={() => onSave(form)}
            className="btn-primary"
          >
            บันทึกโครงสร้างคะแนน (100 คะแนน)
          </button>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// 2) MODAL: ยืนยันส่งมอบผลการเรียนเข้าฝ่ายวิชาการ (Submit & Lock Grades)
// ════════════════════════════════════════════════════════════════════════════
interface SgsSubmitConfirmModalProps {
  subjectCode: string;
  subjectName: string;
  gradeLevel: SgsGradeLevel;
  termNo: 1 | 2;
  yearBe: number;
  classroomLabel: string;
  defaultTeacherName: string;
  stats: SgsCourseGradeStats;
  submitting: boolean;
  submittedRecord: SgsCourseSubmissionRecord | null;
  onClose: () => void;
  onConfirmSubmit: (teacherName: string) => Promise<void>;
  onOpenCertificate: () => void;
}

export function SgsSubmitConfirmModal({
  subjectCode,
  subjectName,
  gradeLevel,
  termNo,
  yearBe,
  classroomLabel,
  defaultTeacherName,
  stats,
  submitting,
  submittedRecord,
  onClose,
  onConfirmSubmit,
  onOpenCertificate,
}: SgsSubmitConfirmModalProps) {
  const [teacherName, setTeacherName] = useState(
    defaultTeacherName || 'ครูผู้สอนประจำรายวิชา',
  );

  const justSubmitted = Boolean(
    submittedRecord && submittedRecord.status === 'submitted',
  );

  return (
    <div
      className="fixed inset-0 z-50 bg-slate-950/50 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg rounded-2xl bg-white shadow-2xl border border-slate-200 overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {justSubmitted && submittedRecord ? (
          <div className="p-6 text-center space-y-4">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-emerald-100 text-emerald-600">
              <CheckCircle2 className="h-8 w-8" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-ink">
                ส่งผลการเรียนเข้าฝ่ายวิชาการเรียบร้อยแล้ว!
              </h3>
              <p className="text-xs text-slate-500 mt-1">
                ระบบได้บันทึกและล็อกคะแนนรายวิชา {subjectCode} {subjectName}{' '}
                ({classroomLabel}) ภาคเรียนที่ {termNo}/{yearBe} แล้ว
              </p>
            </div>
            <div className="rounded-xl bg-slate-50 border border-slate-200 p-4 text-left text-xs space-y-1.5">
              <div className="flex justify-between">
                <span className="text-slate-500">เลขที่ใบรับรองการส่งมอบ:</span>
                <span className="font-bold text-brand-700">
                  {submittedRecord.referenceCode}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">ครูผู้สอนผู้ส่งมอบ:</span>
                <span className="font-semibold text-ink">
                  {submittedRecord.teacherName}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">จำนวนนักเรียนที่นำส่ง:</span>
                <span className="font-semibold text-ink">
                  {submittedRecord.studentCount} คน (ผ่านเกณฑ์{' '}
                  {stats.passRatePct}%)
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">วันเวลาที่ส่งมอบ:</span>
                <span className="font-medium text-slate-700">
                  {new Date(submittedRecord.submittedAt).toLocaleString('th-TH')}
                </span>
              </div>
            </div>
            <div className="flex flex-col sm:flex-row gap-2.5 pt-2">
              <button
                type="button"
                onClick={onClose}
                className="btn-secondary flex-1 justify-center"
              >
                ปิดหน้าต่าง
              </button>
              <button
                type="button"
                onClick={onOpenCertificate}
                className="btn-primary flex-1 justify-center"
              >
                <Award className="h-4 w-4" />
                <span>เปิดใบรับรองการส่งมอบ (พิมพ์)</span>
              </button>
            </div>
          </div>
        ) : (
          <>
            <div className="flex items-center justify-between border-b border-slate-200 px-6 py-4">
              <div className="flex items-center gap-2.5">
                <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
                  <Send className="h-4 w-4" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-ink">
                    ยืนยันส่งมอบผลการเรียนเข้าฝ่ายวิชาการ
                  </h3>
                  <p className="text-xs text-slate-500">
                    {subjectCode} {subjectName} • {gradeLevel} ({classroomLabel})
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={onClose}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div className="grid grid-cols-3 gap-2.5 text-center">
                <div className="rounded-xl bg-slate-50 border border-slate-200 p-3">
                  <p className="text-[11px] text-slate-500">นักเรียนทั้งหมด</p>
                  <p className="text-lg font-bold text-ink tabular-nums">
                    {stats.totalStudents} คน
                  </p>
                </div>
                <div className="rounded-xl bg-emerald-50 border border-emerald-200 p-3">
                  <p className="text-[11px] text-emerald-700">ผ่านเกณฑ์</p>
                  <p className="text-lg font-bold text-emerald-700 tabular-nums">
                    {stats.passedCount} คน ({stats.passRatePct}%)
                  </p>
                </div>
                <div className="rounded-xl bg-amber-50 border border-amber-200 p-3">
                  <p className="text-[11px] text-amber-800">ติด 0 / ร / มส</p>
                  <p className="text-lg font-bold text-amber-800 tabular-nums">
                    {stats.zeroOrSpecialCount} คน
                  </p>
                </div>
              </div>

              <label className="field">
                <span>ชื่อครูผู้สอนผู้ส่งมอบผลการเรียน (แสดงบนใบรับรอง)</span>
                <input
                  value={teacherName}
                  onChange={(e) => setTeacherName(e.target.value)}
                  className="input"
                  placeholder="ระบุชื่อ-นามสกุลครูผู้สอน"
                />
              </label>

              <div className="rounded-xl bg-brand-50/70 border border-brand-100 p-3.5 text-xs text-brand-800 flex items-start gap-2">
                <Lock className="h-4 w-4 shrink-0 mt-0.5" />
                <span>
                  เมื่อกดยืนยัน ระบบจะบันทึกคะแนนล่าสุดลงฐานข้อมูลและล็อกตารางกรอกคะแนนเพื่อป้องกันการแก้ไขโดยไม่ตั้งใจ
                  (สามารถกดปลดล็อกเพื่อแก้ไขภายหลังได้หากฝ่ายวิชาการแจ้งแก้ไข)
                </span>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2.5 border-t border-slate-200 bg-slate-50 px-6 py-3.5">
              <button
                type="button"
                onClick={onClose}
                className="btn-secondary"
              >
                ยกเลิก
              </button>
              <button
                type="button"
                disabled={submitting || stats.totalStudents === 0}
                onClick={() => onConfirmSubmit(teacherName.trim())}
                className="btn-primary"
              >
                <Send className="h-4 w-4" />
                <span>
                  {submitting
                    ? 'กำลังบันทึกและส่งมอบ...'
                    : 'ยืนยันส่งมอบผลการเรียน'}
                </span>
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// 3) MODAL: ใบรับรองการบันทึกและส่งมอบผลการเรียน (SGS Certificate - Printable)
// ════════════════════════════════════════════════════════════════════════════
interface SgsSubmissionCertificateModalProps {
  schoolDisplayName: string;
  subjectCode: string;
  subjectName: string;
  learningArea: SgsLearningArea;
  credits: number;
  gradeLevel: SgsGradeLevel;
  termNo: 1 | 2;
  yearBe: number;
  classroomLabel: string;
  teacherName: string;
  submission: SgsCourseSubmissionRecord | null;
  structure: SgsCourseScoreStructure;
  stats: SgsCourseGradeStats;
  onClose: () => void;
}

export function SgsSubmissionCertificateModal({
  schoolDisplayName,
  subjectCode,
  subjectName,
  learningArea,
  credits,
  gradeLevel,
  termNo,
  yearBe,
  classroomLabel,
  teacherName,
  submission,
  structure,
  stats,
  onClose,
}: SgsSubmissionCertificateModalProps) {
  const handlePrint = () => {
    document.body.classList.add('printing-sgs-certificate');
    const cleanup = () => {
      document.body.classList.remove('printing-sgs-certificate');
      window.removeEventListener('afterprint', cleanup);
    };
    window.addEventListener('afterprint', cleanup);
    window.print();
    setTimeout(cleanup, 1500);
  };

  const refCode =
    submission?.referenceCode || `SGS-${yearBe}-${termNo}-${subjectCode}`;
  const submittedDateText = submission?.submittedAt
    ? new Date(submission.submittedAt).toLocaleString('th-TH', {
        dateStyle: 'long',
        timeStyle: 'short',
      })
    : new Date().toLocaleString('th-TH', {
        dateStyle: 'long',
        timeStyle: 'short',
      });

  return (
    <div
      className="fixed inset-0 z-50 bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto"
      onClick={onClose}
    >
      <div
        className="w-full max-w-4xl rounded-2xl bg-white shadow-2xl border border-slate-200 overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Top Modal Controls (hidden on print) */}
        <div className="flex items-center justify-between border-b border-slate-200 bg-slate-50 px-6 py-3.5 print:hidden">
          <div className="flex items-center gap-2">
            <Award className="h-5 w-5 text-brand-600" />
            <span className="text-sm font-bold text-ink">
              ใบรับรองการบันทึกและส่งมอบผลการเรียน (SGS / ใบปะหน้า ปพ.5)
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handlePrint}
              className="btn-primary btn-sm"
            >
              <Printer className="h-4 w-4" />
              <span>สั่งพิมพ์ / บันทึก PDF</span>
            </button>
            <button
              type="button"
              onClick={onClose}
              className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-200/70"
            >
              <X className="h-5 w-5" />
            </button>
          </div>
        </div>

        {/* Printable A4 Certificate Body */}
        <div className="sgs-cert-print-area p-6 sm:p-8 space-y-6 max-h-[80vh] overflow-y-auto print:max-h-none print:overflow-visible">
          {/* Official Header */}
          <div className="border-b-2 border-slate-800 pb-4 flex flex-col sm:flex-row sm:items-start justify-between gap-3">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wider text-brand-700">
                เอกสารรับรองการส่งมอบผลการเรียน • SGS ACADEMIC SUBMISSION CERTIFICATE
              </p>
              <h2 className="text-xl font-bold text-slate-900 mt-1">
                ใบรับรองการบันทึกและส่งมอบผลการเรียนเข้าสู่ระบบสารสนเทศ (SGS)
              </h2>
              <p className="text-sm font-medium text-slate-700 mt-0.5">
                {schoolDisplayName} • ภาคเรียนที่ {termNo} ปีการศึกษา {yearBe}
              </p>
            </div>
            <div className="rounded-xl border border-slate-300 bg-slate-50 px-3.5 py-2 text-xs text-right shrink-0">
              <p className="text-slate-500">เลขที่อ้างอิงเอกสาร</p>
              <p className="font-bold text-slate-900 text-sm">{refCode}</p>
              <p className="text-[11px] text-emerald-700 font-semibold mt-0.5">
                {submission?.status === 'submitted'
                  ? 'สถานะ: ส่งมอบฝ่ายวิชาการแล้ว'
                  : 'สถานะ: ฉบับร่าง (ยังไม่ส่งมอบ)'}
              </p>
            </div>
          </div>

          {/* 1. Course & Instructor Profile */}
          <div className="space-y-2">
            <h3 className="text-sm font-bold text-slate-900">
              1. ข้อมูลรายวิชาและผู้ส่งมอบ (Course &amp; Instructor Profile)
            </h3>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 rounded-xl border border-slate-200 bg-slate-50/70 p-4 text-xs">
              <div>
                <span className="text-slate-500 block">รหัสวิชา</span>
                <span className="font-bold text-slate-900 text-sm">
                  {subjectCode}
                </span>
              </div>
              <div className="sm:col-span-2">
                <span className="text-slate-500 block">ชื่อรายวิชา</span>
                <span className="font-bold text-slate-900 text-sm">
                  {subjectName}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block">หน่วยกิต</span>
                <span className="font-bold text-slate-900">
                  {credits.toFixed(1)} หน่วยกิต
                </span>
              </div>
              <div>
                <span className="text-slate-500 block">กลุ่มสาระการเรียนรู้</span>
                <span className="font-semibold text-slate-800">
                  {learningArea}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block">ระดับชั้น / ห้องเรียน</span>
                <span className="font-semibold text-slate-800">
                  {gradeLevel} ({classroomLabel})
                </span>
              </div>
              <div>
                <span className="text-slate-500 block">ครูผู้สอนผู้ส่งมอบ</span>
                <span className="font-semibold text-slate-800">
                  {submission?.teacherName || teacherName || '-'}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block">วันเวลาที่ส่งมอบ</span>
                <span className="font-medium text-slate-700">
                  {submittedDateText}
                </span>
              </div>
            </div>
          </div>

          {/* 2. Grade Statistics Summary */}
          <div className="space-y-3">
            <h3 className="text-sm font-bold text-slate-900">
              2. สรุปสถิติผลการเรียนที่นำส่ง (Grade Statistics Summary)
            </h3>

            {/* KPI Strip */}
            <div className="grid grid-cols-2 sm:grid-cols-6 gap-2.5 text-center text-xs">
              <div className="rounded-xl border border-slate-200 p-2.5">
                <span className="text-slate-500 block">นักเรียนทั้งหมด</span>
                <span className="text-base font-bold text-slate-900 tabular-nums">
                  {stats.totalStudents} คน
                </span>
              </div>
              <div className="rounded-xl border border-emerald-200 bg-emerald-50/50 p-2.5">
                <span className="text-emerald-700 block">ผ่านเกณฑ์ (1–4)</span>
                <span className="text-base font-bold text-emerald-700 tabular-nums">
                  {stats.passedCount} ({stats.passRatePct}%)
                </span>
              </div>
              <div className="rounded-xl border border-slate-200 p-2.5">
                <span className="text-slate-500 block">เกรดเฉลี่ย (GPA)</span>
                <span className="text-base font-bold text-brand-700 tabular-nums">
                  {stats.meanGpa.toFixed(2)}
                </span>
              </div>
              <div className="rounded-xl border border-slate-200 p-2.5">
                <span className="text-slate-500 block">คะแนนเฉลี่ย (Mean)</span>
                <span className="text-base font-bold text-slate-900 tabular-nums">
                  {stats.meanScore.toFixed(2)}
                </span>
              </div>
              <div className="rounded-xl border border-slate-200 p-2.5">
                <span className="text-slate-500 block">ส่วนเบี่ยงเบน (S.D.)</span>
                <span className="text-base font-bold text-slate-900 tabular-nums">
                  {stats.sdScore.toFixed(2)}
                </span>
              </div>
              <div className="rounded-xl border border-slate-200 p-2.5">
                <span className="text-slate-500 block">สูงสุด / ต่ำสุด</span>
                <span className="text-base font-bold text-slate-900 tabular-nums">
                  {stats.maxScore} / {stats.minScore}
                </span>
              </div>
            </div>

            {/* Grade Distribution Table */}
            <div className="overflow-x-auto rounded-xl border border-slate-300">
              <table className="w-full text-center text-xs border-collapse">
                <thead>
                  <tr className="bg-slate-100 text-slate-700 border-b border-slate-300">
                    <th className="py-2 px-2 text-left font-bold border-r border-slate-200">
                      ระดับผลการเรียน
                    </th>
                    {SGS_GRADE_BUCKETS.map((g) => (
                      <th
                        key={g}
                        className="py-2 px-2 font-bold border-r border-slate-200 last:border-r-0"
                      >
                        {g}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-b border-slate-200">
                    <td className="py-2 px-2 text-left font-semibold text-slate-600 border-r border-slate-200">
                      จำนวน (คน)
                    </td>
                    {SGS_GRADE_BUCKETS.map((g) => (
                      <td
                        key={g}
                        className="py-2 px-2 font-bold text-slate-900 tabular-nums border-r border-slate-200 last:border-r-0"
                      >
                        {stats.distribution[g] ?? 0}
                      </td>
                    ))}
                  </tr>
                  <tr>
                    <td className="py-2 px-2 text-left font-semibold text-slate-600 border-r border-slate-200">
                      ร้อยละ (%)
                    </td>
                    {SGS_GRADE_BUCKETS.map((g) => {
                      const c = stats.distribution[g] ?? 0;
                      const pct =
                        stats.totalStudents > 0
                          ? ((c / stats.totalStudents) * 100).toFixed(1)
                          : '0.0';
                      return (
                        <td
                          key={g}
                          className="py-2 px-2 text-slate-600 tabular-nums border-r border-slate-200 last:border-r-0"
                        >
                          {pct}%
                        </td>
                      );
                    })}
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* 3. Score Structure & Indicators */}
          <div className="space-y-2">
            <h3 className="text-sm font-bold text-slate-900">
              3. โครงสร้างสัดส่วนคะแนนตามหลักสูตร (รวม 100 คะแนน)
            </h3>
            <div className="grid grid-cols-2 sm:grid-cols-7 gap-2 text-center text-[11px]">
              {[
                ['เก็บก่อนกลางภาค', structure.max_pre_mid_work],
                ['สมุดก่อนกลางภาค', structure.max_pre_mid_notebook],
                ['สอบกลางภาค', structure.max_midterm],
                ['เก็บหลังกลางภาค', structure.max_post_mid_work],
                ['สมุดหลังกลางภาค', structure.max_post_mid_notebook],
                ['จิตพิสัย', structure.max_affective],
                ['สอบปลายภาค', structure.max_final],
              ].map(([lbl, val]) => (
                <div
                  key={String(lbl)}
                  className="rounded-lg border border-slate-200 bg-slate-50 px-2 py-2"
                >
                  <span className="text-slate-500 block">{lbl}</span>
                  <span className="font-bold text-slate-900 text-xs">
                    {val} คะแนน
                  </span>
                </div>
              ))}
            </div>
            {structure.indicators.length > 0 && (
              <div className="rounded-xl border border-slate-200 p-3 text-xs space-y-1">
                <p className="font-semibold text-slate-700">
                  ตัวชี้วัด / ผลการเรียนรู้ที่ประเมิน:
                </p>
                <ul className="list-disc pl-5 space-y-0.5 text-slate-600">
                  {structure.indicators.map((ind) => (
                    <li key={ind.id}>
                      <strong>{ind.code}</strong>: {ind.description || '-'}{' '}
                      ({ind.maxScore} คะแนน)
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>

          {/* 4. Official 3-Party Signature Block */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 pt-8 text-center text-xs">
            <div className="space-y-1.5">
              <div className="border-b border-dotted border-slate-400 h-10 mx-4" />
              <p className="font-semibold text-slate-800">
                ({submission?.teacherName || teacherName || '........................................'})
              </p>
              <p className="text-slate-500">ครูผู้สอน / ผู้ส่งมอบผลการเรียน</p>
              <p className="text-slate-400 text-[11px]">วันที่ ........ / ........ / ........</p>
            </div>
            <div className="space-y-1.5">
              <div className="border-b border-dotted border-slate-400 h-10 mx-4" />
              <p className="font-semibold text-slate-800">
                (........................................)
              </p>
              <p className="text-slate-500">หัวหน้ากลุ่มสาระการเรียนรู้</p>
              <p className="text-slate-400 text-[11px]">วันที่ ........ / ........ / ........</p>
            </div>
            <div className="space-y-1.5">
              <div className="border-b border-dotted border-slate-400 h-10 mx-4" />
              <p className="font-semibold text-slate-800">
                (........................................)
              </p>
              <p className="text-slate-500">
                รองผู้อำนวยการฝ่ายวิชาการ / ผู้อำนวยการ
              </p>
              <p className="text-slate-400 text-[11px]">วันที่ ........ / ........ / ........</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
