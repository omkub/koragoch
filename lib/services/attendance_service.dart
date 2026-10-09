import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/school_info.dart';
import 'firebase_service.dart';

// ═══════════════════════════════════════════════════════════════
// ลงเวลา (สแกนหน้า) — อ่านสถานะรายวัน / แก้เวลา / ความยินยอม
// (ดู supabase/attendance.sql + attendance_daily.sql)
//
// การตัดสินสถานะ มา/สาย/ลา/ไปราชการ/ขาด ทำในฐานข้อมูลที่เดียว
// (attendance_day_status) — แอปแค่แสดงผล เพื่อให้ตรงกับรายงานและสรุป LINE
//
// สิทธิ์จริงอยู่ในฐานข้อมูล ฝั่งแอปซ่อนปุ่มให้ตรงกันเท่านั้น:
//   attendance.view_all  เห็นภาพรวมทั้งโรงเรียน
//   attendance.edit      เพิ่ม / ยกเลิกเวลาแทน (แอดมินโรงเรียน)
// ═══════════════════════════════════════════════════════════════

/// สถานะของคน 1 คนใน 1 วัน
class DayStatus {
  final int idUser;
  final String fullName;
  final DateTime day;
  final String status;
  final DateTime? firstScan; // เวลาไทย
  final DateTime? lastScan; // เวลาไทย
  final int scanCount;
  final int lateMinutes;
  final String note;

  const DayStatus({
    required this.idUser,
    required this.fullName,
    required this.day,
    required this.status,
    this.firstScan,
    this.lastScan,
    this.scanCount = 0,
    this.lateMinutes = 0,
    this.note = '',
  });

  factory DayStatus.fromRow(Map<String, dynamic> r) => DayStatus(
        idUser: (r['id_user'] as num).toInt(),
        fullName: (r['full_name'] ?? '').toString(),
        day: DateTime.parse(r['day'].toString()),
        status: (r['status'] ?? '').toString(),
        firstScan: AttendanceService.toThaiTime(r['first_scan']),
        lastScan: AttendanceService.toThaiTime(r['last_scan']),
        scanCount: (r['scan_count'] as num?)?.toInt() ?? 0,
        lateMinutes: (r['late_minutes'] as num?)?.toInt() ?? 0,
        note: (r['note'] ?? '').toString(),
      );
}

/// สรุปต่อคนในช่วงวันที่ (รายงานรายเดือน)
class AttendanceSummaryRow {
  final int idUser;
  final String fullName;
  final int workDays;
  final int present;
  final int late;
  final int lateMinutes;
  final int onLeave;
  final int onTrip;
  final int absent;
  final int missingOut;

  const AttendanceSummaryRow({
    required this.idUser,
    required this.fullName,
    required this.workDays,
    required this.present,
    required this.late,
    required this.lateMinutes,
    required this.onLeave,
    required this.onTrip,
    required this.absent,
    required this.missingOut,
  });

  factory AttendanceSummaryRow.fromRow(Map<String, dynamic> r) {
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    return AttendanceSummaryRow(
      idUser: n('id_user'),
      fullName: (r['full_name'] ?? '').toString(),
      workDays: n('work_days'),
      present: n('present'),
      late: n('late'),
      lateMinutes: n('late_minutes'),
      onLeave: n('on_leave'),
      onTrip: n('on_trip'),
      absent: n('absent'),
      missingOut: n('missing_out'),
    );
  }
}

/// การสแกน 1 ครั้ง (หน้ารายละเอียด / แก้เวลา)
class ScanLog {
  final int idLog;
  final DateTime scannedAt; // เวลาไทย
  final String source; // device / import / manual
  final String note;
  final String deviceName;
  final bool voided;
  final String voidReason;

  const ScanLog({
    required this.idLog,
    required this.scannedAt,
    required this.source,
    this.note = '',
    this.deviceName = '',
    this.voided = false,
    this.voidReason = '',
  });

  String get sourceLabel => switch (source) {
        'device' => deviceName.isEmpty ? 'เครื่องสแกน' : deviceName,
        'import' => 'นำเข้าไฟล์',
        'manual' => 'เพิ่มโดยผู้ดูแล',
        _ => source,
      };
}

class AttendanceSettingsInfo {
  final bool enabled;
  final String workStart;
  final String lateAfter;
  final String workEnd;
  final bool requireCheckout;

  const AttendanceSettingsInfo({
    this.enabled = false,
    this.workStart = '08:00',
    this.lateAfter = '08:30',
    this.workEnd = '16:30',
    this.requireCheckout = false,
  });

  static String _hm(dynamic v, String fallback) {
    final s = (v ?? '').toString();
    return s.length >= 5 ? s.substring(0, 5) : fallback;
  }

