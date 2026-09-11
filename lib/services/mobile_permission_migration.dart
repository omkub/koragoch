// Converts Firestore menu fields into rows without discarding menu identity.
class MobilePermissionMigration {
  static const mobileMenuAliases = <int, List<String>>{
    0: ['สรุปผล', 'แดชบอร์ด'],
    1: ['รายงาน', 'รายงานสรุปการลา'],
    2: ['ส่งใบลา'],
    3: ['ประวัติ', 'ประวัติการลา'],
    4: ['ระบบ', 'จัดการระบบ', 'จัดการระบบ (รายชื่อบุคลากร)'],
    5: ['บุคลากร', 'บุคลากร (กลุ่มสาระ)'],
    6: ['ครูเวร', 'จัดการข้อมูลครูเวร'],
    7: ['เข้าใช้งาน', 'ประวัติการเข้าใช้งาน'],
    8: ['ปฏิทิน', 'ปฏิทินกิจกรรมส่วนกลาง'],
    -1: ['บัญชี'],
  };

  static const pcMenuAliases = <int, List<String>>{
    0: ['แดชบอร์ด'],
    1: ['รายงานการลา'],
    2: ['ส่งใบลา'],
    3: ['ประวัติการลา'],
    4: ['จัดการระบบ'],
    5: ['ข้อมูลบุคลากร'],
    6: ['ตั้งค่าปฏิทิน'],
    7: ['ประวัติการเข้าใช้งาน'],
    8: ['ตั้งค่า LINE'],
  };

  static const menuAliases = mobileMenuAliases;

  static String bit(dynamic value) {
    if (value == true || value == 1) return '1';
    if (value == false || value == 0) return '0';
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return '1';
    if (text == 'false' || text == '0') return '0';
    throw const FormatException('สิทธิ์เมนูต้องเป็น true/false หรือ 1/0');
  }


  static Map<String, dynamic> roleRecord(Map<String, dynamic> data, int roleId) {
    if (data.containsKey('status')) {
      return {'id_role': roleId, 'status': bit(data['status'])};
    }

    final rows = records(data, roleId);
    return {
      'id_role': roleId,
      'status': rows.any((row) => row['status'] == '1') ? '1' : '0',
    };
  }
  static List<Map<String, dynamic>> records(
    Map<String, dynamic> data,
    int roleId, {
    Map<int, List<String>> aliases = menuAliases,
  }) {
    final result = <Map<String, dynamic>>[];
    for (final entry in aliases.entries) {
      final keys = [entry.key.toString(), ...entry.value];
      final present = keys.where(data.containsKey).toList();
      if (present.isEmpty) continue;
      // The existing app allows a menu if either numeric or legacy name is true.
      final values = present.map((key) => bit(data[key])).toList();
      result.add({
        'id_role': roleId,
        'menu_id': entry.key,
        'status': values.contains('1') ? '1' : '0',
      });
    }
    if (result.isEmpty) {
      throw const FormatException('ไม่พบสิทธิ์เมนู 0–8 หรือ -1 ใน MobilePermissions');
    }
    return result;
  }
}

