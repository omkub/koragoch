/**
 * ชุดทดสอบตัววาดเอกสาร — ใช้เทียบตัววาดของ web (render.ts) กับของ app
 * (lib/forms/form_render.dart) ว่าได้ HTML เดียวกันทุกตัวอักษร
 *
 * แต่ละกรณีตั้งใจให้ผ่านทุกตัวเลือกของแม่แบบอย่างน้อยหนึ่งครั้ง
 * เพิ่มตัวเลือกใหม่ในแม่แบบแล้ว ให้เพิ่มกรณีที่นี่ด้วย แล้วรัน npm run form-fixtures
 */
import { renderDocument, type RenderContext, type RenderOptions } from '../src/forms/render';
import { defaultLeaveTemplate, leaveContext as buildLeaveContext } from '../src/forms/leaveTemplate';
import { LeaveFormData, schoolRecordFromRow, type Row } from '../src/leaveForm/leaveFormData';
import { defaultTripTemplate } from '../src/forms/tripTemplate';
import { commonDefaults, type Block, type FormTemplate } from '../src/forms/template';

export interface RenderCase {
  name: string;
  template: FormTemplate;
  context: RenderContext;
  options: RenderOptions;
}

/** id คงที่ — ไม่ให้ไฟล์ที่สร้างเปลี่ยนทุกครั้งที่รัน */
function stable(t: FormTemplate): FormTemplate {
  return { ...t, blocks: t.blocks.map((b, i) => ({ ...b, id: `${t.formType}-${i + 1}` })) };
}

const c = (name: string, extra = {}) => ({ ...commonDefaults(name, extra), id: name });

const leaveContext: RenderContext = {
  title: 'Leave-นายทดสอบ ระบบ',
  values: {
    ชื่อ: 'นายทดสอบ ระบบ',
    ตำแหน่ง: 'ครู',
    ตำแหน่งและวิทยฐานะ: 'ครู ชำนาญการ',
    ตำแหน่งผู้ลา: 'ครู',
    ประเภทการลา: 'ลาป่วย',
    เหตุผล: 'ไข้หวัด',
    วันที่เริ่ม: '9 ตุลาคม 2569',
    วันที่สิ้นสุด: '10 ตุลาคม 2569',
    จำนวนวัน: '2',
    'วันที่ยื่น-วัน': '9',
    'วันที่ยื่น-เดือน': 'ตุลาคม',
    'วันที่ยื่น-ปี': '2569',
    เบอร์โทร: '08x-xxx-xxxx',
    'ลาครั้งล่าสุด-เริ่ม': '1 กันยายน 2569',
    'ลาครั้งล่าสุด-สิ้นสุด': '1 กันยายน 2569',
    'ลาครั้งล่าสุด-จำนวนวัน': '1',
    เลขรับ: '............................',
    วันที่รับ: '............................',
    เวลารับ: '..............................',
    โรงเรียน: 'โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก',
    'โรงเรียน-ส่วน1': 'โรงเรียนรมย์บุรีพิทยาคม',
    'โรงเรียน-ส่วน2': 'รัชมังคลาภิเษก',
    ที่อยู่โรงเรียน: 'อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000',
    สังกัด: 'สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์',
    หัวหน้าบุคคล: '(นางหัวหน้า บุคคล)',
    'รองผอ.บุคคล': '(นายรอง ผอ.)',
    ผู้อำนวยการ: '(นายผู้อำนวยการ ใจดี)',
  },
  flags: { 'ลาครั้งล่าสุด=ป่วย': true, 'ลาครั้งล่าสุด=ลากิจส่วนตัว': false },
  leaveTypes: [
    { label: 'ลาป่วย', checked: true },
    { label: 'ลากิจ', checked: false },
    { label: 'ลาคลอด', checked: false },
  ],
  reason: 'ไข้หวัด\nพักรักษาตัวที่บ้าน',
  stats: [
    { label: 'ป่วย', previousTimes: '1', previousDays: '1', currentTimes: '1', currentDays: '2', totalTimes: '2', totalDays: '3' },
    { label: 'ลากิจส่วนตัว', previousTimes: '-', previousDays: '-', currentTimes: '-', currentDays: '-', totalTimes: '-', totalDays: '-' },
  ],
};

