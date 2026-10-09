/// เอกสารที่วาดจากแม่แบบที่ออกแบบในหน้าแบบฟอร์มของ web (ใบลา / ใบไปราชการ)
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
import '../utils/web_platform.dart' as platform;
import 'leave_form_data.dart';
import 'template_document_view.dart';

/// ความกว้างกระดาษเป็น px (96 dpi)
double paperWidthPx(FormTemplate template) =>
    template.paper.dimensions.widthMm * 96 / 25.4;

/// HTML ของเอกสาร — ใช้ทั้งพรีวิวและหน้าพิมพ์ จึงได้เอกสารเดียวกันเสมอ
String documentHtml(FormTemplate template, RenderContext ctx,
        {bool forPrint = false}) =>
    renderDocument(
      template,
      ctx,
      forPrint
          ? const RenderOptions(toolbar: true, autoPrint: true)
          : const RenderOptions(),
    );

/// HTML ใบลาจากแม่แบบ
String leaveDocumentHtml(FormTemplate template, LeaveFormData data,
        {bool forPrint = false}) =>
    documentHtml(template, leaveRenderContext(data), forPrint: forPrint);

/// เปิดหน้าพิมพ์จากแม่แบบที่โหลดไว้แล้ว — ต้องเรียกทันทีที่ผู้ใช้กด (ห้ามรอโหลดก่อน)
/// ไม่งั้นเบราว์เซอร์จะบล็อกหน้าต่าง
///
/// ยังไม่เคยโหลดแม่แบบ / เบราว์เซอร์บล็อก → แจ้งผู้ใช้ แล้วคืน false
bool printFormDocument(BuildContext context, FormType type,
    RenderContext Function() buildContext) {
  final messenger = ScaffoldMessenger.of(context);
  final resolved = FormTemplateService.instance.cached(type);
  if (resolved == null) {
    FormTemplateService.instance.resolve(type);
    messenger.showSnackBar(const SnackBar(
        content: Text('กำลังโหลดแบบฟอร์ม กรุณากดพิมพ์อีกครั้ง')));
    return false;
  }
  final html =
      documentHtml(resolved.template, buildContext(), forPrint: true);
  if (platform.openHtmlInNewTab(html)) return true;
  messenger.showSnackBar(const SnackBar(
      content: Text('เบราว์เซอร์บล็อกหน้าต่างพิมพ์ กรุณาอนุญาต pop-up')));
  return false;
}

/// เอกสารจากแม่แบบของ [formType] เติมข้อมูลด้วย [renderContext]
class FormTemplateDocument extends StatefulWidget {
  final FormType formType;
  final RenderContext renderContext;

  const FormTemplateDocument(
      {super.key, required this.formType, required this.renderContext});

  @override
  State<FormTemplateDocument> createState() => _FormTemplateDocumentState();
}

class _FormTemplateDocumentState extends State<FormTemplateDocument> {
  late ResolvedTemplate? _resolved =
      FormTemplateService.instance.cached(widget.formType);

  @override
  void initState() {
    super.initState();
    FormTemplateService.instance.resolve(widget.formType).then((r) {
      if (mounted && !identical(r, _resolved)) setState(() => _resolved = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    Widget paper(Widget child) => Container(
          width: 794,
          height: 1123,
          color: Colors.white,
          alignment: Alignment.center,
          child: child,
        );
    if (resolved == null) return paper(const CircularProgressIndicator());
    return TemplateDocumentView(
      html: documentHtml(resolved.template, widget.renderContext),
      widthPx: paperWidthPx(resolved.template),
      fallback: paper(
          const Text('ตัวอย่างเอกสารแสดงได้เมื่อเปิดผ่านเว็บเบราว์เซอร์')),
    );
  }
}

/// ใบลาที่วาดจากแม่แบบ
class LeaveTemplateDocument extends StatelessWidget {
  final LeaveFormData data;

  const LeaveTemplateDocument({super.key, required this.data});

  @override
  Widget build(BuildContext context) => FormTemplateDocument(
        formType: FormType.leave,
        renderContext: leaveRenderContext(data),
      );
}
