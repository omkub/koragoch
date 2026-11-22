import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Building2,
  Calendar,
  Check,
  ExternalLink,
  FileText,
  Globe,
  GraduationCap,
  Home,
  Megaphone,
  Phone,
  Plus,
  RefreshCw,
  RotateCcw,
  Save,
  Star,
  Trash2,
  Users,
} from 'lucide-react';
import {
  deletePublicContactSubmission,
  fetchPublicSchoolWebConfig,
  loadLocalPublicWebConfig,
  loadPublicContactSubmissions,
  resetPublicSchoolWebConfig,
  savePublicSchoolWebConfig,
  type NewsFilterCat,
  type PublicCalendarEventItem,
  type PublicContactSubmission,
  type PublicDownloadDocItem,
  type PublicNewsItem,
  type PublicSchoolWebConfig,
  type PublicStaffItem,
  type StaffDeptFilter,
} from './publicWebConfig';
import { fetchSchoolStaffMembers } from './staffDivisionMapping';
import type { SchoolBasic } from './types';

interface PublicWebSettingsPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canManage: boolean;
}

type SettingsSectionKey =
  | 'home'
  | 'news'
  | 'staff'
  | 'students'
  | 'about'
  | 'contact';

const SECTION_TABS: {
  key: SettingsSectionKey;
  label: string;
  icon: typeof Home;
}[] = [
  { key: 'home', label: '1. หน้าแรก & สาร ผอ.', icon: Home },
  { key: 'news', label: '2. ข่าวประชาสัมพันธ์', icon: Megaphone },
  { key: 'staff', label: '3. ทำเนียบบุคลากร', icon: Users },
  { key: 'students', label: '4. ข้อมูลนักเรียน & เอกสาร', icon: GraduationCap },
  { key: 'about', label: '5. ข้อมูลโรงเรียน & วิสัยทัศน์', icon: Building2 },
  { key: 'contact', label: '6. ติดต่อ & โซเชียลมีเดีย', icon: Phone },
];

const NEWS_CATEGORY_OPTIONS: {
  value: Exclude<NewsFilterCat, 'all'>;
  label: string;
  badgeStyle: PublicNewsItem['badgeStyle'];
}[] = [
  { value: 'academic', label: 'ข่าววิชาการ', badgeStyle: 'tertiary' },
  { value: 'activity', label: 'กิจกรรมนักเรียน', badgeStyle: 'primary' },
  { value: 'admission', label: 'ประกาศรับสมัคร', badgeStyle: 'secondary' },
  { value: 'procurement', label: 'จัดซื้อจัดจ้าง', badgeStyle: 'surface' },
];

const STAFF_DEPT_OPTIONS: {
  value: Exclude<StaffDeptFilter, 'all'>;
  label: string;
  badgeText: string;
  tone: PublicStaffItem['deptBadgeTone'];
}[] = [
  {
    value: 'executive',
    label: 'คณะผู้บริหาร',
    badgeText: 'คณะผู้บริหารสถานศึกษา',
    tone: 'primary',
  },
  {
    value: 'thai',
    label: 'กลุ่มสาระฯ ภาษาไทย',
    badgeText: 'กลุ่มสาระฯ ภาษาไทย',
    tone: 'secondary',
  },
  {
    value: 'math',
    label: 'กลุ่มสาระฯ คณิตศาสตร์',
    badgeText: 'กลุ่มสาระฯ คณิตศาสตร์',
    tone: 'tertiary',
  },
  {
    value: 'science',
    label: 'วิทยาศาสตร์และเทคโนโลยี',
    badgeText: 'วิทยาศาสตร์และเทคโนโลยี',
    tone: 'primary',
  },
  {
    value: 'social',
    label: 'สังคมศึกษา ศาสนา และวัฒนธรรม',
    badgeText: 'สังคมศึกษา ศาสนา และวัฒนธรรม',
    tone: 'secondary',
  },
  {
    value: 'foreign',
    label: 'กลุ่มสาระฯ ภาษาต่างประเทศ',
    badgeText: 'กลุ่มสาระฯ ภาษาต่างประเทศ',
    tone: 'tertiary',
  },
  {
    value: 'support',
    label: 'สายสนับสนุนการสอน',
    badgeText: 'สายสนับสนุนการสอน',
    tone: 'primary',
  },
];

