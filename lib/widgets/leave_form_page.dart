/// หน้าจอแสดงใบลาพร้อมแถบเครื่องมือพิมพ์
///
/// ใช้แทน `LeaveFormPreview` เดิมได้ทันที รับพารามิเตอร์ชุดเดียวกัน
/// เอกสารวาดจากแม่แบบที่ออกแบบในหน้าแบบฟอร์มของ web ทั้งบนจอและตอนพิมพ์
/// (ดู leave_template_document.dart)
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../forms/form_template.dart';
import '../services/form_template_service.dart';
import '../utils/web_platform.dart' as platform;
import 'leave_form_data.dart';
import 'leave_template_document.dart';

class LeaveFormPage extends StatefulWidget {
  final Map<String, dynamic> leaf;
  final List<Map<String, dynamic>> allUsers;
  final List<Map<String, dynamic>> allLeaveRequests;
  final List<String> leaveTypeNames;

  const LeaveFormPage({
    super.key,
    required this.leaf,
    required this.allUsers,
    required this.allLeaveRequests,
    this.leaveTypeNames = const [],
  });

  @override
  State<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends State<LeaveFormPage> {
  late final LeaveFormData _data = LeaveFormData(
    leaf: widget.leaf,
    allUsers: widget.allUsers,
    allLeaveRequests: widget.allLeaveRequests,
    leaveTypeNames: widget.leaveTypeNames,
  );

  ResolvedTemplate? _resolved =
      FormTemplateService.instance.cached(FormType.leave);

  @override
  void initState() {
    super.initState();
    FormTemplateService.instance.resolve(FormType.leave).then((r) {
      if (mounted && !identical(r, _resolved)) setState(() => _resolved = r);
    });
  }

  /// เปิดหน้าพิมพ์ทันทีที่กด (ไม่รอโหลดอะไร) ไม่งั้นเบราว์เซอร์จะบล็อกหน้าต่าง
  /// ปุ่มจึงกดได้หลังโหลดแม่แบบเสร็จแล้วเท่านั้น
  void _print(ResolvedTemplate resolved) {
    final html =
        leaveDocumentHtml(resolved.template, _data, forPrint: true);
    if (platform.openHtmlInNewTab(html)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('เบราว์เซอร์บล็อกหน้าต่างพิมพ์ กรุณาอนุญาต pop-up')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    final onPrint = resolved == null ? null : () => _print(resolved);

    return Scaffold(
      backgroundColor: const Color(0xFF475569),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        title: Text('ตัวอย่างใบลา - ${widget.leaf['fullName']}',
            style: GoogleFonts.sarabun(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: resolved == null ? 'กำลังโหลดแบบฟอร์ม...' : 'พิมพ์เอกสาร',
            onPressed: onPrint,
            icon: const Icon(Icons.print, color: Colors.white),
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip:
                resolved == null ? 'กำลังโหลดแบบฟอร์ม...' : 'บันทึกเป็น PDF',
            onPressed: onPrint,
            icon: const Icon(Icons.download, color: Colors.white),
            disabledColor: Colors.white38,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          // จอแคบกว่ากระดาษ ย่อทั้งหน้าให้พอดีแทนการล้นขอบ
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: LeaveTemplateDocument(data: _data),
          ),
        ),
      ),
    );
  }
}
