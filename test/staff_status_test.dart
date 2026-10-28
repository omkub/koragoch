// เทสสถานะบุคลากร (lib/utils/staff_status.dart)

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/utils/staff_status.dart';

void main() {
  test('ไม่มีคอลัมน์ / ค่าแปลก = ปฏิบัติงาน', () {
    expect(StaffStatus.isActive({}), isTrue);
    expect(StaffStatus.isActive({'employment_status': 'xyz'}), isTrue);
    expect(StaffStatus.isActive({'employment_status': 'retired'}), isFalse);
    expect(StaffStatus.label('resigned'), 'ลาออก');
    expect(StaffStatus.label(null), 'ปฏิบัติงาน');
  });

  test('รายชื่อไม่แสดงคนพ้นสภาพและบัญชีส่วนกลาง', () {
    expect(StaffStatus.isListed({'employment_status': 'active'}), isTrue);
    expect(StaffStatus.isListed({'employment_status': 'retired'}), isFalse);
    expect(StaffStatus.isListed({'is_super_admin': true}), isFalse);
    expect(StaffStatus.isListed({'is_super_admin': 'false'}), isTrue);
  });

  group('มีผลตามวันที่ (ตั้งล่วงหน้าได้)', () {
    // ตัวอย่างจากผู้ใช้: ย้าย มีผลตั้งแต่ 26/10/69
    // → วันที่ 25 ยังทำงานอยู่ · วันที่ 26 ต้องไม่แสดงแล้ว
    final moving = {'employment_status': 'transferred', 'left_date': '2026-10-26'};

    test('ก่อนวันที่มีผล ยังปฏิบัติงานและอยู่ในรายชื่อ', () {
      expect(StaffStatus.isActive(moving, on: DateTime(2026, 10, 20)), isTrue);
      expect(StaffStatus.isActive(moving, on: DateTime(2026, 10, 25)), isTrue);
    });

    test('วันที่มีผล พ้นสภาพทันที (ไม่ใช่วันถัดไป)', () {
      expect(StaffStatus.isActive(moving, on: DateTime(2026, 10, 26)), isFalse);
      expect(StaffStatus.isActive(moving, on: DateTime(2026, 10, 27)), isFalse);
    });

    test('เวลาในวันไม่มีผล — 23:59 ของวันที่ 25 ยังทำงาน · 00:01 ของวันที่ 26 ไม่แล้ว', () {
      expect(StaffStatus.isActive(moving, on: DateTime(2026, 10, 25, 23, 59)),
          isTrue);
      expect(StaffStatus.isActive(moving, on: DateTime(2026, 10, 26, 0, 1)),
          isFalse);
    });

    test('ไม่ใส่วันที่ = พ้นสภาพทันที (เหมือนเดิม)', () {
      expect(
          StaffStatus.isActive({'employment_status': 'retired'},
              on: DateTime(2000, 1, 1)),
          isFalse);
    });

    test('ตั้งย้ายล่วงหน้า วันนี้ยังทำงาน แต่ไม่ถูกนับในปีงบที่เริ่มหลังวันย้าย', () {
      // ย้ายมีผล 15 ก.ย. 2570 — ปีงบ 2571 (เริ่ม 1 ต.ค. 70) ต้องไม่มีชื่อ
      // แม้วันนี้ยังทำงานอยู่ (กันรายงานปีหน้าดึงคนที่กำหนดย้ายแล้ว)
      final movingNextYear = {
        'employment_status': 'transferred',
        'left_date': '2027-09-15',
      };
      expect(StaffStatus.activeDuring(movingNextYear, DateTime(2027, 10, 1)),
          isFalse);
      expect(StaffStatus.activeDuring(movingNextYear, DateTime(2026, 10, 1)),
          isTrue);
    });
  });

  group('นับตามปีงบประมาณ', () {
    final fy2569 = DateTime(2025, 10, 1); // ปีงบ 2569
    final fy2570 = DateTime(2026, 10, 1); // ปีงบ 2570
    final retiredSep30 = {
      'employment_status': 'retired',
      'left_date': '2026-09-30',
    };

    test('เกษียณ 30 ก.ย. อยู่ในปีงบนั้น แต่ไม่อยู่ปีงบถัดไป', () {
      expect(StaffStatus.activeDuring(retiredSep30, fy2569), isTrue);
      expect(StaffStatus.activeDuring(retiredSep30, fy2570), isFalse);
    });

    test('เกษียณ 1 ต.ค. (มีผลวันแรกของปีงบ) ไม่อยู่ปีงบนั้น แต่อยู่ปีงบก่อน', () {
      final retiredOct1 = {'employment_status': 'retired', 'left_date': '2026-10-01'};
      expect(StaffStatus.activeDuring(retiredOct1, fy2570), isFalse);
      expect(StaffStatus.activeDuring(retiredOct1, fy2569), isTrue);
    });

    test('ลาออกกลางปีงบ ยังนับปีงบนั้น', () {
      final leftNov = {'employment_status': 'resigned', 'left_date': '2026-11-15'};
      expect(StaffStatus.activeDuring(leftNov, fy2570), isTrue);
    });

    test('ปฏิบัติงานอยู่ นับทุกปีงบ / พ้นสภาพแต่ไม่มีวันที่ ไม่นับ', () {
      expect(StaffStatus.activeDuring({}, fy2570), isTrue);
      expect(
          StaffStatus.activeDuring({'employment_status': 'transferred'}, fy2569),
          isFalse);
    });

    test('วันเริ่มปีงบประมาณ', () {
      expect(StaffStatus.fiscalYearStart(DateTime(2026, 9, 30)), fy2569);
      expect(StaffStatus.fiscalYearStart(DateTime(2026, 10, 14)), fy2570);
    });
  });
}
