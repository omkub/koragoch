/// ตัววาดเอกสารจากแม่แบบ → HTML (หน่วยมิลลิเมตร พิมพ์ได้ขนาดกระดาษจริง)
///
/// แปลมาจาก central/src/forms/render.ts ทีละบรรทัด ต้องได้ HTML เดียวกัน
/// ทุกตัวอักษร — test/form_render_parity_test.dart เทียบกับ HTML ที่ web วาดจริง
/// แก้ไฟล์หนึ่งต้องแก้อีกไฟล์ให้ตรงกัน แล้วรัน cd central && npm run form-fixtures
///
/// ข้อควรระวังเวลาแก้:
///   - ตัวเลขต้องเขียนแบบ JavaScript (10 ไม่ใช่ 10.0) ใช้ [jsNum] เสมอ
///   - ขึ้นบรรทัดใน HTML เขียนเป็น \n ตรง ๆ ไม่ใช้สตริงหลายบรรทัด
///     (ไฟล์ใน Windows อาจเป็น CRLF ทำให้ได้ \r\n แต่ web ได้ \n เสมอ)
library;

import '../widgets/leave_form_data.dart' show LeaveStatRow;
import 'form_template.dart';

/// ข้อมูลที่ใช้เติมแม่แบบ (RenderContext ใน web)
class RenderContext {
  /// ชื่อแท็บ / ชื่อไฟล์ PDF
  final String title;

  /// ตัวแทนข้อมูล {ชื่อ} → ค่า (ยังไม่ escape)
  final Map<String, String> values;

  /// เงื่อนไขช่องติ๊ก
  final Map<String, bool> flags;

  /// ใบลา: ช่องติ๊กประเภทการลา
  final List<({String label, bool checked})>? leaveTypes;
  final String? reason;
  final List<LeaveStatRow>? stats;

  /// ไปราชการ: ผู้ร่วมเดินทาง
  final List<({String name, String position})>? members;

  const RenderContext({
    required this.title,
    this.values = const {},
    this.flags = const {},
    this.leaveTypes,
    this.reason,
    this.stats,
    this.members,
  });
}

class RenderOptions {
  /// ปุ่มพิมพ์ลอยมุมขวาบน (หน้าพิมพ์)
  final bool toolbar;

  /// เปิดหน้าต่างพิมพ์ให้เองเมื่อโหลดเสร็จ
  final bool autoPrint;

  /// โหมดตัวแก้ไข: กรอบบรรทัดเมื่อชี้ + ไฮไลต์บรรทัดที่เลือก
  final bool editor;
  final String? selectedBlockId;

  const RenderOptions({
    this.toolbar = false,
    this.autoPrint = false,
    this.editor = false,
    this.selectedBlockId,
  });
}

// ── ตัวช่วย ────────────────────────────────────────────────────

/// ตัวเลขแบบที่ JavaScript แปลงเป็นข้อความ (`${n}`): 10 → "10", 10.5 → "10.5"
String jsNum(num n) {
  if (n is int) return '$n';
  final d = n.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15) {
    return '${d.toInt()}';
  }
  return d.toString();
}

/// htmlEscape ของ web (leaveFormHtml.ts)
String htmlEscape(String? value) {
  final text = value ?? '-';
  return text.replaceAllMapped(RegExp('[&<>"\'/]'), (m) {
    switch (m[0]) {
      case '&':
        return '&amp;';
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '"':
        return '&quot;';
      case "'":
        return '&#39;';
      default:
        return '&#47;';
    }
  });
}

/// 1 มม. = 3.7795 px (96 dpi) — คำนวณลำดับเดียวกับ web ให้ได้ทศนิยมตรงกัน
const double _pxPerMm = 96 / 25.4;
double _mmToPx(double mm) => mm * _pxPerMm;

// ── ข้อความ + ตัวแทนข้อมูล ─────────────────────────────────────

final _placeholder = RegExp(r'\{[^{}]+\}');
final _inlineField = RegExp(r'\[\[[^\[\]]*\]\]');

