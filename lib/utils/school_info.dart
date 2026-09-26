/// ข้อมูลโรงเรียนที่ใช้ร่วมกันทุกที่ในระบบ
///
/// ค่าจริงมาจากตาราง `Schools` ใน Supabase (ดู supabase/create_schools_table.sql)
/// โหลดครั้งเดียวตอนเข้าระบบแล้วเก็บไว้ในหน่วยความจำ
///
/// ถ้ายังโหลดไม่เสร็จหรือต่อฐานข้อมูลไม่ได้ จะใช้ค่าสำรองที่ฝังไว้แทน
/// เพราะใบลาเป็นเอกสารราชการ ปล่อยให้หัวกระดาษว่างไม่ได้
///
/// เดิมชื่อโรงเรียนถูกพิมพ์ฝังไว้ในโค้ด 18 จุด และสะกดไม่ตรงกันด้วย
/// (หน้าปฏิทินเขียน "รมบุรี" ส่วนใบลาเขียน "รมย์บุรี")
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ข้อมูลโรงเรียนหนึ่งแห่ง
@immutable
class SchoolRecord {
  final int? idSchool;
  final String fullName;
  final String namePart1;
  final String namePart2;
  final String address;
  final String affiliation;

  const SchoolRecord({
    this.idSchool,
    required this.fullName,
    required this.namePart1,
    required this.namePart2,
    required this.address,
    required this.affiliation,
  });

  /// ค่าสำรองของโรงเรียนปัจจุบัน ใช้ตอนที่ยังอ่านฐานข้อมูลไม่ได้
  static const SchoolRecord fallback = SchoolRecord(
    fullName: 'โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก',
    namePart1: 'โรงเรียนรมย์บุรีพิทยาคม',
    namePart2: 'รัชมังคลาภิเษก',
    address: 'อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000',
    affiliation:
        'สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์ กระทรวงศึกษาธิการ',
  );

  /// ต่อชื่อสองท่อนเป็นชื่อเต็ม ข้ามท่อนที่ว่าง
  static String joinName(String part1, String part2) =>
      [part1, part2].where((s) => s.trim().isNotEmpty).join(' ');

  /// อ่านจากแถวของตาราง Schools — ช่องไหนว่างให้ใช้ค่าสำรองแทนทีละช่อง
  ///
  /// ชื่อเต็มคำนวณจาก namePart1 + namePart2 เสมอ เพื่อให้แก้ชื่อโรงเรียน
  /// อัปเดตแค่สองช่องนี้พอ ไม่ต้องกลัวลืมแก้ fullName ให้ตรงกัน
  /// (ในฐานข้อมูล fullName ก็เป็นคอลัมน์ที่คำนวณให้อัตโนมัติเช่นกัน)
  factory SchoolRecord.fromRow(Map<String, dynamic> row) {
    String pick(String key, String fallbackValue) {
      final value = (row[key] ?? '').toString().trim();
      return value.isEmpty ? fallbackValue : value;
    }

    // ใช้ค่าสำรองของชื่อต่อเมื่อไม่มีชื่อมาเลยทั้งสองท่อน
    // ถ้ามีท่อนเดียว (โรงเรียนที่ชื่อไม่มีสร้อย) ต้องปล่อยอีกท่อนให้ว่างไว้
    // ไม่ใช่ไปหยิบสร้อยของโรงเรียนอื่นมาเติมให้
    final rawPart1 = (row['namePart1'] ?? '').toString().trim();
    final rawPart2 = (row['namePart2'] ?? '').toString().trim();
    final hasAnyPart = rawPart1.isNotEmpty || rawPart2.isNotEmpty;

    final part1 = hasAnyPart ? rawPart1 : fallback.namePart1;
    final part2 = hasAnyPart ? rawPart2 : fallback.namePart2;
    final joined = joinName(part1, part2);

    return SchoolRecord(
      idSchool: int.tryParse(row['id_school']?.toString() ?? ''),
      // ใช้คอลัมน์ fullName ต่อเมื่อไม่มีชื่อสองท่อนให้ประกอบเลย
      fullName: joined.isNotEmpty ? joined : pick('fullName', fallback.fullName),
      namePart1: part1,
      namePart2: part2,
      address: pick('address', fallback.address),
      affiliation: pick('affiliation', fallback.affiliation),
    );
  }
}

class SchoolInfo {
  const SchoolInfo._();

  static SchoolRecord _current = SchoolRecord.fallback;
  static bool _loaded = false;

  /// โรงเรียนที่ระบบกำลังใช้งานอยู่
  static SchoolRecord get current => _current;

