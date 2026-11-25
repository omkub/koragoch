import { useEffect, useMemo, useState } from 'react';
import {
  ADMISSION_STATUS_META,
  checkPublicAdmissionStatus,
  fetchPublicAdmissionStats,
  readOptionalFileDataUrl,
  submitPublicAdmissionApplication,
  type AdmissionGradeLevel,
  type AdmissionStats,
  type PublicAdmissionConfig,
  type PublicAdmissionStatusResult,
} from './publicWebAdmissions';

interface PublicAdmissionTabProps {
  schoolId: number | null;
  schoolDisplayName: string;
  schoolSubTitle: string;
  admission: PublicAdmissionConfig;
}

export default function PublicAdmissionTab({
  schoolId,
  schoolDisplayName,
  schoolSubTitle,
  admission,
}: PublicAdmissionTabProps) {
  const [gradeTab, setGradeTab] = useState<AdmissionGradeLevel>('m1');
  const [stats, setStats] = useState<AdmissionStats>({
    m1Count: 0,
    m4Count: 0,
    totalCount: 0,
  });

  // Form states
  const [formGrade, setFormGrade] = useState<AdmissionGradeLevel>('m1');
  const [formProgramId, setFormProgramId] = useState<string>(
    admission.programsM1[0]?.id ?? 'm1-normal',
  );
  const [nationalId, setNationalId] = useState('');
  const [prefix, setPrefix] = useState('เด็กชาย');
  const [fullName, setFullName] = useState('');
  const [birthDate, setBirthDate] = useState('');
  const [previousSchool, setPreviousSchool] = useState('');
  const [gpax, setGpax] = useState('');
  const [parentName, setParentName] = useState('');
  const [parentRelation, setParentRelation] = useState('บิดา');
  const [parentPhone, setParentPhone] = useState('');

  const [transcriptFile, setTranscriptFile] = useState<File | null>(null);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [houseRegFile, setHouseRegFile] = useState<File | null>(null);

  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [submittedCode, setSubmittedCode] = useState<string | null>(null);
  const [submittedToDb, setSubmittedToDb] = useState<boolean>(true);

  // Status Checker states
  const [trackingInput, setTrackingInput] = useState('');
  const [trackingNationalId, setTrackingNationalId] = useState('');
  const [checkingStatus, setCheckingStatus] = useState(false);
  const [statusError, setStatusError] = useState<string | null>(null);
  const [statusResult, setStatusResult] =
    useState<PublicAdmissionStatusResult | null>(null);

  // Exam Admit Card Print Modal
  const [admitCardApp, setAdmitCardApp] =
    useState<PublicAdmissionStatusResult | null>(null);

  const currentFormPrograms = useMemo(
    () => (formGrade === 'm1' ? admission.programsM1 : admission.programsM4),
    [formGrade, admission.programsM1, admission.programsM4],
  );

  // Keep formProgramId synced when switching grade
  useEffect(() => {
    if (!currentFormPrograms.some((p) => p.id === formProgramId)) {
      setFormProgramId(currentFormPrograms[0]?.id ?? '');
    }
  }, [currentFormPrograms, formProgramId]);

  const reloadStats = async () => {
    const s = await fetchPublicAdmissionStats(schoolId);
    setStats(s);
  };

  useEffect(() => {
    let alive = true;
    fetchPublicAdmissionStats(schoolId).then((s) => {
      if (alive) setStats(s);
    });
    return () => {
      alive = false;
    };
  }, [schoolId]);

  const scrollToSection = (id: string) => {
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  };

  const handleSelectProgramAndScroll = (
    grade: AdmissionGradeLevel,
    programId: string,
  ) => {
    setFormGrade(grade);
    setFormProgramId(programId);
    if (grade === 'm4' && (prefix === 'เด็กชาย' || prefix === 'เด็กหญิง')) {
      setPrefix('นาย');
    }
    scrollToSection('quick-apply');
  };

  const handleResetForm = () => {
    setNationalId('');
    setFullName('');
    setBirthDate('');
    setPreviousSchool('');
    setGpax('');
    setParentName('');
    setParentPhone('');
    setTranscriptFile(null);
    setPhotoFile(null);
    setHouseRegFile(null);
    setSubmitError(null);
  };

  const handleSubmitForm = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError(null);
    setSubmittedCode(null);

    if (!admission.enabled) {
      setSubmitError('ขณะนี้ปิดรับสมัครนักเรียนชั่วคราว กรุณาติดต่อฝ่ายทะเบียนของโรงเรียน');
      return;
    }

    const cleanNid = nationalId.replace(/\D/g, '');
    if (cleanNid.length !== 13) {
      setSubmitError('กรุณากรอกเลขประจำตัวประชาชนให้ครบ 13 หลัก');
      return;
    }

    const selectedProgram = currentFormPrograms.find(
      (p) => p.id === formProgramId,
    );
    const programLabel =
      selectedProgram?.shortTitle ||
      selectedProgram?.title ||
      (formGrade === 'm1' ? 'ห้องเรียนทั่วไป (ม.1)' : 'แผนการเรียน ม.4');

    setSubmitting(true);
    try {
      const [transcriptData, photoData, houseRegData] = await Promise.all([
        transcriptFile ? readOptionalFileDataUrl(transcriptFile, 350_000) : null,
        photoFile ? readOptionalFileDataUrl(photoFile, 350_000) : null,
        houseRegFile ? readOptionalFileDataUrl(houseRegFile, 350_000) : null,
      ]);

      const gpaxNum = gpax.trim() ? Number(gpax) : null;
      const res = await submitPublicAdmissionApplication(schoolId, {
        codePrefix: admission.codePrefix,
        academicYear: admission.academicYear,
        gradeLevel: formGrade,
        programId: formProgramId,
        programLabel,
        nationalId: cleanNid,
        prefix,
        fullName,
        birthDate,
        previousSchool,
        gpax: Number.isFinite(gpaxNum) ? gpaxNum : null,
        parentName,
        parentRelation,
        parentPhone,
        docTranscriptName: transcriptFile?.name ?? null,
        docPhotoName: photoFile?.name ?? null,
        docHouseRegName: houseRegFile?.name ?? null,
        docTranscriptData: transcriptData,
        docPhotoData: photoData,
        docHouseRegData: houseRegData,
      });

      if (!res.ok || !res.applicationCode) {
        setSubmitError(res.error || 'ไม่สามารถส่งใบสมัครได้ กรุณาลองใหม่อีกครั้ง');
        return;
      }

      setSubmittedCode(res.applicationCode);
      setSubmittedToDb(Boolean(res.savedToDb));
      setTrackingInput(res.applicationCode);
      handleResetForm();
      await reloadStats();
    } finally {
      setSubmitting(false);
    }
  };

  const handleCheckStatus = async (overrideQuery?: string) => {
    const q = (overrideQuery ?? trackingInput).trim();
    if (!q || trackingNationalId.replace(/D/g, '').length !== 13) {
      setStatusError('กรุณากรอกเลขที่ใบสมัคร และเลขประจำตัวประชาชน 13 หลัก');
      return;
    }
    setCheckingStatus(true);
    setStatusError(null);
    try {
      const res = await checkPublicAdmissionStatus(
        schoolId,
        q,
        trackingNationalId,
      );
      if (res.found && res.application) {
        setStatusResult(res.application);
      } else {
        setStatusResult(null);
        setStatusError(res.error || 'ไม่พบข้อมูลการสมัครที่ตรงกับเลขที่ระบุ');
      }
    } finally {
      setCheckingStatus(false);
    }
  };

  const handleOpenAdmitCard = (app: PublicAdmissionStatusResult) => {
    setAdmitCardApp(app);
  };

  const handlePrintAdmitCard = () => {
    window.print();
  };

  return (
    <main className="w-full pt-20 bg-surface flex-1">
      <div className="flex flex-col w-full">
        {/* Top Ambient Banner */}
        <section className="relative w-full overflow-hidden bg-gradient-to-b from-surface-container-high/60 via-surface-container-low/40 to-surface py-space-xl">
          <div className="max-w-7xl mx-auto px-6 lg:px-12 relative z-10">
            {/* Overline & Status Badge */}
            <div className="flex flex-wrap items-center gap-space-sm mb-space-md">
              <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-surface-container-lowest text-primary shadow-sm font-label-md">
                {admission.enabled ? (
                  <>
                    <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-ping" />
                    <span className="w-2 h-2 rounded-full bg-emerald-500 -ml-3.5" />
                  </>
                ) : (
                  <span className="w-2 h-2 rounded-full bg-rose-500" />
                )}
                <span>
                  {admission.enabled
                    ? admission.statusBadge
                    : 'ปิดรับสมัครชั่วคราว'}
                </span>
              </div>
              <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full bg-secondary-fixed text-on-secondary-fixed-variant font-label-md">
                <span className="material-symbols-outlined text-[16px]">
                  event_available
                </span>
                <span>{admission.openPeriodBadge}</span>
              </div>
            </div>

            {/* Main Heading & Intro Bento Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-space-lg items-center">
              <div className="lg:col-span-7 flex flex-col gap-space-md">
                <h1 className="font-headline-lg text-headline-lg text-on-surface text-balance">
                  {admission.heroTitlePrefix} <br className="hidden sm:inline" />
                  <span className="text-primary-container">
                    ปีการศึกษา {admission.academicYear}
                  </span>{' '}
                  {admission.heroTitleGradeSuffix}
                </h1>
                <p className="font-body-md text-body-md text-on-surface-variant max-w-2xl leading-relaxed">
                  {schoolDisplayName} {admission.heroDescription}
                </p>

                {/* Interactive Action Buttons */}
                <div className="flex flex-wrap items-center gap-space-sm pt-space-xs">
                  <button
                    type="button"
                    onClick={() => scrollToSection('quick-apply')}
                    className="inline-flex items-center gap-2 px-6 py-3.5 rounded-full bg-primary-container text-on-primary font-label-lg shadow-md hover:bg-primary transition-all duration-200 hover:-translate-y-0.5"
                  >
                    <span className="material-symbols-outlined text-[20px]">
                      edit_document
                    </span>
                    <span>กรอกใบสมัครออนไลน์</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => scrollToSection('downloads')}
                    className="inline-flex items-center gap-2 px-5 py-3.5 rounded-full bg-surface-container-lowest text-primary hover:bg-surface-container-high font-label-lg shadow-sm transition-all duration-200"
                  >
                    <span className="material-symbols-outlined text-[20px]">
                      download
                    </span>
                    <span>ดาวน์โหลดระเบียบการ (PDF)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => scrollToSection('status-checker')}
                    className="inline-flex items-center gap-2 px-5 py-3.5 rounded-full text-on-surface-variant hover:text-primary font-label-lg transition-colors"
                  >
                    <span className="material-symbols-outlined text-[20px]">
                      search_check
                    </span>
                    <span>ตรวจสอบสถานะ</span>
                  </button>
                </div>

                {/* Quick Metrics Bar (Live counts from Supabase) */}
                <div className="grid grid-cols-3 gap-space-sm pt-space-md">
                  <div className="p-space-sm rounded-xl bg-surface-container-lowest shadow-sm flex flex-col">
                    <span className="font-label-sm text-label-sm text-on-surface-variant">
                      ผู้สมัคร ม.1 ทั้งหมด
                    </span>
                    <div className="flex items-baseline gap-1 mt-0.5">
                      <span className="font-headline-md text-headline-md text-primary tabular-nums">
                        {stats.m1Count.toLocaleString('th-TH')}
                      </span>
                      <span className="font-body-sm text-body-sm text-on-surface-variant">
                        คน
                      </span>
                    </div>
                  </div>
                  <div className="p-space-sm rounded-xl bg-surface-container-lowest shadow-sm flex flex-col">
                    <span className="font-label-sm text-label-sm text-on-surface-variant">
                      ผู้สมัคร ม.4 ทั้งหมด
                    </span>
                    <div className="flex items-baseline gap-1 mt-0.5">
                      <span className="font-headline-md text-headline-md text-primary tabular-nums">
                        {stats.m4Count.toLocaleString('th-TH')}
                      </span>
                      <span className="font-body-sm text-body-sm text-on-surface-variant">
                        คน
                      </span>
                    </div>
                  </div>
                  <div className="p-space-sm rounded-xl bg-surface-container-high shadow-sm flex flex-col">
                    <span className="font-label-sm text-label-sm text-primary">
                      รวมยอดสมัครทั้งหมด
                    </span>
                    <div className="flex items-baseline gap-1 mt-0.5">
                      <span className="font-headline-md text-headline-md text-primary-container tabular-nums">
                        {stats.totalCount.toLocaleString('th-TH')}
                      </span>
                      <span className="font-body-sm text-body-sm text-primary">
                        คน
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Hero Graphic Illustration / School Badge Panel */}
              <div className="lg:col-span-5 relative">
                <div className="relative w-full rounded-2xl overflow-hidden shadow-xl bg-surface-container-lowest p-6">
                  <div className="relative h-64 sm:h-72 w-full rounded-xl overflow-hidden mb-4 bg-surface-container">
                    <img
                      className="w-full h-full object-cover"
                      alt={`บรรยากาศการเรียนการสอน ${schoolDisplayName}`}
                      src={admission.heroImageUrl}
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-primary/80 via-primary/20 to-transparent" />
                    <div className="absolute bottom-4 left-4 right-4 text-on-primary">
                      <span className="px-2.5 py-1 rounded bg-secondary-container text-on-secondary-container font-label-sm text-xs font-semibold">
                        {admission.heroRoundBadge}
                      </span>
                      <p className="font-title-md text-title-md font-bold mt-1 text-on-primary">
                        {admission.heroCardTitle}
                      </p>
                      <p className="font-body-sm text-body-sm text-surface-container-highest">
                        {admission.heroCardSubtitle}
                      </p>
                    </div>
                  </div>

                  {/* Key Quick Info Pill List */}
                  <div className="space-y-2.5">
                    <div className="flex items-center justify-between p-2.5 rounded-lg bg-surface-container-low font-body-sm">
                      <div className="flex items-center gap-2 text-on-surface">
                        <span className="material-symbols-outlined text-[18px] text-primary">
                          badge
                        </span>
                        <span>{admission.m1QuickInfoLabel}</span>
                      </div>
                      <span className="font-label-md text-primary font-medium">
                        {admission.m1QuickInfoQuota}
                      </span>
                    </div>
                    <div className="flex items-center justify-between p-2.5 rounded-lg bg-surface-container-low font-body-sm">
                      <div className="flex items-center gap-2 text-on-surface">
                        <span className="material-symbols-outlined text-[18px] text-primary">
                          school
                        </span>
                        <span>{admission.m4QuickInfoLabel}</span>
                      </div>
                      <span className="font-label-md text-primary font-medium">
                        {admission.m4QuickInfoQuota}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Admission Tracks & Study Plans */}
        <section className="w-full py-space-xl bg-surface">
          <div className="max-w-7xl mx-auto px-6 lg:px-12">
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-space-lg">
              <div>
                <span className="font-label-md text-label-md uppercase tracking-wider text-primary font-semibold">
                  ACADEMIC PROGRAMS
                </span>
                <h2 className="font-headline-md text-headline-md text-on-surface mt-1">
                  ระดับชั้นและแผนการเรียนที่เปิดรับสมัคร
                </h2>
                <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                  เลือกดูรายละเอียดหลักสูตร เกณฑ์คะแนน และคุณสมบัติเฉพาะด้าน
                </p>
              </div>

              {/* Grade Tabs Toggle */}
              <div className="inline-flex p-1.5 rounded-full bg-surface-container-high shadow-inner w-fit">
                <button
                  type="button"
                  onClick={() => setGradeTab('m1')}
                  className={`px-5 py-2 rounded-full font-label-lg transition-all ${
                    gradeTab === 'm1'
                      ? 'bg-primary-container text-on-primary shadow-sm'
                      : 'text-on-surface-variant hover:text-primary'
                  }`}
                >
                  ชั้นมัธยมศึกษาปีที่ 1
                </button>
                <button
                  type="button"
                  onClick={() => setGradeTab('m4')}
                  className={`px-5 py-2 rounded-full font-label-lg transition-all ${
                    gradeTab === 'm4'
                      ? 'bg-primary-container text-on-primary shadow-sm'
                      : 'text-on-surface-variant hover:text-primary'
                  }`}
                >
                  ชั้นมัธยมศึกษาปีที่ 4
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-space-lg">
              {(gradeTab === 'm1'
                ? admission.programsM1
                : admission.programsM4
              ).map((prog) => (
                <div
                  key={prog.id}
                  className="flex flex-col bg-surface-container-lowest rounded-2xl p-space-lg shadow-sm hover:shadow-md transition-shadow relative overflow-hidden"
                >
                  {prog.ribbon && (
                    <div className="absolute top-0 right-0">
                      <span className="px-4 py-1 text-xs font-semibold rounded-bl-xl bg-secondary-container text-on-secondary-container">
                        {prog.ribbon}
                      </span>
                    </div>
                  )}
                  <div className="flex items-start justify-between gap-4">
                    <div
                      className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${
                        prog.iconTone === 'tertiary'
                          ? 'bg-tertiary-fixed text-on-tertiary-fixed'
                          : 'bg-primary-fixed text-on-primary-fixed'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[28px]">
                        {prog.icon || 'school'}
                      </span>
                    </div>
                    <span
                      className={`px-3 py-1 rounded-full bg-surface-container-high text-primary font-label-sm ${
                        prog.ribbon ? 'mt-5' : ''
                      }`}
                    >
                      {prog.quotaLabel}
                    </span>
                  </div>

                  <h3 className="font-title-lg text-title-lg text-on-surface mt-4">
                    {prog.title}
                  </h3>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5">
                    {prog.description}
                  </p>

                  <div className="mt-space-md pt-space-md space-y-2 font-body-sm bg-surface-container-low rounded-xl p-3.5">
                    <div className="flex justify-between items-center gap-3 text-on-surface">
                      <span className="text-on-surface-variant shrink-0">
                        {prog.gpaxLabel}
                      </span>
                      <span className="font-medium text-right text-primary">
                        {prog.gpaxValue}
                      </span>
                    </div>
                    <div className="flex justify-between items-center gap-3 text-on-surface">
                      <span className="text-on-surface-variant shrink-0">
                        วิชาที่ใช้สอบ
                      </span>
                      <span className="font-medium text-right">
                        {prog.examSubjects}
                      </span>
                    </div>
                    {prog.extraLabel && prog.extraValue && (
                      <div className="flex justify-between items-center gap-3 text-on-surface">
                        <span className="text-on-surface-variant shrink-0">
                          {prog.extraLabel}
                        </span>
                        <span className="font-medium text-right text-primary">
                          {prog.extraValue}
                        </span>
                      </div>
                    )}
                    <div className="flex justify-between items-center gap-3 text-on-surface">
                      <span className="text-on-surface-variant shrink-0">
                        {prog.feeLabel}
                      </span>
                      <span
                        className={`font-medium text-right ${
                          prog.feeHighlight
                            ? 'text-emerald-700'
                            : 'text-primary'
                        }`}
                      >
                        {prog.feeValue}
                      </span>
                    </div>
                  </div>

                  <div className="mt-auto pt-6 flex items-center justify-between gap-2">
                    <span className="font-label-md text-on-surface-variant">
                      {prog.openRangeLabel}
                    </span>
                    <button
                      type="button"
                      onClick={() =>
                        handleSelectProgramAndScroll(prog.grade, prog.id)
                      }
                      className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-primary-container text-on-primary font-label-md hover:bg-primary transition-colors"
                    >
                      <span>สมัครแผนนี้</span>
                      <span className="material-symbols-outlined text-[16px]">
                        arrow_forward
                      </span>
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Admission Timeline Section */}
        <section className="w-full py-space-xl bg-surface-container-low/60">
          <div className="max-w-7xl mx-auto px-6 lg:px-12">
            <div className="text-center max-w-2xl mx-auto mb-space-xl">
              <span className="font-label-md text-label-md uppercase tracking-wider text-primary font-semibold">
                ADMISSION SCHEDULE
              </span>
              <h2 className="font-headline-md text-headline-md text-on-surface mt-1">
                กำหนดการรับสมัครและคัดเลือก
              </h2>
              <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                โปรดตรวจสอบและบันทึกวันเวลาที่สำคัญ
                เพื่อไม่ให้พลาดขั้นตอนการรายงานตัวเข้าศึกษา
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-5 gap-space-md relative">
              {admission.timeline.map((step) => (
                <div
                  key={step.step}
                  className={`flex flex-col bg-surface-container-lowest rounded-2xl p-space-md shadow-sm relative z-10 ${
                    step.isCurrent ? 'border-b-4 border-primary' : ''
                  }`}
                >
                  <div
                    className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm mb-3 ${
                      step.isCurrent
                        ? 'bg-primary-container text-on-primary'
                        : 'bg-surface-container-highest text-on-surface'
                    }`}
                  >
                    {step.step}
                  </div>
                  <span
                    className={`px-2 py-0.5 w-fit rounded font-label-sm text-xs mb-2 ${
                      step.isCurrent
                        ? 'bg-emerald-100 text-emerald-800 font-semibold'
                        : 'bg-surface-container text-on-surface-variant'
                    }`}
                  >
                    {step.badge}
                  </span>
                  <h4 className="font-title-md text-title-md text-on-surface leading-tight">
                    {step.title}
                  </h4>
                  <p className="font-body-sm text-body-sm text-primary font-semibold mt-1">
                    {step.dateLabel}
                  </p>
                  <p className="font-body-sm text-body-sm text-on-surface-variant text-xs mt-2">
                    {step.description}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* How to Apply (4 Clear Steps) */}
        <section className="w-full py-space-xl bg-surface">
          <div className="max-w-7xl mx-auto px-6 lg:px-12">
            <div className="flex flex-col lg:flex-row gap-space-lg items-start">
              <div className="lg:w-1/3 flex flex-col gap-3">
                <span className="font-label-md text-label-md uppercase tracking-wider text-primary font-semibold">
                  APPLICATION PROCESS
                </span>
                <h2 className="font-headline-md text-headline-md text-on-surface">
                  ขั้นตอนการสมัครออนไลน์ สะดวก ง่ายใน 4 ขั้น
                </h2>
                <p className="font-body-sm text-body-sm text-on-surface-variant leading-relaxed">
                  ผู้สมัครสามารถกรอกใบสมัครได้จากสมาร์ตโฟนหรือคอมพิวเตอร์
                  โดยเตรียมไฟล์ภาพถ่ายหรือ PDF ให้พร้อมก่อนเริ่มดำเนินการ
                </p>
                <div className="mt-4 p-4 rounded-2xl bg-surface-container-high/60 flex items-start gap-3">
                  <span className="material-symbols-outlined text-primary text-[24px]">
                    support_agent
                  </span>
                  <div className="text-xs text-on-surface">
                    <span className="font-bold block">
                      มีข้อสงสัยระหว่างการสมัคร?
                    </span>
                    <span>
                      โทร {admission.helpdeskPhone} (ฝ่ายทะเบียนและวัดผล)
                      ให้บริการในวันและเวลาราชการ
                    </span>
                  </div>
                </div>
              </div>

              <div className="lg:w-2/3 grid grid-cols-1 sm:grid-cols-2 gap-space-md">
                {admission.processSteps.map((s) => (
                  <div
                    key={s.num}
                    className="p-space-lg rounded-2xl bg-surface-container-lowest shadow-sm flex flex-col gap-2"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-primary-fixed flex items-center justify-center text-on-primary-fixed font-bold">
                        {s.num}
                      </div>
                      <h3 className="font-title-md text-title-md text-on-surface">
                        {s.title}
                      </h3>
                    </div>
                    <p className="font-body-sm text-body-sm text-on-surface-variant text-sm mt-1">
                      {s.description}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        {/* Interactive Application Form Section (#quick-apply) */}
        <section
          className="w-full py-space-xl bg-surface-container-lowest scroll-mt-20"
          id="quick-apply"
        >
          <div className="max-w-5xl mx-auto px-6 lg:px-12">
            <div className="text-center max-w-xl mx-auto mb-space-lg">
              <span className="inline-block px-3 py-1 rounded-full bg-primary-fixed text-on-primary-fixed font-label-md mb-2">
                ระบบรับสมัครออนไลน์ {admission.academicYear}
              </span>
              <h2 className="font-headline-md text-headline-md text-on-surface">
                แบบฟอร์มกรอกใบสมัครนักเรียนใหม่
              </h2>
              <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                กรอกข้อมูลให้ครบถ้วนและถูกต้องตามความเป็นจริง
              </p>
            </div>

            {!admission.enabled ? (
              <div className="bg-surface rounded-2xl p-8 text-center border border-outline-variant/30 space-y-2">
                <span className="material-symbols-outlined text-4xl text-rose-500">
                  event_busy
                </span>
                <p className="font-title-md text-on-surface">
                  ขณะนี้ปิดรับสมัครนักเรียนชั่วคราว
                </p>
                <p className="font-body-sm text-on-surface-variant">
                  หากสมัครไว้แล้ว สามารถตรวจสอบสถานะและพิมพ์บัตรประจำตัวสอบได้ที่ด้านล่าง
                </p>
              </div>
            ) : (
              <form
                className="bg-surface rounded-2xl p-6 sm:p-10 shadow-md"
                onSubmit={handleSubmitForm}
              >
                {/* Step Part 1 */}
                <div className="pb-space-md mb-space-md border-b border-surface-container">
                  <label className="font-title-md text-title-md text-on-surface block mb-3">
                    1. เลือกระดับชั้นและแผนการเรียนที่สมัคร
                  </label>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-space-md">
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        ระดับชั้น *
                      </label>
                      <select
                        value={formGrade}
                        onChange={(e) =>
                          setFormGrade(e.target.value as AdmissionGradeLevel)
                        }
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      >
                        <option value="m1">มัธยมศึกษาปีที่ 1 (ม.1)</option>
                        <option value="m4">มัธยมศึกษาปีที่ 4 (ม.4)</option>
                      </select>
                    </div>
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        แผนการเรียนที่เลือก *
                      </label>
                      <select
                        value={formProgramId}
                        onChange={(e) => setFormProgramId(e.target.value)}
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      >
                        {currentFormPrograms.map((p) => (
                          <option key={p.id} value={p.id}>
                            {p.shortTitle || p.title}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                </div>

                {/* Step Part 2 */}
                <div className="pb-space-md mb-space-md border-b border-surface-container">
                  <label className="font-title-md text-title-md text-on-surface block mb-3">
                    2. ข้อมูลส่วนตัวของผู้สมัคร
                  </label>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-space-md">
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        เลขประจำตัวประชาชน 13 หลัก *
                      </label>
                      <input
                        value={nationalId}
                        onChange={(e) =>
                          setNationalId(e.target.value.replace(/\D/g, '').slice(0, 13))
                        }
                        maxLength={13}
                        placeholder="เลข 13 หลัก"
                        required
                        type="text"
                        inputMode="numeric"
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        คำนำหน้าชื่อ *
                      </label>
                      <select
                        value={prefix}
                        onChange={(e) => setPrefix(e.target.value)}
                        required
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      >
                        <option value="เด็กชาย">เด็กชาย</option>
                        <option value="เด็กหญิง">เด็กหญิง</option>
                        <option value="นาย">นาย</option>
                        <option value="นางสาว">นางสาว</option>
                      </select>
                    </div>
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        ชื่อ - นามสกุล *
                      </label>
                      <input
                        value={fullName}
                        onChange={(e) => setFullName(e.target.value)}
                        placeholder="ระบุชื่อและนามสกุล"
                        required
                        type="text"
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-space-md mt-4">
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        วัน/เดือน/ปี เกิด *
                      </label>
                      <input
                        value={birthDate}
                        onChange={(e) => setBirthDate(e.target.value)}
                        required
                        type="date"
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        โรงเรียนเดิมที่จบการศึกษา *
                      </label>
                      <input
                        value={previousSchool}
                        onChange={(e) => setPreviousSchool(e.target.value)}
                        placeholder="เช่น ร.ร. อนุบาลบ้านด่าน"
                        required
                        type="text"
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        เกรดเฉลี่ยสะสม (GPAX) *
                      </label>
                      <input
                        value={gpax}
                        onChange={(e) => setGpax(e.target.value)}
                        max="4.00"
                        min="0"
                        placeholder="เช่น 3.45"
                        required
                        step="0.01"
                        type="number"
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                  </div>
                </div>

                {/* Step Part 3 */}
                <div className="pb-space-md mb-space-md border-b border-surface-container">
                  <label className="font-title-md text-title-md text-on-surface block mb-3">
                    3. ข้อมูลติดต่อและผู้ปกครอง
                  </label>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-space-md">
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        ชื่อผู้ปกครอง *
                      </label>
                      <input
                        value={parentName}
                        onChange={(e) => setParentName(e.target.value)}
                        placeholder="ชื่อ-นามสกุล ผู้ปกครอง"
                        required
                        type="text"
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        ความสัมพันธ์ *
                      </label>
                      <select
                        value={parentRelation}
                        onChange={(e) => setParentRelation(e.target.value)}
                        required
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      >
                        <option value="บิดา">บิดา</option>
                        <option value="มารดา">มารดา</option>
                        <option value="ผู้ปกครอง">ผู้ปกครอง</option>
                      </select>
                    </div>
                    <div>
                      <label className="font-label-md text-label-md text-on-surface-variant block mb-1">
                        เบอร์โทรศัพท์ติดต่อด่วน *
                      </label>
                      <input
                        value={parentPhone}
                        onChange={(e) => setParentPhone(e.target.value)}
                        placeholder="08x-xxx-xxxx"
                        required
                        type="tel"
                        className="w-full h-11 px-3.5 rounded-lg bg-surface-container-lowest text-on-surface font-body-sm border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                    </div>
                  </div>
                </div>

                {/* Step Part 4 */}
                <div className="mb-space-lg">
                  <label className="font-title-md text-title-md text-on-surface block mb-1">
                    4. อัปโหลดไฟล์หลักฐาน (JPG, PNG หรือ PDF ไม่เกิน 5MB)
                  </label>
                  <p className="font-body-sm text-body-sm text-on-surface-variant text-xs mb-3">
                    สามารถแนบเอกสารภายหลังได้ หรือส่งทางเคาน์เตอร์ทะเบียนในวันรายงานตัว
                  </p>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-space-md">
                    <div className="border border-dashed border-outline-variant/60 rounded-xl p-4 text-center bg-surface-container-lowest">
                      <span className="material-symbols-outlined text-[24px] text-primary">
                        upload_file
                      </span>
                      <span className="block font-label-md mt-1 text-on-surface">
                        ระเบียนแสดงผลการเรียน (ปพ.1)
                      </span>
                      <input
                        accept=".pdf,.png,.jpg,.jpeg"
                        onChange={(e) =>
                          setTranscriptFile(e.target.files?.[0] ?? null)
                        }
                        className="mt-2 text-xs text-on-surface-variant w-full"
                        type="file"
                      />
                    </div>
                    <div className="border border-dashed border-outline-variant/60 rounded-xl p-4 text-center bg-surface-container-lowest">
                      <span className="material-symbols-outlined text-[24px] text-primary">
                        badge
                      </span>
                      <span className="block font-label-md mt-1 text-on-surface">
                        รูปถ่ายนักเรียน (1.5 นิ้ว)
                      </span>
                      <input
                        accept=".png,.jpg,.jpeg"
                        onChange={(e) =>
                          setPhotoFile(e.target.files?.[0] ?? null)
                        }
                        className="mt-2 text-xs text-on-surface-variant w-full"
                        type="file"
                      />
                    </div>
                    <div className="border border-dashed border-outline-variant/60 rounded-xl p-4 text-center bg-surface-container-lowest">
                      <span className="material-symbols-outlined text-[24px] text-primary">
                        home
                      </span>
                      <span className="block font-label-md mt-1 text-on-surface">
                        สำเนาทะเบียนบ้าน
                      </span>
                      <input
                        accept=".pdf,.png,.jpg,.jpeg"
                        onChange={(e) =>
                          setHouseRegFile(e.target.files?.[0] ?? null)
                        }
                        className="mt-2 text-xs text-on-surface-variant w-full"
                        type="file"
                      />
                    </div>
                  </div>
                </div>

                {submitError && (
                  <div className="mb-4 p-3.5 rounded-xl bg-error-container text-on-error-container text-sm flex items-center gap-2">
                    <span className="material-symbols-outlined text-[20px]">
                      error
                    </span>
                    <span>{submitError}</span>
                  </div>
                )}

                {/* Submit Buttons & Notice */}
                <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-4 border-t border-surface-container">
                  <div className="flex items-center gap-2 text-xs text-on-surface-variant">
                    <span className="material-symbols-outlined text-[16px] text-emerald-600">
                      verified_user
                    </span>
                    <span>
                      ข้อมูลของผู้สมัครจะถูกจัดเก็บตามพระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล
                      (PDPA)
                    </span>
                  </div>
                  <div className="flex items-center gap-3 w-full sm:w-auto">
                    <button
                      type="button"
                      onClick={handleResetForm}
                      className="px-5 py-2.5 rounded-full font-label-lg text-on-surface-variant hover:text-primary transition-colors"
                    >
                      ล้างข้อมูล
                    </button>
                    <button
                      type="submit"
                      disabled={submitting}
                      className="flex-1 sm:flex-none px-8 py-3 rounded-full bg-primary-container text-on-primary font-label-lg shadow-md hover:bg-primary transition-colors disabled:opacity-60"
                    >
                      {submitting
                        ? 'กำลังบันทึกใบสมัคร...'
                        : 'ยืนยันการส่งใบสมัคร'}
                    </button>
                  </div>
                </div>

                {/* Success Toast */}
                {submittedCode && (
                  <div className="mt-6 p-4 rounded-xl bg-emerald-50 text-emerald-800 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 border border-emerald-200">
                    <div className="flex items-center gap-2">
                      <span className="material-symbols-outlined text-emerald-600">
                        check_circle
                      </span>
                      <span className="font-body-sm font-medium">
                        บันทึกข้อมูลการสมัครเรียบร้อยแล้ว! เลขที่ใบสมัครของคุณคือ:{' '}
                        <strong className="text-emerald-950">
                          {submittedCode}
                        </strong>
                        {!submittedToDb && (
                          <span className="ml-2 text-xs text-emerald-700">
                            (บันทึกชั่วคราวบนเครื่อง)
                          </span>
                        )}
                      </span>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        scrollToSection('status-checker');
                        handleCheckStatus(submittedCode);
                      }}
                      className="text-xs underline font-bold hover:text-emerald-950 shrink-0"
                    >
                      ตรวจสอบสถานะทันที →
                    </button>
                  </div>
                )}
              </form>
            )}
          </div>
        </section>

        {/* Quick Status Checker Tool Section (#status-checker) */}
        <section
          className="w-full py-space-xl bg-surface-container-low scroll-mt-20"
          id="status-checker"
        >
          <div className="max-w-4xl mx-auto px-6 lg:px-12">
            <div className="bg-surface-container-lowest rounded-3xl p-6 sm:p-10 shadow-lg relative overflow-hidden">
              <div className="absolute -right-12 -top-12 w-48 h-48 rounded-full bg-primary/5 pointer-events-none" />
              <div className="flex items-center gap-3 mb-2">
                <div className="w-9 h-9 rounded-xl bg-primary-container flex items-center justify-center text-on-primary">
                  <span className="material-symbols-outlined text-[20px]">
                    manage_search
                  </span>
                </div>
                <span className="font-label-md text-label-md text-primary font-semibold">
                  ONLINE TRACKING SYSTEM
                </span>
              </div>
              <h3 className="font-headline-md text-headline-md text-on-surface">
                ตรวจสอบสถานะการสมัคร &amp; พิมพ์บัตรประจำตัวสอบ
              </h3>
              <p className="font-body-sm text-body-sm text-on-surface-variant mt-1 mb-6">
                กรอกเลขที่ใบสมัคร และเลขประจำตัวประชาชน 13 หลักของผู้สมัคร
                เพื่อดูผลการอนุมัติเอกสารและดาวน์โหลดบัตรเข้าห้องสอบ
              </p>

              {/* Search Bar */}
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  handleCheckStatus();
                }}
                className="flex flex-col sm:flex-row gap-3"
              >
                <div className="relative flex-1">
                  <span className="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-outline">
                    id_card
                  </span>
                  <input
                    value={trackingInput}
                    onChange={(e) => setTrackingInput(e.target.value)}
                    placeholder={`เลขที่ใบสมัคร เช่น ${admission.codePrefix}-${admission.academicYear.slice(-2)}-00001`}
                    type="text"
                    className="w-full h-12 pl-12 pr-4 rounded-xl bg-surface font-body-sm text-on-surface border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                </div>
                <div className="relative flex-1">
                  <input
                    value={trackingNationalId}
                    onChange={(e) =>
                      setTrackingNationalId(
                        e.target.value.replace(/D/g, '').slice(0, 13),
                      )
                    }
                    placeholder="เลขประจำตัวประชาชน 13 หลัก"
                    inputMode="numeric"
                    autoComplete="off"
                    type="text"
                    className="w-full h-12 px-4 rounded-xl bg-surface font-body-sm text-on-surface border border-outline-variant/30 focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                </div>
                <button
                  type="submit"
                  disabled={checkingStatus}
                  className="px-7 h-12 rounded-xl bg-primary-container text-on-primary font-label-lg shadow-md hover:bg-primary transition-all shrink-0 flex items-center justify-center gap-2 disabled:opacity-60"
                >
                  <span className="material-symbols-outlined text-[20px]">
                    search
                  </span>
                  <span>{checkingStatus ? 'กำลังค้นหา...' : 'ค้นหาสถานะ'}</span>
                </button>
              </form>

              {statusError && (
                <div className="mt-5 p-4 rounded-2xl bg-error-container/70 text-on-error-container text-sm flex items-center gap-2">
                  <span className="material-symbols-outlined text-[20px]">
                    info
                  </span>
                  <span>{statusError}</span>
                </div>
              )}

              {/* Result Box */}
              {statusResult && (
                <div className="mt-6 p-5 rounded-2xl bg-surface-container-high/50 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                  <div className="flex items-start gap-3.5">
                    <div className="w-11 h-11 rounded-full bg-primary-fixed text-primary flex items-center justify-center shrink-0 mt-0.5">
                      <span className="material-symbols-outlined text-[22px]">
                        {ADMISSION_STATUS_META[statusResult.status]?.icon ||
                          'verified'}
                      </span>
                    </div>
                    <div>
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-title-md text-title-md text-on-surface">
                          {statusResult.prefix}
                          {statusResult.full_name}
                        </span>
                        <span
                          className={`px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                            ADMISSION_STATUS_META[statusResult.status]
                              ?.badgeClass || 'bg-slate-100 text-slate-700'
                          }`}
                        >
                          {ADMISSION_STATUS_META[statusResult.status]?.label ||
                            statusResult.status}
                        </span>
                      </div>
                      <p className="font-body-sm text-body-sm text-on-surface-variant text-xs mt-1">
                        ระดับชั้น:{' '}
                        <strong>
                          {statusResult.grade_level === 'm1' ? 'ม.1' : 'ม.4'}{' '}
                          {statusResult.program_label}
                        </strong>{' '}
                        | เลขที่ใบสมัคร:{' '}
                        <strong>{statusResult.application_code}</strong>
                      </p>
                      {(statusResult.exam_seat_no || statusResult.exam_room) && (
                        <p className="font-body-sm text-xs text-primary mt-1 font-medium">
                          เลขที่นั่งสอบ:{' '}
                          {statusResult.exam_seat_no || 'รอประกาศ'} • ห้องสอบ:{' '}
                          {statusResult.exam_room || 'รอประกาศ'}
                        </p>
                      )}
                      {statusResult.status_note && (
                        <p className="text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded-lg px-2.5 py-1.5 mt-2">
                          หมายเหตุจากเจ้าหน้าที่: {statusResult.status_note}
                        </p>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2 w-full sm:w-auto">
                    <button
                      type="button"
                      onClick={() => handleOpenAdmitCard(statusResult)}
                      className="w-full sm:w-auto inline-flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-xl bg-surface-container-lowest text-primary shadow-sm hover:bg-surface font-label-md transition-all"
                    >
                      <span className="material-symbols-outlined text-[18px]">
                        print
                      </span>
                      <span>พิมพ์บัตรสอบ</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </section>

        {/* Required Documents & Downloads Section (#downloads) */}
        <section
          className="w-full py-space-xl bg-surface scroll-mt-20"
          id="downloads"
        >
          <div className="max-w-7xl mx-auto px-6 lg:px-12">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-space-lg">
              {/* Left: Checklist */}
              <div className="lg:col-span-6 flex flex-col justify-between">
                <div>
                  <span className="font-label-md text-label-md uppercase tracking-wider text-primary font-semibold">
                    CHECKLIST
                  </span>
                  <h2 className="font-headline-md text-headline-md text-on-surface mt-1">
                    เอกสารและหลักฐานที่ต้องเตรียม
                  </h2>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1 mb-space-md">
                    กรุณาจัดเตรียมเอกสารฉบับจริงพร้อมสำเนาถูกต้อง
                    เพื่อนำมาแสดงในวันรายงานตัวและมอบตัว
                  </p>
                  <ul className="space-y-3 font-body-sm">
                    {admission.requiredDocs.map((doc) => (
                      <li
                        key={doc.id}
                        className="flex items-start gap-3 p-3 rounded-xl bg-surface-container-lowest shadow-sm"
                      >
                        <span className="material-symbols-outlined text-primary text-[20px] shrink-0 mt-0.5">
                          check_circle
                        </span>
                        <div>
                          <span className="font-title-md text-title-md text-on-surface text-sm block">
                            {doc.title}
                          </span>
                          <span className="text-xs text-on-surface-variant">
                            {doc.description}
                          </span>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              {/* Right: Downloadable PDF Cards */}
              <div className="lg:col-span-6 flex flex-col justify-between">
                <div>
                  <span className="font-label-md text-label-md uppercase tracking-wider text-primary font-semibold">
                    DOWNLOAD FORMS
                  </span>
                  <h2 className="font-headline-md text-headline-md text-on-surface mt-1">
                    ดาวน์โหลดเอกสารและแบบฟอร์ม
                  </h2>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1 mb-space-md">
                    ไฟล์ระเบียบการทางการและแบบฟอร์มประกอบการรับสมัคร
                    ประจำปีการศึกษา {admission.academicYear}
                  </p>
                  <div className="space-y-3">
                    {admission.downloads.map((dl) => {
                      const iconBoxClass =
                        dl.iconTone === 'error'
                          ? 'bg-error-container text-on-error-container'
                          : dl.iconTone === 'primary'
                            ? 'bg-primary-fixed text-primary'
                            : 'bg-surface-container text-on-surface';
                      const hasUrl = Boolean(dl.url && dl.url.trim());
                      return (
                        <div
                          key={dl.id}
                          className="p-4 rounded-2xl bg-surface-container-lowest shadow-sm hover:shadow-md transition-shadow flex items-center justify-between gap-4"
                        >
                          <div className="flex items-center gap-3">
                            <div
                              className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${iconBoxClass}`}
                            >
                              <span className="material-symbols-outlined text-[24px]">
                                {dl.icon || 'picture_as_pdf'}
                              </span>
                            </div>
                            <div>
                              <h4 className="font-title-md text-title-md text-on-surface text-sm">
                                {dl.title}
                              </h4>
                              <span className="text-xs text-on-surface-variant">
                                {dl.meta}
                              </span>
                            </div>
                          </div>
                          {hasUrl ? (
                            <a
                              href={dl.url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="p-2.5 rounded-full bg-surface-container-high text-primary hover:bg-primary-container hover:text-on-primary transition-colors shrink-0"
                              title="ดาวน์โหลดไฟล์"
                            >
                              <span className="material-symbols-outlined text-[20px]">
                                download
                              </span>
                            </a>
                          ) : (
                            <span
                              className="p-2.5 rounded-full bg-surface-container text-on-surface-variant/60 shrink-0"
                              title="ยังไม่ได้แนบลิงก์ไฟล์ (เพิ่มลิงก์ได้ในหน้าตั้งค่าเว็บสาธารณะ)"
                            >
                              <span className="material-symbols-outlined text-[20px]">
                                download
                              </span>
                            </span>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* FAQ & Help Contact Section */}
        <section className="w-full py-space-xl bg-surface-container-low/40">
          <div className="max-w-7xl mx-auto px-6 lg:px-12">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-space-lg">
              {/* FAQs Accordion */}
              <div className="lg:col-span-7 flex flex-col">
                <span className="font-label-md text-label-md uppercase tracking-wider text-primary font-semibold">
                  FREQUENTLY ASKED QUESTIONS
                </span>
                <h2 className="font-headline-md text-headline-md text-on-surface mt-1 mb-space-md">
                  คำถามที่พบบ่อยเกี่ยวกับการรับสมัคร
                </h2>
                <div className="space-y-3 font-body-sm">
                  {admission.faqs.map((faq, idx) => (
                    <details
                      key={faq.id}
                      className="group bg-surface-container-lowest rounded-xl p-4 shadow-sm"
                      open={idx === 0}
                    >
                      <summary className="font-title-md text-title-md text-on-surface cursor-pointer flex justify-between items-center list-none select-none">
                        <span>{faq.question}</span>
                        <span className="material-symbols-outlined text-outline transition-transform duration-200 group-open:rotate-180">
                          expand_more
                        </span>
                      </summary>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-3 pt-3 border-t border-surface-container text-sm">
                        {faq.answer}
                      </p>
                    </details>
                  ))}
                </div>
              </div>

              {/* Helpdesk Contact Callout Card */}
              <div className="lg:col-span-5 flex flex-col justify-center">
                <div className="bg-gradient-to-br from-primary-container to-primary text-on-primary rounded-3xl p-6 sm:p-8 shadow-xl">
                  <div className="w-12 h-12 rounded-2xl bg-surface-container-lowest/15 flex items-center justify-center mb-4">
                    <span className="material-symbols-outlined text-[28px] text-on-primary">
                      contact_support
                    </span>
                  </div>
                  <h3 className="font-headline-sm text-headline-sm text-on-primary">
                    ศูนย์ประสานงานรับสมัครนักเรียน
                  </h3>
                  <p className="font-body-sm text-body-sm text-primary-fixed mt-1">
                    {schoolDisplayName} พร้อมให้ความช่วยเหลือและตอบคำถามทุกข้อสงสัย
                  </p>
                  <div className="mt-6 space-y-3 font-body-sm">
                    <div className="flex items-center gap-3 p-3 rounded-xl bg-surface-container-lowest/10">
                      <span className="material-symbols-outlined text-[20px] text-primary-fixed">
                        call
                      </span>
                      <div>
                        <span className="text-xs text-primary-fixed block">
                          โทรศัพท์สายตรงฝ่ายทะเบียน
                        </span>
                        <span className="font-semibold text-on-primary">
                          {admission.helpdeskPhone}
                        </span>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 p-3 rounded-xl bg-surface-container-lowest/10">
                      <span className="material-symbols-outlined text-[20px] text-primary-fixed">
                        chat
                      </span>
                      <div>
                        <span className="text-xs text-primary-fixed block">
                          LINE Official สำหรับรับสมัคร
                        </span>
                        <span className="font-semibold text-on-primary">
                          {admission.helpdeskLine}
                        </span>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 p-3 rounded-xl bg-surface-container-lowest/10">
                      <span className="material-symbols-outlined text-[20px] text-primary-fixed">
                        location_on
                      </span>
                      <div>
                        <span className="text-xs text-primary-fixed block">
                          สถานที่ตั้ง
                        </span>
                        <span className="font-semibold text-on-primary">
                          {admission.helpdeskAddress}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className="mt-6 pt-4 border-t border-surface-container-lowest/20 flex items-center justify-between text-xs text-primary-fixed">
                    <span>{admission.helpdeskHours}</span>
                    <span className="inline-flex items-center gap-1 font-semibold text-on-primary">
                      {admission.helpdeskAgency}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>

      {/* Exam Admit Card Modal (Printable) */}
      {admitCardApp && (
        <div
          className="fixed inset-0 z-[100] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto print:bg-white print:p-0"
          onClick={() => setAdmitCardApp(null)}
        >
          <div
            className="w-full max-w-2xl bg-white rounded-2xl shadow-2xl overflow-hidden border border-slate-200 print:shadow-none print:border-2 print:border-slate-800 print:rounded-none"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="bg-primary-container text-white px-6 py-5 flex items-center justify-between print:bg-white print:text-slate-900 print:border-b-2 print:border-slate-800">
              <div>
                <p className="text-xs uppercase tracking-wider opacity-80">
                  บัตรประจำตัวผู้เข้าสอบคัดเลือก • EXAM ADMIT CARD
                </p>
                <h3 className="text-lg font-bold mt-0.5">{schoolDisplayName}</h3>
                <p className="text-xs opacity-90">{schoolSubTitle}</p>
              </div>
              <button
                type="button"
                onClick={() => setAdmitCardApp(null)}
                className="p-1.5 rounded-lg hover:bg-white/15 print:hidden"
                aria-label="ปิดหน้าต่าง"
              >
                <span className="material-symbols-outlined text-[22px]">
                  close
                </span>
              </button>
            </div>

            {/* Body */}
            <div className="p-6 space-y-5">
              <div className="flex flex-col sm:flex-row gap-5 items-start">
                {/* Photo box */}
                <div className="w-28 h-36 rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 flex items-center justify-center overflow-hidden shrink-0">
                  {admitCardApp.doc_photo_data ? (
                    <img
                      src={admitCardApp.doc_photo_data}
                      alt={admitCardApp.full_name}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="text-center px-2 text-slate-400">
                      <span className="material-symbols-outlined text-[32px]">
                        person
                      </span>
                      <p className="text-[10px] mt-1">รูปถ่าย 1.5 นิ้ว</p>
                    </div>
                  )}
                </div>

                {/* Applicant Info */}
                <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                  <div>
                    <p className="text-xs text-slate-500">เลขที่ใบสมัคร</p>
                    <p className="font-bold text-primary text-base">
                      {admitCardApp.application_code}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-slate-500">สถานะการสมัคร</p>
                    <span
                      className={`inline-block mt-0.5 px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                        ADMISSION_STATUS_META[admitCardApp.status]?.badgeClass ||
                        'bg-slate-100 text-slate-700'
                      }`}
                    >
                      {ADMISSION_STATUS_META[admitCardApp.status]?.label ||
                        admitCardApp.status}
                    </span>
                  </div>
                  <div className="sm:col-span-2">
                    <p className="text-xs text-slate-500">ชื่อ - นามสกุลผู้สมัคร</p>
                    <p className="font-semibold text-slate-900 text-base">
                      {admitCardApp.prefix}
                      {admitCardApp.full_name}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-slate-500">ระดับชั้น / แผนการเรียน</p>
                    <p className="font-medium text-slate-800">
                      {admitCardApp.grade_level === 'm1' ? 'ม.1' : 'ม.4'} —{' '}
                      {admitCardApp.program_label}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-slate-500">โรงเรียนเดิม / GPAX</p>
                    <p className="font-medium text-slate-800">
                      {admitCardApp.previous_school}
                      {admitCardApp.gpax != null
                        ? ` (${Number(admitCardApp.gpax).toFixed(2)})`
                        : ''}
                    </p>
                  </div>
                </div>
              </div>

              {/* Exam Room Box */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-4 rounded-xl bg-slate-50 border border-slate-200 text-sm">
                <div>
                  <p className="text-xs text-slate-500">เลขที่นั่งสอบ</p>
                  <p className="font-bold text-slate-900 mt-0.5">
                    {admitCardApp.exam_seat_no || 'รอเจ้าหน้าที่กำหนด'}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-slate-500">อาคาร / ห้องสอบ</p>
                  <p className="font-bold text-slate-900 mt-0.5">
                    {admitCardApp.exam_room || 'รอประกาศห้องสอบ'}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-slate-500">วันและเวลาสอบ</p>
                  <p className="font-semibold text-slate-800 mt-0.5">
                    {admitCardApp.exam_date_label ||
                      admission.defaultExamDateLabel}
                  </p>
                </div>
              </div>

              <div className="text-xs text-slate-500 space-y-1 border-t border-slate-200 pt-3">
                <p>
                  • กรุณานำบัตรประจำตัวสอบฉบับนี้พร้อมบัตรประจำตัวประชาชนตัวจริงมาแสดงในวันสอบคัดเลือก
                </p>
                <p>
                  • แต่งกายด้วยชุดนักเรียนโรงเรียนเดิมให้สุภาพเรียบร้อย และมาถึงสนามสอบก่อนเวลาอย่างน้อย 30 นาที
                </p>
              </div>
            </div>

            {/* Footer actions */}
            <div className="px-6 py-4 bg-slate-50 border-t border-slate-200 flex items-center justify-end gap-3 print:hidden">
              <button
                type="button"
                onClick={() => setAdmitCardApp(null)}
                className="px-4 py-2 rounded-xl border border-slate-300 text-slate-700 text-sm font-medium hover:bg-slate-100"
              >
                ปิด
              </button>
              <button
                type="button"
                onClick={handlePrintAdmitCard}
                className="inline-flex items-center gap-1.5 px-5 py-2 rounded-xl bg-primary-container text-white text-sm font-semibold hover:bg-primary"
              >
                <span className="material-symbols-outlined text-[18px]">
                  print
                </span>
                <span>สั่งพิมพ์ / บันทึก PDF</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
