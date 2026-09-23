// เทสของใบลาฉบับ HTML ที่ใช้ตอนพิมพ์/บันทึก PDF
//
// หน้าพิมพ์เป็นเอกสารราชการที่ส่งให้ผู้บริหารเซ็นจริง ถ้าข้อมูลตกหล่นไปช่องใด
// ช่องหนึ่งจะไม่มีอะไรเตือนเลยจนกว่าจะมีคนพิมพ์ออกมาแล้วเห็นเอง

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/utils/school_info.dart';
import 'package:school_leave_app/widgets/leave_form_data.dart';
import 'package:school_leave_app/widgets/leave_form_html.dart';

void main() {
  LeaveFormData buildData() => LeaveFormData(
        leaf: {
          'requestId': 'R-2',
          'fullName': 'นางสมหญิง รักเรียน',
          'position': 'ครู',
          'academicStanding': 'ชำนาญการพิเศษ',
          'leaveType': 'ลาป่วย',
          'reason': 'มีไข้สูง',
          'startDate': '10/09/2569',
          'endDate': '12/09/2569',
          'totalDays': '3',
          'year': '2569',
          'phone': '081-234-5678',
          'timestamp': '2026-09-09T09:15:00',
          'receiveNumber': '45',
        },
        allUsers: <Map<String, dynamic>>[
          {
            'fullName': 'นายสมศักดิ์ บริหารดี',
            'ตำแหน่งงานบริหาร': 'ผู้อำนวยการโรงเรียน',
          },
        ],
        allLeaveRequests: <Map<String, dynamic>>[
          {
            'requestId': 'R-1',
            'fullName': 'นางสมหญิง รักเรียน',
            'leaveType': 'ลาป่วย',
            'startDate': '05/08/2569',
            'totalDays': '1',
            'year': '2569',
            'timestamp': '2026-08-05T08:00:00',
          },
        ],
        leaveTypeNames: const ['ลาป่วย', 'ลากิจส่วนตัว', 'ลาคลอดบุตร'],
      );

  test('ใส่ข้อมูลของผู้ลาครบทุกช่องที่ต้องใช้', () {
    final html = buildLeaveFormHtml(buildData());

    expect(html, contains('นางสมหญิง รักเรียน'));
    expect(html, contains('ครู ชำนาญการพิเศษ'));
    expect(html, contains('ขอลาป่วย'));
    expect(html, contains('มีไข้สูง'));
    expect(html, contains('081-234-5678'));
    expect(html, contains('10 กันยายน 2569'));
    expect(html, contains('12 กันยายน 2569'));
    expect(html, contains('รับที่ 45'));
    expect(html, contains('9 กันยายน 2569')); // วันที่เขียนใบลา
  });

  test('ใช้ชื่อโรงเรียนจากไฟล์กลาง ไม่ได้พิมพ์ฝังไว้', () {
    final html = buildLeaveFormHtml(buildData());

    expect(html, contains(SchoolInfo.fullName));
    expect(html, contains(SchoolInfo.address));
    expect(html, contains('เรียน ${SchoolInfo.addressee}'));
  });

  test('ติ๊กเฉพาะประเภทการลาที่เลือก', () {
    final html = buildLeaveFormHtml(buildData());

    // ช่องที่ติ๊กจะมีเครื่องหมายถูกอยู่ในกล่องก่อนชื่อประเภท
    expect(html, contains('<span class="check">✓</span><span>ลาป่วย</span>'));
    expect(html,
        contains('<span class="check"></span><span>ลากิจส่วนตัว</span>'));
  });

  test('ชื่อผู้อำนวยการมาจากทะเบียนบุคลากร', () {
    final html = buildLeaveFormHtml(buildData());

    expect(html, contains('(นายสมศักดิ์ บริหารดี)'));
    // ตำแหน่งที่ยังไม่มีคน ให้เว้นวงเล็บว่างไว้เซ็น
    expect(html, contains(LeaveFormData.blankSignature));
  });

  test('ตารางสถิตินับใบลาก่อนหน้าถูกต้อง', () {
    final html = buildLeaveFormHtml(buildData());

    // ลาป่วย: เคยลามาแล้ว 1 ครั้ง 1 วัน + ครั้งนี้ 1 ครั้ง 3 วัน = 2 ครั้ง 4 วัน
    expect(
        html,
        contains(
            '<tr><td>ป่วย</td><td>1</td><td>1</td><td>1</td><td>3</td><td>2</td><td>4</td></tr>'));
  });

  test('ปีกนกสูงพอดีกับจำนวนประเภทการลา ไม่ใช่ขนาดตายตัว', () {
    LeaveFormData withTypes(List<String> types) => LeaveFormData(
          leaf: const {'leaveType': 'ลาป่วย'},
          allUsers: const [],
          allLeaveRequests: const [],
          leaveTypeNames: types,
        );

    // สูตร: จำนวน × 22px + ช่องไฟ 2px  (3 อัน = 70, 4 อัน = 94)
    expect(buildLeaveFormHtml(withTypes(['ลาป่วย', 'ลากิจส่วนตัว', 'ลาคลอดบุตร'])),
        contains('height: 70px'));
    expect(
        buildLeaveFormHtml(
            withTypes(['ลาป่วย', 'ลากิจส่วนตัว', 'ลาคลอดบุตร', 'ลาพักผ่อน'])),
        contains('height: 94px'));
  });

  test('autoPrint ใส่สคริปต์สั่งพิมพ์ให้เฉพาะตอนที่ขอ', () {
    expect(buildLeaveFormHtml(buildData(), autoPrint: true),
        contains('window.print()'));

    final plain = buildLeaveFormHtml(buildData());
    // ปุ่มพิมพ์บนแถบเครื่องมือยังมีอยู่ แต่ต้องไม่มีสคริปต์สั่งพิมพ์อัตโนมัติ
    expect(plain, isNot(contains('window.addEventListener')));
  });

  test('ข้อความของผู้ใช้ถูก escape กัน HTML หลุดเข้าไปในเอกสาร', () {
    final data = LeaveFormData(
      leaf: {
        'fullName': '<script>alert(1)</script>',
        'reason': 'ป่วย & อ่อนเพลีย',
        'leaveType': 'ลาป่วย',
      },
      allUsers: const [],
      allLeaveRequests: const [],
    );

    final html = buildLeaveFormHtml(data);

    expect(html, isNot(contains('<script>alert(1)</script>')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, contains('ป่วย &amp; อ่อนเพลีย'));
  });
}
