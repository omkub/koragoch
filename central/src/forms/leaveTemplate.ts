/**
 * แม่แบบเริ่มต้นของใบลา + การแปลงข้อมูลใบลาเป็นตัวแทนข้อมูล
 *
 * แม่แบบเริ่มต้นจัดวางตรงกับใบลาเดิมของ app (lib/widgets/leave_form_html.dart)
 * ระยะเว้นเป็นค่า px เดิมแปลงเป็นมม. (pxToMm) เพื่อให้วาดออกมาตำแหน่งเดียวกัน
 */
import { LeaveFormData } from '../leaveForm/leaveFormData';
import type { RenderContext } from './render';
import {
  ALWAYS_UNCHECKED,
  commonDefaults,
  FONT_CHOICES,
  pxToMm,
  type FlagOption,
  type FormTemplate,
  type Placeholder,
} from './template';

const DOTS_SIGN = 'ลงชื่อ ..................................................';
const DOTS_DATE = '........../........../..........';

export function defaultLeaveTemplate(): FormTemplate {
  const sp = (before: number, after: number) => ({ spaceBeforeMm: pxToMm(before), spaceAfterMm: pxToMm(after) });
  return {
    schema: 1,
    formType: 'leave',
    paper: {
      size: 'A4',
      widthMm: 210,
      heightMm: 297,
      orientation: 'portrait',
      margin: { top: pxToMm(42), right: pxToMm(58), bottom: pxToMm(42), left: pxToMm(58) },
      fontFamily: FONT_CHOICES[0].value,
      fontSizePt: 10.5, // 14px เท่าใบลาเดิม
      lineHeight: 1.45,
      fitToPage: false,
    },
    blocks: [
      {
        ...commonDefaults('หัวเอกสาร + กล่องรับที่', { builtIn: true, ...sp(0, 0) }),
        type: 'header',
        title: 'แบบใบลา',
        subtitle: 'ลาป่วย/ลากิจ/ลาคลอดบุตร',
        showReceiveBox: true,
        receiveLines: ['รับที่ {เลขรับ}', 'วันที่ {วันที่รับ}', 'เวลา {เวลารับ}'],
      },
      {
        ...commonDefaults('ชื่อโรงเรียน / วันที่เขียน', { builtIn: true, align: 'center', ...sp(18, 26) }),
        type: 'textBox',
        lines: ['**{โรงเรียน}**', '{ที่อยู่โรงเรียน}', '', 'วันที่ [[{วันที่ยื่น-วัน}]] [[{วันที่ยื่น-เดือน}]] [[{วันที่ยื่น-ปี}]]'],
        boxWidthMm: pxToMm(360),
        boxPosition: 'right',
        firstLineIndentMm: 0,
      },
      {
        ...commonDefaults('เรื่อง', { builtIn: true, ...sp(4, 4) }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'เรื่อง', bold: true },
          { kind: 'field', text: 'ขอ{ประเภทการลา}', widthMm: null },
        ],
      },
      {
        ...commonDefaults('เรียน', { builtIn: true, ...sp(4, 4) }),
        type: 'row',
        segments: [{ kind: 'text', text: 'เรียน ผู้อำนวยการ{โรงเรียน}' }],
      },
      {
        ...commonDefaults('ข้าพเจ้า / ตำแหน่ง', { builtIn: true, indentMm: pxToMm(58), ...sp(4, 4) }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'ข้าพเจ้า' },
          { kind: 'field', text: '{ชื่อ}', widthMm: null },
          { kind: 'text', text: 'ตำแหน่ง' },
          { kind: 'field', text: '{ตำแหน่งและวิทยฐานะ}', widthMm: null },
          { kind: 'text', text: '{โรงเรียน-ส่วน1}', nowrap: true },
        ],
      },
      {
        ...commonDefaults('สังกัด', { builtIn: true, ...sp(4, 4) }),
        type: 'row',
        segments: [{ kind: 'text', text: '{โรงเรียน-ส่วน2} {สังกัด}' }],
      },
      {
        ...commonDefaults('ประเภทการลา / เหตุผล', { builtIn: true, ...sp(10, 10) }),
        type: 'leaveTypes',
        label: 'ขอลา',
        reasonLabel: 'เนื่องจาก',
        showBrace: true,
      },
      {
        ...commonDefaults('ช่วงวันลา', { builtIn: true, ...sp(4, 4) }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'ตั้งแต่วันที่' },
          { kind: 'field', text: '{วันที่เริ่ม}', widthMm: pxToMm(150) },
          { kind: 'text', text: 'ถึงวันที่' },
          { kind: 'field', text: '{วันที่สิ้นสุด}', widthMm: pxToMm(150) },
          { kind: 'text', text: 'มีกำหนด' },
          { kind: 'field', text: '{จำนวนวัน}', widthMm: pxToMm(60) },
          { kind: 'text', text: 'วัน' },
        ],
      },
      {
        ...commonDefaults('ลาครั้งล่าสุด', { builtIn: true, ...sp(4, 4) }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'ข้าพเจ้าได้ลา' },
          { kind: 'checkbox', label: 'ป่วย', flag: 'ลาครั้งล่าสุด=ป่วย' },
          { kind: 'checkbox', label: 'ลากิจส่วนตัว', flag: 'ลาครั้งล่าสุด=ลากิจส่วนตัว' },
          { kind: 'checkbox', label: 'ลาคลอดบุตร', flag: 'ลาครั้งล่าสุด=ลาคลอดบุตร' },
          { kind: 'text', text: 'ครั้งสุดท้ายตั้งแต่วันที่' },
          { kind: 'field', text: '{ลาครั้งล่าสุด-เริ่ม}', widthMm: pxToMm(130) },
        ],
      },
      {
        ...commonDefaults('ลาครั้งล่าสุด (ต่อ) / ติดต่อ', { builtIn: true, ...sp(4, 4) }),
        type: 'row',
        segments: [
          { kind: 'text', text: 'ถึงวันที่' },
          { kind: 'field', text: '{ลาครั้งล่าสุด-สิ้นสุด}', widthMm: pxToMm(130) },
          { kind: 'text', text: 'มีกำหนด' },
          { kind: 'field', text: '{ลาครั้งล่าสุด-จำนวนวัน}', widthMm: pxToMm(60) },
          { kind: 'text', text: 'วัน ในระหว่างที่ลาติดต่อข้าพเจ้าได้ที่' },
          { kind: 'field', text: '{เบอร์โทร}', widthMm: null },
        ],
      },
      {
        ...commonDefaults('จึงเรียนมา', { builtIn: true, align: 'center', ...sp(22, 0) }),
        type: 'row',
        segments: [{ kind: 'text', text: 'จึงเรียนมาเพื่อโปรดพิจารณา' }],
      },
      {
        ...commonDefaults('สถิติวันลา + ลงนามอนุมัติ', { builtIn: true, ...sp(28, 0) }),
        type: 'approval',
        showStats: true,
        statsTitle: 'สถิติวันลาในปีงบประมาณนี้',
        hrLines: [DOTS_SIGN, '{หัวหน้าบุคคล}', 'หัวหน้ากลุ่มบริหารงานบุคคล', DOTS_DATE],
        applicantLines: ['ขอแสดงความนับถือ', '', DOTS_SIGN, '( {ชื่อ} )', 'ตำแหน่ง {ตำแหน่งผู้ลา}'],
        showComment: true,
        commentLabel: 'ความคิดเห็น',
        deputyLines: [DOTS_SIGN, '{รองผอ.บุคคล}', 'รองผู้อำนวยการกลุ่มบริหารงานบุคคล', DOTS_DATE],
        showOrder: true,
        orderLabel: 'คำสั่ง',
        orderOptions: ['อนุญาต', 'ไม่อนุญาต'],
        directorLines: [DOTS_SIGN, '{ผู้อำนวยการ}', 'ผู้อำนวยการ{โรงเรียน}', DOTS_DATE],
      },
    ],
  };
}

