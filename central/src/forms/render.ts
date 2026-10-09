/**
 * ตัววาดเอกสารจากแม่แบบ → HTML (หน่วยมิลลิเมตร พิมพ์ได้ขนาดกระดาษจริง)
 *
 * CSS พื้นฐานยกมาจากใบลาเดิมของ app (lib/widgets/leave_form_html.dart)
 * แม่แบบเริ่มต้นของใบลาจึงวาดออกมาหน้าตาเหมือนใบลาเดิม
 * ต่างกันที่ระยะเว้น / ย่อหน้า / ความกว้างช่อง ย้ายมาเป็นค่าตั้งของแต่ละบรรทัด
 *
 * ขนาดตัวอักษรในเอกสารเป็น em เทียบกับขนาดพื้นฐานของกระดาษ
 * (ค่าเดิม 14px = 10.5pt) เปลี่ยนขนาดพื้นฐานแล้วทุกส่วนขยายตาม
 */
import type { LeaveStatRow } from '../leaveForm/leaveFormData';
import { htmlEscape } from '../leaveForm/leaveFormHtml';
import {
  ALWAYS_UNCHECKED,
  mmToPx,
  paperDimensions,
  type Align,
  type Block,
  type FormTemplate,
  type Segment,
} from './template';

export interface RenderContext {
  /** ชื่อแท็บ / ชื่อไฟล์ PDF */
  title: string;
  /** ตัวแทนข้อมูล {ชื่อ} → ค่า (ยังไม่ escape) */
  values: Record<string, string>;
  /** เงื่อนไขช่องติ๊ก */
  flags: Record<string, boolean>;
  /** ใบลา: ช่องติ๊กประเภทการลา */
  leaveTypes?: { label: string; checked: boolean }[];
  reason?: string;
  stats?: LeaveStatRow[];
  /** ไปราชการ: ผู้ร่วมเดินทาง */
  members?: { name: string; position: string }[];
}

export interface RenderOptions {
  /** ปุ่มพิมพ์ลอยมุมขวาบน (หน้าพิมพ์) */
  toolbar?: boolean;
  /** เปิดหน้าต่างพิมพ์ให้เองเมื่อโหลดเสร็จ */
  autoPrint?: boolean;
  /** โหมดตัวแก้ไข: กรอบบรรทัดเมื่อชี้ + ไฮไลต์บรรทัดที่เลือก */
  editor?: boolean;
  selectedBlockId?: string | null;
}

// ── ข้อความ + ตัวแทนข้อมูล ─────────────────────────────────────

/** แทน {ชื่อ} ด้วยค่า และ **ตัวหนา** — ตัวแทนที่ไม่รู้จักแสดงตามเดิมให้เห็นว่าพิมพ์ผิด */
export function renderText(template: string, ctx: RenderContext): string {
  const sub = (part: string) =>
    part
      .split(/(\{[^{}]+\})/g)
      .map((piece) => {
        const m = piece.match(/^\{([^{}]+)\}$/);
        if (m && m[1] in ctx.values) return htmlEscape(ctx.values[m[1]]);
        return piece ? htmlEscape(piece) : '';
      })
      .join('');
  const parts = template.split('**');
  const balanced = parts.length % 2 === 1;
  return parts
    .map((part, i) => {
      if (i % 2 === 0) return sub(part);
      // ** ตัวสุดท้ายที่ไม่มีคู่ปิด แสดงตามที่พิมพ์
      if (!balanced && i === parts.length - 1) return htmlEscape('**') + sub(part);
      return `<strong>${sub(part)}</strong>`;
    })
    .join('');
}

const lines = (list: string[], ctx: RenderContext) => list.map((l) => renderText(l, ctx)).join('<br>');

/** ช่องติ๊กแบบเดิมของใบลา */
function checkbox(label: string, checked: boolean): string {
  return '<span style="display: inline-flex; align-items: center; white-space: nowrap;">' +
    `<span class="check">${checked ? '✓' : ''}</span><span>${label}</span></span>`;
}

