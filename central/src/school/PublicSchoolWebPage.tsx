import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft,
  Award,
  Bell,
  BookOpen,
  Building2,
  Calendar,
  Check,
  ChevronRight,
  Clock,
  Copy,
  ExternalLink,
  FileText,
  Globe,
  GraduationCap,
  LogIn,
  Mail,
  MapPin,
  Megaphone,
  Phone,
  Pin,
  Search,
  Sparkles,
  Users,
  X,
} from 'lucide-react';
import type { SchoolBasic } from './types';

interface PublicSchoolWebPageProps {
  school?: SchoolBasic | null;
  schools?: SchoolBasic[];
  isLoggedIn?: boolean;
}

type PublicViewTab = 'home' | 'news' | 'staff' | 'about';
type NewsCategory =
  | 'all'
  | 'ข่าวประชาสัมพันธ์'
  | 'ประกาศโรงเรียน'
  | 'กิจกรรมวิชาการ'
  | 'รับสมัคร';

interface MockNewsItem {
  id: number;
  title: string;
  category: Exclude<NewsCategory, 'all'>;
  dateLabel: string;
  division: string;
  isPinned?: boolean;
  summary: string;
  content: string[];
}

interface MockStaffItem {
  id: number;
  fullName: string;
  position: string;
  academicStanding: string;
  department: string;
  roleTag?: string;
  isExecutive?: boolean;
}