/// แทน {ชื่อ} ด้วยค่า, **ตัวหนา** และ [[ข้อความ]] = ช่องเส้นประในบรรทัด
/// — ตัวแทนที่ไม่รู้จักแสดงตามเดิมให้เห็นว่าพิมพ์ผิด
String renderText(String template, RenderContext ctx) {
  String values(String part) => part.splitMapJoin(
        _placeholder,
        onMatch: (m) {
          final key = m[0]!.substring(1, m[0]!.length - 1);
          return ctx.values.containsKey(key)
              ? htmlEscape(ctx.values[key])
              : htmlEscape(m[0]);
        },
        onNonMatch: (s) => s.isEmpty ? '' : htmlEscape(s),
      );
  String sub(String part) => part.splitMapJoin(
        _inlineField,
        onMatch: (m) =>
            '<span class="line inline">${values(m[0]!.substring(2, m[0]!.length - 2))}</span>',
        onNonMatch: values,
      );
  final parts = template.split('**');
  final balanced = parts.length % 2 == 1;
  final out = StringBuffer();
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (i % 2 == 0) {
      out.write(sub(part));
    } else if (!balanced && i == parts.length - 1) {
      // ** ตัวสุดท้ายที่ไม่มีคู่ปิด แสดงตามที่พิมพ์
      out.write(htmlEscape('**') + sub(part));
    } else {
      out.write('<strong>${sub(part)}</strong>');
    }
  }
  return out.toString();
}

String _lines(List<String> list, RenderContext ctx) =>
    list.map((l) => renderText(l, ctx)).join('<br>');

/// ช่องติ๊กแบบเดิมของใบลา
String _checkbox(String label, bool checked) =>
    '<span style="display: inline-flex; align-items: center; white-space: nowrap;">'
    '<span class="check">${checked ? '✓' : ''}</span><span>$label</span></span>';

bool _flag(RenderContext ctx, String key) =>
    key != alwaysUnchecked && (ctx.flags[key] ?? false);

// ── บรรทัดแต่ละชนิด ────────────────────────────────────────────

const _justify = {
  'left': 'flex-start',
  'center': 'center',
  'right': 'flex-end',
  'justify': 'space-between',
};

String _segmentHtml(Segment seg, RenderContext ctx) {
  switch (seg) {
    case TextSegment():
      final tag = seg.bold ? 'strong' : 'span';
      final style = seg.nowrap ? ' style="white-space: nowrap;"' : '';
      return '<$tag$style>${renderText(seg.text, ctx)}</$tag>';
    case FieldSegment():
      final cls =
          'line${seg.widthMm == null ? ' grow' : ''}${seg.noLine ? ' no-line' : ''}';
      final style =
          seg.widthMm == null ? '' : ' style="width: ${jsNum(seg.widthMm!)}mm"';
      return '<span class="$cls"$style>${renderText(seg.text, ctx)}</span>';
    case CheckboxSegment():
      return '<span>${_checkbox(renderText(seg.label, ctx), _flag(ctx, seg.flag))}</span>';
  }
}

String _boxMargin(String pos) => pos == 'right'
    ? 'margin-left: auto;'
    : pos == 'center'
        ? 'margin-left: auto; margin-right: auto;'
        : '';

