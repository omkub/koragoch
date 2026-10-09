import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/services/attendance_service.dart';

void main() {
  group('เวลาไทย', () {
    test('UTC จากฐานข้อมูล → เวลาไทย', () {
      final t = AttendanceService.toThaiTime('2026-10-09T00:45:12+00:00')!;
      expect([t.year, t.month, t.day, t.hour, t.minute], [2026, 10, 9, 7, 45]);
    });

    test('ข้ามวัน: 18:30 UTC = 01:30 วันถัดไป', () {
      final t = AttendanceService.toThaiTime('2026-10-08T18:30:00Z')!;
      expect([t.day, t.hour, t.minute], [9, 1, 30]);
    });

    test('ค่าว่าง/ผิดรูปแบบ', () {
      expect(AttendanceService.toThaiTime(null), isNull);
      expect(AttendanceService.toThaiTime('xx'), isNull);
    });

    test('ส่งกลับพร้อม +07:00', () {
      expect(AttendanceService.thaiIso(DateTime(2026, 1, 5, 8, 3)),
          '2026-01-05T08:03:00+07:00');
    });

    test('ป้ายวันที่ไทย', () {
      final d = DateTime(2026, 10, 9);
      expect(AttendanceService.thaiShortDate(d), '9 ต.ค. 2569');
      expect(AttendanceService.thaiDayLabel(d), 'ศ. 9 ต.ค.');
      expect(AttendanceService.thaiMonthYear(d), 'ตุลาคม 2569');
      expect(AttendanceService.minutesLabel(15), '15 นาที');
      expect(AttendanceService.minutesLabel(60), '1 ชม.');
      expect(AttendanceService.minutesLabel(75), '1 ชม. 15 นาที');
    });
  });

  test('แถวจาก attendance_day_status', () {
    final s = DayStatus.fromRow({
      'id_user': 7,
      'full_name': 'ครูทดสอบ',
      'day': '2026-10-09',
      'status': 'สาย',
      'first_scan': '2026-10-09T01:45:00+00:00',
      'last_scan': '2026-10-09T09:31:00+00:00',
      'scan_count': 2,
      'late_minutes': 15,
      'note': null,
    });
    expect(s.idUser, 7);
    expect(s.day, DateTime(2026, 10, 9));
    expect(AttendanceService.hm(s.firstScan), '08:45');
    expect(AttendanceService.hm(s.lastScan), '16:31');
    expect(s.note, '');
  });

  test('ตั้งค่า: เวลาตัดวินาที / ไม่มีแถว = ปิด', () {
    final s = AttendanceSettingsInfo.fromRow({
      'enabled': true,
      'work_start': '07:30:00',
      'late_after': '08:00:00',
      'work_end': '16:30:00',
    });
    expect([s.enabled, s.workStart, s.lateAfter], [true, '07:30', '08:00']);
    expect(AttendanceSettingsInfo.fromRow(null).enabled, isFalse);
  });

  test('CSV สรุป มี BOM และภาษาไทยถูก', () {
    final bytes = AttendanceService.summaryCsv([
      const AttendanceSummaryRow(
        idUser: 1,
        fullName: 'นาย ก, ข',
        workDays: 20,
        present: 17,
        late: 2,
        lateMinutes: 25,
        onLeave: 1,
        onTrip: 0,
        absent: 0,
        missingOut: 1,
      ),
    ], title: 'สรุปการลงเวลา ตุลาคม 2569');
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final text = utf8.decode(bytes.sublist(3));
    expect(text, startsWith('สรุปการลงเวลา ตุลาคม 2569'));
    // ชื่อที่มีจุลภาคต้องถูกครอบด้วยเครื่องหมายคำพูด
    expect(text, contains('1,"นาย ก, ข",20,17,2,25,1,0,0,1'));
  });

  test('CSV รายวัน', () {
    final text = utf8.decode(AttendanceService.dailyCsv([
      DayStatus(
        idUser: 1,
        fullName: 'ครู ก',
        day: DateTime(2026, 10, 9),
        status: 'มา',
        firstScan: DateTime(2026, 10, 9, 7, 50),
        lastScan: DateTime(2026, 10, 9, 16, 40),
        scanCount: 2,
      ),
      DayStatus(
        idUser: 2,
        fullName: 'ครู ข',
        day: DateTime(2026, 10, 9),
        status: 'ลา',
        note: 'ลาป่วย',
      ),
    ], title: 'x').sublist(3));
    expect(text, contains('9 ต.ค. 2569,ครู ก,มา,07:50,16:40,,'));
    expect(text, contains('9 ต.ค. 2569,ครู ข,ลา,,,,ลาป่วย'));
  });
}
