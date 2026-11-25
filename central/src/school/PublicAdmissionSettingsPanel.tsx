import { useEffect, useMemo, useState } from 'react';
import {
  CheckCircle2,
  ClipboardList,
  Download,
  FileText,
  Hash,
  Plus,
  Printer,
  RefreshCw,
  Search,
  Settings2,
  ShieldCheck,
  Trash2,
  X,
} from 'lucide-react';
import AdmissionBatchPrintStudio from './AdmissionBatchPrintStudio';
import {
  ADMISSION_STATUS_META,
  bulkUpdateSchoolAdmissions,
  deleteSchoolAdmission,
  fetchSchoolAdmissions,
  parseQuotaNumber,
  updateSchoolAdmission,
  type AdmissionGradeLevel,
  type AdmissionProgramItem,
  type AdmissionRecord,
  type AdmissionStatus,
  type PublicAdmissionConfig,
} from './publicWebAdmissions';

interface PublicAdmissionSettingsPanelProps {
  schoolId: number | null;
  schoolDisplayName?: string;
  admission: PublicAdmissionConfig;
  onChange: (next: PublicAdmissionConfig) => void;
}

const ALL_STATUSES: AdmissionStatus[] = [
  'pending',
  'verified',
  'needs_fix',
  'passed',
  'enrolled',
  'rejected',
];

