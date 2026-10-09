/// ใบลาที่วาดจากแม่แบบที่ออกแบบในหน้าแบบฟอร์มของ web
///
/// - โหลดแม่แบบของโรงเรียน (FormTemplateService) แล้ววาดเป็น HTML ชุดเดียวกับตอนพิมพ์
/// - ระหว่างโหลดแสดงกระดาษว่างพร้อมตัวหมุน
/// - นอกเว็บ (เทส / แอปมือถือในอนาคต) แสดง HTML ไม่ได้ แสดงกระดาษพร้อมข้อความแจ้งแทน
library;

import 'package:flutter/material.dart';

import '../forms/form_render.dart';
import '../forms/form_template.dart';
import '../forms/leave_render_context.dart';
import '../services/form_template_service.dart';
import 'leave_form_data.dart';
import 'template_document_view.dart';

/// ความกว้างกระดาษเป็น px (96 dpi)
double paperWidthPx(FormTemplate template) =>
    template.paper.dimensions.widthMm * 96 / 25.4;

/// HTML ใบลาจากแม่แบบ — ใช้ทั้งพรีวิวและหน้าพิมพ์ จึงได้เอกสารเดียวกันเสมอ
String leaveDocumentHtml(FormTemplate template, LeaveFormData data,
        {bool forPrint = false}) =>
    renderDocument(
      template,
      leaveRenderContext(data),
      forPrint
          ? const RenderOptions(toolbar: true, autoPrint: true)
          : const RenderOptions(),
    );

class LeaveTemplateDocument extends StatefulWidget {
  final LeaveFormData data;

  const LeaveTemplateDocument({super.key, required this.data});

  @override
  State<LeaveTemplateDocument> createState() => _LeaveTemplateDocumentState();
}

class _LeaveTemplateDocumentState extends State<LeaveTemplateDocument> {
  ResolvedTemplate? _resolved =
      FormTemplateService.instance.cached(FormType.leave);

  @override
  void initState() {
    super.initState();
    FormTemplateService.instance.resolve(FormType.leave).then((r) {
      if (mounted && !identical(r, _resolved)) setState(() => _resolved = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    if (resolved == null) {
      return Container(
        width: 794,
        height: 1123,
        color: Colors.white,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    return TemplateDocumentView(
      html: leaveDocumentHtml(resolved.template, widget.data),
      widthPx: paperWidthPx(resolved.template),
      fallback: Container(
        width: 794,
        height: 1123,
        color: Colors.white,
        alignment: Alignment.center,
        child: const Text('ตัวอย่างใบลาแสดงได้เมื่อเปิดผ่านเว็บเบราว์เซอร์'),
      ),
    );
  }
}
