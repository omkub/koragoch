// เทสของข้อมูลโรงเรียน (lib/utils/school_info.dart)
//
// จุดสำคัญคือ "ค่าสำรอง" — ใบลาเป็นเอกสารราชการ ถ้าอ่านตาราง Schools ไม่ได้
// หัวกระดาษต้องไม่ว่าง และต้องไม่แสดงคำว่า null

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/utils/school_info.dart';

void main() {
  setUp(SchoolInfo.reset);

  test('ยังไม่ได้โหลดจากฐานข้อมูล ก็ยังได้ชื่อโรงเรียนที่ถูกต้อง', () {
    expect(SchoolInfo.fullName, 'โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก');
    expect(SchoolInfo.address, contains('บุรีรัมย์'));
    expect(SchoolInfo.affiliation, isNotEmpty);
  });

  test('ข้อความที่ประกอบจากชื่อโรงเรียนสร้างถูกต้อง', () {
    expect(SchoolInfo.addressee,
        'ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก');
    expect(SchoolInfo.directorTitle,
        'ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก');
    expect(SchoolInfo.calendarTitle,
        'ปฏิทิน โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก');
  });

  test('ชื่อสองท่อนต่อกันแล้วได้ชื่อเต็ม', () {
    expect('${SchoolInfo.namePart1} ${SchoolInfo.namePart2}',
        SchoolInfo.fullName);
  });

  group('อ่านแถวจากตาราง Schools', () {
    test('ใช้ค่าจากฐานข้อมูลเมื่อมีครบ', () {
      final record = SchoolRecord.fromRow({
        'id_school': 2,
        'fullName': 'โรงเรียนทดสอบวิทยา',
        'namePart1': 'โรงเรียนทดสอบ',
        'namePart2': 'วิทยา',
        'address': 'อำเภอเมือง จังหวัดทดสอบ 10000',
        'affiliation': 'สังกัดเขตทดสอบ',
      });

      expect(record.idSchool, 2);
      expect(record.fullName, 'โรงเรียนทดสอบวิทยา');
      expect(record.namePart2, 'วิทยา');
    });

    test('ช่องไหนว่างให้ใช้ค่าสำรองเฉพาะช่องนั้น ไม่ทิ้งทั้งแถว', () {
      final record = SchoolRecord.fromRow({
        'id_school': 1,
        'fullName': 'โรงเรียนทดสอบวิทยา',
        'address': '   ',
        'affiliation': null,
      });

      expect(record.fullName, 'โรงเรียนทดสอบวิทยา');
      expect(record.address, SchoolRecord.fallback.address);
      expect(record.affiliation, SchoolRecord.fallback.affiliation);
    });

    test('แถวว่างเปล่าก็ยังได้ค่าสำรองครบ ไม่มีคำว่า null', () {
      final record = SchoolRecord.fromRow(<String, dynamic>{});

      expect(record.fullName, SchoolRecord.fallback.fullName);
      expect(record.namePart1, isNot(contains('null')));
      expect(record.address, isNot(contains('null')));
    });
  });
}
