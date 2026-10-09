import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_service.dart';

// ═══════════════════════════════════════════════════════════════
// ไปราชการ / ประชุม — อ่าน/เขียนตาราง OfficialTrips + OfficialTripMembers
// (ดู supabase/official_trips.sql)
//
// ตัวกันสิทธิ์จริงอยู่ในฐานข้อมูล (RLS + trigger guard_official_trip):
//   ครูอนุมัติเองไม่ได้ / แก้ได้เฉพาะของตัวเองที่ยังรอพิจารณา /
//   หลังอนุมัติแก้ได้เฉพาะรายงานผล — ฝั่งแอปซ่อนปุ่มให้ตรงกันเท่านั้น
//
// วันที่ในตารางนี้เป็นชนิด date จริง ส่ง/รับเป็น 'YYYY-MM-DD'
// (ไม่ใช่ข้อความวันที่ไทยแบบ Leaves)
// ═══════════════════════════════════════════════════════════════

class OfficialTripService {
  static const String pending = 'รอพิจารณา';
  static const String approved = 'อนุมัติ';
  static const String rejected = 'ไม่อนุมัติ';

  static const List<String> tripTypes = ['ประชุม', 'อบรม', 'สัมมนา', 'อื่นๆ'];
  static const List<String> travelModes = [
    'รถยนต์ส่วนตัว',
    'รถยนต์ราชการ',
    'รถโดยสารประจำทาง',
    'เครื่องบิน',
    'อื่นๆ',
  ];
  static const List<String> budgetSources = [
    'เบิกจากต้นสังกัด',
    'ผู้จัดออกค่าใช้จ่าย',
    'ไม่เบิกค่าใช้จ่าย',
  ];

  static const List<String> _thaiMonthsShort = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  final _firebaseService = FirebaseService();

  SupabaseClient get _client {
    final client = _firebaseService.supabaseClient;
    if (client == null) throw StateError('ยังเชื่อมต่อฐานข้อมูลไม่ได้');
    return client;
  }

  // ─── อ่าน ────────────────────────────────────────────────────