  factory AttendanceSettingsInfo.fromRow(Map<String, dynamic>? r) => r == null
      ? const AttendanceSettingsInfo()
      : AttendanceSettingsInfo(
          enabled: r['enabled'] == true,
          workStart: _hm(r['work_start'], '08:00'),
          lateAfter: _hm(r['late_after'], '08:30'),
          workEnd: _hm(r['work_end'], '16:30'),
          requireCheckout: r['require_checkout'] == true,
        );
}

class AttendanceService {
  static const statusOrder = [
    'มา',
    'สาย',
    'ลา',
    'ไปราชการ',
    'ขาด',
    'ยังไม่สแกน',
    'วันหยุด',
    'ยังไม่ถึง',
    'ยังไม่เริ่มใช้',
  ];

  static const _thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม'
  ];
  static const _thaiMonthsShort = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.'
  ];
  static const _thaiWeekdays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];

  final _firebaseService = FirebaseService();

  SupabaseClient get _client {
    final client = _firebaseService.supabaseClient;
    if (client == null) throw StateError('ยังเชื่อมต่อฐานข้อมูลไม่ได้');
    return client;
  }

  int get _schoolId {
    final id = SchoolInfo.currentSchoolId;
    if (id == null) throw StateError('ไม่ทราบโรงเรียนของผู้ใช้');
    return id;
  }

  // ─── เวลา ─────────────────────────────────────────────────────

  /// เวลาจากฐานข้อมูล (UTC) → เวลาไทย (ไม่ขึ้นกับโซนเวลาของเครื่อง)
  static DateTime? toThaiTime(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    final utc = parsed.toUtc().add(const Duration(hours: 7));
    return DateTime(
        utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);
  }

  /// วันนี้ตามเวลาไทย
  static DateTime thaiToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(now.year, now.month, now.day);
  }

  /// เวลาไทย → ISO พร้อมโซน +07:00 สำหรับส่งเข้าฐานข้อมูล
  static String thaiIso(DateTime local) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${p(local.month)}-${p(local.day)}'
        'T${p(local.hour)}:${p(local.minute)}:${p(local.second)}+07:00';
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String hm(DateTime? t) => t == null
      ? '-'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 9 ต.ค. 2569
  static String thaiShortDate(DateTime d) =>
      '${d.day} ${_thaiMonthsShort[d.month - 1]} ${d.year + 543}';

  /// พฤ. 9 ต.ค.
  static String thaiDayLabel(DateTime d) =>
      '${_thaiWeekdays[d.weekday - 1]} ${d.day} ${_thaiMonthsShort[d.month - 1]}';

  /// ตุลาคม 2569
  static String thaiMonthYear(DateTime d) =>
      '${_thaiMonths[d.month - 1]} ${d.year + 543}';

  /// 75 → "1 ชม. 15 นาที"
  static String minutesLabel(int minutes) {
    if (minutes < 60) return '$minutes นาที';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h ชม.' : '$h ชม. $m นาที';
  }

  // ─── อ่าน ────────────────────────────────────────────────────

  /// โรงเรียนของผู้ใช้เปิดระบบลงเวลาแล้วหรือยัง (ใช้ซ่อน/แสดงเมนู)
  /// อ่านไม่ได้ (ยังไม่รัน SQL / ออฟไลน์) = ถือว่ายังไม่เปิด
  Future<bool> isEnabled() async {
    try {
      return (await getSettings()).enabled;
    } catch (_) {
      return false;
    }
  }

  Future<AttendanceSettingsInfo> getSettings() async {
    final row = await _client
        .from('AttendanceSettings')
        .select()
        .eq('id_school', _schoolId)
        .maybeSingle();
    return AttendanceSettingsInfo.fromRow(row);
  }

  /// สิทธิ์ของคนที่ล็อกอิน (เฉพาะที่เกี่ยวกับลงเวลา)
  Future<({bool viewAll, bool edit})> getPermissions() async {
    try {
      final rows = await _client.rpc('my_permissions') as List;
      final keys = rows.map((e) => e.toString()).toSet();
      return (
        viewAll: keys.contains('attendance.view_all'),
        edit: keys.contains('attendance.edit'),
      );
    } catch (_) {
      return (viewAll: false, edit: false);
    }
  }

  /// สถานะรายวัน — ไม่มีสิทธิ์ดูทั้งโรงเรียน ฐานข้อมูลคืนเฉพาะของตัวเอง
  Future<List<DayStatus>> getDayStatus(DateTime from, DateTime to,
      {int? userId}) async {
    final rows = await _client.rpc('attendance_day_status', params: {
      'p_school': _schoolId,
      'p_from': dateKey(from),
      'p_to': dateKey(to),
      'p_user': userId,
    }) as List;
    return rows
        .map((r) => DayStatus.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<AttendanceSummaryRow>> getSummary(
      DateTime from, DateTime to) async {
    final rows = await _client.rpc('attendance_summary', params: {
      'p_school': _schoolId,
      'p_from': dateKey(from),
      'p_to': dateKey(to),
    }) as List;
    return rows
        .map((r) =>
            AttendanceSummaryRow.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// การสแกนทั้งหมดของคนหนึ่งในวันหนึ่ง (รวมที่ถูกยกเลิก)
  Future<List<ScanLog>> getScans(int userId, DateTime day) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    final rows = await _client
        .from('AttendanceLogs')
        .select(
            'id_log, scanned_at, source, note, voided_at, void_reason, AttendanceDevices(name)')
        .eq('id_user', userId)
        .gte('scanned_at', thaiIso(from))
        .lt('scanned_at', thaiIso(to))
        .order('scanned_at');
    return (rows as List).map((r) {
      final row = Map<String, dynamic>.from(r as Map);
      final device = row['AttendanceDevices'];
      return ScanLog(
        idLog: (row['id_log'] as num).toInt(),
        scannedAt: toThaiTime(row['scanned_at'])!,
        source: (row['source'] ?? '').toString(),
        note: (row['note'] ?? '').toString(),
        deviceName: device is Map ? (device['name'] ?? '').toString() : '',
        voided: row['voided_at'] != null,
        voidReason: (row['void_reason'] ?? '').toString(),
      );
    }).toList();
  }

  Future<DateTime?> getMyConsent(int myId) async {
    final row = await _client
        .from('Teachers')
        .select('face_consent_at')
        .eq('id_user', myId)
        .maybeSingle();
    return toThaiTime(row?['face_consent_at']);
  }

  // ─── เขียน ───────────────────────────────────────────────────

  /// เพิ่มเวลาแทน (เครื่องเสีย / ลืมสแกน) — ต้องมีเหตุผล
  Future<void> addManualScan(int userId, DateTime localTime, String reason) {
    return _client.from('AttendanceLogs').insert({
      'id_user': userId,
      'scanned_at': thaiIso(localTime),
      'source': 'manual',
      'note': reason.trim(),
    });
  }

  /// ยกเลิกการสแกนที่ผิด — แถวยังอยู่พร้อมเหตุผล
  Future<void> voidScan(int idLog, String reason) =>
      _client.rpc('void_attendance_log',
          params: {'p_id': idLog, 'p_reason': reason.trim()});

  /// แก้เวลา = ยกเลิกของเดิม + เพิ่มเวลาใหม่ ด้วยเหตุผลเดียวกัน
  Future<void> correctScan(
      ScanLog old, int userId, DateTime newTime, String reason) async {
    await addManualScan(userId, newTime, reason);
    await voidScan(old.idLog, 'แก้เป็น ${hm(newTime)} น. — ${reason.trim()}');
  }

  Future<DateTime?> setConsent(bool consent) async {
    final result =
        await _client.rpc('set_face_consent', params: {'p_consent': consent});
    return toThaiTime(result);
  }

  // ─── รายงาน ──────────────────────────────────────────────────

  /// CSV (UTF-8 มี BOM ให้ Excel อ่านภาษาไทยถูก)
  static Uint8List summaryCsv(List<AttendanceSummaryRow> rows,
      {required String title}) {
    final data = <List<dynamic>>[
      [title],
      [
        'ลำดับ',
        'ชื่อ-สกุล',
        'วันทำการ',
        'มา',
        'สาย (ครั้ง)',
        'สายรวม (นาที)',
        'ลา',
        'ไปราชการ',
        'ขาด',
        'ไม่สแกนออก/ออกก่อน',
      ],
      for (var i = 0; i < rows.length; i++)
        [
          i + 1,
          rows[i].fullName,
          rows[i].workDays,
          rows[i].present,
          rows[i].late,
          rows[i].lateMinutes,
          rows[i].onLeave,
          rows[i].onTrip,
          rows[i].absent,
          rows[i].missingOut,
        ],
    ];
    final text = csv.encode(data);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
  }

  /// CSV รายวันของทั้งโรงเรียน (1 แถว = 1 คน 1 วัน)
  static Uint8List dailyCsv(List<DayStatus> rows, {required String title}) {
    final data = <List<dynamic>>[
      [title],
      ['วันที่', 'ชื่อ-สกุล', 'สถานะ', 'เข้า', 'ออก', 'สาย (นาที)', 'หมายเหตุ'],
      for (final r in rows)
        [
          thaiShortDate(r.day),
          r.fullName,
          r.status,
          r.firstScan == null ? '' : hm(r.firstScan),
          r.scanCount > 1 ? hm(r.lastScan) : '',
          r.lateMinutes == 0 ? '' : r.lateMinutes,
          r.note,
        ],
    ];
    final text = csv.encode(data);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
  }

  static String errorMessage(Object e) {
    if (e is PostgrestException) return e.message;
    return e
        .toString()
        .replaceFirst(RegExp(r'^(Exception|StateError|Bad state): '), '');
  }
}
