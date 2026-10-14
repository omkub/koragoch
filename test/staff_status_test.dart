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

    test('พ้นสภาพวันแรกของปีงบ ยังนับปีงบนั้น', () {
      final leftOct1 = {'employment_status': 'resigned', 'left_date': '2026-10-01'};
      expect(StaffStatus.activeDuring(leftOct1, fy2570), isTrue);
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