const MOCK_NEWS: MockNewsItem[] = [
  {
    id: 1,
    title:
      'ประกาศกำหนดการเปิดภาคเรียนที่ 1 ปีการศึกษา 2569 และแนวปฏิบัติสำหรับนักเรียนและผู้ปกครอง',
    category: 'ประกาศโรงเรียน',
    dateLabel: '15 พฤษภาคม 2569',
    division: 'ฝ่ายวิชาการและกิจการนักเรียน',
    isPinned: true,
    summary:
      'แจ้งกำหนดการรายงานตัว การประชุมผู้ปกครองชั้นเรียน และตารางเปิดภาคเรียนที่ 1 ปีการศึกษา 2569 ของนักเรียนทุกระดับชั้น',
    content: [
      'โรงเรียนขอแจ้งกำหนดการเปิดภาคเรียนที่ 1 ประจำปีการศึกษา 2569 เพื่อให้ผู้ปกครองและนักเรียนเตรียมความพร้อมในการมาเรียนตามวันและเวลาดังนี้:',
      '1. วันประชุมผู้ปกครองและรับมอบตัวนักเรียนใหม่: วันเสาร์ที่ 9 พฤษภาคม 2569 เวลา 08.30 – 12.00 น. ณ หอประชุมอเนกประสงค์ของโรงเรียน',
      '2. วันเปิดภาคเรียนวันแรก (ทุกระดับชั้น): วันจันทร์ที่ 18 พฤษภาคม 2569 โดยขอให้นักเรียนเข้าแถวเคารพธงชาติเวลา 07.50 น.',
      '3. การแต่งกาย: แต่งกายด้วยเครื่องแบบนักเรียนตามระเบียบของทางโรงเรียน สามารถติดต่อรับตารางเรียนและรายชื่อครูที่ปรึกษาได้ทางหน้าเว็บไซต์หรือที่ห้องวิชาการ',
    ],
  },
  {
    id: 2,
    title:
      'ขอแสดงความยินดีกับนักเรียนที่ได้รับรางวัลเหรียญทอง การแข่งขันทักษะวิชาการระดับเขตพื้นที่การศึกษา',
    category: 'กิจกรรมวิชาการ',
    dateLabel: '12 พฤษภาคม 2569',
    division: 'ฝ่ายวิชาการและกิจการนักเรียน',
    isPinned: true,
    summary:
      'ตัวแทนนักเรียนคว้ารางวัลชนะเลิศเหรียญทอง รวม 14 รายการ จากการแข่งขันศิลปหัตถกรรมและทักษะวิชาการระดับเขตพื้นที่การศึกษา',
    content: [
      'โรงเรียนขอแสดงความยินดีกับคณะนักเรียนและครูผู้ฝึกซ้อมทุกกลุ่มสาระการเรียนรู้ ที่ได้เข้าร่วมการแข่งขันทักษะวิชาการระดับเขตพื้นที่การศึกษา ประจำปีการศึกษา 2569',
      'ผลการแข่งขันปรากฏว่า นักเรียนของโรงเรียนได้รับรางวัลชนะเลิศเหรียญทองจำนวน 14 รายการ รางวัลเหรียญเงิน 8 รายการ และรางวัลเหรียญทองแดง 5 รายการ โดยได้เป็นตัวแทนเขตพื้นที่การศึกษาเข้าแข่งขันในระดับภาคต่อไป',
    ],
  },
  {
    id: 3,
    title:
      'ประกาศรับสมัครคัดเลือกบุคคลเพื่อจ้างเป็นลูกจ้างชั่วคราว ตำแหน่งครูอัตราจ้าง วิชาเอกคณิตศาสตร์ และภาษาอังกฤษ',
    category: 'รับสมัคร',
    dateLabel: '10 พฤษภาคม 2569',
    division: 'ฝ่ายบริหารงานบุคคล',
    summary:
      'เปิดรับสมัครครูอัตราจ้าง จำนวน 2 อัตรา ตั้งแต่วันที่ 11 – 20 พฤษภาคม 2569 ในวันและเวลาราชการ ณ ห้องกลุ่มบริหารงานบุคคล',
    content: [
      'ด้วยโรงเรียนมีความประสงค์จะรับสมัครคัดเลือกบุคคลเพื่อจ้างเป็นลูกจ้างชั่วคราว ตำแหน่งครูอัตราจ้าง ปฏิบัติหน้าที่สอนในกลุ่มสาระการเรียนรู้คณิตศาสตร์ (1 อัตรา) และกลุ่มสาระการเรียนรู้ภาษาต่างประเทศ (1 อัตรา)',
      'ผู้สนใจสามารถขอรับและยื่นใบสมัครด้วยตนเองได้ที่ ห้องกลุ่มบริหารงานบุคคล อาคารอำนวยการ ชั้น 1 ตั้งแต่วันที่ 11 – 20 พฤษภาคม 2569 เวลา 08.30 – 16.30 น. (เว้นวันหยุดราชการ) สอบถามรายละเอียดเพิ่มเติมโทร 02-123-4567 ต่อ 102',
    ],
  },
  {
    id: 4,
    title:
      'กิจกรรมพิธีไหว้ครู และพิธีมอบทุนการศึกษาให้แก่นักเรียนเรียนดีแต่ขาดแคลนทุนทรัพย์ ประจำปี 2569',
    category: 'ข่าวประชาสัมพันธ์',
    dateLabel: '8 พฤษภาคม 2569',
    division: 'ฝ่ายบริหารทั่วไป',
    summary:
      'ขอเชิญผู้ปกครองและผู้มีเกียรติร่วมพิธีไหว้ครูและมอบทุนการศึกษาจำนวน 85 ทุน ณ หอประชุมใหญ่ของโรงเรียน',
    content: [
      'โรงเรียนกำหนดจัดกิจกรรมพิธีไหว้ครู ประจำปีการศึกษา 2569 เพื่อให้นักเรียนได้แสดงความกตัญญูกตเวทิตาต่อครูอาจารย์ พร้อมทั้งจัดพิธีมอบทุนการศึกษาให้แก่นักเรียนที่มีผลการเรียนดีและมีความประพฤติเรียบร้อย จำนวน 85 ทุน',
      'ทั้งนี้ ขอขอบคุณคณะกรรมการสถานศึกษาขั้นพื้นฐาน สมาคมผู้ปกครองและครู ตลอดจนผู้มีจิตศรัทธาทุกท่านที่ร่วมสนับสนุนทุนการศึกษาให้แก่นักเรียนของโรงเรียนด้วยดีเสมอมา',
    ],
  },
  {
    id: 5,
    title:
      'ประกาศรายชื่อผู้ชนะการเสนอราคา โครงการปรับปรุงห้องปฏิบัติการคอมพิวเตอร์และระบบเครือข่ายอินเทอร์เน็ตโรงเรียน',
    category: 'ประกาศโรงเรียน',
    dateLabel: '5 พฤษภาคม 2569',
    division: 'ฝ่ายการเงินและพัสดุ',
    summary:
      'ประกาศผลผู้ชนะการจัดซื้อจัดจ้างโครงการยกระดับห้องปฏิบัติการคอมพิวเตอร์เพื่อการเรียนรู้ยุคดิจิทัล ประจำปีงบประมาณ 2569',
    content: [
      'ตามที่โรงเรียนได้ดำเนินการจัดซื้อครุภัณฑ์คอมพิวเตอร์และปรับปรุงระบบเครือข่ายอินเทอร์เน็ตความเร็วสูง เพื่อสนับสนุนการจัดการเรียนการสอนในศตวรรษที่ 21 นั้น',
      'บัดนี้ คณะกรรมการได้พิจารณาคัดเลือกผู้เสนอราคาตามระเบียบกระทรวงการคลังว่าด้วยการจัดซื้อจัดจ้างและการบริหารพัสดุภาครัฐเรียบร้อยแล้ว รายละเอียดตามเอกสารแนบท้ายประกาศ ณ บอร์ดประชาสัมพันธ์ฝ่ายการเงินและพัสดุ',
    ],
  },
  {
    id: 6,
    title:
      'โครงการตรวจสุขภาพประจำปีและการส่งเสริมโภชนาการสำหรับนักเรียนทุกระดับชั้น ร่วมกับโรงพยาบาลส่งเสริมสุขภาพตำบล',
    category: 'ข่าวประชาสัมพันธ์',
    dateLabel: '1 พฤษภาคม 2569',
    division: 'ฝ่ายบริหารทั่วไป',
    summary:
      'บริการตรวจสุขภาพพื้นฐาน ตรวจสุขภาพช่องปาก และประเมินภาวะโภชนาการให้นักเรียนทุกคนโดยไม่เสียค่าใช้จ่าย',
    content: [
      'งานอนามัยโรงเรียน ฝ่ายบริหารทั่วไป ร่วมกับทีมบุคลากรทางการแพทย์ จัดโครงการตรวจสุขภาพนักเรียนประจำปีการศึกษา 2569 เพื่อเฝ้าระวังและดูแลสุขภาพอนามัยของนักเรียนอย่างทั่วถึง',
      'ผู้ปกครองสามารถตรวจสอบผลการตรวจสุขภาพและคำแนะนำจากแพทย์ได้ในสมุดบันทึกสุขภาพประจำตัวนักเรียนหลังเสร็จสิ้นกิจกรรม',
    ],
  },
];

