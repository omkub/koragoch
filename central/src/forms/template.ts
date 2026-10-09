/**
 * แม่แบบฟอร์ม (ใบลา / ใบขออนุญาตไปราชการ)
 *
 * แม่แบบ = ตั้งค่ากระดาษ + รายการบรรทัด/กล่อง (blocks) เรียงจากบนลงล่าง
 * เก็บเป็น JSON ในตาราง FormTemplates (supabase/form_templates.sql)
 * ตัววาด (render.ts) แปลงแม่แบบ + ข้อมูลจริง → HTML หน่วยมิลลิเมตร
 *
 * ค่าตั้งของบรรทัดที่เป็น null = "ค่าเดิม" ของบรรทัดชนิดนั้น (ดู BLOCK_DEFAULTS ใน render.ts)
 */

export type FormType = 'leave' | 'trip';

export const FORM_TYPE_LABEL: Record<FormType, string> = {
  leave: 'ใบลา',
  trip: 'ใบขออนุญาตไปราชการ',
};

// ── หน่วย ──────────────────────────────────────────────────────

/** 1 มม. = 3.7795 px (96 dpi) */
export const PX_PER_MM = 96 / 25.4;
export const pxToMm = (px: number) => Math.round((px / PX_PER_MM) * 10000) / 10000;
export const mmToPx = (mm: number) => mm * PX_PER_MM;
/** 1 pt = 4/3 px */
export const ptToPx = (pt: number) => (pt * 4) / 3;

// ── กระดาษ ─────────────────────────────────────────────────────

export type PaperSize = 'A4' | 'A5' | 'Letter' | 'custom';

export const PAPER_PRESETS: Record<Exclude<PaperSize, 'custom'>, { widthMm: number; heightMm: number; label: string }> = {
  A4: { widthMm: 210, heightMm: 297, label: 'A4 (210 × 297 มม.)' },
  A5: { widthMm: 148, heightMm: 210, label: 'A5 (148 × 210 มม.)' },
  Letter: { widthMm: 215.9, heightMm: 279.4, label: 'Letter (216 × 279 มม.)' },
};

export interface PaperSettings {
  size: PaperSize;
  /** ใช้เมื่อ size = custom (แนวตั้ง) */
  widthMm: number;
  heightMm: number;
  orientation: 'portrait' | 'landscape';
  margin: { top: number; right: number; bottom: number; left: number }; // มม.
  fontFamily: string;
  fontSizePt: number;
  lineHeight: number;
  /** เนื้อหาเกินหน้า → ย่อทั้งหน้าให้พอดีกระดาษหน้าเดียว */
  fitToPage: boolean;
}

/** ขนาดกระดาษจริงตามแนว (มม.) */
export function paperDimensions(p: PaperSettings): { widthMm: number; heightMm: number } {
  const base = p.size === 'custom' ? { widthMm: p.widthMm, heightMm: p.heightMm } : PAPER_PRESETS[p.size];
  const [w, h] = [Math.min(base.widthMm, base.heightMm), Math.max(base.widthMm, base.heightMm)];
  return p.orientation === 'landscape' ? { widthMm: h, heightMm: w } : { widthMm: w, heightMm: h };
}

export const FONT_CHOICES = [
  { value: '"Sarabun", "TH Sarabun New", Tahoma, Arial, sans-serif', label: 'Sarabun (ค่าเดิม)' },
  { value: '"TH Sarabun New", "Sarabun", Tahoma, sans-serif', label: 'TH Sarabun New' },
  { value: '"TH SarabunPSK", "TH Sarabun New", "Sarabun", sans-serif', label: 'TH SarabunPSK' },
  { value: 'Tahoma, Arial, sans-serif', label: 'Tahoma' },
];

// ── บรรทัด / กล่อง ─────────────────────────────────────────────

export type Align = 'left' | 'center' | 'right' | 'justify';

