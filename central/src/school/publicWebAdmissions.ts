import { supabase } from '../supabase';

export type AdmissionGradeLevel = 'm1' | 'm4';

export type AdmissionStatus =
  | 'pending'
  | 'verified'
  | 'needs_fix'
  | 'passed'
  | 'enrolled'
  | 'rejected';

export interface AdmissionProgramItem {
  id: string;
  grade: AdmissionGradeLevel;
  title: string;
  shortTitle: string;
  description: string;
  quotaLabel: string;
  icon: string;
  iconTone: 'primary' | 'tertiary';
  ribbon?: string;
  gpaxLabel: string;
  gpaxValue: string;
  examSubjects: string;
  feeLabel: string;
  feeValue: string;
  feeHighlight?: boolean;
  extraLabel?: string;
  extraValue?: string;
  openRangeLabel: string;
}

export interface AdmissionTimelineStep {
  step: number;
  badge: string;
  title: string;
  dateLabel: string;
  description: string;
  isCurrent?: boolean;
}

export interface AdmissionProcessStep {
  num: string;
  title: string;
  description: string;
}

export interface AdmissionRequiredDoc {
  id: string;
  title: string;
  description: string;
}

export interface AdmissionDownloadItem {
  id: string;
  title: string;
  meta: string;
  icon: string;
  iconTone: 'error' | 'primary' | 'neutral';
  url: string;
}

export interface AdmissionFaqItem {
  id: string;
  question: string;
  answer: string;
}

export interface PublicAdmissionConfig {
  enabled: boolean;
  academicYear: string;
  codePrefix: string;
  statusBadge: string;
  openPeriodBadge: string;
  heroTitlePrefix: string;
  heroTitleGradeSuffix: string;
  heroDescription: string;
  heroImageUrl: string;
  heroRoundBadge: string;
  heroCardTitle: string;
  heroCardSubtitle: string;
  m1QuickInfoLabel: string;
  m1QuickInfoQuota: string;
  m4QuickInfoLabel: string;
  m4QuickInfoQuota: string;
  defaultExamDateLabel: string;
  programsM1: AdmissionProgramItem[];
  programsM4: AdmissionProgramItem[];
  timeline: AdmissionTimelineStep[];
  processSteps: AdmissionProcessStep[];
  requiredDocs: AdmissionRequiredDoc[];
  downloads: AdmissionDownloadItem[];
  faqs: AdmissionFaqItem[];
  helpdeskPhone: string;
  helpdeskLine: string;
  helpdeskAddress: string;
  helpdeskHours: string;
  helpdeskAgency: string;
}

export interface AdmissionStats {
  m1Count: number;
  m4Count: number;
  totalCount: number;
}

export interface AdmissionRecord {
  id: number;
  id_school: number;
  application_code: string;
  academic_year: string;
  grade_level: AdmissionGradeLevel;
  program_id: string;
  program_label: string;
  national_id: string;
  prefix: string;
  full_name: string;
  birth_date: string | null;
  previous_school: string;
  gpax: number | null;
  parent_name: string;
  parent_relation: string;
  parent_phone: string;
  doc_transcript_name: string | null;
  doc_photo_name: string | null;
  doc_house_reg_name: string | null;
  doc_transcript_data: string | null;
  doc_photo_data: string | null;
  doc_house_reg_data: string | null;
  status: AdmissionStatus;
  status_note: string | null;
  exam_seat_no: string | null;
  exam_room: string | null;
  exam_date_label: string | null;
  created_at: string;
  updated_at: string;
}

export interface PublicAdmissionStatusResult {
  id: number;
  application_code: string;
  academic_year: string;
  grade_level: AdmissionGradeLevel;
  program_id: string;
  program_label: string;
  prefix: string;
  full_name: string;
  previous_school: string;
  gpax: number | null;
  status: AdmissionStatus;
  status_note: string | null;
  exam_seat_no: string | null;
  exam_room: string | null;
  exam_date_label: string | null;
  doc_photo_data: string | null;
  created_at: string;
}

export const ADMISSION_STATUS_META: Record<
  AdmissionStatus,
  {
    label: string;
    badgeClass: string;
    icon: string;
    canPrintAdmitCard: boolean;
  }