String _blockInner(Block block, RenderContext ctx) {
  final align = block.common.align;
  switch (block) {
    case RowBlock():
      final justify =
          align != null ? ' style="justify-content: ${_justify[align]}"' : '';
      return '<div class="row"$justify>${block.segments.map((s) => _segmentHtml(s, ctx)).join()}</div>';

    case TextBoxBlock():
      final style = [
        block.boxWidthMm != null ? 'width: ${jsNum(block.boxWidthMm!)}mm;' : '',
        _boxMargin(block.boxPosition),
        'text-align: ${align ?? 'left'};',
        block.firstLineIndentMm != 0
            ? 'text-indent: ${jsNum(block.firstLineIndentMm)}mm;'
            : '',
      ].join(' ').trim();
      return '<section class="textbox" style="$style">${_lines(block.lines, ctx)}</section>';

    case HeaderBlock():
      final receive = block.showReceiveBox
          ? '<div class="receive">${_lines(block.receiveLines, ctx)}</div>'
          : '<div></div>';
      final sub = block.subtitle.isNotEmpty
          ? '<h2>${renderText(block.subtitle, ctx)}</h2>'
          : '';
      return '<section class="top">\n'
          '      <div></div>\n'
          '      <div><h1>${renderText(block.title, ctx)}</h1>$sub</div>\n'
          '      $receive\n'
          '    </section>';

    case LeaveTypesBlock():
      final types = ctx.leaveTypes ?? const [];
      final checks = types
          .map((t) =>
              '<div class="checkline">${_checkbox(htmlEscape(t.label), t.checked)}</div>')
          .join();
      // ความสูงปีกกา = จำนวนบรรทัด × 22px + ช่องไฟ 2px (ตรงกับ .checkline / .checks)
      final braceHeight = types.length * 22 + (types.length - 1) * 2;
      final brace = block.showBrace
          ? '<div class="brace" style="height: ${braceHeight}px">\n'
              '        <svg viewBox="0 0 20 100" preserveAspectRatio="none" aria-hidden="true">\n'
              '          <path d="M4 1 C13 1 11 9 11 22 C11 38 11 46 18 50 C11 54 11 62 11 78 C11 91 13 99 4 99"\n'
              '                fill="none" stroke="rgba(0,0,0,0.55)" stroke-width="1.4"\n'
              '                stroke-linecap="round" vector-effect="non-scaling-stroke" />\n'
              '        </svg>\n'
              '      </div>'
          : '<div></div>';
      return '<section class="leave-block">\n'
          '      <strong>${renderText(block.label, ctx)}</strong>\n'
          '      <div class="checks">\n'
          '        $checks\n'
          '      </div>\n'
          '      $brace\n'
          '      <div class="reason-section" style="padding-top: 34px;">\n'
          '        <span class="reason-label">${renderText(block.reasonLabel, ctx)}</span>\n'
          '        <div class="reason-text">${htmlEscape(ctx.reason ?? '')}</div>\n'
          '        <div class="reason-underline"></div>\n'
          '      </div>\n'
          '    </section>';

    case ApprovalBlock():
      final stats = (ctx.stats ?? const <LeaveStatRow>[])
          .map((row) => '<tr><td>${htmlEscape(row.label)}</td>'
              '<td>${htmlEscape(row.previousTimes)}</td><td>${htmlEscape(row.previousDays)}</td>'
              '<td>${htmlEscape(row.currentTimes)}</td><td>${htmlEscape(row.currentDays)}</td>'
              '<td>${htmlEscape(row.totalTimes)}</td><td>${htmlEscape(row.totalDays)}</td></tr>')
          .join();
      final left = block.showStats
          ? '<div>\n'
              '        <div class="stats-title">${renderText(block.statsTitle, ctx)}</div>\n'
              '        <table>\n'
              '          <thead>\n'
              '            <tr><th rowspan="2">ประเภทการลา</th><th colspan="2">ลามาแล้ว</th><th colspan="2">ลาครั้งนี้</th><th colspan="2">รวมเป็น</th></tr>\n'
              '            <tr><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th></tr>\n'
              '          </thead>\n'
              '          <tbody>$stats</tbody>\n'
              '        </table>\n'
              '        <div class="signature">${_lines(block.hrLines, ctx)}</div>\n'
              '      </div>'
          : '<div><div class="signature">${_lines(block.hrLines, ctx)}</div></div>';
      final comment = block.showComment
          ? '<div class="comment">${renderText(block.commentLabel, ctx)}</div><div class="line grow" style="width:100%; margin-top:4px;"></div>'
          : '';
      final order = block.showOrder
          ? '<div class="order"><strong>${renderText(block.orderLabel, ctx)}</strong>${block.orderOptions.map((o) => '<span>${_checkbox(renderText(o, ctx), false)}</span>').join()}</div>'
          : '';
      return '<section class="bottom">\n'
          '      $left\n'
          '      <div>\n'
          '        <div class="signature" style="margin-top:0;">${_lines(block.applicantLines, ctx)}</div>\n'
          '        $comment\n'
          '        <div class="signature">${_lines(block.deputyLines, ctx)}</div>\n'
          '        $order\n'
          '        <div class="signature">${_lines(block.directorLines, ctx)}</div>\n'
          '      </div>\n'
          '    </section>';

    case MemberTableBlock():
      final members = ctx.members ?? const [];
      final h = block.headers;
      final head = [
        '<th style="width: 12mm">${renderText(h.no, ctx)}</th>',
        '<th>${renderText(h.name, ctx)}</th>',
        block.showPosition ? '<th>${renderText(h.position, ctx)}</th>' : '',
        block.showSignature
            ? '<th style="width: 35mm">${renderText(h.signature, ctx)}</th>'
            : '',
      ].join();
      final body = [
        for (var i = 0; i < members.length; i++)
          '<tr><td class="c">${i + 1}</td><td>${htmlEscape(members[i].name)}</td>'
              '${block.showPosition ? '<td>${htmlEscape(members[i].position.isEmpty ? '-' : members[i].position)}</td>' : ''}'
              '${block.showSignature ? '<td></td>' : ''}'
              '</tr>',
      ].join();
      return '<table class="members"><thead><tr>$head</tr></thead><tbody>$body</tbody></table>';

    case SignatureBlock():
      final style = [
        block.boxWidthMm != null ? 'width: ${jsNum(block.boxWidthMm!)}mm;' : '',
        _boxMargin(block.boxPosition),
        'text-align: ${align ?? 'center'};',
      ].join(' ').trim();
      return '<div class="sig-box" style="$style">${_lines(block.lines, ctx)}</div>';

    case SpacerBlock():
      return '<div style="height: ${jsNum(block.heightMm)}mm"></div>';
  }
}

