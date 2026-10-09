/// ข้อมูลที่หน้าหลักบนมือถือแสดง — โหลดครั้งเดียว ดึงลงเพื่อโหลดใหม่
///
/// - ทุกคน: วันลาของฉันในปีงบปัจจุบัน + ใบลาล่าสุด
/// - ดูภาพรวมได้ (ผู้บริหาร / ผู้ดูแลระบบ): วันนี้ในโรงเรียน (ลา / ไปราชการ)
/// - ผู้ดูแลระบบ: งานรอพิจารณา (ใบลา / ไปราชการ) + คำขอรีเซ็ตรหัส
///   (ผู้บริหารไม่มีสิทธิ์อนุมัติ จึงไม่เห็นส่วนนี้)
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/firebase_service.dart';
import '../../services/official_trip_service.dart';
import '../../widgets/leave_form_data.dart';
import 'menu_access.dart';

class MobileHomeData {
  final String fullName;
  final String subtitle;

  /// ปีงบที่ใช้นับ (เช่น "2570") — null = หารอบงบประมาณไม่เจอ
  final String? fiscalYear;

  /// จำนวนวันลาของฉันตามประเภท (ป่วย / กิจ / คลอด)
  final ({num sick, num personal, num maternity}) myDays;
  final Map<String, dynamic>? latestLeave;

  /// null = ไม่มีสิทธิ์ดู
  final ({int onLeave, int onTrip})? today;
  final ({int leaves, int trips})? pending;
  final int? resetRequests;

  const MobileHomeData({
    required this.fullName,
    required this.subtitle,
    required this.fiscalYear,
    required this.myDays,
    required this.latestLeave,
    this.today,
    this.pending,
    this.resetRequests,
  });

  /// บัญชีผู้ดูแลระบบกลาง (ไม่ใช่ครู) ไม่มีวันลาของตัวเอง
  bool get hasOwnLeaves => fullName != 'ผู้ดูแลระบบ';

  static bool _isRejected(String status) => status.contains('ไม่');
  static bool _isPending(String status) =>
      status.contains('รอ') || status.contains('พิจารณา');

  static Future<MobileHomeData> load(MenuAccess access) async {
    final prefs = await SharedPreferences.getInstance();
    var fullName = access.currentUser;
    var subtitle = access.userRole;
    try {
      final cached = prefs.getString('userFullDataJson');
      if (cached != null && cached.isNotEmpty) {
        final u = jsonDecode(cached) as Map<String, dynamic>;
        final name = (u['fullName'] ?? u['name'] ?? '').toString().trim();
        if (name.isNotEmpty) fullName = name;
        final pos = (u['position'] ?? '').toString().trim();
        final rank = (u['academicStanding'] ?? '').toString().trim();
        final parts = [
          if (pos.isNotEmpty && !pos.contains('เลือก')) pos,
          if (rank.isNotEmpty &&
              rank != 'ไม่มีวิทยฐานะ' &&
              !rank.contains('เลือก'))
            rank,
        ];
        if (parts.isNotEmpty) subtitle = parts.join(' ');
      }
    } catch (e) {
      debugPrint('⚠️  อ่านข้อมูลผู้ใช้ไม่สำเร็จ: $e');
    }

    final service = FirebaseService();
    final overview = access.seesSchoolOverview;
    final now = DateTime.now();
    final todayStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year + 543}';
    final today = DateTime(now.year, now.month, now.day);

    final results = await Future.wait<Object?>([
      service.getFiscalRoundsFromSupabase(),
      overview
          ? service.getLeaveRequestsFromSupabase()
          : service.getMyLeaveRequestsFromSupabase(fullName),
      overview
          ? OfficialTripService()
              .getTrips(from: today, to: today)
              .catchError((_) => <Map<String, dynamic>>[])
          : Future.value(null),
      access.isAdmin
          ? OfficialTripService()
              .getTrips(
                  from: OfficialTripService.fiscalYearStart(
                      OfficialTripService.fiscalYearOf(now)),
                  to: OfficialTripService.fiscalYearEnd(
                      OfficialTripService.fiscalYearOf(now)))
              .catchError((_) => <Map<String, dynamic>>[])
          : Future.value(null),
      access.isAdmin
          ? service.getPendingResetCountFromSupabase().catchError((_) => 0)
          : Future.value(null),
    ]);

    final rounds = (results[0] as List).cast<Map<String, dynamic>>();
    final leaves = (results[1] as List).cast<Map<String, dynamic>>();
    final tripsToday = results[2] as List<Map<String, dynamic>>?;
    final tripsYear = results[3] as List<Map<String, dynamic>>?;
    final resets = results[4] as int?;

    // รอบงบประมาณที่วันนี้อยู่ในช่วง (แบบเดียวกับแดชบอร์ด)
    Map<String, dynamic>? round;
    for (final r in rounds) {
      if (FirebaseService.isDateInRange(todayStr,
          (r['startDate'] ?? '').toString(), (r['endDate'] ?? '').toString())) {
        round = r;
        break;
      }
    }
    round ??= rounds.isNotEmpty ? rounds.first : null;
    final fiscalYear = round?['year']?.toString();

    // ใบใหม่สุดก่อน (ตามวันที่ยื่น)
    final mine = leaves
        .where((l) => (l['fullName'] ?? '').toString().trim() == fullName)
        .toList()
      ..sort((a, b) {
        final ta = LeaveFormData.parseDate(a['timestamp']);
        final tb = LeaveFormData.parseDate(b['timestamp']);
        if (ta == null || tb == null) return ta == null ? 1 : -1;
        return tb.compareTo(ta);
      });
    num days(String keyword) => mine
        .where((l) =>
            l['year']?.toString() == fiscalYear &&
            (l['leaveType'] ?? '').toString().contains(keyword) &&
            !_isRejected((l['status'] ?? '').toString()))
        .fold<num>(
            0, (sum, l) => sum + (num.tryParse('${l['totalDays']}') ?? 0));

    int onLeave = 0;
    if (overview) {
      onLeave = leaves
          .where((l) {
            final status = (l['status'] ?? '').toString();
            return !_isRejected(status) &&
                FirebaseService.isDateInRange(
                    todayStr,
                    (l['startDate'] ?? '').toString(),
                    (l['endDate'] ?? '').toString());
          })
          .map((l) => (l['fullName'] ?? '').toString())
          .toSet()
          .length;
    }
    final onTrip = {
      for (final t in tripsToday ?? const <Map<String, dynamic>>[])
        if (t['status'] != OfficialTripService.rejected)
          ...(t['members'] as List? ?? const [])
    }.length;

    return MobileHomeData(
      fullName: fullName,
      subtitle: subtitle,
      fiscalYear: fiscalYear,
      myDays: (
        sick: days('ป่วย'),
        personal: days('กิจ'),
        maternity: days('คลอด')
      ),
      latestLeave: mine.isEmpty ? null : mine.first,
      today: overview ? (onLeave: onLeave, onTrip: onTrip) : null,
      pending: access.isAdmin
          ? (
              leaves: leaves
                  .where((l) => _isPending((l['status'] ?? '').toString()))
                  .length,
              trips: (tripsYear ?? const [])
                  .where((t) => t['status'] == OfficialTripService.pending)
                  .length,
            )
          : null,
      resetRequests: resets,
    );
  }
}
