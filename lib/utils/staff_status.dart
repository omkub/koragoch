/// สถานะบุคลากร (Teachers.employment_status / left_date — supabase/staff_status.sql)
///
/// ไม่ลบรายชื่อคนที่ลาออก/เกษียณ/ย้าย เพราะใบลาเก่าเป็นเอกสารราชการ
/// แต่ซ่อนจากรายชื่อที่ใช้ทำงานวันนี้ และนับในรายงานเฉพาะปีงบประมาณที่ยัง
/// ปฏิบัติงานอยู่
///
/// ยังไม่ได้รัน SQL = ไม่มีคอลัมน์ = ทุกคนปฏิบัติงานอยู่ (ทำงานแบบเดิม)
library;

class StaffStatus {
  const StaffStatus._();

  static const active = 'active';
  static const resigned = 'resigned';
  static const retired = 'retired';
  static const transferred = 'transferred';

  /// สถานะที่ตั้งได้ เรียงตามที่แสดงในหน้าตั้งค่า
  static const all = [active, resigned, retired, transferred];

  static const labels = {
    active: 'ปฏิบัติงาน',
    resigned: 'ลาออก',
    retired: 'เกษียณ',
    transferred: 'ย้าย',
  };

  static String label(String? status) =>
      labels[status ?? active] ?? labels[active]!;

  static String statusOf(Map<String, dynamic> row) {
    final s = (row['employment_status'] ?? '').toString().trim();
    return labels.containsKey(s) ? s : active;
  }

  /// ยังปฏิบัติงานอยู่ ณ วันที่ [on] (ไม่ส่ง = วันนี้)
  ///
  /// สถานะพ้นสภาพมีผลตั้งแต่ left_date — ตั้ง "ย้าย มีผล 26 ต.ค." ไว้ล่วงหน้า
  /// วันที่ 25 ยังปฏิบัติงานอยู่ วันที่ 26 จึงหายจากรายชื่อ
  /// (ตรงกับ staff_is_working() ใน supabase/staff_status_effective_date.sql)
  /// ไม่มีคอลัมน์ / ค่าแปลก = ปฏิบัติงาน · ไม่ใส่วันที่ = พ้นสภาพทันที
  static bool isActive(Map<String, dynamic> row, {DateTime? on}) {
    if (statusOf(row) == active) return true;
    final left = leftDateOf(row);
    if (left == null) return false;
    final now = on ?? DateTime.now();
    return left.isAfter(DateTime(now.year, now.month, now.day));
  }

  /// บัญชีผู้ดูแลส่วนกลาง — ไม่ใช่บุคลากรของโรงเรียน ไม่แสดงในรายชื่อ
  static bool isSuperAdmin(Map<String, dynamic> row) {
    final v = row['is_super_admin'];
    return v == true || v.toString().toLowerCase() == 'true';
  }

  /// แสดงในรายชื่อที่ใช้ทำงานวันนี้ (เลือกคนส่งใบลาแทน, หน้าบุคลากร, ฯลฯ)
  static bool isListed(Map<String, dynamic> row) =>
      isActive(row) && !isSuperAdmin(row);

  static DateTime? leftDateOf(Map<String, dynamic> row) {
    final raw = (row['left_date'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// ยังปฏิบัติงานอยู่ในช่วงที่เริ่ม [periodStart] (เช่นต้นปีงบประมาณ) หรือไม่
  ///
  /// left_date = วันที่พ้นสภาพ "มีผลตั้งแต่" (วันแรกที่ไม่ได้ปฏิบัติงานแล้ว)
  /// ตามที่เขียนกันในคำสั่ง เช่น "เกษียณ 1 ต.ค. 2569"
  /// นับเฉพาะช่วงที่พ้นสภาพหลังวันเริ่มช่วง —
  /// เกษียณ 1 ต.ค. 2569 อยู่ในรายงานปีงบ 2569 (1 ต.ค. 68 – 30 ก.ย. 69)
  /// แต่ไม่อยู่ในปีงบ 2570 ไม่มีวันที่พ้นสภาพ = ไม่นับแล้ว (ไม่รู้ว่าออกเมื่อไร)
  static bool activeDuring(Map<String, dynamic> row, DateTime periodStart) {
    // ดูสถานะที่บันทึกไว้ ไม่ใช่ "วันนี้ยังทำงานไหม" — คนที่ตั้งย้ายล่วงหน้า
    // วันนี้ยังทำงานอยู่ แต่ต้องไม่ถูกนับในปีงบที่เริ่มหลังวันที่ย้าย
    if (statusOf(row) == active) return true;
    final left = leftDateOf(row);
    if (left == null) return false;
    final start =
        DateTime(periodStart.year, periodStart.month, periodStart.day);
    return left.isAfter(start);
  }

  /// วันเริ่มปีงบประมาณ (1 ต.ค.) ที่ [date] อยู่
  static DateTime fiscalYearStart(DateTime date) => date.month >= 10
      ? DateTime(date.year, 10, 1)
      : DateTime(date.year - 1, 10, 1);
}