const MOCK_STAFF: MockStaffItem[] = [
  {
    id: 1,
    fullName: 'ดร.เกรียงไกร วิทยาธร',
    position: 'ผู้อำนวยการโรงเรียน',
    academicStanding: 'ผู้อำนวยการเชี่ยวชาญ',
    department: 'คณะผู้บริหาร',
    roleTag: 'ผู้บริหารสูงสุดของสถานศึกษา',
    isExecutive: true,
  },
  {
    id: 2,
    fullName: 'นางสาวกานต์พิชชา รัตนโชติ',
    position: 'รองผู้อำนวยการโรงเรียน',
    academicStanding: 'รองผู้อำนวยการชำนาญการพิเศษ',
    department: 'คณะผู้บริหาร',
    roleTag: 'หัวหน้าฝ่ายวิชาการและกิจการนักเรียน',
    isExecutive: true,
  },
  {
    id: 3,
    fullName: 'นายธนภัทร ศรีสุวรรณ',
    position: 'รองผู้อำนวยการโรงเรียน',
    academicStanding: 'รองผู้อำนวยการชำนาญการพิเศษ',
    department: 'คณะผู้บริหาร',
    roleTag: 'หัวหน้าฝ่ายบริหารงานบุคคล',
    isExecutive: true,
  },
  {
    id: 4,
    fullName: 'นางประภัสสร วงศ์สวัสดิ์',
    position: 'รองผู้อำนวยการโรงเรียน',
    academicStanding: 'รองผู้อำนวยการชำนาญการ',
    department: 'คณะผู้บริหาร',
    roleTag: 'หัวหน้าฝ่ายการเงินและพัสดุ',
    isExecutive: true,
  },
  {
    id: 5,
    fullName: 'นายภูมิพัฒน์ เจริญผล',
    position: 'รองผู้อำนวยการโรงเรียน',
    academicStanding: 'รองผู้อำนวยการชำนาญการ',
    department: 'คณะผู้บริหาร',
    roleTag: 'หัวหน้าฝ่ายบริหารทั่วไป',
    isExecutive: true,
  },
  {
    id: 6,
    fullName: 'นางสาวพิมพ์ชนก วรากุล',
    position: 'ครู',
    academicStanding: 'ครูชำนาญการพิเศษ (คศ.3)',
    department: 'กลุ่มสาระฯ ภาษาไทย',
    roleTag: 'หัวหน้ากลุ่มสาระการเรียนรู้ภาษาไทย',
  },
  {
    id: 7,
    fullName: 'นายณัฐวุฒิ อินทรประเสริฐ',
    position: 'ครู',
    academicStanding: 'ครูชำนาญการพิเศษ (คศ.3)',
    department: 'กลุ่มสาระฯ คณิตศาสตร์',
    roleTag: 'หัวหน้ากลุ่มสาระการเรียนรู้คณิตศาสตร์',
  },
  {
    id: 8,
    fullName: 'นางสาวชลธิชา ทองดี',
    position: 'ครู',
    academicStanding: 'ครูชำนาญการ (คศ.2)',
    department: 'กลุ่มสาระฯ คณิตศาสตร์',
    roleTag: 'ครูผู้สอนคณิตศาสตร์ / ครูที่ปรึกษา',
  },
  {
    id: 9,
    fullName: 'นายกิตติพงศ์ วัฒนากูล',
    position: 'ครู',
    academicStanding: 'ครูชำนาญการพิเศษ (คศ.3)',
    department: 'กลุ่มสาระฯ วิทยาศาสตร์และเทคโนโลยี',
    roleTag: 'หัวหน้ากลุ่มสาระฯ วิทยาศาสตร์และเทคโนโลยี',
  },
  {
    id: 10,
    fullName: 'นางสาวศิริพร เมฆาภิรมย์',
    position: 'ครู',
    academicStanding: 'ครูชำนาญการ (คศ.2)',
    department: 'กลุ่มสาระฯ วิทยาศาสตร์และเทคโนโลยี',
    roleTag: 'ครูผู้สอนคอมพิวเตอร์และเทคโนโลยีดิจิทัล',
  },
  {
    id: 11,
    fullName: 'นายอภิชาติ สุขสวัสดิ์',
    position: 'ครู',
    academicStanding: 'ครูชำนาญการพิเศษ (คศ.3)',
    department: 'กลุ่มสาระฯ สังคมศึกษา ศาสนา และวัฒนธรรม',
    roleTag: 'หัวหน้ากลุ่มสาระฯ สังคมศึกษาฯ',
  },
  {
    id: 12,
    fullName: 'นางสาวอารียา จันทร์เพ็ญ',
    position: 'ครู',
    academicStanding: 'ครูชำนาญการ (คศ.2)',
    department: 'กลุ่มสาระฯ ภาษาต่างประเทศ',
    roleTag: 'หัวหน้ากลุ่มสาระฯ ภาษาต่างประเทศ',
  },
  {
    id: 13,
    fullName: 'นายพงศกร เลิศวิริยะ',
    position: 'ครู',
    academicStanding: 'ครู (คศ.1)',
    department: 'กลุ่มสาระฯ สุขศึกษาและพลศึกษา',
    roleTag: 'ครูผู้สอนสุขศึกษาและพลศึกษา',
  },
  {
    id: 14,
    fullName: 'นางสาวมณีรัตน์ สายชล',
    position: 'เจ้าหน้าที่ธุรการ',
    academicStanding: 'ปฏิบัติงานธุรการและสารบรรณ',
    department: 'ฝ่ายบริหารทั่วไป',
    roleTag: 'งานธุรการและประชาสัมพันธ์โรงเรียน',
  },
];

const NEWS_CATEGORIES: { key: NewsCategory; label: string }[] = [
  { key: 'all', label: 'ทั้งหมด' },
  { key: 'ประกาศโรงเรียน', label: 'ประกาศโรงเรียน' },
  { key: 'ข่าวประชาสัมพันธ์', label: 'ข่าวประชาสัมพันธ์' },
  { key: 'กิจกรรมวิชาการ', label: 'กิจกรรมวิชาการ' },
  { key: 'รับสมัคร', label: 'รับสมัครงาน / นักเรียน' },
];

function getInitials(name: string): string {
  const cleaned = name
    .replace(/^(ดร\.|นาย|นางสาว|นาง|ว่าที่ ร\.ต\.|ผอ\.)\s*/g, '')
    .trim();
  return cleaned.slice(0, 2) || 'รร';
}

