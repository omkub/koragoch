/// นอกเว็บแสดง HTML ไม่ได้ — ใช้เอกสารแบบ Flutter ที่ส่งมาแทน
library;

import 'package:flutter/widgets.dart';

class TemplateDocumentView extends StatelessWidget {
  final String html;

  /// ความกว้างกระดาษ (px ที่ 96 dpi)
  final double widthPx;
  final Widget fallback;

  const TemplateDocumentView({
    super.key,
    required this.html,
    required this.widthPx,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) => fallback;
}
