// เทสระบบหลายโรงเรียน (ชั้นที่ 2 — แอปกรองตามโรงเรียน)
//
// ความเสี่ยงหลัก: มีคนเพิ่ม query ใหม่ที่ Teachers/Leaves/... แล้วลืมกรอง
// id_school หน้าจอจะดูปกติดีตอนมีโรงเรียนเดียว แล้วค่อยมาโผล่ข้อมูลข้าม
// โรงเรียนตอนมีโรงเรียนที่สอง เทสนี้อ่านซอร์สตรง ๆ เพื่อดักไว้ตั้งแต่ตอนนี้

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/services/firebase_service.dart';

void main() {
  group('withSchool', () {
    test('แนบ id_school ให้ตารางที่แยกตามโรงเรียน', () {
      final rec = FirebaseService.withSchool(
          'Leaves', {'id_user': 5}, schoolId: 2);
      expect(rec, {'id_user': 5, 'id_school': 2});
    });

    test('ไม่แตะตารางที่ใช้ร่วมกัน', () {
      final rec = FirebaseService.withSchool(
          'LeaveTypes', {'leaveName': 'ลาป่วย'}, schoolId: 2);
      expect(rec.containsKey('id_school'), isFalse);
    });

    test('ไม่ทับค่าที่ผู้เรียกใส่มาเอง', () {
      final rec = FirebaseService.withSchool(
          'Teachers', {'id_school': 7}, schoolId: 2);
      expect(rec['id_school'], 7);
    });

    test('ยังไม่รู้โรงเรียน = ไม่แนบ (ให้ trigger ฝั่งฐานข้อมูลเติมให้)', () {
      final rec = FirebaseService.withSchool('Leaves', {'id_user': 5});
      expect(rec.containsKey('id_school'), isFalse);
    });
  });

  test('ทุก query ที่อ่านตารางแยกโรงเรียน ต้องกรองด้วย inSchool', () {
    // ไฟล์ของแท็บนำเข้าข้อมูล (ห้ามแตะ) ไม่อยู่ในรายการ — ฝั่งนั้นพึ่ง trigger
    const files = [
      'lib/services/firebase_service.dart',
      'lib/screens/login_screen.dart',
      'lib/screens/calendar_settings_tab.dart',
    ];

    final tables = FirebaseService.schoolScopedTables.join('|');
    final fromScoped = RegExp("\\.from\\('($tables)'\\)");

    // query ที่ไม่ต้องกรองเพราะชี้แถวเดียวด้วยคีย์ที่ไม่ซ้ำทั้งระบบอยู่แล้ว
    // หรือเป็นการเขียนที่แนบโรงเรียนด้วย withSchool
    final safe = RegExp(
        r"inSchool\(|withSchool\(|"
        r"\.eq\('(id_user|id_leaves|auth_uid|firebase_uid|ID_AdminRoles)'|"
        r"\.eq\(primaryKeyFor\(|"
        r"// ทุกโรงเรียน");

    final problems = <String>[];
    for (final path in files) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (!fromScoped.hasMatch(lines[i])) continue;

        // ดูทั้งคำสั่ง: 3 บรรทัดก่อนหน้า (inSchool( มักขึ้นก่อน .from)
        // ไปจนถึงบรรทัดที่จบคำสั่ง
        final start = i >= 3 ? i - 3 : 0;
        var end = i;
        while (end < lines.length - 1 && !lines[end].contains(';')) {
          end++;
        }
        final statement = lines.sublist(start, end + 1).join('\n');
        if (!safe.hasMatch(statement)) {
          problems.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(problems, isEmpty,
        reason: 'query เหล่านี้อ่าน/แก้ตารางที่แยกตามโรงเรียนโดยไม่กรอง '
            'id_school — ครอบด้วย FirebaseService.inSchool(...) '
            'หรือถ้าตั้งใจให้เห็นทุกโรงเรียน ให้เขียนคอมเมนต์ "// ทุกโรงเรียน" '
            'ไว้ในคำสั่งนั้นพร้อมเหตุผล');
  });
}
