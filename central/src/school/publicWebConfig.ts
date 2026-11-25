import { supabase } from '../supabase';
import {
  DEFAULT_PUBLIC_ADMISSION_CONFIG,
  mergePublicAdmissionConfig,
  type PublicAdmissionConfig,
} from './publicWebAdmissions';

export type NewsFilterCat =
  | 'all'
  | 'academic'
  | 'activity'
  | 'admission'
  | 'procurement';

export type StaffDeptFilter =
  | 'all'
  | 'executive'
  | 'thai'
  | 'math'
  | 'science'
  | 'social'
  | 'foreign'
  | 'support';

export interface PublicNewsAttachment {
  id: string;
  title: string;
  url: string;
  fileSizeLabel?: string;
}

export interface PublicMediaItem {
  id: string;
  name: string;
  type: 'image' | 'document';
  folder: 'ข่าวประชาสัมพันธ์' | 'เอกสารรับสมัคร' | 'แบนเนอร์และกิจกรรม' | 'ทั่วไป';
  url: string;
  sizeLabel: string;
  uploadedAt: string;
}

export interface PublicNewsItem {
  id: string;
  cat: Exclude<NewsFilterCat, 'all'>;
  badgeText: string;
  badgeStyle: 'primary' | 'secondary' | 'tertiary' | 'surface';
  dateLabel: string;
  title: string;
  summary: string;
  imageUrl: string;
  imageAlt: string;
  author: string;
  authorRole: string;
  isFeatured?: boolean;
  showOnHome?: boolean;
  homeOrder?: number;
  status?: 'published' | 'draft';
  pinned?: boolean;
  attachments?: PublicNewsAttachment[];
  galleryImages?: string[];
  fullParagraphs: string[];
}

export interface PublicStaffItem {
  id: string;
  name: string;
  role: string;
  dept: Exclude<StaffDeptFilter, 'all'>;
  deptBadgeText: string;
  deptBadgeTone: 'primary' | 'secondary' | 'tertiary';
  imageUrl: string;
  education?: string;
  email?: string;
  phone?: string;
  quote?: string;
  isDirector?: boolean;
  isViceDirector?: boolean;
}

export interface PublicCalendarEventItem {
  id: string;
  day: string;
  month: string;
  title: string;
  subtitle: string;
  tag: string;
  tone: 'primary' | 'secondary' | 'tertiary';
}

export interface PublicGradeStatItem {
  badge: string;
  title: string;
  roomsCount: number;
  male: number;
  female: number;
  isSenior: boolean;
}

export interface PublicStudyPlanItem {
  id: string;
  label: string;
  countLabel: string;
}

export interface PublicDownloadDocItem {
  id: string;
  title: string;
  fileType: 'PDF' | 'DOCX';
  fileSize: string;
  updatedLabel: string;
  fileUrl?: string;
}

export interface PublicSchoolWebConfig {
  home: {
    heroBadge: string;
    heroTitle: string;
    heroSubtitle: string;
    heroImageUrl: string;
    admissionBannerTitle: string;
    admissionBannerSubtitle: string;
    stats: {
      studentsCount: number;
      staffCount: number;
      awardsCount: number;
      foundedYearBe: number;
    };
    events: PublicCalendarEventItem[];
    director: {
      name: string;
      position: string;
      standing: string;
      imageUrl: string;
      headline: string;
      message: string;
    };
  };
  news: PublicNewsItem[];
  staff: {
    academicYearLabel: string;
    totalStaffLabel: string;
    executives: PublicStaffItem[];
    teachingStaff: PublicStaffItem[];
  };
  students: {
    updatedDateLabel: string;
    heroImageUrl: string;
    grades: PublicGradeStatItem[];
    studyPlans: PublicStudyPlanItem[];
    downloads: PublicDownloadDocItem[];
  };
  about: {
    englishName: string;
    smisCode: string;
    schoolSizeLabel: string;
    foundedYearBe: string;
    areaSizeLabel: string;
    gradeRangeLabel: string;
    campusHeroImageUrl: string;
    historyImageUrl: string;
    historyParagraphs: string[];
    visionTitle: string;
    visionText: string;
    missions: string[];
    goals: string[];
    schoolColors: string;
    philosophyTitle: string;
    philosophyDesc: string;
    mottoTitle: string;
    mottoDesc: string;
    uniquenessTitle: string;
    uniquenessDesc: string;
    identityTitle: string;
    identityDesc: string;
  };
  contact: {
    address: string;
    shortLocation: string;
    phoneMain: string;
    phoneAcademic: string;
    fax: string;
    emailMain: string;
    emailAcademic: string;
    officeHours: string;
    officeHoursNote: string;
    facebookName: string;
    facebookUrl: string;
    lineOfficialId: string;
    lineOfficialUrl: string;
    googleMapsUrl: string;
    mapPreviewImageUrl: string;
    mapDirectionsNote: string;
  };
  admission: PublicAdmissionConfig;
  mediaLibrary: PublicMediaItem[];
}

