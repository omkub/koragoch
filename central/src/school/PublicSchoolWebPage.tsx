import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { logoSrc } from '../ui/SchoolLogo';
import {
  fetchPublicSchoolWebConfig,
  loadLocalPublicWebConfig,
  submitPublicContactMessage,
  type NewsFilterCat,
  type PublicNewsItem,
  type PublicSchoolWebConfig,
  type StaffDeptFilter,
} from './publicWebConfig';
import {
  lookupPublicStudentSgsTranscript,
  type PublicSgsStudentInfo,
  type StudentMultiYearTranscript,
} from './sgsGradingStore';
import PublicAdmissionTab from './PublicAdmissionTab';
import type { SchoolBasic } from './types';

interface PublicSchoolWebPageProps {
  school?: SchoolBasic | null;
  schools?: SchoolBasic[];
  isLoggedIn?: boolean;
  canManagePublicWeb?: boolean;
}

export type PublicPageTab =
  | 'home'
  | 'admission'
  | 'news'
  | 'staff'
  | 'students'
  | 'about'
  | 'contact';

const NAV_ITEMS: { key: PublicPageTab; label: string; icon: string }[] = [
  { key: 'home', label: 'หน้าแรก', icon: 'home' },
  { key: 'admission', label: 'รับสมัครนักเรียน', icon: 'how_to_reg' },
  { key: 'news', label: 'ข่าวประชาสัมพันธ์', icon: 'campaign' },
  { key: 'staff', label: 'ทำเนียบบุคลากร', icon: 'badge' },
  { key: 'students', label: 'ข้อมูลนักเรียน', icon: 'school' },
  { key: 'about', label: 'ข้อมูลโรงเรียน', icon: 'account_balance' },
  { key: 'contact', label: 'ติดต่อ', icon: 'mail' },
];