> = {
  pending: {
    label: 'รอตรวจสอบเอกสาร',
    badgeClass: 'bg-amber-100 text-amber-800',
    icon: 'hourglass_top',
    canPrintAdmitCard: false,
  },
  verified: {
    label: 'เอกสารสมบูรณ์ (มีสิทธิ์สอบ)',
    badgeClass: 'bg-emerald-100 text-emerald-800',
    icon: 'verified',
    canPrintAdmitCard: true,
  },
  needs_fix: {
    label: 'ขอเอกสารเพิ่มเติม',
    badgeClass: 'bg-orange-100 text-orange-800',
    icon: 'warning',
    canPrintAdmitCard: false,
  },
  passed: {
    label: 'ผ่านการคัดเลือก',
    badgeClass: 'bg-sky-100 text-sky-800',
    icon: 'workspace_premium',
    canPrintAdmitCard: true,
  },
  enrolled: {
    label: 'รายงานตัวและมอบตัวแล้ว',
    badgeClass: 'bg-indigo-100 text-indigo-800',
    icon: 'how_to_reg',
    canPrintAdmitCard: true,
  },
  rejected: {
    label: 'ไม่ผ่านการคัดเลือก',
    badgeClass: 'bg-rose-100 text-rose-800',
    icon: 'cancel',
    canPrintAdmitCard: false,
  },
};