export const DEFAULT_PUBLIC_SCHOOL_WEB_CONFIG: PublicSchoolWebConfig = {
  home: {
    heroBadge: 'โรงเรียนมาตรฐานสากล • สพม.บุรีรัมย์',
    heroTitle: 'มุ่งมั่นพัฒนาผู้เรียน สู่ความเป็นเลิศทางวิชาการและคุณธรรม',
    heroSubtitle:
      'บูรณาการเทคโนโลยีการศึกษาสมัยใหม่ ควบคู่การปลูกฝังคุณธรรมจริยธรรมและทักษะชีวิตในศตวรรษที่ 21',
    heroImageUrl:
      'https://images.unsplash.com/photo-1650525217641-891e936d3486?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxUaGFpJTIwaGlnaCUyMHNjaG9vbCUyMGNhbXB1cyUyMGJ1aWxkaW5nJTIwc3R1ZGVudHMlMjBsZWFybmluZ3xlbnwwfDB8fHwxNzc2Nzk3MTk5fDA&ixlib=rb-4.1.0&q=80&w=1080',
    admissionBannerTitle: 'เปิดรับสมัครนักเรียน 2568',
    admissionBannerSubtitle: 'ระดับชั้น ม.1 และ ม.4 • ภาคเรียนที่ 1',
    stats: {
      studentsCount: 1450,
      staffCount: 86,
      awardsCount: 42,
      foundedYearBe: 2531,
    },
    events: [
      {
        id: 'ev-1',
        day: '16',
        month: 'พ.ค.',
        title: 'วันเปิดภาคเรียนที่ 1 ปีการศึกษา 2568',
        subtitle: 'เวลา 07.45 น. • ลานเอนกประสงค์หน้าเสาธง',
        tag: 'วิชาการ',
        tone: 'primary',
      },
      {
        id: 'ev-2',
        day: '22',
        month: 'พ.ค.',
        title: 'การประชุมผู้ปกครองนักเรียน ภาคเรียนที่ 1/2568',
        subtitle: 'เวลา 08.30 – 12.00 น. • หอประชุมเฉลิมพระเกียรติ',
        tag: 'ผู้ปกครอง',
        tone: 'secondary',
      },
      {
        id: 'ev-3',
        day: '05',
        month: 'มิ.ย.',
        title: 'พิธีไหว้ครูและมอบทุนการศึกษา ประจำปี 2568',
        subtitle: 'เวลา 08.30 – 11.30 น. • หอประชุมเฉลิมพระเกียรติ',
        tag: 'กิจกรรมนักเรียน',
        tone: 'tertiary',
      },
    ],
    director: {
      name: 'นายสมชาย ใจดี',
      position: 'ผู้อำนวยการโรงเรียน',
      standing: 'วิทยฐานะ ผู้อำนวยการเชี่ยวชาญ',
      imageUrl:
        'https://images.unsplash.com/photo-1763596387544-f0eb2a14dbbd?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxzZW5pb3IlMjBUaGFpJTIwbWFsZSUyMHNjaG9vbCUyMGRpcmVjdG9yJTIwcG9ydHJhaXQlMjBmb3JtYWwlMjBzdWl0fGVufDB8MHx8fDE3NzY3OTcyMDF8MA&ixlib=rb-4.1.0&q=80&w=1080',
      headline:
        '“สร้างโอกาสทางการศึกษา พัฒนาคนสู่อนาคต ด้วยนวัตกรรมและคุณธรรม”',
      message:
        'มุ่งมั่นในการยกระดับคุณภาพการจัดการเรียนรู้ให้สอดคล้องกับมาตรฐานสากล โดยเน้นผู้เรียนเป็นสำคัญ ส่งเสริมศักยภาพตามความถนัดทั้งด้านวิทยาศาสตร์ เทคโนโลยี ภาษา และศิลปะ พร้อมทั้งปลูกฝังความรับผิดชอบต่อสังคมและสิ่งแวดล้อม',
    },
  },
  news: [
    {
      id: 'featured-sci',
      cat: 'academic',
      badgeText: 'ข่าววิชาการ',
      badgeStyle: 'tertiary',
      dateLabel: '15 พฤษภาคม 2568',
      title:
        'นักเรียนโรงเรียนรมย์บุรีพิทยาคมฯ คว้ารางวัลชนะเลิศการแข่งขันโครงงานวิทยาศาสตร์ระดับภาคตะวันออกเฉียงเหนือ',
      summary:
        'ตัวแทนนักเรียนระดับชั้นมัธยมศึกษาปีที่ 5 สร้างชื่อเสียงให้กับโรงเรียนและจังหวัดบุรีรัมย์ ด้วยการคว้ารางวัลชนะเลิศเหรียญทอง การประกวดโครงงานวิทยาศาสตร์นวัตกรรมสิ่งแวดล้อม พร้อมเตรียมเป็นตัวแทนเข้าแข่งขันในระดับประเทศต่อไป',
      imageUrl:
        'https://images.unsplash.com/photo-1761039808597-5639866bab8a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxUaGFpJTIwaGlnaCUyMHNjaG9vbCUyMHN0dWRlbnRzJTIwc2NpZW5jZSUyMGNvbXBldGl0aW9uJTIwYXdhcmQlMjBjZXJlbW9ueXxlbnwwfDB8fHwxNzc2Nzk3MzU2fDA&ixlib=rb-4.1.0&q=80&w=1080',
      imageAlt: 'นักเรียนรับรางวัลการแข่งขันวิชาการระดับภาค',
      author: 'กลุ่มสาระการเรียนรู้วิทยาศาสตร์และเทคโนโลยี',
      authorRole: 'ฝ่ายวิชาการ',
      isFeatured: true,
      showOnHome: true,
      homeOrder: 1,
      fullParagraphs: [
        'โรงเรียนขอแสดงความยินดีกับทีมนักเรียนระดับชั้นมัธยมศึกษาปีที่ 5 และคณะครูที่ปรึกษา กลุ่มสาระการเรียนรู้วิทยาศาสตร์และเทคโนโลยี ที่ได้รับรางวัลชนะเลิศเหรียญทอง การประกวดโครงงานวิทยาศาสตร์ด้านนวัตกรรมสิ่งแวดล้อม ระดับภาคตะวันออกเฉียงเหนือ ประจำปีการศึกษา 2568',
        'ผลงานโครงงานดังกล่าวเป็นการพัฒนานวัตกรรมวัสดุกรองน้ำพลังงานสะอาดจากวัสดุเหลือใช้ทางการเกษตรในท้องถิ่นจังหวัดบุรีรัมย์ ซึ่งได้รับคำชื่นชมจากคณะกรรมการผู้ทรงคุณวุฒิเป็นอย่างมาก และจะได้เป็นตัวแทนระดับภาคเข้าแข่งขันในงานศิลปหัตถกรรมนักเรียนระดับชาติต่อไป',
      ],
    },
    {
      id: 'news-admission-68',
      cat: 'admission',
      badgeText: 'ประกาศรับสมัคร',
      badgeStyle: 'secondary',
      dateLabel: '12 พฤษภาคม 2568',
      title:
        'ประกาศรายชื่อผู้มีสิทธิ์เข้าสอบคัดเลือกและแผนผังห้องสอบ ระดับชั้น ม.1 และ ม.4 ปีการศึกษา 2568',
      summary:
        'ให้นักเรียนที่มีรายชื่อตรวจสอบเลขประจำตัวผู้เข้าสอบ อาคารสอบ และเตรียมบัตรประจำตัวประชาชนหรือบัตรนักเรียนมาแสดงในวันสอบคัดเลือก',
      imageUrl:
        'https://images.unsplash.com/photo-1653250198948-1405af521dbb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxzY2hvb2wlMjBhZG1pc3Npb24lMjBleGFtJTIwY2xhc3Nyb29tJTIwc3R1ZGVudHMlMjB3cml0aW5nfGVufDB8MHx8fDE3NzY3OTczNTZ8MA&ixlib=rb-4.1.0&q=80&w=1080',
      imageAlt: 'ประกาศรายชื่อผู้มีสิทธิ์สอบคัดเลือก ม.1 และ ม.4',
      author: 'กลุ่มบริหารงานวิชาการ',
      authorRole: 'งานรับนักเรียน',
      showOnHome: false,
      fullParagraphs: [
        'ตามที่โรงเรียนได้เปิดรับสมัครนักเรียนเข้าศึกษาต่อระดับชั้นมัธยมศึกษาปีที่ 1 และชั้นมัธยมศึกษาปีที่ 4 ประจำปีการศึกษา 2568 บัดนี้การตรวจสอบคุณสมบัติเสร็จสิ้นแล้ว จึงประกาศรายชื่อผู้มีสิทธิ์เข้าสอบคัดเลือกและแผนผังห้องสอบ',
        'ขอให้นักเรียนผู้เข้าสอบมารายงานตัว ณ อาคารสอบตั้งแต่เวลา 08.00 น. พร้อมนำบัตรประจำตัวผู้เข้าสอบ บัตรประชาชน ดินสอ 2B ปากกาน้ำเงิน และยางลบมาให้พร้อม',
      ],
    },
    {
      id: 'news-Sports',
      cat: 'activity',
      badgeText: 'กิจกรรมนักเรียน',
      badgeStyle: 'primary',
      dateLabel: '8 พฤษภาคม 2568',
      title:
        'ประมวลภาพกิจกรรมกีฬาสีภายใน "รมย์บุรีเกมส์ ครั้งที่ 35" สร้างความสามัคคีและสุขภาพที่ดีของนักเรียน',
      summary:
        'บรรยากาศขบวนพาเหรด การแข่งขันกรีฑา และกองเชียร์จากทั้ง 4 คณะสี ที่แสดงออกถึงความคิดสร้างสรรค์และความสามัคคีของพี่น้องชาวรมย์บุรีพิทยาคม',
      imageUrl:
        'https://images.unsplash.com/photo-1762013191908-be2eedb3cade?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxUaGFpJTIwc2Nob29sJTIwc3BvcnRzJTIwZGF5JTIwc3R1ZGVudHMlMjBydW5uaW5nJTIwY2hlZXJpbmd8ZW58MHwwfHx8MTc3Njc5NzM1N3ww&ixlib=rb-4.1.0&q=80&w=1080',
      imageAlt: 'กิจกรรมกีฬาสีภายใน รมย์บุรีเกมส์',
      author: 'กลุ่มบริหารงานกิจการนักเรียน',
      authorRole: 'งานกีฬาและนันทนาการ',
      showOnHome: true,
      homeOrder: 2,
      fullParagraphs: [
        'โรงเรียนได้จัดกิจกรรมแข่งขันกีฬาสีภายใน "รมย์บุรีเกมส์" เพื่อส่งเสริมให้นักเรียนได้แสดงออกถึงความสามารถด้านกีฬา การทำงานเป็นทีม และการมีน้ำใจนักกีฬา รู้แพ้ รู้ชนะ รู้อภัย',
        'ภายในงานมีการประกวดขบวนพาเหรดรณรงค์อนุรักษ์สิ่งแวดล้อม การแข่งขันกรีฑา ฟุตซอล วอลเลย์บอล และบาสเกตบอล ท่ามกลางบรรยากาศที่อบอุ่นและสนุกสนาน',
      ],
    },
    {
      id: 'news-stem-camp',
      cat: 'academic',
      badgeText: 'ข่าววิชาการ',
      badgeStyle: 'tertiary',
      dateLabel: '3 พฤษภาคม 2568',
      title:
        'เปิดรับสมัครนักเรียนเข้าร่วมค่ายพัฒนาทักษะสะเต็มศึกษาและหุ่นยนต์ (STEM & Robotics Camp 2025)',
      summary:
        'เชิญชวนนักเรียนระดับชั้น ม.ต้น และ ม.ปลาย ที่สนใจด้านการเขียนโปรแกรมและประดิษฐ์หุ่นยนต์ สมัครเข้าร่วมอบรมเชิงปฏิบัติการฟรีไม่มีค่าใช้จ่าย',
      imageUrl:
        'https://images.unsplash.com/photo-1657891670079-3fe7db4fb91a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxzY2hvb2wlMjBjb21wdXRlciUyMGxhYiUyMHN0dWRlbnRzJTIwY29kaW5nJTIwcm9ib3RpY3N8ZW58MHwwfHx8MTc3Njc5NzM1N3ww&ixlib=rb-4.1.0&q=80&w=1080',
      imageAlt: 'อบรมเชิงปฏิบัติการ STEM และหุ่นยนต์',
      author: 'กลุ่มสาระการเรียนรู้วิทยาศาสตร์และเทคโนโลยี',
      authorRole: 'ศูนย์สะเต็มศึกษา',
      showOnHome: false,
      fullParagraphs: [
        'ศูนย์สะเต็มศึกษาของโรงเรียน เปิดรับสมัครนักเรียนระดับชั้น ม.1 – ม.6 ที่มีความสนใจด้านเทคโนโลยี หุ่นยนต์อัตโนมัติ และการเขียนโปรแกรมควบคุมไมโครคอนโทรลเลอร์ เข้าร่วมค่าย STEM & Robotics Camp 2025',
        'นักเรียนที่ผ่านการอบรมจะได้รับเกียรติบัตรและมีโอกาสได้รับการคัดเลือกเป็นตัวแทนโรงเรียนเข้าแข่งขันหุ่นยนต์ระดับเขตพื้นที่การศึกษาและระดับภูมิภาค',
      ],
    },
    {
      id: 'news-procurement-lab',
      cat: 'procurement',
      badgeText: 'จัดซื้อจัดจ้าง',
      badgeStyle: 'surface',
      dateLabel: '28 เมษายน 2568',
      title:
        'ประกาศประกวดราคาซื้อครุภัณฑ์ห้องปฏิบัติการคอมพิวเตอร์และสื่อการเรียนการสอนดิจิทัล ด้วยวิธีประกวดราคาอิเล็กทรอนิกส์ (e-bidding)',
      summary:
        'ผู้สนใจสามารถขอรับเอกสารประกวดราคาอิเล็กทรอนิกส์โดยดาวน์โหลดผ่านทางระบบจัดซื้อจัดจ้างภาครัฐด้วยอิเล็กทรอนิกส์ (e-GP) ตั้งแต่วันนี้เป็นต้นไป',
      imageUrl:
        'https://images.unsplash.com/photo-1767844056603-f2ef4ef2fc2f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxvZmZpY2lhbCUyMGRvY3VtZW50JTIwc2lnbmluZyUyMG9mZmljZSUyMGRlc2slMjBwYXBlcndvcmt8ZW58MHwwfHx8MTc3Njc5NzM1N3ww&ixlib=rb-4.1.0&q=80&w=1080',
      imageAlt: 'ประกาศจัดซื้อจัดจ้างปรับปรุงห้องปฏิบัติการ',
      author: 'กลุ่มบริหารงานงบประมาณ',
      authorRole: 'งานพัสดุและสินทรัพย์',
      showOnHome: false,
      fullParagraphs: [
        'โรงเรียนมีความประสงค์จะประกวดราคาซื้อครุภัณฑ์ห้องปฏิบัติการคอมพิวเตอร์และสื่อการเรียนการสอนดิจิทัล จำนวน 45 ชุด ด้วยวิธีประกวดราคาอิเล็กทรอนิกส์ (e-bidding) ตามรายละเอียดคุณลักษณะเฉพาะแนบท้ายประกาศ',
        'ผู้ยื่นข้อเสนอสามารถศึกษารายละเอียดและดาวน์โหลดเอกสารผ่านระบบจัดซื้อจัดจ้างภาครัฐ (e-GP) ของกรมบัญชีกลาง หรือสอบถามข้อมูลเพิ่มเติมได้ที่งานพัสดุ กลุ่มบริหารงานงบประมาณ ในวันและเวลาราชการ',
      ],
    },
    {
      id: 'news-wai-kru',
      cat: 'activity',
      badgeText: 'กิจกรรมนักเรียน',
      badgeStyle: 'primary',
      dateLabel: '22 เมษายน 2568',
      title:
        'กิจกรรมพิธีไหว้ครูและมอบทุนการศึกษาแก่นักเรียนเรียนดีแต่ขาดแคลนทุนทรัพย์ ประจำปีการศึกษา 2568',
      summary:
        'โรงเรียนจัดพิธีไหว้ครูเพื่อสืบสานประเพณีอันดีงามในการแสดงความกตัญญูกตเวทีต่อบูรพาจารย์ พร้อมมอบทุนการศึกษาจำนวนกว่า 85 ทุน',
      imageUrl:
        'https://images.unsplash.com/photo-1761504695830-0ab3bc5bd8c0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxUaGFpJTIwY3VsdHVyYWwlMjBjZXJlbW9ueSUyMHNjaG9vbCUyMHN0dWRlbnRzJTIwdGVhY2hlcnMlMjByZXNwZWN0fGVufDB8MHx8fDE3NzY3OTczNTh8MA&ixlib=rb-4.1.0&q=80&w=1080',
      imageAlt: 'พิธีไหว้ครูและมอบทุนการศึกษาประจำปี',
      author: 'กลุ่มบริหารงานกิจการนักเรียน',
      authorRole: 'งานส่งเสริมคุณธรรมจริยธรรม',
      showOnHome: false,
      fullParagraphs: [
        'โรงเรียนได้จัดพิธีไหว้ครูประจำปีการศึกษา 2568 ณ หอประชุมเฉลิมพระเกียรติ เพื่อให้นักเรียนได้แสดงความเคารพและระลึกถึงพระคุณของครูอาจารย์ผู้ประสิทธิ์ประสาทวิชาความรู้',
        'ในโอกาสนี้ คณะผู้บริหาร คณะกรรมการสถานศึกษา และศิษย์เก่า ได้ร่วมมอบทุนการศึกษาให้แก่นักเรียนที่มีผลการเรียนดี มีความประพฤติเรียบร้อย แต่ขาดแคลนทุนทรัพย์ รวมทั้งสิ้นกว่า 85 ทุน',
      ],
    },
    {
      id: 'news-new-term',
      cat: 'admission',
      badgeText: 'ประกาศรับสมัคร',
      badgeStyle: 'secondary',
      dateLabel: '16 เมษายน 2568',
      title:
        'กำหนดการเปิดภาคเรียนที่ 1/2568 และการเตรียมความพร้อมก่อนเปิดเรียนสำหรับนักเรียนทุกระดับชั้น',
      summary:
        'แจ้งกำหนดการประชุมผู้ปกครองนักเรียน วันรายงานตัว การแต่งกาย และมาตรการดูแลความปลอดภัยภายในสถานศึกษาสำหรับภาคเรียนที่ 1',
      imageUrl:
        'https://images.unsplash.com/photo-1650525217641-891e936d3486?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxzY2hvb2wlMjBidWlsZGluZyUyMGNhbXB1cyUyMG1vcm5pbmclMjBzdHVkZW50cyUyMHdhbGtpbmd8ZW58MHwwfHx8MTc3Njc5NzM1OHww&ixlib=rb-4.1.0&q=80&w=1080',
      imageAlt: 'กำหนดการเปิดภาคเรียนที่ 1 ปีการศึกษา 2568',
      author: 'กลุ่มบริหารงานทั่วไป',
      authorRole: 'งานประชาสัมพันธ์',
      showOnHome: true,
      homeOrder: 3,
      fullParagraphs: [
        'โรงเรียนขอแจ้งกำหนดการเปิดภาคเรียนที่ 1 ประจำปีการศึกษา 2568 โดยกำหนดเปิดเรียนพร้อมกันทุกระดับชั้น (ม.1 – ม.6) ในวันที่ 16 พฤษภาคม 2568',
        'ทั้งนี้ ขอความร่วมมือผู้ปกครองและนักเรียนตรวจสอบตารางเรียน รายชื่อครูที่ปรึกษา และระเบียบการแต่งกายได้ทางหน้าเว็บไซต์ของโรงเรียน หรือติดต่อสอบถามที่ฝ่ายวิชาการและฝ่ายกิจการนักเรียน',
      ],
    },
  ],
  staff: {
    academicYearLabel: '2568',
    totalStaffLabel: '64 ท่าน',
    executives: [
      {
        id: 'exec-director',
        name: 'นายสมศักดิ์ วัฒนากูล',
        role: 'ผู้อำนวยการโรงเรียน',
        dept: 'executive',
        deptBadgeText: 'ผู้อำนวยการสถานศึกษา',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1643284461591-7fd5fc242ef7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxzZW5pb3IlMjBhc2lhbiUyMG1hbGUlMjBzY2hvb2wlMjBkaXJlY3RvciUyMGZvcm1hbCUyMHN1aXQlMjBwb3J0cmFpdHxlbnwwfDB8fHwxNzc2Nzk3NDI1fDA&ixlib=rb-4.1.0&q=80&w=1080',
        education: 'กศ.ม. (การบริหารการศึกษา)',
        email: 'director@romburipit.ac.th',
        phone: '044-612-xxx ต่อ 101',
        quote:
          '“มุ่งมั่นพัฒนาผู้เรียนให้มีความเป็นเลิศทางวิชาการ ควบคู่คุณธรรมจริยธรรม ก้าวทันเทคโนโลยีดิจิทัล บนพื้นฐานความเป็นไทย”',
        isDirector: true,
      },
      {
        id: 'exec-vp-academic',
        name: 'นางสาวปิยะนุช ศรีสุวรรณ',
        role: 'รองผู้อำนวยการโรงเรียน',
        dept: 'executive',
        deptBadgeText: 'กลุ่มบริหารวิชาการ',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1758600587839-56ba05596c69?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMGZlbWFsZSUyMGV4ZWN1dGl2ZSUyMHRlYWNoZXIlMjBmb3JtYWwlMjBibGF6ZXIlMjBwb3J0cmFpdHxlbnwwfDB8fHwxNzc2Nzk3NDI2fDA&ixlib=rb-4.1.0&q=80&w=1080',
        email: 'academic.vp@romburipit.ac.th',
        isViceDirector: true,
      },
      {
        id: 'exec-vp-student',
        name: 'นายวิชัย รัตนากร',
        role: 'รองผู้อำนวยการโรงเรียน',
        dept: 'executive',
        deptBadgeText: 'กลุ่มบริหารกิจการนักเรียน',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1752486268300-1bb7d6d9867d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMG1hbGUlMjB2aWNlJTIwcHJpbmNpcGFsJTIwZm9ybWFsJTIwc3VpdCUyMHBvcnRyYWl0fGVufDB8MHx8fDE3NzY3OTc0MjZ8MA&ixlib=rb-4.1.0&q=80&w=1080',
        email: 'student.vp@romburipit.ac.th',
        isViceDirector: true,
      },
      {
        id: 'exec-vp-general',
        name: 'นางกัลยาณี ทองคำ',
        role: 'รองผู้อำนวยการโรงเรียน',
        dept: 'executive',
        deptBadgeText: 'กลุ่มบริหารทั่วไปและงบประมาณ',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1657152042392-c1f39e52e7c9?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMGZlbWFsZSUyMHNlbmlvciUyMGFkbWluaXN0cmF0b3IlMjBmb3JtYWwlMjBwb3J0cmFpdHxlbnwwfDB8fHwxNzc2Nzk3NDI3fDA&ixlib=rb-4.1.0&q=80&w=1080',
        email: 'general.vp@romburipit.ac.th',
        isViceDirector: true,
      },
    ],
    teachingStaff: [
      {
        id: 'staff-1',
        name: 'นางสาวดวงใจ วรรณศิลป์',
        role: 'หัวหน้ากลุ่มสาระฯ • ครูชำนาญการพิเศษ',
        dept: 'thai',
        deptBadgeText: 'กลุ่มสาระฯ ภาษาไทย',
        deptBadgeTone: 'secondary',
        imageUrl:
          'https://images.unsplash.com/photo-1580894732230-28cef47eb8d3?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMGZlbWFsZSUyMHRlYWNoZXIlMjBzbWlsaW5nJTIwY2xhc3Nyb29tJTIwcG9ydHJhaXR8ZW58MHwwfHx8MTc3Njc5NzQyN3ww&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-2',
        name: 'นายประเสริฐ อักษรทอง',
        role: 'ครูชำนาญการ',
        dept: 'thai',
        deptBadgeText: 'กลุ่มสาระฯ ภาษาไทย',
        deptBadgeTone: 'secondary',
        imageUrl:
          'https://images.unsplash.com/photo-1659100947220-48b5d5738148?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMG1hbGUlMjB0ZWFjaGVyJTIwZ2xhc3NlcyUyMGZvcm1hbCUyMHBvcnRyYWl0fGVufDB8MHx8fDE3NzY3OTc0Mjd8MA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-3',
        name: 'นายธนากร พิพัฒน์พงศ์',
        role: 'หัวหน้ากลุ่มสาระฯ • ครูชำนาญการพิเศษ',
        dept: 'math',
        deptBadgeText: 'กลุ่มสาระฯ คณิตศาสตร์',
        deptBadgeTone: 'tertiary',
        imageUrl:
          'https://images.unsplash.com/photo-1565598621680-94ac0c22b148?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMG1hbGUlMjBtYXRoJTIwdGVhY2hlciUyMHBvcnRyYWl0JTIwcHJvZmVzc2lvbmFsfGVufDB8MHx8fDE3NzY3OTc0Mjh8MA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-4',
        name: 'นางสาวชลธิชา วงศ์สวัสดิ์',
        role: 'ครูชำนาญการ',
        dept: 'math',
        deptBadgeText: 'กลุ่มสาระฯ คณิตศาสตร์',
        deptBadgeTone: 'tertiary',
        imageUrl:
          'https://images.unsplash.com/photo-1758600432277-5c768ebd7f13?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMGFzaWFuJTIwZmVtYWxlJTIwdGVhY2hlciUyMHByb2Zlc3Npb25hbCUyMHBvcnRyYWl0fGVufDB8MHx8fDE3NzY3OTc0Mjh8MA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-5',
        name: 'ดร.ศุภชัย นวัตกรรม',
        role: 'หัวหน้ากลุ่มสาระฯ • ครูเชี่ยวชาญ',
        dept: 'science',
        deptBadgeText: 'วิทยาศาสตร์และเทคโนโลยี',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1648448942225-7aa06c7e8f79?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMG1hbGUlMjBzY2llbmNlJTIwdGVhY2hlciUyMGxhYiUyMHByb2Zlc3Npb25hbCUyMHBvcnRyYWl0fGVufDB8MHx8fDE3NzY3OTc0Mjl8MA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-6',
        name: 'นางสาวภัทราพร แก้วมณี',
        role: 'ครูชำนาญการ (เคมี - ชีววิทยา)',
        dept: 'science',
        deptBadgeText: 'วิทยาศาสตร์และเทคโนโลยี',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1763890965378-69fbc8beb7f0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMGZlbWFsZSUyMHNjaWVuY2UlMjB0ZWFjaGVyJTIwZ2xhc3NlcyUyMHBvcnRyYWl0fGVufDB8MHx8fDE3NzY3OTc0Mjl8MA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-7',
        name: 'นายณัฐวุฒิ ไอทีสยาม',
        role: 'ครูผู้สอนคอมพิวเตอร์และเทคโนโลยีดิจิทัล',
        dept: 'science',
        deptBadgeText: 'วิทยาศาสตร์และเทคโนโลยี',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1589697547048-962940abc062?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMG1hbGUlMjBjb21wdXRlciUyMHRlYWNoZXIlMjBtb2Rlcm4lMjBwb3J0cmFpdHxlbnwwfDB8fHwxNzc2Nzk3NDI5fDA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-8',
        name: 'นางสุภาพร ธรรมรักษ์',
        role: 'หัวหน้ากลุ่มสาระฯ • ครูชำนาญการพิเศษ',
        dept: 'social',
        deptBadgeText: 'สังคมศึกษา ศาสนา และวัฒนธรรม',
        deptBadgeTone: 'secondary',
        imageUrl:
          'https://images.unsplash.com/photo-1664382951771-40432ecc81bd?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMGZlbWFsZSUyMGhpc3RvcnklMjB0ZWFjaGVyJTIwc21pbGluZyUyMHBvcnRyYWl0fGVufDB8MHx8fDE3NzY3OTc0MzB8MA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-9',
        name: 'นายเกรียงไกร ชาติไทย',
        role: 'ครูชำนาญการ (ประวัติศาสตร์ - หน้าที่พลเมือง)',
        dept: 'social',
        deptBadgeText: 'สังคมศึกษา ศาสนา และวัฒนธรรม',
        deptBadgeTone: 'secondary',
        imageUrl:
          'https://images.unsplash.com/photo-1758685734503-58a8accc24e8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMG1hbGUlMjBzb2NpYWwlMjBzdHVkaWVzJTIwdGVhY2hlciUyMHBvcnRyYWl0fGVufDB8MHx8fDE3NzY3OTc0MzB8MA&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-10',
        name: 'นางสาวอลิสา อินเตอร์',
        role: 'หัวหน้ากลุ่มสาระฯ • ครูชำนาญการพิเศษ',
        dept: 'foreign',
        deptBadgeText: 'กลุ่มสาระฯ ภาษาต่างประเทศ',
        deptBadgeTone: 'tertiary',
        imageUrl:
          'https://images.unsplash.com/photo-1711645169736-533eae2589fc?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMGZlbWFsZSUyMGVuZ2xpc2glMjB0ZWFjaGVyJTIwcHJvZmVzc2lvbmFsJTIwcG9ydHJhaXR8ZW58MHwwfHx8MTc3Njc5NzQzMHww&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-11',
        name: 'นางสาวพิมพ์ชนก ใจอารี',
        role: 'เจ้าหน้าที่ธุรการและการเงิน',
        dept: 'support',
        deptBadgeText: 'สายสนับสนุนการสอน',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1758520145147-c30bc656f314?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMGZlbWFsZSUyMG9mZmljZSUyMGFkbWluaXN0cmF0b3IlMjBzbWlsaW5nJTIwcG9ydHJhaXR8ZW58MHwwfHx8MTc3Njc5NzQzMXww&ixlib=rb-4.1.0&q=80&w=1080',
      },
      {
        id: 'staff-12',
        name: 'นายสมหมาย รักสะอาด',
        role: 'หัวหน้างานอาคารสถานที่และโสตทัศนูปกรณ์',
        dept: 'support',
        deptBadgeText: 'สายสนับสนุนการสอน',
        deptBadgeTone: 'primary',
        imageUrl:
          'https://images.unsplash.com/photo-1742119897876-67e9935ac375?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxhc2lhbiUyMG1hbGUlMjBsaWJyYXJpYW4lMjBzdXBwb3J0JTIwc3RhZmYlMjBwb3J0cmFpdHxlbnwwfDB8fHwxNzc2Nzk3NDMxfDA&ixlib=rb-4.1.0&q=80&w=1080',
      },
    ],
  },
  students: {
    updatedDateLabel: 'ปีการศึกษา 2568 • ข้อมูล ณ วันที่ 10 มิถุนายน 2568',
    heroImageUrl:
      'https://images.unsplash.com/photo-1509062522246-3755977927d7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxoaWdoJTIwc2Nob29sJTIwc3R1ZGVudHMlMjBjbGFzc3Jvb20lMjBsZWFybmluZ3xlbnwwfDB8fHwxNzc2Nzk3NDM3fDA&ixlib=rb-4.1.0&q=80&w=1080',
    grades: [
      {
        badge: 'ม.1',
        title: 'ชั้นมัธยมศึกษาปีที่ 1',
        roomsCount: 6,
        male: 104,
        female: 114,
        isSenior: false,
      },
      {
        badge: 'ม.2',
        title: 'ชั้นมัธยมศึกษาปีที่ 2',
        roomsCount: 6,
        male: 98,
        female: 116,
        isSenior: false,
      },
      {
        badge: 'ม.3',
        title: 'ชั้นมัธยมศึกษาปีที่ 3',
        roomsCount: 6,
        male: 101,
        female: 109,
        isSenior: false,
      },
      {
        badge: 'ม.4',
        title: 'ชั้นมัธยมศึกษาปีที่ 4',
        roomsCount: 6,
        male: 95,
        female: 113,
        isSenior: true,
      },
      {
        badge: 'ม.5',
        title: 'ชั้นมัธยมศึกษาปีที่ 5',
        roomsCount: 6,
        male: 94,
        female: 108,
        isSenior: true,
      },
      {
        badge: 'ม.6',
        title: 'ชั้นมัธยมศึกษาปีที่ 6',
        roomsCount: 6,
        male: 94,
        female: 102,
        isSenior: true,
      },
    ],
    studyPlans: [
      { id: 'plan-1', label: 'แผนวิทย์ - คณิต', countLabel: '240 คน' },
      { id: 'plan-2', label: 'แผนศิลป์ - คำนวณ', countLabel: '156 คน' },
      { id: 'plan-3', label: 'แผนศิลป์ - ภาษา', countLabel: '120 คน' },
      { id: 'plan-4', label: 'แผนทวิศึกษา / อาชีพ', countLabel: '90 คน' },
    ],
    downloads: [
      {
        id: 'doc-1',
        title: 'คู่มือนักเรียนและผู้ปกครอง ปีการศึกษา 2568',
        fileType: 'PDF',
        fileSize: '4.2 MB',
        updatedLabel: 'อัปเดต 1 พ.ค. 2568',
      },
      {
        id: 'doc-2',
        title: 'ระเบียบการแต่งกายและทรงผมนักเรียน พ.ศ. 2568',
        fileType: 'PDF',
        fileSize: '1.8 MB',
        updatedLabel: 'อัปเดต 15 เม.ย. 2568',
      },
      {
        id: 'doc-3',
        title:
          'แบบฟอร์มขอใบรับรองผลการเรียน (ปพ.7) และระเบียนแสดงผลการเรียน (ปพ.1)',
        fileType: 'PDF',
        fileSize: '520 KB',
        updatedLabel: 'งานทะเบียนวัดผล',
      },
      {
        id: 'doc-4',
        title: 'แบบฟอร์มคำร้องขอลาป่วย / ลากิจ สำหรับนักเรียน',
        fileType: 'DOCX',
        fileSize: '340 KB',
        updatedLabel: 'ฝ่ายกิจการนักเรียน',
      },
      {
        id: 'doc-5',
        title: 'ปฏิทินวิชาการและกำหนดการสอบ ภาคเรียนที่ 1/2568',
        fileType: 'PDF',
        fileSize: '1.1 MB',
        updatedLabel: 'ฝ่ายวิชาการ',
      },
    ],
  },
  about: {
    englishName: 'Romburipittayakom Ratchamangklaphisek School',
    smisCode: '1031250148',
    schoolSizeLabel: 'โรงเรียนมัธยมศึกษาขนาดกลาง',
    foundedYearBe: '2531',
    areaSizeLabel: '45 ไร่',
    gradeRangeLabel: 'ม.1 – ม.6',
    campusHeroImageUrl:
      'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=1200&q=80',
    historyImageUrl:
      'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&w=1000&q=80',
    historyParagraphs: [
      'ได้รับการประกาศจัดตั้งโดยกระทรวงศึกษาธิการ เมื่อปีพุทธศักราช 2531 เพื่อเฉลิมพระเกียรติพระบาทสมเด็จพระบรมชนกาธิเบศร มหาภูมิพลอดุลยเดชมหาราช บรมนาถบพิตร เนื่องในวโรกาสมหามงคลพระราชพิธีรัชมังคลาภิเษก ที่ทรงครองสิริราชสมบัติยาวนานกว่าพระมหากษัตริย์ทุกพระองค์ในประวัติศาสตร์ไทย',
      'ในระยะแรกของการก่อตั้ง โรงเรียนได้เปิดทำการเรียนการสอนในระดับชั้นมัธยมศึกษาตอนต้น เพื่อรองรับนักเรียนในเขตพื้นที่ตำบลรมย์บุรีและตำบลใกล้เคียง ต่อมาเมื่อชุมชนขยายตัวและมีความต้องการศึกษาต่อในระดับที่สูงขึ้น กระทรวงศึกษาธิการจึงอนุมัติให้เปิดสอนในระดับชั้นมัธยมศึกษาตอนปลาย (ม.1 – ม.6) อย่างเต็มรูปแบบ',
      'ปัจจุบัน โรงเรียนสังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์ สำนักงานคณะกรรมการการศึกษาขั้นพื้นฐาน (สพฐ.) มีการพัฒนาอาคารสถานที่ ห้องปฏิบัติการวิทยาศาสตร์ ห้องคอมพิวเตอร์ และแหล่งเรียนรู้ที่ทันสมัย เพื่อรองรับการจัดการเรียนรู้ตามหลักสูตรแกนกลางการศึกษาขั้นพื้นฐาน',
    ],
    visionTitle: 'มุ่งสู่มาตรฐานสากล บนพื้นฐานความพอเพียง',
    visionText:
      'เป็นสถานศึกษาที่พัฒนาผู้เรียนให้มีความเป็นเลิศทางวิชาการ มีคุณธรรมจริยธรรม ก้าวทันเทคโนโลยีดิจิทัล และดำรงชีวิตตามหลักปรัชญาของเศรษฐกิจพอเพียง',
    missions: [
      'จัดการเรียนรู้ที่เน้นผู้เรียนเป็นสำคัญด้วยกระบวนการ Active Learning และสื่อเทคโนโลยีสมัยใหม่',
      'ปลูกฝังคุณธรรม จริยธรรม ความเป็นพลเมืองดี และวิถีชีวิตตามหลักปรัชญาของเศรษฐกิจพอเพียง',
      'พัฒนาครูและบุคลากรทางการศึกษาให้เป็นมืออาชีพตามมาตรฐานวิชาชีพ',
      'ประสานความร่วมมือกับผู้ปกครอง ชุมชน และภาคีเครือข่ายในการร่วมพัฒนาสถานศึกษา',
    ],
    goals: [
      'ผู้เรียนมีผลสัมฤทธิ์ทางการเรียนและทักษะการคิดวิเคราะห์สูงขึ้นตามเกณฑ์มาตรฐานชาติ',
      'ผู้เรียนมีระเบียบวินัย จิตสาธารณะ และห่างไกลจากยาเสพติดและอบายมุข',
      'สถานศึกษามีสภาพแวดล้อมที่ปลอดภัย เอื้อต่อการเรียนรู้และเป็นมิตรกับสิ่งแวดล้อม',
    ],
    schoolColors: 'น้ำเงิน – ขาว',
    philosophyTitle: '“ปญฺญา โลกสฺมิ ปชฺโชโต”',
    philosophyDesc:
      'ปัญญาเป็นแสงสว่างในโลก — มุ่งเน้นการสร้างสติปัญญาและความรู้คู่คุณธรรม',
    mottoTitle: '“เรียนดี มีวินัย ใฝ่คุณธรรม นำชุมชน”',
    mottoDesc:
      'ยึดมั่นในการศึกษาเล่าเรียน รักษาระเบียบวินัย และเป็นกำลังสำคัญในการพัฒนาท้องถิ่น',
    uniquenessTitle: '“โรงเรียนสะอาด บรรยากาศร่มรื่น”',
    uniquenessDesc:
      'สถานศึกษาพอเพียงต้นแบบที่มีสิ่งแวดล้อมเอื้อต่อการเรียนรู้และสุขภาวะที่ดี',
    identityTitle: '“ยิ้มใส ไหว้สวย มีจิตอาสา”',
    identityDesc:
      'นักเรียนมีกิริยามารยาทงดงามตามวิถีไทย และพร้อมช่วยเหลือสังคมด้วยจิตสาธารณะ',
  },
  contact: {
    address:
      'เลขที่ 199 หมู่ 4 ตำบลรมย์บุรี อำเภอรมย์บุรี จังหวัดบุรีรัมย์ รหัสไปรษณีย์ 31150',
    shortLocation: 'ต.รมย์บุรี อ.รมย์บุรี จ.บุรีรัมย์',
    phoneMain: '044-612-xxx ต่อ 101',
    phoneAcademic: '044-612-xxx ต่อ 102',
    fax: '044-612-xxx ต่อ 109',
    emailMain: 'info@romburipit.ac.th',
    emailAcademic: 'academic@romburipit.ac.th',
    officeHours: 'วันจันทร์ – วันศุกร์ เวลา 08.00 – 16.30 น.',
    officeHoursNote: '(หยุดวันเสาร์ - อาทิตย์ และวันหยุดนักขัตฤกษ์)',
    facebookName: 'งานประชาสัมพันธ์ ร.ร.รมย์บุรีฯ',
    facebookUrl: 'https://facebook.com',
    lineOfficialId: '@romburipit',
    lineOfficialUrl: 'https://line.me',
    googleMapsUrl:
      'https://maps.google.com/?q=โรงเรียนรมย์บุรีพิทยาคม+รัชมังคลาภิเษก+บุรีรัมย์',
    mapPreviewImageUrl:
      'https://images.unsplash.com/photo-1763615834709-cd4b196980db?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4NjA1NTB8MHwxfHNlYXJjaHwxfHxzY2hvb2wlMjBjYW1wdXMlMjBhZXJpYWwlMjB2aWV3JTIwZ3JlZW4lMjB0cmVlcyUyMGJ1aWxkaW5nc3xlbnwwfDB8fHwxNzc2Nzk3NDM0fDA&ixlib=rb-4.1.0&q=80&w=1080',
    mapDirectionsNote:
      'ตั้งอยู่ริมทางหลวงหมายเลข 2074 ตำบลรมย์บุรี อำเภอรมย์บุรี จังหวัดบุรีรัมย์ ห่างจากที่ว่าการอำเภอประมาณ 1.5 กิโลเมตร',
  },
  admission: DEFAULT_PUBLIC_ADMISSION_CONFIG,
  mediaLibrary: [
    {
      id: 'media-1',
      name: 'ภาพบรรยากาศอาคารเรียนหลัก.jpg',
      type: 'image',
      folder: 'แบนเนอร์และกิจกรรม',
      url: 'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=1200&q=80',
      sizeLabel: '1.2 MB',
      uploadedAt: '2026-05-01',
    },
    {
      id: 'media-2',
      name: 'กิจกรรมวิชาการและโครงงานวิทยาศาสตร์.jpg',
      type: 'image',
      folder: 'ข่าวประชาสัมพันธ์',
      url: 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&w=1200&q=80',
      sizeLabel: '980 KB',
      uploadedAt: '2026-05-02',
    },
    {
      id: 'media-3',
      name: 'ระเบียบการรับสมัครนักเรียนใหม่_2568.pdf',
      type: 'document',
      folder: 'เอกสารรับสมัคร',
      url: 'https://www.obec.go.th',
      sizeLabel: '2.4 MB',
      uploadedAt: '2026-05-03',
    },
  ],
};