  /// โรงเรียนของครูที่ล็อกอินอยู่ (Teachers.id_school)
  ///
  /// null = ยังไม่รู้ (ยังไม่ล็อกอิน หรืออ่านฐานข้อมูลไม่ได้) — ตอนนั้นแอป
  /// จะไม่กรองตามโรงเรียน ทำงานแบบเดิมก่อนมีหลายโรงเรียน
  /// ส่วนการกันข้ามโรงเรียนจริง ๆ อยู่ที่ RLS ฝั่งฐานข้อมูล ไม่ได้พึ่งค่านี้
  static int? get currentSchoolId => _current.idSchool;

  /// โหลดข้อมูลโรงเรียนจากฐานข้อมูล (ทำครั้งเดียวต่อการเปิดแอป)
  ///
  /// เลือกโรงเรียนตาม Teachers.id_school ของคนที่ล็อกอิน (ถามฐานข้อมูลผ่าน
  /// ฟังก์ชัน current_school_id() ซึ่งผูกกับ session ปลอมไม่ได้)
  /// ถ้าหาไม่เจอ ใช้โรงเรียนแถวแรกแบบเดิม
  ///
  /// [force] true จะโหลดใหม่แม้เคยโหลดแล้ว ใช้ตอนแอดมินเพิ่งแก้ข้อมูล
  ///
  /// ล้มเหลวก็ไม่เป็นไร ค่าสำรองยังใช้งานได้ จึงไม่โยน error ออกไป
  static Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;

    try {
      final client = Supabase.instance.client;
      // ต้องมี timeout เสมอ เพราะจุดที่เรียกฟังก์ชันนี้อยู่ในเส้นทางเข้าแอป
      // ถ้าเน็ตค้างแล้วรอไม่มีกำหนด ผู้ใช้จะเจอหน้าจอค้างกดอะไรไม่ได้
      // ค่าสำรองมีอยู่แล้ว รอไม่ได้ก็ใช้ค่าสำรองไปก่อน
      const timeout = Duration(seconds: 8);

      int? schoolId;
      try {
        final result =
            await client.rpc('current_school_id').timeout(timeout);
        schoolId = int.tryParse(result?.toString() ?? '');
      } catch (e) {
        // ยังไม่ได้รัน multi_school_step1_id_school.sql — ใช้แถวแรกแบบเดิม
        debugPrint('ℹ️  หาโรงเรียนของผู้ใช้ไม่ได้ ใช้โรงเรียนแรกแทน: $e');
      }

      var query = client.from('Schools').select();
      if (schoolId != null) query = query.eq('id_school', schoolId);
      final rows =
          await query.order('id_school').limit(1).timeout(timeout);

      if (rows.isNotEmpty) {
        _current = SchoolRecord.fromRow(Map<String, dynamic>.from(rows.first));
        _loaded = true;
        debugPrint('✅ โหลดข้อมูลโรงเรียนแล้ว: ${_current.fullName} '
            '(id_school=${_current.idSchool})');
        return;
      }

      debugPrint('ℹ️  ตาราง Schools ยังไม่มีข้อมูล — ใช้ค่าสำรอง');
    } catch (e) {
      // ยังไม่ได้สร้างตาราง หรือเน็ตหลุด — ใบลายังพิมพ์ได้ด้วยค่าสำรอง
      debugPrint('⚠️  โหลดข้อมูลโรงเรียนไม่สำเร็จ ใช้ค่าสำรองแทน: $e');
    }
  }

  /// ล้างค่าที่โหลดไว้ ใช้ตอนออกจากระบบ
  ///
  /// สำคัญมากเมื่อมีหลายโรงเรียน: ถ้าไม่ล้าง คนถัดไปที่ล็อกอินบนเครื่องเดียวกัน
  /// จะได้ชื่อโรงเรียนและตัวกรองของคนก่อนหน้า
  static void reset() {
    _current = SchoolRecord.fallback;
    _loaded = false;
  }

  // ── ค่าที่หน้าจอต่าง ๆ เรียกใช้ ─────────────────────────────────

  /// ชื่อเต็มที่ใช้ในหัวเอกสารราชการ
  static String get fullName => _current.fullName;

  /// ชื่อส่วนแรก ใช้ตอนที่ต้องตัดบรรทัดกลางประโยค
  static String get namePart1 => _current.namePart1;

  /// ชื่อส่วนหลัง ต่อจาก [namePart1]
  static String get namePart2 => _current.namePart2;

  /// ที่อยู่ใต้ชื่อโรงเรียนในหัวเอกสาร
  static String get address => _current.address;

  /// ต้นสังกัด ใช้ต่อท้ายชื่อโรงเรียนในย่อหน้าแรกของใบลา
  static String get affiliation => _current.affiliation;

  /// คำขึ้นต้น "เรียน ..." ในใบลา
  static String get addressee => 'ผู้อำนวยการ$fullName';

  /// ชื่อตำแหน่งใต้ช่องเซ็นของผู้อำนวยการ
  static String get directorTitle => 'ผู้อำนวยการ$fullName';

  /// ชื่อที่ใช้บนหัวหน้าจอปฏิทิน
  static String get calendarTitle => 'ปฏิทิน $fullName';
}
