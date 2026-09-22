/// การคำนวณข้อมูลทั้งหมดที่ใบลาต้องใช้ แยกออกมาจากการวาดหน้าจอ
///
/// เดิมตรรกะชุดนี้ถูกเขียนซ้ำอยู่ 3 ที่ (ฟอร์มกรอก, ฟอร์มพรีวิว, HTML สำหรับพิมพ์)
/// ทำให้เวลาแก้ต้องไล่แก้ทั้งสามที่ ลืมที่ใดที่หนึ่งแล้วข้อมูลจะไม่ตรงกัน
/// โดยไม่มีอะไรเตือน — รวมมาไว้ที่นี่ที่เดียวเพื่อให้ทุกมุมมองอ่านค่าชุดเดียวกัน
///
/// คลาสนี้ไม่ยุ่งกับ UI เลย จึงเขียนเทสได้ตรง ๆ
library;

import 'package:flutter/foundation.dart';

import '../services/firebase_service.dart';

/// หนึ่งแถวของตาราง "สถิติวันลาในปีงบประมาณนี้"
class LeaveStatRow {
  /// ชื่อประเภทการลาที่แสดงในตาราง
  final String label;

  /// จำนวนครั้ง/วันที่ลามาแล้วก่อนใบนี้
  final String previousTimes;
  final String previousDays;

  /// จำนวนครั้ง/วันของใบลาใบนี้
  final String currentTimes;
  final String currentDays;

  /// ผลรวมทั้งสองส่วน
  final String totalTimes;
  final String totalDays;

  const LeaveStatRow({
    required this.label,
    required this.previousTimes,
    required this.previousDays,
    required this.currentTimes,
    required this.currentDays,
    required this.totalTimes,
    required this.totalDays,
  });
}

/// ข้อมูลใบลาหนึ่งใบที่แปลงพร้อมแสดงผลแล้ว
class LeaveFormData {
  final Map<String, dynamic> leaf;
  final List<Map<String, dynamic>> allUsers;
  final List<Map<String, dynamic>> allLeaveRequests;
  final List<String> leaveTypeNames;

  LeaveFormData({
    required this.leaf,
    required this.allUsers,
    required this.allLeaveRequests,
    this.leaveTypeNames = const [],
  });

  // ── ค่าที่อ่านตรงจากใบลา ────────────────────────────────────────

  String get fullName => (leaf['fullName'] ?? '').toString();

  String get leaveTypeRaw => (leaf['leaveType'] ?? '').toString();

  String get reason => (leaf['reason'] ?? '').toString();

  String get phone => (leaf['phone'] ?? '').toString();

  String? get receiveNumber => leaf['receiveNumber']?.toString();

  String? get receiveDate => leaf['receiveDate']?.toString();

  String? get receiveTime => leaf['receiveTime']?.toString();

  /// หัวข้อ "เรื่อง" — เว้นว่างถ้ายังไม่ได้เลือกประเภทการลา
  String get subject => leaveTypeRaw == '---เลือก---' ? '' : 'ขอ$leaveTypeRaw';

  num get totalDays => double.tryParse(leaf['totalDays']?.toString() ?? '1') ?? 1;

  String get totalDaysText => FirebaseService.formatLeaveDayCount(totalDays);

  String get startDateText => FirebaseService.formatThaiDate(leaf['startDate']);

  String get endDateText => FirebaseService.formatThaiDate(leaf['endDate']);

  // ── วันที่เขียนใบลา ─────────────────────────────────────────────

  String get requestDay => _dayOf(leaf['timestamp']);
  String get requestMonth => _monthOf(leaf['timestamp']);
  String get requestYear => _yearOf(leaf['timestamp']);

  // ── ตำแหน่งและวิทยฐานะ ─────────────────────────────────────────

  static bool _isBlankChoice(String value) {
    final v = value.trim();
    return v.isEmpty || v == '-' || v.contains('เลือก');
  }

  static bool _hasNoAcademicStanding(String value) =>
      value.trim() == 'ไม่มีวิทยฐานะ';

  Map<String, dynamic> _userForLeaf() {
    final name = fullName.trim();
    if (name.isEmpty) return const {};
    return allUsers.firstWhere(
      (u) => (u['fullName'] ?? u['name'] ?? '').toString().trim() == name,
      orElse: () => const {},
    );
  }

  /// ตำแหน่งของผู้ลา — ถ้าในใบลาไม่มีให้ไปหยิบจากทะเบียนบุคลากร
  String get position {
    final direct = (leaf['position'] ?? '').toString();
    if (!_isBlankChoice(direct)) return direct;
    final user = _userForLeaf();
    final fromUser = (user['position'] ?? user['ตำแหน่ง'] ?? '').toString();
    return _isBlankChoice(fromUser) ? '' : fromUser;
  }