const STORAGE_PREFIX = 'public_school_web_config_v1_';

function getStorageKey(schoolId: number | null | undefined): string {
  return `${STORAGE_PREFIX}${schoolId ?? 'default'}`;
}

export function mergeWithDefaultPublicWebConfig(
  partial: Partial<PublicSchoolWebConfig> | null | undefined,
): PublicSchoolWebConfig {
  const d = DEFAULT_PUBLIC_SCHOOL_WEB_CONFIG;
  if (!partial || typeof partial !== 'object') {
    return JSON.parse(JSON.stringify(d)) as PublicSchoolWebConfig;
  }
  return {
    home: {
      ...d.home,
      ...(partial.home ?? {}),
      stats: {
        ...d.home.stats,
        ...(partial.home?.stats ?? {}),
      },
      events: Array.isArray(partial.home?.events)
        ? partial.home.events
        : d.home.events,
      director: {
        ...d.home.director,
        ...(partial.home?.director ?? {}),
      },
    },
    news: Array.isArray(partial.news) ? partial.news : d.news,
    staff: {
      ...d.staff,
      ...(partial.staff ?? {}),
      executives: Array.isArray(partial.staff?.executives)
        ? partial.staff.executives
        : d.staff.executives,
      teachingStaff: Array.isArray(partial.staff?.teachingStaff)
        ? partial.staff.teachingStaff
        : d.staff.teachingStaff,
    },
    students: {
      ...d.students,
      ...(partial.students ?? {}),
      grades: Array.isArray(partial.students?.grades)
        ? partial.students.grades
        : d.students.grades,
      studyPlans: Array.isArray(partial.students?.studyPlans)
        ? partial.students.studyPlans
        : d.students.studyPlans,
      downloads: Array.isArray(partial.students?.downloads)
        ? partial.students.downloads
        : d.students.downloads,
    },
    about: {
      ...d.about,
      ...(partial.about ?? {}),
      historyParagraphs: Array.isArray(partial.about?.historyParagraphs)
        ? partial.about.historyParagraphs
        : d.about.historyParagraphs,
      missions: Array.isArray(partial.about?.missions)
        ? partial.about.missions
        : d.about.missions,
      goals: Array.isArray(partial.about?.goals)
        ? partial.about.goals
        : d.about.goals,
    },
    contact: {
      ...d.contact,
      ...(partial.contact ?? {}),
    },
    admission: mergePublicAdmissionConfig(partial.admission),
    mediaLibrary: Array.isArray(partial.mediaLibrary)
      ? partial.mediaLibrary
      : d.mediaLibrary,
  };
}

