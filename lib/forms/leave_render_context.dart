/// ข้อมูลใบลา → ตัวแทนข้อมูล / ช่องติ๊ก / ตาราง สำหรับวาดใบลาจากแม่แบบ
///
/// แปลมาจาก leaveContext() ใน central/src/forms/leaveTemplate.ts
/// ชื่อตัวแทนข้อมูลต้องตรงกับที่หน้าแบบฟอร์มใน web ให้เลือก (LEAVE_PLACEHOLDERS)
/// test/form_render_parity_test.dart เทียบผลกับ web ให้แล้ว
library;

import '../utils/school_info.dart';
import '../widgets/leave_form_data.dart';
import 'form_render.dart';

const _receiveBlank = '............................';

/// [school] ไม่ส่ง = โรงเรียนที่ระบบกำลังใช้งานอยู่
RenderContext leaveRenderContext(LeaveFormData data, {SchoolRecord? school}) {
  final s = school ?? SchoolInfo.current;
  final latest = data.latestLeaveLabel;
  return RenderContext(
    title: 'Leave-${data.fullName}',
    values: {
      'ชื่อ': data.fullName,
      'ตำแหน่ง': data.position,
      'วิทยฐานะ': data.academicStanding,
      'ตำแหน่งและวิทยฐานะ': data.positionWithStanding,
      'ตำแหน่งผู้ลา': data.position.isEmpty ? '-' : data.position,
      'ประเภทการลา': data.leaveTypeRaw,
      'เรื่อง': data.subject,
      'เหตุผล': data.reason,
      'วันที่เริ่ม': data.startDateText,
      'วันที่สิ้นสุด': data.endDateText,
      'จำนวนวัน': data.totalDaysText,
      'วันที่ยื่น': '${data.requestDay} ${data.requestMonth} ${data.requestYear}',
      'วันที่ยื่น-วัน': data.requestDay,
      'วันที่ยื่น-เดือน': data.requestMonth,
      'วันที่ยื่น-ปี': data.requestYear,
      'เบอร์โทร': data.phone,
      'ลาครั้งล่าสุด-เริ่ม': data.latestStartText,
      'ลาครั้งล่าสุด-สิ้นสุด': data.latestEndText,
      'ลาครั้งล่าสุด-จำนวนวัน': data.latestDaysText,
      'เลขรับ': data.receiveNumber ?? _receiveBlank,
      'วันที่รับ': data.receiveDate ?? _receiveBlank,
      'เวลารับ': data.receiveTime ?? '..............................',
      'โรงเรียน': s.fullName,
      'โรงเรียน-ส่วน1': s.namePart1,
      'โรงเรียน-ส่วน2': s.namePart2,
      'ที่อยู่โรงเรียน': s.address,
      'สังกัด': s.affiliation,
      'หัวหน้าบุคคล': data.hrName,
      'รองผอ.บุคคล': data.deputyName,
      'ผู้อำนวยการ': data.directorName,
    },
    flags: {
      'ลาครั้งล่าสุด=ป่วย': latest == 'ป่วย',
      'ลาครั้งล่าสุด=ลากิจส่วนตัว': latest == 'ลากิจส่วนตัว',
      'ลาครั้งล่าสุด=ลาคลอดบุตร': latest == 'ลาคลอดบุตร',
    },
    leaveTypes: [
      for (final t in data.printableLeaveTypes)
        (label: t, checked: data.isSelectedLeaveType(t)),
    ],
    reason: data.reason,
    stats: data.statRows,
  );
}
