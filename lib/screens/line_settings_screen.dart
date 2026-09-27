import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// แท็บ "ตั้งค่า LINE" ในหน้าจัดการระบบ
///
/// การตั้งค่า LINE ย้ายไปอยู่ที่เว็บผู้ดูแลระบบส่วนกลางแล้ว (central/ หน้า
/// "LINE แจ้งเตือน") เพราะแต่ละโรงเรียนส่งเข้ากลุ่มของตัวเอง และเจ้าของกำหนดให้
/// เฉพาะผู้ดูแลส่วนกลางเป็นคนเลือกว่าโรงเรียนไหนใช้กลุ่มไหน
/// (ตาราง SchoolLineSettings — แอดมินโรงเรียนอ่าน/แก้ไม่ได้ตาม RLS)
class LineSettingsScreen extends StatelessWidget {
  const LineSettingsScreen({super.key});

  static final Uri centralUrl =
      Uri.parse('https://omkub.github.io/koragoch/central/#/line');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active_outlined,
                color: Color(0xFF06C755), size: 28),
            const SizedBox(width: 12),
            Text('การแจ้งเตือน LINE',
                style: GoogleFonts.sarabun(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 16),
          Text(
            'การตั้งค่า LINE ย้ายไปอยู่ที่เว็บผู้ดูแลระบบส่วนกลางแล้วครับ\n'
            'แต่ละโรงเรียนแจ้งเตือนเข้ากลุ่ม LINE ของตัวเอง '
            'โดยผู้ดูแลระบบส่วนกลางเป็นผู้กำหนดกลุ่มและเปิด/ปิดการแจ้งเตือน\n\n'
            'ถ้าต้องการเปลี่ยนกลุ่ม LINE หรือเปิด/ปิดการแจ้งเตือนของโรงเรียน '
            'กรุณาติดต่อผู้ดูแลระบบส่วนกลาง',
            style: GoogleFonts.sarabun(
                fontSize: 15, height: 1.6, color: Colors.blueGrey.shade700),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () =>
                launchUrl(centralUrl, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('เปิดเว็บผู้ดูแลระบบส่วนกลาง',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