/// ระยะเว้นของบรรทัดที่ไม่ได้ตั้ง (ค่าเดิมของชนิดนั้น) — px ตามใบลาเดิม
const Map<String, (int, int)> blockDefaultSpacePx = {
  'row': (4, 4),
  'textBox': (4, 4),
  'header': (0, 0),
  'leaveTypes': (10, 10),
  'approval': (28, 0),
  'memberTable': (8, 8),
  'signature': (14, 0),
  'spacer': (0, 0),
};

String _blockHtml(Block block, RenderContext ctx) {
  final b = block.common;
  final (defBefore, defAfter) = blockDefaultSpacePx[block.type]!;
  final style = [
    'margin-top: ${b.spaceBeforeMm == null ? '${defBefore}px' : '${jsNum(b.spaceBeforeMm!)}mm'};',
    'margin-bottom: ${b.spaceAfterMm == null ? '${defAfter}px' : '${jsNum(b.spaceAfterMm!)}mm'};',
    b.minHeightMm != null ? 'min-height: ${jsNum(b.minHeightMm!)}mm;' : '',
    b.indentMm != null ? 'padding-left: ${jsNum(b.indentMm!)}mm;' : '',
    b.offsetXMm != 0 || b.offsetYMm != 0
        ? 'position: relative; left: ${jsNum(b.offsetXMm)}mm; top: ${jsNum(b.offsetYMm)}mm;'
        : '',
    b.fontSizePt != null ? 'font-size: ${jsNum(b.fontSizePt!)}pt;' : '',
    b.bold ? 'font-weight: 700;' : '',
    b.underline ? 'text-decoration: underline;' : '',
  ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return '<div class="blk" data-block="${htmlEscape(b.id)}" style="$style">${_blockInner(block, ctx)}</div>';
}

// ── ทั้งหน้า ───────────────────────────────────────────────────

String renderDocument(FormTemplate template, RenderContext ctx,
    [RenderOptions opts = const RenderOptions()]) {
  final p = template.paper;
  final dims = p.dimensions;
  final widthMm = jsNum(dims.widthMm);
  final heightMm = jsNum(dims.heightMm);
  final m = p.margin;
  final availW = _mmToPx(dims.widthMm - m.left - m.right);
  final availH = _mmToPx(dims.heightMm - m.top - m.bottom);
  final body = template.blocks
      .where((b) => b.common.visible)
      .map((b) => _blockHtml(b, ctx))
      .join('\n    ');

  final selected = opts.selectedBlockId;
  final editorCss = opts.editor
      ? '@media screen {\n'
          '      .blk { cursor: pointer; }\n'
          '      .blk:hover { outline: 1px dashed rgba(59,130,246,.6); outline-offset: 1px; }\n'
          '      ${selected != null && selected.isNotEmpty ? '.blk[data-block="${htmlEscape(selected)}"] { outline: 2px solid #3b82f6; outline-offset: 2px; background: rgba(59,130,246,.05); }' : ''}\n'
          '    }'
      : '';

  return '<!doctype html>\n'
      '<html>\n'
      '<head>\n'
      '  <meta charset="utf-8">\n'
      '  <title>${htmlEscape(ctx.title)}</title>\n'
      '  <style>\n'
      '    @page { size: ${widthMm}mm ${heightMm}mm; margin: 0; }\n'
      '    * { box-sizing: border-box; }\n'
      '    body { margin: 0; background: #475569; font-family: ${p.fontFamily}; color: #111; }\n'
      '    .page { width: ${widthMm}mm; min-height: ${heightMm}mm; margin: 0 auto; padding: ${jsNum(m.top)}mm ${jsNum(m.right)}mm ${jsNum(m.bottom)}mm ${jsNum(m.left)}mm; background: white; font-size: ${jsNum(p.fontSizePt)}pt; line-height: ${jsNum(p.lineHeight)}; }\n'
      '    .top { display: grid; grid-template-columns: 165px 1fr 180px; align-items: start; }\n'
      '    h1 { text-align: center; font-size: 1.142857em; margin: 0; text-decoration: underline; }\n'
      '    h2 { text-align: center; font-size: 0.928571em; margin: 0; font-weight: 400; }\n'
      '    .receive { border: 1px solid #111; padding: 10px 12px; font-size: 0.857143em; line-height: 1.8; }\n'
      '    .textbox strong, .sig-box strong { font-weight: 700; }\n'
      '    .row { display: flex; align-items: baseline; gap: 6px; }\n'
      '    .line { border-bottom: 1px dotted #aaa; min-height: 20px; padding: 0 8px 1px; text-align: center; font-weight: 600; display: inline-block; white-space: nowrap; }\n'
      '    .line.no-line { border-bottom-color: transparent; }\n'
      '    .line.inline { min-height: 0; padding: 0 12px 1px; text-indent: 0; }\n'
      '    .grow { flex: 1; }\n'
      '    .leave-block { display: grid; grid-template-columns: 78px 115px 62px 1fr; align-items: start; }\n'
      '    .checks { display: grid; gap: 2px; }\n'
      '    .checkline { display: flex; align-items: center; gap: 7px; height: 22px; }\n'
      '    .check { width: 14px; height: 14px; border: 1px solid #111; display: inline-flex; align-items: center; justify-content: center; font-size: 0.928571em; line-height: 1; margin-right: 6px; }\n'
      '    .brace { display: block; width: 26px; margin: 0 auto; }\n'
      '    .brace svg { display: block; width: 100%; height: 100%; }\n'
      '    .bottom { display: grid; grid-template-columns: 1fr 1.04fr; gap: 46px; align-items: end; }\n'
      '    .stats-title { text-align: center; font-weight: 700; font-size: 0.857143em; margin-bottom: 8px; }\n'
      '    table { width: 100%; border-collapse: collapse; }\n'
      '    th, td { border: 1px solid #333; padding: 4px 5px; text-align: center; font-size: 0.785714em; line-height: 1.25; }\n'
      '    table.members th, table.members td { font-size: 1em; padding: 3px 8px; text-align: left; }\n'
      '    table.members th, table.members td.c { text-align: center; }\n'
      '    .signature { text-align: center; margin-top: 14px; line-height: 1.35; }\n'
      '    .sig-box { line-height: 1.35; }\n'
      '    .comment { margin-top: 26px; font-size: 0.857143em; font-weight: 700; }\n'
      '    .order { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 22px; }\n'
      '    .toolbar { position: fixed; right: 16px; top: 16px; }\n'
      '    .toolbar button { padding: 8px 12px; border: 0; background: #0f172a; color: white; border-radius: 6px; cursor: pointer; }\n'
      '    .reason-section { display: grid; grid-template-columns: max-content minmax(0, 1fr); column-gap: 6px; align-items: start; margin: 0 0 4px; min-width: 0; }\n'
      '    .reason-label { grid-column: 1; white-space: nowrap; }\n'
      '    .reason-text { grid-column: 2; min-width: 0; white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; }\n'
      '    .reason-underline { grid-column: 2; border-bottom: 1px dotted #aaa; margin-top: 4px; }\n'
      '    @media print { body { background: white; } .toolbar { display: none; } .page { margin: 0; box-shadow: none; } }\n'
      '    $editorCss\n'
      '  </style>\n'
      '</head>\n'
      '<body>\n'
      '  ${opts.toolbar ? '<div class="toolbar"><button onclick="window.print()">พิมพ์ / บันทึก PDF</button></div>' : ''}\n'
      '  <main class="page" data-avail-w="${jsNum(availW)}" data-avail-h="${jsNum(availH)}">\n'
      '    <div class="content">\n'
      '    $body\n'
      '    </div>\n'
      '  </main>\n'
      '${p.fitToPage ? _fitScript : ''}${opts.autoPrint ? _printScript : ''}</body>\n'
      '</html>\n';
}

/// ย่อเนื้อหาทั้งหน้าให้พอดีกระดาษหน้าเดียว (FIT_SCRIPT ใน web)
const String _fitScript = '<script>\n'
    '  (function () {\n'
    '    function fit() {\n'
    "      var page = document.querySelector('.page');\n"
    "      var c = document.querySelector('.content');\n"
    '      if (!page || !c) return;\n'
    "      c.style.transform = ''; c.style.width = ''; c.style.marginBottom = '';\n"
    '      var w = parseFloat(page.dataset.availW), h = parseFloat(page.dataset.availH), k = 1;\n'
    '      for (var i = 0; i < 8; i++) {\n'
    "        c.style.width = (w / k) + 'px';\n"
    '        var nk = Math.min(1, h / c.scrollHeight, (w / k) / c.scrollWidth * k);\n'
    '        if (Math.abs(nk - k) < 0.002) { k = nk; break; }\n'
    '        k = nk;\n'
    '      }\n'
    '      if (k < 1) {\n'
    "        c.style.width = (w / k) + 'px';\n"
    "        c.style.transformOrigin = 'top left';\n"
    "        c.style.transform = 'scale(' + k + ')';\n"
    "        c.style.marginBottom = (-(c.scrollHeight * (1 - k))) + 'px';\n"
    '      } else {\n'
    "        c.style.width = '';\n"
    '      }\n'
    '      page.dataset.fitScale = String(k);\n'
    '    }\n'
    '    fit();\n'
    '    if (document.fonts && document.fonts.ready) document.fonts.ready.then(fit);\n'
    "    window.addEventListener('load', fit);\n"
    '  })();\n'
    '</script>\n';

const String _printScript = '<script>\n'
    "  window.addEventListener('load', function() {\n"
    '    setTimeout(function() {\n'
    '      window.focus();\n'
    '      window.print();\n'
    '    }, 350);\n'
    '  });\n'
    '</script>\n';
