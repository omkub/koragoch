/// แสดงเอกสาร HTML ใน iframe (เว็บ)
///
/// - ความสูงปรับตามเนื้อหาจริงหลังโหลด (เอกสารยาวเกินหน้าก็เห็นครบ ไม่มีแถบเลื่อนซ้อน)
/// - เป็นภาพตัวอย่างอย่างเดียว: ปิดการรับเมาส์ ให้ล้อเลื่อนเลื่อนหน้าจอด้านนอกได้
/// - HTML เปลี่ยนถี่ ๆ (พิมพ์ในฟอร์ม) รอให้หยุดพิมพ์ครู่หนึ่งค่อยโหลดใหม่ ลดการกระพริบ
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class TemplateDocumentView extends StatefulWidget {
  final String html;

  /// ความกว้างกระดาษ (px ที่ 96 dpi)
  final double widthPx;

  /// ใช้นอกเว็บเท่านั้น (ดู template_document_view_io.dart)
  final Widget fallback;

  const TemplateDocumentView({
    super.key,
    required this.html,
    required this.widthPx,
    required this.fallback,
  });

  @override
  State<TemplateDocumentView> createState() => _TemplateDocumentViewState();
}

class _TemplateDocumentViewState extends State<TemplateDocumentView> {
  web.HTMLIFrameElement? _frame;
  Timer? _debounce;
  final List<Timer> _remeasure = [];

  /// เริ่มที่สัดส่วน A4 ก่อนรู้ความสูงจริง
  late double _height = widget.widthPx * 297 / 210;

  @override
  void didUpdateWidget(TemplateDocumentView old) {
    super.didUpdateWidget(old);
    if (old.html == widget.html) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final t in _remeasure) {
      t.cancel();
    }
    super.dispose();
  }

  void _load() {
    _frame?.srcdoc = widget.html.toJS;
  }

  void _measure() {
    final h = _frame?.contentDocument?.documentElement?.scrollHeight;
    if (h == null || h <= 0 || !mounted) return;
    if ((h - _height).abs() > 1) setState(() => _height = h.toDouble());
  }

  void _onCreated(Object element) {
    final frame = element as web.HTMLIFrameElement;
    frame.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..pointerEvents = 'none'
      ..backgroundColor = 'transparent';
    frame.onLoad.listen((_) {
      _measure();
      // ฟอนต์โหลดเสร็จ / สคริปต์ย่อให้พอดีหน้าทำงาน แล้วความสูงเปลี่ยนอีกรอบ
      for (final ms in [150, 600, 1500]) {
        _remeasure.add(Timer(Duration(milliseconds: ms), _measure));
      }
    });
    _frame = frame;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.widthPx,
      height: _height,
      child: HtmlElementView.fromTagName(
        tagName: 'iframe',
        onElementCreated: _onCreated,
      ),
    );
  }
}
