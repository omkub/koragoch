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

const mobileInk = Color(0xFF0F172A);
const mobileMuted = Color(0xFF64748B);
const mobileAccent = Color(0xFF2563EB);
const mobileBg = Color(0xFFF4F7FC);
const mobileLine = Color(0xFFE2E8F0);

/// หมวดหมู่ของทางลัดในหน้าหลัก
enum MobileShortcutGroup {
  /// บริการและการทำงานประจำวันของครู/บุคลากร
  work,

  /// การบริหาร รายงาน และการตั้งค่าระบบ
  management,
}

/// ทางลัดหนึ่งปุ่ม = เมนูหนึ่งเมนู (รหัสตาม MenuAccess)
class MobileShortcut {
  final int menu;
  final String label;
  final String subtitle;
  final IconData icon;
  final MobileShortcutGroup group;
  final Color iconColor;
  final Color iconBg;

  const MobileShortcut(
    this.menu,
    this.label,
    this.icon, {
    this.subtitle = '',
    this.group = MobileShortcutGroup.work,
    this.iconColor = mobileAccent,
    this.iconBg = const Color(0xFFDBEAFE),
  });
}

/// ลำดับทางลัดในหน้าหลัก — แยกหมวดหมู่และสีไอคอนให้กวาดตาดูง่าย
const mobileShortcuts = [
  // ── หมวดที่ 1: บริการและการทำงาน ──
  MobileShortcut(
    9,
    'ไปราชการ',
    Icons.business_center_rounded,
    subtitle: 'บันทึก / ประวัติ',
    group: MobileShortcutGroup.work,
    iconColor: Color(0xFF0284C7),
    iconBg: Color(0xFFE0F2FE),
  ),
  MobileShortcut(
    10,
    'ลงเวลา',
    Icons.fingerprint_rounded,
    subtitle: 'สแกนเข้า-ออกงาน',
    group: MobileShortcutGroup.work,
    iconColor: Color(0xFF0D9488),
    iconBg: Color(0xFFCCFBF1),
  ),
  MobileShortcut(
    8,
    'ปฏิทิน',
    Icons.calendar_month_rounded,
    subtitle: 'วันหยุด / กิจกรรม',
    group: MobileShortcutGroup.work,
    iconColor: Color(0xFF7C3AED),
    iconBg: Color(0xFFEDE9FE),
  ),

  // ── หมวดที่ 2: การบริหารและดูแลระบบ ──
  MobileShortcut(
    0,
    'สรุปผล',
    Icons.pie_chart_rounded,
    subtitle: 'แดชบอร์ดภาพรวม',
    group: MobileShortcutGroup.management,
    iconColor: Color(0xFF2563EB),
    iconBg: Color(0xFFDBEAFE),
  ),
  MobileShortcut(
    1,
    'รายงาน',
    Icons.assessment_rounded,
    subtitle: 'สถิติการลารายคน',
    group: MobileShortcutGroup.management,
    iconColor: Color(0xFF4F46E5),
    iconBg: Color(0xFFE0E7FF),
  ),
  MobileShortcut(
    5,
    'บุคลากร',
    Icons.groups_rounded,
    subtitle: 'ทำเนียบกลุ่มสาระ',
    group: MobileShortcutGroup.management,
    iconColor: Color(0xFF059669),
    iconBg: Color(0xFFD1FAE5),
  ),
  MobileShortcut(
    4,
    'จัดการระบบ',
    Icons.admin_panel_settings_rounded,
    subtitle: 'ผู้ใช้ / ตั้งค่า',
    group: MobileShortcutGroup.management,
    iconColor: Color(0xFFD97706),
    iconBg: Color(0xFFFEF3C7),
  ),
  MobileShortcut(
    7,
    'เข้าใช้งาน',
    Icons.verified_user_rounded,
    subtitle: 'ประวัติการล็อกอิน',
    group: MobileShortcutGroup.management,
    iconColor: Color(0xFF475569),
    iconBg: Color(0xFFF1F5F9),
  ),
];

/// หัวข้อหมวดหมู่พร้อมไอคอนนำสายตา ใช้จัดระเบียบทุกหน้าใน mobile_v2
class MobileSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final Color iconColor;

  const MobileSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailingText,
    this.iconColor = mobileAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.sarabun(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: mobileInk,
                letterSpacing: 0.1,
              ),
            ),
          ),
          if (trailingText != null && trailingText!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailingText!,
                style: GoogleFonts.sarabun(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: mobileMuted,
                ),
              ),
            ),
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
          fontSize: 19, fontWeight: FontWeight.w800, color: mobileInk));
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: mobileLine),
              ),
              child: SchoolLogo(dataUrl: SchoolInfo.logo, size: 26),
            ),
            const SizedBox(width: 10),
            Flexible(child: text),
          ])
        : text,
    actions: [...actions, const SizedBox(width: 4)],
    shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
  );
}
