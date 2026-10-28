// เทสตำแหน่งบริหาร ณ วันที่ (lib/utils/admin_position.dart)

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/utils/admin_position.dart';

void main() {
  const director = 'ผู้อำนวยการโรงเรียน';

  // ตัวอย่างจากผู้ใช้: ผอ. คนใหม่มีผลตั้งแต่ 26/10/69 แทนคนเดิม
  final oldDirector = {
    'fullName': 'ผอ. คนเดิม',
    'adminPositionHistory': [
      {'role': director, 'start': null, 'end': '2026-10-26'},
    ],
  };
  final newDirector = {
    'fullName': 'ผอ. คนใหม่',
    'adminPositionHistory': [
      {'role': director, 'start': '2026-10-26', 'end': null},
    ],
  };
  final users = [oldDirector, newDirector];

  group('ใครดำรงตำแหน่งวันไหน', () {
    test('25 ต.ค. ยังเป็นคนเดิม · 26 ต.ค. เป็นคนใหม่', () {
      expect(AdminPosition.positionOn(oldDirector, DateTime(2026, 10, 25)),
          director);
      expect(AdminPosition.positionOn(oldDirector, DateTime(2026, 10, 26)), '');
      expect(AdminPosition.positionOn(newDirector, DateTime(2026, 10, 25)), '');
      expect(AdminPosition.positionOn(newDirector, DateTime(2026, 10, 26)),
          director);
    });

    test('ช่องเซ็นใบลาเลือกผู้ดำรงตำแหน่งตามวันที่', () {
      expect(AdminPosition.holderOn(users, director, DateTime(2026, 10, 25))
          ?['fullName'], 'ผอ. คนเดิม');
      expect(AdminPosition.holderOn(users, director, DateTime(2026, 10, 26))
          ?['fullName'], 'ผอ. คนใหม่');
      // ใบลาเก่ามากก่อนเริ่มบันทึกประวัติ — ยังเป็นคนเดิม
      expect(AdminPosition.holderOn(users, director, DateTime(2020, 1, 1))
          ?['fullName'], 'ผอ. คนเดิม');
    });

    test('ชื่อตำแหน่งยาวกว่า/มีช่องว่าง ยังจับคู่ได้', () {
      final u = {
        'fullName': 'ผอ.',
        'adminPositionHistory': [
          {'role': 'ผู้อำนวยการ โรงเรียนรมย์บุรีพิทยาคม', 'start': null, 'end': null},
        ],
      };
      expect(
          AdminPosition.holderOn([u], director, DateTime(2026, 1, 1)), same(u));
    });

    test('พ้นสภาพแล้วไม่มีตำแหน่ง แม้ประวัติยังไม่ได้ปิด', () {
      // ผอ. เกษียณ 1 ต.ค. แต่ยังไม่ได้บันทึกคนใหม่ — ใบลาวันที่ 2 ต.ค.
      // ต้องไม่ขึ้นชื่อคนที่เกษียณไปแล้วเป็นผู้ลงนาม
      final retired = {
        'fullName': 'ผอ. เกษียณ',
        'employment_status': 'retired',
        'left_date': '2026-10-01',
        'adminPositionHistory': [
          {'role': director, 'start': null, 'end': null},
        ],
      };
      expect(AdminPosition.positionOn(retired, DateTime(2026, 9, 30)), director);
      expect(AdminPosition.positionOn(retired, DateTime(2026, 10, 2)), '');
    });

    test('ไม่มีประวัติ (ยังไม่ได้รัน SQL) ใช้ตำแหน่งในทะเบียนแบบเดิม', () {
      final legacy = {'fullName': 'ก', 'ตำแหน่งงานบริหาร': director};
      expect(AdminPosition.positionOn(legacy, DateTime(2000, 1, 1)), director);
      expect(
          AdminPosition.positionOn(
              {'ตำแหน่งงานบริหาร': 'ไม่มีตำแหน่งบริหาร'}, DateTime.now()),
          '');
    });
  });

  group('ตำแหน่งในช่วงรายงาน', () {
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year + 543}';
    // ปีงบ 2570 = 1 ต.ค. 69 ถึงก่อน 1 ต.ค. 70
    final fyStart = DateTime(2026, 10, 1);
    final fyEnd = DateTime(2027, 10, 1);

    test('เปลี่ยนกลางปีงบ บอกวันที่ให้ทั้งสองคน', () {
      expect(
          AdminPosition.describeDuring(oldDirector, fyStart, fyEnd,
              formatDate: fmt),
          '$director (ถึง 25/10/2569)');
      expect(
          AdminPosition.describeDuring(newDirector, fyStart, fyEnd,
              formatDate: fmt),
          '$director (ตั้งแต่ 26/10/2569)');
    });

    test('ปีงบก่อนหน้า มีแต่คนเดิม คนใหม่ไม่มีตำแหน่ง', () {
      final prevStart = DateTime(2025, 10, 1);
      expect(
          AdminPosition.describeDuring(oldDirector, prevStart, fyStart,
              formatDate: fmt),
          director);
      expect(
          AdminPosition.describeDuring(newDirector, prevStart, fyStart,
              formatDate: fmt),
          '');
    });
  });

  test('อ่าน/เขียนรูปแบบเดียวกับที่ตัวโหลดข้อมูลแนบมา', () {
    final p = AdminPositionPeriod.fromMap(
        {'id': 7, 'role': director, 'start': '2026-10-26', 'end': null})!;
    expect(p.toMap(),
        {'id': 7, 'role': director, 'start': '2026-10-26', 'end': null, 'note': ''});
  });
}