  /// วิทยฐานะ — "ไม่มีวิทยฐานะ" ถือว่าไม่ต้องแสดงอะไรเลย
  String get academicStanding {
    final direct = (leaf['academicStanding'] ?? '').toString().trim();
    if (_hasNoAcademicStanding(direct)) return '';
    if (!_isBlankChoice(direct)) return direct;
    final user = _userForLeaf();
    final fromUser =
        (user['academicStanding'] ?? user['rank'] ?? user['วิทยฐานะ'] ?? '')
            .toString()
            .trim();
    return _isBlankChoice(fromUser) || _hasNoAcademicStanding(fromUser)
        ? ''
        : fromUser;
  }

  /// ตำแหน่ง + วิทยฐานะ ต่อกันด้วยช่องว่าง ใช้ในบรรทัด "ข้าพเจ้า ... ตำแหน่ง ..."
  String get positionWithStanding {
    final pos = position;
    final rank = academicStanding;
    if (rank.isEmpty) return pos;
    return pos.isEmpty ? rank : '$pos $rank';
  }

  // ── ประเภทการลาที่แสดงเป็นช่องติ๊ก ──────────────────────────────

  /// ดึงจากตาราง LeaveTypes ถ้าไม่มีให้ใช้สามประเภทมาตรฐาน
  List<String> get printableLeaveTypes {
    final names = leaveTypeNames
        .where((t) => t.trim().isNotEmpty && !t.contains('เลือก'))
        .toList();
    if (names.isEmpty) {
      return const ['ลาป่วย', 'ลากิจส่วนตัว', 'ลาคลอดบุตร'];
    }
    return names;
  }

  /// เทียบประเภทการลาแบบตรงตัว เพราะชื่อที่แสดงและชื่อที่เทียบมาจาก
  /// ตาราง LeaveTypes ชุดเดียวกัน จึงตรงกันเสมอ
  bool isSelectedLeaveType(String candidate) {
    final a = leaveTypeRaw.trim();
    final b = candidate.trim();
    if (a.isEmpty || b.isEmpty) return false;
    return a == b;
  }

  // ── การลาครั้งล่าสุดก่อนหน้าใบนี้ ───────────────────────────────

  Map<String, dynamic>? get latestLeave {
    final name = fullName.trim();
    final fiscalYear = (leaf['year'] ?? '').toString().trim();
    if (name.isEmpty || fiscalYear.isEmpty) return null;

    final candidates = allLeaveRequests.where((leave) {
      return (leave['fullName'] ?? '').toString().trim() == name &&
          (leave['year'] ?? '').toString().trim() == fiscalYear &&
          _isBeforeCurrent(leave);
    }).toList()
      ..sort(FirebaseService.compareLeaveRecency);

    return candidates.isEmpty ? null : candidates.first;
  }

  /// ชื่อประเภทการลาครั้งล่าสุด ใช้ติ๊กช่อง "ข้าพเจ้าได้ลา ..."
  String? get latestLeaveLabel {
    final leave = latestLeave;
    if (leave == null) return null;
    final leaveType = (leave['leaveType'] ?? '').toString();
    if (leaveType.contains('ป่วย')) return 'ป่วย';
    if (leaveType.contains('กิจ')) return 'ลากิจส่วนตัว';
    if (leaveType.contains('คลอด')) return 'ลาคลอดบุตร';
    return null;
  }

  String get latestStartText {
    final leave = latestLeave;
    return leave == null
        ? ''
        : FirebaseService.formatThaiDate(leave['startDate']);
  }

  String get latestEndText {
    final leave = latestLeave;
    return leave == null
        ? ''
        : FirebaseService.formatThaiDate(leave['endDate']);
  }

  String get latestDaysText {
    final leave = latestLeave;
    return leave == null
        ? ''
        : FirebaseService.formatLeaveDayCount(leave['totalDays']);
  }

  // ── ชื่อผู้บริหารสำหรับช่องเซ็น ─────────────────────────────────

  static const String blankSignature = '(................................)';

  /// หาชื่อผู้บริหารจากตำแหน่งงานบริหารในทะเบียนบุคลากร
  ///
  /// เทียบแบบไม่สนช่องว่าง และยอมให้ชื่อในฐานยาวกว่า/สั้นกว่าได้
  /// เช่น 'ผู้อำนวยการโรงเรียน' กับ 'ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม'
  String managerName(String adminTitle) {
    if (allUsers.isEmpty) return blankSignature;

    String norm(String v) => v.replaceAll(RegExp(r'\s+'), '').trim();
    final target = norm(adminTitle);

    Map<String, dynamic> find(bool Function(String) match) {
      return allUsers.firstWhere(
        (u) {
          final value = u['ตำแหน่งงานบริหาร']?.toString() ?? '';
          if (value.isEmpty) return false;
          return match(norm(value));
        },
        orElse: () => <String, dynamic>{},
      );
    }

    var manager = find((v) => v == target);
    if (manager.isEmpty) {
      manager = find((v) => v.contains(target) || target.contains(v));
    }

    final name = manager['fullName']?.toString().trim() ?? '';
    return name.isNotEmpty ? '($name)' : blankSignature;
  }

  String get hrName => managerName('หัวหน้ากลุ่มบริหารงานบุคคล');
  String get deputyName => managerName('รองผู้อำนวยการกลุ่มบริหารงานบุคคล');
  String get directorName => managerName('ผู้อำนวยการโรงเรียน');