export const DEFAULT_PUBLIC_ADMISSION_CONFIG: PublicAdmissionConfig = {
  enabled: true,
  academicYear: '2568',
  codePrefix: 'RBP',
  statusBadge: 'ระบบรับสมัครนักเรียนใหม่ออนไลน์',
  openPeriodBadge: 'เปิดรับสมัครวันนี้ – 25 พฤษภาคม 2568',
  heroTitlePrefix: 'รับสมัครนักเรียนใหม่',
  heroTitleGradeSuffix: '(ม.1 และ ม.4)',
  heroDescription:
    'เปิดประตูสู่อนาคตทางการศึกษาที่เปี่ยมคุณภาพ มุ่งมั่นสร้างเยาวชนที่มีคุณธรรม ความรู้ล้ำเลิศ และทักษะชีวิตพร้อมก้าวสู่ศตวรรษที่ 21',
  heroImageUrl:
    'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&w=1200&q=80',
  heroRoundBadge: 'รอบทั่วไป ประจำปี 2568',
  heroCardTitle: 'ร่วมเป็นส่วนหนึ่งของครอบครัวโรงเรียนเรา',
  heroCardSubtitle: 'วิชาการเด่น เน้นคุณธรรม นำเทคโนโลยี',
  m1QuickInfoLabel: 'รับผู้จบ ป.6 เข้า ม.1',
  m1QuickInfoQuota: '4 ห้องเรียน (160 คน)',
  m4QuickInfoLabel: 'รับผู้จบ ม.3 เข้า ม.4',
  m4QuickInfoQuota: '4 แผนการเรียน (200 คน)',
  defaultExamDateLabel: '30 พ.ค. 2568 เวลา 08.30 - 15.30 น.',
  programsM1: [
    {
      id: 'm1-normal',
      grade: 'm1',
      title: 'ห้องเรียนทั่วไป (Normal Program)',
      shortTitle: 'ห้องเรียนทั่วไป (ม.1)',
      description:
        'เน้นการเรียนรู้ตามหลักสูตรแกนกลาง เสริมทักษะการคิดวิเคราะห์ ความคิดสร้างสรรค์ กีฬา ดนตรี และเทคโนโลยีดิจิทัลขั้นพื้นฐาน',
      quotaLabel: 'รับ 120 คน',
      icon: 'menu_book',
      iconTone: 'tertiary',
      gpaxLabel: 'คุณสมบัติ/เกณฑ์ GPAX',
      gpaxValue: 'จบ ป.6 หรือเทียบเท่า GPAX ≥ 2.00',
      examSubjects: 'ไทย, คณิต, วิทย์, อังกฤษ, สังคม',
      feeLabel: 'ค่าบำรุงการศึกษา',
      feeValue: 'ไม่มีค่าใช้จ่ายเพิ่มเติม (ตามนโยบายรัฐ)',
      feeHighlight: true,
      openRangeLabel: 'เปิดรับสมัคร: 1-25 พ.ค. 68',
    },
    {
      id: 'm1-special',
      grade: 'm1',
      title: 'ห้องเรียนพิเศษวิทยาศาสตร์-คณิตศาสตร์ (GSM)',
      shortTitle: 'ห้องเรียนพิเศษ GSM (ม.1)',
      description:
        'หลักสูตรเข้มข้น มุ่งเน้นการทดลอง โครงงานวิทยาศาสตร์ และการเขียนโปรแกรมคอมพิวเตอร์ มีอาจารย์พิเศษร่วมติวเข้มและทัศนศึกษาดูงาน',
      quotaLabel: 'รับ 40 คน',
      icon: 'biotech',
      iconTone: 'primary',
      ribbon: 'ห้องเรียนเน้นความเป็นเลิศ',
      gpaxLabel: 'คุณสมบัติ/เกณฑ์ GPAX',
      gpaxValue: 'GPAX รวม ≥ 3.00, วิทย์-คณิต ≥ 3.00',
      examSubjects: 'คณิตศาสตร์ประยุกต์, วิทยาศาสตร์ทดลอง, อังกฤษ',
      feeLabel: 'ค่าสนับสนุนโครงการ',
      feeValue: 'ตามมติคณะกรรมการสถานศึกษา',
      openRangeLabel: 'เปิดรับสมัคร: 1-25 พ.ค. 68',
    },
  ],
  programsM4: [
    {
      id: 'm4-scimath',
      grade: 'm4',
      title: 'แผนการเรียนวิทยาศาสตร์-คณิตศาสตร์ (วิทย์-คณิต)',
      shortTitle: 'วิทย์-คณิต (ม.4)',
      description:
        'มุ่งเน้นพื้นฐานวิชาการทางวิทยาศาสตร์ คณิตศาสตร์ และเทคโนโลยีขั้นสูง เพื่อเตรียมความพร้อมศึกษาต่อคณะสายวิทยาศาสตร์สุขภาพ แพทยศาสตร์ วิศวกรรมศาสตร์',
      quotaLabel: 'รับ 80 คน',
      icon: 'science',
      iconTone: 'primary',
      gpaxLabel: 'เกณฑ์ GPAX',
      gpaxValue: 'GPAX รวม ≥ 2.75, วิทย์-คณิต GPA ≥ 2.75',
      examSubjects: 'คณิตศาสตร์, วิทยาศาสตร์, ภาษาอังกฤษ',
      feeLabel: 'ค่าบำรุงการศึกษา',
      feeValue: 'ตามระเบียบสถานศึกษา',
      feeHighlight: true,
      openRangeLabel: 'เปิดรับสมัคร: 1-25 พ.ค. 68',
    },
    {
      id: 'm4-artsmath',
      grade: 'm4',
      title: 'แผนการเรียนศิลป์-คำนวณ',
      shortTitle: 'ศิลป์-คำนวณ (ม.4)',
      description:
        'พัฒนาทักษะคณิตศาสตร์ประยุกต์ ภาษาอังกฤษเพื่อการสื่อสาร และพื้นฐานเศรษฐศาสตร์ ก้าวสู่คณะบริหารธุรกิจ บัญชี เศรษฐศาสตร์ สารสนเทศ และนิเทศศาสตร์',
      quotaLabel: 'รับ 40 คน',
      icon: 'calculate',
      iconTone: 'tertiary',
      gpaxLabel: 'เกณฑ์ GPAX',
      gpaxValue: 'GPAX รวม ≥ 2.50, คณิตศาสตร์ GPA ≥ 2.50',
      examSubjects: 'คณิตศาสตร์, ภาษาไทย, ภาษาอังกฤษ, สังคมฯ',
      feeLabel: 'ค่าบำรุงการศึกษา',
      feeValue: 'ตามระเบียบสถานศึกษา',
      feeHighlight: true,
      openRangeLabel: 'เปิดรับสมัคร: 1-25 พ.ค. 68',
    },
    {
      id: 'm4-artslang',
      grade: 'm4',
      title: 'แผนการเรียนศิลป์-ภาษา (Language-Arts Program)',
      shortTitle: 'แผนการเรียนศิลป์-ภาษา (ม.4)',
      description:
        'เน้นการสื่อสารภาษาต่างประเทศรอบด้าน เตรียมความพร้อมสู่สายมนุษยศาสตร์ อักษรศาสตร์ ศิลปศาสตร์ นิติศาสตร์ และการท่องเที่ยวบริการ',
      quotaLabel: 'รับ 40 คน',
      icon: 'translate',
      iconTone: 'primary',
      gpaxLabel: 'คุณสมบัติ/เกณฑ์ GPAX',
      gpaxValue: 'จบ ม.3, GPAX รวม ≥ 2.00, ไทย-ภาษา GPA ≥ 2.50',
      examSubjects: 'ภาษาไทย, ภาษาอังกฤษ, สังคมศึกษา',
      feeLabel: 'ค่าบำรุงการศึกษา',
      feeValue: 'ไม่มีค่าใช้จ่ายเพิ่มเติม (ตามนโยบายรัฐ)',
      feeHighlight: true,
      openRangeLabel: 'เปิดรับสมัคร: 1-25 พ.ค. 68',
    },
    {
      id: 'm4-voca',
      grade: 'm4',
      title: 'แผนการเรียนทวิศึกษา (Dual Education)',
      shortTitle: 'แผนการเรียนทวิศึกษา (วิชาชีพร่วม ปวช.) (ม.4)',
      description:
        'จัดการศึกษาเรียนควบคู่สามัญและอาชีพ ได้รับ 2 วุฒิการศึกษา (ม.6 + ปวช.) ร่วมกับสถาบันอาชีวศึกษา ฝึกปฏิบัติจริงพร้อมทำงานทันที',
      quotaLabel: 'รับ 40 คน',
      icon: 'handyman',
      iconTone: 'tertiary',
      ribbon: 'เรียน ม.ปลาย ควบ ปวช. จบมีงานทำ',
      gpaxLabel: 'คุณสมบัติ/เกณฑ์',
      gpaxValue: 'จบ ม.3 GPAX ≥ 2.00 มีใจรักงานวิชาชีพ',
      examSubjects: 'สอบสัมภาษณ์และประเมินความถนัดทางวิชาชีพ',
      extraLabel: 'วุฒิที่ได้รับ',
      extraValue: '2 วุฒิ (ม.6 + ปวช. เทคนิค/อาชีวะ)',
      feeLabel: 'ค่าบำรุงการศึกษา',
      feeValue: 'ตามโครงการเรียนฟรี 15 ปี',
      feeHighlight: true,
      openRangeLabel: 'เปิดรับสมัคร: 1-25 พ.ค. 68',
    },
  ],
  timeline: [
    {
      step: 1,
      badge: 'กำลังดำเนินการ',
      title: 'รับสมัครออนไลน์',
      dateLabel: '1 – 25 พ.ค. 2568',
      description: 'กรอกข้อมูลและอัปโหลดเอกสารผ่านเว็บไซต์ตลอด 24 ชั่วโมง',
      isCurrent: true,
    },
    {
      step: 2,
      badge: 'เร็วๆ นี้',
      title: 'ประกาศรายชื่อสอบ',
      dateLabel: '27 พ.ค. 2568',
      description: 'ประกาศรายชื่อผู้มีสิทธิ์สอบคัดเลือกและห้องสอบผ่านเว็บไซต์',
    },
    {
      step: 3,
      badge: 'สอบวัดความรู้',
      title: 'สอบคัดเลือก',
      dateLabel: '30 พ.ค. 2568',
      description: 'ณ อาคารเรียน 1 และ 2 เวลา 08.30 - 15.30 น.',
    },
    {
      step: 4,
      badge: 'ผลการสอบ',
      title: 'ประกาศผลคัดเลือก',
      dateLabel: '2 มิ.ย. 2568',
      description: 'ประกาศผลทางออนไลน์ และป้ายประกาศหน้าเสาธงโรงเรียน',
    },
    {
      step: 5,
      badge: 'เข้าศึกษา',
      title: 'รายงานตัว & มอบตัว',
      dateLabel: '5 มิ.ย. 2568',
      description: 'ผู้ปกครองพานักเรียนมารายงานตัวพร้อมเอกสารตัวจริง ณ หอประชุมโรงเรียน',
    },
  ],
  processSteps: [
    {
      num: '01',
      title: 'ตรวจคุณสมบัติ & ระเบียบการ',
      description:
        'อ่านคุณสมบัติเฉพาะของแต่ละแผนการเรียนอย่างถี่ถ้วน และดาวน์โหลดระเบียบการศึกษาของโรงเรียน',
    },
    {
      num: '02',
      title: 'กรอกข้อมูล & เลือกแผน',
      description:
        'ระบุเลขบัตร ปชช., ชื่อ-สกุล, ที่อยู่, เบอร์โทรผู้ปกครอง และเลือกแผนการเรียนลำดับที่ต้องการ',
    },
    {
      num: '03',
      title: 'แนบไฟล์เอกสารหลักฐาน',
      description:
        'ถ่ายรูปหรือแนบไฟล์ ปพ.1, สำเนาทะเบียนบ้าน และรูปถ่ายชุดนักเรียนขนาด 1.5 นิ้วให้คมชัด',
    },
    {
      num: '04',
      title: 'พิมพ์บัตรประจำตัวสอบ',
      description:
        'รอเจ้าหน้าที่ตรวจสอบเอกสาร (1-2 วันทำการ) แล้วพิมพ์บัตรประจำตัวสอบเพื่อนำมาในวันสอบ',
    },
  ],
  requiredDocs: [
    {
      id: 'doc-1',
      title: 'ใบระเบียนแสดงผลการเรียน (ปพ.1)',
      description:
        'ฉบับจริงพร้อมสำเนา 1 ฉบับ (แสดงผลการเรียนตามเกณฑ์แต่ละแผนการเรียน)',
    },
    {
      id: 'doc-2',
      title: 'สำเนาทะเบียนบ้าน',
      description:
        'สำเนาของนักเรียน, บิดา, มารดา หรือผู้ปกครอง อย่างละ 1 ฉบับ (พร้อมลงนามสำเนาถูกต้อง)',
    },
    {
      id: 'doc-3',
      title: 'รูปถ่ายหน้าตรงขนาด 1.5 นิ้ว (จำนวน 3 รูป)',
      description:
        'สวมเครื่องแบบนักเรียนเดิม ไม่สวมหมวกและแว่นตาดำ ถ่ายไว้ไม่เกิน 6 เดือน',
    },
    {
      id: 'doc-4',
      title: 'บัตรประจำตัวสอบพิมพ์จากระบบ',
      description:
        'พิมพ์เอกสารบัตรประจำตัวสอบสีหรือขาวดำจากระบบรับสมัครออนไลน์',
    },
  ],
  downloads: [
    {
      id: 'dl-1',
      title: 'ประกาศระเบียบการรับสมัครนักเรียนใหม่ ปีการศึกษา 2568 (ฉบับเต็ม)',
      meta: 'PDF • 2.4 MB • ปรับปรุงล่าสุด 1 พ.ค. 2568',
      icon: 'picture_as_pdf',
      iconTone: 'error',
      url: '',
    },
    {
      id: 'dl-2',
      title: 'แบบฟอร์มใบรับรองความประพฤติจากสถานศึกษาเดิม',
      meta: 'PDF • 540 KB • สำหรับผู้สมัคร ม.1 และ ม.4',
      icon: 'description',
      iconTone: 'primary',
      url: '',
    },
    {
      id: 'dl-3',
      title: 'คู่มือการใช้งานระบบรับสมัครออนไลน์สำหรับผู้ปกครอง',
      meta: 'PDF • 1.8 MB • พร้อมภาพประกอบทีละขั้นตอน',
      icon: 'menu_book',
      iconTone: 'neutral',
      url: '',
    },
  ],
  faqs: [
    {
      id: 'faq-1',
      question: 'หากแนบเอกสารไม่ครบในระบบ สามารถส่งย้อนหลังได้หรือไม่?',
      answer:
        'สามารถส่งย้อนหลังได้ โดยเข้าสู่ระบบด้วยเลขบัตรประจำตัวประชาชนเพื่ออัปโหลดเพิ่มเติม หรือนำเอกสารฉบับจริงมาส่งในวันสอบคัดเลือก ณ ห้องทะเบียน',
    },
    {
      id: 'faq-2',
      question: 'สามารถสมัครทั้งห้องเรียนทั่วไปและห้องเรียนพิเศษพร้อมกันได้ไหม?',
      answer:
        'ผู้สมัครสามารถเลือกลำดับสำรองได้ในขั้นตอนการกรอกใบสมัคร โดยหากไม่ผ่านการคัดเลือกในแผนห้องเรียนพิเศษ จะถูกนำรายชื่อเข้าพิจารณาในแผนห้องเรียนทั่วไปตามลำดับคะแนน',
    },
    {
      id: 'faq-3',
      question: 'กรณีผู้ปกครองไม่สะดวกสมัครออนไลน์ สามารถมาสมัครที่โรงเรียนได้หรือไม่?',
      answer:
        'ทางโรงเรียนมีบริการจุดอำนวยความสะดวกการสมัครออนไลน์ (One Stop Service) ณ อาคาร 1 ชั้นล่าง พร้อมครูและพี่เลี้ยงคอยให้คำแนะนำ ระหว่างเวลา 08.30 – 16.00 น. ทุกวันทำการ',
    },
  ],
  helpdeskPhone: '044-611-xxx ต่อ 102',
  helpdeskLine: '@romburipit-admission',
  helpdeskAddress: 'ต.รมย์บุรี อ.บ้านด่าน จ.บุรีรัมย์ 31000',
  helpdeskHours: 'เวลาทำการ: จันทร์ - ศุกร์ 08:30 - 16:30 น.',
  helpdeskAgency: 'สพม.บุรีรัมย์',
};

