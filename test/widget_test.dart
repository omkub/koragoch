// เทสของฟังก์ชันล้วน ๆ ที่เป็นกติกาทางธุรกิจของระบบ
//
// ไฟล์นี้เดิมเป็นเทส "ปุ่มนับเลข" ที่ `flutter create` แถมมาให้ตอนสร้างโปรเจกต์
// ซึ่งไม่เคยตรงกับแอปนี้เลยและตกมาตลอด จึงเปลี่ยนมาทดสอบของจริงแทน
//
// เลือกทดสอบสองเรื่องนี้เพราะเป็นตรรกะที่เคยแก้ไปแล้วหลายรอบ และถ้าพังจะกระทบ
// ทุกหน้าพร้อมกัน แต่มองด้วยตาไม่เห็นทันที

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/utils/profile_image.dart';
import 'package:school_leave_app/utils/teacher_sort.dart';

void main() {
  group('การเรียงลำดับบุคลากร', () {
    Map<String, dynamic> teacher(
      String fullName, {
      String department = '',
      String position = 'ครู',
      String academic = '',
    }) =>
        {
          'fullName': fullName,
          'department': department,
          'position': position,
          'academicStanding': academic,
        };

    test('เรียงตามกลุ่มสาระก่อน: ฝ่ายบริหาร → ภาษาไทย → คณิตศาสตร์', () {
      final sorted = sortedTeachers([
        teacher('ค', department: 'คณิตศาสตร์'),
        teacher('ก', department: 'ฝ่ายบริหาร'),
        teacher('ข', department: 'ภาษาไทย'),
      ]);

      expect(sorted.map((t) => t['fullName']), ['ก', 'ข', 'ค']);
    });

    test('อยู่กลุ่มสาระเดียวกัน ให้เรียงตามวิทยฐานะจากสูงไปต่ำ', () {
      final sorted = sortedTeachers([
        teacher('ชำนาญการ', department: 'ภาษาไทย', academic: 'ชำนาญการ'),
        teacher('เชี่ยวชาญ', department: 'ภาษาไทย', academic: 'เชี่ยวชาญ'),
        teacher('ชำนาญการพิเศษ',
            department: 'ภาษาไทย', academic: 'ชำนาญการพิเศษ'),
      ]);

      expect(sorted.map((t) => t['fullName']),
          ['เชี่ยวชาญ', 'ชำนาญการพิเศษ', 'ชำนาญการ']);
    });

    test('ผู้อำนวยการมาก่อนรองผู้อำนวยการ แม้วิทยฐานะจะต่ำกว่า', () {
      final sorted = sortedTeachers([
        teacher('รองผอ',
            department: 'ฝ่ายบริหาร',
            position: 'รองผู้อำนวยการ',
            academic: 'เชี่ยวชาญ'),
        teacher('ผอ',
            department: 'ฝ่ายบริหาร',
            position: 'ผู้อำนวยการ',
            academic: 'ชำนาญการ'),
      ]);

      expect(sorted.map((t) => t['fullName']), ['ผอ', 'รองผอ']);
    });

    test('กลุ่มสาระที่ไม่อยู่ในรายการจะไปอยู่ท้ายสุด', () {
      expect(departmentPriorityIndex('กลุ่มสาระที่ไม่มีจริง'), 999);
      expect(departmentPriorityIndex('ฝ่ายบริหาร'), 0);
    });

    test('สะกดกลุ่มสาระไม่ครบก็ยังจัดลำดับถูก (เทียบแบบมีคำนี้อยู่)', () {
      // ข้อมูลในฐานข้อมูลสะกดไม่เหมือนกันทุกแถว จึงต้องรองรับคำย่อ
      expect(departmentPriorityIndex('คณิต'),
          departmentPriorityIndex('คณิตศาสตร์'));
    });

    test('ไม่แก้ไขลิสต์ต้นฉบับ', () {
      final original = [
        teacher('ข', department: 'คณิตศาสตร์'),
        teacher('ก', department: 'ฝ่ายบริหาร'),
      ];
      sortedTeachers(original);

      expect(original.first['fullName'], 'ข');
    });
  });

  group('การแปลงลิงก์รูปโปรไฟล์', () {
    test('ดึง file id ออกจากลิงก์ Google Drive ได้ทุกรูปแบบที่ใช้จริง', () {
      const id = '1AbCdEfGhIjKlMnOpQrStUvWxYz01234';
      for (final url in [
        'https://drive.google.com/file/d/$id/view?usp=sharing',
        'https://drive.google.com/open?id=$id',
        'https://drive.google.com/uc?export=view&id=$id',
        'https://drive.google.com/thumbnail?id=$id&sz=w200',
      ]) {
        expect(extractDriveFileId(url), id, reason: 'ล้มเหลวที่ $url');
      }
    });

    test('ลิงก์ Drive ถูกแปลงไปใช้พร็อกซี wsrv.nl', () {
      // ยิงตรงไป lh3 จะโดน HTTP 429 เวลาโหลดหลายรูปพร้อมกัน
      // จนรูปหายทั้งหน้า — เคยเป็นบั๊กที่ไล่หากันอยู่นาน
      const id = '1AbCdEfGhIjKlMnOpQrStUvWxYz01234';
      final resolved =
          resolveDisplayImageUrl('https://drive.google.com/open?id=$id');

      expect(resolved, contains('wsrv.nl'));
      expect(resolved, contains(id));
    });

    test('ค่าว่างหรือค่าที่ไม่ใช่ลิงก์ คืน null เพื่อให้แสดงตัวอักษรย่อแทน', () {
      expect(resolveDisplayImageUrl(null), isNull);
      expect(resolveDisplayImageUrl(''), isNull);
      expect(resolveDisplayImageUrl('   '), isNull);
      expect(resolveDisplayImageUrl('ไม่ใช่ลิงก์'), isNull);
    });

    test('รูปที่เพิ่งเลือกจากเครื่อง (data URL) ส่งผ่านไปตรง ๆ', () {
      const dataUrl = 'data:image/jpeg;base64,AAAA';
      expect(resolveDisplayImageUrl(dataUrl), dataUrl);
    });

    test('ลิงก์รูปจากที่อื่นที่ไม่ใช่ Drive ใช้ได้ตามเดิม', () {
      const url = 'https://example.com/photo.jpg';
      expect(resolveDisplayImageUrl(url), url);
    });
  });
}