export const LEAVE_PLACEHOLDERS: Placeholder[] = [
  { key: 'ชื่อ', label: 'ชื่อผู้ลา' },
  { key: 'ตำแหน่ง', label: 'ตำแหน่ง' },
  { key: 'วิทยฐานะ', label: 'วิทยฐานะ' },
  { key: 'ตำแหน่งและวิทยฐานะ', label: 'ตำแหน่ง + วิทยฐานะ' },
  { key: 'ตำแหน่งผู้ลา', label: 'ตำแหน่ง (ว่าง = -)' },
  { key: 'ประเภทการลา', label: 'ประเภทการลา' },
  { key: 'เรื่อง', label: 'เรื่อง (ขอ...)' },
  { key: 'เหตุผล', label: 'เหตุผล' },
  { key: 'วันที่เริ่ม', label: 'วันที่เริ่มลา' },
  { key: 'วันที่สิ้นสุด', label: 'วันที่สิ้นสุด' },
  { key: 'จำนวนวัน', label: 'จำนวนวัน' },
  { key: 'วันที่ยื่น', label: 'วันที่เขียนใบลา' },
  { key: 'วันที่ยื่น-วัน', label: 'วันที่เขียนใบลา: วัน' },
  { key: 'วันที่ยื่น-เดือน', label: 'วันที่เขียนใบลา: เดือน' },
  { key: 'วันที่ยื่น-ปี', label: 'วันที่เขียนใบลา: ปี' },
  { key: 'เบอร์โทร', label: 'เบอร์ติดต่อ' },
  { key: 'ลาครั้งล่าสุด-เริ่ม', label: 'ลาครั้งล่าสุด: เริ่ม' },
  { key: 'ลาครั้งล่าสุด-สิ้นสุด', label: 'ลาครั้งล่าสุด: สิ้นสุด' },
  { key: 'ลาครั้งล่าสุด-จำนวนวัน', label: 'ลาครั้งล่าสุด: จำนวนวัน' },
  { key: 'เลขรับ', label: 'เลขรับ' },
  { key: 'วันที่รับ', label: 'วันที่รับ' },
  { key: 'เวลารับ', label: 'เวลารับ' },
  { key: 'โรงเรียน', label: 'ชื่อโรงเรียน' },
  { key: 'โรงเรียน-ส่วน1', label: 'ชื่อโรงเรียน ส่วนแรก' },
  { key: 'โรงเรียน-ส่วน2', label: 'ชื่อโรงเรียน ส่วนหลัง' },
  { key: 'ที่อยู่โรงเรียน', label: 'ที่อยู่โรงเรียน' },
  { key: 'สังกัด', label: 'สังกัด' },
  { key: 'หัวหน้าบุคคล', label: '(ชื่อหัวหน้ากลุ่มบริหารงานบุคคล)' },
  { key: 'รองผอ.บุคคล', label: '(ชื่อรองผอ. กลุ่มบริหารงานบุคคล)' },
  { key: 'ผู้อำนวยการ', label: '(ชื่อผู้อำนวยการ)' },
];