export function mergePublicAdmissionConfig(
  partial: Partial<PublicAdmissionConfig> | null | undefined,
): PublicAdmissionConfig {
  const d = DEFAULT_PUBLIC_ADMISSION_CONFIG;
  if (!partial || typeof partial !== 'object') {
    return JSON.parse(JSON.stringify(d)) as PublicAdmissionConfig;
  }
  return {
    ...d,
    ...partial,
    programsM1: Array.isArray(partial.programsM1)
      ? partial.programsM1
      : d.programsM1,
    programsM4: Array.isArray(partial.programsM4)
      ? partial.programsM4
      : d.programsM4,
    timeline: Array.isArray(partial.timeline) ? partial.timeline : d.timeline,
    processSteps: Array.isArray(partial.processSteps)
      ? partial.processSteps
      : d.processSteps,
    requiredDocs: Array.isArray(partial.requiredDocs)
      ? partial.requiredDocs
      : d.requiredDocs,
    downloads: Array.isArray(partial.downloads)
      ? partial.downloads
      : d.downloads,
    faqs: Array.isArray(partial.faqs) ? partial.faqs : d.faqs,
  };
}

// ---------------------------------------------------------------------------
// LocalStorage fallback helpers (ทำงานได้ทันทีแม้ยังไม่ได้รัน SQL)
// ---------------------------------------------------------------------------
const LOCAL_ADMISSIONS_PREFIX = 'public_web_admissions_v1_';

