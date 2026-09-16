// ═══════════════════════════════════════════════════════════════
// การเรียงลำดับรายชื่อบุคลากรที่ใช้ร่วมกันทุกหน้า
//
// ลำดับ: กลุ่มสาระ → ตำแหน่งบริหาร → วิทยฐานะ → ชื่อ
//   1. กลุ่มสาระ  : ฝ่ายบริหาร → ภาษาไทย → คณิตศาสตร์ → ... (ตาม kDepartmentPriority)
//   2. บริหาร     : ผู้อำนวยการ → รองผู้อำนวยการ → อื่น ๆ
//   3. วิทยฐานะ   : เชี่ยวชาญพิเศษ → เชี่ยวชาญ → ชำนาญการพิเศษ → ชำนาญการ → ไม่มี
//   4. ชื่อ-นามสกุล (ก-ฮ)
//
// อยากสลับลำดับกลุ่มสาระ แก้ที่ kDepartmentPriority ที่เดียวครับ 🥇🏆
// ═══════════════════════════════════════════════════════════════

/// ลำดับกลุ่มสาระ — แต่ละแถวคือชื่อเต็มและคำย่อที่ใช้เทียบแบบ "มีคำนี้อยู่"
/// (ข้อมูลในฐานข้อมูลสะกดไม่เหมือนกันทุกแถว จึงเทียบด้วย contains)
const List<List<String>> kDepartmentPriority = [
  ['ฝ่ายบริหาร', 'บริหาร'],
  ['ภาษาไทย', 'ไทย'],
  ['คณิตศาสตร์', 'คณิต'],
  ['วิทยาศาสตร์และเทคโนโลยี', 'วิทยาศาสตร์', 'วิท'],
  ['สังคมศึกษา ศาสนา และวัฒนธรรม', 'สังคมศึกษา', 'สังคม'],
  ['ศิลปะ'],
  ['สุขศึกษาและพลศึกษา', 'สุขศึกษา', 'สุข'],
  ['การงานอาชีพ', 'การงาน'],
  ['ภาษาต่างประเทศ', 'ต่างประเทศ'],
  ['งานสำนักงาน', 'สำนักงาน'],
  ['อื่นๆ', 'อื่น ๆ', 'อื่น'],
];

/// วิทยฐานะเรียงจากสูงไปต่ำ
const List<String> kAcademicPriorityHighToLow = [
  'เชี่ยวชาญพิเศษ',
  'เชี่ยวชาญ',
  'ชำนาญการพิเศษ',
  'ชำนาญการ',
  'ไม่มีวิทยฐานะ',
];

/// อ่านค่าแรกที่ไม่ว่างจากคีย์ที่เป็นไปได้ (ชื่อคอลัมน์ไม่ตรงกันทุกแหล่ง)
String _textValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != '---เลือก---') {
      return value;
    }
  }
  return '';
}

String departmentOf(Map<String, dynamic> teacher) =>
    _textValue(teacher, ['department', 'กลุ่มสาระการเรียนรู้', 'กลุ่มสาระ']);

String positionOf(Map<String, dynamic> teacher) =>
    _textValue(teacher, ['position', 'ตำแหน่ง', 'adminPosition']);

String academicOf(Map<String, dynamic> teacher) =>
    _textValue(teacher, ['academicStanding', 'วิทยฐานะ', 'rank']);

/// ลำดับของกลุ่มสาระ (ไม่อยู่ในรายการ = ไปท้ายสุด)
int departmentPriorityIndex(String department) {
  final index = kDepartmentPriority.indexWhere(
    (aliases) => aliases.any((item) => department.contains(item)),
  );
  return index == -1 ? 999 : index;
}

/// ลำดับของวิทยฐานะ (ไม่ระบุ = ไปท้ายสุด)
int academicPriorityIndex(String academic) {
  final index =
      kAcademicPriorityHighToLow.indexWhere((item) => academic.contains(item));
  return index == -1 ? 999 : index;
}

/// ผู้อำนวยการมาก่อนรองผู้อำนวยการ แล้วค่อยครู
int managementPriority(Map<String, dynamic> teacher) {
  final position = positionOf(teacher);
  if (position.contains('ผู้อำนวยการ') && !position.contains('รอง')) return 0;
  if (position.contains('รองผู้อำนวยการ') || position.contains('รอง')) return 1;
  return 2;
}

/// ตัวเปรียบเทียบมาตรฐานสำหรับ `List.sort`
int compareTeachers(Map<String, dynamic> a, Map<String, dynamic> b) {
  final deptCompare = departmentPriorityIndex(departmentOf(a))
      .compareTo(departmentPriorityIndex(departmentOf(b)));
  if (deptCompare != 0) return deptCompare;

  final managementCompare =
      managementPriority(a).compareTo(managementPriority(b));
  if (managementCompare != 0) return managementCompare;

  final academicCompare = academicPriorityIndex(academicOf(a))
      .compareTo(academicPriorityIndex(academicOf(b)));
  if (academicCompare != 0) return academicCompare;

  return (a['fullName'] ?? '')
      .toString()
      .compareTo((b['fullName'] ?? '').toString());
}

/// คืนรายชื่อชุดใหม่ที่เรียงแล้ว (ไม่แก้ list เดิม)
List<Map<String, dynamic>> sortedTeachers(Iterable<Map<String, dynamic>> list) =>
    List<Map<String, dynamic>>.from(list)..sort(compareTeachers);

/// เรียง "ชื่อกลุ่มสาระ" ตามลำดับเดียวกัน ใช้กับแท็บ/ตัวกรอง
List<String> sortedDepartmentNames(Iterable<String> departments) =>
    departments.toList()
      ..sort((a, b) {
        final compare =
            departmentPriorityIndex(a).compareTo(departmentPriorityIndex(b));
        return compare != 0 ? compare : a.compareTo(b);
      });
