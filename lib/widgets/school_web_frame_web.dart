/// แสดงหน้าเว็บโรงเรียน (/central/) ใน iframe แบบโต้ตอบได้เต็มรูปแบบ (สำหรับ Flutter Web)
library;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class SchoolWebFrame extends StatefulWidget {
  final String url;

  const SchoolWebFrame({
    super.key,
    required this.url,
  });

  @override
  State<SchoolWebFrame> createState() => _SchoolWebFrameState();
}

class _SchoolWebFrameState extends State<SchoolWebFrame> {
  web.HTMLIFrameElement? _frame;

  @override
  void didUpdateWidget(SchoolWebFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && _frame != null) {
      _frame!.src = widget.url;
    }
  }

  void _onCreated(Object element) {
    final frame = element as web.HTMLIFrameElement;
    frame.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      ..backgroundColor = '#F8FAFC';
    frame.allow = 'clipboard-read; clipboard-write';
    frame.src = widget.url;
    _frame = frame;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: HtmlElementView.fromTagName(
        tagName: 'iframe',
        onElementCreated: _onCreated,
      ),
    );
  }
}