function getLocalAdmissionsKey(schoolId: number | null | undefined): string {
  return `${LOCAL_ADMISSIONS_PREFIX}${schoolId ?? 'default'}`;
}

function loadLocalAdmissions(
  schoolId: number | null | undefined,
): AdmissionRecord[] {
  // ไม่เก็บข้อมูลผู้สมัคร (เลขบัตร / รูป / เอกสาร) ในเบราว์เซอร์ — ล้างของเก่าทิ้ง
  try {
    window.localStorage.removeItem(getLocalAdmissionsKey(schoolId));
  } catch {
    // ignore
  }
  return [];
}

function saveLocalAdmissions(
  schoolId: number | null | undefined,
  _rows: AdmissionRecord[],
) {
  loadLocalAdmissions(schoolId);
}

export async function fetchPublicAdmissionStats(
  schoolId: number | null | undefined,
): Promise<AdmissionStats> {
  const localRows = loadLocalAdmissions(schoolId);
  const localStats: AdmissionStats = {
    m1Count: localRows.filter((r) => r.grade_level === 'm1').length,
    m4Count: localRows.filter((r) => r.grade_level === 'm4').length,
    totalCount: localRows.length,
  };

  if (!schoolId) return localStats;

  try {
    const { data, error } = await supabase.rpc('get_public_admission_stats', {
      target_school: schoolId,
    });
    if (!error && data && typeof data === 'object') {
      const obj = data as {
        m1_count?: number;
        m4_count?: number;
        total_count?: number;
      };
      return {
        m1Count: Number(obj.m1_count ?? 0),
        m4Count: Number(obj.m4_count ?? 0),
        totalCount: Number(obj.total_count ?? 0),
      };
    }
  } catch {
    // fallback
  }

  return localStats;
}