/** ค่าตั้งที่ทุกบรรทัดมีเหมือนกัน */
export interface BlockCommon {
  id: string;
  /** ชื่อที่แสดงในรายการบรรทัดของตัวแก้ไข */
  name: string;
  visible: boolean;
  /** บรรทัดที่มากับแม่แบบเริ่มต้น — ซ่อนได้แต่ลบไม่ได้ */
  builtIn?: boolean;
  spaceBeforeMm: number | null;
  spaceAfterMm: number | null;
  minHeightMm: number | null;
  indentMm: number | null;
  offsetXMm: number;
  offsetYMm: number;
  align: Align | null;
  fontSizePt: number | null;
  bold: boolean;
  underline: boolean;
}

/** ส่วนย่อยของบรรทัดข้อความ */
export type Segment =
  | { kind: 'text'; text: string; bold?: boolean; nowrap?: boolean }
  /** ช่องเส้นประ — width null = ยืดเต็มที่ว่าง */
  | { kind: 'field'; text: string; widthMm: number | null }
  /** ช่องติ๊ก — ติ๊กเมื่อเงื่อนไข (flag) เป็นจริง */
  | { kind: 'checkbox'; label: string; flag: string };

export interface RowBlock extends BlockCommon {
  type: 'row';
  segments: Segment[];
}

/** กล่องข้อความหลายบรรทัด (**ตัวหนา** ได้) วางในกล่องกว้างตามที่ตั้ง */
export interface TextBoxBlock extends BlockCommon {
  type: 'textBox';
  lines: string[];
  boxWidthMm: number | null;
  boxPosition: 'left' | 'center' | 'right';
  firstLineIndentMm: number;
}

/** หัวเอกสารใบลา: ชื่อแบบฟอร์ม + กล่อง "รับที่" มุมขวา */
export interface HeaderBlock extends BlockCommon {
  type: 'header';
  title: string;
  subtitle: string;
  showReceiveBox: boolean;
  receiveLines: string[];
}

/** ช่องติ๊กประเภทการลา + ปีกกา + เหตุผล */
export interface LeaveTypesBlock extends BlockCommon {
  type: 'leaveTypes';
  label: string;
  reasonLabel: string;
  showBrace: boolean;
}

/** ส่วนล่างใบลา: ตารางสถิติ + ช่องเซ็นผู้ลา / ผู้บังคับบัญชา */
export interface ApprovalBlock extends BlockCommon {
  type: 'approval';
  showStats: boolean;
  statsTitle: string;
  hrLines: string[];
  applicantLines: string[];
  showComment: boolean;
  commentLabel: string;
  deputyLines: string[];
  showOrder: boolean;
  orderLabel: string;
  orderOptions: string[];
  directorLines: string[];
}

/** ตารางรายชื่อผู้ร่วมเดินทาง (ไปราชการ) */
export interface MemberTableBlock extends BlockCommon {
  type: 'memberTable';
  showPosition: boolean;
  showSignature: boolean;
  headers: { no: string; name: string; position: string; signature: string };
}

/** ช่องลงชื่อ (หลายบรรทัด) วางในกล่องกว้างตามที่ตั้ง */
export interface SignatureBlock extends BlockCommon {
  type: 'signature';
  lines: string[];
  boxWidthMm: number | null;
  boxPosition: 'left' | 'center' | 'right';
}

export interface SpacerBlock extends BlockCommon {
  type: 'spacer';
  heightMm: number;
}

export type Block =
  | RowBlock
  | TextBoxBlock
  | HeaderBlock
  | LeaveTypesBlock
  | ApprovalBlock
  | MemberTableBlock
  | SignatureBlock
  | SpacerBlock;

export type BlockType = Block['type'];

export const BLOCK_TYPE_LABEL: Record<BlockType, string> = {
  row: 'บรรทัดข้อความ',
  textBox: 'กล่องข้อความ',
  header: 'หัวเอกสาร',
  leaveTypes: 'ประเภทการลา',
  approval: 'ส่วนลงนามอนุมัติ',
  memberTable: 'ตารางผู้ร่วมเดินทาง',
  signature: 'ช่องลงชื่อ',
  spacer: 'ที่ว่าง',
};

