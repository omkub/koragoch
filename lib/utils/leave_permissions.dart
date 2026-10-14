/// ใครทำอะไรกับใบลาได้ — ตรงกับที่ฐานข้อมูลบังคับ (supabase/admin_role_by_id.sql)
///
///   ผู้ดูแลระบบ (รวมผู้ดูแลส่วนกลาง ซึ่งเป็น id_role 22 เหมือนกัน):
///     ส่งใบลาแทนคนอื่น, แก้/ลบได้ทุกใบ, อนุมัติ
///   สิทธิ์อื่นทั้งหมด (ครู, ผู้บริหาร, ...):
///     ส่งใบลาของตัวเองเท่านั้น, แก้/ลบได้เฉพาะใบของตัวเองที่ยังไม่อนุมัติ
///
/// หน้าจอใช้ซ่อนปุ่ม ตัวกันจริงคือ RLS + trigger ในฐานข้อมูล
library;

class LeavePermissions {
  const LeavePermissions._();

  static bool isAdminRole(String? role) =>
      role?.contains('ผู้ดูแลระบบ') == true;

  /// เลือกบุคลากรคนอื่นในฟอร์มส่งใบลาได้
  static bool canFileForOthers(String? role) => isAdminRole(role);

  /// ใบลาที่ยังไม่ถูกดำเนินการ (ผู้ลาแก้เองได้)
  static bool isPending(String status) =>
      status == 'รอพิจารณา' || status == 'ยังไม่ส่ง';

  /// ใบลานี้เป็นของคนที่ล็อกอินอยู่หรือไม่ — เทียบ id_user ก่อน (ถ้ามีทั้งคู่)
  /// ไม่งั้นเทียบชื่อเต็ม
  static bool isOwn(Map<String, dynamic> leave,
      {String? myName, Object? myId}) {
    final leaveId = leave['id_user']?.toString().trim() ?? '';
    final mine = myId?.toString().trim() ?? '';
    if (leaveId.isNotEmpty && mine.isNotEmpty) return leaveId == mine;
    final name = (leave['fullName'] ?? '').toString().trim();
    return name.isNotEmpty && name == (myName ?? '').trim();
  }

  /// แก้ไข / ลบ ใบลานี้ได้
  static bool canModify(Map<String, dynamic> leave,
      {required String? role, String? myName, Object? myId}) {
    if (isAdminRole(role)) return true;
    final status = (leave['status'] ?? 'รอพิจารณา').toString();
    return isPending(status) &&
        isOwn(leave, myName: myName, myId: myId);
  }
}
