// เทสของตัวคำนวณข้อมูลใบลา (lib/widgets/leave_form_data.dart)
//
// ตรรกะชุดนี้เดิมฝังอยู่ในหน้าจอ เขียนเทสไม่ได้เลย พอแยกออกมาเป็นคลาสล้วน ๆ
// ที่ไม่ยุ่งกับ UI จึงทดสอบกติกาสำคัญได้ตรง ๆ เช่น การนับสถิติวันลา
// และการเลือก "การลาครั้งล่าสุด" ซึ่งถ้าผิดจะทำให้ใบลาราชการผิดไปด้วย

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/widgets/leave_form_data.dart';

void main() {
  Map<String, dynamic> leave({
    required String requestId,
    String fullName = 'สมชาย ใจดี',
    String leaveType = 'ลาป่วย',
    String startDate = '10/01/2569',
    String endDate = '10/01/2569',
    String totalDays = '1',
    String year = '2569',
    String? timestamp,
  }) =>
      {
        'requestId': requestId,
        'fullName': fullName,
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        'totalDays': totalDays,
        'year': year,
        'timestamp': timestamp ?? startDate,
      };

  group('ตำแหน่งและวิทยฐานะ', () {
    test('หยิบจากทะเบียนบุคลากรเมื่อในใบลาไม่มี', () {
      final data = LeaveFormData(
        leaf: {'fullName': 'สมชาย ใจดี'},
        allUsers: [
          {
            'fullName': 'สมชาย ใจดี',
            'position': 'ครู',
            'academicStanding': 'ชำนาญการ',
          }
        ],
        allLeaveRequests: const [],
      );

      expect(data.position, 'ครู');
      expect(data.academicStanding, 'ชำนาญการ');
      expect(data.positionWithStanding, 'ครู ชำนาญการ');
    });

    test('"ไม่มีวิทยฐานะ" ถือว่าไม่ต้องแสดงอะไรเลย', () {
      final data = LeaveFormData(
        leaf: {
          'fullName': 'สมชาย ใจดี',
          'position': 'ครู',
          'academicStanding': 'ไม่มีวิทยฐานะ',
        },
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.academicStanding, '');
      expect(data.positionWithStanding, 'ครู');
    });

    test('ค่าที่ยังไม่ได้เลือกถือเป็นค่าว่าง', () {
      final data = LeaveFormData(
        leaf: {'fullName': 'สมชาย ใจดี', 'position': '---เลือก---'},
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.position, '');
    });
  });

  group('หัวข้อเรื่อง', () {
    test('เติมคำว่า "ขอ" นำหน้าประเภทการลา', () {
      final data = LeaveFormData(
        leaf: {'leaveType': 'ลากิจส่วนตัว'},
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.subject, 'ขอลากิจส่วนตัว');
    });

    test('ยังไม่ได้เลือกประเภท ให้เว้นว่างไม่ใช่ "ขอ---เลือก---"', () {
      final data = LeaveFormData(
        leaf: {'leaveType': '---เลือก---'},
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.subject, '');
    });
  });

  group('การลาครั้งล่าสุดก่อนใบนี้', () {
    test('เลือกใบที่ใกล้ที่สุดที่เกิดก่อนใบปัจจุบัน', () {
      final current = leave(requestId: 'C', startDate: '20/01/2569');
      final data = LeaveFormData(
        leaf: current,
        allUsers: const [],
        allLeaveRequests: [
          leave(requestId: 'A', startDate: '05/01/2569'),
          leave(requestId: 'B', startDate: '15/01/2569'),
          current,
        ],
      );

      expect(data.latestLeave?['requestId'], 'B');
      expect(data.latestLeaveLabel, 'ป่วย');
    });

    test('ไม่นับใบที่เกิดหลังใบปัจจุบัน', () {
      final current = leave(requestId: 'A', startDate: '05/01/2569');
      final data = LeaveFormData(
        leaf: current,
        allUsers: const [],
        allLeaveRequests: [
          current,
          leave(requestId: 'B', startDate: '15/01/2569'),
        ],
      );

      expect(data.latestLeave, isNull);
      expect(data.latestLeaveLabel, isNull);
    });

    test('ไม่นับใบลาของคนอื่น', () {
      final current = leave(requestId: 'A', startDate: '20/01/2569');
      final data = LeaveFormData(
        leaf: current,
        allUsers: const [],
        allLeaveRequests: [
          current,
          leave(
              requestId: 'B',
              startDate: '10/01/2569',
              fullName: 'สมหญิง รักเรียน'),
        ],
      );

      expect(data.latestLeave, isNull);
    });

    test('ไม่นับใบลาคนละปีงบประมาณ', () {
      final current = leave(requestId: 'A', startDate: '20/01/2569');
      final data = LeaveFormData(
        leaf: current,
        allUsers: const [],
        allLeaveRequests: [
          current,
          leave(requestId: 'B', startDate: '10/01/2568', year: '2568'),
        ],
      );

      expect(data.latestLeave, isNull);
    });
  });

  group('ตารางสถิติวันลา', () {
    test('รวมเฉพาะใบลาประเภทเดียวกันที่เกิดก่อนหน้า', () {
      final current =
          leave(requestId: 'C', startDate: '20/01/2569', totalDays: '2');
      final data = LeaveFormData(
        leaf: current,
        allUsers: const [],
        allLeaveRequests: [
          leave(requestId: 'A', startDate: '05/01/2569', totalDays: '1'),
          leave(requestId: 'B', startDate: '10/01/2569', totalDays: '3'),
          leave(
              requestId: 'X',
              startDate: '12/01/2569',
              leaveType: 'ลากิจส่วนตัว',
              totalDays: '5'),
          current,
        ],
      );

      final sick = data.statRows.firstWhere((r) => r.label == 'ป่วย');
      expect(sick.previousTimes, '2'); // ใบ A กับ B
      expect(sick.previousDays, '4'); // 1 + 3
      expect(sick.currentTimes, '1');
      expect(sick.currentDays, '2');
      expect(sick.totalTimes, '3');
      expect(sick.totalDays, '6');

      // ลากิจมีแต่ใบก่อนหน้า ใบปัจจุบันเป็นลาป่วย จึงไม่นับเป็นครั้งนี้
      final personal =
          data.statRows.firstWhere((r) => r.label == 'ลากิจส่วนตัว');
      expect(personal.previousTimes, '1');
      expect(personal.currentTimes, '-');
      expect(personal.totalTimes, '1');
    });

    test('ไม่มีประวัติเลย แสดงขีดแทนศูนย์', () {
      final current = leave(requestId: 'A', leaveType: 'ลาคลอดบุตร');
      final data = LeaveFormData(
        leaf: current,
        allUsers: const [],
        allLeaveRequests: [current],
      );

      final maternity =
          data.statRows.firstWhere((r) => r.label == 'ลาคลอดบุตร');
      expect(maternity.previousTimes, '-');
      expect(maternity.previousDays, '-');
      expect(maternity.currentTimes, '1');
    });
  });

  group('ชื่อผู้บริหารสำหรับช่องเซ็น', () {
    final List<Map<String, dynamic>> users = [
      {'fullName': 'ก ผอ', 'ตำแหน่งงานบริหาร': 'ผู้อำนวยการโรงเรียน'},
      {
        'fullName': 'ข รองผอ',
        'ตำแหน่งงานบริหาร': 'รองผู้อำนวยการกลุ่มบริหารงานบุคคล'
      },
    ];

    test('หาเจอตามชื่อตำแหน่ง', () {
      final data = LeaveFormData(
        leaf: const {},
        allUsers: users,
        allLeaveRequests: const [],
      );

      expect(data.directorName, '(ก ผอ)');
      expect(data.deputyName, '(ข รองผอ)');
    });

    test('ไม่มีคนในตำแหน่งนั้น ให้เว้นช่องว่างไว้เซ็น', () {
      final data = LeaveFormData(
        leaf: const {},
        allUsers: users,
        allLeaveRequests: const [],
      );

      expect(data.hrName, LeaveFormData.blankSignature);
    });

    test('ไม่มีข้อมูลบุคลากรเลย ก็ยังไม่พัง', () {
      final data = LeaveFormData(
        leaf: const {},
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.directorName, LeaveFormData.blankSignature);
    });
  });

  group('ประเภทการลาที่แสดงเป็นช่องติ๊ก', () {
    test('ใช้รายการจากฐานข้อมูลเมื่อมี', () {
      final data = LeaveFormData(
        leaf: const {},
        allUsers: const [],
        allLeaveRequests: const [],
        leaveTypeNames: const ['ลาป่วย', 'ลาพักผ่อน', '---เลือก---'],
      );

      expect(data.printableLeaveTypes, ['ลาป่วย', 'ลาพักผ่อน']);
    });

    test('ไม่มีข้อมูลจากฐาน ใช้สามประเภทมาตรฐาน', () {
      final data = LeaveFormData(
        leaf: const {},
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.printableLeaveTypes,
          ['ลาป่วย', 'ลากิจส่วนตัว', 'ลาคลอดบุตร']);
    });

    test('ติ๊กเฉพาะประเภทที่ตรงตัวเป๊ะ', () {
      final data = LeaveFormData(
        leaf: const {'leaveType': 'ลาป่วย'},
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.isSelectedLeaveType('ลาป่วย'), isTrue);
      expect(data.isSelectedLeaveType('ลากิจส่วนตัว'), isFalse);
      expect(data.isSelectedLeaveType(''), isFalse);
    });
  });

  group('การแปลงวันที่', () {
    test('อ่านรูปแบบ วัน/เดือน/ปี พ.ศ. ได้', () {
      final parsed = LeaveFormData.parseDate('10/01/2569');
      expect(parsed?.year, 2026);
      expect(parsed?.month, 1);
      expect(parsed?.day, 10);
    });

    test('ค่าที่อ่านไม่ได้คืน null ไม่โยน error', () {
      expect(LeaveFormData.parseDate(null), isNull);
      expect(LeaveFormData.parseDate('ไม่ใช่วันที่'), isNull);
    });

    test('วันที่เขียนใบลาแปลงเป็นข้อความไทยพร้อม พ.ศ.', () {
      final data = LeaveFormData(
        leaf: const {'timestamp': '2026-01-10T08:30:00'},
        allUsers: const [],
        allLeaveRequests: const [],
      );

      expect(data.requestDay, '10');
      expect(data.requestMonth, 'มกราคม');
      expect(data.requestYear, '2569');
    });
  });
}