/** ชนิดบรรทัดที่เพิ่มเองได้ ต่อประเภทฟอร์ม */
export const ADDABLE_BLOCKS: Record<FormType, BlockType[]> = {
  leave: ['row', 'textBox', 'signature', 'spacer'],
  trip: ['row', 'textBox', 'signature', 'memberTable', 'spacer'],
};

export interface FormTemplate {
  schema: 1;
  formType: FormType;
  paper: PaperSettings;
  blocks: Block[];
}

// ── ตัวแทนข้อมูล ───────────────────────────────────────────────

export interface Placeholder {
  key: string; // ชื่อในวงเล็บปีกกา เช่น ชื่อ → {ชื่อ}
  label: string;
}

/** เงื่อนไขของช่องติ๊ก */
export interface FlagOption {
  key: string;
  label: string;
}

export const ALWAYS_UNCHECKED = 'ว่าง';

// ── ตัวช่วย ────────────────────────────────────────────────────

let counter = 0;
export const newBlockId = () => `b${Date.now().toString(36)}${(counter++).toString(36)}`;

export const cloneTemplate = (t: FormTemplate): FormTemplate => JSON.parse(JSON.stringify(t));

export function commonDefaults(name: string, extra: Partial<BlockCommon> = {}): BlockCommon {
  return {
    id: newBlockId(),
    name,
    visible: true,
    spaceBeforeMm: null,
    spaceAfterMm: null,
    minHeightMm: null,
    indentMm: null,
    offsetXMm: 0,
    offsetYMm: 0,
    align: null,
    fontSizePt: null,
    bold: false,
    underline: false,
    ...extra,
  };
}

/** บรรทัดใหม่เปล่า ๆ ตามชนิด (ปุ่ม "เพิ่มบรรทัด") */
export function newBlock(type: BlockType): Block {
  const c = commonDefaults(`${BLOCK_TYPE_LABEL[type]}ใหม่`);
  switch (type) {
    case 'row':
      return { ...c, type, segments: [{ kind: 'text', text: 'ข้อความ' }] };
    case 'textBox':
      return { ...c, type, lines: ['ข้อความ'], boxWidthMm: null, boxPosition: 'left', firstLineIndentMm: 0 };
    case 'signature':
      return {
        ...c,
        type,
        lines: ['ลงชื่อ ..................................................', '( {ชื่อ} )', 'ตำแหน่ง {ตำแหน่ง}'],
        boxWidthMm: 90,
        boxPosition: 'right',
      };
    case 'memberTable':
      return {
        ...c,
        type,
        showPosition: true,
        showSignature: false,
        headers: { no: 'ที่', name: 'ชื่อ - สกุล', position: 'ตำแหน่ง', signature: 'ลายมือชื่อ' },
      };
    case 'spacer':
      return { ...c, type, heightMm: 5 };
    case 'header':
      return { ...c, type, title: 'หัวเรื่อง', subtitle: '', showReceiveBox: false, receiveLines: [] };
    case 'leaveTypes':
      return { ...c, type, label: 'ขอลา', reasonLabel: 'เนื่องจาก', showBrace: true };
    case 'approval':
      throw new Error('ส่วนลงนามอนุมัติมีได้ชุดเดียวในแม่แบบเริ่มต้น');
  }
}

/**
 * อ่านแม่แบบจากฐานข้อมูลอย่างปลอดภัย — เติมค่าที่ขาด (แม่แบบที่บันทึกก่อนเพิ่มฟีเจอร์ใหม่)
 * ถ้าอ่านไม่ได้ใช้ค่าเริ่มต้น
 */
export function normalizeTemplate(raw: unknown, fallback: FormTemplate): FormTemplate {
  if (!raw || typeof raw !== 'object') return cloneTemplate(fallback);
  const t = raw as Partial<FormTemplate>;
  if (t.formType !== fallback.formType || !Array.isArray(t.blocks)) return cloneTemplate(fallback);
  const base = commonDefaults('');
  return {
    schema: 1,
    formType: fallback.formType,
    paper: { ...fallback.paper, ...(t.paper ?? {}), margin: { ...fallback.paper.margin, ...(t.paper?.margin ?? {}) } },
    blocks: t.blocks.map((b) => ({ ...base, ...b }) as Block),
  };
}