export const LEAVE_FLAGS: FlagOption[] = [
  { key: 'ลาครั้งล่าสุด=ป่วย', label: 'ลาครั้งล่าสุดเป็นลาป่วย' },
  { key: 'ลาครั้งล่าสุด=ลากิจส่วนตัว', label: 'ลาครั้งล่าสุดเป็นลากิจ' },
  { key: 'ลาครั้งล่าสุด=ลาคลอดบุตร', label: 'ลาครั้งล่าสุดเป็นลาคลอด' },
  { key: ALWAYS_UNCHECKED, label: 'ว่างไว้เสมอ (ให้ติ๊กด้วยมือ)' },
];

/** ข้อมูลใบลา → ตัวแทนข้อมูล / ช่องติ๊ก / ตาราง */
export function leaveContext(data: LeaveFormData): RenderContext {
  const latest = data.latestLeaveLabel;
  const school = data.school;
  return {
    title: `Leave-${data.fullName}`,
    values: {
      ชื่อ: data.fullName,
      ตำแหน่ง: data.position,
      วิทยฐานะ: data.academicStanding,
      ตำแหน่งและวิทยฐานะ: data.positionWithStanding,
      ตำแหน่งผู้ลา: data.position === '' ? '-' : data.position,
      ประเภทการลา: data.leaveTypeRaw,
      เรื่อง: data.subject,
      เหตุผล: data.reason,
      วันที่เริ่ม: data.startDateText,
      วันที่สิ้นสุด: data.endDateText,
      จำนวนวัน: data.totalDaysText,
      วันที่ยื่น: `${data.requestDay} ${data.requestMonth} ${data.requestYear}`,
      'วันที่ยื่น-วัน': `${data.requestDay}`,
      'วันที่ยื่น-เดือน': data.requestMonth,
      'วันที่ยื่น-ปี': `${data.requestYear}`,
      เบอร์โทร: data.phone,
      'ลาครั้งล่าสุด-เริ่ม': data.latestStartText,
      'ลาครั้งล่าสุด-สิ้นสุด': data.latestEndText,
      'ลาครั้งล่าสุด-จำนวนวัน': data.latestDaysText,
      เลขรับ: data.receiveNumber ?? '............................',
      วันที่รับ: data.receiveDate ?? '............................',
      เวลารับ: data.receiveTime ?? '..............................',
      โรงเรียน: school.fullName,
      'โรงเรียน-ส่วน1': school.namePart1,
      'โรงเรียน-ส่วน2': school.namePart2,
      ที่อยู่โรงเรียน: school.address,
      สังกัด: school.affiliation,
      หัวหน้าบุคคล: data.hrName,
      'รองผอ.บุคคล': data.deputyName,
      ผู้อำนวยการ: data.directorName,
    },
    flags: {
      'ลาครั้งล่าสุด=ป่วย': latest === 'ป่วย',
      'ลาครั้งล่าสุด=ลากิจส่วนตัว': latest === 'ลากิจส่วนตัว',
      'ลาครั้งล่าสุด=ลาคลอดบุตร': latest === 'ลาคลอดบุตร',
    },
    leaveTypes: data.printableLeaveTypes.map((t) => ({ label: t, checked: data.isSelectedLeaveType(t) })),
    reason: data.reason,
    stats: data.statRows,
  };
}