export function loadLocalPublicWebConfig(
  schoolId: number | null | undefined,
): PublicSchoolWebConfig {
  try {
    const raw = window.localStorage.getItem(getStorageKey(schoolId));
    if (!raw) {
      return mergeWithDefaultPublicWebConfig(null);
    }
    const parsed = JSON.parse(raw) as Partial<PublicSchoolWebConfig>;
    return mergeWithDefaultPublicWebConfig(parsed);
  } catch {
    return mergeWithDefaultPublicWebConfig(null);
  }
}

export async function fetchPublicSchoolWebConfig(
  schoolId: number | null | undefined,
): Promise<PublicSchoolWebConfig> {
  let baseConfig = loadLocalPublicWebConfig(schoolId);
  let hasSavedCustomRow = false;

  if (schoolId) {
    try {
      const { data, error } = await supabase
        .from('SchoolPublicWebConfigs')
        .select('config_json')
        .eq('id_school', schoolId)
        .maybeSingle();

      if (!error && data && data.config_json) {
        hasSavedCustomRow = true;
        baseConfig = mergeWithDefaultPublicWebConfig(
          data.config_json as Partial<PublicSchoolWebConfig>,
        );
      }
    } catch {
      // ignore if table not created yet
    }
  }

  // ดึงข้อมูลจริงจากฐานข้อมูล (Schools, Teachers, SchoolWebStudents, SchoolWebClassrooms, SchoolWebAnnouncements)
  const enriched = await enrichConfigWithRealDatabaseData(
    schoolId,
    baseConfig,
    hasSavedCustomRow,
  );

  if (schoolId) {
    try {
      window.localStorage.setItem(
        getStorageKey(schoolId),
        JSON.stringify(enriched),
      );
    } catch {
      // ignore quota error
    }
  }

  return enriched;
}