export interface SubmitAdmissionInput {
  codePrefix: string;
  academicYear: string;
  gradeLevel: AdmissionGradeLevel;
  programId: string;
  programLabel: string;
  nationalId: string;
  prefix: string;
  fullName: string;
  birthDate: string;
  previousSchool: string;
  gpax: number | null;
  parentName: string;
  parentRelation: string;
  parentPhone: string;
  docTranscriptName?: string | null;
  docPhotoName?: string | null;
  docHouseRegName?: string | null;
  docTranscriptData?: string | null;
  docPhotoData?: string | null;
  docHouseRegData?: string | null;
}

export async function submitPublicAdmissionApplication(
  schoolId: number | null | undefined,
  input: SubmitAdmissionInput,
): Promise<{
  ok: boolean;
  applicationCode?: string;
  savedToDb?: boolean;
  error?: string;
}> {
  const cleanNid = input.nationalId.replace(/\D/g, '');
  if (cleanNid.length !== 13) {
    return {
      ok: false,
      error: 'กรุณากรอกเลขประจำตัวประชาชนให้ครบ 13 หลัก',
    };
  }
  if (!input.fullName.trim()) {
    return { ok: false, error: 'กรุณาระบุชื่อ-นามสกุลผู้สมัคร' };
  }

  if (schoolId) {
    try {
      const { data, error } = await supabase.rpc('submit_public_admission', {
        p_school_id: schoolId,
        p_code_prefix: input.codePrefix || 'ADM',
        p_academic_year: input.academicYear || '2568',
        p_grade_level: input.gradeLevel,
        p_program_id: input.programId,
        p_program_label: input.programLabel,
        p_national_id: cleanNid,
        p_prefix: input.prefix,
        p_full_name: input.fullName.trim(),
        p_birth_date: input.birthDate || null,
        p_previous_school: input.previousSchool.trim(),
        p_gpax: input.gpax,
        p_parent_name: input.parentName.trim(),
        p_parent_relation: input.parentRelation,
        p_parent_phone: input.parentPhone.trim(),
        p_doc_transcript_name: input.docTranscriptName ?? null,
        p_doc_photo_name: input.docPhotoName ?? null,
        p_doc_house_reg_name: input.docHouseRegName ?? null,
        p_doc_transcript_data: input.docTranscriptData ?? null,
        p_doc_photo_data: input.docPhotoData ?? null,
        p_doc_house_reg_data: input.docHouseRegData ?? null,
      });

      if (!error && data && typeof data === 'object') {
        const res = data as {
          ok?: boolean;
          application_code?: string;
          error?: string;
        };
        if (res.ok && res.application_code) {
          return {
            ok: true,
            applicationCode: res.application_code,
            savedToDb: true,
          };
        }
        if (res.error) {
          return { ok: false, error: res.error };
        }
      }
    } catch {
      // fallback to localStorage
    }
  }

  return { ok: false, error: 'ระบบรับสมัครยังไม่พร้อมใช้งาน กรุณาติดต่อโรงเรียน' };
}