export default function PublicSchoolWebPage({
  school = null,
  schools = [],
  isLoggedIn = false,
}: PublicSchoolWebPageProps) {
  const { schoolId: paramSchoolId } = useParams<{ schoolId?: string }>();
  const navigate = useNavigate();

  const [activeTab, setActiveTab] = useState<PublicViewTab>('home');
  const [newsCategory, setNewsCategory] = useState<NewsCategory>('all');
  const [selectedNews, setSelectedNews] = useState<MockNewsItem | null>(null);
  const [staffDeptFilter, setStaffDeptFilter] = useState<string>('all');
  const [staffSearch, setStaffSearch] = useState('');
  const [copiedLink, setCopiedLink] = useState(false);

  const matchedSchool = useMemo(() => {
    if (paramSchoolId) {
      const idNum = Number(paramSchoolId);
      const found = schools.find((s) => s.id_school === idNum);
      if (found) return found;
    }
    return school ?? schools[0] ?? null;
  }, [paramSchoolId, school, schools]);

  const displaySchoolName =
    matchedSchool?.fullName || 'โรงเรียนสาธิตพิทยาคม (ตัวอย่างหน้าเว็บสาธารณะ)';
  const displayAffiliation =
    matchedSchool?.affiliation ||
    'สำนักงานเขตพื้นที่การศึกษามัธยมศึกษา · กระทรวงศึกษาธิการ';

  const filteredNews = useMemo(() => {
    if (newsCategory === 'all') return MOCK_NEWS;
    return MOCK_NEWS.filter((n) => n.category === newsCategory);
  }, [newsCategory]);

  const departmentList = useMemo(() => {
    const set = new Set<string>();
    for (const s of MOCK_STAFF) set.add(s.department);
    return ['all', ...set];
  }, []);

  const filteredStaff = useMemo(() => {
    const q = staffSearch.trim().toLowerCase();
    return MOCK_STAFF.filter((s) => {
      if (staffDeptFilter !== 'all' && s.department !== staffDeptFilter) {
        return false;
      }
      if (!q) return true;
      return (
        s.fullName.toLowerCase().includes(q) ||
        s.position.toLowerCase().includes(q) ||
        s.department.toLowerCase().includes(q) ||
        (s.roleTag?.toLowerCase().includes(q) ?? false)
      );
    });
  }, [staffDeptFilter, staffSearch]);

  const executives = useMemo(
    () => MOCK_STAFF.filter((s) => s.isExecutive),
    [],
  );

  function handleCopyPublicUrl() {
    const url = `${window.location.origin}${window.location.pathname}#/public${
      matchedSchool?.id_school ? `/${matchedSchool.id_school}` : ''
    }`;
    navigator.clipboard?.writeText(url).then(() => {
      setCopiedLink(true);
      setTimeout(() => setCopiedLink(false), 2500);
    });
  }

  return (
    <div className="min-h-screen bg-canvas text-ink">
      {/* ─── แถบแจ้งสถานะตัวอย่างหน้าเว็บสำหรับคนนอกดู ─────────────────────── */}
      <div className="border-b border-brand-700 bg-brand-700 px-4 py-2 text-xs text-white">
        <div className="mx-auto flex max-w-[1280px] flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Globe className="h-3.5 w-3.5 shrink-0 text-brand-200" />
            <span>
              <strong>หน้าเว็บโรงเรียนสำหรับคนนอกดู (Public Web)</strong> —
              ผู้ปกครอง นักเรียน และบุคคลทั่วไปเปิดดูได้โดยไม่ต้องล็อกอิน
            </span>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {schools.length > 1 && (
              <select
                value={matchedSchool?.id_school ?? ''}
                onChange={(e) => navigate(`/public/${e.target.value}`)}
                aria-label="สลับดูโรงเรียนอื่น"
                className="rounded-md border border-white/30 bg-brand-600 px-2 py-0.5 text-xs text-white outline-none"
              >
                {schools.map((s) => (
                  <option key={s.id_school} value={s.id_school}>
                    {s.fullName || `โรงเรียน #${s.id_school}`}
                  </option>
                ))}
              </select>
            )}

            <button
              type="button"
              onClick={handleCopyPublicUrl}
              className="inline-flex items-center gap-1 rounded-md bg-white/15 px-2.5 py-1 text-[11px] font-medium text-white transition-colors hover:bg-white/25"
            >
              {copiedLink ? (
                <>
                  <Check className="h-3 w-3" />
                  <span>คัดลอกลิงก์แล้ว</span>
                </>
              ) : (
                <>
                  <Copy className="h-3 w-3" />
                  <span>คัดลอกลิงก์หน้าเว็บ</span>
                </>
              )}
            </button>

            {isLoggedIn ? (
              <Link
                to="/"
                className="inline-flex items-center gap-1 rounded-md bg-white px-2.5 py-1 text-[11px] font-semibold text-brand-700 shadow-sm hover:bg-brand-50"
              >
                <ArrowLeft className="h-3 w-3" />
                <span>กลับระบบงานบุคลากร</span>
              </Link>
            ) : (
              <Link
                to="/"
                className="inline-flex items-center gap-1 rounded-md bg-white px-2.5 py-1 text-[11px] font-semibold text-brand-700 shadow-sm hover:bg-brand-50"
              >
                <LogIn className="h-3 w-3" />
                <span>เข้าสู่ระบบบุคลากร</span>
              </Link>
            )}
          </div>
        </div>
      </div>

      {/* ─── ส่วนหัวเว็บไซต์โรงเรียน (Navbar) ───────────────────────────────── */}
      <header className="sticky top-0 z-20 border-b border-line bg-white/95 backdrop-blur">
        <div className="mx-auto flex max-w-[1280px] flex-col gap-3 px-4 py-3.5 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-600 text-white shadow-sm">
              <GraduationCap className="h-6 w-6" strokeWidth={1.75} />
            </div>
            <div className="min-w-0">
              <h1 className="truncate text-base font-bold tracking-tight text-ink sm:text-lg">
                {displaySchoolName}
              </h1>
              <p className="truncate text-xs text-slate-500">
                {displayAffiliation}
              </p>
            </div>
          </div>

          <nav className="flex flex-wrap items-center gap-1.5">
            {(
              [
                { id: 'home', label: 'หน้าแรกโรงเรียน' },
                { id: 'news', label: 'ข่าวประชาสัมพันธ์' },
                { id: 'staff', label: 'ทำเนียบบุคลากร' },
                { id: 'about', label: 'ข้อมูลโรงเรียน & ติดต่อเรา' },
              ] as { id: PublicViewTab; label: string }[]
            ).map((item) => {
              const active = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setActiveTab(item.id)}
                  className={`rounded-xl px-3.5 py-2 text-xs font-semibold transition-colors ${
                    active
                      ? 'bg-brand-600 text-white shadow-sm'
                      : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
                  }`}
                >
                  {item.label}
                </button>
              );
            })}
          </nav>
        </div>
      </header>

      {/* ─── แบนเนอร์ต้อนรับ (Hero Section) ────────────────────────────────── */}
      {activeTab === 'home' && (
        <section className="border-b border-line bg-gradient-to-br from-brand-50/80 via-white to-sky-50/60">
          <div className="mx-auto max-w-[1280px] px-4 py-8 sm:px-6 sm:py-12">
            <div className="grid gap-8 lg:grid-cols-12 lg:items-center">
              <div className="space-y-4 lg:col-span-7">
                <div className="inline-flex items-center gap-1.5 rounded-full bg-brand-100/80 px-3 py-1 text-xs font-semibold text-brand-700">
                  <Sparkles className="h-3.5 w-3.5" />
                  <span>ยินดีต้อนรับสู่เว็บไซต์ประชาสัมพันธ์สถานศึกษา</span>
                </div>

                <h2 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
                  {displaySchoolName}
                </h2>

                <p className="text-sm font-medium text-brand-700">
                  คำขวัญ: &ldquo;เรียนดี มีวินัย ใฝ่คุณธรรม นำเทคโนโลยี
                  สู่วิถีพลเมืองคุณภาพ&rdquo;
                </p>

                <p className="text-sm leading-relaxed text-slate-600">
                  มุ่งมั่นพัฒนาผู้เรียนให้มีความเป็นเลิศทางวิชาการ
                  ควบคู่คุณธรรมจริยธรรม ทักษะการคิดวิเคราะห์ และเทคโนโลยีสมัยใหม่
                  ภายใต้สภาพแวดล้อมที่อบอุ่น ปลอดภัย และร่วมมือกับชุมชนอย่างยั่งยืน
                </p>

                <div className="flex flex-wrap items-center gap-2.5 pt-2">
                  <button
                    type="button"
                    onClick={() => setActiveTab('news')}
                    className="btn-primary"
                  >
                    <Megaphone className="h-4 w-4" strokeWidth={1.75} />
                    <span>ดูประกาศและข่าวสารทั้งหมด</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveTab('staff')}
                    className="btn-secondary"
                  >
                    <Users className="h-4 w-4" strokeWidth={1.75} />
                    <span>ทำเนียบผู้บริหารและครู</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveTab('about')}
                    className="btn-secondary"
                  >
                    <Phone className="h-4 w-4" strokeWidth={1.75} />
                    <span>ติดต่อโรงเรียน</span>
                  </button>
                </div>
              </div>

              {/* การ์ดตัวเลขสถิติภาพรวมโรงเรียน */}
              <div className="grid grid-cols-2 gap-3.5 lg:col-span-5">
                <div className="surface-card p-4">
                  <div className="flex items-center gap-2 text-brand-600">
                    <Users className="h-4 w-4" />
                    <span className="text-xs font-semibold">ครูและบุคลากร</span>
                  </div>
                  <p className="mt-2 text-2xl font-bold tabular-nums text-ink">
                    68 <span className="text-xs font-normal text-slate-500">คน</span>
                  </p>
                  <p className="mt-0.5 text-[11px] text-slate-500">
                    ผู้บริหาร 5 · ครูผู้สอน 58 · สนับสนุน 5
                  </p>
                </div>

                <div className="surface-card p-4">
                  <div className="flex items-center gap-2 text-emerald-600">
                    <GraduationCap className="h-4 w-4" />
                    <span className="text-xs font-semibold">นักเรียนทั้งหมด</span>
                  </div>
                  <p className="mt-2 text-2xl font-bold tabular-nums text-ink">
                    1,240{' '}
                    <span className="text-xs font-normal text-slate-500">คน</span>
                  </p>
                  <p className="mt-0.5 text-[11px] text-slate-500">
                    มัธยมศึกษาปีที่ 1 – 6 (36 ห้องเรียน)
                  </p>
                </div>

                <div className="surface-card p-4">
                  <div className="flex items-center gap-2 text-amber-600">
                    <BookOpen className="h-4 w-4" />
                    <span className="text-xs font-semibold">กลุ่มสาระการเรียนรู้</span>
                  </div>
                  <p className="mt-2 text-2xl font-bold tabular-nums text-ink">
                    8{' '}
                    <span className="text-xs font-normal text-slate-500">
                      กลุ่มสาระ
                    </span>
                  </p>
                  <p className="mt-0.5 text-[11px] text-slate-500">
                    หลักสูตรแกนกลางและห้องเรียนพิเศษ
                  </p>
                </div>

                <div className="surface-card p-4">
                  <div className="flex items-center gap-2 text-sky-600">
                    <Calendar className="h-4 w-4" />
                    <span className="text-xs font-semibold">ปีการศึกษาปัจจุบัน</span>
                  </div>
                  <p className="mt-2 text-2xl font-bold tabular-nums text-ink">
                    1/2569
                  </p>
                  <p className="mt-0.5 text-[11px] text-slate-500">
                    เปิดทำการ จันทร์ – ศุกร์ 07.30 – 16.30 น.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>
      )}

      {/* ─── พื้นที่เนื้อหาหลัก ────────────────────────────────────────────── */}
      <main className="mx-auto max-w-[1280px] space-y-10 px-4 py-8 sm:px-6">
        {/* ==================== 1. ข่าวประชาสัมพันธ์และประกาศ ==================== */}
        {(activeTab === 'home' || activeTab === 'news') && (
          <section className="space-y-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <div className="flex items-center gap-2 text-brand-600">
                  <Bell className="h-4 w-4" strokeWidth={2} />
                  <span className="text-xs font-semibold uppercase tracking-wider">
                    ข่าวสารและประกาศล่าสุด
                  </span>
                </div>
                <h2 className="mt-1 text-xl font-bold tracking-tight text-ink">
                  ข่าวประชาสัมพันธ์และประกาศโรงเรียน
                </h2>
                <p className="mt-0.5 text-xs text-slate-500">
                  ติดตามประกาศสำคัญ กิจกรรมของนักเรียน และข่าวสารจากทางโรงเรียน
                </p>
              </div>

              {/* ตัวกรองหมวดข่าว */}
              <div className="flex flex-wrap gap-1.5">
                {NEWS_CATEGORIES.map((cat) => {
                  const active = newsCategory === cat.key;
                  return (
                    <button
                      key={cat.key}
                      type="button"
                      onClick={() => setNewsCategory(cat.key)}
                      className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors ${
                        active
                          ? 'border-brand-600 bg-brand-600 text-white'
                          : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                      }`}
                    >
                      {cat.label}
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {filteredNews.map((news) => (
                <article
                  key={news.id}
                  onClick={() => setSelectedNews(news)}
                  className="surface-card group flex cursor-pointer flex-col justify-between p-5 transition-all hover:border-brand-300 hover:shadow-md"
                >
                  <div className="space-y-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span
                        className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${
                          news.category === 'ประกาศโรงเรียน'
                            ? 'bg-brand-50 text-brand-700 ring-1 ring-inset ring-brand-200'
                            : news.category === 'กิจกรรมวิชาการ'
                              ? 'bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-200'
                              : news.category === 'รับสมัคร'
                                ? 'bg-amber-50 text-amber-800 ring-1 ring-inset ring-amber-200'
                                : 'bg-sky-50 text-sky-700 ring-1 ring-inset ring-sky-200'
                        }`}
                      >
                        {news.category}
                      </span>

                      {news.isPinned && (
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-amber-700">
                          <Pin className="h-3 w-3" />
                          <span>ปักหมุด</span>
                        </span>
                      )}
                    </div>

                    <h3 className="text-sm font-semibold leading-snug text-ink group-hover:text-brand-700">
                      {news.title}
                    </h3>

                    <p className="line-clamp-3 text-xs leading-relaxed text-slate-600">
                      {news.summary}
                    </p>
                  </div>

                  <div className="mt-4 flex items-center justify-between border-t border-line/70 pt-3 text-[11px] text-slate-500">
                    <span className="inline-flex items-center gap-1">
                      <Calendar className="h-3 w-3 text-slate-400" />
                      <span>{news.dateLabel}</span>
                    </span>
                    <span className="inline-flex items-center gap-0.5 font-semibold text-brand-600 group-hover:translate-x-0.5 transition-transform">
                      <span>อ่านรายละเอียด</span>
                      <ChevronRight className="h-3.5 w-3.5" />
                    </span>
                  </div>
                </article>
              ))}
            </div>
          </section>
        )}

        {/* ==================== 2. ทำเนียบผู้บริหารและบุคลากร ==================== */}
        {(activeTab === 'home' || activeTab === 'staff') && (
          <section className="space-y-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <div className="flex items-center gap-2 text-brand-600">
                  <Users className="h-4 w-4" strokeWidth={2} />
                  <span className="text-xs font-semibold uppercase tracking-wider">
                    โครงสร้างผู้บริหารและคณาจารย์
                  </span>
                </div>
                <h2 className="mt-1 text-xl font-bold tracking-tight text-ink">
                  ทำเนียบผู้บริหารและบุคลากรโรงเรียน
                </h2>
                <p className="mt-0.5 text-xs text-slate-500">
                  รายชื่อคณะผู้บริหาร หัวหน้ากลุ่มสาระการเรียนรู้ และบุคลากรประจำโรงเรียน
                </p>
              </div>

              {activeTab === 'home' && (
                <button
                  type="button"
                  onClick={() => setActiveTab('staff')}
                  className="btn-secondary btn-sm self-start sm:self-auto"
                >
                  <span>ดูทำเนียบบุคลากรทั้งหมด ({MOCK_STAFF.length} คน)</span>
                  <ChevronRight className="h-3.5 w-3.5" />
                </button>
              )}
            </div>

            {/* แผงคณะผู้บริหารโรงเรียน */}
            <div className="surface-card p-6">
              <h3 className="mb-4 text-sm font-semibold text-ink">
                คณะผู้บริหารสถานศึกษา ({executives.length} ท่าน)
              </h3>

              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
                {executives.map((exec, idx) => (
                  <div
                    key={exec.id}
                    className={`flex flex-col items-center rounded-xl border p-4 text-center ${
                      idx === 0
                        ? 'border-brand-300 bg-brand-50/50 sm:col-span-2 lg:col-span-1'
                        : 'border-line bg-canvas/50'
                    }`}
                  >
                    <div
                      className={`flex h-14 w-14 items-center justify-center rounded-full text-base font-bold ${
                        idx === 0
                          ? 'bg-brand-600 text-white shadow-sm'
                          : 'bg-white text-brand-700 ring-1 ring-brand-200'
                      }`}
                    >
                      {getInitials(exec.fullName)}
                    </div>
                    <p className="mt-3 text-sm font-semibold text-ink">
                      {exec.fullName}
                    </p>
                    <p className="mt-0.5 text-xs font-medium text-brand-700">
                      {exec.position}
                    </p>
                    <p className="mt-1 text-[11px] text-slate-500">
                      {exec.roleTag}
                    </p>
                    <span className="mt-2 rounded-full bg-white px-2.5 py-0.5 text-[10px] font-medium text-slate-600 ring-1 ring-line">
                      {exec.academicStanding}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* ตาราง/การ์ดค้นหาครูและบุคลากรแยกตามกลุ่มสาระ */}
            <div className="surface-card p-6 space-y-5">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-ink">
                    รายชื่อครูและบุคลากรแยกตามกลุ่มสาระการเรียนรู้ / ฝ่ายงาน
                  </h3>
                  <p className="text-xs text-slate-500">
                    ค้นหาจากชื่อ-นามสกุล ตำแหน่ง หรือเลือกดูตามกลุ่มสาระการเรียนรู้
                  </p>
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <div className="relative min-w-[210px]">
                    <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400" />
                    <input
                      type="text"
                      value={staffSearch}
                      onChange={(e) => setStaffSearch(e.target.value)}
                      placeholder="ค้นหาชื่อครู หรือกลุ่มสาระ..."
                      className="input py-1.5 pl-8 text-xs"
                    />
                  </div>

                  <select
                    value={staffDeptFilter}
                    onChange={(e) => setStaffDeptFilter(e.target.value)}
                    aria-label="เลือกกลุ่มสาระการเรียนรู้"
                    className="input w-auto py-1.5 text-xs"
                  >
                    {departmentList.map((dept) => (
                      <option key={dept} value={dept}>
                        {dept === 'all' ? 'ทุกกลุ่มสาระ / ทุกฝ่าย' : dept}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid gap-3.5 sm:grid-cols-2 lg:grid-cols-3">
                {filteredStaff.map((person) => (
                  <div
                    key={person.id}
                    className="flex items-start gap-3.5 rounded-xl border border-line bg-white p-4 transition-colors hover:border-brand-200"
                  >
                    <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-xs font-bold text-brand-700 ring-1 ring-inset ring-brand-200">
                      {getInitials(person.fullName)}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-semibold text-ink">
                        {person.fullName}
                      </p>
                      <p className="text-xs font-medium text-brand-700">
                        {person.position} · {person.academicStanding}
                      </p>
                      <p className="mt-1 truncate text-[11px] text-slate-500">
                        {person.roleTag || person.department}
                      </p>
                      <span className="mt-1.5 inline-block rounded-md bg-slate-100 px-2 py-0.5 text-[10px] font-medium text-slate-600">
                        {person.department}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </section>
        )}

        {/* ==================== 3. ข้อมูลโรงเรียน & ติดต่อเรา ==================== */}
        {(activeTab === 'home' || activeTab === 'about') && (
          <section className="grid gap-6 lg:grid-cols-12">
            {/* ซ้าย 7 คอลัมน์: วิสัยทัศน์ ปรัชญา พันธกิจ */}
            <div className="surface-card p-6 space-y-5 lg:col-span-7">
              <div className="flex items-center gap-2 text-brand-600">
                <Award className="h-4 w-4" strokeWidth={2} />
                <h2 className="text-base font-bold text-ink">
                  ข้อมูลพื้นฐาน วิสัยทัศน์ และเอกลักษณ์ของโรงเรียน
                </h2>
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                <div className="rounded-xl border border-line bg-canvas/60 p-4">
                  <p className="text-xs font-semibold text-brand-700">
                    ปรัชญาของโรงเรียน
                  </p>
                  <p className="mt-1 text-sm font-medium text-ink">
                    &ldquo;นตฺถิ ปญฺญา สมา อาภา — แสงสว่างเสมอด้วยปัญญาไม่มี&rdquo;
                  </p>
                </div>

                <div className="rounded-xl border border-line bg-canvas/60 p-4">
                  <p className="text-xs font-semibold text-brand-700">
                    คำขวัญของโรงเรียน
                  </p>
                  <p className="mt-1 text-sm font-medium text-ink">
                    &ldquo;เรียนดี มีวินัย ใฝ่คุณธรรม นำเทคโนโลยี&rdquo;
                  </p>
                </div>

                <div className="rounded-xl border border-line bg-canvas/60 p-4 sm:col-span-2">
                  <p className="text-xs font-semibold text-brand-700">
                    วิสัยทัศน์ (Vision)
                  </p>
                  <p className="mt-1 text-xs leading-relaxed text-slate-600">
                    ภายในปี พ.ศ. 2572 {displaySchoolName} เป็นสถานศึกษาชั้นนำในการพัฒนาผู้เรียนสู่มาตรฐานสากล
                    มีทักษะทางวิชาการและเทคโนโลยีดิจิทัล ยึดมั่นในคุณธรรมจริยธรรม
                    และน้อมนำหลักปรัชญาของเศรษฐกิจพอเพียงสู่การปฏิบัติจริง
                  </p>
                </div>

                <div className="rounded-xl border border-line bg-canvas/60 p-4">
                  <p className="text-xs font-semibold text-brand-700">
                    อัตลักษณ์ผู้เรียน
                  </p>
                  <p className="mt-1 text-xs text-slate-600">
                    &ldquo;ไหว้สวย ยิ้มใส ใฝ่เรียนรู้ คู่จิตอาสา&rdquo;
                  </p>
                </div>

                <div className="rounded-xl border border-line bg-canvas/60 p-4">
                  <p className="text-xs font-semibold text-brand-700">
                    เอกลักษณ์สถานศึกษา
                  </p>
                  <p className="mt-1 text-xs text-slate-600">
                    &ldquo;โรงเรียนปลอดขยะ บรรยากาศร่มรื่น ทันสมัยด้วยสื่อดิจิทัล&rdquo;
                  </p>
                </div>
              </div>
            </div>

            {/* ขวา 5 คอลัมน์: ช่องทางติดต่อโรงเรียน */}
            <div className="surface-card p-6 space-y-5 lg:col-span-5">
              <div className="flex items-center gap-2 text-brand-600">
                <Building2 className="h-4 w-4" strokeWidth={2} />
                <h2 className="text-base font-bold text-ink">
                  สถานที่ตั้งและช่องทางติดต่อโรงเรียน
                </h2>
              </div>

              <div className="space-y-3.5 text-xs text-slate-600">
                <div className="flex items-start gap-3">
                  <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-brand-600" />
                  <div>
                    <p className="font-semibold text-ink">ที่อยู่สถานศึกษา</p>
                    <p className="mt-0.5 leading-relaxed">
                      เลขที่ 199 ถนนศึกษาเจริญ ตำบลในเมือง อำเภอเมือง
                      รหัสไปรษณีย์ 10200
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Phone className="mt-0.5 h-4 w-4 shrink-0 text-brand-600" />
                  <div>
                    <p className="font-semibold text-ink">เบอร์โทรศัพท์ติดต่อ</p>
                    <p className="mt-0.5">
                      ห้องธุรการกลาง: 02-123-4567 · ห้องวิชาการ: 02-123-4568
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Mail className="mt-0.5 h-4 w-4 shrink-0 text-brand-600" />
                  <div>
                    <p className="font-semibold text-ink">อีเมลสารบรรณโรงเรียน</p>
                    <p className="mt-0.5">contact@school-academic.ac.th</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Clock className="mt-0.5 h-4 w-4 shrink-0 text-brand-600" />
                  <div>
                    <p className="font-semibold text-ink">วันและเวลาทำการ</p>
                    <p className="mt-0.5">
                      วันจันทร์ – วันศุกร์ เวลา 07.30 – 16.30 น. (เว้นวันหยุดราชการ)
                    </p>
                  </div>
                </div>
              </div>

              <div className="border-t border-line pt-4">
                <p className="mb-2.5 text-xs font-semibold text-ink">
                  ลิงก์บริการสำหรับผู้ปกครองและบุคลากร
                </p>
                <div className="flex flex-wrap gap-2">
                  <Link to="/" className="btn-primary btn-sm">
                    <LogIn className="h-3.5 w-3.5" />
                    <span>เข้าสู่ระบบงานบุคลากร</span>
                  </Link>
                  <a
                    href="https://www.moe.go.th"
                    target="_blank"
                    rel="noreferrer"
                    className="btn-secondary btn-sm"
                  >
                    <span>เว็บไซต์กระทรวงศึกษาธิการ</span>
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              </div>
            </div>
          </section>
        )}
      </main>

      {/* ─── หน้าต่างอ่านรายละเอียดข่าวประชาสัมพันธ์ (Modal) ───────────────── */}
      {selectedNews && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4"
          onClick={() => setSelectedNews(null)}
        >
          <div
            className="max-h-[85vh] w-full max-w-2xl overflow-y-auto rounded-2xl border border-line bg-white p-6 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start justify-between gap-3 border-b border-line pb-4">
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  <span className="rounded-full bg-brand-50 px-2.5 py-0.5 text-xs font-semibold text-brand-700">
                    {selectedNews.category}
                  </span>
                  <span className="text-xs text-slate-500">
                    {selectedNews.dateLabel} · {selectedNews.division}
                  </span>
                </div>
                <h3 className="mt-2 text-lg font-bold leading-snug text-ink">
                  {selectedNews.title}
                </h3>
              </div>

              <button
                type="button"
                onClick={() => setSelectedNews(null)}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-ink"
                aria-label="ปิดหน้าต่างข่าว"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="mt-4 space-y-3 text-sm leading-relaxed text-slate-700">
              {selectedNews.content.map((para, idx) => (
                <p key={idx}>{para}</p>
              ))}
            </div>

            <div className="mt-6 flex items-center justify-between border-t border-line pt-4">
              <span className="inline-flex items-center gap-1.5 text-xs text-slate-500">
                <FileText className="h-3.5 w-3.5 text-brand-600" />
                <span>เผยแพร่โดย: {selectedNews.division}</span>
              </span>
              <button
                type="button"
                onClick={() => setSelectedNews(null)}
                className="btn-primary btn-sm"
              >
                ปิดหน้าต่าง
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ─── ส่วนท้ายเว็บไซต์ (Footer) ──────────────────────────────────────── */}
      <footer className="mt-12 border-t border-line bg-white py-6">
        <div className="mx-auto flex max-w-[1280px] flex-col items-center justify-between gap-3 px-4 text-xs text-slate-500 sm:flex-row sm:px-6">
          <p>
            © {new Date().getFullYear() + 543} {displaySchoolName} ·
            เว็บไซต์ประชาสัมพันธ์สำหรับบุคคลภายนอก
          </p>
          <div className="flex items-center gap-4">
            <button
              type="button"
              onClick={() => setActiveTab('home')}
              className="hover:text-ink"
            >
              หน้าแรก
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('news')}
              className="hover:text-ink"
            >
              ข่าวประชาสัมพันธ์
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('staff')}
              className="hover:text-ink"
            >
              ทำเนียบบุคลากร
            </button>
            <Link to="/" className="font-semibold text-brand-600 hover:underline">
              สำหรับบุคลากร
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