interface RealtimeStaffRow {
  id_user: number;
  fullName: string | null;
  roleName: string | null;
  adminRoleName?: string | null;
  profileImage?: string | null;
}

interface RealtimeAnnouncementRow {
  id: number;
  title: string;
  content: string | null;
  category: 'general' | 'academic' | 'hr' | string;
  is_pinned: boolean;
  published_at: string;
}

interface RealtimeSchoolPayload {
  ok?: boolean;
  school?: {
    id_school: number;
    namePart1?: string | null;
    namePart2?: string | null;
    fullName?: string | null;
    affiliation?: string | null;
    localCode?: string | null;
    address?: string | null;
    subdistrict?: string | null;
    district?: string | null;
    province?: string | null;
    logo?: string | null;
  } | null;
  academicYearBe?: number | null;
  academicYearLabel?: string | null;
  staffCount?: number;
  staffList?: RealtimeStaffRow[];
  studentCount?: number;
  classroomCount?: number;
  gradeStats?: PublicGradeStatItem[];
  planStats?: PublicStudyPlanItem[];
  announcements?: RealtimeAnnouncementRow[];
}

function classifyTeacherDepartment(roleText: string): {
  dept: Exclude<StaffDeptFilter, 'all'>;
  badgeText: string;
  tone: PublicStaffItem['deptBadgeTone'];
} {
  const t = roleText.toLowerCase();
  if (t.includes('ภาษาไทย')) {
    return {
      dept: 'thai',
      badgeText: 'กลุ่มสาระฯ ภาษาไทย',
      tone: 'secondary',
    };
  }
  if (t.includes('คณิต')) {
    return {
      dept: 'math',
      badgeText: 'กลุ่มสาระฯ คณิตศาสตร์',
      tone: 'tertiary',
    };
  }
  if (t.includes('วิทย์') || t.includes('วิทยาศาสตร์') || t.includes('คอมพิวเตอร์') || t.includes('เทคโนโลยี')) {
    return {
      dept: 'science',
      badgeText: 'วิทยาศาสตร์และเทคโนโลยี',
      tone: 'primary',
    };
  }
  if (t.includes('สังคม') || t.includes('ประวัติ')) {
    return {
      dept: 'social',
      badgeText: 'สังคมศึกษา ศาสนา และวัฒนธรรม',
      tone: 'secondary',
    };
  }
  if (t.includes('อังกฤษ') || t.includes('ภาษาต่างประเทศ') || t.includes('จีน')) {
    return {
      dept: 'foreign',
      badgeText: 'กลุ่มสาระฯ ภาษาต่างประเทศ',
      tone: 'tertiary',
    };
  }
  if (t.includes('ธุรการ') || t.includes('สนับสนุน') || t.includes('เจ้าหน้าที่') || t.includes('การเงิน') || t.includes('พัสดุ')) {
    return {
      dept: 'support',
      badgeText: 'สายสนับสนุนการสอน',
      tone: 'primary',
    };
  }
  return {
    dept: 'science',
    badgeText: roleText || 'ข้าราชการครูและบุคลากร',
    tone: 'primary',
  };
}

