import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/services/official_trip_service.dart';

void main() {
  group('countWorkingDays', () {
    // 9 ต.ค. 2026 = วันศุกร์
    final fri = DateTime(2026, 10, 9);
    final mon = DateTime(2026, 10, 12);

    test('ไม่นับเสาร์-อาทิตย์', () {
      expect(
          OfficialTripService.countWorkingDays(fri, mon,
              halfDay: false, holidays: {}, workingDays: {}),
          2);
    });

    test('ไม่นับวันหยุด แต่นับวันทำงานพิเศษ', () {
      expect(
          OfficialTripService.countWorkingDays(fri, mon,
              halfDay: false,
              holidays: {'2026-10-12'},
              workingDays: {'2026-10-10'}),
          2);
    });

    test('ครึ่งวัน = 0.5', () {
      expect(
          OfficialTripService.countWorkingDays(fri, fri,
              halfDay: true, holidays: {}, workingDays: {}),
          0.5);
    });
  });

  group('ปีงบประมาณ', () {
    test('ต.ค. ขึ้นปีงบใหม่', () {
      expect(OfficialTripService.fiscalYearOf(DateTime(2026, 9, 30)), 2569);
      expect(OfficialTripService.fiscalYearOf(DateTime(2026, 10, 1)), 2570);
    });

    test('ช่วงวันของปีงบ', () {
      expect(OfficialTripService.fiscalYearStart(2570), DateTime(2026, 10, 1));
      expect(OfficialTripService.fiscalYearEnd(2570), DateTime(2027, 9, 30));
    });
  });

  test('formatThaiRange', () {
    expect(
        OfficialTripService.formatThaiRange(
            DateTime(2026, 10, 9), DateTime(2026, 10, 9)),
        '9 ต.ค. 2569');
    expect(
        OfficialTripService.formatThaiRange(
            DateTime(2026, 10, 9), DateTime(2026, 10, 10)),
        '9–10 ต.ค. 2569');
    expect(
        OfficialTripService.formatThaiRange(
            DateTime(2026, 9, 30), DateTime(2026, 10, 2)),
        '30 ก.ย. – 2 ต.ค. 2569');
  });
}
