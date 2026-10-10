/// เมนูรองบนมือถือ (เปิดจากทางลัดในหน้าหลัก) — หน้าละเมนู เลื่อนเข้าจากขวา
///
/// พาร์ท 1 ใช้หน้าจอเดิมของแต่ละเมนูไปก่อน (ห่อด้วยแถบหัว + ปุ่มย้อนกลับ)
/// พาร์ท 7 จะปรับหน้าพวกนี้ให้เป็นแบบมือถือทีละหน้า
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../attendance_screen.dart';
import '../dashboard_screen.dart';
import '../login_logs_screen.dart';
import '../mobile/mobile_calendar_screen.dart';
import '../official_trip_screen.dart';
import '../personnel_screen.dart';
import '../report_overview_screen.dart';
import '../user_management_screen.dart';

const mobileInk = Color(0xFF0F172A);
const mobileMuted = Color(0xFF64748B);
const mobileAccent = Color(0xFF2563EB);
const mobileBg = Color(0xFFF4F7FC);

/// ทางลัดหนึ่งปุ่ม = เมนูหนึ่งเมนู (รหัสตาม MenuAccess)
class MobileShortcut {
  final int menu;
  final String label;
  final IconData icon;
  const MobileShortcut(this.menu, this.label, this.icon);
}

/// ลำดับทางลัดในหน้าหลัก — แสดงเฉพาะเมนูที่มีสิทธิ์
const mobileShortcuts = [
  MobileShortcut(9, 'ไปราชการ', Icons.business_center_outlined),
  MobileShortcut(8, 'ปฏิทิน', Icons.calendar_month_outlined),
  MobileShortcut(10, 'ลงเวลา', Icons.fingerprint),
  MobileShortcut(0, 'สรุปผล', Icons.dashboard_outlined),
  MobileShortcut(1, 'รายงาน', Icons.bar_chart_rounded),
  MobileShortcut(5, 'บุคลากร', Icons.people_outline),
  MobileShortcut(4, 'จัดการระบบ', Icons.settings_outlined),
  MobileShortcut(7, 'เข้าใช้งาน', Icons.security_rounded),
];

/// เปิดเมนูรองแบบเลื่อนเข้า (ปัดขอบซ้ายเพื่อย้อนกลับได้)
Future<void> openMobileMenu(BuildContext context, MobileShortcut s) {
  return Navigator.of(context).push(CupertinoPageRoute(
    builder: (ctx) => MobileSubPage(
      title: s.label,
      child: _pageFor(ctx, s.menu),
    ),
  ));
}

Widget _pageFor(BuildContext context, int menu) {
  void back() => Navigator.of(context).maybePop();
  switch (menu) {
    case 0:
      return const DashboardScreen();
    case 1:
      return const ReportOverviewScreen();
    case 4:
      return UserManagementScreen(onBack: back);
    case 5:
      return PersonnelScreen(onBack: back);
    case 7:
      return const LoginLogsScreen();
    case 8:
      return const MobileCalendarScreen();
    case 9:
      return const OfficialTripScreen(showHeader: false);
    case 10:
      return const AttendanceScreen();
  }
  return const SizedBox.shrink();
}

/// แถบหัวแบบแอป (ชื่อหน้า + ปุ่มย้อนกลับ) ใช้กับหน้ารองทุกหน้า
class MobileSubPage extends StatelessWidget {
  final String title;
  final Widget child;

  const MobileSubPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBg,
      appBar: mobileAppBar(title),
      body: child,
    );
  }
}

AppBar mobileAppBar(String title, {List<Widget> actions = const []}) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    foregroundColor: mobileInk,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    centerTitle: false,
    titleSpacing: 16,
    title: Text(title,
        style: GoogleFonts.sarabun(
            fontSize: 20, fontWeight: FontWeight.w700, color: mobileInk)),
    actions: [...actions, const SizedBox(width: 4)],
    shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
  );
}