const tripContext: RenderContext = {
  title: 'OfficialTrip-ประชุม',
  values: {
    ชื่อ: 'นายทดสอบ ระบบ',
    ตำแหน่ง: 'ครู ชำนาญการ',
    เรื่อง: 'ประชุมพัฒนาหลักสูตร',
    ประเภท: 'ประชุม',
    หน่วยงานที่จัด: 'สพม.บุรีรัมย์',
    สถานที่: 'หอประชุม',
    จังหวัด: 'จังหวัดบุรีรัมย์',
    เลขที่หนังสือ: 'ศธ 04xxx/1234',
    วันที่หนังสือ: '1 ตุลาคม 2569',
    ช่วงวันที่: '9 ตุลาคม 2569 ถึงวันที่ 10 ตุลาคม 2569',
    ช่วงเวลา: 'เต็มวัน',
    จำนวนวัน: '2',
    การเดินทาง: 'รถยนต์ราชการ',
    แหล่งค่าใช้จ่าย: 'เบิกจากต้นสังกัด',
    ค่าใช้จ่าย: 'ประมาณ 1,500 บาท',
    จำนวนผู้ร่วมเดินทาง: '3',
    วันที่ยื่น: '9 ตุลาคม 2569',
    โรงเรียน: 'โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก',
    ที่อยู่โรงเรียน: 'อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000',
    ผู้อำนวยการ: '(นายผู้อำนวยการ ใจดี)',
  },
  flags: { อนุมัติแล้ว: true, ไม่อนุมัติ: false },
  members: [
    { name: 'นายทดสอบ ระบบ', position: 'ครู ชำนาญการ' },
    { name: 'นางสาวตัวอย่าง ใจดี', position: '' },
    { name: 'นาย <ชื่อแปลก> & "เครื่องหมาย"', position: 'ครูผู้ช่วย' },
  ],
};

/** แม่แบบใบลาแบบกำหนดบรรทัดเอง (กระดาษเดิม) */
function leaveWith(blocks: Block[], paper: Partial<FormTemplate['paper']> = {}): FormTemplate {
  const base = defaultLeaveTemplate();
  return { ...base, paper: { ...base.paper, ...paper }, blocks };
}