async function fetchRealtimePayloadForSchool(
  schoolId: number | null | undefined,
): Promise<RealtimeSchoolPayload | null> {
  // 1) ลองเรียกผ่าน RPC get_public_school_realtime_data (ใช้ได้ทั้ง anon และ authenticated)
  try {
    const rpcRes = await supabase.rpc('get_public_school_realtime_data', {
      target_school: schoolId ?? null,
    });
    if (!rpcRes.error && rpcRes.data && (rpcRes.data as RealtimeSchoolPayload).ok) {
      return rpcRes.data as RealtimeSchoolPayload;
    }
  } catch {
    // fallback ด้านล่างหากยังไม่ได้รัน school_web_realtime_public.sql
  }

  if (!schoolId) return null;

  // 2) Fallback ดึงจากตารางจริงโดยตรง (เมื่อล็อกอินอยู่ หรือตารางเปิดให้อ่านได้)
  try {
    const [
      schoolRes,
      yearRes,
      teachersRes,
      rolesRes,
      adminRolesRes,
      clsRes,
      stuRes,
      profRes,
      annRes,
    ] = await Promise.all([
      supabase.from('Schools').select('*').eq('id_school', schoolId).maybeSingle(),
      supabase
        .from('AcademicYears')
        .select('year_be, label, is_current')
        .eq('id_school', schoolId)
        .order('is_current', { ascending: false })
        .order('year_be', { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from('Teachers')
        .select('id_user, fullName, id_role, id_adminrole, is_super_admin, employment_status, profileImage')
        .eq('id_school', schoolId)
        .order('fullName', { ascending: true }),
      supabase.from('roles').select('ID_Roles, Accessrights'),
      supabase.from('adminroles').select('ID_AdminRoles, AdminRolesName').eq('id_school', schoolId),
      supabase
        .from('SchoolWebClassrooms')
        .select('id, grade_level, room_no, name, is_active')
        .eq('id_school', schoolId),
      supabase
        .from('SchoolWebStudents')
        .select('id, prefix, classroom_id, status')
        .eq('id_school', schoolId)
        .eq('status', 'enrolled'),
      supabase
        .from('SchoolWebStudentProfiles')
        .select('student_id, gender, study_plan')
        .eq('id_school', schoolId),
      supabase
        .from('SchoolWebAnnouncements')
        .select('id, title, content, category, is_pinned, published_at')
        .eq('id_school', schoolId)
        .order('is_pinned', { ascending: false })
        .order('published_at', { ascending: false })
        .limit(12),
    ]);

    const roleMap = new Map<number, string>();
    for (const r of (rolesRes.data as { ID_Roles: number; Accessrights: string }[] | null) ?? []) {
      roleMap.set(r.ID_Roles, r.Accessrights);
    }

    const adminRoleMap = new Map<number, string>();
    for (const ar of (adminRolesRes.data as { ID_AdminRoles: number; AdminRolesName: string | null }[] | null) ?? []) {
      if (ar.AdminRolesName) adminRoleMap.set(ar.ID_AdminRoles, ar.AdminRolesName);
    }

    const rawTeachers =
      (teachersRes.data as {
        id_user: number;
        fullName: string | null;
        id_role: number | null;
        id_adminrole?: number | null;
        is_super_admin?: boolean | null;
        employment_status?: string | null;
        profileImage?: string | null;
      }[] | null) ?? [];

    const activeTeachers = rawTeachers.filter(
      (t) =>
        !t.is_super_admin &&
        (!t.employment_status || t.employment_status === 'active'),
    );

    const staffList: RealtimeStaffRow[] = activeTeachers.map((t) => ({
      id_user: t.id_user,
      fullName: t.fullName,
      roleName:
        (t.id_role != null ? roleMap.get(t.id_role) : null) ??
        'ข้าราชการครูและบุคลากร',
      adminRoleName:
        t.id_adminrole != null ? adminRoleMap.get(t.id_adminrole) ?? null : null,
      profileImage: t.profileImage ?? null,
    }));

    const clsList = (
      (clsRes.data as {
        id: number;
        grade_level: string;
        is_active: boolean;
      }[] | null) ?? []
    ).filter((c) => c.is_active !== false);

    const clsGradeById = new Map<number, string>();
    const roomsByGrade = new Map<string, number>();
    for (const c of clsList) {
      clsGradeById.set(c.id, c.grade_level);
      roomsByGrade.set(
        c.grade_level,
        (roomsByGrade.get(c.grade_level) ?? 0) + 1,
      );
    }

    const profByStu = new Map<
      number,
      { gender?: string | null; study_plan?: string | null }
    >();
    for (const p of (profRes.data as {
      student_id: number;
      gender?: string | null;
      study_plan?: string | null;
    }[] | null) ?? []) {
      profByStu.set(p.student_id, p);
    }

    const stuList =
      (stuRes.data as {
        id: number;
        prefix: string | null;
        classroom_id: number | null;
      }[] | null) ?? [];

    const gradeCounter = new Map<string, { male: number; female: number }>();
    const planCounter = new Map<string, number>();

    for (const st of stuList) {
      const gLevel =
        (st.classroom_id ? clsGradeById.get(st.classroom_id) : null) || 'ม.1';
      const prof = profByStu.get(st.id);
      const isFemale =
        prof?.gender === 'หญิง' ||
        (st.prefix ?? '').includes('หญิง') ||
        (st.prefix ?? '').includes('นางสาว');

      const prevG = gradeCounter.get(gLevel) ?? { male: 0, female: 0 };
      if (isFemale) prevG.female += 1;
      else prevG.male += 1;
      gradeCounter.set(gLevel, prevG);

      const planName = prof?.study_plan?.trim() || 'ทั่วไป (มัธยมศึกษา)';
      planCounter.set(planName, (planCounter.get(planName) ?? 0) + 1);
    }

    const gradeStats: PublicGradeStatItem[] = [
      'ม.1',
      'ม.2',
      'ม.3',
      'ม.4',
      'ม.5',
      'ม.6',
    ].map((badge, idx) => {
      const counts = gradeCounter.get(badge) ?? { male: 0, female: 0 };
      return {
        badge,
        title: `ชั้นมัธยมศึกษาปีที่ ${idx + 1}`,
        roomsCount: roomsByGrade.get(badge) ?? 0,
        male: counts.male,
        female: counts.female,
        isSenior: idx >= 3,
      };
    });

    const planStats: PublicStudyPlanItem[] = [...planCounter.entries()].map(
      ([label, count], idx) => ({
        id: `plan-real-${idx + 1}`,
        label,
        countLabel: `${count.toLocaleString('th-TH')} คน`,
      }),
    );

    const yearRow = yearRes.data as { year_be?: number; label?: string } | null;

    return {
      ok: true,
      school: (schoolRes.data as RealtimeSchoolPayload['school']) ?? null,
      academicYearBe: yearRow?.year_be ?? null,
      academicYearLabel: yearRow?.label ?? null,
      staffCount: staffList.length,
      staffList,
      studentCount: stuList.length,
      classroomCount: clsList.length,
      gradeStats,
      planStats,
      announcements:
        (annRes.data as RealtimeAnnouncementRow[] | null) ?? [],
    };
  } catch {
    return null;
  }
}

async function enrichConfigWithRealDatabaseData(
  schoolId: number | null | undefined,
  config: PublicSchoolWebConfig,
  hasSavedCustomRow: boolean,
): Promise<PublicSchoolWebConfig> {
  const payload = await fetchRealtimePayloadForSchool(schoolId);
  if (!payload) return config;

  const d = DEFAULT_PUBLIC_SCHOOL_WEB_CONFIG;
  const next: PublicSchoolWebConfig = JSON.parse(
    JSON.stringify(config),
  ) as PublicSchoolWebConfig;

  // 1) ข้อมูลโรงเรียนจริงจากตาราง Schools
  if (payload.school) {
    const s = payload.school;
    if (
      s.localCode?.trim() &&
      (!hasSavedCustomRow || next.about.smisCode === d.about.smisCode)
    ) {
      next.about.smisCode = s.localCode.trim();
    }

    const composedShortLoc = [
      s.subdistrict?.trim() && `ต.${s.subdistrict.trim().replace(/^ตำบล/, '')}`,
      s.district?.trim() && `อ.${s.district.trim().replace(/^อำเภอ/, '')}`,
      s.province?.trim() && `จ.${s.province.trim().replace(/^จังหวัด/, '')}`,
    ]
      .filter(Boolean)
      .join(' ');

    if (
      composedShortLoc &&
      (!hasSavedCustomRow ||
        next.contact.shortLocation === d.contact.shortLocation)
    ) {
      next.contact.shortLocation = composedShortLoc;
    }

    const realAddr =
      s.address?.trim() ||
      [
        s.subdistrict?.trim() && `ตำบล${s.subdistrict.trim().replace(/^ตำบล/, '')}`,
        s.district?.trim() && `อำเภอ${s.district.trim().replace(/^อำเภอ/, '')}`,
        s.province?.trim() && `จังหวัด${s.province.trim().replace(/^จังหวัด/, '')}`,
      ]
        .filter(Boolean)
        .join(' ');

    if (
      realAddr &&
      (!hasSavedCustomRow || next.contact.address === d.contact.address)
    ) {
      next.contact.address = realAddr;
    }
  }

  // 2) ปีการศึกษาปัจจุบันจริง
  if (payload.academicYearBe) {
    next.staff.academicYearLabel = String(payload.academicYearBe);
  }

  // 3) ข้อมูลบุคลากรและผู้บริหารจริงจากตาราง Teachers + adminroles + roles
  if (
    typeof payload.staffCount === 'number' &&
    payload.staffCount > 0 &&
    Array.isArray(payload.staffList) &&
    payload.staffList.length > 0
  ) {
    next.home.stats.staffCount = payload.staffCount;
    next.staff.totalStaffLabel = `${payload.staffCount.toLocaleString('th-TH')} ท่าน`;

    const realExecs: PublicStaffItem[] = [];
    const realTeachers: PublicStaffItem[] = [];

    for (const raw of payload.staffList) {
      const fullName = (raw.fullName ?? '').trim();
      if (!fullName) continue;
      const adminRole = (raw.adminRoleName ?? '').trim();
      const normalRole = (raw.roleName ?? 'ข้าราชการครูและบุคลากร').trim();
      const effectiveTitle = adminRole || normalRole;

      const isDir =
        effectiveTitle.includes('ผู้อำนวยการ') &&
        !effectiveTitle.includes('รอง');
      const isVp = effectiveTitle.includes('รองผู้อำนวยการ');

      if (isDir || isVp) {
        realExecs.push({
          id: `real-exec-${raw.id_user}`,
          name: fullName,
          role: effectiveTitle,
          dept: 'executive',
          deptBadgeText: isDir
            ? 'ผู้อำนวยการสถานศึกษา'
            : effectiveTitle,
          deptBadgeTone: 'primary',
          imageUrl:
            raw.profileImage?.trim() ||
            (isDir
              ? d.staff.executives[0]?.imageUrl
              : d.staff.executives[1]?.imageUrl) ||
            'https://images.unsplash.com/photo-1643284461591-7fd5fc242ef7?auto=format&fit=crop&w=800&q=80',
          isDirector: isDir,
          isViceDirector: isVp,
          quote: isDir ? d.staff.executives[0]?.quote : undefined,
        });
      } else {
        const classified = classifyTeacherDepartment(effectiveTitle);
        realTeachers.push({
          id: `real-staff-${raw.id_user}`,
          name: fullName,
          role: effectiveTitle,
          dept: classified.dept,
          deptBadgeText: classified.badgeText,
          deptBadgeTone: classified.tone,
          imageUrl:
            raw.profileImage?.trim() ||
            'https://images.unsplash.com/photo-1580894732230-28cef47eb8d3?auto=format&fit=crop&w=800&q=80',
        });
      }
    }

    const isDefaultExecs =
      next.staff.executives.length === d.staff.executives.length &&
      next.staff.executives[0]?.name === d.staff.executives[0]?.name;
    if (realExecs.length > 0 && (!hasSavedCustomRow || isDefaultExecs)) {
      next.staff.executives = realExecs;
    }

    const realDir = realExecs.find((e) => e.isDirector) ?? realExecs[0];
    if (
      realDir &&
      (!hasSavedCustomRow || next.home.director.name === d.home.director.name)
    ) {
      next.home.director.name = realDir.name;
      next.home.director.position = realDir.role;
      if (realDir.imageUrl) {
        next.home.director.imageUrl = realDir.imageUrl;
      }
    }

    const isDefaultTeachers =
      next.staff.teachingStaff.length === d.staff.teachingStaff.length &&
      next.staff.teachingStaff[0]?.name === d.staff.teachingStaff[0]?.name;
    if (
      (realTeachers.length > 0 || realExecs.length > 0) &&
      (!hasSavedCustomRow || isDefaultTeachers)
    ) {
      next.staff.teachingStaff =
        realTeachers.length > 0 ? realTeachers : realExecs;
    }
  }

  // 4) สถิตินักเรียนจริงจากตาราง SchoolWebStudents + SchoolWebClassrooms + SchoolWebStudentProfiles
  if (
    (typeof payload.studentCount === 'number' && payload.studentCount > 0) ||
    (typeof payload.classroomCount === 'number' && payload.classroomCount > 0)
  ) {
    if (payload.studentCount && payload.studentCount > 0) {
      next.home.stats.studentsCount = payload.studentCount;
    }
    const isDefaultGrades =
      next.students.grades.length === d.students.grades.length &&
      next.students.grades[0]?.male === d.students.grades[0]?.male &&
      next.students.grades[0]?.female === d.students.grades[0]?.female;
    if (
      Array.isArray(payload.gradeStats) &&
      payload.gradeStats.length > 0 &&
      (!hasSavedCustomRow || isDefaultGrades)
    ) {
      next.students.grades = payload.gradeStats;
    }
    if (
      Array.isArray(payload.planStats) &&
      payload.planStats.length > 0 &&
      (!hasSavedCustomRow || isDefaultGrades)
    ) {
      next.students.studyPlans = payload.planStats;
    }
  }

  // 5) ข่าวประกาศจริงจากตาราง SchoolWebAnnouncements
  if (Array.isArray(payload.announcements) && payload.announcements.length > 0) {
    const existingIds = new Set(next.news.map((n) => n.id));
    const mappedAnnouncements: PublicNewsItem[] = payload.announcements
      .filter((a) => !existingIds.has(`db-ann-${a.id}`))
      .map((a, idx) => {
        const isAcad = a.category === 'academic';
        const dateStr = a.published_at
          ? new Date(a.published_at).toLocaleDateString('th-TH', {
              day: 'numeric',
              month: 'long',
              year: 'numeric',
            })
          : 'ประกาศล่าสุด';
        return {
          id: `db-ann-${a.id}`,
          cat: isAcad ? 'academic' : 'activity',
          badgeText: isAcad ? 'ข่าววิชาการ' : 'ประกาศโรงเรียน',
          badgeStyle: isAcad ? 'tertiary' : 'primary',
          dateLabel: dateStr,
          title: a.title,
          summary: a.content || a.title,
          imageUrl:
            d.news[idx % d.news.length]?.imageUrl ||
            'https://images.unsplash.com/photo-1650525217641-891e936d3486?auto=format&fit=crop&w=1080&q=80',
          imageAlt: a.title,
          author: isAcad ? 'ฝ่ายวิชาการและกิจการนักเรียน' : 'ฝ่ายบริหารทั่วไป',
          authorRole: 'ประกาศโรงเรียน',
          isFeatured: Boolean(a.is_pinned && idx === 0),
          showOnHome: true,
          homeOrder: idx + 1,
          fullParagraphs: (a.content || a.title)
            .split('\n')
            .map((p) => p.trim())
            .filter(Boolean),
        };
      });

    if (mappedAnnouncements.length > 0) {
      // หากมีประกาศที่ปักหมุดในระบบโรงเรียน ให้ขึ้นเป็นข่าวเด่น
      const hasPinnedDb = mappedAnnouncements.some((m) => m.isFeatured);
      const existingNews = hasPinnedDb
        ? next.news.map((n) => ({ ...n, isFeatured: false }))
        : next.news;
      next.news = [...mappedAnnouncements, ...existingNews];
    }
  }

  return next;
}

export async function savePublicSchoolWebConfig(
  schoolId: number | null | undefined,
  config: PublicSchoolWebConfig,
): Promise<{ savedToDb: boolean }> {
  const normalized = mergeWithDefaultPublicWebConfig(config);
  try {
    window.localStorage.setItem(
      getStorageKey(schoolId),
      JSON.stringify(normalized),
    );
  } catch {
    // ignore localStorage error
  }

  if (!schoolId) {
    return { savedToDb: false };
  }

  try {
    const { error } = await supabase.from('SchoolPublicWebConfigs').upsert(
      {
        id_school: schoolId,
        config_json: normalized,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'id_school' },
    );
    if (!error) {
      return { savedToDb: true };
    }
  } catch {
    // fallback to localStorage when table doesn't exist yet
  }

  return { savedToDb: false };
}

export async function resetPublicSchoolWebConfig(
  schoolId: number | null | undefined,
): Promise<PublicSchoolWebConfig> {
  const fresh = mergeWithDefaultPublicWebConfig(null);
  try {
    window.localStorage.removeItem(getStorageKey(schoolId));
  } catch {
    // ignore
  }
  if (schoolId) {
    try {
      await supabase
        .from('SchoolPublicWebConfigs')
        .delete()
        .eq('id_school', schoolId);
    } catch {
      // ignore
    }
  }
  return fresh;
}

export interface PublicContactSubmission {
  id: string;
  name: string;
  emailOrPhone: string;
  subject: string;
  message: string;
  createdAt: string;
}

const MESSAGES_TABLE = 'SchoolPublicWebMessages';

type MessageRow = {
  id: number;
  name: string;
  email_or_phone: string | null;
  subject: string | null;
  message: string;
  created_at: string;
};

function toSubmission(r: MessageRow): PublicContactSubmission {
  return {
    id: String(r.id),
    name: r.name,
    emailOrPhone: r.email_or_phone ?? '',
    subject: r.subject ?? '',
    message: r.message,
    createdAt: new Date(r.created_at).toLocaleString('th-TH', {
      dateStyle: 'medium',
      timeStyle: 'short',
    }),
  };
}

/** อ่านกล่องข้อความ (เฉพาะผู้มีสิทธิ์ตั้งค่าเว็บสาธารณะ — RLS กันไว้) */
export async function loadPublicContactSubmissions(
  schoolId: number | null | undefined,
): Promise<PublicContactSubmission[]> {
  if (schoolId == null) return [];
  const { data, error } = await supabase
    .from(MESSAGES_TABLE)
    .select('id, name, email_or_phone, subject, message, created_at')
    .eq('id_school', schoolId)
    .order('created_at', { ascending: false })
    .limit(200);
  if (error || !data) return [];
  return (data as MessageRow[]).map(toSubmission);
}

/** คนนอกส่งข้อความถึงโรงเรียน (ส่งได้อย่างเดียว อ่านไม่ได้) */
export async function submitPublicContactMessage(
  schoolId: number | null | undefined,
  payload: Omit<PublicContactSubmission, 'id' | 'createdAt'>,
): Promise<void> {
  if (schoolId == null) throw new Error('ไม่พบโรงเรียนปลายทาง');
  const { error } = await supabase.from(MESSAGES_TABLE).insert({
    id_school: schoolId,
    name: payload.name.trim().slice(0, 200),
    email_or_phone: payload.emailOrPhone.trim().slice(0, 200) || null,
    subject: payload.subject.slice(0, 200) || null,
    message: payload.message.trim().slice(0, 5000),
  });
  if (error) throw error;
}

export async function deletePublicContactSubmission(
  schoolId: number | null | undefined,
  messageId: string,
): Promise<PublicContactSubmission[]> {
  await supabase.from(MESSAGES_TABLE).delete().eq('id', Number(messageId));
  return loadPublicContactSubmissions(schoolId);
}
