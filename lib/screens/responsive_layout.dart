import 'package:flutter/material.dart';
import '../utils/school_info.dart';
import 'main_layout.dart';
import 'mobile/mobile_main_layout.dart';
import 'mobile_v2/mobile_shell.dart';

class ResponsiveLayout extends StatefulWidget {
  const ResponsiveLayout({super.key});

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  /// หน้าจอมือถือของโรงเรียน (ตั้งที่เว็บส่วนกลาง) — จำไว้ตอนเปิดหน้านี้
  /// แอดมินแก้ข้อมูลโรงเรียนระหว่างใช้งาน (SchoolInfo.load ใหม่) จะไม่สลับหน้าตา
  /// กลางคัน ค่าใหม่มีผลเมื่อเปิดแอปครั้งถัดไป
  final bool _oldMobileUi = SchoolInfo.useOldMobileUi;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🕵️‍♂️ ถ้าหน้าจอแคบกว่า 1100px ใช้หน้าจอมือถือตามที่โรงเรียนตั้งไว้ 🥇🏆
        //   แบบใหม่ = แบบแอป (mobile_v2) / แบบเดิม = แถบล่าง 9 ปุ่ม
        if (constraints.maxWidth < 1100) {
          return _oldMobileUi
              ? const MobileMainLayout()
              : const MobileShell();
        }
        // 🖥️ ถ้าหน้าจอกว้าง ให้ใช้ดีไซน์แบบ PC Desktop มาตรฐานครับ
        return const MainLayout();
      },
    );
  }
}
