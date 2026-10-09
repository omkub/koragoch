/// เมนูที่ผู้ใช้มีสิทธิ์เข้า (บนมือถือ) — ตรรกะเดียวกับ MobileMainLayout เดิม
///
/// รหัสเมนู (ตรงกับตาราง Permissions / MobilePermissions):
///   0 สรุปผล · 1 รายงาน · 2 ส่งใบลา · 3 ประวัติการลา · 4 จัดการระบบ
///   5 บุคลากร · 7 ประวัติการเข้าใช้งาน · 8 ปฏิทิน · 9 ไปราชการ · 10 ลงเวลา
///   -1 บัญชี
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/attendance_service.dart';
import '../../services/firebase_service.dart';

class MenuAccess {
  final String currentUser;
  final String userRole;
  final List<int> allowed;

  const MenuAccess(
      {required this.currentUser,
      required this.userRole,
      required this.allowed});

  /// ผู้ดูแลระบบ = คนเดียวที่อนุมัติใบลาได้
  bool get isAdmin =>
      userRole.contains('ผู้ดูแลระบบ') || currentUser == 'ผู้ดูแลระบบ';

  bool can(int menu) => allowed.contains(menu);

  /// ดูภาพรวมทั้งโรงเรียนได้ (ผู้บริหาร / ผู้ดูแลระบบ) — ใช้สิทธิ์เมนูสรุปผล/รายงาน
  bool get seesSchoolOverview => isAdmin || can(0) || can(1);

  static bool _isTruthy(dynamic v) {
    if (v == null) return false;
    if (v == true || v == 1) return true;
    final s = v.toString().trim().toUpperCase();
    return s == 'TRUE' || s == '1';
  }

  /// อ่านบทบาทจากเครื่อง + สิทธิ์เมนูจากฐานข้อมูล (อ่านไม่ได้ = ค่าเริ่มต้นตามบทบาท)
  static Future<MenuAccess> load() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = prefs.getString('currentUser') ?? '';
    final userRole = prefs.getString('userRole') ?? 'ครู';
    final service = FirebaseService();

    final results = await Future.wait([
      service
          .getPermissionDocFromSupabase('MobilePermissions', userRole)
          .then((d) async =>
              d ??
              await service.getPermissionDocFromSupabase(
                  'Permissions', userRole))
          .catchError((_) => null),
      AttendanceService().isEnabled().catchError((_) => false),
    ]);
    final data = results[0] as Map<String, dynamic>?;
    final attendanceEnabled = results[1] as bool;

    final isAdmin =
        userRole.contains('ผู้ดูแลระบบ') || currentUser == 'ผู้ดูแลระบบ';
    var allowed =
        data == null ? _defaults(isAdmin) : _fromData(data, isAdmin: isAdmin);
    if (userRole.contains('ครู')) allowed.remove(0);
    if (!attendanceEnabled) allowed.remove(10);
    if (allowed.isEmpty) allowed = _defaults(isAdmin);

    return MenuAccess(
        currentUser: currentUser, userRole: userRole, allowed: allowed);
  }

  static List<int> _defaults(bool isAdmin) =>
      isAdmin ? [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, -1] : [0, 2, 3, 9, 10, -1];

  static List<int> _fromData(Map<String, dynamic> data,
      {required bool isAdmin}) {
    final allowed = <int>[];
    for (var i = 0; i <= 10; i++) {
      if (i == 6) continue;
      if (_isTruthy(data['$i'])) allowed.add(i);
    }
    const oldMapping = {
      'แดชบอร์ด': 0,
      'รายงานสรุปการลา': 1,
      'ส่งใบลา': 2,
      'ประวัติการลา': 3,
      'จัดการระบบ (รายชื่อบุคลากร)': 4,
      'จัดการระบบ': 4,
      'บุคลากร (กลุ่มสาระ)': 5,
      'ประวัติการเข้าใช้งาน': 7,
      'ปฏิทินกิจกรรมส่วนกลาง': 8,
    };
    oldMapping.forEach((key, index) {
      if (!allowed.contains(index) && _isTruthy(data[key])) allowed.add(index);
    });
    final hasAccountField = data.containsKey('-1') || data.containsKey('บัญชี');
    if (!hasAccountField || _isTruthy(data['-1'] ?? data['บัญชี'])) {
      allowed.add(-1);
    }
    if (isAdmin && !allowed.contains(4)) allowed.add(4);
    return allowed;
  }
}
