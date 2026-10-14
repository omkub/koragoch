// เทสสิทธิ์ใบลา (lib/utils/leave_permissions.dart)

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/utils/leave_permissions.dart';

void main() {
  final mine = {'id_user': 5, 'fullName': 'ครู ก', 'status': 'รอพิจารณา'};
  final others = {'id_user': 9, 'fullName': 'ครู ข', 'status': 'รอพิจารณา'};
  final approved = {...mine, 'status': 'ส่งใบแล้ว'};

  test('ส่งใบลาแทนคนอื่นได้เฉพาะผู้ดูแลระบบ', () {
    expect(LeavePermissions.canFileForOthers('ผู้ดูแลระบบ'), isTrue);
    expect(LeavePermissions.canFileForOthers('ผู้บริหาร'), isFalse);
    expect(LeavePermissions.canFileForOthers('ครู'), isFalse);
    expect(LeavePermissions.canFileForOthers(null), isFalse);
  });

  test('ผู้ดูแลระบบแก้ได้ทุกใบ', () {
    expect(LeavePermissions.canModify(others, role: 'ผู้ดูแลระบบ'), isTrue);
    expect(LeavePermissions.canModify(approved, role: 'ผู้ดูแลระบบ'), isTrue);
  });

  test('สิทธิ์อื่นแก้ได้เฉพาะใบของตัวเองที่ยังไม่อนุมัติ', () {
    for (final role in ['ครู', 'ผู้บริหาร']) {
      expect(LeavePermissions.canModify(mine, role: role, myId: 5), isTrue);
      expect(LeavePermissions.canModify(others, role: role, myId: 5), isFalse);
      expect(
          LeavePermissions.canModify(approved, role: role, myId: 5), isFalse);
    }
  });

  test('ไม่มี id ให้เทียบ ใช้ชื่อเต็ม', () {
    final noId = {'fullName': 'ครู ก', 'status': 'ยังไม่ส่ง'};
    expect(LeavePermissions.canModify(noId, role: 'ครู', myName: 'ครู ก'),
        isTrue);
    expect(LeavePermissions.canModify(noId, role: 'ครู', myName: 'ครู ข'),
        isFalse);
    expect(LeavePermissions.canModify(noId, role: 'ครู'), isFalse);
  });

  test('id_user ต่างกัน แม้ชื่อซ้ำ ก็ไม่ใช่ใบของตัวเอง', () {
    final sameName = {'id_user': 9, 'fullName': 'ครู ก', 'status': 'รอพิจารณา'};
    expect(
        LeavePermissions.canModify(sameName,
            role: 'ครู', myName: 'ครู ก', myId: 5),
        isFalse);
  });
}
