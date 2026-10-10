/// ปุ่มเปิด/ปิด "หน้าตาใหม่บนมือถือ (ทดลอง)" — วางไว้ในหน้าบัญชีทั้งแบบเดิมและแบบใหม่
/// สลับได้ไปกลับตลอด ไม่มีผลกับข้อมูล
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/mobile_ui_preference.dart';

class MobileUiSwitchTile extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const MobileUiSwitchTile(
      {super.key, this.margin = const EdgeInsets.symmetric(horizontal: 24)});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MobileUiPreference.useNewUi,
      builder: (context, on, _) => Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: SwitchListTile(
          value: on,
          onChanged: MobileUiPreference.set,
          activeTrackColor: const Color(0xFF2563EB),
          secondary: const Icon(Icons.auto_awesome_rounded,
              color: Color(0xFF2563EB)),
          title: Text('หน้าตาใหม่บนมือถือ',
              style: GoogleFonts.sarabun(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(
              on
                  ? 'กำลังใช้หน้าตาใหม่ — ปิดเพื่อกลับไปแบบเดิม (เฉพาะเครื่องนี้)'
                  : 'กำลังใช้หน้าตาเดิม — เปิดเพื่อใช้หน้าตาใหม่',
              style: GoogleFonts.sarabun(
                  fontSize: 12, color: const Color(0xFF64748B))),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