export default function PublicAdmissionSettingsPanel({
  schoolId,
  schoolDisplayName = 'โรงเรียน',
  admission,
  onChange,
}: PublicAdmissionSettingsPanelProps) {
  const [subTab, setSubTab] = useState<'applicants' | 'batch_print' | 'config'>(
    'applicants',
  );

  // Applicants state
  const [records, setRecords] = useState<AdmissionRecord[]>([]);
  const [loadingRecords, setLoadingRecords] = useState(false);
  const [fromDb, setFromDb] = useState(true);
  const [search, setSearch] = useState('');
  const [gradeFilter, setGradeFilter] = useState<'all' | AdmissionGradeLevel>(
    'all',
  );
  const [programFilter, setProgramFilter] = useState<string>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | AdmissionStatus>(
    'all',
  );
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [batchPrintSelectedIds, setBatchPrintSelectedIds] = useState<
    number[] | undefined
  >(undefined);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [showGuideline, setShowGuideline] = useState(false);

  // Auto-Assign Seat & Room Modal
  const [seatModalOpen, setSeatModalOpen] = useState(false);
  const [bulkRoom, setBulkRoom] = useState('อาคาร 1 ห้อง 112');
  const [bulkSeatPrefix, setBulkSeatPrefix] = useState('101-');
  const [bulkSeatStart, setBulkSeatStart] = useState('1');
  const [bulkExamDate, setBulkExamDate] = useState(
    admission.defaultExamDateLabel,
  );
  const [bulkAlsoApprove, setBulkAlsoApprove] = useState(true);

  const [selected, setSelected] = useState<AdmissionRecord | null>(null);
  const [editStatus, setEditStatus] = useState<AdmissionStatus>('pending');
  const [editNote, setEditNote] = useState('');
  const [editSeatNo, setEditSeatNo] = useState('');
  const [editRoom, setEditRoom] = useState('');
  const [editExamDate, setEditExamDate] = useState('');
  const [savingRecord, setSavingRecord] = useState(false);
  const [actionNotice, setActionNotice] = useState<string | null>(null);

  const loadRecords = async () => {
    setLoadingRecords(true);
    try {
      const res = await fetchSchoolAdmissions(schoolId);
      setRecords(res.rows);
      setFromDb(res.fromDb);
    } finally {
      setLoadingRecords(false);
    }
  };

  useEffect(() => {
    loadRecords();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [schoolId]);

  const counts = useMemo(() => {
    const m1 = records.filter((r) => r.grade_level === 'm1').length;
    const m4 = records.filter((r) => r.grade_level === 'm4').length;
    const pending = records.filter((r) => r.status === 'pending').length;
    const verified = records.filter(
      (r) =>
        r.status === 'verified' ||
        r.status === 'passed' ||
        r.status === 'enrolled',
    ).length;
    return { total: records.length, m1, m4, pending, verified };
  }, [records]);

  const quotaSummary = useMemo(() => {
    const allPrograms = [...admission.programsM1, ...admission.programsM4];
    return allPrograms.map((p) => {
      const applied = records.filter(
        (r) => r.program_id === p.id || r.program_label === p.shortTitle,
      ).length;
      const quota = parseQuotaNumber(p.quotaLabel);
      const pct = quota > 0 ? Math.min(100, Math.round((applied / quota) * 100)) : 0;
      return {
        id: p.id,
        grade: p.grade,
        title: p.shortTitle || p.title,
        applied,
        quota,
        pct,
      };
    });
  }, [admission.programsM1, admission.programsM4, records]);

  const filteredRecords = useMemo(() => {
    const q = search.trim().toLowerCase();
    return records.filter((r) => {
      if (gradeFilter !== 'all' && r.grade_level !== gradeFilter) return false;
      if (programFilter !== 'all' && r.program_id !== programFilter) return false;
      if (statusFilter !== 'all' && r.status !== statusFilter) return false;
      if (!q) return true;
      return (
        r.application_code.toLowerCase().includes(q) ||
        r.full_name.toLowerCase().includes(q) ||
        r.national_id.includes(q) ||
        r.previous_school.toLowerCase().includes(q) ||
        r.program_label.toLowerCase().includes(q)
      );
    });
  }, [records, search, gradeFilter, programFilter, statusFilter]);

  const allFilteredSelected =
    filteredRecords.length > 0 &&
    filteredRecords.every((r) => selectedIds.has(r.id));

  const toggleSelectAllFiltered = () => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (allFilteredSelected) {
        for (const r of filteredRecords) next.delete(r.id);
      } else {
        for (const r of filteredRecords) next.add(r.id);
      }
      return next;
    });
  };

  const toggleSelectOne = (id: number) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleBulkApprove = async () => {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    if (
      !window.confirm(
        `ต้องการอนุมัติเอกสาร (มีสิทธิ์สอบ) ให้ผู้สมัครที่เลือกจำนวน ${ids.length} คน ใช่หรือไม่?`,
      )
    ) {
      return;
    }
    setBulkBusy(true);
    setActionNotice(null);
    try {
      const res = await bulkUpdateSchoolAdmissions(
        schoolId,
        ids.map((id) => ({ id, status: 'verified' })),
      );
      if (res.ok) {
        setRecords((prev) =>
          prev.map((r) =>
            selectedIds.has(r.id) ? { ...r, status: 'verified' } : r,
          ),
        );
        setActionNotice(
          `อนุมัติเอกสาร (มีสิทธิ์สอบ) เรียบร้อยแล้ว ${res.updatedCount} คน`,
        );
        setSelectedIds(new Set());
      } else {
        setActionNotice(res.error || 'อนุมัติแบบกลุ่มไม่สำเร็จ');
      }
    } finally {
      setBulkBusy(false);
    }
  };

  const handleBulkAssignSeats = async () => {
    const targetRecords = records
      .filter((r) => selectedIds.has(r.id))
      .sort((a, b) => a.application_code.localeCompare(b.application_code));
    if (targetRecords.length === 0) return;

    const startNum = Math.max(1, Number(bulkSeatStart) || 1);
    const updates = targetRecords.map((r, idx) => ({
      id: r.id,
      exam_seat_no: `${bulkSeatPrefix}${String(startNum + idx).padStart(3, '0')}`,
      exam_room: bulkRoom.trim() || null,
      exam_date_label: bulkExamDate.trim() || null,
      ...(bulkAlsoApprove ? { status: 'verified' as AdmissionStatus } : {}),
    }));

    setBulkBusy(true);
    setActionNotice(null);
    try {
      const res = await bulkUpdateSchoolAdmissions(schoolId, updates);
      if (res.ok) {
        const updateMap = new Map(updates.map((u) => [u.id, u]));
        setRecords((prev) =>
          prev.map((r) => {
            const u = updateMap.get(r.id);
            if (!u) return r;
            return {
              ...r,
              exam_seat_no: u.exam_seat_no,
              exam_room: u.exam_room,
              exam_date_label: u.exam_date_label,
              status: u.status ?? r.status,
            };
          }),
        );
        setActionNotice(
          `กำหนดห้องสอบและรันเลขที่นั่งสอบอัตโนมัติแล้ว ${res.updatedCount} คน (${updates[0].exam_seat_no} – ${updates[updates.length - 1].exam_seat_no})`,
        );
        setSeatModalOpen(false);
        setSelectedIds(new Set());
      } else {
        setActionNotice(res.error || 'รันเลขที่นั่งสอบไม่สำเร็จ');
      }
    } finally {
      setBulkBusy(false);
    }
  };

  const handleSendSelectedToBatchPrint = () => {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    setBatchPrintSelectedIds(ids);
    setSubTab('batch_print');
  };

  const openEditor = (rec: AdmissionRecord) => {
    setSelected(rec);
    setEditStatus(rec.status);
    setEditNote(rec.status_note ?? '');
    setEditSeatNo(rec.exam_seat_no ?? '');
    setEditRoom(rec.exam_room ?? '');
    setEditExamDate(rec.exam_date_label ?? admission.defaultExamDateLabel);
  };

  const handleSaveRecord = async () => {
    if (!selected) return;
    setSavingRecord(true);
    setActionNotice(null);
    try {
      const res = await updateSchoolAdmission(schoolId, selected.id, {
        status: editStatus,
        status_note: editNote.trim() || null,
        exam_seat_no: editSeatNo.trim() || null,
        exam_room: editRoom.trim() || null,
        exam_date_label: editExamDate.trim() || null,
      });
      if (res.ok) {
        setRecords((prev) =>
          prev.map((r) =>
            r.id === selected.id
              ? {
                  ...r,
                  status: editStatus,
                  status_note: editNote.trim() || null,
                  exam_seat_no: editSeatNo.trim() || null,
                  exam_room: editRoom.trim() || null,
                  exam_date_label: editExamDate.trim() || null,
                }
              : r,
          ),
        );
        setActionNotice(
          `อัปเดตสถานะใบสมัคร ${selected.application_code} เรียบร้อยแล้ว`,
        );
        setSelected(null);
      } else {
        setActionNotice(res.error || 'อัปเดตไม่สำเร็จ');
      }
    } finally {
      setSavingRecord(false);
    }
  };

  const handleDeleteRecord = async (rec: AdmissionRecord) => {
    if (
      !window.confirm(
        `ต้องการลบใบสมัครเลขที่ ${rec.application_code} (${rec.prefix}${rec.full_name}) หรือไม่?`,
      )
    ) {
      return;
    }
    const res = await deleteSchoolAdmission(schoolId, rec.id);
    if (res.ok) {
      setRecords((prev) => prev.filter((r) => r.id !== rec.id));
      if (selected?.id === rec.id) setSelected(null);
      setActionNotice(`ลบใบสมัคร ${rec.application_code} แล้ว`);
    }
  };

  const handleExportCsv = () => {
    const header = [
      'เลขที่ใบสมัคร',
      'ปีการศึกษา',
      'ระดับชั้น',
      'แผนการเรียน',
      'เลขบัตรประชาชน',
      'คำนำหน้า',
      'ชื่อ-นามสกุล',
      'วันเกิด',
      'โรงเรียนเดิม',
      'GPAX',
      'ผู้ปกครอง',
      'ความสัมพันธ์',
      'เบอร์โทร',
      'สถานะ',
      'เลขที่นั่งสอบ',
      'ห้องสอบ',
      'หมายเหตุ',
      'วันที่สมัคร',
    ];
    const esc = (v: unknown) =>
      `"${String(v ?? '').replace(/"/g, '""')}"`;
    const rows = filteredRecords.map((r) => [
      r.application_code,
      r.academic_year,
      r.grade_level === 'm1' ? 'ม.1' : 'ม.4',
      r.program_label,
      `'${r.national_id}`,
      r.prefix,
      r.full_name,
      r.birth_date ?? '',
      r.previous_school,
      r.gpax ?? '',
      r.parent_name,
      r.parent_relation,
      r.parent_phone,
      ADMISSION_STATUS_META[r.status]?.label ?? r.status,
      r.exam_seat_no ?? '',
      r.exam_room ?? '',
      r.status_note ?? '',
      new Date(r.created_at).toLocaleString('th-TH'),
    ]);
    const csv =
      '\uFEFF' +
      [header.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join(
        '\n',
      );
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `admissions_${admission.academicYear}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Config helpers
  const patchConfig = (patch: Partial<PublicAdmissionConfig>) => {
    onChange({ ...admission, ...patch });
  };

  const updateProgram = (
    grade: AdmissionGradeLevel,
    idx: number,
    patch: Partial<AdmissionProgramItem>,
  ) => {
    const key = grade === 'm1' ? 'programsM1' : 'programsM4';
    const nextList = admission[key].map((item, i) =>
      i === idx ? { ...item, ...patch } : item,
    );
    patchConfig({ [key]: nextList });
  };

  const addProgram = (grade: AdmissionGradeLevel) => {
    const key = grade === 'm1' ? 'programsM1' : 'programsM4';
    const newItem: AdmissionProgramItem = {
      id: `${grade}-${Date.now()}`,
      grade,
      title: grade === 'm1' ? 'แผนการเรียนใหม่ (ม.1)' : 'แผนการเรียนใหม่ (ม.4)',
      shortTitle: grade === 'm1' ? 'แผนใหม่ (ม.1)' : 'แผนใหม่ (ม.4)',
      description: 'รายละเอียดหลักสูตรและจุดเด่นของแผนการเรียน',
      quotaLabel: 'รับ 40 คน',
      icon: 'school',
      iconTone: 'primary',
      gpaxLabel: 'เกณฑ์ GPAX',
      gpaxValue: 'GPAX รวม ≥ 2.00',
      examSubjects: 'ไทย, คณิต, วิทย์, อังกฤษ',
      feeLabel: 'ค่าบำรุงการศึกษา',
      feeValue: 'ตามระเบียบสถานศึกษา',
      feeHighlight: true,
      openRangeLabel: `เปิดรับสมัครปีการศึกษา ${admission.academicYear}`,
    };
    patchConfig({ [key]: [...admission[key], newItem] });
  };

  const removeProgram = (grade: AdmissionGradeLevel, idx: number) => {
    const key = grade === 'm1' ? 'programsM1' : 'programsM4';
    patchConfig({ [key]: admission[key].filter((_, i) => i !== idx) });
  };

  return (
    <div className="space-y-5">
      {/* Sub-tab switcher */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-2 shadow-card">
        <div className="flex flex-wrap gap-1.5">
          <button
            type="button"
            onClick={() => setSubTab('applicants')}
            className={`inline-flex items-center gap-2 rounded-xl px-4 py-2 text-xs font-semibold transition-colors ${
              subTab === 'applicants'
                ? 'bg-brand-600 text-white'
                : 'text-slate-600 hover:bg-slate-100'
            }`}
          >
            <ClipboardList className="h-4 w-4" />
            <span>จัดการใบสมัครนักเรียนใหม่ ({counts.total})</span>
          </button>
          <button
            type="button"
            onClick={() => {
              setBatchPrintSelectedIds(undefined);
              setSubTab('batch_print');
            }}
            className={`inline-flex items-center gap-2 rounded-xl px-4 py-2 text-xs font-semibold transition-colors ${
              subTab === 'batch_print'
                ? 'bg-brand-600 text-white'
                : 'text-slate-600 hover:bg-slate-100'
            }`}
          >
            <Printer className="h-4 w-4" />
            <span>พิมพ์บัตรสอบแบบกลุ่ม (A4) ({counts.verified})</span>
          </button>
          <button
            type="button"
            onClick={() => setSubTab('config')}
            className={`inline-flex items-center gap-2 rounded-xl px-4 py-2 text-xs font-semibold transition-colors ${
              subTab === 'config'
                ? 'bg-brand-600 text-white'
                : 'text-slate-600 hover:bg-slate-100'
            }`}
          >
            <Settings2 className="h-4 w-4" />
            <span>ตั้งค่าข้อความ แผนการเรียน และกำหนดการ</span>
          </button>
        </div>

        <label className="inline-flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-slate-700 cursor-pointer">
          <input
            type="checkbox"
            checked={admission.enabled}
            onChange={(e) => patchConfig({ enabled: e.target.checked })}
            className="h-4 w-4 rounded border-slate-300 text-brand-600"
          />
          <span>
            {admission.enabled
              ? 'เปิดรับสมัครออนไลน์อยู่'
              : 'ปิดรับสมัครชั่วคราว'}
          </span>
        </label>
      </div>

      {/* ══════════════════════════════════════════════════════════════════
          SUB-TAB 1: จัดการใบสมัครออนไลน์
         ══════════════════════════════════════════════════════════════════ */}
      {subTab === 'applicants' && (
        <div className="space-y-4">
          {!fromDb && (
            <div className="alert-info text-xs">
              ยังไม่พบตาราง <code>SchoolPublicWebAdmissions</code> ใน Supabase —
              กำลังแสดงข้อมูลชั่วคราวบนเครื่อง กรุณารันไฟล์{' '}
              <code>supabase/school_public_web_admissions.sql</code> เพื่อเก็บใบสมัครบนฐานข้อมูลจริง
            </div>
          )}

          {actionNotice && (
            <div className="alert-ok flex items-center gap-2 text-xs">
              <CheckCircle2 className="h-4 w-4 shrink-0" />
              <span>{actionNotice}</span>
            </div>
          )}

          {/* KPI Summary */}
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
            <div className="card p-4">
              <p className="text-xs text-slate-500">ผู้สมัครทั้งหมด</p>
              <p className="text-2xl font-bold text-ink mt-1 tabular-nums">
                {counts.total}
              </p>
            </div>
            <div className="card p-4">
              <p className="text-xs text-slate-500">สมัคร ม.1</p>
              <p className="text-2xl font-bold text-brand-600 mt-1 tabular-nums">
                {counts.m1}
              </p>
            </div>
            <div className="card p-4">
              <p className="text-xs text-slate-500">สมัคร ม.4</p>
              <p className="text-2xl font-bold text-indigo-600 mt-1 tabular-nums">
                {counts.m4}
              </p>
            </div>
            <div className="card p-4">
              <p className="text-xs text-slate-500">รอตรวจสอบเอกสาร</p>
              <p className="text-2xl font-bold text-amber-600 mt-1 tabular-nums">
                {counts.pending}
              </p>
            </div>
            <div className="card p-4">
              <p className="text-xs text-slate-500">เอกสารสมบูรณ์ / ผ่าน</p>
              <p className="text-2xl font-bold text-emerald-600 mt-1 tabular-nums">
                {counts.verified}
              </p>
            </div>
          </div>

          {/* สรุปยอดโควตารับสมัครรายแผนการเรียน */}
          <div className="card">
            <div className="card-title flex flex-wrap items-center justify-between gap-2">
              <span>สรุปยอดโควตารับสมัครรายแผนการเรียน</span>
              <div className="flex items-center gap-2">
                {programFilter !== 'all' && (
                  <button
                    type="button"
                    onClick={() => setProgramFilter('all')}
                    className="text-xs font-medium text-brand-600 hover:underline"
                  >
                    แสดงทุกแผน
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setShowGuideline((v) => !v)}
                  className="btn-secondary btn-sm"
                >
                  <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
                  <span>
                    {showGuideline ? 'ซ่อนเกณฑ์ตรวจด่วน' : 'เกณฑ์ตรวจสอบด่วน'}
                  </span>
                </button>
              </div>
            </div>
            <div className="card-body space-y-3">
              {showGuideline && (
                <div className="rounded-xl border border-emerald-200 bg-emerald-50/70 p-3.5 text-xs text-emerald-900">
                  <p className="font-bold mb-1.5">
                    เกณฑ์ตรวจสอบเอกสารผู้สมัครด่วน (Verification Guideline)
                  </p>
                  <ul className="grid grid-cols-1 sm:grid-cols-2 gap-1.5 text-emerald-800">
                    <li>1. เลขบัตรประชาชน 13 หลักและชื่อ-สกุล ตรงกับใบ ปพ.1</li>
                    <li>2. เกรดเฉลี่ยสะสม (GPAX) ผ่านเกณฑ์ของแผนการเรียนที่เลือก</li>
                    <li>3. รูปถ่ายชุดนักเรียน 1.5 นิ้ว หน้าตรงชัดเจน ไม่สวมหมวก/แว่นดำ</li>
                    <li>4. ข้อมูลโรงเรียนเดิมและเบอร์โทรผู้ปกครองติดต่อได้จริง</li>
                  </ul>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                {quotaSummary.map((item) => {
                  const isFiltered = programFilter === item.id;
                  const barColor =
                    item.pct >= 100
                      ? 'bg-rose-500'
                      : item.pct >= 80
                        ? 'bg-amber-500'
                        : 'bg-brand-600';
                  return (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() =>
                        setProgramFilter(isFiltered ? 'all' : item.id)
                      }
                      className={`text-left rounded-xl border p-3 transition-all ${
                        isFiltered
                          ? 'border-brand-500 bg-brand-50/50 ring-1 ring-brand-200'
                          : 'border-slate-200 hover:border-slate-300 bg-white'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2 text-xs">
                        <span className="font-semibold text-ink truncate">
                          <span className="mr-1.5 rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-bold text-slate-700">
                            {item.grade === 'm1' ? 'ม.1' : 'ม.4'}
                          </span>
                          {item.title}
                        </span>
                        <span className="font-bold text-brand-700 tabular-nums shrink-0">
                          {item.applied}
                          {item.quota > 0 ? ` / ${item.quota}` : ' คน'}
                        </span>
                      </div>
                      <div className="mt-2 h-2 w-full rounded-full bg-slate-100 overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all ${barColor}`}
                          style={{ width: `${item.pct}%` }}
                        />
                      </div>
                      <div className="mt-1 flex items-center justify-between text-[10px] text-slate-500">
                        <span>
                          {item.quota > 0
                            ? `เต็มแล้ว ${item.pct}%`
                            : 'ไม่จำกัดโควตา'}
                        </span>
                        <span>
                          {isFiltered ? 'กำลังกรองแผนนี้อยู่' : 'คลิกเพื่อกรอง'}
                        </span>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Filter & Actions */}
          <div className="card">
            <div className="card-body space-y-4">
              {selectedIds.size > 0 && (
                <div className="flex flex-wrap items-center justify-between gap-2.5 rounded-xl border border-brand-200 bg-brand-50/80 px-4 py-2.5">
                  <span className="text-xs font-bold text-brand-800">
                    เลือกอยู่ {selectedIds.size} รายการ
                  </span>
                  <div className="flex flex-wrap items-center gap-2">
                    <button
                      type="button"
                      onClick={handleBulkApprove}
                      disabled={bulkBusy}
                      className="btn-primary btn-sm"
                    >
                      <CheckCircle2 className="h-3.5 w-3.5" />
                      <span>อนุมัติเอกสารทั้งหมดที่เลือก</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setSeatModalOpen(true)}
                      disabled={bulkBusy}
                      className="btn-secondary btn-sm"
                    >
                      <Hash className="h-3.5 w-3.5" />
                      <span>จัดห้องสอบ &amp; รันเลขที่นั่งสอบ</span>
                    </button>
                    <button
                      type="button"
                      onClick={handleSendSelectedToBatchPrint}
                      className="btn-secondary btn-sm"
                    >
                      <Printer className="h-3.5 w-3.5" />
                      <span>พิมพ์บัตรสอบที่เลือก ({selectedIds.size})</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setSelectedIds(new Set())}
                      className="text-xs text-slate-500 hover:text-ink px-2 py-1"
                    >
                      ล้างการเลือก
                    </button>
                  </div>
                </div>
              )}

              <div className="flex flex-wrap items-center gap-2.5">
                <div className="relative flex-1 min-w-[220px]">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                  <input
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="ค้นหาเลขที่ใบสมัคร, ชื่อ-สกุล, เลข ปชช., โรงเรียนเดิม..."
                    className="input pl-9"
                  />
                </div>
                <select
                  value={gradeFilter}
                  onChange={(e) =>
                    setGradeFilter(
                      e.target.value as 'all' | AdmissionGradeLevel,
                    )
                  }
                  className="input w-auto"
                >
                  <option value="all">ทุกระดับชั้น</option>
                  <option value="m1">ม.1</option>
                  <option value="m4">ม.4</option>
                </select>
                <select
                  value={statusFilter}
                  onChange={(e) =>
                    setStatusFilter(e.target.value as 'all' | AdmissionStatus)
                  }
                  className="input w-auto"
                >
                  <option value="all">ทุกสถานะ</option>
                  {ALL_STATUSES.map((st) => (
                    <option key={st} value={st}>
                      {ADMISSION_STATUS_META[st].label}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  onClick={loadRecords}
                  disabled={loadingRecords}
                  className="btn-secondary"
                >
                  <RefreshCw
                    className={`h-4 w-4 ${loadingRecords ? 'animate-spin' : ''}`}
                  />
                  รีเฟรช
                </button>
                <button
                  type="button"
                  onClick={handleExportCsv}
                  disabled={filteredRecords.length === 0}
                  className="btn-secondary"
                >
                  <Download className="h-4 w-4" />
                  Export CSV
                </button>
              </div>

              {filteredRecords.length === 0 ? (
                <div className="py-12 text-center text-sm text-slate-500">
                  {loadingRecords
                    ? 'กำลังโหลดรายการใบสมัคร...'
                    : 'ยังไม่มีใบสมัครที่ตรงกับเงื่อนไขการค้นหา'}
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead>
                      <tr className="border-b border-slate-200 text-slate-500">
                        <th className="py-2.5 pr-2 w-8">
                          <input
                            type="checkbox"
                            checked={allFilteredSelected}
                            onChange={toggleSelectAllFiltered}
                            className="checkbox"
                            aria-label="เลือกผู้สมัครทั้งหมดในหน้านี้"
                          />
                        </th>
                        <th className="py-2.5 pr-3 font-semibold">เลขที่ใบสมัคร</th>
                        <th className="py-2.5 px-3 font-semibold">ผู้สมัคร</th>
                        <th className="py-2.5 px-3 font-semibold">
                          ระดับชั้น / แผนการเรียน
                        </th>
                        <th className="py-2.5 px-3 font-semibold">
                          โรงเรียนเดิม / GPAX
                        </th>
                        <th className="py-2.5 px-3 font-semibold">ผู้ปกครอง</th>
                        <th className="py-2.5 px-3 font-semibold">
                          สถานะ / ห้องสอบ
                        </th>
                        <th className="py-2.5 pl-3 text-right font-semibold">
                          จัดการ
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {filteredRecords.map((r) => (
                        <tr
                          key={r.id}
                          className={`hover:bg-slate-50/80 ${
                            selectedIds.has(r.id) ? 'bg-brand-50/30' : ''
                          }`}
                        >
                          <td className="py-3 pr-2">
                            <input
                              type="checkbox"
                              checked={selectedIds.has(r.id)}
                              onChange={() => toggleSelectOne(r.id)}
                              className="checkbox"
                              aria-label={`เลือก ${r.full_name}`}
                            />
                          </td>
                          <td className="py-3 pr-3 font-semibold text-brand-700 whitespace-nowrap">
                            <div>{r.application_code}</div>
                            <div className="text-[11px] font-normal text-slate-400">
                              {new Date(r.created_at).toLocaleDateString(
                                'th-TH',
                              )}
                            </div>
                          </td>
                          <td className="py-3 px-3">
                            <div className="font-semibold text-ink">
                              {r.prefix}
                              {r.full_name}
                            </div>
                            <div className="text-[11px] text-slate-500 tabular-nums">
                              ปชช. {r.national_id}
                            </div>
                          </td>
                          <td className="py-3 px-3">
                            <span className="inline-block rounded bg-slate-100 px-1.5 py-0.5 font-semibold text-slate-700 mr-1.5">
                              {r.grade_level === 'm1' ? 'ม.1' : 'ม.4'}
                            </span>
                            <span className="text-slate-700">
                              {r.program_label}
                            </span>
                          </td>
                          <td className="py-3 px-3">
                            <div className="text-slate-700">
                              {r.previous_school}
                            </div>
                            <div className="text-[11px] text-slate-500">
                              GPAX:{' '}
                              {r.gpax != null ? Number(r.gpax).toFixed(2) : '-'}
                            </div>
                          </td>
                          <td className="py-3 px-3">
                            <div className="text-slate-700">
                              {r.parent_name} ({r.parent_relation})
                            </div>
                            <div className="text-[11px] text-slate-500">
                              {r.parent_phone}
                            </div>
                          </td>
                          <td className="py-3 px-3">
                            <span
                              className={`inline-block rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${
                                ADMISSION_STATUS_META[r.status]?.badgeClass ||
                                'bg-slate-100 text-slate-700'
                              }`}
                            >
                              {ADMISSION_STATUS_META[r.status]?.label ||
                                r.status}
                            </span>
                            {(r.exam_seat_no || r.exam_room) && (
                              <div className="text-[11px] text-slate-500 mt-1">
                                ที่นั่ง: {r.exam_seat_no || '-'} •{' '}
                                {r.exam_room || '-'}
                              </div>
                            )}
                          </td>
                          <td className="py-3 pl-3 text-right whitespace-nowrap space-x-1.5">
                            <button
                              type="button"
                              onClick={() => openEditor(r)}
                              className="btn-secondary btn-sm"
                            >
                              ตรวจสอบ / จัดห้องสอบ
                            </button>
                            <button
                              type="button"
                              onClick={() => handleDeleteRecord(r)}
                              className="inline-flex items-center justify-center rounded-lg border border-rose-200 p-1.5 text-rose-600 hover:bg-rose-50"
                              title="ลบใบสมัคร"
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ══════════════════════════════════════════════════════════════════
          SUB-TAB 2: พิมพ์บัตรประจำตัวสอบแบบกลุ่ม (Batch Print Studio 2 ใบ/A4)
         ══════════════════════════════════════════════════════════════════ */}
      {subTab === 'batch_print' && (
        <AdmissionBatchPrintStudio
          schoolDisplayName={schoolDisplayName}
          admission={admission}
          records={records}
          initialSelectedIds={batchPrintSelectedIds}
        />
      )}

      {/* ══════════════════════════════════════════════════════════════════
          SUB-TAB 3: ตั้งค่าหน้ารับสมัคร (ข้อความ / แผนการเรียน / กำหนดการ / PDF / FAQ)
         ══════════════════════════════════════════════════════════════════ */}
      {subTab === 'config' && (
        <div className="space-y-5">
          {/* Basic Banner & Period */}
          <div className="card">
            <div className="card-title">
              <span>ข้อมูลทั่วไปและแบนเนอร์หน้ารับสมัคร</span>
            </div>
            <div className="card-body grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="label">ปีการศึกษาที่เปิดรับสมัคร</label>
                <input
                  className="input"
                  value={admission.academicYear}
                  onChange={(e) =>
                    patchConfig({ academicYear: e.target.value })
                  }
                  placeholder="2568"
                />
              </div>
              <div>
                <label className="label">
                  รหัสขึ้นต้นเลขที่ใบสมัคร (เช่น RBP → RBP-68-00001)
                </label>
                <input
                  className="input"
                  value={admission.codePrefix}
                  onChange={(e) => patchConfig({ codePrefix: e.target.value })}
                  placeholder="RBP"
                />
              </div>
              <div>
                <label className="label">ป้ายช่วงเวลารับสมัคร</label>
                <input
                  className="input"
                  value={admission.openPeriodBadge}
                  onChange={(e) =>
                    patchConfig({ openPeriodBadge: e.target.value })
                  }
                />
              </div>
              <div>
                <label className="label">วันและเวลาสอบค่าเริ่มต้น (บนบัตรสอบ)</label>
                <input
                  className="input"
                  value={admission.defaultExamDateLabel}
                  onChange={(e) =>
                    patchConfig({ defaultExamDateLabel: e.target.value })
                  }
                />
              </div>
              <div className="md:col-span-2">
                <label className="label">ข้อความแนะนำใต้หัวข้อ</label>
                <textarea
                  className="input min-h-[72px]"
                  value={admission.heroDescription}
                  onChange={(e) =>
                    patchConfig({ heroDescription: e.target.value })
                  }
                />
              </div>
              <div className="md:col-span-2">
                <label className="label">ลิงก์รูปภาพแบนเนอร์ (URL)</label>
                <input
                  className="input"
                  value={admission.heroImageUrl}
                  onChange={(e) =>
                    patchConfig({ heroImageUrl: e.target.value })
                  }
                />
              </div>
              <div>
                <label className="label">สรุปจำนวนรับ ม.1</label>
                <input
                  className="input"
                  value={admission.m1QuickInfoQuota}
                  onChange={(e) =>
                    patchConfig({ m1QuickInfoQuota: e.target.value })
                  }
                />
              </div>
              <div>
                <label className="label">สรุปจำนวนรับ ม.4</label>
                <input
                  className="input"
                  value={admission.m4QuickInfoQuota}
                  onChange={(e) =>
                    patchConfig({ m4QuickInfoQuota: e.target.value })
                  }
                />
              </div>
            </div>
          </div>

          {/* Programs M.1 & M.4 */}
          {(['m1', 'm4'] as AdmissionGradeLevel[]).map((grade) => {
            const list =
              grade === 'm1' ? admission.programsM1 : admission.programsM4;
            return (
              <div key={grade} className="card">
                <div className="card-title flex items-center justify-between">
                  <span>
                    แผนการเรียนที่เปิดรับ —{' '}
                    {grade === 'm1' ? 'ชั้น ม.1' : 'ชั้น ม.4'} ({list.length}{' '}
                    แผน)
                  </span>
                  <button
                    type="button"
                    onClick={() => addProgram(grade)}
                    className="btn-secondary btn-sm"
                  >
                    <Plus className="h-3.5 w-3.5" />
                    เพิ่มแผนการเรียน
                  </button>
                </div>
                <div className="card-body space-y-4">
                  {list.map((p, idx) => (
                    <div
                      key={p.id}
                      className="rounded-xl border border-slate-200 p-4 space-y-3 bg-slate-50/50"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="text-xs font-semibold text-brand-700">
                          แผนที่ {idx + 1}
                        </span>
                        {list.length > 1 && (
                          <button
                            type="button"
                            onClick={() => removeProgram(grade, idx)}
                            className="text-xs text-rose-600 hover:underline inline-flex items-center gap-1"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                            ลบแผนนี้
                          </button>
                        )}
                      </div>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                        <div className="md:col-span-2">
                          <label className="label">ชื่อแผนการเรียนเต็ม</label>
                          <input
                            className="input"
                            value={p.title}
                            onChange={(e) =>
                              updateProgram(grade, idx, {
                                title: e.target.value,
                                shortTitle: e.target.value,
                              })
                            }
                          />
                        </div>
                        <div>
                          <label className="label">จำนวนที่รับ</label>
                          <input
                            className="input"
                            value={p.quotaLabel}
                            onChange={(e) =>
                              updateProgram(grade, idx, {
                                quotaLabel: e.target.value,
                              })
                            }
                          />
                        </div>
                        <div className="md:col-span-3">
                          <label className="label">คำอธิบายแผนการเรียน</label>
                          <input
                            className="input"
                            value={p.description}
                            onChange={(e) =>
                              updateProgram(grade, idx, {
                                description: e.target.value,
                              })
                            }
                          />
                        </div>
                        <div>
                          <label className="label">เกณฑ์ GPAX / คุณสมบัติ</label>
                          <input
                            className="input"
                            value={p.gpaxValue}
                            onChange={(e) =>
                              updateProgram(grade, idx, {
                                gpaxValue: e.target.value,
                              })
                            }
                          />
                        </div>
                        <div>
                          <label className="label">วิชาที่ใช้สอบ</label>
                          <input
                            className="input"
                            value={p.examSubjects}
                            onChange={(e) =>
                              updateProgram(grade, idx, {
                                examSubjects: e.target.value,
                              })
                            }
                          />
                        </div>
                        <div>
                          <label className="label">ค่าบำรุงการศึกษา</label>
                          <input
                            className="input"
                            value={p.feeValue}
                            onChange={(e) =>
                              updateProgram(grade, idx, {
                                feeValue: e.target.value,
                              })
                            }
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}

          {/* Timeline 5 Steps */}
          <div className="card">
            <div className="card-title">
              <span>กำหนดการรับสมัครและคัดเลือก (5 ขั้นตอน)</span>
            </div>
            <div className="card-body grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              {admission.timeline.map((step, idx) => (
                <div
                  key={step.step}
                  className="rounded-xl border border-slate-200 p-3.5 space-y-2"
                >
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-brand-700">
                      ขั้นที่ {step.step}
                    </span>
                    <label className="inline-flex items-center gap-1.5 text-[11px] text-slate-600 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={Boolean(step.isCurrent)}
                        onChange={(e) => {
                          const next = admission.timeline.map((s, i) =>
                            i === idx
                              ? { ...s, isCurrent: e.target.checked }
                              : s,
                          );
                          patchConfig({ timeline: next });
                        }}
                      />
                      กำลังดำเนินการ
                    </label>
                  </div>
                  <input
                    className="input text-xs"
                    value={step.title}
                    onChange={(e) => {
                      const next = admission.timeline.map((s, i) =>
                        i === idx ? { ...s, title: e.target.value } : s,
                      );
                      patchConfig({ timeline: next });
                    }}
                    placeholder="ชื่อขั้นตอน"
                  />
                  <input
                    className="input text-xs"
                    value={step.dateLabel}
                    onChange={(e) => {
                      const next = admission.timeline.map((s, i) =>
                        i === idx ? { ...s, dateLabel: e.target.value } : s,
                      );
                      patchConfig({ timeline: next });
                    }}
                    placeholder="วันที่"
                  />
                  <input
                    className="input text-xs"
                    value={step.description}
                    onChange={(e) => {
                      const next = admission.timeline.map((s, i) =>
                        i === idx ? { ...s, description: e.target.value } : s,
                      );
                      patchConfig({ timeline: next });
                    }}
                    placeholder="คำอธิบายสั้นๆ"
                  />
                </div>
              ))}
            </div>
          </div>

          {/* Downloadable PDFs */}
          <div className="card">
            <div className="card-title flex items-center justify-between">
              <span>เอกสารและแบบฟอร์มให้ดาวน์โหลด (PDF / Google Drive)</span>
              <button
                type="button"
                onClick={() =>
                  patchConfig({
                    downloads: [
                      ...admission.downloads,
                      {
                        id: `dl-${Date.now()}`,
                        title: 'เอกสารใหม่',
                        meta: 'PDF',
                        icon: 'picture_as_pdf',
                        iconTone: 'primary',
                        url: '',
                      },
                    ],
                  })
                }
                className="btn-secondary btn-sm"
              >
                <Plus className="h-3.5 w-3.5" />
                เพิ่มเอกสาร
              </button>
            </div>
            <div className="card-body space-y-3">
              {admission.downloads.map((dl, idx) => (
                <div
                  key={dl.id}
                  className="grid grid-cols-1 md:grid-cols-12 gap-2.5 items-center rounded-xl border border-slate-200 p-3"
                >
                  <div className="md:col-span-5">
                    <label className="label">ชื่อเอกสาร</label>
                    <input
                      className="input"
                      value={dl.title}
                      onChange={(e) => {
                        const next = admission.downloads.map((item, i) =>
                          i === idx ? { ...item, title: e.target.value } : item,
                        );
                        patchConfig({ downloads: next });
                      }}
                    />
                  </div>
                  <div className="md:col-span-3">
                    <label className="label">รายละเอียดขนาด/วันที่</label>
                    <input
                      className="input"
                      value={dl.meta}
                      onChange={(e) => {
                        const next = admission.downloads.map((item, i) =>
                          i === idx ? { ...item, meta: e.target.value } : item,
                        );
                        patchConfig({ downloads: next });
                      }}
                    />
                  </div>
                  <div className="md:col-span-3">
                    <label className="label">ลิงก์ดาวน์โหลด (URL)</label>
                    <input
                      className="input"
                      value={dl.url}
                      placeholder="https://drive.google.com/..."
                      onChange={(e) => {
                        const next = admission.downloads.map((item, i) =>
                          i === idx ? { ...item, url: e.target.value } : item,
                        );
                        patchConfig({ downloads: next });
                      }}
                    />
                  </div>
                  <div className="md:col-span-1 flex justify-end pt-5">
                    <button
                      type="button"
                      onClick={() =>
                        patchConfig({
                          downloads: admission.downloads.filter(
                            (_, i) => i !== idx,
                          ),
                        })
                      }
                      className="text-rose-600 hover:bg-rose-50 p-2 rounded-lg"
                      title="ลบเอกสาร"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Helpdesk Contact */}
          <div className="card">
            <div className="card-title">
              <span>ศูนย์ประสานงานรับสมัครนักเรียน</span>
            </div>
            <div className="card-body grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="label">โทรศัพท์สายตรงฝ่ายทะเบียน</label>
                <input
                  className="input"
                  value={admission.helpdeskPhone}
                  onChange={(e) =>
                    patchConfig({ helpdeskPhone: e.target.value })
                  }
                />
              </div>
              <div>
                <label className="label">LINE Official สำหรับรับสมัคร</label>
                <input
                  className="input"
                  value={admission.helpdeskLine}
                  onChange={(e) =>
                    patchConfig({ helpdeskLine: e.target.value })
                  }
                />
              </div>
              <div>
                <label className="label">สถานที่ตั้ง</label>
                <input
                  className="input"
                  value={admission.helpdeskAddress}
                  onChange={(e) =>
                    patchConfig({ helpdeskAddress: e.target.value })
                  }
                />
              </div>
              <div>
                <label className="label">เวลาทำการ</label>
                <input
                  className="input"
                  value={admission.helpdeskHours}
                  onChange={(e) =>
                    patchConfig({ helpdeskHours: e.target.value })
                  }
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ══════════════════════════════════════════════════════════════════
          MODAL: ตรวจสอบใบสมัคร & กำหนดห้องสอบ
         ══════════════════════════════════════════════════════════════════ */}
      {selected && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/50 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto"
          onClick={() => setSelected(null)}
        >
          <div
            className="w-full max-w-2xl rounded-2xl bg-white shadow-2xl border border-slate-200 overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-6 py-4">
              <div>
                <h3 className="text-base font-bold text-ink">
                  ตรวจสอบใบสมัคร {selected.application_code}
                </h3>
                <p className="text-xs text-slate-500">
                  {selected.prefix}
                  {selected.full_name} •{' '}
                  {selected.grade_level === 'm1' ? 'ม.1' : 'ม.4'}{' '}
                  {selected.program_label}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setSelected(null)}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="p-6 space-y-5 max-h-[75vh] overflow-y-auto">
              {/* Applicant details */}
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 rounded-xl bg-slate-50 p-4 text-xs">
                <div>
                  <span className="text-slate-500 block">เลขบัตรประชาชน</span>
                  <span className="font-semibold text-ink tabular-nums">
                    {selected.national_id}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block">วันเกิด</span>
                  <span className="font-semibold text-ink">
                    {selected.birth_date || '-'}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block">GPAX</span>
                  <span className="font-semibold text-ink">
                    {selected.gpax != null
                      ? Number(selected.gpax).toFixed(2)
                      : '-'}
                  </span>
                </div>
                <div className="col-span-2">
                  <span className="text-slate-500 block">โรงเรียนเดิม</span>
                  <span className="font-semibold text-ink">
                    {selected.previous_school}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block">ผู้ปกครอง</span>
                  <span className="font-semibold text-ink">
                    {selected.parent_name} ({selected.parent_relation}) —{' '}
                    {selected.parent_phone}
                  </span>
                </div>
              </div>

              {/* Uploaded files */}
              <div>
                <p className="text-xs font-semibold text-slate-700 mb-2 flex items-center gap-1.5">
                  <FileText className="h-3.5 w-3.5" />
                  เอกสารที่แนบมาในระบบ
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 text-xs">
                  {[
                    {
                      label: 'ปพ.1',
                      name: selected.doc_transcript_name,
                      data: selected.doc_transcript_data,
                    },
                    {
                      label: 'รูปถ่าย 1.5 นิ้ว',
                      name: selected.doc_photo_name,
                      data: selected.doc_photo_data,
                    },
                    {
                      label: 'ทะเบียนบ้าน',
                      name: selected.doc_house_reg_name,
                      data: selected.doc_house_reg_data,
                    },
                  ].map((doc) => (
                    <div
                      key={doc.label}
                      className="rounded-xl border border-slate-200 p-3 flex flex-col justify-between gap-2"
                    >
                      <div>
                        <span className="font-semibold text-ink block">
                          {doc.label}
                        </span>
                        <span className="text-[11px] text-slate-500 break-all">
                          {doc.name || 'ยังไม่ได้แนบไฟล์'}
                        </span>
                      </div>
                      {doc.data && (
                        <a
                          href={doc.data}
                          download={doc.name || `${doc.label}.file`}
                          className="text-[11px] font-semibold text-brand-600 hover:underline"
                        >
                          เปิด/ดาวน์โหลดไฟล์ที่แนบ
                        </a>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Status & Exam Seat Assignment */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="label">สถานะการสมัคร</label>
                  <select
                    className="input"
                    value={editStatus}
                    onChange={(e) =>
                      setEditStatus(e.target.value as AdmissionStatus)
                    }
                  >
                    {ALL_STATUSES.map((st) => (
                      <option key={st} value={st}>
                        {ADMISSION_STATUS_META[st].label}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="label">เลขที่นั่งสอบ</label>
                  <input
                    className="input"
                    value={editSeatNo}
                    onChange={(e) => setEditSeatNo(e.target.value)}
                    placeholder="เช่น 101-001"
                  />
                </div>
                <div>
                  <label className="label">อาคาร / ห้องสอบ</label>
                  <input
                    className="input"
                    value={editRoom}
                    onChange={(e) => setEditRoom(e.target.value)}
                    placeholder="เช่น อาคาร 1 ห้อง 112"
                  />
                </div>
                <div>
                  <label className="label">วันและเวลาสอบ</label>
                  <input
                    className="input"
                    value={editExamDate}
                    onChange={(e) => setEditExamDate(e.target.value)}
                    placeholder="30 พ.ค. 2568 เวลา 08.30 - 15.30 น."
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="label">
                    หมายเหตุถึงผู้สมัคร (แสดงในหน้าตรวจสอบสถานะ)
                  </label>
                  <textarea
                    className="input min-h-[68px]"
                    value={editNote}
                    onChange={(e) => setEditNote(e.target.value)}
                    placeholder="เช่น เอกสารครบถ้วนแล้ว สามารถพิมพ์บัตรสอบได้ หรือ กรุณานำ ปพ.1 ตัวจริงมาแสดงในวันสอบ"
                  />
                </div>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2.5 border-t border-slate-200 bg-slate-50 px-6 py-3.5">
              <button
                type="button"
                onClick={() => setSelected(null)}
                className="btn-secondary"
              >
                ยกเลิก
              </button>
              <button
                type="button"
                onClick={handleSaveRecord}
                disabled={savingRecord}
                className="btn-primary"
              >
                {savingRecord ? 'กำลังบันทึก...' : 'บันทึกผลการตรวจสอบ'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ══════════════════════════════════════════════════════════════════
          MODAL: จัดห้องสอบ & รันเลขที่นั่งสอบอัตโนมัติแบบกลุ่ม
         ══════════════════════════════════════════════════════════════════ */}
      {seatModalOpen && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/50 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setSeatModalOpen(false)}
        >
          <div
            className="w-full max-w-lg rounded-2xl bg-white shadow-2xl border border-slate-200 overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-6 py-4">
              <div>
                <h3 className="text-base font-bold text-ink">
                  จัดห้องสอบ &amp; รันเลขที่นั่งสอบอัตโนมัติ
                </h3>
                <p className="text-xs text-slate-500">
                  จะกำหนดให้ผู้สมัครที่เลือกไว้จำนวน {selectedIds.size} คน
                  เรียงตามเลขที่ใบสมัคร
                </p>
              </div>
              <button
                type="button"
                onClick={() => setSeatModalOpen(false)}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div>
                <label className="label">อาคาร / ห้องสอบ</label>
                <input
                  className="input"
                  value={bulkRoom}
                  onChange={(e) => setBulkRoom(e.target.value)}
                  placeholder="เช่น อาคาร 1 ห้อง 112"
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="label">รหัสขึ้นต้นเลขที่นั่ง</label>
                  <input
                    className="input"
                    value={bulkSeatPrefix}
                    onChange={(e) => setBulkSeatPrefix(e.target.value)}
                    placeholder="เช่น 101-"
                  />
                </div>
                <div>
                  <label className="label">เริ่มรันจากเลขที่</label>
                  <input
                    type="number"
                    min={1}
                    className="input"
                    value={bulkSeatStart}
                    onChange={(e) => setBulkSeatStart(e.target.value)}
                  />
                </div>
              </div>
              <p className="text-xs text-brand-700 bg-brand-50 rounded-lg px-3 py-2">
                ตัวอย่างเลขที่นั่งที่จะได้:{' '}
                <strong>
                  {bulkSeatPrefix}
                  {String(Math.max(1, Number(bulkSeatStart) || 1)).padStart(
                    3,
                    '0',
                  )}
                </strong>{' '}
                ถึง{' '}
                <strong>
                  {bulkSeatPrefix}
                  {String(
                    Math.max(1, Number(bulkSeatStart) || 1) +
                      Math.max(0, selectedIds.size - 1),
                  ).padStart(3, '0')}
                </strong>
              </p>
              <div>
                <label className="label">วันและเวลาสอบ</label>
                <input
                  className="input"
                  value={bulkExamDate}
                  onChange={(e) => setBulkExamDate(e.target.value)}
                />
              </div>
              <label className="inline-flex items-center gap-2 text-xs text-slate-700 cursor-pointer">
                <input
                  type="checkbox"
                  checked={bulkAlsoApprove}
                  onChange={(e) => setBulkAlsoApprove(e.target.checked)}
                  className="checkbox"
                />
                <span>
                  เปลี่ยนสถานะเป็น &ldquo;เอกสารสมบูรณ์ (มีสิทธิ์สอบ)&rdquo; พร้อมกันด้วย
                </span>
              </label>
            </div>

            <div className="flex items-center justify-end gap-2.5 border-t border-slate-200 bg-slate-50 px-6 py-3.5">
              <button
                type="button"
                onClick={() => setSeatModalOpen(false)}
                className="btn-secondary"
              >
                ยกเลิก
              </button>
              <button
                type="button"
                onClick={handleBulkAssignSeats}
                disabled={bulkBusy}
                className="btn-primary"
              >
                {bulkBusy
                  ? 'กำลังบันทึก...'
                  : `ยืนยันจัดห้องสอบ (${selectedIds.size} คน)`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