const flag = (ctx: RenderContext, key: string) => key !== ALWAYS_UNCHECKED && !!ctx.flags[key];

// ── บรรทัดแต่ละชนิด ────────────────────────────────────────────

const JUSTIFY: Record<Align, string> = {
  left: 'flex-start',
  center: 'center',
  right: 'flex-end',
  justify: 'space-between',
};

function segmentHtml(seg: Segment, ctx: RenderContext): string {
  switch (seg.kind) {
    case 'text': {
      const tag = seg.bold ? 'strong' : 'span';
      const style = seg.nowrap ? ' style="white-space: nowrap;"' : '';
      return `<${tag}${style}>${renderText(seg.text, ctx)}</${tag}>`;
    }
    case 'field':
      return seg.widthMm === null
        ? `<span class="line grow">${renderText(seg.text, ctx)}</span>`
        : `<span class="line" style="width: ${seg.widthMm}mm">${renderText(seg.text, ctx)}</span>`;
    case 'checkbox':
      return `<span>${checkbox(renderText(seg.label, ctx), flag(ctx, seg.flag))}</span>`;
  }
}

const boxMargin = (pos: 'left' | 'center' | 'right') =>
  pos === 'right' ? 'margin-left: auto;' : pos === 'center' ? 'margin-left: auto; margin-right: auto;' : '';