  /// รายการไปราชการที่ทับช่วง [from]–[to] พร้อมรายชื่อผู้ร่วมเดินทาง
  /// (`members` = รายการ id_user)
  Future<List<Map<String, dynamic>>> getTrips({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await FirebaseService.inSchool(_client
            .from('OfficialTrips')
            .select('*, OfficialTripMembers(id_user)'))
        .lte('startDate', dateKey(to))
        .gte('endDate', dateKey(from))
        .order('startDate', ascending: false);

    return (rows as List).map((row) {
      final trip = Map<String, dynamic>.from(row as Map);
      final members = (trip.remove('OfficialTripMembers') as List? ?? [])
          .map((m) => (m as Map)['id_user'])
          .whereType<int>()
          .toList();
      return {...trip, 'members': members};
    }).toList();
  }

  /// วันหยุด / วันทำงานพิเศษ (คีย์ 'YYYY-MM-DD') ใช้คำนวณจำนวนวัน
  /// แบบเดียวกับหน้าส่งใบลา
  Future<({Set<String> holidays, Set<String> workingDays})>
      getSpecialDates() async {
    try {
      final results = await Future.wait([
        _firebaseService.getSpecialHolidaysFromSupabase(),
        _firebaseService.getSpecialWorkingDaysFromSupabase(),
      ]);
      return (
        holidays: results[0].map(_specialDateKey).whereType<String>().toSet(),
        workingDays:
            results[1].map(_specialDateKey).whereType<String>().toSet(),
      );
    } catch (e) {
      debugPrint('⚠️  โหลดวันหยุดไม่สำเร็จ: $e');
      return (holidays: <String>{}, workingDays: <String>{});
    }
  }

  // ─── เขียน ───────────────────────────────────────────────────

  /// บันทึกรายการใหม่ แล้วเพิ่มผู้ร่วมเดินทาง
  /// (ผู้บันทึกถูกเพิ่มเป็นผู้ร่วมเดินทางให้อัตโนมัติโดย trigger)
  Future<void> createTrip(
      Map<String, dynamic> trip, Iterable<int> memberIds) async {
    final inserted = await _client
        .from('OfficialTrips')
        .insert(trip)
        .select('id_trip')
        .single();
    final idTrip = inserted['id_trip'] as int;
    final others = memberIds.where((id) => id != trip['id_user']).toSet();
    if (others.isNotEmpty) {
      await _client.from('OfficialTripMembers').upsert(
          [for (final id in others) {'id_trip': idTrip, 'id_user': id}],
          onConflict: 'id_trip,id_user',
          ignoreDuplicates: true);
    }
  }

  /// แก้รายการ และปรับรายชื่อผู้ร่วมเดินทางให้ตรงกับ [memberIds]
  /// (ผู้บันทึกต้องอยู่ในรายชื่อเสมอ)
  Future<void> updateTrip(int idTrip, Map<String, dynamic> changes,
      {required int ownerId,
      required Iterable<int> oldMemberIds,
      required Iterable<int> memberIds}) async {
    await _client.from('OfficialTrips').update(changes).eq('id_trip', idTrip);

    final wanted = {...memberIds, ownerId};
    final old = oldMemberIds.toSet();
    final toAdd = wanted.difference(old);
    final toRemove = old.difference(wanted);
    if (toAdd.isNotEmpty) {
      await _client.from('OfficialTripMembers').upsert(
          [for (final id in toAdd) {'id_trip': idTrip, 'id_user': id}],
          onConflict: 'id_trip,id_user',
          ignoreDuplicates: true);
    }
    if (toRemove.isNotEmpty) {
      await _client
          .from('OfficialTripMembers')
          .delete()
          .eq('id_trip', idTrip)
          .inFilter('id_user', toRemove.toList());
    }
  }

  Future<void> deleteTrip(int idTrip) =>
      _client.from('OfficialTrips').delete().eq('id_trip', idTrip);

  /// อนุมัติ / ไม่อนุมัติ (เฉพาะผู้ดูแลระบบ — ฐานข้อมูลปฏิเสธคนอื่น)
  Future<void> setStatus(int idTrip,
      {required String status, required int? approverId, String? note}) {
    return _client.from('OfficialTrips').update({
      'status': status,
      'approvedBy': status == pending ? null : approverId,
      'approvedAt':
          status == pending ? null : DateTime.now().toUtc().toIso8601String(),
      'approverNote': (note ?? '').trim().isEmpty ? null : note!.trim(),
    }).eq('id_trip', idTrip);
  }

  Future<void> saveReport(int idTrip, String summary) {
    final text = summary.trim();
    return _client.from('OfficialTrips').update({
      'reportSummary': text.isEmpty ? null : text,
      'reportedAt':
          text.isEmpty ? null : DateTime.now().toUtc().toIso8601String(),
    }).eq('id_trip', idTrip);
  }

  // ─── ตัวช่วย ─────────────────────────────────────────────────

  /// ข้อความ error จากฐานข้อมูล (เช่น ข้อความภาษาไทยจาก trigger)
  static String errorMessage(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// 9 ต.ค. 2569
  static String formatThaiDate(DateTime d) =>
      '${d.day} ${_thaiMonthsShort[d.month - 1]} ${d.year + 543}';

  /// 9 ต.ค. 2569 / 9–10 ต.ค. 2569 / 30 ก.ย. – 2 ต.ค. 2569
  static String formatThaiRange(DateTime start, DateTime end) {
    if (dateKey(start) == dateKey(end)) return formatThaiDate(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}–${formatThaiDate(end)}';
    }
    if (start.year == end.year) {
      return '${start.day} ${_thaiMonthsShort[start.month - 1]} – ${formatThaiDate(end)}';
    }
    return '${formatThaiDate(start)} – ${formatThaiDate(end)}';
  }

  /// ปีงบประมาณ (พ.ศ.) ของวันที่ — เริ่ม 1 ต.ค.
  static int fiscalYearOf(DateTime d) =>
      (d.month >= 10 ? d.year + 1 : d.year) + 543;

  static DateTime fiscalYearStart(int buddhistYear) =>
      DateTime(buddhistYear - 543 - 1, 10, 1);

  static DateTime fiscalYearEnd(int buddhistYear) =>
      DateTime(buddhistYear - 543, 9, 30);

  /// จำนวนวันทำการ — กติกาเดียวกับหน้าส่งใบลา:
  /// วันทำงานพิเศษนับเสมอ, วันหยุดไม่นับ, เสาร์-อาทิตย์ไม่นับ
  static num countWorkingDays(DateTime start, DateTime end,
      {required bool halfDay,
      required Set<String> holidays,
      required Set<String> workingDays}) {
    if (halfDay) return 0.5;
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    var total = 0;
    for (var day = first;
        !day.isAfter(last);
        day = day.add(const Duration(days: 1))) {
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

  static String? _specialDateKey(Map<String, dynamic> data) {
    DateTime? dt;
    final dateValue = data['dateValue'];
    if (dateValue is int) dt = DateTime.fromMillisecondsSinceEpoch(dateValue);
    if (dt == null) {
      final s = (data['date'] ?? data['day'] ?? data['workDate'])?.toString();
      if (s != null) {
        dt = FirebaseService.parseFast(s);
        if (dt != null && dt.year > 2400) {
          dt = DateTime(dt.year - 543, dt.month, dt.day);
        }
      }
    }
    return dt == null ? null : dateKey(dt);
  }
}