export default function PublicWebSettingsPage({
  school,
  schoolId,
  canManage,
}: PublicWebSettingsPageProps) {
  const [section, setSection] = useState<SettingsSectionKey>('home');
  const [config, setConfig] = useState<PublicSchoolWebConfig>(() =>
    loadLocalPublicWebConfig(schoolId),
  );
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [importingStaff, setImportingStaff] = useState(false);
  const [contactMessages, setContactMessages] = useState<
    PublicContactSubmission[]
  >([]);
  const [notice, setNotice] = useState<{
    type: 'ok' | 'info' | 'error';
    text: string;
  } | null>(null);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setConfig(loadLocalPublicWebConfig(schoolId));
    loadPublicContactSubmissions(schoolId).then((m) => {
      if (alive) setContactMessages(m);
    });
    fetchPublicSchoolWebConfig(schoolId)
      .then((loaded) => {
        if (alive) setConfig(loaded);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [schoolId]);

  const schoolDisplayName =
    school?.fullName || 'โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก';

  if (!canManage) {
    return (
      <div className="card">
        <div className="card-body py-12 text-center space-y-3">
          <Globe className="mx-auto h-10 w-10 text-slate-400" />
          <h2 className="text-base font-semibold text-ink">
            ไม่มีสิทธิ์ตั้งค่าหน้าเว็บโรงเรียนสาธารณะ
          </h2>
          <p className="text-sm text-slate-500 max-w-md mx-auto">
            เฉพาะผู้ดูแลส่วนกลาง แอดมินโรงเรียน
            หรือครูที่ได้รับมอบหมายหน้าที่ตั้งค่าเว็บโรงเรียนสาธารณะเท่านั้นที่สามารถแก้ไขข้อมูลในหน้านี้ได้
          </p>
          <div className="pt-2">
            <Link
              to={schoolId ? `/public/${schoolId}` : '/public'}
              className="btn-primary"
            >
              <ExternalLink className="h-4 w-4" />
              เปิดดูหน้าเว็บโรงเรียนสาธารณะ
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const handleSave = async () => {
    setSaving(true);
    setNotice(null);
    try {
      const res = await savePublicSchoolWebConfig(schoolId, config);
      setNotice({
        type: 'ok',
        text: res.savedToDb
          ? 'บันทึกข้อมูลหน้าเว็บโรงเรียนสาธารณะลงฐานข้อมูลเรียบร้อยแล้ว'
          : 'บันทึกข้อมูลหน้าเว็บโรงเรียนสาธารณะเรียบร้อยแล้ว (พร้อมแสดงผลที่หน้าเว็บสาธารณะทันที)',
      });
    } catch (err) {
      setNotice({
        type: 'error',
        text:
          err instanceof Error
            ? err.message
            : 'เกิดข้อผิดพลาดในการบันทึกข้อมูล',
      });
    } finally {
      setSaving(false);
    }
  };

  const handleResetDefault = async () => {
    if (
      !window.confirm(
        'ต้องการคืนค่าข้อมูลหน้าเว็บสาธารณะทั้งหมดกลับเป็นค่าเริ่มต้นตามต้นฉบับหรือไม่?',
      )
    ) {
      return;
    }
    const fresh = await resetPublicSchoolWebConfig(schoolId);
    setConfig(fresh);
    setNotice({
      type: 'info',
      text: 'คืนค่าข้อมูลหน้าเว็บสาธารณะกลับเป็นค่าเริ่มต้นเรียบร้อยแล้ว',
    });
  };

  const handleImportStaffFromDb = async () => {
    if (!schoolId) return;
    setImportingStaff(true);
    setNotice(null);
    try {
      const members = await fetchSchoolStaffMembers(schoolId);

      if (!members || members.length === 0) {
        setNotice({
          type: 'info',
          text: 'ไม่พบรายชื่อบุคลากรในตาราง Teachers ของโรงเรียนนี้ จึงคงรายชื่อตัวอย่างไว้',
        });
        return;
      }

      const nextExecs: PublicStaffItem[] = [];
      const nextTeachers: PublicStaffItem[] = [];

      for (const raw of members) {
        const fullName = (raw.fullName ?? '').trim();
        if (!fullName) continue;
        const roleName = (raw.roleName || 'ครูชำนาญการ').trim();
        const isDir =
          roleName.includes('ผู้อำนวยการ') && !roleName.includes('รอง');
        const isVp = roleName.includes('รองผู้อำนวยการ');

        if (isDir || isVp) {
          nextExecs.push({
            id: `db-exec-${raw.id_user}`,
            name: fullName,
            role: roleName,
            dept: 'executive',
            deptBadgeText: isDir
              ? 'ผู้อำนวยการสถานศึกษา'
              : 'รองผู้อำนวยการสถานศึกษา',
            deptBadgeTone: 'primary',
            imageUrl: isDir
              ? 'https://images.unsplash.com/photo-1643284461591-7fd5fc242ef7?auto=format&fit=crop&w=800&q=80'
              : 'https://images.unsplash.com/photo-1752486268300-1bb7d6d9867d?auto=format&fit=crop&w=800&q=80',
            isDirector: isDir,
            isViceDirector: isVp,
          });
        } else {
          nextTeachers.push({
            id: `db-staff-${raw.id_user}`,
            name: fullName,
            role: roleName,
            dept: 'science',
            deptBadgeText: roleName,
            deptBadgeTone: 'primary',
            imageUrl:
              'https://images.unsplash.com/photo-1580894732230-28cef47eb8d3?auto=format&fit=crop&w=800&q=80',
          });
        }
      }

      setConfig((prev) => ({
        ...prev,
        staff: {
          ...prev.staff,
          totalStaffLabel: `${nextExecs.length + nextTeachers.length} ท่าน`,
          executives:
            nextExecs.length > 0 ? nextExecs : prev.staff.executives,
          teachingStaff:
            nextTeachers.length > 0 ? nextTeachers : prev.staff.teachingStaff,
        },
      }));

      setNotice({
        type: 'ok',
        text: `ดึงรายชื่อบุคลากรจากฐานข้อมูลโรงเรียนจำนวน ${nextExecs.length + nextTeachers.length} ท่านเรียบร้อยแล้ว (อย่าลืมกด "บันทึกการตั้งค่า")`,
      });
    } catch {
      setNotice({
        type: 'error',
        text: 'ไม่สามารถดึงรายชื่อบุคลากรจากฐานข้อมูลได้',
      });
    } finally {
      setImportingStaff(false);
    }
  };

  return (
    <div className="space-y-5">
      {/* ── Header Bar ──────────────────────────────────────────────────── */}
      <div className="card">
        <div className="card-body flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="badge-brand">
                <Globe className="h-3.5 w-3.5" />
                ตั้งค่าเว็บสาธารณะ (Public Web)
              </span>
              <span className="badge-slate">{schoolDisplayName}</span>
            </div>
            <h1 className="mt-1.5 text-lg font-semibold text-ink">
              จัดการข้อมูลหน้าเว็บโรงเรียนสำหรับบุคคลภายนอก
            </h1>
            <p className="text-xs text-slate-500">
              แก้ไขข่าวประชาสัมพันธ์ ทำเนียบบุคลากร สถิตินักเรียน ข้อมูลโรงเรียน
              และช่องทางติดต่อ โดยแสดงผลบนหน้าเว็บสาธารณะทันที
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Link
              to={schoolId ? `/public/${schoolId}` : '/public'}
              target="_blank"
              rel="noreferrer"
              className="btn-secondary"
            >
              <ExternalLink className="h-4 w-4" />
              ดูหน้าเว็บสาธารณะ
            </Link>
            <button
              type="button"
              onClick={handleResetDefault}
              className="btn-secondary text-slate-600"
              title="คืนค่าเริ่มต้นตามต้นฉบับ webschool.html"
            >
              <RotateCcw className="h-4 w-4" />
              คืนค่าเริ่มต้น
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={saving || loading}
              className="btn-primary"
            >
              <Save className="h-4 w-4" />
              {saving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า'}
            </button>
          </div>
        </div>
      </div>

      {notice && (
        <div
          className={
            notice.type === 'ok'
              ? 'alert-ok flex items-center gap-2'
              : notice.type === 'error'
                ? 'alert-error'
                : 'alert-info'
          }
        >
          {notice.type === 'ok' && <Check className="h-4 w-4 shrink-0" />}
          <span>{notice.text}</span>
        </div>
      )}

      {/* ── Section Navigation Tabs ─────────────────────────────────────── */}
      <div className="flex flex-wrap gap-1.5 rounded-2xl border border-slate-200/80 bg-white p-1.5 shadow-card">
        {SECTION_TABS.map((tab) => {
          const Icon = tab.icon;
          const active = section === tab.key;
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => setSection(tab.key)}
              className={`inline-flex items-center gap-2 rounded-xl px-3.5 py-2 text-xs font-medium transition-all ${
                active
                  ? 'bg-brand-600 text-white shadow-sm'
                  : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
              }`}
            >
              <Icon className="h-4 w-4" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* ════════════════════════════════════════════════════════════════════
          SECTION 1: หน้าแรก & สารจากผู้อำนวยการ
         ════════════════════════════════════════════════════════════════════ */}
      {section === 'home' && (
        <div className="space-y-5">
          {/* Hero Banner */}
          <div className="card">
            <div className="card-title">
              <span>แบนเนอร์หลักหน้าแรก (Hero Section)</span>
            </div>
            <div className="card-body grid grid-cols-1 gap-4 sm:grid-cols-2">
              <label className="field">
                <span>ป้ายกำกับด้านบน (Badge)</span>
                <input
                  className="input"
                  value={config.home.heroBadge}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: { ...p.home, heroBadge: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ลิงก์รูปภาพแบนเนอร์หน้าแรก (URL)</span>
                <input
                  className="input"
                  value={config.home.heroImageUrl}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: { ...p.home, heroImageUrl: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field sm:col-span-2">
                <span>หัวข้อพาดหัวหลัก (Hero Title)</span>
                <input
                  className="input"
                  value={config.home.heroTitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: { ...p.home, heroTitle: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field sm:col-span-2">
                <span>คำโปรยใต้หัวข้อหลัก</span>
                <textarea
                  rows={2}
                  className="input"
                  value={config.home.heroSubtitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: { ...p.home, heroSubtitle: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>หัวข้อการ์ดประกาศมุมขวาล่าง</span>
                <input
                  className="input"
                  value={config.home.admissionBannerTitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        admissionBannerTitle: e.target.value,
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>คำอธิบายการ์ดประกาศมุมขวาล่าง</span>
                <input
                  className="input"
                  value={config.home.admissionBannerSubtitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        admissionBannerSubtitle: e.target.value,
                      },
                    }))
                  }
                />
              </label>
            </div>
          </div>

          {/* 4 Quick Stats */}
          <div className="card">
            <div className="card-title">
              <span>ตัวเลขสถิติสำคัญ 4 ช่องบนหน้าแรก</span>
            </div>
            <div className="card-body grid grid-cols-1 gap-4 sm:grid-cols-4">
              <label className="field">
                <span>จำนวนนักเรียนทั้งหมด (คน)</span>
                <input
                  type="number"
                  className="input"
                  value={config.home.stats.studentsCount}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        stats: {
                          ...p.home.stats,
                          studentsCount: Number(e.target.value) || 0,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ข้าราชการครูและบุคลากร (ท่าน)</span>
                <input
                  type="number"
                  className="input"
                  value={config.home.stats.staffCount}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        stats: {
                          ...p.home.stats,
                          staffCount: Number(e.target.value) || 0,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>รางวัลเกียรติยศระดับชาติ</span>
                <input
                  type="number"
                  className="input"
                  value={config.home.stats.awardsCount}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        stats: {
                          ...p.home.stats,
                          awardsCount: Number(e.target.value) || 0,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ปีที่ก่อตั้งโรงเรียน (พ.ศ.)</span>
                <input
                  type="number"
                  className="input"
                  value={config.home.stats.foundedYearBe}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        stats: {
                          ...p.home.stats,
                          foundedYearBe: Number(e.target.value) || 2531,
                        },
                      },
                    }))
                  }
                />
              </label>
            </div>
          </div>

          {/* Calendar Events */}
          <div className="card">
            <div className="card-title">
              <span className="flex items-center gap-2">
                <Calendar className="h-4 w-4 text-brand-600" />
                ปฏิทินการศึกษาและกำหนดการสำคัญ (หน้าแรก)
              </span>
              <button
                type="button"
                onClick={() => {
                  const nextEv: PublicCalendarEventItem = {
                    id: `ev-${Date.now()}`,
                    day: '01',
                    month: 'ก.ค.',
                    title: 'กิจกรรมใหม่ของโรงเรียน',
                    subtitle: 'เวลา 08.30 น. • หอประชุมโรงเรียน',
                    tag: 'กิจกรรม',
                    tone: 'primary',
                  };
                  setConfig((p) => ({
                    ...p,
                    home: {
                      ...p.home,
                      events: [...p.home.events, nextEv],
                    },
                  }));
                }}
                className="btn-secondary btn-sm"
              >
                <Plus className="h-3.5 w-3.5" />
                เพิ่มกำหนดการ
              </button>
            </div>
            <div className="card-body space-y-3">
              {config.home.events.map((ev, idx) => (
                <div
                  key={ev.id}
                  className="subcard grid grid-cols-1 gap-3 sm:grid-cols-12 items-end"
                >
                  <label className="field sm:col-span-1">
                    <span>วันที่</span>
                    <input
                      className="input"
                      value={ev.day}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          home: {
                            ...p.home,
                            events: p.home.events.map((item, i) =>
                              i === idx ? { ...item, day: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>เดือนย่อ</span>
                    <input
                      className="input"
                      value={ev.month}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          home: {
                            ...p.home,
                            events: p.home.events.map((item, i) =>
                              i === idx ? { ...item, month: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-4">
                    <span>ชื่อกิจกรรม</span>
                    <input
                      className="input"
                      value={ev.title}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          home: {
                            ...p.home,
                            events: p.home.events.map((item, i) =>
                              i === idx ? { ...item, title: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-3">
                    <span>เวลาและสถานที่</span>
                    <input
                      className="input"
                      value={ev.subtitle}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          home: {
                            ...p.home,
                            events: p.home.events.map((item, i) =>
                              i === idx ? { ...item, subtitle: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-1">
                    <span>ป้ายหมวด</span>
                    <input
                      className="input"
                      value={ev.tag}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          home: {
                            ...p.home,
                            events: p.home.events.map((item, i) =>
                              i === idx ? { ...item, tag: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <div className="sm:col-span-1 flex justify-end">
                    <button
                      type="button"
                      onClick={() =>
                        setConfig((p) => ({
                          ...p,
                          home: {
                            ...p.home,
                            events: p.home.events.filter((_, i) => i !== idx),
                          },
                        }))
                      }
                      className="btn-danger btn-sm"
                      title="ลบกำหนดการนี้"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Director's Message */}
          <div className="card">
            <div className="card-title">
              <span>สารจากผู้อำนวยการโรงเรียน (หน้าแรก)</span>
            </div>
            <div className="card-body grid grid-cols-1 gap-4 sm:grid-cols-3">
              <label className="field">
                <span>ชื่อ-นามสกุลผู้อำนวยการ</span>
                <input
                  className="input"
                  value={config.home.director.name}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        director: { ...p.home.director, name: e.target.value },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ตำแหน่ง</span>
                <input
                  className="input"
                  value={config.home.director.position}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        director: {
                          ...p.home.director,
                          position: e.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>วิทยฐานะ</span>
                <input
                  className="input"
                  value={config.home.director.standing}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        director: {
                          ...p.home.director,
                          standing: e.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field sm:col-span-3">
                <span>ลิงก์รูปภาพผู้อำนวยการ (URL)</span>
                <input
                  className="input"
                  value={config.home.director.imageUrl}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        director: {
                          ...p.home.director,
                          imageUrl: e.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field sm:col-span-3">
                <span>ข้อความพาดหัวสารจากผู้อำนวยการ</span>
                <input
                  className="input"
                  value={config.home.director.headline}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        director: {
                          ...p.home.director,
                          headline: e.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field sm:col-span-3">
                <span>เนื้อหาสารจากผู้อำนวยการ</span>
                <textarea
                  rows={3}
                  className="input"
                  value={config.home.director.message}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      home: {
                        ...p.home,
                        director: {
                          ...p.home.director,
                          message: e.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          SECTION 2: ข่าวประชาสัมพันธ์และประกาศ
         ════════════════════════════════════════════════════════════════════ */}
      {section === 'news' && (
        <div className="space-y-4">
          <div className="card">
            <div className="card-title">
              <div>
                <span>รายการข่าวประชาสัมพันธ์และประกาศ ({config.news.length} ข่าว)</span>
                <p className="text-xs font-normal text-slate-500 mt-0.5">
                  สามารถเลือกข่าวเด่นประจำสัปดาห์ และเลือกข่าวที่ต้องการให้แสดงบนหน้าแรกได้
                </p>
              </div>
              <button
                type="button"
                onClick={() => {
                  const newItem: PublicNewsItem = {
                    id: `news-${Date.now()}`,
                    cat: 'academic',
                    badgeText: 'ข่าววิชาการ',
                    badgeStyle: 'tertiary',
                    dateLabel: '22 พฤษภาคม 2568',
                    title: 'หัวข้อข่าวประชาสัมพันธ์ใหม่ของโรงเรียน',
                    summary:
                      'สรุปใจความสำคัญของข่าวประชาสัมพันธ์หรือประกาศเพื่อให้ผู้ปกครองและนักเรียนทราบโดยทั่วกัน',
                    imageUrl:
                      'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&w=1080&q=80',
                    imageAlt: 'ภาพประกอบข่าวประชาสัมพันธ์',
                    author: 'งานประชาสัมพันธ์',
                    authorRole: 'ฝ่ายบริหารทั่วไป',
                    isFeatured: false,
                    showOnHome: true,
                    homeOrder: 1,
                    fullParagraphs: [
                      'รายละเอียดเนื้อหาข่าวประชาสัมพันธ์ฉบับเต็ม ย่อหน้าที่ 1 สามารถแก้ไขข้อความนี้ได้ตามต้องการ',
                    ],
                  };
                  setConfig((p) => ({
                    ...p,
                    news: [newItem, ...p.news],
                  }));
                }}
                className="btn-primary btn-sm"
              >
                <Plus className="h-3.5 w-3.5" />
                เพิ่มข่าวประชาสัมพันธ์
              </button>
            </div>

            <div className="card-body space-y-4">
              {config.news.map((item, idx) => (
                <div key={item.id} className="subcard space-y-3">
                  <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-200/80 pb-2.5">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="badge-brand">ข่าวที่ #{idx + 1}</span>
                      {item.isFeatured && (
                        <span className="badge-amber">
                          <Star className="h-3 w-3" />
                          ข่าวเด่นประจำสัปดาห์
                        </span>
                      )}
                      {item.showOnHome && (
                        <span className="badge-green">แสดงบนหน้าแรก</span>
                      )}
                    </div>

                    <div className="flex flex-wrap items-center gap-2">
                      <label className="inline-flex items-center gap-1.5 text-xs font-medium text-slate-700 cursor-pointer">
                        <input
                          type="checkbox"
                          className="checkbox"
                          checked={Boolean(item.isFeatured)}
                          onChange={(e) => {
                            const checked = e.target.checked;
                            setConfig((p) => ({
                              ...p,
                              news: p.news.map((n, i) => ({
                                ...n,
                                isFeatured:
                                  i === idx
                                    ? checked
                                    : checked
                                      ? false
                                      : n.isFeatured,
                              })),
                            }));
                          }}
                        />
                        <span>ตั้งเป็นข่าวเด่นประจำสัปดาห์</span>
                      </label>

                      <label className="inline-flex items-center gap-1.5 text-xs font-medium text-slate-700 cursor-pointer">
                        <input
                          type="checkbox"
                          className="checkbox"
                          checked={Boolean(item.showOnHome)}
                          onChange={(e) => {
                            const checked = e.target.checked;
                            setConfig((p) => ({
                              ...p,
                              news: p.news.map((n, i) =>
                                i === idx ? { ...n, showOnHome: checked } : n,
                              ),
                            }));
                          }}
                        />
                        <span>แสดงบนหน้าแรก</span>
                      </label>

                      <button
                        type="button"
                        onClick={() =>
                          setConfig((p) => ({
                            ...p,
                            news: p.news.filter((_, i) => i !== idx),
                          }))
                        }
                        className="btn-danger btn-sm"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                        ลบข่าว
                      </button>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-3 sm:grid-cols-12">
                    <label className="field sm:col-span-3">
                      <span>หมวดหมู่ข่าว</span>
                      <select
                        className="input"
                        value={item.cat}
                        onChange={(e) => {
                          const catVal = e.target.value as Exclude<
                            NewsFilterCat,
                            'all'
                          >;
                          const found = NEWS_CATEGORY_OPTIONS.find(
                            (o) => o.value === catVal,
                          );
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx
                                ? {
                                    ...n,
                                    cat: catVal,
                                    badgeText: found?.label ?? n.badgeText,
                                    badgeStyle:
                                      found?.badgeStyle ?? n.badgeStyle,
                                  }
                                : n,
                            ),
                          }));
                        }}
                      >
                        {NEWS_CATEGORY_OPTIONS.map((opt) => (
                          <option key={opt.value} value={opt.value}>
                            {opt.label}
                          </option>
                        ))}
                      </select>
                    </label>

                    <label className="field sm:col-span-3">
                      <span>วันที่เผยแพร่</span>
                      <input
                        className="input"
                        value={item.dateLabel}
                        onChange={(e) => {
                          const val = e.target.value;
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx ? { ...n, dateLabel: val } : n,
                            ),
                          }));
                        }}
                      />
                    </label>

                    <label className="field sm:col-span-3">
                      <span>หน่วยงานผู้เผยแพร่</span>
                      <input
                        className="input"
                        value={item.author}
                        onChange={(e) => {
                          const val = e.target.value;
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx ? { ...n, author: val } : n,
                            ),
                          }));
                        }}
                      />
                    </label>

                    <label className="field sm:col-span-3">
                      <span>ฝ่าย/งาน</span>
                      <input
                        className="input"
                        value={item.authorRole}
                        onChange={(e) => {
                          const val = e.target.value;
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx ? { ...n, authorRole: val } : n,
                            ),
                          }));
                        }}
                      />
                    </label>

                    <label className="field sm:col-span-8">
                      <span>หัวข้อข่าว</span>
                      <input
                        className="input"
                        value={item.title}
                        onChange={(e) => {
                          const val = e.target.value;
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx ? { ...n, title: val } : n,
                            ),
                          }));
                        }}
                      />
                    </label>

                    <label className="field sm:col-span-4">
                      <span>ลิงก์รูปภาพประกอบข่าว (URL)</span>
                      <input
                        className="input"
                        value={item.imageUrl}
                        onChange={(e) => {
                          const val = e.target.value;
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx ? { ...n, imageUrl: val } : n,
                            ),
                          }));
                        }}
                      />
                    </label>

                    <label className="field sm:col-span-6">
                      <span>ข้อความสรุปย่อ (แสดงในการ์ดข่าว)</span>
                      <textarea
                        rows={2}
                        className="input"
                        value={item.summary}
                        onChange={(e) => {
                          const val = e.target.value;
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx ? { ...n, summary: val } : n,
                            ),
                          }));
                        }}
                      />
                    </label>

                    <label className="field sm:col-span-6">
                      <span>
                        เนื้อหาข่าวฉบับเต็ม (คั่นแต่ละย่อหน้าด้วยการขึ้นบรรทัดใหม่)
                      </span>
                      <textarea
                        rows={2}
                        className="input"
                        value={item.fullParagraphs.join('\n')}
                        onChange={(e) => {
                          const paras = e.target.value
                            .split('\n')
                            .map((s) => s.trim())
                            .filter(Boolean);
                          setConfig((p) => ({
                            ...p,
                            news: p.news.map((n, i) =>
                              i === idx
                                ? {
                                    ...n,
                                    fullParagraphs:
                                      paras.length > 0 ? paras : [''],
                                  }
                                : n,
                            ),
                          }));
                        }}
                      />
                    </label>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          SECTION 3: ทำเนียบบุคลากร
         ════════════════════════════════════════════════════════════════════ */}
      {section === 'staff' && (
        <div className="space-y-5">
          <div className="card">
            <div className="card-title">
              <div>
                <span>ข้อมูลภาพรวมทำเนียบบุคลากร</span>
                <p className="text-xs font-normal text-slate-500 mt-0.5">
                  จัดการรายชื่อผู้บริหารและคณาจารย์ หรือดึงรายชื่อจากฐานข้อมูลบุคลากรของโรงเรียน
                </p>
              </div>
              <button
                type="button"
                onClick={handleImportStaffFromDb}
                disabled={importingStaff}
                className="btn-secondary btn-sm"
              >
                <RefreshCw
                  className={`h-3.5 w-3.5 ${importingStaff ? 'animate-spin' : ''}`}
                />
                {importingStaff
                  ? 'กำลังดึงรายชื่อ...'
                  : 'ดึงรายชื่อจากฐานข้อมูลโรงเรียน'}
              </button>
            </div>
            <div className="card-body grid grid-cols-1 gap-4 sm:grid-cols-2">
              <label className="field">
                <span>ประจำปีการศึกษา (พ.ศ.)</span>
                <input
                  className="input"
                  value={config.staff.academicYearLabel}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      staff: {
                        ...p.staff,
                        academicYearLabel: e.target.value,
                      },
                    }))
                  }
                />
              </label>
              <label className="field">
                <span>ป้ายแสดงจำนวนบุคลากรทั้งหมด (เช่น 64 ท่าน)</span>
                <input
                  className="input"
                  value={config.staff.totalStaffLabel}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      staff: {
                        ...p.staff,
                        totalStaffLabel: e.target.value,
                      },
                    }))
                  }
                />
              </label>
            </div>
          </div>

          {/* Executives */}
          <div className="card">
            <div className="card-title">
              <span>1. คณะผู้บริหารสถานศึกษา ({config.staff.executives.length} ท่าน)</span>
              <button
                type="button"
                onClick={() => {
                  const nextExec: PublicStaffItem = {
                    id: `exec-${Date.now()}`,
                    name: 'ชื่อ-นามสกุลผู้บริหาร',
                    role: 'รองผู้อำนวยการโรงเรียน',
                    dept: 'executive',
                    deptBadgeText: 'กลุ่มบริหารงานทั่วไป',
                    deptBadgeTone: 'primary',
                    imageUrl:
                      'https://images.unsplash.com/photo-1752486268300-1bb7d6d9867d?auto=format&fit=crop&w=800&q=80',
                    email: 'vp@romburipit.ac.th',
                    isViceDirector: true,
                  };
                  setConfig((p) => ({
                    ...p,
                    staff: {
                      ...p.staff,
                      executives: [...p.staff.executives, nextExec],
                    },
                  }));
                }}
                className="btn-secondary btn-sm"
              >
                <Plus className="h-3.5 w-3.5" />
                เพิ่มผู้บริหาร
              </button>
            </div>
            <div className="card-body space-y-3">
              {config.staff.executives.map((exec, idx) => (
                <div
                  key={exec.id}
                  className="subcard grid grid-cols-1 gap-3 sm:grid-cols-12 items-end"
                >
                  <label className="field sm:col-span-3">
                    <span>ชื่อ-นามสกุล</span>
                    <input
                      className="input"
                      value={exec.name}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            executives: p.staff.executives.map((item, i) =>
                              i === idx ? { ...item, name: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-3">
                    <span>ตำแหน่ง</span>
                    <input
                      className="input"
                      value={exec.role}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            executives: p.staff.executives.map((item, i) =>
                              i === idx ? { ...item, role: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>กลุ่มบริหาร / ป้ายกำกับ</span>
                    <input
                      className="input"
                      value={exec.deptBadgeText}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            executives: p.staff.executives.map((item, i) =>
                              i === idx
                                ? { ...item, deptBadgeText: val }
                                : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>อีเมล</span>
                    <input
                      className="input"
                      value={exec.email ?? ''}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            executives: p.staff.executives.map((item, i) =>
                              i === idx ? { ...item, email: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>ลิงก์รูปภาพ (URL)</span>
                    <input
                      className="input"
                      value={exec.imageUrl}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            executives: p.staff.executives.map((item, i) =>
                              i === idx ? { ...item, imageUrl: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <div className="sm:col-span-12 flex items-center justify-between pt-1">
                    <label className="inline-flex items-center gap-2 text-xs font-medium text-slate-700 cursor-pointer">
                      <input
                        type="checkbox"
                        className="checkbox"
                        checked={Boolean(exec.isDirector)}
                        onChange={(e) => {
                          const checked = e.target.checked;
                          setConfig((p) => ({
                            ...p,
                            staff: {
                              ...p.staff,
                              executives: p.staff.executives.map((item, i) => ({
                                ...item,
                                isDirector:
                                  i === idx
                                    ? checked
                                    : checked
                                      ? false
                                      : item.isDirector,
                              })),
                            },
                          }));
                        }}
                      />
                      <span>แสดงเป็นการ์ดผู้อำนวยการสถานศึกษา (ผู้บริหารสูงสุด)</span>
                    </label>

                    <button
                      type="button"
                      onClick={() =>
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            executives: p.staff.executives.filter(
                              (_, i) => i !== idx,
                            ),
                          },
                        }))
                      }
                      className="btn-danger btn-sm"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                      ลบ
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Teaching & Support Staff */}
          <div className="card">
            <div className="card-title">
              <span>
                2. คณาจารย์และบุคลากรสายสนับสนุน (
                {config.staff.teachingStaff.length} ท่าน)
              </span>
              <button
                type="button"
                onClick={() => {
                  const nextPerson: PublicStaffItem = {
                    id: `staff-${Date.now()}`,
                    name: 'ชื่อ-นามสกุลครู/บุคลากร',
                    role: 'ครูชำนาญการ',
                    dept: 'thai',
                    deptBadgeText: 'กลุ่มสาระฯ ภาษาไทย',
                    deptBadgeTone: 'secondary',
                    imageUrl:
                      'https://images.unsplash.com/photo-1580894732230-28cef47eb8d3?auto=format&fit=crop&w=800&q=80',
                  };
                  setConfig((p) => ({
                    ...p,
                    staff: {
                      ...p.staff,
                      teachingStaff: [nextPerson, ...p.staff.teachingStaff],
                    },
                  }));
                }}
                className="btn-primary btn-sm"
              >
                <Plus className="h-3.5 w-3.5" />
                เพิ่มบุคลากร
              </button>
            </div>
            <div className="card-body space-y-3">
              {config.staff.teachingStaff.map((person, idx) => (
                <div
                  key={person.id}
                  className="subcard grid grid-cols-1 gap-3 sm:grid-cols-12 items-end"
                >
                  <label className="field sm:col-span-3">
                    <span>ชื่อ-นามสกุล</span>
                    <input
                      className="input"
                      value={person.name}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            teachingStaff: p.staff.teachingStaff.map(
                              (item, i) =>
                                i === idx ? { ...item, name: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-3">
                    <span>ตำแหน่ง / วิทยฐานะ</span>
                    <input
                      className="input"
                      value={person.role}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            teachingStaff: p.staff.teachingStaff.map(
                              (item, i) =>
                                i === idx ? { ...item, role: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-3">
                    <span>กลุ่มสาระการเรียนรู้ / ฝ่าย</span>
                    <select
                      className="input"
                      value={person.dept}
                      onChange={(e) => {
                        const deptVal = e.target.value as Exclude<
                          StaffDeptFilter,
                          'all'
                        >;
                        const opt = STAFF_DEPT_OPTIONS.find(
                          (o) => o.value === deptVal,
                        );
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            teachingStaff: p.staff.teachingStaff.map(
                              (item, i) =>
                                i === idx
                                  ? {
                                      ...item,
                                      dept: deptVal,
                                      deptBadgeText:
                                        opt?.badgeText ?? item.deptBadgeText,
                                      deptBadgeTone:
                                        opt?.tone ?? item.deptBadgeTone,
                                    }
                                  : item,
                            ),
                          },
                        }));
                      }}
                    >
                      {STAFF_DEPT_OPTIONS.filter(
                        (o) => o.value !== 'executive',
                      ).map((opt) => (
                        <option key={opt.value} value={opt.value}>
                          {opt.label}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label className="field sm:col-span-2">
                    <span>ลิงก์รูปภาพ (URL)</span>
                    <input
                      className="input"
                      value={person.imageUrl}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            teachingStaff: p.staff.teachingStaff.map(
                              (item, i) =>
                                i === idx ? { ...item, imageUrl: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <div className="sm:col-span-1 flex justify-end">
                    <button
                      type="button"
                      onClick={() =>
                        setConfig((p) => ({
                          ...p,
                          staff: {
                            ...p.staff,
                            teachingStaff: p.staff.teachingStaff.filter(
                              (_, i) => i !== idx,
                            ),
                          },
                        }))
                      }
                      className="btn-danger btn-sm"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          SECTION 4: ข้อมูลนักเรียน & เอกสารดาวน์โหลด
         ════════════════════════════════════════════════════════════════════ */}
      {section === 'students' && (
        <div className="space-y-5">
          <div className="card">
            <div className="card-title">
              <span>ข้อมูลสถิตินักเรียนแยกตามระดับชั้น (ม.1 – ม.6)</span>
            </div>
            <div className="card-body space-y-4">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <label className="field">
                  <span>ข้อความระบุวันที่ข้อมูล (แสดงบนหัวหน้าข้อมูลนักเรียน)</span>
                  <input
                    className="input"
                    value={config.students.updatedDateLabel}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        students: {
                          ...p.students,
                          updatedDateLabel: e.target.value,
                        },
                      }))
                    }
                  />
                </label>
                <label className="field">
                  <span>ลิงก์รูปภาพประกอบหน้าข้อมูลนักเรียน (URL)</span>
                  <input
                    className="input"
                    value={config.students.heroImageUrl}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        students: {
                          ...p.students,
                          heroImageUrl: e.target.value,
                        },
                      }))
                    }
                  />
                </label>
              </div>

              <div className="overflow-x-auto">
                <table className="table">
                  <thead>
                    <tr>
                      <th>ชั้น</th>
                      <th>ชื่อระดับชั้น</th>
                      <th>จำนวนห้องเรียน</th>
                      <th>นักเรียนชาย (คน)</th>
                      <th>นักเรียนหญิง (คน)</th>
                      <th>รวม (คน)</th>
                    </tr>
                  </thead>
                  <tbody>
                    {config.students.grades.map((g, idx) => (
                      <tr key={g.badge}>
                        <td className="font-semibold text-brand-700">
                          {g.badge}
                        </td>
                        <td>
                          <input
                            className="input py-1.5"
                            value={g.title}
                            onChange={(e) => {
                              const val = e.target.value;
                              setConfig((p) => ({
                                ...p,
                                students: {
                                  ...p.students,
                                  grades: p.students.grades.map((item, i) =>
                                    i === idx ? { ...item, title: val } : item,
                                  ),
                                },
                              }));
                            }}
                          />
                        </td>
                        <td>
                          <input
                            type="number"
                            className="input py-1.5 w-24"
                            value={g.roomsCount}
                            onChange={(e) => {
                              const val = Number(e.target.value) || 0;
                              setConfig((p) => ({
                                ...p,
                                students: {
                                  ...p.students,
                                  grades: p.students.grades.map((item, i) =>
                                    i === idx
                                      ? { ...item, roomsCount: val }
                                      : item,
                                  ),
                                },
                              }));
                            }}
                          />
                        </td>
                        <td>
                          <input
                            type="number"
                            className="input py-1.5 w-28"
                            value={g.male}
                            onChange={(e) => {
                              const val = Number(e.target.value) || 0;
                              setConfig((p) => ({
                                ...p,
                                students: {
                                  ...p.students,
                                  grades: p.students.grades.map((item, i) =>
                                    i === idx ? { ...item, male: val } : item,
                                  ),
                                },
                              }));
                            }}
                          />
                        </td>
                        <td>
                          <input
                            type="number"
                            className="input py-1.5 w-28"
                            value={g.female}
                            onChange={(e) => {
                              const val = Number(e.target.value) || 0;
                              setConfig((p) => ({
                                ...p,
                                students: {
                                  ...p.students,
                                  grades: p.students.grades.map((item, i) =>
                                    i === idx ? { ...item, female: val } : item,
                                  ),
                                },
                              }));
                            }}
                          />
                        </td>
                        <td className="font-semibold text-ink tabular-nums">
                          {(Number(g.male) || 0) + (Number(g.female) || 0)} คน
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Study Plans */}
              <div className="pt-2">
                <p className="text-xs font-semibold text-slate-700 mb-2">
                  จำนวนนักเรียนแยกตามแผนการเรียน (ม.ปลาย)
                </p>
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
                  {config.students.studyPlans.map((plan, idx) => (
                    <div key={plan.id} className="subcard space-y-2">
                      <label className="field">
                        <span>ชื่อแผนการเรียน</span>
                        <input
                          className="input"
                          value={plan.label}
                          onChange={(e) => {
                            const val = e.target.value;
                            setConfig((p) => ({
                              ...p,
                              students: {
                                ...p.students,
                                studyPlans: p.students.studyPlans.map(
                                  (item, i) =>
                                    i === idx ? { ...item, label: val } : item,
                                ),
                              },
                            }));
                          }}
                        />
                      </label>
                      <label className="field">
                        <span>จำนวน (เช่น 240 คน)</span>
                        <input
                          className="input"
                          value={plan.countLabel}
                          onChange={(e) => {
                            const val = e.target.value;
                            setConfig((p) => ({
                              ...p,
                              students: {
                                ...p.students,
                                studyPlans: p.students.studyPlans.map(
                                  (item, i) =>
                                    i === idx
                                      ? { ...item, countLabel: val }
                                      : item,
                                ),
                              },
                            }));
                          }}
                        />
                      </label>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Student Downloads */}
          <div className="card">
            <div className="card-title">
              <span className="flex items-center gap-2">
                <FileText className="h-4 w-4 text-brand-600" />
                รายการเอกสารและคู่มือนักเรียนสำหรับดาวน์โหลด
              </span>
              <button
                type="button"
                onClick={() => {
                  const nextDoc: PublicDownloadDocItem = {
                    id: `doc-${Date.now()}`,
                    title: 'เอกสารหรือแบบฟอร์มใหม่สำหรับนักเรียน',
                    fileType: 'PDF',
                    fileSize: '1.0 MB',
                    updatedLabel: 'งานทะเบียนวัดผล',
                    fileUrl: '',
                  };
                  setConfig((p) => ({
                    ...p,
                    students: {
                      ...p.students,
                      downloads: [...p.students.downloads, nextDoc],
                    },
                  }));
                }}
                className="btn-secondary btn-sm"
              >
                <Plus className="h-3.5 w-3.5" />
                เพิ่มเอกสารดาวน์โหลด
              </button>
            </div>
            <div className="card-body space-y-3">
              {config.students.downloads.map((doc, idx) => (
                <div
                  key={doc.id}
                  className="subcard grid grid-cols-1 gap-3 sm:grid-cols-12 items-end"
                >
                  <label className="field sm:col-span-4">
                    <span>ชื่อเอกสาร / แบบฟอร์ม</span>
                    <input
                      className="input"
                      value={doc.title}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          students: {
                            ...p.students,
                            downloads: p.students.downloads.map((item, i) =>
                              i === idx ? { ...item, title: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-2">
                    <span>ชนิดไฟล์</span>
                    <select
                      className="input"
                      value={doc.fileType}
                      onChange={(e) => {
                        const val = e.target.value as 'PDF' | 'DOCX';
                        setConfig((p) => ({
                          ...p,
                          students: {
                            ...p.students,
                            downloads: p.students.downloads.map((item, i) =>
                              i === idx ? { ...item, fileType: val } : item,
                            ),
                          },
                        }));
                      }}
                    >
                      <option value="PDF">PDF</option>
                      <option value="DOCX">DOCX</option>
                    </select>
                  </label>

                  <label className="field sm:col-span-2">
                    <span>ขนาดไฟล์</span>
                    <input
                      className="input"
                      value={doc.fileSize}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          students: {
                            ...p.students,
                            downloads: p.students.downloads.map((item, i) =>
                              i === idx ? { ...item, fileSize: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <label className="field sm:col-span-3">
                    <span>ลิงก์ไฟล์ดาวน์โหลด (URL ถ้ามี)</span>
                    <input
                      className="input"
                      placeholder="https://..."
                      value={doc.fileUrl ?? ''}
                      onChange={(e) => {
                        const val = e.target.value;
                        setConfig((p) => ({
                          ...p,
                          students: {
                            ...p.students,
                            downloads: p.students.downloads.map((item, i) =>
                              i === idx ? { ...item, fileUrl: val } : item,
                            ),
                          },
                        }));
                      }}
                    />
                  </label>

                  <div className="sm:col-span-1 flex justify-end">
                    <button
                      type="button"
                      onClick={() =>
                        setConfig((p) => ({
                          ...p,
                          students: {
                            ...p.students,
                            downloads: p.students.downloads.filter(
                              (_, i) => i !== idx,
                            ),
                          },
                        }))
                      }
                      className="btn-danger btn-sm"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          SECTION 5: ข้อมูลโรงเรียน ประวัติ วิสัยทัศน์ และเอกลักษณ์
         ════════════════════════════════════════════════════════════════════ */}
      {section === 'about' && (
        <div className="space-y-5">
          <div className="card">
            <div className="card-title">
              <span>ข้อมูลพื้นฐานและประวัติความเป็นมาของสถานศึกษา</span>
            </div>
            <div className="card-body grid grid-cols-1 gap-4 sm:grid-cols-3">
              <label className="field sm:col-span-2">
                <span>ชื่อสถานศึกษา (ภาษาอังกฤษ)</span>
                <input
                  className="input"
                  value={config.about.englishName}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, englishName: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>รหัสสถานศึกษา 10 หลัก (SMIS)</span>
                <input
                  className="input"
                  value={config.about.smisCode}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, smisCode: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ขนาดสถานศึกษา</span>
                <input
                  className="input"
                  value={config.about.schoolSizeLabel}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, schoolSizeLabel: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ปีที่ก่อตั้ง (พ.ศ.)</span>
                <input
                  className="input"
                  value={config.about.foundedYearBe}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, foundedYearBe: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>พื้นที่สถานศึกษา (เช่น 45 ไร่)</span>
                <input
                  className="input"
                  value={config.about.areaSizeLabel}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, areaSizeLabel: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ระดับชั้นที่เปิดสอน</span>
                <input
                  className="input"
                  value={config.about.gradeRangeLabel}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, gradeRangeLabel: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>สีประจำโรงเรียน</span>
                <input
                  className="input"
                  value={config.about.schoolColors}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, schoolColors: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ลิงก์ภาพอาคารเรียนหลัก (URL)</span>
                <input
                  className="input"
                  value={config.about.campusHeroImageUrl}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, campusHeroImageUrl: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field sm:col-span-3">
                <span>
                  ประวัติความเป็นมาของโรงเรียน (คั่นแต่ละย่อหน้าด้วยการขึ้นบรรทัดใหม่)
                </span>
                <textarea
                  rows={5}
                  className="input"
                  value={config.about.historyParagraphs.join('\n')}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: {
                        ...p.about,
                        historyParagraphs: e.target.value
                          .split('\n')
                          .map((s) => s.trim())
                          .filter(Boolean),
                      },
                    }))
                  }
                />
              </label>
            </div>
          </div>

          <div className="card">
            <div className="card-title">
              <span>วิสัยทัศน์ พันธกิจ เป้าประสงค์ และอัตลักษณ์</span>
            </div>
            <div className="card-body grid grid-cols-1 gap-4 sm:grid-cols-2">
              <label className="field">
                <span>หัวข้อวิสัยทัศน์ (Vision Title)</span>
                <input
                  className="input"
                  value={config.about.visionTitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, visionTitle: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>คำอธิบายวิสัยทัศน์ (Vision Statement)</span>
                <input
                  className="input"
                  value={config.about.visionText}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, visionText: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>พันธกิจ (Mission — บรรทัดละ 1 ข้อ)</span>
                <textarea
                  rows={4}
                  className="input"
                  value={config.about.missions.join('\n')}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: {
                        ...p.about,
                        missions: e.target.value
                          .split('\n')
                          .map((s) => s.trim())
                          .filter(Boolean),
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>เป้าประสงค์ (Goals — บรรทัดละ 1 ข้อ)</span>
                <textarea
                  rows={4}
                  className="input"
                  value={config.about.goals.join('\n')}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: {
                        ...p.about,
                        goals: e.target.value
                          .split('\n')
                          .map((s) => s.trim())
                          .filter(Boolean),
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>ปรัชญาโรงเรียน (บาลี/หัวข้อ)</span>
                <input
                  className="input"
                  value={config.about.philosophyTitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, philosophyTitle: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>คำแปล/คำอธิบายปรัชญาโรงเรียน</span>
                <input
                  className="input"
                  value={config.about.philosophyDesc}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, philosophyDesc: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>คำขวัญโรงเรียน</span>
                <input
                  className="input"
                  value={config.about.mottoTitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, mottoTitle: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>คำอธิบายคำขวัญโรงเรียน</span>
                <input
                  className="input"
                  value={config.about.mottoDesc}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, mottoDesc: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>เอกลักษณ์สถานศึกษา</span>
                <input
                  className="input"
                  value={config.about.uniquenessTitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, uniquenessTitle: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>คำอธิบายเอกลักษณ์สถานศึกษา</span>
                <input
                  className="input"
                  value={config.about.uniquenessDesc}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, uniquenessDesc: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>อัตลักษณ์ผู้เรียน</span>
                <input
                  className="input"
                  value={config.about.identityTitle}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, identityTitle: e.target.value },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>คำอธิบายอัตลักษณ์ผู้เรียน</span>
                <input
                  className="input"
                  value={config.about.identityDesc}
                  onChange={(e) =>
                    setConfig((p) => ({
                      ...p,
                      about: { ...p.about, identityDesc: e.target.value },
                    }))
                  }
                />
              </label>
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════
          SECTION 6: ข้อมูลติดต่อ แผนที่ และโซเชียลมีเดีย
         ════════════════════════════════════════════════════════════════════ */}
      {section === 'contact' && (
        <div className="card">
          <div className="card-title">
            <span>ข้อมูลติดต่อราชการ โซเชียลมีเดีย และแผนที่ตั้งโรงเรียน</span>
          </div>
          <div className="card-body grid grid-cols-1 gap-4 sm:grid-cols-2">
            <label className="field sm:col-span-2">
              <span>ที่อยู่โรงเรียนฉบับเต็ม</span>
              <input
                className="input"
                value={config.contact.address}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, address: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>ที่ตั้งย่อ (ตำบล / อำเภอ / จังหวัด)</span>
              <input
                className="input"
                value={config.contact.shortLocation}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, shortLocation: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>เบอร์โทรศัพท์ธุรการกลาง / ประชาสัมพันธ์</span>
              <input
                className="input"
                value={config.contact.phoneMain}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, phoneMain: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>เบอร์โทรศัพท์ฝ่ายวิชาการ (ทะเบียน-วัดผล)</span>
              <input
                className="input"
                value={config.contact.phoneAcademic}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, phoneAcademic: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>หมายเลขโทรสาร (Fax)</span>
              <input
                className="input"
                value={config.contact.fax}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, fax: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>อีเมลสารบรรณกลาง</span>
              <input
                className="input"
                value={config.contact.emailMain}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, emailMain: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>อีเมลงานทะเบียนวัดผล</span>
              <input
                className="input"
                value={config.contact.emailAcademic}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, emailAcademic: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>วันและเวลาทำการ</span>
              <input
                className="input"
                value={config.contact.officeHours}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, officeHours: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>หมายเหตุวันหยุดราชการ</span>
              <input
                className="input"
                value={config.contact.officeHoursNote}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, officeHoursNote: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>ชื่อเพจ Facebook โรงเรียน</span>
              <input
                className="input"
                value={config.contact.facebookName}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, facebookName: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>ลิงก์เพจ Facebook (URL)</span>
              <input
                className="input"
                value={config.contact.facebookUrl}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, facebookUrl: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>LINE Official ID</span>
              <input
                className="input"
                value={config.contact.lineOfficialId}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, lineOfficialId: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field">
              <span>ลิงก์ LINE Official (URL)</span>
              <input
                className="input"
                value={config.contact.lineOfficialUrl}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, lineOfficialUrl: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field sm:col-span-2">
              <span>ลิงก์ Google Maps ของโรงเรียน</span>
              <input
                className="input"
                value={config.contact.googleMapsUrl}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: { ...p.contact, googleMapsUrl: e.target.value },
                  }))
                }
              />
            </label>

            <label className="field sm:col-span-2">
              <span>คำอธิบายการเดินทาง / จุดสังเกตที่ตั้งโรงเรียน</span>
              <textarea
                rows={2}
                className="input"
                value={config.contact.mapDirectionsNote}
                onChange={(e) =>
                  setConfig((p) => ({
                    ...p,
                    contact: {
                      ...p.contact,
                      mapDirectionsNote: e.target.value,
                    },
                  }))
                }
              />
            </label>
          </div>

          {/* กล่องข้อความที่ส่งมาจากแบบฟอร์มติดต่อบนหน้าเว็บสาธารณะ */}
          <div className="border-t border-slate-100 px-4 py-4 sm:px-5 space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-semibold text-ink">
                  กล่องข้อความติดต่อจากหน้าเว็บสาธารณะ ({contactMessages.length}{' '}
                  รายการ)
                </h3>
                <p className="text-xs text-slate-500">
                  ข้อความที่ผู้ปกครองหรือบุคคลภายนอกส่งผ่านแบบฟอร์ม &ldquo;ส่งข้อความถึงโรงเรียน&rdquo;
                </p>
              </div>
            </div>

            {contactMessages.length === 0 ? (
              <div className="subcard text-center py-6 text-xs text-slate-500">
                ยังไม่มีข้อความที่ส่งเข้ามาจากหน้าเว็บสาธารณะ
              </div>
            ) : (
              <div className="space-y-2.5">
                {contactMessages.map((msg) => (
                  <div
                    key={msg.id}
                    className="subcard flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between"
                  >
                    <div className="space-y-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="text-xs font-semibold text-ink">
                          {msg.name}
                        </span>
                        <span className="badge-brand">{msg.subject}</span>
                        <span className="text-[11px] text-slate-500">
                          ติดต่อกลับ: {msg.emailOrPhone}
                        </span>
                        <span className="text-[11px] text-slate-400">
                          • {msg.createdAt}
                        </span>
                      </div>
                      <p className="text-xs text-slate-700 whitespace-pre-line">
                        {msg.message}
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={() =>
                        void deletePublicContactSubmission(schoolId, msg.id).then(
                          setContactMessages,
                        )
                      }
                      className="btn-danger btn-sm shrink-0"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                      ลบข้อความ
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
