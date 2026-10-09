import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/services/attendance_import.dart';

Uint8List _file(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('parseDateTime', () {
    test('ปี-เดือน-วัน', () {
      expect(AttendanceImport.parseDateTime('2026-10-09 07:45:12'),
          DateTime(2026, 10, 9, 7, 45, 12));
      expect(AttendanceImport.parseDateTime('2026/10/09T07:45'),
          DateTime(2026, 10, 9, 7, 45));
    });

    test('วัน/เดือน/ปี แบบไทย และ พ.ศ.', () {
      expect(AttendanceImport.parseDateTime('9/10/2569 07:45'),
          DateTime(2026, 10, 9, 7, 45));
      expect(AttendanceImport.parseDateTime('09-10-2026 04:30:00 PM'),
          DateTime(2026, 10, 9, 16, 30));
    });

    test('ค่าผิดรูปแบบ', () {
      expect(AttendanceImport.parseDateTime('31/02/2026 08:00'), isNull);
      expect(AttendanceImport.parseDateTime('2026-10-09'), isNull);
      expect(AttendanceImport.parseDateTime('1001'), isNull);
    });
  });

  test('ZKTeco AttLog.dat (tab, ไม่มีหัวตาราง)', () {
    final table = AttendanceImport.parse(_file(
        '        1001\t2026-10-09 07:45:12\t1\t0\t1\t0\n'
        '        1004\t2026-10-09 08:40:01\t1\t0\t1\t0\n'));
    expect(table.rows.length, 2);
    expect(table.codeColumn, 0);
    expect(table.dateTimeColumn, 1);
    expect(table.timeColumn, isNull);

    final (scans, invalid) = AttendanceImport.toScans(table,
        codeColumn: 0, dateTimeColumn: 1);
    expect(invalid, 0);
    expect(scans.first.code, '1001');
    expect(scans.last.localTime, DateTime(2026, 10, 9, 8, 40, 1));
  });

  test('CSV มีหัวตาราง วันที่กับเวลาแยกช่อง + แถวซ้ำ/แถวเสีย', () {
    final table = AttendanceImport.parse(_file('﻿'
        'ชื่อ,รหัส,วันที่,เวลา\n'
        '"สมชาย, ใจดี",1001,09/10/2026,07:45\n'
        '"สมชาย, ใจดี",1001,09/10/2026,07:45\n'
        'สมหญิง,1004,09/10/2026,08:40\n'
        'เสีย,1005,,\n'));
    expect(table.header, ['ชื่อ', 'รหัส', 'วันที่', 'เวลา']);
    expect(table.rows.first[0], 'สมชาย, ใจดี');
    expect(table.codeColumn, 1);
    expect(table.dateTimeColumn, 2);
    expect(table.timeColumn, 3);

    final (scans, invalid) = AttendanceImport.toScans(table,
        codeColumn: 1, dateTimeColumn: 2, timeColumn: 3);
    expect(scans.length, 2); // แถวซ้ำถูกรวม
    expect(invalid, 1);
  });

  test('ส่งเข้าฐานข้อมูลเป็นเวลาไทย', () {
    expect(AttendanceImport.toBangkokIso(DateTime(2026, 10, 9, 7, 5, 3)),
        '2026-10-09T07:05:03+07:00');
  });
}
