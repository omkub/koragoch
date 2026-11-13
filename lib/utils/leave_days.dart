/// สูตรนับจำนวนวันลา — ใช้ร่วมกันทุกที่ ห้ามเขียนสูตรซ้ำในหน้าจอ
///
/// ผู้ใช้: app PC (`leave_form_screen.dart`), app มือถือ แบบใหม่
/// (`mobile_v2/mobile_leave_form.dart`) และแบบเดิม
/// (`mobile/mobile_leave_form_screen.dart`), ปุ่ม "คำนวณวันลาย้อนหลัง"
/// (`calendar_settings_tab.dart`) และไปราชการ
/// (`OfficialTripService.countWorkingDays`)
///
/// กติกา
/// - ครึ่งวัน = 0.5
/// - ลาคลอด = นับวันปฏิทินทุกวัน (รวมเสาร์-อาทิตย์ / วันหยุด)
/// - อื่น ๆ = นับวันทำการ: วันทำงานพิเศษนับเสมอ, วันหยุดพิเศษไม่นับ,
///   เสาร์-อาทิตย์ไม่นับ
/// - ตัดเวลาออกก่อนนับ (นับตามวันที่เท่านั้น) และสลับให้ถ้าวันเริ่มอยู่หลังวันสิ้นสุด
class LeaveDays {
  LeaveDays._();

  /// ประเภทการลาที่นับแบบวันปฏิทิน
  static bool isMaternityType(String? leaveType) =>
      (leaveType ?? '').contains('คลอด');

  /// คีย์วันที่ 'YYYY-MM-DD' — รูปแบบเดียวกับชุดวันหยุด / วันทำงานพิเศษ
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static num count(
    DateTime start,
    DateTime end, {
    bool halfDay = false,
    bool maternity = false,
    Set<String> holidays = const {},
    Set<String> workingDays = const {},
  }) {
    if (halfDay) return 0.5;

    var first = DateTime(start.year, start.month, start.day);
    var last = DateTime(end.year, end.month, end.day);
    if (last.isBefore(first)) {
      final tmp = first;
      first = last;
      last = tmp;
    }

    if (maternity) {
      // นับเป็นวันตามปฏิทิน ไม่ใช้ difference().inDays เพราะช่วงเปลี่ยนเวลา
      // (DST) ทำให้ได้ 23 ชม. แล้วปัดลง
      var days = 0;
      for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
        days++;
      }
      return days;
    }

    var total = 0;
    for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
      final key = dateKey(day);
      final isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      if (workingDays.contains(key)) {
        total++;
      } else if (!holidays.contains(key) && !isWeekend) {
        total++;
      }
    }
    return total;
  }

  static DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
}
