import { useEffect, useMemo, useState } from 'react';
import {
  CheckSquare,
  Printer,
  Scissors,
  Search,
  Square,
  User,
} from 'lucide-react';
import {
  ADMISSION_STATUS_META,
  type AdmissionGradeLevel,
  type AdmissionRecord,
  type PublicAdmissionConfig,
} from './publicWebAdmissions';

interface AdmissionBatchPrintStudioProps {
  schoolDisplayName: string;
  admission: PublicAdmissionConfig;
  records: AdmissionRecord[];
  initialSelectedIds?: number[];
}

export default function AdmissionBatchPrintStudio({
  schoolDisplayName,
  admission,
  records,
  initialSelectedIds,
}: AdmissionBatchPrintStudioProps) {
  const [gradeFilter, setGradeFilter] = useState<'all' | AdmissionGradeLevel>(
    'all',
  );
  const [approvedOnly, setApprovedOnly] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<number>>(() => {
    if (initialSelectedIds && initialSelectedIds.length > 0) {
      return new Set(initialSelectedIds);
    }
    return new Set(
      records
        .filter((r) => ADMISSION_STATUS_META[r.status]?.canPrintAdmitCard)
        .map((r) => r.id),
    );
  });

  // Sync if caller passes a new explicit selection from the applicant table
  useEffect(() => {
    if (initialSelectedIds && initialSelectedIds.length > 0) {
      setSelectedIds(new Set(initialSelectedIds));
      setApprovedOnly(false);
    }
  }, [initialSelectedIds]);

  const queueCandidates = useMemo(() => {
    const q = search.trim().toLowerCase();
    return records.filter((r) => {
      if (
        approvedOnly &&
        !ADMISSION_STATUS_META[r.status]?.canPrintAdmitCard
      ) {
        return false;
      }
      if (gradeFilter !== 'all' && r.grade_level !== gradeFilter) return false;
      if (!q) return true;
      return (
        r.application_code.toLowerCase().includes(q) ||
        r.full_name.toLowerCase().includes(q) ||
        r.national_id.includes(q) ||
        (r.exam_seat_no ?? '').toLowerCase().includes(q) ||
        (r.exam_room ?? '').toLowerCase().includes(q)
      );
    });
  }, [records, approvedOnly, gradeFilter, search]);

  const printableList = useMemo(
    () => queueCandidates.filter((r) => selectedIds.has(r.id)),
    [queueCandidates, selectedIds],
  );

  // Pair into 2 cards per A4 sheet
  const sheets = useMemo(() => {
    const pairs: AdmissionRecord[][] = [];
    for (let i = 0; i < printableList.length; i += 2) {
      pairs.push(printableList.slice(i, i + 2));
    }
    return pairs;
  }, [printableList]);

  const toggleOne = (id: number) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const selectAllVisible = () => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      for (const r of queueCandidates) next.add(r.id);
      return next;
    });
  };

  const clearAllVisible = () => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      for (const r of queueCandidates) next.delete(r.id);
      return next;
    });
  };

  const handlePrintBatch = () => {
    if (printableList.length === 0) return;
    document.body.classList.add('printing-admission-batch');
    const cleanup = () => {
      document.body.classList.remove('printing-admission-batch');
      window.removeEventListener('afterprint', cleanup);
    };
    window.addEventListener('afterprint', cleanup);
    window.print();
    // Fallback cleanup in case afterprint doesn't fire in some browsers
    setTimeout(cleanup, 1500);
  };

  return (
    <div className="space-y-4">
      {/* Top Action Bar */}
      <div className="card">
        <div className="card-body flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 className="text-sm font-bold text-ink">
              พิมพ์บัตรประจำตัวสอบแบบกลุ่ม (จัดหน้า 2 ใบ / 1 แผ่น A4)
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              เลือกผู้สมัครจากคิวด้านซ้าย แล้วกดสั่งพิมพ์หรือบันทึกเป็น PDF ได้ทันที
              (ระบบแบ่งหน้า A4 และซ่อนเมนูหลังบ้านให้อัตโนมัติ)
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2.5">
            <span className="rounded-xl bg-brand-50 px-3 py-1.5 text-xs font-semibold text-brand-700 tabular-nums">
              เลือกพิมพ์ {printableList.length} คน • {sheets.length} แผ่น A4
            </span>
            <button
              type="button"
              onClick={handlePrintBatch}
              disabled={printableList.length === 0}
              className="btn-primary"
            >
              <Printer className="h-4 w-4" />
              <span>สั่งพิมพ์ / บันทึก PDF ({sheets.length} แผ่น)</span>
            </button>
          </div>
        </div>
      </div>

      {/* Main Split Workspace */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
        {/* Left: Print Queue */}
        <div className="lg:col-span-4 card overflow-hidden">
          <div className="border-b border-slate-200 bg-slate-50/70 p-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-ink">
                คิวพิมพ์รายชื่อ ({queueCandidates.length} คน)
              </span>
              <div className="flex items-center gap-2 text-[11px]">
                <button
                  type="button"
                  onClick={selectAllVisible}
                  className="font-semibold text-brand-600 hover:underline"
                >
                  เลือกทั้งหมด
                </button>
                <span className="text-slate-300">|</span>
                <button
                  type="button"
                  onClick={clearAllVisible}
                  className="text-slate-500 hover:underline"
                >
                  ล้าง
                </button>
              </div>
            </div>

            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="ค้นหาชื่อ, เลขที่ใบสมัคร, ห้องสอบ..."
                className="input pl-8 py-1.5 text-xs"
              />
            </div>

            <div className="flex items-center justify-between gap-2">
              <select
                value={gradeFilter}
                onChange={(e) =>
                  setGradeFilter(e.target.value as 'all' | AdmissionGradeLevel)
                }
                className="input w-auto py-1 text-xs"
              >
                <option value="all">ทุกระดับชั้น</option>
                <option value="m1">ม.1</option>
                <option value="m4">ม.4</option>
              </select>

              <label className="inline-flex items-center gap-1.5 text-[11px] text-slate-600 cursor-pointer">
                <input
                  type="checkbox"
                  checked={approvedOnly}
                  onChange={(e) => setApprovedOnly(e.target.checked)}
                  className="checkbox h-3.5 w-3.5"
                />
                <span>เฉพาะผ่านอนุมัติแล้ว</span>
              </label>
            </div>
          </div>

          <div className="max-h-[640px] overflow-y-auto divide-y divide-slate-100">
            {queueCandidates.length === 0 ? (
              <div className="p-8 text-center text-xs text-slate-500">
                ไม่พบรายชื่อในคิวพิมพ์ (ลองปิดตัวกรอง &ldquo;เฉพาะผ่านอนุมัติแล้ว&rdquo;
                หรืออนุมัติเอกสารผู้สมัครก่อน)
              </div>
            ) : (
              queueCandidates.map((r) => {
                const checked = selectedIds.has(r.id);
                return (
                  <button
                    key={r.id}
                    type="button"
                    onClick={() => toggleOne(r.id)}
                    className={`w-full text-left px-4 py-3 flex items-start gap-3 transition-colors ${
                      checked ? 'bg-brand-50/40' : 'hover:bg-slate-50'
                    }`}
                  >
                    {checked ? (
                      <CheckSquare className="h-4 w-4 text-brand-600 shrink-0 mt-0.5" />
                    ) : (
                      <Square className="h-4 w-4 text-slate-300 shrink-0 mt-0.5" />
                    )}
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between gap-2">
                        <span className="text-xs font-semibold text-ink truncate">
                          {r.prefix}
                          {r.full_name}
                        </span>
                        <span className="text-[10px] font-bold text-brand-700 shrink-0">
                          {r.grade_level === 'm1' ? 'ม.1' : 'ม.4'}
                        </span>
                      </div>
                      <div className="text-[11px] text-slate-500 truncate mt-0.5">
                        {r.application_code} • {r.program_label}
                      </div>
                      <div className="text-[10px] text-slate-400 mt-0.5">
                        ที่นั่ง: {r.exam_seat_no || 'ยังไม่กำหนด'} • ห้อง:{' '}
                        {r.exam_room || 'ยังไม่กำหนด'}
                      </div>
                    </div>
                  </button>
                );
              })
            )}
          </div>
        </div>

        {/* Right: Print Sheet Preview (2 cards per A4 sheet) */}
        <div className="lg:col-span-8 space-y-4">
          <div className="flex items-center justify-between px-1">
            <span className="text-xs font-bold text-slate-700">
              ตัวอย่างหน้าพิมพ์จริง (Print Sheet Preview — A4 Portrait)
            </span>
            <span className="text-xs text-slate-500">
              แสดง {sheets.length} แผ่น
            </span>
          </div>

          {sheets.length === 0 ? (
            <div className="card p-12 text-center text-sm text-slate-500">
              กรุณาติ๊กเลือกรายชื่อผู้สมัครจากคิวด้านซ้ายอย่างน้อย 1 คน
              เพื่อดูตัวอย่างหน้าพิมพ์ A4
            </div>
          ) : (
            <div className="admission-batch-print-area space-y-6">
              {sheets.map((pair, sheetIdx) => (
                <div
                  key={sheetIdx}
                  className="admission-a4-sheet bg-white rounded-2xl border border-slate-200 shadow-card p-6 space-y-5"
                >
                  <div className="flex items-center justify-between text-[11px] text-slate-400 print:hidden">
                    <span>
                      แผ่นที่ {sheetIdx + 1} / {sheets.length} (A4)
                    </span>
                    <span>
                      บัตรที่ {sheetIdx * 2 + 1}
                      {pair.length > 1 ? ` – ${sheetIdx * 2 + 2}` : ''}
                    </span>
                  </div>

                  {pair.map((app, cardIdx) => (
                    <div key={app.id}>
                      <div className="rounded-xl border-2 border-slate-800 overflow-hidden bg-white">
                        {/* Card Header */}
                        <div className="bg-slate-900 text-white px-5 py-3 flex items-center justify-between print:bg-slate-100 print:text-slate-900 print:border-b-2 print:border-slate-800">
                          <div>
                            <p className="text-[10px] uppercase tracking-wider opacity-80">
                              บัตรประจำตัวผู้เข้าสอบคัดเลือก • ปีการศึกษา{' '}
                              {app.academic_year}
                            </p>
                            <h4 className="text-sm font-bold leading-snug">
                              {schoolDisplayName}
                            </h4>
                          </div>
                          <div className="text-right">
                            <p className="text-[10px] opacity-80">เลขที่ใบสมัคร</p>
                            <p className="text-sm font-bold tracking-wide">
                              {app.application_code}
                            </p>
                          </div>
                        </div>

                        {/* Card Body */}
                        <div className="p-4 space-y-3">
                          <div className="flex gap-4 items-start">
                            {/* Photo */}
                            <div className="w-24 h-30 aspect-[3/4] rounded-lg border border-dashed border-slate-400 bg-slate-50 flex flex-col items-center justify-center overflow-hidden shrink-0">
                              {app.doc_photo_data ? (
                                <img
                                  src={app.doc_photo_data}
                                  alt={app.full_name}
                                  className="w-full h-full object-cover"
                                />
                              ) : (
                                <>
                                  <User className="h-7 w-7 text-slate-300" />
                                  <span className="text-[9px] text-slate-400 mt-1">
                                    ติดรูป 1.5 นิ้ว
                                  </span>
                                </>
                              )}
                            </div>

                            {/* Details */}
                            <div className="flex-1 grid grid-cols-2 gap-x-4 gap-y-2 text-xs">
                              <div className="col-span-2">
                                <span className="text-[10px] text-slate-500 block">
                                  ชื่อ - นามสกุลผู้เข้าสอบ
                                </span>
                                <span className="text-sm font-bold text-slate-900">
                                  {app.prefix}
                                  {app.full_name}
                                </span>
                              </div>
                              <div>
                                <span className="text-[10px] text-slate-500 block">
                                  เลขประจำตัวประชาชน
                                </span>
                                <span className="font-semibold text-slate-800 tabular-nums">
                                  {app.national_id}
                                </span>
                              </div>
                              <div>
                                <span className="text-[10px] text-slate-500 block">
                                  ระดับชั้น / แผนการเรียน
                                </span>
                                <span className="font-semibold text-slate-800">
                                  {app.grade_level === 'm1' ? 'ม.1' : 'ม.4'} —{' '}
                                  {app.program_label}
                                </span>
                              </div>
                              <div className="col-span-2">
                                <span className="text-[10px] text-slate-500 block">
                                  โรงเรียนเดิม / GPAX
                                </span>
                                <span className="font-medium text-slate-700">
                                  {app.previous_school}
                                  {app.gpax != null
                                    ? ` (GPAX ${Number(app.gpax).toFixed(2)})`
                                    : ''}
                                </span>
                              </div>
                            </div>
                          </div>

                          {/* Exam Assignment Row */}
                          <div className="grid grid-cols-3 gap-2 rounded-lg border border-slate-300 bg-slate-50 px-3.5 py-2.5 text-xs">
                            <div>
                              <span className="text-[10px] text-slate-500 block">
                                เลขที่นั่งสอบ
                              </span>
                              <span className="font-bold text-slate-900 text-sm">
                                {app.exam_seat_no || 'รอประกาศ'}
                              </span>
                            </div>
                            <div>
                              <span className="text-[10px] text-slate-500 block">
                                อาคาร / ห้องสอบ
                              </span>
                              <span className="font-bold text-slate-900">
                                {app.exam_room || 'รอประกาศ'}
                              </span>
                            </div>
                            <div>
                              <span className="text-[10px] text-slate-500 block">
                                วันและเวลาสอบ
                              </span>
                              <span className="font-semibold text-slate-800">
                                {app.exam_date_label ||
                                  admission.defaultExamDateLabel}
                              </span>
                            </div>
                          </div>

                          {/* Footer signature */}
                          <div className="flex items-end justify-between gap-4 pt-1 text-[10px] text-slate-500">
                            <p>
                              หมายเหตุ: นำบัตรนี้พร้อมบัตรประชาชนตัวจริงมาแสดงในวันสอบ
                              และมาถึงก่อนเวลา 30 นาที
                            </p>
                            <div className="text-center shrink-0 min-w-[140px]">
                              <div className="border-b border-dotted border-slate-400 h-5" />
                              <span className="block mt-0.5">
                                ลงชื่อกรรมการคุมสอบ
                              </span>
                            </div>
                          </div>
                        </div>
                      </div>

                      {/* Dashed Cut Line between the 2 cards on the A4 sheet */}
                      {cardIdx === 0 && pair.length > 1 && (
                        <div className="my-4 flex items-center gap-2 text-slate-400">
                          <Scissors className="h-3.5 w-3.5 shrink-0" />
                          <div className="flex-1 border-t border-dashed border-slate-300" />
                          <span className="text-[10px] shrink-0">
                            ตัดตามรอยประ
                          </span>
                          <div className="flex-1 border-t border-dashed border-slate-300" />
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
