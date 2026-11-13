/// เมนูรองบนมือถือ (เปิดจากทางลัดในหน้าหลัก) — หน้าละเมนู เลื่อนเข้าจากขวา
/// พร้อมชุดสีและคอมโพเนนต์หัวข้อหมวดหมู่ที่ใช้ร่วมกันใน mobile_v2
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
import '../../utils/school_info.dart';
import '../../widgets/school_logo.dart';
import '../../theme/app_tokens.dart';

const mobileInk = AppColors.text;
const mobileMuted = AppColors.textMuted;
const mobileAccent = AppColors.accent;
const mobileBg = AppColors.page;
const mobileLine = AppColors.line;

/// หมวดหมู่ของทางลัดในหน้าหลัก
enum MobileShortcutGroup {
  /// บริการและการทำงานประจำวันของครู/บุคลากร
  work,

  /// การบริหาร รายงาน และการตั้งค่าระบบ
  management,
}

/// ทางลัดหนึ่งปุ่ม = เมนูหนึ่งเมนู (รหัสตาม MenuAccess)
/// ไอคอนทุกปุ่มสีเดียวกัน (ตัวอักษรรอง) — แยกหมวดด้วยหัวข้อ ไม่ใช่ด้วยสี
class MobileShortcut {
  final int menu;
  final String label;
  final String subtitle;
  final IconData icon;
  final MobileShortcutGroup group;

  const MobileShortcut(
    this.menu,
    this.label,
    this.icon, {
    this.subtitle = '',
    this.group = MobileShortcutGroup.work,
  });
}

/// ลำดับทางลัดในหน้าหลัก
const mobileShortcuts = [
  // ── หมวดที่ 1: บริการและการทำงาน ──
  MobileShortcut(9, 'ไปราชการ', Icons.business_center_outlined,
      subtitle: 'บันทึก / ประวัติ'),
  MobileShortcut(10, 'ลงเวลา', Icons.fingerprint_rounded,
      subtitle: 'เข้า-ออกงาน'),
  MobileShortcut(8, 'ปฏิทิน', Icons.calendar_month_outlined,
      subtitle: 'วันหยุด / กิจกรรม'),

  // ── หมวดที่ 2: การบริหารและดูแลระบบ ──
  MobileShortcut(0, 'สรุปผล', Icons.pie_chart_outline_rounded,
      subtitle: 'ภาพรวม', group: MobileShortcutGroup.management),
  MobileShortcut(1, 'รายงาน', Icons.assessment_outlined,
      subtitle: 'สถิติรายคน', group: MobileShortcutGroup.management),
  MobileShortcut(5, 'บุคลากร', Icons.groups_outlined,
      subtitle: 'กลุ่มสาระ', group: MobileShortcutGroup.management),
  MobileShortcut(4, 'จัดการระบบ', Icons.admin_panel_settings_outlined,
      subtitle: 'ผู้ใช้ / ตั้งค่า', group: MobileShortcutGroup.management),
  MobileShortcut(7, 'เข้าใช้งาน', Icons.verified_user_outlined,
      subtitle: 'ประวัติล็อกอิน', group: MobileShortcutGroup.management),
];

/// หัวข้อหมวดหมู่ของทุกหน้าใน mobile_v2 — ข้อความล้วน ข้อมูลประกอบเป็นตัวอักษรจาง
/// ([icon] เก็บไว้เพื่อความเข้ากันได้ของโค้ดเดิม แต่ไม่แสดงแล้ว)
class MobileSectionHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? trailingText;

  const MobileSectionHeader({
    super.key,
    this.icon,
    required this.title,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.section)),
          if (trailingText != null && trailingText!.isNotEmpty)
            Text(trailingText!, style: AppText.figure(12, color: AppColors.textMuted, weight: FontWeight.w400)),
        ],
      ),
    );
  }
}

/// เปิดเมนูรองแบบเลื่อนเข้า (ปัดขอบซ้ายเพื่อย้อนกลับได้)
Future<void> openMobileMenu(BuildContext context, MobileShortcut s) {
  return Navigator.of(context).push(CupertinoPageRoute(
    builder: (ctx) => MobileSubPage(
      title: s.label,
      child: _pageFor(ctx, s.menu),
    ),
  ));
}

/// หน้าของแต่ละเมนู — ไม่มีชื่อหน้า / ปุ่มย้อนกลับซ้ำกับแถบหัวของ MobileSubPage
Widget _pageFor(BuildContext context, int menu) {
  switch (menu) {
    case 0:
      return const DashboardScreen();
    case 1:
      return const ReportOverviewScreen(appStyle: true);
    case 4:
      // ไม่ส่ง onBack = ไม่มีปุ่มย้อนกลับซ้ำ (แถบหัวมีแล้ว)
      return const UserManagementScreen();
    case 5:
      return const PersonnelScreen();
    case 7:
      return const LoginLogsScreen(appStyle: true);
    case 8:
      return const MobileCalendarScreen(showHeader: false);
    case 9:
      return const OfficialTripScreen(showHeader: false);
    case 10:
      return const AttendanceScreen(showHeader: false);
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

/// [showLogo] = โลโก้โรงเรียนของผู้ใช้หน้าชื่อหน้า (แถบหัวของแท็บหลักใน MobileShell)
AppBar mobileAppBar(String title,
    {List<Widget> actions = const [], bool showLogo = false}) {
  final text = Text(title,
      style: GoogleFonts.sarabun(
          fontSize: 18, fontWeight: FontWeight.w600, color: mobileInk));
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    foregroundColor: mobileInk,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    centerTitle: false,
    titleSpacing: 16,
    title: showLogo
        ? Row(children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.page,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mobileLine),
              ),
              child: SchoolLogo(dataUrl: SchoolInfo.logo, size: 26),
            ),
            const SizedBox(width: 10),
            Flexible(child: text),
          ])
        : text,
    actions: [...actions, const SizedBox(width: 4)],
    shape: const Border(bottom: BorderSide(color: AppColors.line)),
  );
}