function blockInner(block: Block, ctx: RenderContext): string {
  switch (block.type) {
    case 'row': {
      const justify = block.align ? ` style="justify-content: ${JUSTIFY[block.align]}"` : '';
      return `<div class="row"${justify}>${block.segments.map((s) => segmentHtml(s, ctx)).join('')}</div>`;
    }

    case 'textBox': {
      const style = [
        block.boxWidthMm !== null ? `width: ${block.boxWidthMm}mm;` : '',
        boxMargin(block.boxPosition),
        `text-align: ${block.align ?? 'left'};`,
        block.firstLineIndentMm ? `text-indent: ${block.firstLineIndentMm}mm;` : '',
      ].join(' ').trim();
      return `<section class="textbox" style="${style}">${lines(block.lines, ctx)}</section>`;
    }

    case 'header': {
      const receive = block.showReceiveBox
        ? `<div class="receive">${lines(block.receiveLines, ctx)}</div>`
        : '<div></div>';
      const sub = block.subtitle ? `<h2>${renderText(block.subtitle, ctx)}</h2>` : '';
      return `<section class="top">
      <div></div>
      <div><h1>${renderText(block.title, ctx)}</h1>${sub}</div>
      ${receive}
    </section>`;
    }

    case 'leaveTypes': {
      const types = ctx.leaveTypes ?? [];
      const checks = types.map((t) => `<div class="checkline">${checkbox(htmlEscape(t.label), t.checked)}</div>`).join('');
      // ความสูงปีกกา = จำนวนบรรทัด × 22px + ช่องไฟ 2px (ตรงกับ .checkline / .checks)
      const braceHeight = types.length * 22 + (types.length - 1) * 2;
      const brace = block.showBrace
        ? `<div class="brace" style="height: ${braceHeight}px">
        <svg viewBox="0 0 20 100" preserveAspectRatio="none" aria-hidden="true">
          <path d="M4 1 C13 1 11 9 11 22 C11 38 11 46 18 50 C11 54 11 62 11 78 C11 91 13 99 4 99"
                fill="none" stroke="rgba(0,0,0,0.55)" stroke-width="1.4"
                stroke-linecap="round" vector-effect="non-scaling-stroke" />
        </svg>
      </div>`
        : '<div></div>';
      return `<section class="leave-block">
      <strong>${renderText(block.label, ctx)}</strong>
      <div class="checks">
        ${checks}
      </div>
      ${brace}
      <div class="reason-section" style="padding-top: 34px;">
        <span class="reason-label">${renderText(block.reasonLabel, ctx)}</span>
        <div class="reason-text">${htmlEscape(ctx.reason ?? '')}</div>
        <div class="reason-underline"></div>
      </div>
    </section>`;
    }

    case 'approval': {
      const stats = (ctx.stats ?? [])
        .map(
          (row) =>
            `<tr><td>${htmlEscape(row.label)}</td>` +
            `<td>${htmlEscape(row.previousTimes)}</td><td>${htmlEscape(row.previousDays)}</td>` +
            `<td>${htmlEscape(row.currentTimes)}</td><td>${htmlEscape(row.currentDays)}</td>` +
            `<td>${htmlEscape(row.totalTimes)}</td><td>${htmlEscape(row.totalDays)}</td></tr>`,
        )
        .join('');
      const left = block.showStats
        ? `<div>
        <div class="stats-title">${renderText(block.statsTitle, ctx)}</div>
        <table>
          <thead>
            <tr><th rowspan="2">ประเภทการลา</th><th colspan="2">ลามาแล้ว</th><th colspan="2">ลาครั้งนี้</th><th colspan="2">รวมเป็น</th></tr>
            <tr><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th></tr>
          </thead>
          <tbody>${stats}</tbody>
        </table>
        <div class="signature">${lines(block.hrLines, ctx)}</div>
      </div>`
        : `<div><div class="signature">${lines(block.hrLines, ctx)}</div></div>`;
      const comment = block.showComment
        ? `<div class="comment">${renderText(block.commentLabel, ctx)}</div><div class="line grow" style="width:100%; margin-top:4px;"></div>`
        : '';
      const order = block.showOrder
        ? `<div class="order"><strong>${renderText(block.orderLabel, ctx)}</strong>${block.orderOptions
            .map((o) => `<span>${checkbox(renderText(o, ctx), false)}</span>`)
            .join('')}</div>`
        : '';
      return `<section class="bottom">
      ${left}
      <div>
        <div class="signature" style="margin-top:0;">${lines(block.applicantLines, ctx)}</div>
        ${comment}
        <div class="signature">${lines(block.deputyLines, ctx)}</div>
        ${order}
        <div class="signature">${lines(block.directorLines, ctx)}</div>
      </div>
    </section>`;
    }

    case 'memberTable': {
      const members = ctx.members ?? [];
      const head = [
        `<th style="width: 12mm">${renderText(block.headers.no, ctx)}</th>`,
        `<th>${renderText(block.headers.name, ctx)}</th>`,
        block.showPosition ? `<th>${renderText(block.headers.position, ctx)}</th>` : '',
        block.showSignature ? `<th style="width: 35mm">${renderText(block.headers.signature, ctx)}</th>` : '',
      ].join('');
      const body = members
        .map(
          (m, i) =>
            `<tr><td class="c">${i + 1}</td><td>${htmlEscape(m.name)}</td>` +
            (block.showPosition ? `<td>${htmlEscape(m.position || '-')}</td>` : '') +
            (block.showSignature ? '<td></td>' : '') +
            '</tr>',
        )
        .join('');
      return `<table class="members"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
    }

    case 'signature': {
      const style = [
        block.boxWidthMm !== null ? `width: ${block.boxWidthMm}mm;` : '',
        boxMargin(block.boxPosition),
        `text-align: ${block.align ?? 'center'};`,
      ].join(' ').trim();
      return `<div class="sig-box" style="${style}">${lines(block.lines, ctx)}</div>`;
    }

    case 'spacer':
      return `<div style="height: ${block.heightMm}mm"></div>`;
  }
}

/** ระยะเว้นของบรรทัดที่ไม่ได้ตั้ง (ค่าเดิมของชนิดนั้น) — px ตามใบลาเดิม */
export const BLOCK_DEFAULT_SPACE_PX: Record<Block['type'], [number, number]> = {
  row: [4, 4],
  textBox: [4, 4],
  header: [0, 0],
  leaveTypes: [10, 10],
  approval: [28, 0],
  memberTable: [8, 8],
  signature: [14, 0],
  spacer: [0, 0],
};

function blockHtml(block: Block, ctx: RenderContext): string {
  const [defBefore, defAfter] = BLOCK_DEFAULT_SPACE_PX[block.type];
  const style = [
    `margin-top: ${block.spaceBeforeMm === null ? `${defBefore}px` : `${block.spaceBeforeMm}mm`};`,
    `margin-bottom: ${block.spaceAfterMm === null ? `${defAfter}px` : `${block.spaceAfterMm}mm`};`,
    block.minHeightMm !== null ? `min-height: ${block.minHeightMm}mm;` : '',
    block.indentMm !== null ? `padding-left: ${block.indentMm}mm;` : '',
    block.offsetXMm || block.offsetYMm ? `position: relative; left: ${block.offsetXMm}mm; top: ${block.offsetYMm}mm;` : '',
    block.fontSizePt !== null ? `font-size: ${block.fontSizePt}pt;` : '',
    block.bold ? 'font-weight: 700;' : '',
    block.underline ? 'text-decoration: underline;' : '',
  ].join(' ').replace(/\s+/g, ' ').trim();
  return `<div class="blk" data-block="${htmlEscape(block.id)}" style="${style}">${blockInner(block, ctx)}</div>`;
}

// ── ทั้งหน้า ───────────────────────────────────────────────────

export function renderDocument(template: FormTemplate, ctx: RenderContext, opts: RenderOptions = {}): string {
  const p = template.paper;
  const { widthMm, heightMm } = paperDimensions(p);
  const m = p.margin;
  const availW = mmToPx(widthMm - m.left - m.right);
  const availH = mmToPx(heightMm - m.top - m.bottom);
  const body = template.blocks.filter((b) => b.visible).map((b) => blockHtml(b, ctx)).join('\n    ');

  const editorCss = opts.editor
    ? `@media screen {
      .blk { cursor: pointer; }
      .blk:hover { outline: 1px dashed rgba(59,130,246,.6); outline-offset: 1px; }
      ${opts.selectedBlockId ? `.blk[data-block="${htmlEscape(opts.selectedBlockId)}"] { outline: 2px solid #3b82f6; outline-offset: 2px; background: rgba(59,130,246,.05); }` : ''}
    }`
    : '';

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>${htmlEscape(ctx.title)}</title>
  <style>
    @page { size: ${widthMm}mm ${heightMm}mm; margin: 0; }
    * { box-sizing: border-box; }
    body { margin: 0; background: #475569; font-family: ${p.fontFamily}; color: #111; }
    .page { width: ${widthMm}mm; min-height: ${heightMm}mm; margin: 0 auto; padding: ${m.top}mm ${m.right}mm ${m.bottom}mm ${m.left}mm; background: white; font-size: ${p.fontSizePt}pt; line-height: ${p.lineHeight}; }
    .top { display: grid; grid-template-columns: 165px 1fr 180px; align-items: start; }
    h1 { text-align: center; font-size: 1.142857em; margin: 0; text-decoration: underline; }
    h2 { text-align: center; font-size: 0.928571em; margin: 0; font-weight: 400; }
    .receive { border: 1px solid #111; padding: 10px 12px; font-size: 0.857143em; line-height: 1.8; }
    .textbox strong, .sig-box strong { font-weight: 700; }
    .row { display: flex; align-items: baseline; gap: 6px; }
    .line { border-bottom: 1px dotted #aaa; min-height: 20px; padding: 0 8px 1px; text-align: center; font-weight: 600; display: inline-block; white-space: nowrap; }
    .grow { flex: 1; }
    .leave-block { display: grid; grid-template-columns: 78px 115px 62px 1fr; align-items: start; }
    .checks { display: grid; gap: 2px; }
    .checkline { display: flex; align-items: center; gap: 7px; height: 22px; }
    .check { width: 14px; height: 14px; border: 1px solid #111; display: inline-flex; align-items: center; justify-content: center; font-size: 0.928571em; line-height: 1; margin-right: 6px; }
    .brace { display: block; width: 26px; margin: 0 auto; }
    .brace svg { display: block; width: 100%; height: 100%; }
    .bottom { display: grid; grid-template-columns: 1fr 1.04fr; gap: 46px; align-items: end; }
    .stats-title { text-align: center; font-weight: 700; font-size: 0.857143em; margin-bottom: 8px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #333; padding: 4px 5px; text-align: center; font-size: 0.785714em; line-height: 1.25; }
    table.members th, table.members td { font-size: 1em; padding: 3px 8px; text-align: left; }
    table.members th, table.members td.c { text-align: center; }
    .signature { text-align: center; margin-top: 14px; line-height: 1.35; }
    .sig-box { line-height: 1.35; }
    .comment { margin-top: 26px; font-size: 0.857143em; font-weight: 700; }
    .order { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 22px; }
    .toolbar { position: fixed; right: 16px; top: 16px; }
    .toolbar button { padding: 8px 12px; border: 0; background: #0f172a; color: white; border-radius: 6px; cursor: pointer; }
    .reason-section { display: grid; grid-template-columns: max-content minmax(0, 1fr); column-gap: 6px; align-items: start; margin: 0 0 4px; min-width: 0; }
    .reason-label { grid-column: 1; white-space: nowrap; }
    .reason-text { grid-column: 2; min-width: 0; white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; }
    .reason-underline { grid-column: 2; border-bottom: 1px dotted #aaa; margin-top: 4px; }
    @media print { body { background: white; } .toolbar { display: none; } .page { margin: 0; box-shadow: none; } }
    ${editorCss}
  </style>
</head>
<body>
  ${opts.toolbar ? '<div class="toolbar"><button onclick="window.print()">พิมพ์ / บันทึก PDF</button></div>' : ''}
  <main class="page" data-avail-w="${availW}" data-avail-h="${availH}">
    <div class="content">
    ${body}
    </div>
  </main>
${p.fitToPage ? FIT_SCRIPT : ''}${opts.autoPrint ? PRINT_SCRIPT : ''}</body>
</html>
`;
}

/**
 * ย่อเนื้อหาทั้งหน้าให้พอดีกระดาษหน้าเดียว
 * ขยายกล่องเนื้อหาให้กว้างขึ้นแล้ว scale ลง (ข้อความไหลใหม่ตามความกว้าง) คำนวณซ้ำจนนิ่ง
 * ผลลัพธ์เก็บไว้ที่ data-fit-scale ให้ตัวแก้ไขแสดง "ย่อเหลือ xx%"
 */
const FIT_SCRIPT = `<script>
  (function () {
    function fit() {
      var page = document.querySelector('.page');
      var c = document.querySelector('.content');
      if (!page || !c) return;
      c.style.transform = ''; c.style.width = ''; c.style.marginBottom = '';
      var w = parseFloat(page.dataset.availW), h = parseFloat(page.dataset.availH), k = 1;
      for (var i = 0; i < 8; i++) {
        c.style.width = (w / k) + 'px';
        var nk = Math.min(1, h / c.scrollHeight, (w / k) / c.scrollWidth * k);
        if (Math.abs(nk - k) < 0.002) { k = nk; break; }
        k = nk;
      }
      if (k < 1) {
        c.style.width = (w / k) + 'px';
        c.style.transformOrigin = 'top left';
        c.style.transform = 'scale(' + k + ')';
        c.style.marginBottom = (-(c.scrollHeight * (1 - k))) + 'px';
      } else {
        c.style.width = '';
      }
      page.dataset.fitScale = String(k);
    }
    fit();
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(fit);
    window.addEventListener('load', fit);
  })();
</script>
`;

const PRINT_SCRIPT = `<script>
  window.addEventListener('load', function() {
    setTimeout(function() {
      window.focus();
      window.print();
    }, 350);
  });
</script>
`;