export async function checkPublicAdmissionStatus(
  schoolId: number | null | undefined,
  applicationCode: string,
  nationalId: string,
): Promise<{
  found: boolean;
  application?: PublicAdmissionStatusResult;
  error?: string;
}> {
  const q = applicationCode.trim();
  const nid = nationalId.replace(/D/g, '');
  if (!q || nid.length !== 13) {
    return {
      found: false,
      error: 'กรุณากรอกเลขที่ใบสมัคร และเลขประจำตัวประชาชน 13 หลัก',
    };
  }

  if (schoolId) {
    try {
      const { data, error } = await supabase.rpc(
        'check_public_admission_status',
        {
          target_school: schoolId,
          p_application_code: q,
          p_national_id: nid,
        },
      );
      if (!error && data && typeof data === 'object') {
        const res = data as {
          found?: boolean;
          application?: PublicAdmissionStatusResult;
          error?: string;
        };
        if (res.found && res.application) {
          return { found: true, application: res.application };
        }
        if (res.found === false) {
          return {
            found: false,
            error: res.error || 'ไม่พบข้อมูลการสมัครที่ตรงกับเลขที่ระบุ',
          };
        }
      }
    } catch {
      // fallback
    }
  }

  const localMatch = findLocalAdmission(schoolId, q);
  if (localMatch) {
    return { found: true, application: localMatch };
  }
  return {
    found: false,
    error: 'ไม่พบข้อมูลการสมัครที่ตรงกับเลขที่ระบุ',
  };
}

function findLocalAdmission(
  schoolId: number | null | undefined,
  q: string,
): PublicAdmissionStatusResult | null {
  const digits = q.replace(/\D/g, '');
  const upper = q.toUpperCase();
  const rows = loadLocalAdmissions(schoolId);
  const found = rows.find(
    (r) =>
      r.application_code.toUpperCase() === upper ||
      (digits.length === 13 && r.national_id === digits),
  );
  if (!found) return null;
  return {
    id: found.id,
    application_code: found.application_code,
    academic_year: found.academic_year,
    grade_level: found.grade_level,
    program_id: found.program_id,
    program_label: found.program_label,
    prefix: found.prefix,
    full_name: found.full_name,
    previous_school: found.previous_school,
    gpax: found.gpax,
    status: found.status,
    status_note: found.status_note,
    exam_seat_no: found.exam_seat_no,
    exam_room: found.exam_room,
    exam_date_label: found.exam_date_label,
    doc_photo_data: found.doc_photo_data,
    created_at: found.created_at,
  };
}