  // ── ตารางสถิติวันลา ────────────────────────────────────────────

  /// สามแถวมาตรฐานของตารางสถิติ
  List<LeaveStatRow> get statRows => [
        _statRow('ป่วย', 'ป่วย'),
        _statRow('ลากิจส่วนตัว', 'กิจ'),
        _statRow('ลาคลอดบุตร', 'คลอด'),
      ];

  LeaveStatRow _statRow(String label, String keyword) {
    final currentYear = (leaf['year'] ?? '').toString();
    final history = allLeaveRequests.where((req) {
      final reqName = (req['fullName'] ?? '').toString();
      final reqType = (req['leaveType'] ?? '').toString();
      final reqYear = (req['year'] ?? '').toString();
      return reqName == fullName &&
          reqType.contains(keyword) &&
          reqYear == currentYear &&
          _isBeforeCurrent(req);
    }).toList();

    final prevTimes = history.length;
    final prevDays = history.fold<double>(
      0,
      (sum, req) =>
          sum + (double.tryParse(req['totalDays']?.toString() ?? '0') ?? 0),
    );

    final currentMatch = leaveTypeRaw.contains(keyword);
    final totalTimes = prevTimes + (currentMatch ? 1 : 0);
    final totalDaysCalc = prevDays + (currentMatch ? totalDays : 0);

    return LeaveStatRow(
      label: label,
      previousTimes: prevTimes > 0 ? prevTimes.toString() : '-',
      previousDays: prevTimes > 0
          ? FirebaseService.formatLeaveDayCount(prevDays)
          : '-',
      currentTimes: currentMatch ? '1' : '-',
      currentDays: currentMatch ? totalDaysText : '-',
      totalTimes: totalTimes > 0 ? totalTimes.toString() : '-',
      totalDays: totalTimes > 0
          ? FirebaseService.formatLeaveDayCount(totalDaysCalc)
          : '-',
    );
  }

  // ── ตัวช่วยเรื่องวันที่ ─────────────────────────────────────────

  /// ใบลาใบนี้เกิดก่อนใบที่กำลังแสดงอยู่หรือไม่
  ///
  /// เทียบวันลาก่อน ถ้าวันเดียวกันค่อยเทียบเวลาที่ยื่น และถ้ายังเท่ากันอีก
  /// ค่อยเทียบรหัสใบลาเพื่อให้ผลลัพธ์คงที่ไม่สลับไปมา
  bool _isBeforeCurrent(Map<String, dynamic> leave) {
    if (leave['requestId'] == leaf['requestId']) return false;

    final leaveDate = _sequenceDate(leave);
    final currentDate = _sequenceDate(leaf);
    if (leaveDate == null || currentDate == null) return false;

    final leaveDay = DateTime(leaveDate.year, leaveDate.month, leaveDate.day);
    final currentDay =
        DateTime(currentDate.year, currentDate.month, currentDate.day);
    if (leaveDay.isBefore(currentDay)) return true;
    if (leaveDay.isAfter(currentDay)) return false;

    final leaveTimestamp = parseDate(leave['timestamp']);
    final currentTimestamp = parseDate(leaf['timestamp']);
    if (leaveTimestamp != null && currentTimestamp != null) {
      return leaveTimestamp.isBefore(currentTimestamp);
    }

    return (leave['requestId'] ?? '')
            .toString()
            .compareTo((leaf['requestId'] ?? '').toString()) <
        0;
  }

  static DateTime? _sequenceDate(Map<String, dynamic> leave) {
    return parseDate(leave['startDateValue']) ??
        parseDate(leave['startDate']) ??
        parseDate(leave['timestamp']);
  }

  /// แปลงค่าวันที่ได้ทุกรูปแบบที่ระบบเคยเก็บไว้ (DateTime, ISO, วว/ดด/ปปปป พ.ศ.)
  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final isoParsed = DateTime.tryParse(value.trim());
      if (isoParsed != null) return isoParsed;
      final parsed = FirebaseService.parseFast(value);
      if (parsed != null) {
        return parsed.year > 2400
            ? DateTime(parsed.year - 543, parsed.month, parsed.day)
            : parsed;
      }
      if (value.contains('/')) {
        try {
          final parts = value.split('/');
          return DateTime(int.parse(parts[2]) - 543, int.parse(parts[1]),
              int.parse(parts[0]));
        } catch (e) {
          debugPrint('แปลงวันที่ "$value" ไม่สำเร็จ: $e');
        }
      }
    }
    return null;
  }

  static const String _blankDate = '....................';

  static const List<String> thaiMonths = [
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
    'ธันวาคม',
  ];

  static String _dayOf(dynamic value) {
    final dt = parseDate(value);
    return dt == null ? _blankDate : dt.day.toString();
  }

  static String _monthOf(dynamic value) {
    final dt = parseDate(value);
    return dt == null ? _blankDate : thaiMonths[dt.month - 1];
  }

  static String _yearOf(dynamic value) {
    final dt = parseDate(value);
    return dt == null ? _blankDate : (dt.year + 543).toString();
  }
}