export function renderCases(): RenderCase[] {
  const cases: RenderCase[] = [
    { name: 'ใบลาเริ่มต้น', template: stable(defaultLeaveTemplate()), context: leaveContext, options: {} },
    { name: 'ใบลาเริ่มต้น + ปุ่มพิมพ์ + พิมพ์อัตโนมัติ', template: stable(defaultLeaveTemplate()), context: leaveContext, options: { toolbar: true, autoPrint: true } },
    { name: 'ใบลาเริ่มต้น โหมดตัวแก้ไข', template: stable(defaultLeaveTemplate()), context: leaveContext, options: { editor: true, selectedBlockId: 'leave-3' } },
    { name: 'ใบลาเริ่มต้น ไม่มีข้อมูล', template: stable(defaultLeaveTemplate()), context: { title: '', values: {}, flags: {} }, options: {} },
    { name: 'ใบไปราชการเริ่มต้น', template: stable(defaultTripTemplate()), context: tripContext, options: {} },
    { name: 'ใบไปราชการเริ่มต้น ไม่มีผู้ร่วมเดินทาง', template: stable(defaultTripTemplate()), context: { ...tripContext, members: [] }, options: {} },

    {
      name: 'ข้อความ: ตัวหนา / ช่องเส้นประในบรรทัด / ตัวแทนที่ไม่รู้จัก / escape',
      template: leaveWith([
        {
          ...c('tb'),
          type: 'textBox',
          lines: [
            '**{ชื่อ}** เขียนที่ {ไม่มีตัวนี้} [[{วันที่เริ่ม}]] ถึง [[ ]]',
            'ตัวหนาไม่ปิด **ค้าง',
            '****',
            '**[[{ชื่อ}]]** และ [[**ไม่หนา**]]',
            '{อันตราย} <b>ไม่ใช่แท็ก</b> & \'quote\' / slash',
            '',
            '{{ชื่อ}} {} [[[ชื่อ]]]',
          ],
          boxWidthMm: null,
          boxPosition: 'left',
          firstLineIndentMm: 0,
        },
      ]),
      context: { ...leaveContext, values: { ...leaveContext.values, อันตราย: '<script>alert("x")</script>' } },
      options: {},
    },
    {
      name: 'บรรทัดข้อความ: ทุกชนิดส่วนย่อย + ทุกการจัดวาง',
      template: leaveWith([
        ...(['left', 'center', 'right', 'justify', null] as const).map((align, i) => ({
          ...c(`row${i}`, { align }),
          type: 'row' as const,
          segments: [
            { kind: 'text' as const, text: 'ข้อความ', bold: true },
            { kind: 'text' as const, text: '{ชื่อ}', nowrap: true },
            { kind: 'field' as const, text: '{ชื่อ}', widthMm: null },
            { kind: 'field' as const, text: '{วันที่เริ่ม}', widthMm: 39.6875 },
            { kind: 'field' as const, text: '', widthMm: 12.5, noLine: true },
            { kind: 'field' as const, text: 'ไม่มีเส้น', widthMm: null, noLine: true },
            { kind: 'checkbox' as const, label: 'ติ๊ก', flag: 'ลาครั้งล่าสุด=ป่วย' },
            { kind: 'checkbox' as const, label: 'ไม่ติ๊ก', flag: 'ลาครั้งล่าสุด=ลากิจส่วนตัว' },
            { kind: 'checkbox' as const, label: 'ไม่มีเงื่อนไขนี้', flag: 'อะไรก็ได้' },
            { kind: 'checkbox' as const, label: 'ว่างเสมอ', flag: 'ว่าง' },
          ],
        })),
      ]),
      context: { ...leaveContext, flags: { ...leaveContext.flags, ว่าง: true } },
      options: {},
    },
    {
      name: 'กล่องข้อความ: กว้าง / ตำแหน่ง / ย่อหน้าแรก / จัดวาง',
      template: leaveWith(
        (['left', 'center', 'right'] as const).flatMap((pos, i) => [
          { ...c(`a${i}`), type: 'textBox' as const, lines: ['ก', 'ข'], boxWidthMm: 80.5, boxPosition: pos, firstLineIndentMm: 0 },
          { ...c(`b${i}`, { align: 'justify' }), type: 'textBox' as const, lines: ['ย่อหน้า'], boxWidthMm: null, boxPosition: pos, firstLineIndentMm: 25 },
          { ...c(`c${i}`, { align: 'right' }), type: 'textBox' as const, lines: [], boxWidthMm: 0, boxPosition: pos, firstLineIndentMm: 0.5 },
        ]),
      ),
      context: leaveContext,
      options: {},
    },
    {
      name: 'ค่าตั้งร่วมของบรรทัด: ระยะ / สูง / ย่อหน้า / ขยับ / ตัวอักษร / ซ่อน',
      template: leaveWith([
        { ...c('s1', { spaceBeforeMm: 0, spaceAfterMm: 12.25 }), type: 'spacer', heightMm: 7.5 },
        { ...c('s2', { minHeightMm: 30, indentMm: 15.3458, fontSizePt: 14, bold: true, underline: true }), type: 'row', segments: [{ kind: 'text', text: 'หนา ขีดเส้นใต้' }] },
        { ...c('s3', { offsetXMm: -3, offsetYMm: 0 }), type: 'row', segments: [] },
        { ...c('s4', { offsetXMm: 0, offsetYMm: 2.5 }), type: 'spacer', heightMm: 0 },
        { ...c('s5', { visible: false }), type: 'row', segments: [{ kind: 'text', text: 'ซ่อนไว้' }] },
        { ...c('s6', { spaceBeforeMm: 1e-7, fontSizePt: 10.5 }), type: 'spacer', heightMm: 0.1 + 0.2 },
        { ...c('id "แปลก" <x>'), type: 'spacer', heightMm: 1 },
      ]),
      context: leaveContext,
      options: { editor: true, selectedBlockId: 'id "แปลก" <x>' },
    },
    {
      name: 'หัวเอกสาร: ไม่มีกล่องรับที่ / ไม่มีชื่อรอง',
      template: leaveWith([
        { ...c('h1'), type: 'header', title: '**แบบ**ใบลา {ชื่อ}', subtitle: '', showReceiveBox: false, receiveLines: ['ไม่แสดง'] },
        { ...c('h2'), type: 'header', title: '', subtitle: 'รอง', showReceiveBox: true, receiveLines: [] },
      ]),
      context: leaveContext,
      options: {},
    },
    {
      name: 'ประเภทการลา: ไม่มีปีกกา / ไม่มีประเภท / ไม่มีเหตุผล',
      template: leaveWith([
        { ...c('l1'), type: 'leaveTypes', label: 'ขอลา', reasonLabel: 'เนื่องจาก', showBrace: false },
        { ...c('l2'), type: 'leaveTypes', label: '**ขอ**', reasonLabel: '', showBrace: true },
      ]),
      context: { ...leaveContext, leaveTypes: [], reason: undefined },
      options: {},
    },
    {
      name: 'ประเภทการลา: ประเภทเดียว ชื่อมีอักขระพิเศษ',
      template: leaveWith([{ ...c('l1'), type: 'leaveTypes', label: 'ขอลา', reasonLabel: 'เนื่องจาก', showBrace: true }]),
      context: { ...leaveContext, leaveTypes: [{ label: 'ลา <พิเศษ>', checked: true }], reason: '<b>ไม่หนา</b>' },
      options: {},
    },
    {
      name: 'ส่วนอนุมัติ: ปิดทุกส่วนเสริม',
      template: leaveWith([
        {
          ...c('ap'),
          type: 'approval',
          showStats: false,
          statsTitle: 'ไม่แสดง',
          hrLines: ['ลงชื่อ', '{หัวหน้าบุคคล}'],
          applicantLines: [],
          showComment: false,
          commentLabel: 'ไม่แสดง',
          deputyLines: ['{รองผอ.บุคคล}'],
          showOrder: false,
          orderLabel: 'ไม่แสดง',
          orderOptions: ['ไม่แสดง'],
          directorLines: [],
        },
      ]),
      context: { ...leaveContext, stats: undefined },
      options: {},
    },
    {
      name: 'ส่วนอนุมัติ: ไม่มีสถิติ แต่เปิดตาราง',
      template: leaveWith([
        {
          ...c('ap'),
          type: 'approval',
          showStats: true,
          statsTitle: '**สถิติ**',
          hrLines: [],
          applicantLines: ['a'],
          showComment: true,
          commentLabel: '{ไม่มี}',
          deputyLines: [],
          showOrder: true,
          orderLabel: 'คำสั่ง',
          orderOptions: [],
          directorLines: ['b'],
        },
      ]),
      context: { ...leaveContext, stats: [] },
      options: {},
    },
    {
      name: 'ตารางผู้ร่วมเดินทาง: ทุกแบบคอลัมน์',
      template: {
        ...defaultTripTemplate(),
        blocks: [
          { ...c('m1'), type: 'memberTable', showPosition: true, showSignature: true, headers: { no: 'ที่', name: '**ชื่อ**', position: 'ตำแหน่ง', signature: 'ลายมือชื่อ' } },
          { ...c('m2'), type: 'memberTable', showPosition: false, showSignature: false, headers: { no: '', name: 'ชื่อ', position: 'x', signature: 'y' } },
          { ...c('m3'), type: 'memberTable', showPosition: false, showSignature: true, headers: { no: 'ลำดับ', name: 'ชื่อ', position: '', signature: '{ชื่อ}' } },
        ],
      },
      context: tripContext,
      options: {},
    },
    {
      name: 'ตารางผู้ร่วมเดินทาง: ไม่มีข้อมูลผู้ร่วมเดินทาง',
      template: {
        ...defaultTripTemplate(),
        blocks: [{ ...c('m1'), type: 'memberTable', showPosition: true, showSignature: false, headers: { no: 'ที่', name: 'ชื่อ', position: 'ตำแหน่ง', signature: '' } }],
      },
      context: { ...tripContext, members: undefined },
      options: {},
    },
    {
      name: 'ช่องลงชื่อ: กว้าง / ตำแหน่ง / จัดวาง',
      template: leaveWith([
        { ...c('g1'), type: 'signature', lines: ['ลงชื่อ ....', '( {ชื่อ} )'], boxWidthMm: 90, boxPosition: 'right' },
        { ...c('g2', { align: 'left' }), type: 'signature', lines: ['**หนา**'], boxWidthMm: null, boxPosition: 'center' },
        { ...c('g3', { align: 'justify' }), type: 'signature', lines: [], boxWidthMm: 45.25, boxPosition: 'left' },
      ]),
      context: leaveContext,
      options: {},
    },
    {
      name: 'กระดาษ: A5 แนวนอน + ย่อให้พอดีหน้า',
      template: leaveWith([{ ...c('r'), type: 'row', segments: [{ kind: 'text', text: 'x' }] }], {
        size: 'A5',
        orientation: 'landscape',
        fitToPage: true,
        fontFamily: 'Tahoma, Arial, sans-serif',
        fontSizePt: 16,
        lineHeight: 2,
        margin: { top: 10, right: 12.5, bottom: 0, left: 33.3333 },
      }),
      context: leaveContext,
      options: { autoPrint: true },
    },
    {
      name: 'กระดาษ: กำหนดเอง (กว้างกว่าสูง) / Letter',
      template: leaveWith([], { size: 'custom', widthMm: 300, heightMm: 100.5, orientation: 'portrait' }),
      context: leaveContext,
      options: {},
    },
    {
      name: 'กระดาษ: Letter แนวนอน',
      template: leaveWith([], { size: 'Letter', orientation: 'landscape' }),
      context: { ...leaveContext, title: '<ชื่อ & "แท็บ">' },
      options: { toolbar: true },
    },
  ];
  return cases;
}

