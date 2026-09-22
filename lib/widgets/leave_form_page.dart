/// หน้าจอแสดงใบลาพร้อมแถบเครื่องมือพิมพ์
///
/// ใช้แทน `LeaveFormPreview` เดิมได้ทันที รับพารามิเตอร์ชุดเดียวกัน
/// ต่างกันตรงที่เอกสารข้างในวาดจาก [LeaveFormDocument] ฉบับกลาง
/// และหน้าพิมพ์สร้างจากข้อมูลชุดเดียวกันแทนที่จะคำนวณแยก
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/web_platform.dart' as platform;
import 'leave_form_data.dart';
import 'leave_form_document.dart';
import 'leave_form_html.dart';

class LeaveFormPage extends StatelessWidget {
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

  void _print(BuildContext context, LeaveFormData data) {
    final html = buildLeaveFormHtml(data, autoPrint: true);
    if (platform.openHtmlInNewTab(html)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('เบราว์เซอร์บล็อกหน้าต่างพิมพ์ กรุณาอนุญาต pop-up')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = LeaveFormData(
      leaf: leaf,
      allUsers: allUsers,
      allLeaveRequests: allLeaveRequests,
      leaveTypeNames: leaveTypeNames,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF475569),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        title: Text('ตัวอย่างใบลา - ${leaf['fullName']}',
            style: GoogleFonts.sarabun(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'พิมพ์เอกสาร',
            onPressed: () => _print(context, data),
            icon: const Icon(Icons.print, color: Colors.white),
          ),
          IconButton(
            tooltip: 'บันทึกเป็น PDF',
            onPressed: () => _print(context, data),
            icon: const Icon(Icons.download, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: LeaveFormDocument(data: data)),
      ),
    );
  }
}
