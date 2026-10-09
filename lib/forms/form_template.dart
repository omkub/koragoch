/// แม่แบบฟอร์ม (ใบลา / ใบขออนุญาตไปราชการ) ที่ออกแบบจากหน้าแบบฟอร์มใน web
///
/// โครงสร้างตรงกับ central/src/forms/template.ts ทุกช่อง:
/// แม่แบบ = ตั้งค่ากระดาษ + รายการบรรทัด/กล่อง (blocks) เรียงจากบนลงล่าง
/// เก็บเป็น JSON ในตาราง FormTemplates (supabase/form_templates.sql)
///
/// ค่าตั้งของบรรทัดที่เป็น null = "ค่าเดิม" ของบรรทัดชนิดนั้น (ตัววาดเป็นผู้ตัดสิน)
/// ไฟล์นี้ไม่ยุ่งกับ UI และฐานข้อมูล จึงเขียนเทสได้ตรง ๆ
library;

enum FormType {
  leave('leave'),
  trip('trip');

  final String key;
  const FormType(this.key);

  static FormType? fromKey(Object? key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

// ── ตัวช่วยอ่าน JSON ─────────────────────────────────────────────
//
// แม่แบบที่บันทึกไว้ก่อนเพิ่มฟีเจอร์ใหม่อาจไม่มีบางช่อง หรือชนิดไม่ตรง
// อ่านแบบไม่ล้ม: ค่าที่ใช้ไม่ได้ = ค่าตั้งต้น (ตรงกับที่ web มองเป็น undefined)

double? _numOrNull(Object? v) => v is num ? v.toDouble() : null;
double _num(Object? v, double fallback) => _numOrNull(v) ?? fallback;
String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;
List<String> _strings(Object? v) =>
    v is List ? [for (final x in v) if (x is String) x] : const [];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

/// เลขแบบที่ JSON.stringify ของ web เขียน (10 ไม่ใช่ 10.0)
Object? _jsonNum(double? v) =>
    v == null ? null : (v == v.roundToDouble() && v.abs() < 1e15 ? v.toInt() : v);

// ── กระดาษ ─────────────────────────────────────────────────────

class PaperMargin {
  final double top, right, bottom, left;

  const PaperMargin(
      {required this.top,
      required this.right,
      required this.bottom,
      required this.left});

  PaperMargin merge(Map<String, dynamic> raw) => PaperMargin(
        top: _num(raw['top'], top),
        right: _num(raw['right'], right),
        bottom: _num(raw['bottom'], bottom),
        left: _num(raw['left'], left),
      );

  Map<String, Object?> toJson() => {
        'top': _jsonNum(top),
        'right': _jsonNum(right),
        'bottom': _jsonNum(bottom),
        'left': _jsonNum(left),
      };
}

class PaperSettings {
  /// A4 / A5 / Letter / custom
  final String size;

  /// ใช้เมื่อ size = custom (แนวตั้ง)
  final double widthMm;
  final double heightMm;

  /// portrait / landscape
  final String orientation;
  final PaperMargin margin;
  final String fontFamily;
  final double fontSizePt;
  final double lineHeight;

  /// เนื้อหาเกินหน้า → ย่อทั้งหน้าให้พอดีกระดาษหน้าเดียว
  final bool fitToPage;

  const PaperSettings({
    required this.size,
    required this.widthMm,
    required this.heightMm,
    required this.orientation,
    required this.margin,
    required this.fontFamily,
    required this.fontSizePt,
    required this.lineHeight,
    required this.fitToPage,
  });

  static const presets = {
    'A4': (widthMm: 210.0, heightMm: 297.0),
    'A5': (widthMm: 148.0, heightMm: 210.0),
    'Letter': (widthMm: 215.9, heightMm: 279.4),
  };

  /// ค่าที่ส่งมาทับค่าเดิม (ช่องที่ขาด/ใช้ไม่ได้ = ค่าเดิม) — แบบ { ...fallback, ...raw } ใน web
  PaperSettings merge(Map<String, dynamic> raw) => PaperSettings(
        size: _str(raw['size'], size),
        widthMm: _num(raw['widthMm'], widthMm),
        heightMm: _num(raw['heightMm'], heightMm),
        orientation: _str(raw['orientation'], orientation),
        margin: margin.merge(_map(raw['margin'])),
        fontFamily: _str(raw['fontFamily'], fontFamily),
        fontSizePt: _num(raw['fontSizePt'], fontSizePt),
        lineHeight: _num(raw['lineHeight'], lineHeight),
        fitToPage: _bool(raw['fitToPage'], fitToPage),
      );

  /// ขนาดกระดาษจริงตามแนว (มม.)
  ({double widthMm, double heightMm}) get dimensions {
    final base = presets[size] ?? (widthMm: widthMm, heightMm: heightMm);
    final short =
        base.widthMm < base.heightMm ? base.widthMm : base.heightMm;
    final long = base.widthMm < base.heightMm ? base.heightMm : base.widthMm;
    return orientation == 'landscape'
        ? (widthMm: long, heightMm: short)
        : (widthMm: short, heightMm: long);
  }

  Map<String, Object?> toJson() => {
        'size': size,
        'widthMm': _jsonNum(widthMm),
        'heightMm': _jsonNum(heightMm),
        'orientation': orientation,
        'margin': margin.toJson(),
        'fontFamily': fontFamily,
        'fontSizePt': _jsonNum(fontSizePt),
        'lineHeight': _jsonNum(lineHeight),
        'fitToPage': fitToPage,
      };
}

// ── ส่วนย่อยของบรรทัดข้อความ ───────────────────────────────────

sealed class Segment {
  const Segment();

  static Segment? fromJson(Object? raw) {
    final m = _map(raw);
    switch (m['kind']) {
      case 'text':
        return TextSegment(
            text: _str(m['text']),
            bold: _bool(m['bold']),
            nowrap: _bool(m['nowrap']));
      case 'field':
        return FieldSegment(
            text: _str(m['text']),
            widthMm: _numOrNull(m['widthMm']),
            noLine: _bool(m['noLine']));
      case 'checkbox':
        return CheckboxSegment(
            label: _str(m['label']), flag: _str(m['flag']));
    }
    return null;
  }

  Map<String, Object?> toJson();
}

class TextSegment extends Segment {
  final String text;
  final bool bold;
  final bool nowrap;
  const TextSegment({required this.text, this.bold = false, this.nowrap = false});

  @override
  Map<String, Object?> toJson() => {
        'kind': 'text',
        'text': text,
        if (bold) 'bold': true,
        if (nowrap) 'nowrap': true,
      };
}

/// ช่องกรอก — widthMm null = ยืดเต็มที่ว่าง, noLine = ไม่แสดงเส้นประใต้ช่อง
class FieldSegment extends Segment {
  final String text;
  final double? widthMm;
  final bool noLine;
  const FieldSegment({required this.text, this.widthMm, this.noLine = false});

  @override
  Map<String, Object?> toJson() => {
        'kind': 'field',
        'text': text,
        'widthMm': _jsonNum(widthMm),
        if (noLine) 'noLine': true,
      };
}

/// ช่องติ๊ก — ติ๊กเมื่อเงื่อนไข (flag) เป็นจริง
class CheckboxSegment extends Segment {
  final String label;
  final String flag;
  const CheckboxSegment({required this.label, required this.flag});

  @override
  Map<String, Object?> toJson() => {'kind': 'checkbox', 'label': label, 'flag': flag};
}

// ── บรรทัด / กล่อง ─────────────────────────────────────────────

/// ค่าตั้งที่ทุกบรรทัดมีเหมือนกัน (BlockCommon ใน web)
class BlockCommon {
  final String id;
  final String name;
  final bool visible;
  final bool builtIn;
  final double? spaceBeforeMm;
  final double? spaceAfterMm;
  final double? minHeightMm;
  final double? indentMm;
  final double offsetXMm;
  final double offsetYMm;

  /// left / center / right / justify (null = ค่าเดิม)
  final String? align;
  final double? fontSizePt;
  final bool bold;
  final bool underline;

  const BlockCommon({
    required this.id,
    required this.name,
    this.visible = true,
    this.builtIn = false,
    this.spaceBeforeMm,
    this.spaceAfterMm,
    this.minHeightMm,
    this.indentMm,
    this.offsetXMm = 0,
    this.offsetYMm = 0,
    this.align,
    this.fontSizePt,
    this.bold = false,
    this.underline = false,
  });

  static const _aligns = {'left', 'center', 'right', 'justify'};

  /// ช่องที่ขาด = ค่าของ commonDefaults() ใน web
  factory BlockCommon.fromJson(Map<String, dynamic> m) => BlockCommon(
        id: _str(m['id']),
        name: _str(m['name']),
        visible: _bool(m['visible'], true),
        builtIn: _bool(m['builtIn']),
        spaceBeforeMm: _numOrNull(m['spaceBeforeMm']),
        spaceAfterMm: _numOrNull(m['spaceAfterMm']),
        minHeightMm: _numOrNull(m['minHeightMm']),
        indentMm: _numOrNull(m['indentMm']),
        offsetXMm: _num(m['offsetXMm'], 0),
        offsetYMm: _num(m['offsetYMm'], 0),
        align: _aligns.contains(m['align']) ? m['align'] as String : null,
        fontSizePt: _numOrNull(m['fontSizePt']),
        bold: _bool(m['bold']),
        underline: _bool(m['underline']),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'visible': visible,
        'spaceBeforeMm': _jsonNum(spaceBeforeMm),
        'spaceAfterMm': _jsonNum(spaceAfterMm),
        'minHeightMm': _jsonNum(minHeightMm),
        'indentMm': _jsonNum(indentMm),
        'offsetXMm': _jsonNum(offsetXMm),
        'offsetYMm': _jsonNum(offsetYMm),
        'align': align,
        'fontSizePt': _jsonNum(fontSizePt),
        'bold': bold,
        'underline': underline,
        if (builtIn) 'builtIn': true,
      };
}

String _boxPosition(Object? v) =>
    v == 'center' || v == 'right' ? v as String : 'left';

sealed class Block {
  final BlockCommon common;
  const Block(this.common);

  String get type;

  /// ชนิดที่ไม่รู้จัก (แม่แบบจาก web รุ่นใหม่กว่า app) = null → ข้ามบรรทัดนั้น
  static Block? fromJson(Object? raw) {
    final m = _map(raw);
    final c = BlockCommon.fromJson(m);
    switch (m['type']) {
      case 'row':
        return RowBlock(c,
            segments: [
              for (final s in (m['segments'] is List ? m['segments'] as List : const []))
                if (Segment.fromJson(s) case final seg?) seg
            ]);
      case 'textBox':
        return TextBoxBlock(c,
            lines: _strings(m['lines']),
            boxWidthMm: _numOrNull(m['boxWidthMm']),
            boxPosition: _boxPosition(m['boxPosition']),
            firstLineIndentMm: _num(m['firstLineIndentMm'], 0));
      case 'header':
        return HeaderBlock(c,
            title: _str(m['title']),
            subtitle: _str(m['subtitle']),
            showReceiveBox: _bool(m['showReceiveBox']),
            receiveLines: _strings(m['receiveLines']));
      case 'leaveTypes':
        return LeaveTypesBlock(c,
            label: _str(m['label']),
            reasonLabel: _str(m['reasonLabel']),
            showBrace: _bool(m['showBrace']));
      case 'approval':
        return ApprovalBlock(c,
            showStats: _bool(m['showStats']),
            statsTitle: _str(m['statsTitle']),
            hrLines: _strings(m['hrLines']),
            applicantLines: _strings(m['applicantLines']),
            showComment: _bool(m['showComment']),
            commentLabel: _str(m['commentLabel']),
            deputyLines: _strings(m['deputyLines']),
            showOrder: _bool(m['showOrder']),
            orderLabel: _str(m['orderLabel']),
            orderOptions: _strings(m['orderOptions']),
            directorLines: _strings(m['directorLines']));
      case 'memberTable':
        final h = _map(m['headers']);
        return MemberTableBlock(c,
            showPosition: _bool(m['showPosition']),
            showSignature: _bool(m['showSignature']),
            headers: (
              no: _str(h['no']),
              name: _str(h['name']),
              position: _str(h['position']),
              signature: _str(h['signature']),
            ));
      case 'signature':
        return SignatureBlock(c,
            lines: _strings(m['lines']),
            boxWidthMm: _numOrNull(m['boxWidthMm']),
            boxPosition: _boxPosition(m['boxPosition']));
      case 'spacer':
        return SpacerBlock(c, heightMm: _num(m['heightMm'], 0));
    }
    return null;
  }

  Map<String, Object?> fields();

  Map<String, Object?> toJson() => {...common.toJson(), 'type': type, ...fields()};
}

class RowBlock extends Block {
  final List<Segment> segments;
  const RowBlock(super.common, {required this.segments});

  @override
  String get type => 'row';
  @override
  Map<String, Object?> fields() =>
      {'segments': [for (final s in segments) s.toJson()]};
}

/// กล่องข้อความหลายบรรทัด (**ตัวหนา** / [[ช่องเส้นประ]] ได้) วางในกล่องกว้างตามที่ตั้ง
class TextBoxBlock extends Block {
  final List<String> lines;
  final double? boxWidthMm;

  /// left / center / right
  final String boxPosition;
  final double firstLineIndentMm;
  const TextBoxBlock(super.common,
      {required this.lines,
      this.boxWidthMm,
      this.boxPosition = 'left',
      this.firstLineIndentMm = 0});

  @override
  String get type => 'textBox';
  @override
  Map<String, Object?> fields() => {
        'lines': lines,
        'boxWidthMm': _jsonNum(boxWidthMm),
        'boxPosition': boxPosition,
        'firstLineIndentMm': _jsonNum(firstLineIndentMm),
      };
}

/// หัวเอกสารใบลา: ชื่อแบบฟอร์ม + กล่อง "รับที่" มุมขวา
class HeaderBlock extends Block {
  final String title;
  final String subtitle;
  final bool showReceiveBox;
  final List<String> receiveLines;
  const HeaderBlock(super.common,
      {required this.title,
      required this.subtitle,
      required this.showReceiveBox,
      required this.receiveLines});

  @override
  String get type => 'header';
  @override
  Map<String, Object?> fields() => {
        'title': title,
        'subtitle': subtitle,
        'showReceiveBox': showReceiveBox,
        'receiveLines': receiveLines,
      };
}

/// ช่องติ๊กประเภทการลา + ปีกกา + เหตุผล
class LeaveTypesBlock extends Block {
  final String label;
  final String reasonLabel;
  final bool showBrace;
  const LeaveTypesBlock(super.common,
      {required this.label, required this.reasonLabel, required this.showBrace});

  @override
  String get type => 'leaveTypes';
  @override
  Map<String, Object?> fields() =>
      {'label': label, 'reasonLabel': reasonLabel, 'showBrace': showBrace};
}

/// ส่วนล่างใบลา: ตารางสถิติ + ช่องเซ็นผู้ลา / ผู้บังคับบัญชา
class ApprovalBlock extends Block {
  final bool showStats;
  final String statsTitle;
  final List<String> hrLines;
  final List<String> applicantLines;
  final bool showComment;
  final String commentLabel;
  final List<String> deputyLines;
  final bool showOrder;
  final String orderLabel;
  final List<String> orderOptions;
  final List<String> directorLines;
  const ApprovalBlock(
    super.common, {
    required this.showStats,
    required this.statsTitle,
    required this.hrLines,
    required this.applicantLines,
    required this.showComment,
    required this.commentLabel,
    required this.deputyLines,
    required this.showOrder,
    required this.orderLabel,
    required this.orderOptions,
    required this.directorLines,
  });

  @override
  String get type => 'approval';
  @override
  Map<String, Object?> fields() => {
        'showStats': showStats,
        'statsTitle': statsTitle,
        'hrLines': hrLines,
        'applicantLines': applicantLines,
        'showComment': showComment,
        'commentLabel': commentLabel,
        'deputyLines': deputyLines,
        'showOrder': showOrder,
        'orderLabel': orderLabel,
        'orderOptions': orderOptions,
        'directorLines': directorLines,
      };
}

/// ตารางรายชื่อผู้ร่วมเดินทาง (ไปราชการ)
class MemberTableBlock extends Block {
  final bool showPosition;
  final bool showSignature;
  final ({String no, String name, String position, String signature}) headers;
  const MemberTableBlock(super.common,
      {required this.showPosition,
      required this.showSignature,
      required this.headers});

  @override
  String get type => 'memberTable';
  @override
  Map<String, Object?> fields() => {
        'showPosition': showPosition,
        'showSignature': showSignature,
        'headers': {
          'no': headers.no,
          'name': headers.name,
          'position': headers.position,
          'signature': headers.signature,
        },
      };
}

/// ช่องลงชื่อ (หลายบรรทัด) วางในกล่องกว้างตามที่ตั้ง
class SignatureBlock extends Block {
  final List<String> lines;
  final double? boxWidthMm;
  final String boxPosition;
  const SignatureBlock(super.common,
      {required this.lines, this.boxWidthMm, this.boxPosition = 'left'});

  @override
  String get type => 'signature';
  @override
  Map<String, Object?> fields() => {
        'lines': lines,
        'boxWidthMm': _jsonNum(boxWidthMm),
        'boxPosition': boxPosition,
      };
}

class SpacerBlock extends Block {
  final double heightMm;
  const SpacerBlock(super.common, {required this.heightMm});

  @override
  String get type => 'spacer';
  @override
  Map<String, Object?> fields() => {'heightMm': _jsonNum(heightMm)};
}

// ── แม่แบบ ─────────────────────────────────────────────────────

/// เงื่อนไขช่องติ๊กที่หมายถึง "ว่างไว้เสมอ (ให้ติ๊กด้วยมือ)"
const String alwaysUnchecked = 'ว่าง';

class FormTemplate {
  final FormType formType;
  final PaperSettings paper;
  final List<Block> blocks;

  const FormTemplate(
      {required this.formType, required this.paper, required this.blocks});

  /// อ่านแม่แบบจากฐานข้อมูลอย่างปลอดภัย — normalizeTemplate() ใน web
  ///
  /// อ่านไม่ได้ / ประเภทฟอร์มไม่ตรง = [fallback] ทั้งชุด
  /// ช่องกระดาษที่ขาด = ค่าของ [fallback], ช่องบรรทัดที่ขาด = ค่าตั้งต้นของบรรทัด
  static FormTemplate normalize(Object? raw, FormTemplate fallback) {
    if (raw is! Map) return fallback;
    final m = Map<String, dynamic>.from(raw);
    if (m['formType'] != fallback.formType.key || m['blocks'] is! List) {
      return fallback;
    }
    return FormTemplate(
      formType: fallback.formType,
      paper: fallback.paper.merge(_map(m['paper'])),
      blocks: [
        for (final b in m['blocks'] as List)
          if (Block.fromJson(b) case final block?) block
      ],
    );
  }

  /// ใช้กับแม่แบบที่เชื่อถือได้ (แม่แบบเริ่มต้นที่สร้างจากโค้ด web)
  factory FormTemplate.fromJson(Map<String, dynamic> m) {
    final type = FormType.fromKey(m['formType']);
    if (type == null) {
      throw FormatException('ประเภทฟอร์มไม่ถูกต้อง: ${m['formType']}');
    }
    final p = _map(m['paper']);
    final paper = PaperSettings(
      size: _str(p['size'], 'A4'),
      widthMm: _num(p['widthMm'], 210),
      heightMm: _num(p['heightMm'], 297),
      orientation: _str(p['orientation'], 'portrait'),
      margin: const PaperMargin(top: 20, right: 20, bottom: 20, left: 20)
          .merge(_map(p['margin'])),
      fontFamily: _str(p['fontFamily'], 'Sarabun, sans-serif'),
      fontSizePt: _num(p['fontSizePt'], 12),
      lineHeight: _num(p['lineHeight'], 1.5),
      fitToPage: _bool(p['fitToPage']),
    );
    return FormTemplate(
      formType: type,
      paper: paper,
      blocks: [
        for (final b in (m['blocks'] is List ? m['blocks'] as List : const []))
          if (Block.fromJson(b) case final block?) block
      ],
    );
  }

  Map<String, Object?> toJson() => {
        'schema': 1,
        'formType': formType.key,
        'paper': paper.toJson(),
        'blocks': [for (final b in blocks) b.toJson()],
      };
}
