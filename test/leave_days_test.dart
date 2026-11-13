import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/utils/leave_days.dart';

void main() {
  // 9 ต.ค. 2026 = วันศุกร์
  final fri = DateTime(2026, 10, 9);
  final sat = DateTime(2026, 10, 10);
  final sun = DateTime(2026, 10, 11);
  final mon = DateTime(2026, 10, 12);

  group('LeaveDays.count — วันทำการ', () {
    test('ศุกร์–จันทร์ ไม่นับเสาร์-อาทิตย์ = 2 วัน', () {
      expect(LeaveDays.count(fri, mon), 2);
    });

    test('ไม่นับวันหยุดพิเศษ แต่นับวันทำงานพิเศษ', () {
      expect(
          LeaveDays.count(fri, mon,
              holidays: {'2026-10-12'}, workingDays: {'2026-10-10'}),
          2);
    });

    test('ลาเฉพาะเสาร์-อาทิตย์ = 0 วัน', () {
      expect(LeaveDays.count(sat, sun), 0);
    });

    test('วันเดียว = 1 วัน', () {
      expect(LeaveDays.count(fri, fri), 1);
    });

    test('ตัดเวลาออกก่อนนับ — วันเริ่มมีเวลา 10:00 ก็ยังนับครบ', () {
      final thu10am = DateTime(2026, 10, 8, 10, 0);
      expect(LeaveDays.count(thu10am, fri), 2);
    });

    test('วันเริ่มอยู่หลังวันสิ้นสุด — สลับให้', () {
      expect(LeaveDays.count(mon, fri), 2);
    });
  });

  group('LeaveDays.count — ครึ่งวัน / ลาคลอด', () {
    test('ครึ่งวัน = 0.5', () {
      expect(LeaveDays.count(fri, fri, halfDay: true), 0.5);
    });

    test('ลาคลอด นับวันปฏิทินทุกวัน รวมเสาร์-อาทิตย์และวันหยุด', () {
      expect(
          LeaveDays.count(fri, mon,
              maternity: true, holidays: {'2026-10-12'}),
          4);
    });

    test('ลาคลอด 90 วัน (วันเริ่ม + 89)', () {
      final end = fri.add(const Duration(days: 89));
      expect(LeaveDays.count(fri, end, maternity: true), 90);
    });

    test('isMaternityType', () {
      expect(LeaveDays.isMaternityType('ลาคลอดบุตร'), isTrue);
      expect(LeaveDays.isMaternityType('ลาป่วย'), isFalse);
      expect(LeaveDays.isMaternityType(null), isFalse);
    });
  });
}