// ---------------------------------------------------------------------------
// Admin / Settings Page CRUD (SchoolPublicWebAdmissions)
// ---------------------------------------------------------------------------
export async function fetchSchoolAdmissions(
  schoolId: number | null | undefined,
): Promise<{ rows: AdmissionRecord[]; fromDb: boolean }> {
  const localRows = loadLocalAdmissions(schoolId);
  if (!schoolId) return { rows: localRows, fromDb: false };

  try {
    const { data, error } = await supabase
      .from('SchoolPublicWebAdmissions')
      .select('*')
      .eq('id_school', schoolId)
      .order('created_at', { ascending: false });

    if (!error && Array.isArray(data)) {
      return { rows: data as AdmissionRecord[], fromDb: true };
    }
  } catch {
    // fallback
  }
  return { rows: localRows, fromDb: false };
}

export async function updateSchoolAdmission(
  schoolId: number | null | undefined,
  id: number,
  patch: {
    status?: AdmissionStatus;
    status_note?: string | null;
    exam_seat_no?: string | null;
    exam_room?: string | null;
    exam_date_label?: string | null;
  },
): Promise<{ ok: boolean; error?: string }> {
  const nowIso = new Date().toISOString();
  if (schoolId) {
    try {
      const { error } = await supabase
        .from('SchoolPublicWebAdmissions')
        .update({ ...patch, updated_at: nowIso })
        .eq('id', id)
        .eq('id_school', schoolId);
      if (!error) return { ok: true };
    } catch {
      // fallback
    }
  }

  const localRows = loadLocalAdmissions(schoolId);
  const idx = localRows.findIndex((r) => r.id === id);
  if (idx >= 0) {
    localRows[idx] = { ...localRows[idx], ...patch, updated_at: nowIso };
    saveLocalAdmissions(schoolId, localRows);
    return { ok: true };
  }
  return { ok: false, error: 'ไม่สามารถอัปเดตข้อมูลใบสมัครได้ (กรุณารันไฟล์ SQL ก่อน)' };
}

export async function deleteSchoolAdmission(
  schoolId: number | null | undefined,
  id: number,
): Promise<{ ok: boolean; error?: string }> {
  if (schoolId) {
    try {
      const { error } = await supabase
        .from('SchoolPublicWebAdmissions')
        .delete()
        .eq('id', id)
        .eq('id_school', schoolId);
      if (!error) return { ok: true };
    } catch {
      // fallback
    }
  }

  const localRows = loadLocalAdmissions(schoolId).filter((r) => r.id !== id);
  saveLocalAdmissions(schoolId, localRows);
  return { ok: true };
}

/** อัปเดตใบสมัครหลายรายการพร้อมกัน (เช่น อนุมัติเอกสารแบบกลุ่ม หรือรันเลขที่นั่งสอบอัตโนมัติ) */
export async function bulkUpdateSchoolAdmissions(
  schoolId: number | null | undefined,
  updates: {
    id: number;
    status?: AdmissionStatus;
    status_note?: string | null;
    exam_seat_no?: string | null;
    exam_room?: string | null;
    exam_date_label?: string | null;
  }[],
): Promise<{ ok: boolean; updatedCount: number; error?: string }> {
  if (updates.length === 0) return { ok: true, updatedCount: 0 };
  let updatedCount = 0;
  for (const item of updates) {
    const { id, ...patch } = item;
    const res = await updateSchoolAdmission(schoolId, id, patch);
    if (res.ok) updatedCount += 1;
  }
  return {
    ok: updatedCount > 0,
    updatedCount,
    error:
      updatedCount === 0
        ? 'ไม่สามารถอัปเดตใบสมัครแบบกลุ่มได้'
        : undefined,
  };
}

/** ดึงตัวเลขโควตาจากข้อความ เช่น "รับ 120 คน" → 120 */
export function parseQuotaNumber(quotaLabel: string | null | undefined): number {
  const m = String(quotaLabel ?? '').match(/(\d+)/);
  return m ? Number(m[1]) : 0;
}

/** แปลงไฟล์ภาพ/PDF ขนาดไม่เกิน limitBytes เป็น Data URL (ถ้าเกินเก็บเฉพาะชื่อไฟล์) */
export function readOptionalFileDataUrl(
  file: File,
  maxBytes = 400_000,
): Promise<string | null> {
  return new Promise((resolve) => {
    if (file.size > maxBytes) {
      resolve(null);
      return;
    }
    const reader = new FileReader();
    reader.onload = () =>
      resolve(typeof reader.result === 'string' ? reader.result : null);
    reader.onerror = () => resolve(null);
    reader.readAsDataURL(file);
  });
}