// ── ข้อมูลใบลา → ตัวแทนข้อมูล (leaveContext) ─────────────────────

export interface LeaveContextCase {
  name: string;
  leaf: Row;
  allUsers: Row[];
  allLeaveRequests: Row[];
  leaveTypeNames: string[];
  schoolRow: Row;
}

const users: Row[] = [
  { fullName: 'นายทดสอบ ระบบ', position: 'ครู', academicStanding: 'ชำนาญการ' },
  { fullName: 'นางสาวไม่มี วิทยฐานะ', position: '', academicStanding: 'ไม่มีวิทยฐานะ' },
  { fullName: 'นางหัวหน้า บุคคล', ตำแหน่งงานบริหาร: 'หัวหน้ากลุ่มบริหารงานบุคคล' },
  { fullName: 'นายรอง ผอ.', ตำแหน่งงานบริหาร: 'รองผู้อำนวยการ กลุ่มบริหารงานบุคคล' },
  { fullName: 'นายผู้อำนวยการ ใจดี', ตำแหน่งงานบริหาร: 'ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม' },
];

const history: Row[] = [
  { requestId: 'h1', fullName: 'นายทดสอบ ระบบ', leaveType: 'ลาป่วย', year: '2570', startDate: '01/09/2569', endDate: '01/09/2569', totalDays: 1, timestamp: '2026-09-01T08:00:00' },
  { requestId: 'h2', fullName: 'นายทดสอบ ระบบ', leaveType: 'ลากิจส่วนตัว', year: '2570', startDate: '15/09/2569', endDate: '16/09/2569', totalDays: 1.5, timestamp: '2026-09-14T08:00:00' },
  { requestId: 'h3', fullName: 'นายทดสอบ ระบบ', leaveType: 'ลาป่วย', year: '2569', startDate: '01/03/2569', endDate: '02/03/2569', totalDays: 2, timestamp: '2026-03-01T08:00:00' },
  { requestId: 'h4', fullName: 'นางสาวไม่มี วิทยฐานะ', leaveType: 'ลาป่วย', year: '2570', startDate: '01/10/2569', endDate: '01/10/2569', totalDays: 1, timestamp: '2026-10-01T08:00:00' },
];