export default function PublicSchoolWebPage({
  school,
  schools = [],
  isLoggedIn = false,
  canManagePublicWeb = false,
}: PublicSchoolWebPageProps) {
  const { schoolId: schoolIdParam } = useParams<{ schoolId?: string }>();
  const navigate = useNavigate();

  const activeSchool = useMemo(() => {
    if (schoolIdParam && schools.length > 0) {
      const matched = schools.find(
        (s) => String(s.id_school) === schoolIdParam,
      );
      if (matched) return matched;
    }
    return school ?? schools[0] ?? null;
  }, [school, schoolIdParam, schools]);

  const activeSchoolId = activeSchool?.id_school ?? null;

  const [config, setConfig] = useState<PublicSchoolWebConfig>(() =>
    loadLocalPublicWebConfig(activeSchoolId),
  );

  useEffect(() => {
    let alive = true;
    setConfig(loadLocalPublicWebConfig(activeSchoolId));
    fetchPublicSchoolWebConfig(activeSchoolId).then((loaded) => {
      if (alive) setConfig(loaded);
    });
    return () => {
      alive = false;
    };
  }, [activeSchoolId]);

  const schoolDisplayName =
    activeSchool?.fullName || 'โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก';

  const schoolAffiliation =
    activeSchool?.affiliation ||
    'สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์ กระทรวงศึกษาธิการ';

  const [activeTab, setActiveTab] = useState<PublicPageTab>('home');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // News tab filters & modal
  const [newsSearch, setNewsSearch] = useState('');
  const [newsCat, setNewsCat] = useState<NewsFilterCat>('all');
  const [selectedArticle, setSelectedArticle] =
    useState<PublicNewsItem | null>(null);

  // Staff tab filter
  const [staffDept, setStaffDept] = useState<StaffDeptFilter>('all');

  // Student downloads interactive feedback state
  const [downloadStates, setDownloadStates] = useState<
    Record<string, 'idle' | 'loading' | 'done'>
  >({});

  // Contact form state
  const [contactName, setContactName] = useState('');
  const [contactEmailOrPhone, setContactEmailOrPhone] = useState('');
  const [contactSubject, setContactSubject] = useState('');
  const [contactMessage, setContactMessage] = useState('');
  const [contactSubmittedName, setContactSubmittedName] = useState<
    string | null
  >(null);

  // SGS Online Student Grade Lookup Modal state
  const [sgsModalOpen, setSgsModalOpen] = useState(false);
  const [sgsCodeInput, setSgsCodeInput] = useState('');
  const [sgsVerifyInput, setSgsVerifyInput] = useState('');
  const [sgsLoading, setSgsLoading] = useState(false);
  const [sgsError, setSgsError] = useState<string | null>(null);
  const [sgsStudentResult, setSgsStudentResult] =
    useState<PublicSgsStudentInfo | null>(null);
  const [sgsTranscriptResult, setSgsTranscriptResult] =
    useState<StudentMultiYearTranscript | null>(null);

  const handleLookupSgsOnline = async (e: React.FormEvent) => {
    e.preventDefault();
    setSgsLoading(true);
    setSgsError(null);
    const res = await lookupPublicStudentSgsTranscript({
      schoolId: activeSchoolId,
      studentCode: sgsCodeInput,
      verifyCode: sgsVerifyInput,
    });
    setSgsLoading(false);
    if (!res.ok || !res.student || !res.transcript) {
      setSgsError(res.error || 'ไม่พบข้อมูลผลการเรียนของรหัสนักเรียนที่ระบุ');
      setSgsStudentResult(null);
      setSgsTranscriptResult(null);
      return;
    }
    setSgsStudentResult(res.student);
    setSgsTranscriptResult(res.transcript);
  };

  const resolvedSchoolLogo = logoSrc(activeSchool?.logo);

  // Home page quick stats counter animation
  const [statsCount, setStatsCount] = useState(() => ({
    students: config.home.stats.studentsCount,
    staff: config.home.stats.staffCount,
    awards: config.home.stats.awardsCount,
    founded: config.home.stats.foundedYearBe,
  }));

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
    setMobileMenuOpen(false);
  }, [activeTab]);

  useEffect(() => {
    if (activeTab !== 'home') return;
    const target = config.home.stats;
    let frame = 0;
    const totalFrames = 24;
    const timer = window.setInterval(() => {
      frame += 1;
      const progress = Math.min(1, frame / totalFrames);
      const eased = 1 - Math.pow(1 - progress, 3);
      setStatsCount({
        students: Math.round(target.studentsCount * eased),
        staff: Math.round(target.staffCount * eased),
        awards: Math.round(target.awardsCount * eased),
        founded: Math.round(target.foundedYearBe * eased),
      });
      if (frame >= totalFrames) {
        window.clearInterval(timer);
      }
    }, 35);
    return () => window.clearInterval(timer);
  }, [activeTab, config.home.stats]);

  const homeNews = useMemo(() => {
    const chosen = config.news.filter(
      (item) => item.showOnHome || item.homeOrder !== undefined,
    );
    const list = chosen.length > 0 ? chosen : config.news.slice(0, 3);
    return [...list]
      .sort((a, b) => (a.homeOrder ?? 99) - (b.homeOrder ?? 99))
      .slice(0, 3);
  }, [config.news]);

  const publishedNews = useMemo(
    () =>
      config.news
        .filter((item) => item.status !== 'draft')
        .sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned))),
    [config.news],
  );

  const featuredNews = useMemo(() => {
    const featured =
      publishedNews.find((item) => item.isFeatured) ?? publishedNews[0] ?? null;
    if (!featured) return null;
    const q = newsSearch.trim().toLowerCase();
    const matchCat = newsCat === 'all' || featured.cat === newsCat;
    const matchQ =
      !q ||
      featured.title.toLowerCase().includes(q) ||
      featured.summary.toLowerCase().includes(q);
    return matchCat && matchQ ? featured : null;
  }, [publishedNews, newsCat, newsSearch]);

  const filteredGridNews = useMemo(() => {
    const featuredId =
      (publishedNews.find((item) => item.isFeatured) ?? publishedNews[0])?.id ??
      '';
    const q = newsSearch.trim().toLowerCase();
    return publishedNews
      .filter((item) => item.id !== featuredId)
      .filter((item) => {
        const matchCat = newsCat === 'all' || item.cat === newsCat;
        const matchQ =
          !q ||
          item.title.toLowerCase().includes(q) ||
          item.summary.toLowerCase().includes(q) ||
          item.badgeText.toLowerCase().includes(q);
        return matchCat && matchQ;
      });
  }, [publishedNews, newsCat, newsSearch]);

  const showExecutiveSection =
    staffDept === 'all' || staffDept === 'executive';
  const showTeachingSection = staffDept !== 'executive';

  const filteredTeachingStaff = useMemo(() => {
    if (staffDept === 'all') return config.staff.teachingStaff;
    return config.staff.teachingStaff.filter((s) => s.dept === staffDept);
  }, [config.staff.teachingStaff, staffDept]);

  // Student stats computed dynamically from config.students.grades
  const studentTotals = useMemo(() => {
    let totalMale = 0;
    let totalFemale = 0;
    let juniorTotal = 0;
    let seniorTotal = 0;
    let juniorRooms = 0;
    let seniorRooms = 0;
    let maxGradeTotal = 1;

    for (const g of config.students.grades) {
      const m = Number(g.male) || 0;
      const f = Number(g.female) || 0;
      const r = Number(g.roomsCount) || 0;
      const sum = m + f;
      totalMale += m;
      totalFemale += f;
      if (sum > maxGradeTotal) maxGradeTotal = sum;
      if (g.isSenior) {
        seniorTotal += sum;
        seniorRooms += r;
      } else {
        juniorTotal += sum;
        juniorRooms += r;
      }
    }

    const grandTotal = totalMale + totalFemale;
    const totalRooms = juniorRooms + seniorRooms;
    const juniorPct =
      grandTotal > 0 ? Number(((juniorTotal / grandTotal) * 100).toFixed(1)) : 50;
    const seniorPct =
      grandTotal > 0 ? Number((100 - juniorPct).toFixed(1)) : 50;
    const avgPerRoom =
      totalRooms > 0 ? Math.round(grandTotal / totalRooms) : 0;

    return {
      grandTotal,
      totalMale,
      totalFemale,
      juniorTotal,
      seniorTotal,
      juniorRooms,
      seniorRooms,
      totalRooms,
      juniorPct,
      seniorPct,
      avgPerRoom,
      maxGradeTotal,
    };
  }, [config.students.grades]);

  const handleTriggerDownload = (docId: string, fileUrl?: string) => {
    if (fileUrl && fileUrl.trim().startsWith('http')) {
      window.open(fileUrl.trim(), '_blank', 'noopener,noreferrer');
    }
    const current = downloadStates[docId] ?? 'idle';
    if (current !== 'idle') return;
    setDownloadStates((prev) => ({ ...prev, [docId]: 'loading' }));
    window.setTimeout(() => {
      setDownloadStates((prev) => ({ ...prev, [docId]: 'done' }));
      window.setTimeout(() => {
        setDownloadStates((prev) => ({ ...prev, [docId]: 'idle' }));
      }, 2400);
    }, 900);
  };

  const handleContactSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await submitPublicContactMessage(activeSchoolId, {
      name: contactName.trim() || 'ผู้ติดต่อ',
      emailOrPhone: contactEmailOrPhone,
      subject: contactSubject,
      message: contactMessage,
    });
    } catch {
      window.alert('ส่งข้อความไม่สำเร็จ กรุณาลองใหม่ หรือติดต่อโรงเรียนทางโทรศัพท์');
      return;
    }
    setContactSubmittedName(contactName.trim() || 'ผู้ติดต่อ');
    setContactName('');
    setContactEmailOrPhone('');
    setContactSubject('');
    setContactMessage('');
  };

  const switchTab = (tab: PublicPageTab) => {
    setActiveTab(tab);
  };

  const directorExec =
    config.staff.executives.find((e) => e.isDirector) ??
    config.staff.executives[0] ??
    null;
  const viceDirectors = config.staff.executives.filter(
    (e) => e.id !== directorExec?.id,
  );

  return (
    <div className="min-h-screen bg-surface font-body-md text-body-md text-on-surface flex flex-col">
      {/* ── Top Fixed Header (ตรงตาม webschool.html) ────────────────────── */}
      <header className="fixed top-0 w-full z-50 bg-surface-container-lowest/90 backdrop-blur-xl shadow-[0_1px_8px_rgba(0,0,0,0.04)] print:hidden">
        <div className="h-20 max-w-7xl mx-auto px-6 lg:px-12 flex items-center justify-between gap-space-md">
          <div className="flex items-center gap-space-md shrink-0">
            <button
              type="button"
              onClick={() => switchTab('home')}
              className="w-11 h-11 rounded-xl bg-primary-container flex items-center justify-center shrink-0 hover:bg-primary transition-colors overflow-hidden"
              title="กลับหน้าแรก"
            >
              {resolvedSchoolLogo ? (
                <img
                  src={resolvedSchoolLogo}
                  alt={schoolDisplayName}
                  className="w-full h-full object-contain bg-white p-0.5"
                />
              ) : (
                <span className="material-symbols-outlined text-on-primary text-[24px]">
                  school
                </span>
              )}
            </button>
            <div className="flex flex-col text-left">
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => switchTab('home')}
                  className="font-title-lg text-title-lg text-on-surface leading-tight hover:text-primary transition-colors text-left"
                >
                  {schoolDisplayName}
                </button>
                {schools.length > 1 && (
                  <select
                    aria-label="เลือกโรงเรียน"
                    value={activeSchool ? String(activeSchool.id_school) : ''}
                    onChange={(e) => {
                      const nextId = e.target.value;
                      if (nextId) navigate(`/public/${nextId}`);
                    }}
                    className="hidden xl:inline-block rounded-lg border border-outline-variant/50 bg-surface-container-low px-2 py-0.5 text-xs font-medium text-on-surface-variant focus:border-primary focus:outline-none"
                  >
                    {schools.map((s) => (
                      <option key={s.id_school} value={String(s.id_school)}>
                        {s.fullName || `โรงเรียน #${s.id_school}`}
                      </option>
                    ))}
                  </select>
                )}
              </div>
              <span className="font-body-sm text-body-sm text-on-surface-variant hidden sm:block">
                {schoolAffiliation}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-space-sm sm:gap-space-md">
            <nav className="hidden lg:flex items-center gap-space-xs">
              {NAV_ITEMS.map((item) => {
                const isActive = activeTab === item.key;
                return (
                  <button
                    key={item.key}
                    type="button"
                    aria-current={isActive ? 'page' : undefined}
                    onClick={() => switchTab(item.key)}
                    className={
                      isActive
                        ? 'px-4 py-2 font-label-lg text-label-lg transition-colors bg-primary-container text-on-primary rounded-full'
                        : 'px-4 py-2 rounded-full font-label-lg text-label-lg text-on-surface-variant hover:text-primary transition-colors'
                    }
                  >
                    {item.label}
                  </button>
                );
              })}
            </nav>

            {canManagePublicWeb && (
              <Link
                to="/public-web-settings"
                title="ตั้งค่าเนื้อหาหน้าเว็บโรงเรียนสาธารณะ"
                className="inline-flex items-center gap-1.5 rounded-full bg-secondary-fixed hover:bg-secondary-container px-3.5 py-2 font-label-md text-label-md text-on-secondary-fixed transition-colors"
              >
                <span className="material-symbols-outlined text-[18px]">
                  edit_note
                </span>
                <span className="hidden md:inline">ตั้งค่าเว็บสาธารณะ</span>
              </Link>
            )}

            <Link
              to="/"
              title={
                isLoggedIn
                  ? 'กลับสู่ระบบบริหารจัดการโรงเรียน'
                  : 'เข้าสู่ระบบสำหรับครูและบุคลากร'
              }
              className="inline-flex items-center gap-1.5 rounded-full bg-surface-container-low hover:bg-surface-container px-3.5 py-2 font-label-md text-label-md text-primary transition-colors"
            >
              <span className="material-symbols-outlined text-[20px]">
                account_circle
              </span>
              <span className="hidden sm:inline">
                {isLoggedIn ? 'ระบบบุคลากร' : 'สำหรับบุคลากร'}
              </span>
            </Link>

            {/* ปุ่มเมนูบนมือถือ */}
            <button
              type="button"
              onClick={() => setMobileMenuOpen((v) => !v)}
              aria-label="เปิดเมนูนำทาง"
              className="lg:hidden w-10 h-10 rounded-full bg-surface-container-low hover:bg-surface-container flex items-center justify-center text-on-surface transition-colors"
            >
              <span className="material-symbols-outlined text-[22px]">
                {mobileMenuOpen ? 'close' : 'menu'}
              </span>
            </button>
          </div>
        </div>

        {/* เมนูนำทางบนมือถือ */}
        {mobileMenuOpen && (
          <div className="lg:hidden border-t border-outline-variant/20 bg-surface-container-lowest px-6 py-4 shadow-lg">
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {NAV_ITEMS.map((item) => {
                const isActive = activeTab === item.key;
                return (
                  <button
                    key={item.key}
                    type="button"
                    onClick={() => switchTab(item.key)}
                    className={`flex items-center gap-2 px-4 py-2.5 rounded-xl font-label-lg text-label-lg transition-colors ${
                      isActive
                        ? 'bg-primary-container text-on-primary'
                        : 'bg-surface-container-low text-on-surface-variant hover:text-primary'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[18px]">
                      {item.icon}
                    </span>
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </header>

      {/* ════════════════════════════════════════════════════════════════════
          PAGE 1: หน้าแรก (HOME)
         ════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'home' && (
        <main className="pt-20 flex-1">
          {/* Hero Section */}
          <section className="relative overflow-hidden bg-gradient-to-br from-primary via-primary-container to-tertiary-container text-on-primary pt-12 pb-20 lg:py-24">
            <div
              className="absolute inset-0 opacity-10 pointer-events-none"
              style={{
                backgroundImage:
                  'radial-gradient(circle at 20% 20%, #ffffff 1px, transparent 1px)',
                backgroundSize: '32px 32px',
              }}
            />
            <div className="max-w-7xl mx-auto px-6 lg:px-12 relative z-10">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
                <div className="lg:col-span-7 flex flex-col items-start gap-space-lg">
                  <div className="inline-flex items-center gap-space-sm px-4 py-1.5 rounded-full bg-surface-container-lowest/15 backdrop-blur-md">
                    <span className="w-2 h-2 rounded-full bg-secondary-container" />
                    <span className="font-label-md text-label-md text-primary-fixed tracking-wide uppercase">
                      {config.home.heroBadge}
                    </span>
                  </div>
                  <h1 className="font-display-lg text-display-lg-mobile lg:text-display-lg text-on-primary">
                    {config.home.heroTitle}
                  </h1>
                  <p className="font-body-lg text-body-lg text-primary-fixed max-w-2xl">
                    {schoolDisplayName} {config.home.heroSubtitle}
                  </p>
                  <div className="flex flex-wrap items-center gap-space-md pt-2">
                    <button
                      type="button"
                      onClick={() => switchTab('news')}
                      className="inline-flex items-center gap-space-sm px-6 py-3.5 rounded-xl bg-secondary-container text-on-secondary-fixed font-label-lg text-label-lg shadow-sm hover:opacity-95 transition-opacity"
                    >
                      <span>ดูข่าวประชาสัมพันธ์</span>
                      <span className="material-symbols-outlined text-[20px]">
                        arrow_forward
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setNewsCat('admission');
                        switchTab('news');
                      }}
                      className="inline-flex items-center gap-space-sm px-6 py-3.5 rounded-xl bg-surface-container-lowest/10 hover:bg-surface-container-lowest/20 text-on-primary font-label-lg text-label-lg backdrop-blur-md transition-colors"
                    >
                      <span className="material-symbols-outlined text-[20px]">
                        how_to_reg
                      </span>
                      <span>ข้อมูลการรับสมัครนักเรียน</span>
                    </button>
                  </div>
                </div>

                <div className="lg:col-span-5">
                  <div className="relative rounded-2xl overflow-hidden shadow-[0_20px_48px_rgba(0,0,0,0.28)] bg-surface-container-lowest/10 p-2 backdrop-blur-sm">
                    <img
                      alt={`อาคารเรียนและบรรยากาศ${schoolDisplayName}`}
                      className="w-full h-[340px] lg:h-[400px] object-cover rounded-xl"
                      src={config.home.heroImageUrl}
                    />
                    <div className="absolute bottom-5 left-5 right-5 rounded-xl bg-surface-container-lowest/95 backdrop-blur-xl p-4 shadow-[0_12px_32px_rgba(13,28,46,0.12)] flex items-center justify-between gap-space-md">
                      <div className="flex items-center gap-space-md">
                        <div className="w-10 h-10 rounded-lg bg-secondary-fixed flex items-center justify-center shrink-0">
                          <span className="material-symbols-outlined text-secondary text-[22px]">
                            campaign
                          </span>
                        </div>
                        <div>
                          <p className="font-label-lg text-label-lg text-on-surface">
                            {config.home.admissionBannerTitle}
                          </p>
                          <p className="font-label-md text-label-md text-on-surface-variant">
                            {config.home.admissionBannerSubtitle}
                          </p>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          setNewsCat('admission');
                          switchTab('news');
                        }}
                        className="font-label-md text-label-md text-primary hover:underline shrink-0"
                      >
                        รายละเอียด →
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Floating Quick Stats */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 -mt-10 relative z-20">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-surface-container-lowest rounded-xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-center gap-space-md">
                <div className="w-12 h-12 rounded-xl bg-primary-fixed flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-primary text-[26px]">
                    groups
                  </span>
                </div>
                <div>
                  <p className="font-headline-lg text-headline-lg text-primary leading-none tabular-nums">
                    {statsCount.students.toLocaleString()}+
                  </p>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                    จำนวนนักเรียนทั้งหมด
                  </p>
                </div>
              </div>

              <div className="bg-surface-container-lowest rounded-xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-center gap-space-md">
                <div className="w-12 h-12 rounded-xl bg-tertiary-fixed flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-tertiary text-[26px]">
                    badge
                  </span>
                </div>
                <div>
                  <p className="font-headline-lg text-headline-lg text-primary leading-none tabular-nums">
                    {statsCount.staff}
                  </p>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                    ข้าราชการครูและบุคลากร
                  </p>
                </div>
              </div>

              <div className="bg-surface-container-lowest rounded-xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-center gap-space-md">
                <div className="w-12 h-12 rounded-xl bg-secondary-fixed flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-secondary text-[26px]">
                    emoji_events
                  </span>
                </div>
                <div>
                  <p className="font-headline-lg text-headline-lg text-primary leading-none tabular-nums">
                    {statsCount.awards}+
                  </p>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                    รางวัลเกียรติยศระดับชาติ
                  </p>
                </div>
              </div>

              <div className="bg-surface-container-lowest rounded-xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-center gap-space-md">
                <div className="w-12 h-12 rounded-xl bg-surface-container-high flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-primary-container text-[26px]">
                    account_balance
                  </span>
                </div>
                <div>
                  <p className="font-headline-lg text-headline-lg text-primary leading-none tabular-nums">
                    พ.ศ. {statsCount.founded}
                  </p>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                    ปีที่ก่อตั้งโรงเรียน
                  </p>
                </div>
              </div>
            </div>
          </section>

          {/* Latest News Section */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 py-16">
            <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-space-md mb-10">
              <div>
                <span className="font-label-lg text-label-lg text-secondary uppercase tracking-wider">
                  ข่าวสารและประกาศล่าสุด
                </span>
                <h2 className="font-headline-lg text-headline-lg text-on-surface mt-1">
                  ข่าวประชาสัมพันธ์โรงเรียน
                </h2>
              </div>
              <button
                type="button"
                onClick={() => switchTab('news')}
                className="inline-flex items-center gap-space-xs font-label-lg text-label-lg text-primary hover:text-primary-container transition-colors"
              >
                <span>ดูข่าวสารทั้งหมด</span>
                <span className="material-symbols-outlined text-[20px]">
                  chevron_right
                </span>
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {homeNews.map((item) => (
                <article
                  key={item.id}
                  onClick={() => setSelectedArticle(item)}
                  className="cursor-pointer bg-surface-container-lowest rounded-xl overflow-hidden shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col justify-between group hover:-translate-y-1 transition-transform"
                >
                  <div>
                    <div className="relative h-52 overflow-hidden">
                      <img
                        alt={item.imageAlt}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                        src={item.imageUrl}
                      />
                      <span
                        className={`absolute top-4 left-4 px-3 py-1 rounded-full font-label-sm text-label-sm ${
                          item.badgeStyle === 'secondary'
                            ? 'bg-secondary-container text-on-secondary-fixed'
                            : item.badgeStyle === 'tertiary'
                              ? 'bg-tertiary-fixed text-on-tertiary-fixed'
                              : 'bg-primary-fixed text-on-primary-fixed'
                        }`}
                      >
                        {item.badgeText}
                      </span>
                    </div>
                    <div className="p-6">
                      <div className="flex items-center gap-space-xs text-on-surface-variant font-label-md text-label-md mb-2">
                        <span className="material-symbols-outlined text-[16px]">
                          calendar_today
                        </span>
                        <span>{item.dateLabel}</span>
                      </div>
                      <h3 className="font-title-lg text-title-lg text-on-surface line-clamp-2 group-hover:text-primary transition-colors">
                        {item.title}
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-2 line-clamp-2">
                        {item.summary}
                      </p>
                    </div>
                  </div>
                  <div className="px-6 pb-6">
                    <span className="inline-flex items-center gap-space-xs font-label-lg text-label-lg text-primary">
                      <span>อ่านรายละเอียด</span>
                      <span className="material-symbols-outlined text-[18px]">
                        arrow_forward
                      </span>
                    </span>
                  </div>
                </article>
              ))}
            </div>
          </section>

          {/* Upcoming Events & Quick Services */}
          <section className="bg-surface-container-low py-16">
            <div className="max-w-7xl mx-auto px-6 lg:px-12">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
                {/* Upcoming Events Calendar */}
                <div className="lg:col-span-7 flex flex-col justify-between">
                  <div>
                    <span className="font-label-lg text-label-lg text-secondary uppercase tracking-wider">
                      ปฏิทินการศึกษา
                    </span>
                    <h2 className="font-headline-md text-headline-md text-on-surface mt-1 mb-6">
                      กิจกรรมและกำหนดการสำคัญ
                    </h2>
                    <div className="flex flex-col gap-space-md">
                      {config.home.events.map((ev) => (
                        <div
                          key={ev.id}
                          className="bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.04)] flex items-center gap-space-lg"
                        >
                          <div
                            className={`w-16 h-16 rounded-xl flex flex-col items-center justify-center shrink-0 ${
                              ev.tone === 'secondary'
                                ? 'bg-secondary-fixed text-on-secondary-fixed'
                                : ev.tone === 'tertiary'
                                  ? 'bg-tertiary-fixed text-on-tertiary-fixed'
                                  : 'bg-primary-container text-on-primary'
                            }`}
                          >
                            <span className="font-headline-sm text-headline-sm leading-none">
                              {ev.day}
                            </span>
                            <span className="font-label-sm text-label-sm uppercase mt-0.5">
                              {ev.month}
                            </span>
                          </div>
                          <div className="flex-1">
                            <h3 className="font-title-md text-title-md text-on-surface">
                              {ev.title}
                            </h3>
                            <p className="font-body-sm text-body-sm text-on-surface-variant mt-0.5">
                              {ev.subtitle}
                            </p>
                          </div>
                          <span
                            className={`px-3 py-1 rounded-full font-label-sm text-label-sm hidden sm:inline-block ${
                              ev.tone === 'secondary'
                                ? 'bg-secondary-fixed text-on-secondary-fixed'
                                : ev.tone === 'tertiary'
                                  ? 'bg-tertiary-fixed text-on-tertiary-fixed'
                                  : 'bg-primary-fixed text-on-primary-fixed'
                            }`}
                          >
                            {ev.tag}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Quick Services */}
                <div className="lg:col-span-5 flex flex-col justify-between">
                  <div>
                    <span className="font-label-lg text-label-lg text-primary uppercase tracking-wider">
                      บริการออนไลน์
                    </span>
                    <h2 className="font-headline-md text-headline-md text-on-surface mt-1 mb-6">
                      ระบบสารสนเทศและบริการด่วน
                    </h2>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <button
                        type="button"
                        onClick={() => switchTab('students')}
                        className="text-left bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.04)] hover:bg-primary-container hover:text-on-primary group transition-colors flex flex-col justify-between h-36"
                      >
                        <div className="w-10 h-10 rounded-lg bg-primary-fixed group-hover:bg-surface-container-lowest/20 flex items-center justify-center">
                          <span className="material-symbols-outlined text-primary group-hover:text-on-primary">
                            assignment_ind
                          </span>
                        </div>
                        <div>
                          <p className="font-title-md text-title-md text-on-surface group-hover:text-on-primary">
                            ระบบดูแลช่วยเหลือนักเรียน
                          </p>
                          <p className="font-label-md text-label-md text-on-surface-variant group-hover:text-primary-fixed">
                            ข้อมูลนักเรียนและสวัสดิการ
                          </p>
                        </div>
                      </button>

                      <button
                        type="button"
                        onClick={() => switchTab('students')}
                        className="text-left bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.04)] hover:bg-primary-container hover:text-on-primary group transition-colors flex flex-col justify-between h-36"
                      >
                        <div className="w-10 h-10 rounded-lg bg-secondary-fixed group-hover:bg-surface-container-lowest/20 flex items-center justify-center">
                          <span className="material-symbols-outlined text-secondary group-hover:text-on-primary">
                            menu_book
                          </span>
                        </div>
                        <div>
                          <p className="font-title-md text-title-md text-on-surface group-hover:text-on-primary">
                            ตารางเรียนและตารางสอบ
                          </p>
                          <p className="font-label-md text-label-md text-on-surface-variant group-hover:text-primary-fixed">
                            ภาคเรียนที่ 1/2568
                          </p>
                        </div>
                      </button>

                      <button
                        type="button"
                        onClick={() => switchTab('students')}
                        className="text-left bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.04)] hover:bg-primary-container hover:text-on-primary group transition-colors flex flex-col justify-between h-36"
                      >
                        <div className="w-10 h-10 rounded-lg bg-tertiary-fixed group-hover:bg-surface-container-lowest/20 flex items-center justify-center">
                          <span className="material-symbols-outlined text-tertiary group-hover:text-on-primary">
                            description
                          </span>
                        </div>
                        <div>
                          <p className="font-title-md text-title-md text-on-surface group-hover:text-on-primary">
                            ดาวน์โหลดเอกสาร
                          </p>
                          <p className="font-label-md text-label-md text-on-surface-variant group-hover:text-primary-fixed">
                            คำร้อง ปพ.1 และระเบียบการ
                          </p>
                        </div>
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setSgsError(null);
                          setSgsModalOpen(true);
                        }}
                        className="text-left bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.04)] hover:bg-primary-container hover:text-on-primary group transition-colors flex flex-col justify-between h-36"
                      >
                        <div className="w-10 h-10 rounded-lg bg-primary-fixed group-hover:bg-surface-container-lowest/20 flex items-center justify-center">
                          <span className="material-symbols-outlined text-primary group-hover:text-on-primary">
                            analytics
                          </span>
                        </div>
                        <div>
                          <p className="font-title-md text-title-md text-on-surface group-hover:text-on-primary">
                            ระบบตรวจสอบผลการเรียน
                          </p>
                          <p className="font-label-md text-label-md text-on-surface-variant group-hover:text-primary-fixed">
                            SGS สำหรับนักเรียน/ผู้ปกครอง
                          </p>
                        </div>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Director's Message & School Identity */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 py-16">
            <div className="bg-surface-container-lowest rounded-2xl p-8 lg:p-12 shadow-[0_12px_32px_rgba(13,28,46,0.06)] grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
              <div className="lg:col-span-4 flex flex-col items-center text-center">
                <div className="w-44 h-44 rounded-2xl overflow-hidden shadow-md mb-4 bg-surface-container">
                  <img
                    alt={`ผู้อำนวยการ${schoolDisplayName}`}
                    className="w-full h-full object-cover"
                    src={config.home.director.imageUrl}
                  />
                </div>
                <h3 className="font-title-lg text-title-lg text-on-surface">
                  {config.home.director.name}
                </h3>
                <p className="font-body-sm text-body-sm text-on-surface-variant">
                  {config.home.director.position}
                  {schoolDisplayName}
                </p>
                <span className="mt-2 px-3 py-1 rounded-full bg-primary-fixed text-on-primary-fixed font-label-sm text-label-sm">
                  {config.home.director.standing}
                </span>
              </div>

              <div className="lg:col-span-8 flex flex-col gap-space-md">
                <span className="font-label-lg text-label-lg text-secondary uppercase tracking-wider">
                  สารจากผู้อำนวยการ
                </span>
                <h2 className="font-headline-md text-headline-md text-primary">
                  {config.home.director.headline}
                </h2>
                <p className="font-body-md text-body-md text-on-surface-variant">
                  {schoolDisplayName} {config.home.director.message}
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
                  <div className="p-4 rounded-xl bg-surface-container-low">
                    <p className="font-label-lg text-label-lg text-primary">
                      อัตลักษณ์โรงเรียน
                    </p>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                      {config.about.identityTitle}
                    </p>
                  </div>
                  <div className="p-4 rounded-xl bg-surface-container-low">
                    <p className="font-label-lg text-label-lg text-primary">
                      ปรัชญาโรงเรียน
                    </p>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                      {config.about.philosophyTitle} —{' '}
                      {config.about.philosophyDesc}
                    </p>
                  </div>
                </div>
                <div className="pt-2 flex flex-wrap gap-space-md">
                  <button
                    type="button"
                    onClick={() => switchTab('about')}
                    className="inline-flex items-center gap-space-xs font-label-lg text-label-lg text-primary hover:underline"
                  >
                    <span>อ่านประวัติและวิสัยทัศน์โรงเรียน</span>
                    <span className="material-symbols-outlined text-[18px]">
                      arrow_forward
                    </span>
                  </button>
                  <button
                    type="button"
                    onClick={() => switchTab('staff')}
                    className="inline-flex items-center gap-space-xs font-label-lg text-label-lg text-secondary hover:underline"
                  >
                    <span>ทำเนียบผู้บริหารและครูอาจารย์</span>
                    <span className="material-symbols-outlined text-[18px]">
                      arrow_forward
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </section>
        </main>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          PAGE 1.5: รับสมัครนักเรียน (STUDENT ADMISSION ONLINE)
         ════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'admission' && (
        <PublicAdmissionTab
          schoolId={activeSchoolId}
          schoolDisplayName={schoolDisplayName}
          schoolSubTitle={schoolAffiliation}
          admission={config.admission}
        />
      )}

      {/* ════════════════════════════════════════════════════════════════════
          PAGE 2: ข่าวประชาสัมพันธ์ (NEWSROOM)
         ════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'news' && (
        <main className="pt-20 flex-1">
          {/* Page Header & Search Banner */}
          <section className="bg-gradient-to-br from-primary via-primary-container to-tertiary-container text-on-primary py-14 lg:py-16">
            <div className="max-w-7xl mx-auto px-6 lg:px-12">
              <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-8">
                <div className="max-w-2xl">
                  <div className="inline-flex items-center gap-space-sm px-3.5 py-1 rounded-full bg-surface-container-lowest/15 backdrop-blur-md mb-4">
                    <span className="w-2 h-2 rounded-full bg-secondary-container" />
                    <span className="font-label-md text-label-md text-primary-fixed tracking-wider uppercase">
                      01 / NEWSROOM • ศูนย์ข่าวสารและประกาศ
                    </span>
                  </div>
                  <h1 className="font-display-lg text-display-lg-mobile lg:text-display-lg text-on-primary">
                    ข่าวประชาสัมพันธ์และประกาศโรงเรียน
                  </h1>
                  <p className="font-body-md text-body-md text-primary-fixed mt-3">
                    ติดตามข่าวสารความเคลื่อนไหว กิจกรรมวิชาการ ประกาศรับสมัครนักเรียน
                    และข่าวจัดซื้อจัดจ้างของ{schoolDisplayName}
                  </p>
                </div>

                {/* Search Input */}
                <div className="w-full lg:w-96">
                  <div className="relative flex items-center bg-surface-container-lowest rounded-xl shadow-[0_12px_32px_rgba(13,28,46,0.16)] px-4 py-3">
                    <span className="material-symbols-outlined text-on-surface-variant text-[22px] mr-3">
                      search
                    </span>
                    <input
                      type="text"
                      value={newsSearch}
                      onChange={(e) => setNewsSearch(e.target.value)}
                      placeholder="ค้นหาข่าวสาร กิจกรรม หรือประกาศ..."
                      className="w-full bg-transparent text-on-surface placeholder:text-on-surface-variant/70 font-body-sm text-body-sm focus:outline-none"
                    />
                    {newsSearch && (
                      <button
                        type="button"
                        onClick={() => setNewsSearch('')}
                        className="text-on-surface-variant hover:text-on-surface ml-2"
                        aria-label="ล้างคำค้นหา"
                      >
                        <span className="material-symbols-outlined text-[18px]">
                          close
                        </span>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Category Filter Chips */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 -mt-6 relative z-20">
            <div className="bg-surface-container-lowest rounded-2xl p-4 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-wrap items-center justify-between gap-4">
              <div className="flex flex-wrap items-center gap-2">
                {(
                  [
                    { key: 'all', label: 'ทั้งหมด' },
                    { key: 'academic', label: 'ข่าววิชาการ' },
                    { key: 'activity', label: 'กิจกรรมนักเรียน' },
                    { key: 'admission', label: 'ประกาศรับสมัคร' },
                    { key: 'procurement', label: 'จัดซื้อจัดจ้าง' },
                  ] as { key: NewsFilterCat; label: string }[]
                ).map((cat) => {
                  const isActive = newsCat === cat.key;
                  return (
                    <button
                      key={cat.key}
                      type="button"
                      onClick={() => setNewsCat(cat.key)}
                      className={
                        isActive
                          ? 'px-4 py-2 rounded-full bg-primary-container text-on-primary font-label-lg text-label-lg transition-colors'
                          : 'px-4 py-2 rounded-full bg-surface-container-low text-on-surface-variant hover:bg-surface-container font-label-lg text-label-lg transition-colors'
                      }
                    >
                      {cat.label}
                    </button>
                  );
                })}
              </div>
              <div className="font-label-md text-label-md text-on-surface-variant">
                แสดง{' '}
                <span className="font-semibold text-primary">
                  {(featuredNews ? 1 : 0) + filteredGridNews.length}
                </span>{' '}
                รายการ
              </div>
            </div>
          </section>

          {/* Featured News Banner */}
          {featuredNews && (
            <section className="max-w-7xl mx-auto px-6 lg:px-12 pt-10 pb-6">
              <article
                onClick={() => setSelectedArticle(featuredNews)}
                className="cursor-pointer bg-surface-container-lowest rounded-2xl overflow-hidden shadow-[0_12px_32px_rgba(13,28,46,0.06)] grid grid-cols-1 lg:grid-cols-12 group"
              >
                <div className="lg:col-span-7 relative min-h-[280px] lg:min-h-[380px] overflow-hidden">
                  <img
                    alt={featuredNews.imageAlt}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                    src={featuredNews.imageUrl}
                  />
                  <div className="absolute top-4 left-4 flex items-center gap-2">
                    <span className="px-3.5 py-1.5 rounded-full bg-secondary-container text-on-secondary-fixed font-label-md text-label-md shadow-sm">
                      ข่าวเด่นประจำสัปดาห์
                    </span>
                    <span className="px-3.5 py-1.5 rounded-full bg-surface-container-lowest/90 backdrop-blur-md text-primary font-label-md text-label-md">
                      {featuredNews.badgeText}
                    </span>
                  </div>
                </div>

                <div className="lg:col-span-5 p-8 lg:p-10 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center gap-space-xs text-on-surface-variant font-label-md text-label-md mb-3">
                      <span className="material-symbols-outlined text-[18px]">
                        calendar_today
                      </span>
                      <span>{featuredNews.dateLabel}</span>
                      <span>•</span>
                      <span>{featuredNews.authorRole || 'ฝ่ายวิชาการ'}</span>
                    </div>
                    <h2 className="font-headline-md text-headline-md text-on-surface group-hover:text-primary transition-colors">
                      {featuredNews.title}
                    </h2>
                    <p className="font-body-md text-body-md text-on-surface-variant mt-4">
                      {featuredNews.summary}
                    </p>
                  </div>

                  <div className="pt-6 mt-6 border-t border-outline-variant/20 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-primary-fixed flex items-center justify-center text-primary">
                        <span className="material-symbols-outlined text-[18px]">
                          science
                        </span>
                      </div>
                      <div>
                        <p className="font-label-md text-label-md text-on-surface">
                          {featuredNews.author}
                        </p>
                        <p className="font-label-sm text-label-sm text-on-surface-variant">
                          ผู้เผยแพร่ข่าว
                        </p>
                      </div>
                    </div>
                    <span className="inline-flex items-center gap-space-xs px-4 py-2 rounded-xl bg-primary-container text-on-primary font-label-lg text-label-lg hover:bg-primary transition-colors">
                      <span>อ่านข่าวเต็ม</span>
                      <span className="material-symbols-outlined text-[18px]">
                        arrow_forward
                      </span>
                    </span>
                  </div>
                </div>
              </article>
            </section>
          )}

          {/* News Grid */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 py-8 pb-20">
            {filteredGridNews.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {filteredGridNews.map((item) => (
                  <article
                    key={item.id}
                    onClick={() => setSelectedArticle(item)}
                    className="cursor-pointer bg-surface-container-lowest rounded-xl overflow-hidden shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col justify-between group hover:-translate-y-1 transition-transform"
                  >
                    <div>
                      <div className="relative h-52 overflow-hidden">
                        <img
                          alt={item.imageAlt}
                          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                          src={item.imageUrl}
                        />
                        <span
                          className={`absolute top-4 left-4 px-3 py-1 rounded-full font-label-sm text-label-sm ${
                            item.badgeStyle === 'secondary'
                              ? 'bg-secondary-container text-on-secondary-fixed'
                              : item.badgeStyle === 'tertiary'
                                ? 'bg-tertiary-fixed text-on-tertiary-fixed'
                                : item.badgeStyle === 'surface'
                                  ? 'bg-surface-container-highest text-on-surface'
                                  : 'bg-primary-fixed text-on-primary-fixed'
                          }`}
                        >
                          {item.badgeText}
                        </span>
                      </div>
                      <div className="p-6">
                        <div className="flex items-center gap-space-xs text-on-surface-variant font-label-md text-label-md mb-2">
                          <span className="material-symbols-outlined text-[16px]">
                            calendar_today
                          </span>
                          <span>{item.dateLabel}</span>
                        </div>
                        <h3 className="font-title-lg text-title-lg text-on-surface line-clamp-2 group-hover:text-primary transition-colors">
                          {item.title}
                        </h3>
                        <p className="font-body-sm text-body-sm text-on-surface-variant mt-2 line-clamp-2">
                          {item.summary}
                        </p>
                      </div>
                    </div>
                    <div className="px-6 pb-6 pt-2 flex items-center justify-between">
                      <span className="inline-flex items-center gap-space-xs font-label-lg text-label-lg text-primary">
                        <span>อ่านรายละเอียด</span>
                        <span className="material-symbols-outlined text-[18px]">
                          arrow_forward
                        </span>
                      </span>
                      <span className="font-label-sm text-label-sm text-on-surface-variant">
                        {item.authorRole}
                      </span>
                    </div>
                  </article>
                ))}
              </div>
            ) : (
              !featuredNews && (
                <div className="text-center py-16 bg-surface-container-low rounded-2xl mt-6">
                  <span className="material-symbols-outlined text-on-surface-variant text-[48px] mb-2">
                    search_off
                  </span>
                  <h3 className="font-title-lg text-title-lg text-on-surface">
                    ไม่พบข่าวสารที่คุณค้นหา
                  </h3>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                    ลองเปลี่ยนคำค้นหา หรือเลือกหมวดหมู่ &ldquo;ทั้งหมด&rdquo;
                  </p>
                </div>
              )
            )}

            {/* Pagination */}
            <div className="mt-12 flex items-center justify-center gap-2">
              <button
                type="button"
                className="w-10 h-10 rounded-xl bg-surface-container-low text-on-surface-variant flex items-center justify-center hover:bg-surface-container transition-colors"
                aria-label="หน้าก่อนหน้า"
              >
                <span className="material-symbols-outlined text-[20px]">
                  chevron_left
                </span>
              </button>
              <button
                type="button"
                className="w-10 h-10 rounded-xl bg-primary-container text-on-primary font-label-lg text-label-lg flex items-center justify-center"
              >
                1
              </button>
              <button
                type="button"
                onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
                className="w-10 h-10 rounded-xl bg-surface-container-low text-on-surface hover:bg-surface-container font-label-lg text-label-lg flex items-center justify-center transition-colors"
              >
                2
              </button>
              <button
                type="button"
                onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
                className="w-10 h-10 rounded-xl bg-surface-container-low text-on-surface hover:bg-surface-container font-label-lg text-label-lg flex items-center justify-center transition-colors"
              >
                3
              </button>
              <button
                type="button"
                onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
                className="w-10 h-10 rounded-xl bg-surface-container-low text-on-surface-variant flex items-center justify-center hover:bg-surface-container transition-colors"
                aria-label="หน้าถัดไป"
              >
                <span className="material-symbols-outlined text-[20px]">
                  chevron_right
                </span>
              </button>
            </div>
          </section>
        </main>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          PAGE 3: ทำเนียบบุคลากร (STAFF DIRECTORY)
         ════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'staff' && (
        <main className="pt-20 flex-1">
          {/* Page Header */}
          <section className="relative overflow-hidden bg-gradient-to-br from-primary via-primary-container to-tertiary-container text-on-primary py-14 lg:py-16">
            <div
              className="absolute inset-0 opacity-10 pointer-events-none"
              style={{
                backgroundImage:
                  'radial-gradient(circle at 20% 20%, #ffffff 1px, transparent 1px)',
                backgroundSize: '32px 32px',
              }}
            />
            <div className="max-w-7xl mx-auto px-6 lg:px-12 relative z-10">
              <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-6">
                <div>
                  <div className="inline-flex items-center gap-space-sm px-4 py-1.5 rounded-full bg-surface-container-lowest/15 backdrop-blur-md mb-4">
                    <span className="w-2 h-2 rounded-full bg-secondary-container" />
                    <span className="font-label-md text-label-md text-primary-fixed tracking-wide uppercase">
                      ทำเนียบบุคลากร • ประจำปีการศึกษา{' '}
                      {config.staff.academicYearLabel}
                    </span>
                  </div>
                  <h1 className="font-display-lg text-display-lg-mobile lg:text-display-lg text-on-primary">
                    คณะผู้บริหาร คณาจารย์ และบุคลากร
                  </h1>
                  <p className="font-body-lg text-body-lg text-primary-fixed max-w-2xl mt-2">
                    ทีมบริหารและคณาจารย์ผู้เชี่ยวชาญในทุกกลุ่มสาระการเรียนรู้
                    มุ่งมั่นพัฒนาศักยภาพผู้เรียนสู่มาตรฐานสากล
                  </p>
                </div>

                <div className="bg-surface-container-lowest/10 backdrop-blur-md rounded-xl p-4 flex items-center gap-space-md shrink-0">
                  <div className="w-12 h-12 rounded-lg bg-secondary-container text-on-secondary-fixed flex items-center justify-center">
                    <span className="material-symbols-outlined text-[26px]">
                      groups
                    </span>
                  </div>
                  <div>
                    <p className="font-headline-md text-headline-md text-on-primary leading-none">
                      {config.staff.totalStaffLabel}
                    </p>
                    <p className="font-label-md text-label-md text-primary-fixed mt-1">
                      บุคลากรทั้งหมดในสถานศึกษา
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Department Filter Bar */}
          <section className="bg-surface-container-low py-4 sticky top-20 z-40 shadow-[0_4px_16px_rgba(13,28,46,0.04)]">
            <div className="max-w-7xl mx-auto px-6 lg:px-12">
              <div className="flex items-center gap-2 overflow-x-auto py-1">
                {(
                  [
                    { key: 'all', label: 'ทั้งหมด', icon: 'apps' },
                    { key: 'executive', label: 'คณะผู้บริหาร' },
                    { key: 'thai', label: 'ภาษาไทย' },
                    { key: 'math', label: 'คณิตศาสตร์' },
                    { key: 'science', label: 'วิทยาศาสตร์และเทคโนโลยี' },
                    { key: 'social', label: 'สังคมศึกษา' },
                    { key: 'foreign', label: 'ภาษาต่างประเทศ' },
                    { key: 'support', label: 'ฝ่ายสนับสนุน' },
                  ] as { key: StaffDeptFilter; label: string; icon?: string }[]
                ).map((item) => {
                  const isActive = staffDept === item.key;
                  return (
                    <button
                      key={item.key}
                      type="button"
                      onClick={() => setStaffDept(item.key)}
                      className={
                        isActive
                          ? 'px-4 py-2 rounded-full font-label-lg text-label-lg bg-primary-container text-on-primary shrink-0 transition-all flex items-center gap-1.5'
                          : 'px-4 py-2 rounded-full font-label-lg text-label-lg bg-surface-container-lowest text-on-surface-variant hover:text-primary shrink-0 transition-all flex items-center gap-1.5'
                      }
                    >
                      {item.icon && (
                        <span className="material-symbols-outlined text-[18px]">
                          {item.icon}
                        </span>
                      )}
                      <span>{item.label}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          </section>

          {/* Section 1: Executive Team */}
          {showExecutiveSection && (
            <section className="max-w-7xl mx-auto px-6 lg:px-12 py-12">
              <div className="mb-8">
                <span className="font-label-lg text-label-lg text-secondary uppercase tracking-wider">
                  01 / EXECUTIVE LEADERSHIP
                </span>
                <h2 className="font-headline-lg text-headline-lg text-on-surface mt-1">
                  คณะผู้บริหารสถานศึกษา
                </h2>
              </div>

              {/* Featured Director Card */}
              {directorExec && (
                <div className="bg-surface-container-lowest rounded-2xl p-6 lg:p-8 shadow-[0_12px_32px_rgba(13,28,46,0.06)] mb-8">
                  <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
                    <div className="lg:col-span-4 flex justify-center">
                      <div className="relative w-64 h-72 rounded-xl overflow-hidden bg-surface-container-low shadow-sm">
                        <img
                          alt={`${directorExec.name} ${directorExec.role}`}
                          className="w-full h-full object-cover object-top"
                          src={directorExec.imageUrl}
                        />
                        <div className="absolute bottom-3 left-3 right-3 px-3 py-1.5 rounded-lg bg-primary-container/90 backdrop-blur-md text-on-primary text-center">
                          <span className="font-label-md text-label-md">
                            {directorExec.deptBadgeText}
                          </span>
                        </div>
                      </div>
                    </div>
                    <div className="lg:col-span-8 flex flex-col gap-space-md">
                      <div className="inline-flex items-center gap-space-xs px-3 py-1 rounded-full bg-secondary-fixed text-on-secondary-fixed font-label-md text-label-md w-fit">
                        <span className="material-symbols-outlined text-[16px]">
                          verified
                        </span>
                        <span>ผู้บริหารสูงสุด</span>
                      </div>
                      <div>
                        <h3 className="font-headline-lg text-headline-lg text-on-surface">
                          {directorExec.name}
                        </h3>
                        <p className="font-title-md text-title-md text-primary mt-1">
                          {directorExec.role}
                          {schoolDisplayName}
                        </p>
                      </div>
                      {directorExec.quote && (
                        <p className="font-body-md text-body-md text-on-surface-variant bg-surface-container-low p-4 rounded-xl">
                          {directorExec.quote}
                        </p>
                      )}
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
                        <div className="flex items-center gap-space-sm text-on-surface-variant">
                          <span className="material-symbols-outlined text-primary text-[20px]">
                            school
                          </span>
                          <span className="font-body-sm text-body-sm">
                            {directorExec.education ||
                              'กศ.ม. (การบริหารการศึกษา)'}
                          </span>
                        </div>
                        {directorExec.email && (
                          <div className="flex items-center gap-space-sm text-on-surface-variant">
                            <span className="material-symbols-outlined text-primary text-[20px]">
                              mail
                            </span>
                            <span className="font-body-sm text-body-sm">
                              {directorExec.email}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Vice Directors Grid */}
              {viceDirectors.length > 0 && (
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  {viceDirectors.map((vp) => (
                    <div
                      key={vp.id}
                      className="bg-surface-container-lowest rounded-xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col items-center text-center"
                    >
                      <div className="w-36 h-40 rounded-xl overflow-hidden bg-surface-container-low mb-4">
                        <img
                          alt={`${vp.name} ${vp.role}`}
                          className="w-full h-full object-cover object-top"
                          src={vp.imageUrl}
                        />
                      </div>
                      <span className="px-3 py-1 rounded-full bg-primary-fixed text-on-primary-fixed font-label-sm text-label-sm mb-2">
                        {vp.deptBadgeText}
                      </span>
                      <h3 className="font-title-lg text-title-lg text-on-surface">
                        {vp.name}
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                        {vp.role}
                      </p>
                      {vp.email && (
                        <p className="font-label-sm text-label-sm text-primary mt-2">
                          {vp.email}
                        </p>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </section>
          )}

          {/* Section 2: Teaching & Support Staff */}
          {showTeachingSection && (
            <section className="max-w-7xl mx-auto px-6 lg:px-12 py-8 pb-20">
              <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-8">
                <div>
                  <span className="font-label-lg text-label-lg text-secondary uppercase tracking-wider">
                    02 / ACADEMIC &amp; SUPPORT STAFF
                  </span>
                  <h2 className="font-headline-lg text-headline-lg text-on-surface mt-1">
                    คณาจารย์และบุคลากรสายสนับสนุน
                  </h2>
                </div>
                <p className="font-label-md text-label-md text-on-surface-variant">
                  แสดงบุคลากร{' '}
                  <span className="text-primary font-semibold">
                    {filteredTeachingStaff.length}
                  </span>{' '}
                  ท่าน
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
                {filteredTeachingStaff.map((person) => (
                  <div
                    key={person.id}
                    className="bg-surface-container-lowest rounded-xl overflow-hidden shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col justify-between group hover:-translate-y-1 transition-transform"
                  >
                    <div className="p-5 flex flex-col items-center text-center">
                      <div className="w-28 h-28 rounded-full overflow-hidden bg-surface-container-low mb-4 ring-4 ring-surface-container">
                        <img
                          alt={person.name}
                          className="w-full h-full object-cover object-top"
                          src={person.imageUrl}
                        />
                      </div>
                      <span
                        className={`px-3 py-1 rounded-full font-label-sm text-label-sm mb-2 ${
                          person.deptBadgeTone === 'secondary'
                            ? 'bg-secondary-fixed text-on-secondary-fixed'
                            : person.deptBadgeTone === 'tertiary'
                              ? 'bg-tertiary-fixed text-on-tertiary-fixed'
                              : 'bg-primary-fixed text-on-primary-fixed'
                        }`}
                      >
                        {person.deptBadgeText}
                      </span>
                      <h3 className="font-title-md text-title-md text-on-surface">
                        {person.name}
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                        {person.role}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}
        </main>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          PAGE 4: ข้อมูลนักเรียน (STUDENT INFORMATION & PORTALS)
         ════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'students' && (
        <main className="pt-20 flex-1">
          {/* Page Header / Hero */}
          <section className="hero-mesh text-on-primary py-14 lg:py-20 relative overflow-hidden">
            <div className="max-w-7xl mx-auto px-6 lg:px-12 relative z-10">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
                <div className="lg:col-span-7 flex flex-col gap-space-md">
                  <div className="inline-flex items-center gap-space-xs px-3.5 py-1.5 rounded-full bg-white/10 backdrop-blur-md w-fit">
                    <span className="material-symbols-outlined text-secondary-container text-[18px]">
                      analytics
                    </span>
                    <span className="font-label-md text-label-md text-primary-fixed tracking-wide">
                      {config.students.updatedDateLabel}
                    </span>
                  </div>
                  <h1 className="font-display-lg text-display-lg-mobile lg:text-display-lg text-on-primary">
                    ข้อมูลนักเรียนและบริการการศึกษา
                  </h1>
                  <p className="font-body-lg text-body-lg text-primary-fixed/90 max-w-2xl">
                    ศูนย์รวมข้อมูลสถิติจำนวนนักเรียนแยกตามระดับชั้น แผนการเรียน
                    และช่องทางเข้าถึงระบบสารสนเทศสำหรับนักเรียนและผู้ปกครอง{' '}
                    {schoolDisplayName}
                  </p>
                </div>

                <div className="lg:col-span-5">
                  <div className="relative rounded-2xl overflow-hidden ambient-shadow bg-surface-container-lowest/10 backdrop-blur-md p-3">
                    <img
                      alt="นักเรียนในห้องเรียน"
                      className="w-full h-56 sm:h-64 object-cover rounded-xl"
                      src={config.students.heroImageUrl}
                    />
                    <div className="mt-3 flex items-center justify-between px-2 text-primary-fixed">
                      <span className="font-label-md text-label-md flex items-center gap-1.5">
                        <span className="material-symbols-outlined text-secondary-container text-[18px]">
                          verified
                        </span>
                        ระบบสารสนเทศนักเรียน (Student Portal)
                      </span>
                      <span className="font-label-sm text-label-sm bg-white/15 px-2.5 py-0.5 rounded-full">
                        สพม.บุรีรัมย์
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Summary KPI Cards */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 -mt-8 relative z-20">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-surface-container-lowest rounded-xl p-6 ambient-shadow flex items-start justify-between">
                <div>
                  <p className="font-label-md text-label-md text-on-surface-variant">
                    นักเรียนทั้งหมด
                  </p>
                  <p className="font-headline-lg text-headline-lg text-primary mt-1 tabular-nums">
                    {studentTotals.grandTotal.toLocaleString()}
                  </p>
                  <p className="font-label-sm text-label-sm text-on-surface-variant mt-1">
                    คน (ชาย {studentTotals.totalMale.toLocaleString()} • หญิง{' '}
                    {studentTotals.totalFemale.toLocaleString()})
                  </p>
                </div>
                <div className="w-12 h-12 rounded-xl bg-primary-fixed flex items-center justify-center text-primary shrink-0">
                  <span className="material-symbols-outlined text-[26px]">
                    groups
                  </span>
                </div>
              </div>

              <div className="bg-surface-container-lowest rounded-xl p-6 ambient-shadow flex items-start justify-between">
                <div>
                  <p className="font-label-md text-label-md text-on-surface-variant">
                    มัธยมศึกษาตอนต้น (ม.1 - ม.3)
                  </p>
                  <p className="font-headline-lg text-headline-lg text-on-surface mt-1 tabular-nums">
                    {studentTotals.juniorTotal.toLocaleString()}
                  </p>
                  <p className="font-label-sm text-label-sm text-primary mt-1">
                    {studentTotals.juniorRooms} ห้องเรียน • คิดเป็น{' '}
                    {studentTotals.juniorPct}%
                  </p>
                </div>
                <div className="w-12 h-12 rounded-xl bg-surface-container-high flex items-center justify-center text-primary-container shrink-0">
                  <span className="material-symbols-outlined text-[26px]">
                    local_library
                  </span>
                </div>
              </div>

              <div className="bg-surface-container-lowest rounded-xl p-6 ambient-shadow flex items-start justify-between">
                <div>
                  <p className="font-label-md text-label-md text-on-surface-variant">
                    มัธยมศึกษาตอนปลาย (ม.4 - ม.6)
                  </p>
                  <p className="font-headline-lg text-headline-lg text-on-surface mt-1 tabular-nums">
                    {studentTotals.seniorTotal.toLocaleString()}
                  </p>
                  <p className="font-label-sm text-label-sm text-secondary mt-1">
                    {studentTotals.seniorRooms} ห้องเรียน • คิดเป็น{' '}
                    {studentTotals.seniorPct}%
                  </p>
                </div>
                <div className="w-12 h-12 rounded-xl bg-secondary-fixed flex items-center justify-center text-secondary shrink-0">
                  <span className="material-symbols-outlined text-[26px]">
                    workspace_premium
                  </span>
                </div>
              </div>

              <div className="bg-surface-container-lowest rounded-xl p-6 ambient-shadow flex items-start justify-between">
                <div>
                  <p className="font-label-md text-label-md text-on-surface-variant">
                    จำนวนห้องเรียนรวม
                  </p>
                  <p className="font-headline-lg text-headline-lg text-tertiary mt-1 tabular-nums">
                    {studentTotals.totalRooms}
                  </p>
                  <p className="font-label-sm text-label-sm text-on-surface-variant mt-1">
                    ห้อง • เฉลี่ย {studentTotals.avgPerRoom} คน/ห้อง
                  </p>
                </div>
                <div className="w-12 h-12 rounded-xl bg-tertiary-fixed flex items-center justify-center text-tertiary shrink-0">
                  <span className="material-symbols-outlined text-[26px]">
                    meeting_room
                  </span>
                </div>
              </div>
            </div>
          </section>

          {/* 01 / Student Statistics Breakdown */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 py-16">
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-10">
              <div>
                <p className="font-label-lg text-label-lg text-secondary tracking-wider uppercase">
                  01 / STUDENT STATISTICS
                </p>
                <h2 className="font-headline-lg text-headline-lg text-on-surface mt-1">
                  สถิติจำนวนนักเรียนแยกตามระดับชั้น
                </h2>
              </div>
              <p className="font-body-sm text-body-sm text-on-surface-variant">
                {config.students.updatedDateLabel}
              </p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
              {/* Left: Donut Ratio Card */}
              <div className="lg:col-span-5 bg-surface-container-lowest rounded-2xl p-8 ambient-shadow flex flex-col justify-between">
                <div>
                  <h3 className="font-title-lg text-title-lg text-on-surface">
                    สัดส่วนนักเรียน ม.ต้น และ ม.ปลาย
                  </h3>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                    เปรียบเทียบจำนวนนักเรียนระหว่างระดับมัธยมศึกษาตอนต้นและตอนปลาย
                  </p>
                </div>

                <div className="my-8 flex flex-col items-center justify-center">
                  <div
                    className="relative w-52 h-52 rounded-full flex items-center justify-center"
                    style={{
                      background: `conic-gradient(#1e3a8a 0% ${studentTotals.juniorPct}%, #fe932c ${studentTotals.juniorPct}% 100%)`,
                    }}
                  >
                    <div className="w-36 h-36 rounded-full bg-surface-container-lowest flex flex-col items-center justify-center text-center shadow-inner">
                      <span className="font-label-sm text-label-sm text-on-surface-variant">
                        รวมทั้งหมด
                      </span>
                      <span className="font-headline-md text-headline-md text-primary tabular-nums">
                        {studentTotals.grandTotal.toLocaleString()}
                      </span>
                      <span className="font-label-sm text-label-sm text-on-surface-variant">
                        คน
                      </span>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4 pt-4 bg-surface-container-low rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <span className="w-3.5 h-3.5 rounded-sm bg-primary-container mt-1 shrink-0" />
                    <div>
                      <p className="font-label-lg text-label-lg text-on-surface">
                        มัธยมต้น (ม.1-ม.3)
                      </p>
                      <p className="font-body-sm text-body-sm text-on-surface-variant tabular-nums">
                        {studentTotals.juniorTotal.toLocaleString()} คน (
                        {studentTotals.juniorPct}%)
                      </p>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <span className="w-3.5 h-3.5 rounded-sm bg-secondary-container mt-1 shrink-0" />
                    <div>
                      <p className="font-label-lg text-label-lg text-on-surface">
                        มัธยมปลาย (ม.4-ม.6)
                      </p>
                      <p className="font-body-sm text-body-sm text-on-surface-variant tabular-nums">
                        {studentTotals.seniorTotal.toLocaleString()} คน (
                        {studentTotals.seniorPct}%)
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Right: Grade Level Progress Bars & Study Plans */}
              <div className="lg:col-span-7 bg-surface-container-lowest rounded-2xl p-8 ambient-shadow flex flex-col justify-between gap-6">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <h3 className="font-title-lg text-title-lg text-on-surface">
                      จำนวนนักเรียนรายระดับชั้น (ม.1 – ม.6)
                    </h3>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-0.5">
                      รวมทั้งหมด {studentTotals.totalRooms} ห้องเรียน
                    </p>
                  </div>
                  <span className="px-3 py-1 rounded-full bg-surface-container text-primary font-label-md text-label-md">
                    {studentTotals.totalRooms} ห้องเรียน
                  </span>
                </div>

                <div className="flex flex-col gap-5">
                  {config.students.grades.map((row) => {
                    const total = (Number(row.male) || 0) + (Number(row.female) || 0);
                    const pct = Math.min(
                      100,
                      Math.max(
                        12,
                        Math.round(
                          (total / Math.max(250, studentTotals.maxGradeTotal)) *
                            100,
                        ),
                      ),
                    );
                    return (
                      <div key={row.badge} className="flex flex-col gap-1.5">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2.5">
                            <span
                              className={`w-8 h-8 rounded-lg font-label-lg text-label-lg flex items-center justify-center ${
                                row.isSenior
                                  ? 'bg-secondary-fixed text-on-secondary-fixed'
                                  : 'bg-primary-fixed text-primary'
                              }`}
                            >
                              {row.badge}
                            </span>
                            <span className="font-title-md text-title-md text-on-surface">
                              {row.title}
                            </span>
                            <span className="font-label-sm text-label-sm text-on-surface-variant bg-surface-container-low px-2 py-0.5 rounded">
                              {row.roomsCount} ห้อง
                            </span>
                          </div>
                          <div className="text-right">
                            <span className="font-title-md text-title-md text-primary tabular-nums">
                              {total} คน
                            </span>
                            <span className="font-label-sm text-label-sm text-on-surface-variant ml-1.5 tabular-nums">
                              (ช. {row.male} / ญ. {row.female})
                            </span>
                          </div>
                        </div>
                        <div className="w-full h-3 rounded-full bg-surface-container-low overflow-hidden">
                          <div
                            className={`h-full rounded-full ${
                              row.isSenior
                                ? 'bg-secondary-container'
                                : 'bg-primary-container'
                            }`}
                            style={{ width: `${pct}%` }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Study Plans Summary */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2">
                  {config.students.studyPlans.map((plan) => (
                    <div
                      key={plan.id}
                      className="bg-surface-container-low rounded-xl p-3.5"
                    >
                      <p className="font-label-sm text-label-sm text-on-surface-variant">
                        {plan.label}
                      </p>
                      <p className="font-title-lg text-title-lg text-primary mt-0.5 tabular-nums">
                        {plan.countLabel}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </section>

          {/* 02 / Student Services & Portals */}
          <section className="bg-surface-container-low py-16">
            <div className="max-w-7xl mx-auto px-6 lg:px-12">
              <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-10">
                <div>
                  <p className="font-label-lg text-label-lg text-secondary tracking-wider uppercase">
                    02 / STUDENT PORTALS
                  </p>
                  <h2 className="font-headline-lg text-headline-lg text-on-surface mt-1">
                    ระบบบริการและสารสนเทศนักเรียน
                  </h2>
                </div>
                <p className="font-body-sm text-body-sm text-on-surface-variant">
                  เข้าถึงบริการออนไลน์ ตารางเรียน ผลการเรียน และกิจกรรมพัฒนาผู้เรียน
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <div className="bg-surface-container-lowest rounded-2xl p-6 ambient-shadow flex flex-col justify-between gap-6 hover:-translate-y-1 transition-transform">
                  <div className="flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                      <div className="w-12 h-12 rounded-xl bg-primary-fixed flex items-center justify-center text-primary">
                        <span className="material-symbols-outlined text-[26px]">
                          calendar_month
                        </span>
                      </div>
                      <span className="px-3 py-1 rounded-full bg-surface-container text-primary font-label-sm text-label-sm">
                        ภาคเรียนที่ 1/2568
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-lg text-title-lg text-on-surface">
                        ตารางเรียน / ตารางสอบ
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5">
                        ตรวจสอบตารางเรียนรายห้องเรียน ตารางสอบกลางภาคและปลายภาคเรียน
                        ระดับชั้น ม.1 – ม.6
                      </p>
                    </div>
                  </div>
                  <a
                    href="#student-downloads"
                    className="inline-flex items-center justify-between w-full px-4 py-3 rounded-xl bg-surface-container-low hover:bg-primary-container text-primary hover:text-on-primary font-label-lg text-label-lg transition-colors"
                  >
                    <span>ดูตารางเรียนและตารางสอบ</span>
                    <span className="material-symbols-outlined text-[20px]">
                      arrow_forward
                    </span>
                  </a>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 ambient-shadow flex flex-col justify-between gap-6 hover:-translate-y-1 transition-transform">
                  <div className="flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                      <div className="w-12 h-12 rounded-xl bg-secondary-fixed flex items-center justify-center text-secondary">
                        <span className="material-symbols-outlined text-[26px]">
                          fact_check
                        </span>
                      </div>
                      <span className="px-3 py-1 rounded-full bg-secondary-fixed text-on-secondary-fixed font-label-sm text-label-sm">
                        SGS Online
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-lg text-title-lg text-on-surface">
                        ระบบตรวจสอบผลการเรียน
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5">
                        ระบบวัดและประเมินผลการเรียน (SGS) สำหรับนักเรียนและผู้ปกครอง
                        ตรวจสอบเกรดเฉลี่ยและเวลาเรียน
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setSgsError(null);
                      setSgsModalOpen(true);
                    }}
                    className="inline-flex items-center justify-between w-full px-4 py-3 rounded-xl bg-primary-container hover:bg-primary text-on-primary font-label-lg text-label-lg transition-colors"
                  >
                    <span>เข้าสู่ระบบ SGS นักเรียน</span>
                    <span className="material-symbols-outlined text-[20px]">
                      open_in_new
                    </span>
                  </button>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 ambient-shadow flex flex-col justify-between gap-6 hover:-translate-y-1 transition-transform">
                  <div className="flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                      <div className="w-12 h-12 rounded-xl bg-tertiary-fixed flex items-center justify-center text-tertiary">
                        <span className="material-symbols-outlined text-[26px]">
                          diversity_3
                        </span>
                      </div>
                      <span className="px-3 py-1 rounded-full bg-tertiary-fixed text-on-tertiary-fixed font-label-sm text-label-sm">
                        กิจการนักเรียน
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-lg text-title-lg text-on-surface">
                        ระบบดูแลช่วยเหลือนักเรียน
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5">
                        บันทึกข้อมูลเยี่ยมบ้าน การคัดกรองนักเรียนรายบุคคล
                        และการส่งเสริมความประพฤติและสวัสดิภาพนักเรียน
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => switchTab('contact')}
                    className="inline-flex items-center justify-between w-full px-4 py-3 rounded-xl bg-surface-container-low hover:bg-primary-container text-primary hover:text-on-primary font-label-lg text-label-lg transition-colors"
                  >
                    <span>ติดต่อฝ่ายกิจการนักเรียน</span>
                    <span className="material-symbols-outlined text-[20px]">
                      arrow_forward
                    </span>
                  </button>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 ambient-shadow flex flex-col justify-between gap-6 hover:-translate-y-1 transition-transform">
                  <div className="flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                      <div className="w-12 h-12 rounded-xl bg-primary-fixed flex items-center justify-center text-primary">
                        <span className="material-symbols-outlined text-[26px]">
                          interests
                        </span>
                      </div>
                      <span className="px-3 py-1 rounded-full bg-surface-container text-primary font-label-sm text-label-sm">
                        38 ชุมนุม
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-lg text-title-lg text-on-surface">
                        กิจกรรมชุมนุมและพัฒนาผู้เรียน
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5">
                        ลงทะเบียนเลือกชุมนุมวิชาการ กีฬา ดนตรี ศิลปะ ลูกเสือ-เนตรนารี
                        และนักศึกษาวิชาทหาร (รด.)
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => switchTab('news')}
                    className="inline-flex items-center justify-between w-full px-4 py-3 rounded-xl bg-surface-container-low hover:bg-primary-container text-primary hover:text-on-primary font-label-lg text-label-lg transition-colors"
                  >
                    <span>ดูกิจกรรมนักเรียนทั้งหมด</span>
                    <span className="material-symbols-outlined text-[20px]">
                      arrow_forward
                    </span>
                  </button>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 ambient-shadow flex flex-col justify-between gap-6 hover:-translate-y-1 transition-transform">
                  <div className="flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                      <div className="w-12 h-12 rounded-xl bg-secondary-fixed flex items-center justify-center text-secondary">
                        <span className="material-symbols-outlined text-[26px]">
                          school
                        </span>
                      </div>
                      <span className="px-3 py-1 rounded-full bg-secondary-fixed text-on-secondary-fixed font-label-sm text-label-sm">
                        แนะแนว &amp; TCAS
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-lg text-title-lg text-on-surface">
                        ทุนการศึกษาและแนะแนวศึกษาต่อ
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5">
                        ข้อมูลข่าวสารทุนการศึกษา กยศ. การเตรียมความพร้อมเข้ามหาวิทยาลัย
                        (TCAS) และแฟ้มสะสมผลงาน
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => switchTab('news')}
                    className="inline-flex items-center justify-between w-full px-4 py-3 rounded-xl bg-surface-container-low hover:bg-primary-container text-primary hover:text-on-primary font-label-lg text-label-lg transition-colors"
                  >
                    <span>ประกาศทุนการศึกษา</span>
                    <span className="material-symbols-outlined text-[20px]">
                      arrow_forward
                    </span>
                  </button>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 ambient-shadow flex flex-col justify-between gap-6 hover:-translate-y-1 transition-transform">
                  <div className="flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                      <div className="w-12 h-12 rounded-xl bg-tertiary-fixed flex items-center justify-center text-tertiary">
                        <span className="material-symbols-outlined text-[26px]">
                          menu_book
                        </span>
                      </div>
                      <span className="px-3 py-1 rounded-full bg-tertiary-fixed text-on-tertiary-fixed font-label-sm text-label-sm">
                        E-Library
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-lg text-title-lg text-on-surface">
                        ห้องสมุดดิจิทัลและสื่อการเรียนรู้
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5">
                        สืบค้นหนังสืออิเล็กทรอนิกส์ สื่อการสอนออนไลน์
                        และคลังข้อสอบย้อนหลังของทุกกลุ่มสาระการเรียนรู้
                      </p>
                    </div>
                  </div>
                  <a
                    href="#student-downloads"
                    className="inline-flex items-center justify-between w-full px-4 py-3 rounded-xl bg-surface-container-low hover:bg-primary-container text-primary hover:text-on-primary font-label-lg text-label-lg transition-colors"
                  >
                    <span>เข้าสู่คลังสื่อการเรียนรู้</span>
                    <span className="material-symbols-outlined text-[20px]">
                      arrow_forward
                    </span>
                  </a>
                </div>
              </div>
            </div>
          </section>

          {/* 03 / Student Handbook & Document Downloads */}
          <section
            id="student-downloads"
            className="max-w-7xl mx-auto px-6 lg:px-12 py-16"
          >
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
              {/* Left info panel */}
              <div className="lg:col-span-5 flex flex-col gap-6">
                <div>
                  <p className="font-label-lg text-label-lg text-secondary tracking-wider uppercase">
                    03 / DOWNLOADS
                  </p>
                  <h2 className="font-headline-lg text-headline-lg text-on-surface mt-1">
                    เอกสารและคู่มือนักเรียน
                  </h2>
                  <p className="font-body-md text-body-md text-on-surface-variant mt-3">
                    ดาวน์โหลดแบบฟอร์มคำร้องทางทะเบียนวัดผล คู่มือนักเรียนและผู้ปกครอง
                    รวมถึงระเบียบปฏิบัติของ{schoolDisplayName}
                  </p>
                </div>

                <div className="bg-surface-container-low rounded-2xl p-6 flex flex-col gap-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-primary-container text-on-primary flex items-center justify-center shrink-0">
                      <span className="material-symbols-outlined text-[22px]">
                        support_agent
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-md text-title-md text-on-surface">
                        ติดต่อห้องทะเบียนและวัดผล
                      </h3>
                      <p className="font-label-md text-label-md text-on-surface-variant">
                        อาคาร 1 ชั้น 1 • {config.contact.officeHours}
                      </p>
                    </div>
                  </div>
                  <p className="font-body-sm text-body-sm text-on-surface-variant">
                    สำหรับการขอใบรับรองผลการเรียน (ปพ.7) หรือระเบียนแสดงผลการเรียน (ปพ.1)
                    กรุณาเตรียมรูปถ่ายชุดนักเรียนขนาด 1.5 นิ้ว จำนวน 2 รูป
                  </p>
                  <button
                    type="button"
                    onClick={() => switchTab('contact')}
                    className="inline-flex items-center gap-2 font-label-lg text-label-lg text-primary hover:underline w-fit"
                  >
                    <span>สอบถามข้อมูลเพิ่มเติม</span>
                    <span className="material-symbols-outlined text-[18px]">
                      arrow_forward
                    </span>
                  </button>
                </div>
              </div>

              {/* Right document list */}
              <div className="lg:col-span-7 flex flex-col gap-4">
                {config.students.downloads.map((doc) => {
                  const status = downloadStates[doc.id] ?? 'idle';
                  return (
                    <div
                      key={doc.id}
                      className="bg-surface-container-lowest rounded-xl p-5 ambient-shadow flex flex-col sm:flex-row sm:items-center justify-between gap-4"
                    >
                      <div className="flex items-start gap-4">
                        <div
                          className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${
                            doc.fileType === 'DOCX'
                              ? 'bg-secondary-fixed text-secondary'
                              : 'bg-primary-fixed text-primary'
                          }`}
                        >
                          <span className="material-symbols-outlined text-[24px]">
                            {doc.fileType === 'DOCX'
                              ? 'edit_document'
                              : 'picture_as_pdf'}
                          </span>
                        </div>
                        <div>
                          <h3 className="font-title-md text-title-md text-on-surface">
                            {doc.title}
                          </h3>
                          <p className="font-label-md text-label-md text-on-surface-variant mt-0.5">
                            ไฟล์ {doc.fileType} • ขนาด {doc.fileSize} •{' '}
                            {doc.updatedLabel}
                          </p>
                        </div>
                      </div>

                      <button
                        type="button"
                        onClick={() =>
                          handleTriggerDownload(doc.id, doc.fileUrl)
                        }
                        className={`inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl font-label-lg text-label-lg transition-colors shrink-0 ${
                          status === 'done'
                            ? 'bg-primary-container text-on-primary'
                            : 'bg-surface-container-low hover:bg-primary-container text-primary hover:text-on-primary'
                        }`}
                      >
                        <span className="material-symbols-outlined text-[18px]">
                          {status === 'loading'
                            ? 'hourglass_top'
                            : status === 'done'
                              ? 'check_circle'
                              : 'download'}
                        </span>
                        <span>
                          {status === 'loading'
                            ? 'กำลังเตรียมไฟล์...'
                            : status === 'done'
                              ? 'ดาวน์โหลดสำเร็จ'
                              : 'ดาวน์โหลด'}
                        </span>
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          </section>
        </main>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          PAGE 5: ข้อมูลโรงเรียน (SCHOOL INFORMATION & HERITAGE)
         ════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'about' && (
        <main className="pt-20 flex-1">
          {/* Section 1: Hero Header */}
          <section className="relative overflow-hidden bg-gradient-to-br from-primary via-primary-container to-tertiary-container text-on-primary py-16 lg:py-24">
            <div className="max-w-7xl mx-auto px-6 lg:px-12">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-center">
                <div className="lg:col-span-7 space-y-6">
                  <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/10 backdrop-blur-md">
                    <span className="w-2 h-2 rounded-full bg-secondary-container" />
                    <span className="font-label-md text-label-md text-primary-fixed tracking-wider uppercase">
                      01 / ข้อมูลพื้นฐานสถานศึกษา
                    </span>
                  </div>
                  <h1 className="font-display-lg text-display-lg-mobile lg:text-display-lg text-on-primary">
                    {schoolDisplayName}
                  </h1>
                  <p className="font-body-lg text-body-lg text-primary-fixed/90 max-w-2xl">
                    {schoolAffiliation} — {config.about.visionText}
                  </p>
                  <div className="flex flex-wrap items-center gap-4 pt-2">
                    <div className="flex items-center gap-2.5 bg-white/10 backdrop-blur-md px-4 py-2.5 rounded-xl">
                      <span className="material-symbols-outlined text-secondary-container text-[20px]">
                        location_on
                      </span>
                      <span className="font-label-lg text-label-lg text-on-primary">
                        {config.contact.shortLocation}
                      </span>
                    </div>
                    <div className="flex items-center gap-2.5 bg-white/10 backdrop-blur-md px-4 py-2.5 rounded-xl">
                      <span className="material-symbols-outlined text-secondary-container text-[20px]">
                        workspace_premium
                      </span>
                      <span className="font-label-lg text-label-lg text-on-primary">
                        ก่อตั้ง พ.ศ. {config.about.foundedYearBe}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="lg:col-span-5">
                  <div className="relative rounded-2xl overflow-hidden shadow-[0_20px_48px_rgba(0,14,46,0.35)] bg-surface-container-high">
                    <img
                      alt={`อาคารเรียน${schoolDisplayName}`}
                      className="w-full h-72 lg:h-80 object-cover"
                      src={config.about.campusHeroImageUrl}
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-primary/80 via-transparent to-transparent" />
                    <div className="absolute bottom-4 left-4 right-4 bg-surface-container-lowest/95 backdrop-blur-md rounded-xl p-4 flex items-center justify-between">
                      <div>
                        <p className="font-label-sm text-label-sm text-on-surface-variant">
                          รหัสสถานศึกษา 10 หลัก
                        </p>
                        <p className="font-title-md text-title-md text-primary tabular-nums">
                          {config.about.smisCode}
                        </p>
                      </div>
                      <span className="px-3 py-1 rounded-full bg-secondary-fixed text-on-secondary-fixed font-label-md text-label-md">
                        {config.about.schoolSizeLabel}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Section 2: School History */}
          <section className="py-16 lg:py-24 bg-surface">
            <div className="max-w-7xl mx-auto px-6 lg:px-12">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
                <div className="lg:col-span-5 space-y-6">
                  <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-surface-container text-primary font-label-md text-label-md">
                    <span>02 / HISTORY</span>
                  </div>
                  <h2 className="font-headline-lg text-headline-lg text-on-surface">
                    ประวัติความเป็นมาของสถานศึกษา
                  </h2>
                  <p className="font-body-md text-body-md text-on-surface-variant">
                    จุดเริ่มต้นและพัฒนาการของการจัดการศึกษาเพื่อเยาวชนและชุมชน
                  </p>
                  <div className="rounded-2xl overflow-hidden shadow-[0_12px_32px_rgba(13,28,46,0.06)] bg-surface-container-low">
                    <img
                      alt="บรรยากาศการเรียนการสอนและอาคารเรียน"
                      className="w-full h-64 object-cover"
                      src={config.about.historyImageUrl}
                    />
                    <div className="p-5 bg-surface-container-lowest">
                      <p className="font-label-lg text-label-lg text-primary">
                        {schoolDisplayName}
                      </p>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                        ก่อตั้งเมื่อพุทธศักราช {config.about.foundedYearBe}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="lg:col-span-7 space-y-6">
                  <div className="bg-surface-container-lowest rounded-2xl p-8 shadow-[0_12px_32px_rgba(13,28,46,0.06)] space-y-6">
                    <div className="flex items-start gap-4">
                      <div className="w-12 h-12 rounded-xl bg-primary-fixed flex items-center justify-center shrink-0">
                        <span className="material-symbols-outlined text-primary text-[24px]">
                          history_edu
                        </span>
                      </div>
                      <div>
                        <h3 className="font-headline-sm text-headline-sm text-on-surface">
                          จุดเริ่มต้นและพัฒนาการ
                        </h3>
                        <p className="font-label-md text-label-md text-secondary">
                          พุทธศักราช {config.about.foundedYearBe} – ปัจจุบัน
                        </p>
                      </div>
                    </div>

                    <div className="space-y-4 font-body-md text-body-md text-on-surface-variant">
                      {config.about.historyParagraphs.map((para, idx) => (
                        <p key={idx}>
                          {idx === 0 && (
                            <strong className="text-on-surface font-semibold">
                              {schoolDisplayName}{' '}
                            </strong>
                          )}
                          {para}
                        </p>
                      ))}
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-4">
                      <div className="bg-surface-container-low rounded-xl p-4">
                        <p className="font-label-sm text-label-sm text-on-surface-variant">
                          ปีที่ก่อตั้ง
                        </p>
                        <p className="font-headline-md text-headline-md text-primary mt-1 tabular-nums">
                          {config.about.foundedYearBe}
                        </p>
                        <p className="font-body-sm text-body-sm text-on-surface-variant">
                          ปีพุทธศักราช
                        </p>
                      </div>
                      <div className="bg-surface-container-low rounded-xl p-4">
                        <p className="font-label-sm text-label-sm text-on-surface-variant">
                          ระดับที่เปิดสอน
                        </p>
                        <p className="font-headline-md text-headline-md text-primary mt-1">
                          {config.about.gradeRangeLabel}
                        </p>
                        <p className="font-body-sm text-body-sm text-on-surface-variant">
                          มัธยมศึกษาตอนต้น - ตอนปลาย
                        </p>
                      </div>
                      <div className="bg-surface-container-low rounded-xl p-4">
                        <p className="font-label-sm text-label-sm text-on-surface-variant">
                          พื้นที่สถานศึกษา
                        </p>
                        <p className="font-headline-md text-headline-md text-primary mt-1 tabular-nums">
                          {config.about.areaSizeLabel}
                        </p>
                        <p className="font-body-sm text-body-sm text-on-surface-variant">
                          สภาพแวดล้อมร่มรื่นเอื้อต่อการเรียนรู้
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Section 3: Vision, Mission & Goals */}
          <section className="py-16 lg:py-24 bg-surface-container-low">
            <div className="max-w-7xl mx-auto px-6 lg:px-12 space-y-12">
              <div className="max-w-2xl space-y-3">
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-surface-container-high text-primary font-label-md text-label-md">
                  <span>03 / VISION &amp; MISSION</span>
                </div>
                <h2 className="font-headline-lg text-headline-lg text-on-surface">
                  วิสัยทัศน์ พันธกิจ และเป้าหมาย
                </h2>
                <p className="font-body-md text-body-md text-on-surface-variant">
                  เข็มทิศในการบริหารจัดการศึกษาของ{schoolDisplayName}
                  เพื่อยกระดับคุณภาพผู้เรียนอย่างรอบด้าน
                </p>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Vision */}
                <div className="bg-surface-container-lowest rounded-2xl p-8 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col justify-between space-y-6">
                  <div className="space-y-4">
                    <div className="w-12 h-12 rounded-xl bg-primary-container text-on-primary flex items-center justify-center">
                      <span className="material-symbols-outlined text-[24px]">
                        visibility
                      </span>
                    </div>
                    <div>
                      <span className="font-label-md text-label-md text-secondary uppercase tracking-wider">
                        วิสัยทัศน์ (Vision)
                      </span>
                      <h3 className="font-headline-sm text-headline-sm text-on-surface mt-1">
                        {config.about.visionTitle}
                      </h3>
                    </div>
                    <p className="font-body-md text-body-md text-on-surface-variant">
                      “{schoolDisplayName} {config.about.visionText}”
                    </p>
                  </div>
                  <div className="pt-4 border-t border-outline-variant/20 flex items-center gap-2 text-primary font-label-md text-label-md">
                    <span className="material-symbols-outlined text-[18px]">
                      verified
                    </span>
                    <span>แผนพัฒนาคุณภาพการศึกษา</span>
                  </div>
                </div>

                {/* Mission */}
                <div className="bg-surface-container-lowest rounded-2xl p-8 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col justify-between space-y-6">
                  <div className="space-y-4">
                    <div className="w-12 h-12 rounded-xl bg-secondary-container text-on-secondary-fixed flex items-center justify-center">
                      <span className="material-symbols-outlined text-[24px]">
                        flag
                      </span>
                    </div>
                    <div>
                      <span className="font-label-md text-label-md text-secondary uppercase tracking-wider">
                        พันธกิจ (Mission)
                      </span>
                      <h3 className="font-headline-sm text-headline-sm text-on-surface mt-1">
                        ภารกิจหลักเพื่อพัฒนาการศึกษา
                      </h3>
                    </div>
                    <ul className="space-y-3 font-body-sm text-body-sm text-on-surface-variant">
                      {config.about.missions.map((m, idx) => (
                        <li key={idx} className="flex items-start gap-2.5">
                          <span className="material-symbols-outlined text-primary text-[18px] shrink-0 mt-0.5">
                            check_circle
                          </span>
                          <span>{m}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                  <div className="pt-4 border-t border-outline-variant/20 flex items-center gap-2 text-primary font-label-md text-label-md">
                    <span className="material-symbols-outlined text-[18px]">
                      groups
                    </span>
                    <span>ขับเคลื่อนโดยบุคลากรและภาคีเครือข่าย</span>
                  </div>
                </div>

                {/* Core Goals */}
                <div className="bg-surface-container-lowest rounded-2xl p-8 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col justify-between space-y-6">
                  <div className="space-y-4">
                    <div className="w-12 h-12 rounded-xl bg-tertiary-container text-on-tertiary flex items-center justify-center">
                      <span className="material-symbols-outlined text-[24px]">
                        track_changes
                      </span>
                    </div>
                    <div>
                      <span className="font-label-md text-label-md text-secondary uppercase tracking-wider">
                        เป้าประสงค์ (Goals)
                      </span>
                      <h3 className="font-headline-sm text-headline-sm text-on-surface mt-1">
                        ผลสัมฤทธิ์ที่มุ่งหวัง
                      </h3>
                    </div>
                    <ul className="space-y-3 font-body-sm text-body-sm text-on-surface-variant">
                      {config.about.goals.map((g, idx) => (
                        <li key={idx} className="flex items-start gap-2.5">
                          <span className="material-symbols-outlined text-secondary text-[18px] shrink-0 mt-0.5">
                            stars
                          </span>
                          <span>{g}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                  <div className="pt-4 border-t border-outline-variant/20 flex items-center gap-2 text-primary font-label-md text-label-md">
                    <span className="material-symbols-outlined text-[18px]">
                      trending_up
                    </span>
                    <span>ประเมินผลตามมาตรฐานการศึกษาขั้นพื้นฐาน</span>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Section 4: School Identity */}
          <section className="py-16 lg:py-24 bg-surface">
            <div className="max-w-7xl mx-auto px-6 lg:px-12 space-y-12">
              <div className="flex flex-col md:flex-row md:items-end justify-between gap-6">
                <div className="space-y-3">
                  <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-surface-container text-primary font-label-md text-label-md">
                    <span>04 / SCHOOL IDENTITY</span>
                  </div>
                  <h2 className="font-headline-lg text-headline-lg text-on-surface">
                    เอกลักษณ์ อัตลักษณ์ และสัญลักษณ์ประจำโรงเรียน
                  </h2>
                </div>
                <div className="flex items-center gap-3 bg-surface-container-low px-5 py-3 rounded-xl">
                  <div className="flex items-center -space-x-1">
                    <span className="w-6 h-6 rounded-full bg-primary-container ring-2 ring-white" />
                    <span className="w-6 h-6 rounded-full bg-white ring-2 ring-outline-variant" />
                  </div>
                  <div>
                    <p className="font-label-sm text-label-sm text-on-surface-variant">
                      สีประจำโรงเรียน
                    </p>
                    <p className="font-label-lg text-label-lg text-primary">
                      {config.about.schoolColors}
                    </p>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <div className="bg-surface-container-lowest rounded-2xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] space-y-4">
                  <div className="w-11 h-11 rounded-xl bg-primary-fixed text-primary flex items-center justify-center">
                    <span className="material-symbols-outlined text-[22px]">
                      auto_stories
                    </span>
                  </div>
                  <div>
                    <p className="font-label-md text-label-md text-secondary">
                      ปรัชญาโรงเรียน
                    </p>
                    <h3 className="font-title-lg text-title-lg text-on-surface mt-1">
                      {config.about.philosophyTitle}
                    </h3>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-2">
                      {config.about.philosophyDesc}
                    </p>
                  </div>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] space-y-4">
                  <div className="w-11 h-11 rounded-xl bg-secondary-fixed text-secondary flex items-center justify-center">
                    <span className="material-symbols-outlined text-[22px]">
                      military_tech
                    </span>
                  </div>
                  <div>
                    <p className="font-label-md text-label-md text-secondary">
                      คำขวัญโรงเรียน
                    </p>
                    <h3 className="font-title-lg text-title-lg text-on-surface mt-1">
                      {config.about.mottoTitle}
                    </h3>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-2">
                      {config.about.mottoDesc}
                    </p>
                  </div>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] space-y-4">
                  <div className="w-11 h-11 rounded-xl bg-tertiary-fixed text-tertiary flex items-center justify-center">
                    <span className="material-symbols-outlined text-[22px]">
                      eco
                    </span>
                  </div>
                  <div>
                    <p className="font-label-md text-label-md text-secondary">
                      เอกลักษณ์สถานศึกษา
                    </p>
                    <h3 className="font-title-lg text-title-lg text-on-surface mt-1">
                      {config.about.uniquenessTitle}
                    </h3>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-2">
                      {config.about.uniquenessDesc}
                    </p>
                  </div>
                </div>

                <div className="bg-surface-container-lowest rounded-2xl p-6 shadow-[0_12px_32px_rgba(13,28,46,0.06)] space-y-4">
                  <div className="w-11 h-11 rounded-xl bg-primary-fixed text-primary flex items-center justify-center">
                    <span className="material-symbols-outlined text-[22px]">
                      volunteer_activism
                    </span>
                  </div>
                  <div>
                    <p className="font-label-md text-label-md text-secondary">
                      อัตลักษณ์ผู้เรียน
                    </p>
                    <h3 className="font-title-lg text-title-lg text-on-surface mt-1">
                      {config.about.identityTitle}
                    </h3>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-2">
                      {config.about.identityDesc}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* Section 5: Basic Information & Map */}
          <section className="py-16 lg:py-24 bg-surface-container-low">
            <div className="max-w-7xl mx-auto px-6 lg:px-12 space-y-10">
              <div className="space-y-3">
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-surface-container-high text-primary font-label-md text-label-md">
                  <span>05 / SCHOOL PROFILE</span>
                </div>
                <h2 className="font-headline-lg text-headline-lg text-on-surface">
                  ข้อมูลพื้นฐานและที่ตั้งสถานศึกษา
                </h2>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
                {/* Information Table Card */}
                <div className="lg:col-span-7 bg-surface-container-lowest rounded-2xl p-8 shadow-[0_12px_32px_rgba(13,28,46,0.06)]">
                  <h3 className="font-headline-sm text-headline-sm text-on-surface mb-6">
                    รายละเอียดสถานศึกษา
                  </h3>
                  <dl className="divide-y divide-outline-variant/25">
                    {[
                      {
                        dt: 'ชื่อสถานศึกษา (ภาษาไทย)',
                        dd: schoolDisplayName,
                      },
                      {
                        dt: 'ชื่อสถานศึกษา (ภาษาอังกฤษ)',
                        dd: config.about.englishName,
                      },
                      {
                        dt: 'รหัสสถานศึกษา (SMIS)',
                        dd: config.about.smisCode,
                      },
                      {
                        dt: 'หน่วยงานต้นสังกัด',
                        dd: schoolAffiliation,
                      },
                      {
                        dt: 'ประเภทและระดับที่เปิดสอน',
                        dd: `สหศึกษา ระดับชั้น ${config.about.gradeRangeLabel}`,
                      },
                      {
                        dt: 'ที่ตั้งสถานศึกษา',
                        dd: config.contact.address,
                      },
                      {
                        dt: 'โทรศัพท์ / อีเมล',
                        dd: `${config.contact.phoneMain} • อีเมล ${config.contact.emailMain}`,
                      },
                    ].map((row) => (
                      <div
                        key={row.dt}
                        className="py-3.5 grid grid-cols-1 sm:grid-cols-12 gap-2"
                      >
                        <dt className="sm:col-span-5 font-label-lg text-label-lg text-on-surface-variant">
                          {row.dt}
                        </dt>
                        <dd className="sm:col-span-7 font-body-md text-body-md text-on-surface">
                          {row.dd}
                        </dd>
                      </div>
                    ))}
                  </dl>
                </div>

                {/* Location & Quick Contact Card */}
                <div className="lg:col-span-5 bg-surface-container-lowest rounded-2xl p-8 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex flex-col justify-between space-y-6">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <h3 className="font-headline-sm text-headline-sm text-on-surface">
                        แผนที่ตั้งโรงเรียน
                      </h3>
                      <span className="px-3 py-1 rounded-full bg-primary-fixed text-primary font-label-sm text-label-sm">
                        {config.contact.shortLocation}
                      </span>
                    </div>
                    <div className="relative rounded-xl overflow-hidden h-52 bg-surface-container">
                      <img
                        alt="แผนที่และบริเวณโรงเรียน"
                        className="w-full h-full object-cover"
                        src={config.contact.mapPreviewImageUrl}
                      />
                      <div className="absolute inset-0 bg-primary/30 flex items-center justify-center">
                        <div className="bg-surface-container-lowest px-4 py-2.5 rounded-xl shadow-lg flex items-center gap-2">
                          <span className="material-symbols-outlined text-secondary text-[22px]">
                            location_on
                          </span>
                          <span className="font-label-lg text-label-lg text-on-surface">
                            {schoolDisplayName}
                          </span>
                        </div>
                      </div>
                    </div>
                    <p className="font-body-sm text-body-sm text-on-surface-variant">
                      {config.contact.mapDirectionsNote} ({config.contact.officeHours})
                    </p>
                  </div>

                  <div className="flex flex-col sm:flex-row gap-3 pt-2">
                    <button
                      type="button"
                      onClick={() => switchTab('contact')}
                      className="flex-1 inline-flex items-center justify-center gap-2 px-5 py-3 rounded-xl bg-primary-container text-on-primary font-label-lg text-label-lg hover:bg-primary transition-colors"
                    >
                      <span className="material-symbols-outlined text-[18px]">
                        mail
                      </span>
                      <span>ติดต่อสอบถามโรงเรียน</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => switchTab('staff')}
                      className="inline-flex items-center justify-center gap-2 px-5 py-3 rounded-xl bg-surface-container text-primary font-label-lg text-label-lg hover:bg-surface-container-high transition-colors"
                    >
                      <span>ทำเนียบบุคลากร</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </main>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          PAGE 6: ติดต่อ (CONTACT SCHOOL)
         ════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'contact' && (
        <main className="pt-20 flex-1">
          {/* Page Hero */}
          <section className="relative overflow-hidden bg-gradient-to-br from-primary via-primary-container to-tertiary-container text-on-primary py-14 lg:py-20">
            <div
              className="absolute inset-0 opacity-10 pointer-events-none"
              style={{
                backgroundImage:
                  'radial-gradient(circle at 20% 20%, #ffffff 1px, transparent 1px)',
                backgroundSize: '32px 32px',
              }}
            />
            <div className="max-w-7xl mx-auto px-6 lg:px-12 relative z-10">
              <div className="max-w-3xl flex flex-col items-start gap-space-md">
                <div className="inline-flex items-center gap-space-sm px-4 py-1.5 rounded-full bg-surface-container-lowest/15 backdrop-blur-md">
                  <span className="w-2 h-2 rounded-full bg-secondary-container" />
                  <span className="font-label-md text-label-md text-primary-fixed tracking-wide uppercase">
                    ศูนย์บริการข้อมูลและประชาสัมพันธ์ • ติดต่อโรงเรียน
                  </span>
                </div>
                <h1 className="font-display-lg text-display-lg-mobile lg:text-display-lg text-on-primary">
                  ติดต่อ{schoolDisplayName}
                </h1>
                <p className="font-body-lg text-body-lg text-primary-fixed">
                  สอบถามข้อมูลการรับสมัครนักเรียน การติดต่อราชการ การขอเอกสารทางการศึกษา
                  หรือส่งข้อเสนอแนะถึงฝ่ายบริหารสถานศึกษา
                </p>
              </div>
            </div>
          </section>

          {/* Main 2-Column Contact Layout */}
          <section className="max-w-7xl mx-auto px-6 lg:px-12 py-14 lg:py-16">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
              {/* Left Column: Contact Details & Social Channels */}
              <div className="lg:col-span-5 flex flex-col gap-6">
                <div>
                  <span className="font-label-lg text-label-lg text-secondary uppercase tracking-wider">
                    ข้อมูลการติดต่อ
                  </span>
                  <h2 className="font-headline-md text-headline-md text-on-surface mt-1">
                    ช่องทางการติดต่อราชการ
                  </h2>
                  <p className="font-body-sm text-body-sm text-on-surface-variant mt-2">
                    ท่านสามารถติดต่อสอบถามข้อมูลโดยตรงผ่านหมายเลขโทรศัพท์ อีเมล
                    หรือเดินทางมาติดต่อ ณ ห้องธุรการ อาคารอำนวยการ ชั้น 1
                  </p>
                </div>

                {/* Contact Info Cards */}
                <div className="flex flex-col gap-4">
                  <div className="bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-start gap-space-md">
                    <div className="w-12 h-12 rounded-xl bg-primary-fixed flex items-center justify-center shrink-0">
                      <span className="material-symbols-outlined text-primary text-[24px]">
                        location_on
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-md text-title-md text-on-surface">
                        ที่อยู่โรงเรียน
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                        {config.contact.address}
                      </p>
                    </div>
                  </div>

                  <div className="bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-start gap-space-md">
                    <div className="w-12 h-12 rounded-xl bg-secondary-fixed flex items-center justify-center shrink-0">
                      <span className="material-symbols-outlined text-secondary text-[24px]">
                        call
                      </span>
                    </div>
                    <div className="flex-1">
                      <h3 className="font-title-md text-title-md text-on-surface">
                        หมายเลขโทรศัพท์และโทรสาร
                      </h3>
                      <div className="mt-1 space-y-1 font-body-sm text-body-sm text-on-surface-variant">
                        <p>
                          ธุรการกลาง / ประชาสัมพันธ์:{' '}
                          <span className="text-on-surface font-medium tabular-nums">
                            {config.contact.phoneMain}
                          </span>
                        </p>
                        <p>
                          กลุ่มบริหารงานวิชาการ (ทะเบียน-วัดผล):{' '}
                          <span className="text-on-surface font-medium tabular-nums">
                            {config.contact.phoneAcademic}
                          </span>
                        </p>
                        <p>
                          โทรสาร (Fax):{' '}
                          <span className="text-on-surface font-medium tabular-nums">
                            {config.contact.fax}
                          </span>
                        </p>
                      </div>
                    </div>
                  </div>

                  <div className="bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-start gap-space-md">
                    <div className="w-12 h-12 rounded-xl bg-tertiary-fixed flex items-center justify-center shrink-0">
                      <span className="material-symbols-outlined text-tertiary text-[24px]">
                        mail
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-md text-title-md text-on-surface">
                        อีเมลทางการ
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                        สารบรรณกลาง:{' '}
                        <span className="text-primary font-medium">
                          {config.contact.emailMain}
                        </span>
                      </p>
                      <p className="font-body-sm text-body-sm text-on-surface-variant">
                        งานทะเบียนวัดผล:{' '}
                        <span className="text-primary font-medium">
                          {config.contact.emailAcademic}
                        </span>
                      </p>
                    </div>
                  </div>

                  <div className="bg-surface-container-lowest rounded-xl p-5 shadow-[0_12px_32px_rgba(13,28,46,0.06)] flex items-start gap-space-md">
                    <div className="w-12 h-12 rounded-xl bg-surface-container-high flex items-center justify-center shrink-0">
                      <span className="material-symbols-outlined text-primary-container text-[24px]">
                        schedule
                      </span>
                    </div>
                    <div>
                      <h3 className="font-title-md text-title-md text-on-surface">
                        วันและเวลาทำการ
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                        {config.contact.officeHours}
                      </p>
                      <p className="font-label-md text-label-md text-secondary mt-0.5">
                        {config.contact.officeHoursNote}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Social Channels */}
                <div className="bg-surface-container-low rounded-xl p-6">
                  <p className="font-title-md text-title-md text-on-surface mb-3">
                    ช่องทางสื่อสังคมออนไลน์ (Official Social Media)
                  </p>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <a
                      href={config.contact.facebookUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="flex items-center gap-space-sm p-3.5 rounded-xl bg-surface-container-lowest hover:bg-primary-container hover:text-on-primary group transition-colors shadow-sm"
                    >
                      <div className="w-9 h-9 rounded-lg bg-primary-fixed group-hover:bg-surface-container-lowest/20 flex items-center justify-center shrink-0">
                        <span className="material-symbols-outlined text-primary group-hover:text-on-primary text-[20px]">
                          thumb_up
                        </span>
                      </div>
                      <div className="overflow-hidden">
                        <p className="font-label-lg text-label-lg text-on-surface group-hover:text-on-primary truncate">
                          Facebook เพจโรงเรียน
                        </p>
                        <p className="font-label-sm text-label-sm text-on-surface-variant group-hover:text-primary-fixed truncate">
                          {config.contact.facebookName}
                        </p>
                      </div>
                    </a>

                    <a
                      href={config.contact.lineOfficialUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="flex items-center gap-space-sm p-3.5 rounded-xl bg-surface-container-lowest hover:bg-primary-container hover:text-on-primary group transition-colors shadow-sm"
                    >
                      <div className="w-9 h-9 rounded-lg bg-tertiary-fixed group-hover:bg-surface-container-lowest/20 flex items-center justify-center shrink-0">
                        <span className="material-symbols-outlined text-tertiary group-hover:text-on-primary text-[20px]">
                          chat
                        </span>
                      </div>
                      <div className="overflow-hidden">
                        <p className="font-label-lg text-label-lg text-on-surface group-hover:text-on-primary truncate">
                          LINE Official
                        </p>
                        <p className="font-label-sm text-label-sm text-on-surface-variant group-hover:text-primary-fixed truncate">
                          {config.contact.lineOfficialId}
                        </p>
                      </div>
                    </a>
                  </div>
                </div>
              </div>

              {/* Right Column: Contact Form */}
              <div className="lg:col-span-7">
                <div className="bg-surface-container-lowest rounded-2xl p-8 lg:p-10 shadow-[0_12px_32px_rgba(13,28,46,0.06)]">
                  <div className="mb-8">
                    <span className="font-label-lg text-label-lg text-primary uppercase tracking-wider">
                      แบบฟอร์มติดต่อออนไลน์
                    </span>
                    <h2 className="font-headline-md text-headline-md text-on-surface mt-1">
                      ส่งข้อความถึงโรงเรียน
                    </h2>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                      กรุณากรอกข้อมูลให้ครบถ้วน เจ้าหน้าที่งานสารบรรณและประชาสัมพันธ์จะติดต่อกลับภายใน
                      1 – 2 วันทำการ
                    </p>
                  </div>

                  <form onSubmit={handleContactSubmit} className="space-y-6">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                      <div>
                        <label
                          htmlFor="contact-name"
                          className="block font-label-lg text-label-lg text-on-surface mb-2"
                        >
                          ชื่อ - นามสกุล <span className="text-error">*</span>
                        </label>
                        <input
                          id="contact-name"
                          type="text"
                          required
                          value={contactName}
                          onChange={(e) => setContactName(e.target.value)}
                          placeholder="ระบุชื่อ-นามสกุลผู้ติดต่อ"
                          className="w-full px-4 py-3 rounded-xl bg-surface-container-low text-on-surface font-body-sm text-body-sm placeholder:text-on-surface-variant/60 focus:outline-none focus:ring-2 focus:ring-primary transition-shadow"
                        />
                      </div>

                      <div>
                        <label
                          htmlFor="contact-phone"
                          className="block font-label-lg text-label-lg text-on-surface mb-2"
                        >
                          อีเมล หรือ เบอร์โทรศัพท์{' '}
                          <span className="text-error">*</span>
                        </label>
                        <input
                          id="contact-phone"
                          type="text"
                          required
                          value={contactEmailOrPhone}
                          onChange={(e) =>
                            setContactEmailOrPhone(e.target.value)
                          }
                          placeholder="เช่น 081-234-5678 หรือ name@email.com"
                          className="w-full px-4 py-3 rounded-xl bg-surface-container-low text-on-surface font-body-sm text-body-sm placeholder:text-on-surface-variant/60 focus:outline-none focus:ring-2 focus:ring-primary transition-shadow"
                        />
                      </div>
                    </div>

                    <div>
                      <label
                        htmlFor="contact-subject"
                        className="block font-label-lg text-label-lg text-on-surface mb-2"
                      >
                        หัวข้อเรื่องที่ต้องการติดต่อ{' '}
                        <span className="text-error">*</span>
                      </label>
                      <select
                        id="contact-subject"
                        required
                        value={contactSubject}
                        onChange={(e) => setContactSubject(e.target.value)}
                        className="w-full px-4 py-3 rounded-xl bg-surface-container-low text-on-surface font-body-sm text-body-sm focus:outline-none focus:ring-2 focus:ring-primary transition-shadow"
                      >
                        <option value="" disabled>
                          -- เลือกหัวข้อเรื่องที่ต้องการติดต่อ --
                        </option>
                        <option value="admission">
                          สอบถามข้อมูลการรับสมัครนักเรียนใหม่ (ม.1 / ม.4)
                        </option>
                        <option value="academic">
                          ขอเอกสารทางการศึกษา (ปพ.1 / ปพ.7 / ใบรับรอง)
                        </option>
                        <option value="general">
                          ติดต่อราชการทั่วไป / ประสานงานหน่วยงานภายนอก
                        </option>
                        <option value="feedback">
                          แจ้งข้อเสนอแนะ / ร้องเรียนการให้บริการ
                        </option>
                      </select>
                    </div>

                    <div>
                      <label
                        htmlFor="contact-message"
                        className="block font-label-lg text-label-lg text-on-surface mb-2"
                      >
                        รายละเอียดข้อความ <span className="text-error">*</span>
                      </label>
                      <textarea
                        id="contact-message"
                        rows={5}
                        required
                        value={contactMessage}
                        onChange={(e) => setContactMessage(e.target.value)}
                        placeholder="ระบุรายละเอียดหรือคำถามที่ต้องการให้โรงเรียนตรวจสอบ..."
                        className="w-full px-4 py-3 rounded-xl bg-surface-container-low text-on-surface font-body-sm text-body-sm placeholder:text-on-surface-variant/60 focus:outline-none focus:ring-2 focus:ring-primary transition-shadow resize-y"
                      />
                    </div>

                    {contactSubmittedName && (
                      <div className="p-4 rounded-xl bg-primary-fixed text-on-primary-fixed flex items-start gap-space-sm">
                        <span className="material-symbols-outlined text-primary text-[22px] shrink-0">
                          check_circle
                        </span>
                        <div>
                          <p className="font-label-lg text-label-lg">
                            ส่งข้อความเรียบร้อยแล้ว
                          </p>
                          <p className="font-body-sm text-body-sm mt-0.5">
                            ขอบคุณคุณ{contactSubmittedName}{' '}
                            ทางโรงเรียนได้รับข้อความของท่านแล้ว
                            และจะดำเนินการติดต่อกลับโดยเร็วที่สุด
                          </p>
                        </div>
                      </div>
                    )}

                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pt-2">
                      <p className="font-label-md text-label-md text-on-surface-variant flex items-center gap-1.5">
                        <span className="material-symbols-outlined text-[18px] text-primary">
                          verified_user
                        </span>
                        <span>
                          ข้อมูลของท่านจะถูกเก็บรักษาตามนโยบายคุ้มครองข้อมูลส่วนบุคคล
                          (PDPA)
                        </span>
                      </p>
                      <button
                        type="submit"
                        className="inline-flex items-center justify-center gap-space-sm px-8 py-3.5 rounded-xl bg-gradient-to-r from-primary to-primary-container text-on-primary font-label-lg text-label-lg shadow-sm hover:opacity-95 transition-opacity shrink-0"
                      >
                        <span className="material-symbols-outlined text-[20px]">
                          send
                        </span>
                        <span>ส่งข้อความ</span>
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            </div>
          </section>

          {/* School Map & Directions Section */}
          <section className="bg-surface-container-low py-14 lg:py-16">
            <div className="max-w-7xl mx-auto px-6 lg:px-12">
              <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-8">
                <div>
                  <span className="font-label-lg text-label-lg text-secondary uppercase tracking-wider">
                    แผนที่และการเดินทาง
                  </span>
                  <h2 className="font-headline-md text-headline-md text-on-surface mt-1">
                    แผนที่ตั้ง{schoolDisplayName}
                  </h2>
                </div>
                <a
                  href={config.contact.googleMapsUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-space-xs px-5 py-2.5 rounded-xl bg-surface-container-lowest text-primary font-label-lg text-label-lg shadow-sm hover:bg-primary-container hover:text-on-primary transition-colors w-fit"
                >
                  <span className="material-symbols-outlined text-[20px]">
                    map
                  </span>
                  <span>เปิดใน Google Maps</span>
                </a>
              </div>

              <div className="bg-surface-container-lowest rounded-2xl p-3 shadow-[0_12px_32px_rgba(13,28,46,0.06)]">
                <div className="relative w-full h-[360px] lg:h-[420px] rounded-xl overflow-hidden bg-surface-container">
                  <img
                    alt={`แผนที่จำลองและทัศนียภาพ${schoolDisplayName}`}
                    className="w-full h-full object-cover"
                    src={config.contact.mapPreviewImageUrl}
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-on-surface/80 via-on-surface/20 to-transparent" />
                  <div className="absolute bottom-6 left-6 right-6 sm:right-auto sm:max-w-md bg-surface-container-lowest/95 backdrop-blur-xl rounded-xl p-5 shadow-lg">
                    <div className="flex items-start gap-space-md">
                      <div className="w-11 h-11 rounded-xl bg-primary-container text-on-primary flex items-center justify-center shrink-0">
                        <span className="material-symbols-outlined text-[24px]">
                          school
                        </span>
                      </div>
                      <div>
                        <h3 className="font-title-md text-title-md text-on-surface">
                          {schoolDisplayName}
                        </h3>
                        <p className="font-body-sm text-body-sm text-on-surface-variant mt-1">
                          {config.contact.mapDirectionsNote}
                        </p>
                        <div className="flex flex-wrap items-center gap-3 mt-3">
                          <span className="inline-flex items-center gap-1 font-label-sm text-label-sm px-2.5 py-1 rounded-full bg-primary-fixed text-on-primary-fixed">
                            <span className="material-symbols-outlined text-[14px]">
                              directions_car
                            </span>
                            มีจุดจอดรถผู้มาติดต่อราชการ
                          </span>
                          <span className="inline-flex items-center gap-1 font-label-sm text-label-sm px-2.5 py-1 rounded-full bg-secondary-fixed text-on-secondary-fixed">
                            <span className="material-symbols-outlined text-[14px]">
                              security
                            </span>
                            แลกบัตรที่ป้อมยามประตู 1
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </main>
      )}

      {/* ── Modal อ่านข่าวประชาสัมพันธ์ฉบับเต็ม ──────────────────────────── */}
      {selectedArticle && (
        <div
          className="fixed inset-0 z-50 bg-on-surface/60 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6"
          onClick={() => setSelectedArticle(null)}
        >
          <div
            className="bg-surface-container-lowest rounded-2xl max-w-3xl w-full max-h-[90vh] overflow-y-auto shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="relative h-64 sm:h-80">
              <img
                src={selectedArticle.imageUrl}
                alt={selectedArticle.imageAlt}
                className="w-full h-full object-cover"
              />
              <button
                type="button"
                onClick={() => setSelectedArticle(null)}
                className="absolute top-4 right-4 w-10 h-10 rounded-full bg-surface-container-lowest/90 text-on-surface flex items-center justify-center shadow-md hover:bg-surface-container-lowest"
                aria-label="ปิดหน้าต่างข่าว"
              >
                <span className="material-symbols-outlined text-[22px]">
                  close
                </span>
              </button>
              <span className="absolute bottom-4 left-6 px-3.5 py-1.5 rounded-full bg-secondary-container text-on-secondary-fixed font-label-md text-label-md shadow-sm">
                {selectedArticle.badgeText}
              </span>
            </div>

            <div className="p-6 sm:p-8 space-y-5">
              <div className="flex flex-wrap items-center gap-2 text-on-surface-variant font-label-md text-label-md">
                <span className="material-symbols-outlined text-[18px]">
                  calendar_today
                </span>
                <span>{selectedArticle.dateLabel}</span>
                {selectedArticle.author && (
                  <>
                    <span>•</span>
                    <span>{selectedArticle.author}</span>
                  </>
                )}
              </div>

              <h2 className="font-headline-md text-headline-md text-on-surface">
                {selectedArticle.title}
              </h2>

              <div className="space-y-4 font-body-md text-body-md text-on-surface-variant leading-relaxed">
                <p className="font-medium text-on-surface">
                  {selectedArticle.summary}
                </p>
                {selectedArticle.fullParagraphs.map((para, idx) => (
                  <p key={idx}>{para}</p>
                ))}
              </div>

              {/* ไฟล์เอกสารแนบและดาวน์โหลดท้ายข่าว (PDF & Documents) */}
              {selectedArticle.attachments &&
                selectedArticle.attachments.length > 0 && (
                  <div className="space-y-2.5 pt-2">
                    <h3 className="font-title-md text-title-md text-on-surface flex items-center gap-2">
                      <span className="material-symbols-outlined text-primary text-[20px]">
                        attach_file
                      </span>
                      <span>เอกสารแนบและประกาศฉบับเต็ม (ดาวน์โหลด)</span>
                    </h3>
                    <div className="space-y-2">
                      {selectedArticle.attachments.map((att) => (
                        <div
                          key={att.id}
                          className="flex items-center justify-between gap-3 rounded-xl bg-surface-container-low p-3.5"
                        >
                          <div className="flex items-center gap-3 min-w-0">
                            <div className="w-10 h-10 rounded-lg bg-error-container text-on-error-container flex items-center justify-center shrink-0">
                              <span className="material-symbols-outlined text-[20px]">
                                picture_as_pdf
                              </span>
                            </div>
                            <div className="min-w-0">
                              <p className="font-label-lg text-on-surface truncate">
                                {att.title}
                              </p>
                              {att.fileSizeLabel && (
                                <p className="font-label-sm text-on-surface-variant">
                                  {att.fileSizeLabel}
                                </p>
                              )}
                            </div>
                          </div>
                          {att.url ? (
                            <a
                              href={att.url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center gap-1.5 rounded-full bg-primary-container px-4 py-2 font-label-md text-on-primary hover:bg-primary transition-colors shrink-0"
                            >
                              <span className="material-symbols-outlined text-[16px]">
                                download
                              </span>
                              <span>ดาวน์โหลด</span>
                            </a>
                          ) : (
                            <span className="text-xs text-on-surface-variant shrink-0">
                              รอแนบลิงก์
                            </span>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}

              {/* แกลเลอรีประมวลภาพบรรยากาศ */}
              {selectedArticle.galleryImages &&
                selectedArticle.galleryImages.length > 0 && (
                  <div className="space-y-2.5 pt-2">
                    <h3 className="font-title-md text-title-md text-on-surface flex items-center gap-2">
                      <span className="material-symbols-outlined text-primary text-[20px]">
                        photo_library
                      </span>
                      <span>ประมวลภาพบรรยากาศและกิจกรรม</span>
                    </h3>
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                      {selectedArticle.galleryImages.map((imgUrl, idx) => (
                        <a
                          key={idx}
                          href={logoSrc(imgUrl) ?? imgUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="block rounded-xl overflow-hidden bg-surface-container aspect-[4/3]"
                        >
                          <img
                            src={logoSrc(imgUrl) ?? imgUrl}
                            alt={`${selectedArticle.title} ภาพที่ ${idx + 1}`}
                            className="w-full h-full object-cover hover:scale-105 transition-transform"
                          />
                        </a>
                      ))}
                    </div>
                  </div>
                )}

              <div className="pt-4 border-t border-outline-variant/25 flex items-center justify-between">
                <span className="font-label-md text-label-md text-on-surface-variant">
                  {schoolDisplayName}
                </span>
                <button
                  type="button"
                  onClick={() => setSelectedArticle(null)}
                  className="px-5 py-2.5 rounded-xl bg-primary-container text-on-primary font-label-lg text-label-lg hover:bg-primary transition-colors"
                >
                  ปิดหน้าต่างนี้
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Modal ระบบตรวจสอบผลการเรียนออนไลน์ (SGS Online Portal) ──────── */}
      {sgsModalOpen && (
        <div
          className="fixed inset-0 z-50 bg-on-surface/60 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6"
          onClick={() => setSgsModalOpen(false)}
        >
          <div
            className="bg-surface-container-lowest rounded-2xl max-w-5xl w-full max-h-[92vh] overflow-y-auto shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="sticky top-0 z-10 bg-gradient-to-r from-primary via-primary-container to-tertiary-container text-on-primary px-6 py-5 flex items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-xl bg-surface-container-lowest/15 flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-secondary-container text-[24px]">
                    fact_check
                  </span>
                </div>
                <div>
                  <span className="font-label-sm text-label-sm text-primary-fixed uppercase tracking-wider">
                    SGS ONLINE • ระบบวัดและประเมินผลการเรียน
                  </span>
                  <h2 className="font-headline-sm text-headline-sm text-on-primary">
                    ตรวจสอบผลการเรียนและคะแนนสะสมทุกชั้นปี ({schoolDisplayName})
                  </h2>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setSgsModalOpen(false)}
                className="w-10 h-10 rounded-full bg-surface-container-lowest/15 hover:bg-surface-container-lowest/25 text-on-primary flex items-center justify-center transition-colors"
                aria-label="ปิดหน้าต่าง SGS"
              >
                <span className="material-symbols-outlined text-[22px]">
                  close
                </span>
              </button>
            </div>

            <div className="p-6 sm:p-8 space-y-6">
              {/* Search Form */}
              <form
                onSubmit={handleLookupSgsOnline}
                className="bg-surface-container-low rounded-2xl p-5 grid grid-cols-1 sm:grid-cols-12 gap-4 items-end"
              >
                <div className="sm:col-span-5">
                  <label className="block font-label-lg text-label-lg text-on-surface mb-1.5">
                    รหัสประจำตัวนักเรียน <span className="text-error">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    value={sgsCodeInput}
                    onChange={(e) => setSgsCodeInput(e.target.value)}
                    placeholder="เช่น 5902116"
                    className="w-full px-4 py-2.5 rounded-xl bg-surface-container-lowest border border-outline-variant/40 text-on-surface font-body-sm text-body-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  />
                </div>

                <div className="sm:col-span-5">
                  <label className="block font-label-lg text-label-lg text-on-surface mb-1.5">
                    เลขบัตรประชาชน 13 หลัก
                  </label>
                  <input
                    type="text"
                    value={sgsVerifyInput}
                    onChange={(e) => setSgsVerifyInput(e.target.value)}
                    placeholder="เลขบัตรประชาชน 13 หลักของนักเรียน"
                        inputMode="numeric"
                        required
                    className="w-full px-4 py-2.5 rounded-xl bg-surface-container-lowest border border-outline-variant/40 text-on-surface font-body-sm text-body-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  />
                </div>

                <div className="sm:col-span-2">
                  <button
                    type="submit"
                    disabled={sgsLoading}
                    className="w-full inline-flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-xl bg-primary-container hover:bg-primary text-on-primary font-label-lg text-label-lg transition-colors"
                  >
                    <span className="material-symbols-outlined text-[18px]">
                      search
                    </span>
                    <span>{sgsLoading ? 'กำลังค้นหา...' : 'ดูผลการเรียน'}</span>
                  </button>
                </div>
              </form>

              {sgsError && (
                <div className="p-4 rounded-xl bg-error-container text-on-error-container flex items-center gap-2 font-body-sm text-body-sm">
                  <span className="material-symbols-outlined text-[20px]">
                    error
                  </span>
                  <span>{sgsError}</span>
                </div>
              )}

              {/* Student Result & Transcript */}
              {sgsStudentResult && sgsTranscriptResult && (
                <div className="space-y-6">
                  {/* Student Profile & Summary KPIs */}
                  <div className="bg-surface-container-lowest rounded-2xl border border-outline-variant/30 p-6 space-y-5">
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-outline-variant/20 pb-4">
                      <div>
                        <span className="px-3 py-1 rounded-full bg-primary-fixed text-primary font-label-sm text-label-sm">
                          รหัสนักเรียน {sgsStudentResult.student_code} • ชั้น{' '}
                          {sgsStudentResult.classroom_name} (เลขที่{' '}
                          {sgsStudentResult.seat_no ?? '-'})
                        </span>
                        <h3 className="font-headline-md text-headline-md text-on-surface mt-2">
                          {sgsStudentResult.prefix ?? ''}
                          {sgsStudentResult.first_name}{' '}
                          {sgsStudentResult.last_name}
                        </h3>
                        <p className="font-body-sm text-body-sm text-on-surface-variant">
                          แผนการเรียน: {sgsStudentResult.study_plan}
                        </p>
                      </div>

                      <button
                        type="button"
                        onClick={() => window.print()}
                        className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-surface-container-low hover:bg-surface-container text-primary font-label-lg text-label-lg transition-colors w-fit"
                      >
                        <span className="material-symbols-outlined text-[18px]">
                          print
                        </span>
                        <span>พิมพ์ใบรายงานผลการเรียน</span>
                      </button>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                      <div className="rounded-xl bg-primary-fixed/40 p-4">
                        <p className="font-label-md text-label-md text-primary">
                          เกรดเฉลี่ยสะสมทุกชั้นปี (GPAX)
                        </p>
                        <p className="font-headline-lg text-headline-lg text-primary mt-1 tabular-nums">
                          {sgsTranscriptResult.overallGpax.toFixed(2)}
                        </p>
                      </div>

                      <div className="rounded-xl bg-surface-container-low p-4">
                        <p className="font-label-md text-label-md text-on-surface-variant">
                          หน่วยกิตที่สอบผ่าน / ลงทะเบียนสะสม
                        </p>
                        <p className="font-headline-lg text-headline-lg text-on-surface mt-1 tabular-nums">
                          {sgsTranscriptResult.totalCreditsEarned.toFixed(1)} /{' '}
                          {sgsTranscriptResult.totalCreditsAttempted.toFixed(1)}
                        </p>
                      </div>

                      <div className="rounded-xl bg-secondary-fixed/50 p-4">
                        <p className="font-label-md text-label-md text-secondary">
                          จำนวนภาคเรียนที่มีผลการเรียน
                        </p>
                        <p className="font-headline-lg text-headline-lg text-secondary mt-1 tabular-nums">
                          {sgsTranscriptResult.terms.length} ภาคเรียน
                        </p>
                      </div>
                    </div>
                  </div>

                  {/* Term-by-Term Score & Grade Tables */}
                  {sgsTranscriptResult.terms.length === 0 ? (
                    <div className="rounded-2xl bg-surface-container-low p-10 text-center">
                      <span className="material-symbols-outlined text-on-surface-variant text-[40px] mb-2">
                        assignment_late
                      </span>
                      <p className="font-title-md text-title-md text-on-surface">
                        พบข้อมูลนักเรียนในระบบ แต่ยังไม่มีรายการคะแนนที่ประกาศในภาคเรียนนี้
                      </p>
                    </div>
                  ) : (
                    <div className="space-y-5">
                      {sgsTranscriptResult.terms.map((term) => (
                        <div
                          key={`${term.gradeLevel}-${term.termNo}-${term.yearBe}`}
                          className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest overflow-hidden"
                        >
                          <div className="bg-surface-container-low px-5 py-3.5 flex flex-wrap items-center justify-between gap-2">
                            <div className="flex items-center gap-2">
                              <span className="px-3 py-1 rounded-full bg-primary-container text-on-primary font-label-md text-label-md">
                                ชั้น {term.gradeLevel}
                              </span>
                              <span className="font-title-md text-title-md text-on-surface">
                                ภาคเรียนที่ {term.termNo} / ปีการศึกษา{' '}
                                {term.yearBe}
                              </span>
                            </div>
                            <div className="flex flex-wrap items-center gap-2 font-label-md text-label-md">
                              <span className="px-3 py-1 rounded-full bg-surface-container-lowest text-on-surface">
                                หน่วยกิต: {term.termCreditsEarned}/
                                {term.termCreditsAttempted}
                              </span>
                              <span className="px-3 py-1 rounded-full bg-primary-fixed text-primary">
                                GPA ประจำภาค: {term.termGpa.toFixed(2)}
                              </span>
                              <span className="px-3 py-1 rounded-full bg-secondary-fixed text-on-secondary-fixed">
                                GPAX สะสม:{' '}
                                {term.cumulativeGpaxAfterTerm.toFixed(2)}
                              </span>
                            </div>
                          </div>

                          <div className="overflow-x-auto">
                            <table className="w-full text-left border-collapse text-xs">
                              <thead>
                                <tr className="border-b border-outline-variant/20 bg-surface text-on-surface-variant">
                                  <th className="px-4 py-2.5">รหัสวิชา</th>
                                  <th className="px-4 py-2.5">ชื่อรายวิชา</th>
                                  <th className="px-3 py-2.5 text-center">
                                    หน่วยกิต
                                  </th>
                                  <th className="px-3 py-2.5 text-center">
                                    คะแนนเก็บ
                                  </th>
                                  <th className="px-3 py-2.5 text-center">
                                    คะแนนสมุด
                                  </th>
                                  <th className="px-3 py-2.5 text-center">
                                    กลางภาค
                                  </th>
                                  <th className="px-3 py-2.5 text-center">
                                    ปลายภาค
                                  </th>
                                  <th className="px-3 py-2.5 text-center">
                                    รวม (100)
                                  </th>
                                  <th className="px-3 py-2.5 text-center">
                                    เกรด
                                  </th>
                                  <th className="px-3 py-2.5 text-center">
                                    เวลาเรียน
                                  </th>
                                </tr>
                              </thead>
                              <tbody className="divide-y divide-outline-variant/15">
                                {term.rows.map(({ record, computed }) => (
                                  <tr
                                    key={record.subject_code}
                                    className="hover:bg-surface-container-low/50"
                                  >
                                    <td className="px-4 py-2.5 font-mono font-semibold text-primary">
                                      {record.subject_code}
                                    </td>
                                    <td className="px-4 py-2.5 font-medium text-on-surface">
                                      {record.subject_name}
                                    </td>
                                    <td className="px-3 py-2.5 text-center tabular-nums">
                                      {record.subject_type === 'กิจกรรม'
                                        ? '-'
                                        : record.credits.toFixed(1)}
                                    </td>
                                    <td className="px-3 py-2.5 text-center tabular-nums">
                                      {record.pre_mid_work +
                                        record.post_mid_work +
                                        record.affective_score}
                                    </td>
                                    <td className="px-3 py-2.5 text-center tabular-nums">
                                      {computed.totalNotebook}
                                    </td>
                                    <td className="px-3 py-2.5 text-center tabular-nums">
                                      {record.midterm_score}
                                    </td>
                                    <td className="px-3 py-2.5 text-center tabular-nums">
                                      {record.final_score}
                                    </td>
                                    <td className="px-3 py-2.5 text-center font-mono font-bold text-on-surface tabular-nums">
                                      {computed.totalScore}
                                    </td>
                                    <td className="px-3 py-2.5 text-center">
                                      <span className="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full bg-primary-fixed text-primary font-bold">
                                        {computed.displayGrade}
                                      </span>
                                    </td>
                                    <td className="px-3 py-2.5 text-center tabular-nums text-on-surface-variant">
                                      {computed.attendancePercent}%
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
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ── Footer (ตรงตาม webschool.html) ───────────────────────────────── */}
      <footer className="bg-on-surface text-inverse-on-surface pt-16 pb-10 print:hidden">
        <div className="max-w-7xl mx-auto px-6 lg:px-12">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-10 pb-12 border-b border-outline-variant/20">
            <div className="lg:col-span-5 flex flex-col gap-space-md">
              <div className="flex items-center gap-space-md">
                <div className="w-11 h-11 rounded-xl bg-primary-container flex items-center justify-center shrink-0 overflow-hidden">
                  {resolvedSchoolLogo ? (
                    <img
                      src={resolvedSchoolLogo}
                      alt={schoolDisplayName}
                      className="w-full h-full object-contain bg-white p-0.5"
                    />
                  ) : (
                    <span className="material-symbols-outlined text-on-primary text-[24px]">
                      school
                    </span>
                  )}
                </div>
                <div>
                  <p className="font-title-lg text-title-lg text-on-primary">
                    {schoolDisplayName}
                  </p>
                  <p className="font-label-md text-label-md text-inverse-primary">
                    {schoolAffiliation}
                  </p>
                </div>
              </div>
              <p className="font-body-sm text-body-sm text-surface-variant max-w-md">
                {config.about.visionText}
              </p>
            </div>

            <div className="lg:col-span-3 flex flex-col gap-space-sm">
              <p className="font-title-md text-title-md text-on-primary mb-2">
                แผนผังเว็บไซต์
              </p>
              {NAV_ITEMS.map((item) => (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => switchTab(item.key)}
                  className="text-left font-body-sm text-body-sm text-surface-variant hover:text-on-primary transition-colors"
                >
                  {item.label}
                </button>
              ))}
              {canManagePublicWeb && (
                <Link
                  to="/public-web-settings"
                  className="text-left font-body-sm text-body-sm text-secondary-container hover:underline mt-1"
                >
                  → ตั้งค่าข้อมูลหน้าเว็บสาธารณะ
                </Link>
              )}
              <Link
                to="/"
                className="text-left font-body-sm text-body-sm text-secondary-container hover:underline mt-1"
              >
                {isLoggedIn
                  ? '→ กลับสู่ระบบบริหารจัดการโรงเรียน'
                  : '→ เข้าสู่ระบบสำหรับครูและบุคลากร'}
              </Link>
            </div>

            <div className="lg:col-span-4 flex flex-col gap-space-sm">
              <p className="font-title-md text-title-md text-on-primary mb-2">
                ติดต่อโรงเรียน
              </p>
              <div className="flex items-start gap-space-sm text-surface-variant font-body-sm text-body-sm">
                <span className="material-symbols-outlined text-[20px] text-secondary-container shrink-0 mt-0.5">
                  location_on
                </span>
                <span>{config.contact.address}</span>
              </div>
              <div className="flex items-center gap-space-sm text-surface-variant font-body-sm text-body-sm">
                <span className="material-symbols-outlined text-[20px] text-secondary-container shrink-0">
                  call
                </span>
                <span>โทรศัพท์: {config.contact.phoneMain}</span>
              </div>
              <div className="flex items-center gap-space-sm text-surface-variant font-body-sm text-body-sm">
                <span className="material-symbols-outlined text-[20px] text-secondary-container shrink-0">
                  mail
                </span>
                <span>อีเมล: {config.contact.emailMain}</span>
              </div>
            </div>
          </div>

          <div className="pt-8 flex flex-col sm:flex-row items-center justify-between gap-4 font-label-md text-label-md text-surface-variant">
            <p>© 2568 {schoolDisplayName}. สงวนลิขสิทธิ์ตามกฎหมาย.</p>
            <p>พัฒนาเพื่อการบริหารจัดการและประชาสัมพันธ์สถานศึกษา</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
