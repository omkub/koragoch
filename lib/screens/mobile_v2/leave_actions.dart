/// สถานะใบลา + การอนุมัติ / ไม่อนุมัติ / ลบ — ตรรกะเดียวกับหน้าประวัติมือถือเดิม
///
/// อนุมัติ = สถานะ "ส่งใบแล้ว" + ออกเลขรับ วันที่รับ เวลารับ
/// ไม่อนุมัติ = สถานะ "ยังไม่ส่ง" (ส่งกลับให้ผู้ลาแก้แล้วส่งใหม่)
/// มีแต่ผู้ดูแลระบบที่ทำได้ (ผู้บริหารไม่มีสิทธิ์อนุมัติ) — ฐานข้อมูลตรวจสิทธิ์ซ้ำอีกชั้น
library;

import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import '../../theme/app_tokens.dart';

enum LeaveStatusGroup { pending, approved, returned }

class LeaveStatus {
  LeaveStatus._();

  static const approveTo = 'ส่งใบแล้ว';
  static const returnTo = 'ยังไม่ส่ง';

  static String of(Map<String, dynamic> leave) =>
      (leave['status'] ?? 'รอพิจารณา').toString();

  static bool isApproved(String s) =>
      s == 'ส่งใบแล้ว' ||
      s == 'ส่งใบลาแล้ว' ||
      s == 'อนุมัติแล้ว' ||
      s == 'อนุญาต' ||
      (s.contains('อนุมัติ') && !s.contains('ไม่'));

  static LeaveStatusGroup group(String s) {
    if (isApproved(s)) return LeaveStatusGroup.approved;
    if (s.contains('รอ') || s.contains('พิจารณา')) {
      return LeaveStatusGroup.pending;
    }
    return LeaveStatusGroup.returned;
  }

  /// โทนหมึกของตรายางสถานะ
  static StampTone tone(String s) => switch (group(s)) {
        LeaveStatusGroup.approved => StampTone.approved,
        LeaveStatusGroup.pending => StampTone.pending,
        LeaveStatusGroup.returned => StampTone.returned,
      };

  /// ตรายางสถานะของใบลา (ลายเซ็นของระบบ)
  static Widget stamp(String s, {bool large = false}) =>
      StatusStamp(s.isEmpty ? '-' : s, tone: tone(s), large: large);
}

class LeaveActions {
  LeaveActions._();

  static final _service = FirebaseService();

  /// อนุมัติ — คืนเลขรับที่ออกให้
  static Future<String> approve(String requestId) async {
    final receiveNumber = await _service.generateReceiveNumber();
    final now = DateTime.now();
    await _service.updateLeaveRequest(requestId, {
      'status': LeaveStatus.approveTo,
      'receiveNumber': receiveNumber,
      // คอลัมน์ receiveDate/receiveTime เป็น date/time ต้องส่ง ISO (ค.ศ.)
      'receiveDate': FirebaseService.toIsoDate(now),
      'receiveTime': FirebaseService.toIsoTime(now.hour, now.minute),
    });
    return '$receiveNumber';
  }

  /// ไม่อนุมัติ — ส่งกลับเป็น "ยังไม่ส่ง"
  static Future<void> returnToApplicant(String requestId) =>
      _service.updateLeaveRequest(requestId, {'status': LeaveStatus.returnTo});

  /// ลบถาวร (ลบไฟล์ใบรับรองแพทย์ที่แนบด้วย)
  static Future<void> delete(Map<String, dynamic> leave) async {
    final medicalUrl = leave['medicalCertificate']?.toString() ?? '';
    if (medicalUrl.isNotEmpty) {
      await _service.deleteDriveFileStrict(medicalUrl);
    }
    await _service
        .deleteLeaveFromSupabase(leave['requestId']?.toString() ?? '');
  }
}
