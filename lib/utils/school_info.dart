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

  /// อ่านจากแถวของตาราง Schools — ช่องไหนว่างให้ใช้ค่าสำรองแทนทีละช่อง
  factory SchoolRecord.fromRow(Map<String, dynamic> row) {
    String pick(String key, String fallbackValue) {
      final value = (row[key] ?? '').toString().trim();
      return value.isEmpty ? fallbackValue : value;
    }

    return SchoolRecord(
      idSchool: int.tryParse(row['id_school']?.toString() ?? ''),
      fullName: pick('fullName', fallback.fullName),
      namePart1: pick('namePart1', fallback.namePart1),
      namePart2: pick('namePart2', fallback.namePart2),
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

  /// โหลดข้อมูลโรงเรียนจากฐานข้อมูล (ทำครั้งเดียวต่อการเปิดแอป)
  ///
  /// [force] true จะโหลดใหม่แม้เคยโหลดแล้ว ใช้ตอนแอดมินเพิ่งแก้ข้อมูล
  ///
  /// ล้มเหลวก็ไม่เป็นไร ค่าสำรองยังใช้งานได้ จึงไม่โยน error ออกไป
  static Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;

    try {
      final client = Supabase.instance.client;
      // ตอนนี้มีโรงเรียนเดียว จึงหยิบแถวแรกมาใช้
      // เวลาทำหลายโรงเรียนค่อยเปลี่ยนมาเลือกตาม Teachers.id_school
      final rows = await client
          .from('Schools')
          .select()
          .order('id_school')
          .limit(1);

      if (rows.isNotEmpty) {
        _current = SchoolRecord.fromRow(Map<String, dynamic>.from(rows.first));
        _loaded = true;
        debugPrint('✅ โหลดข้อมูลโรงเรียนแล้ว: ${_current.fullName}');
        return;
      }

      debugPrint('ℹ️  ตาราง Schools ยังไม่มีข้อมูล — ใช้ค่าสำรอง');
    } catch (e) {
      // ยังไม่ได้สร้างตาราง หรือเน็ตหลุด — ใบลายังพิมพ์ได้ด้วยค่าสำรอง
      debugPrint('⚠️  โหลดข้อมูลโรงเรียนไม่สำเร็จ ใช้ค่าสำรองแทน: $e');
    }
  }

  /// ล้างค่าที่โหลดไว้ ใช้ตอนออกจากระบบ
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