export function leaveContextCases(): LeaveContextCase[] {
  const school = { namePart1: 'โรงเรียนทดสอบ', namePart2: 'วิทยา', province: 'บุรีรัมย์', district: 'เมือง', affiliation: 'สังกัด สพม.' };
  return [
    {
      name: 'ใบลาที่ยื่นแล้ว + ประวัติ + ผู้บริหาร',
      leaf: {
        requestId: 'r1', fullName: 'นายทดสอบ ระบบ', leaveType: 'ลาป่วย', reason: 'ไข้หวัด', year: '2570',
        startDate: '09/10/2569', endDate: '10/10/2569', totalDays: 2, phone: '0812345678',
        timestamp: '2026-10-09T09:30:00', receiveNumber: '12', receiveDate: '9 ต.ค. 69',
      },
      allUsers: users,
      allLeaveRequests: history,
      leaveTypeNames: ['---เลือก---', 'ลาป่วย', 'ลากิจส่วนตัว', 'ลาคลอดบุตร', ' '],
      schoolRow: school,
    },
    {
      name: 'ใบลาครึ่งวัน ไม่มีตำแหน่ง/วิทยฐานะ',
      leaf: {
        requestId: 'r2', fullName: 'นางสาวไม่มี วิทยฐานะ', leaveType: 'ลากิจส่วนตัว', reason: '', year: '2570',
        startDate: '12/10/2569', endDate: '12/10/2569', totalDays: 0.5, timestamp: '2026-10-11T23:59:00',
      },
      allUsers: users,
      allLeaveRequests: history,
      leaveTypeNames: [],
      schoolRow: {},
    },
    {
      name: 'พรีวิวหน้าส่งใบลา (ยังไม่ยื่น ยังไม่เลือกประเภท)',
      leaf: { fullName: '', leaveType: '---เลือก---', reason: '', startDate: '09/10/2569', endDate: '09/10/2569', totalDays: 1, year: '2570' },
      allUsers: [],
      allLeaveRequests: [],
      leaveTypeNames: ['ลาป่วย'],
      schoolRow: school,
    },
  ];
}

/** ชุดทดสอบ leaveContext พร้อมผลที่ web คำนวณ */
export function computedLeaveContexts() {
  return leaveContextCases().map((lc) => ({
    ...lc,
    context: buildLeaveContext(
      new LeaveFormData({
        leaf: lc.leaf,
        allUsers: lc.allUsers,
        allLeaveRequests: lc.allLeaveRequests,
        leaveTypeNames: lc.leaveTypeNames,
        school: schoolRecordFromRow(lc.schoolRow),
      }),
    ),
  }));
}

/** ชุดทดสอบพร้อม HTML ที่ตัววาดของ web สร้าง */
export function renderedCases() {
  return renderCases().map((rc) => ({ ...rc, html: renderDocument(rc.template, rc.context, rc.options) }));
}
