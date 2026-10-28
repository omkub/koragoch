/// ตำแหน่งบริหาร ณ วันที่ใดๆ — อ่านจากประวัติ (supabase/admin_position_history.sql)
///
/// ประวัติแนบมากับข้อมูลบุคลากรแต่ละคนใน `adminPositionHistory`
/// (FirebaseService.getUsersFromSupabase) ทุกหน้าที่ได้รายชื่อบุคลากรไป
/// จึงถามได้ทันทีว่า "วันที่ X คนนี้เป็นอะไร" โดยไม่ต้องโหลดเพิ่ม
///
/// end = วันแรกที่ไม่ได้ดำรงตำแหน่ง (ความหมายเดียวกับ left_date)
/// ตั้ง ผอ. คนใหม่มีผล 26 ต.ค. → วันที่ 25 ยังเป็นคนเดิม วันที่ 26 เป็นคนใหม่
///
/// ยังไม่ได้รัน SQL / คนที่ไม่มีประวัติ = ใช้ตำแหน่งในทะเบียนแบบเดิม
/// (ไม่รู้ว่าเปลี่ยนเมื่อไร จึงถือว่าดำรงตำแหน่งนี้ทุกวัน)
library;

import 'staff_status.dart';

/// ช่วงเวลาที่ดำรงตำแหน่งหนึ่ง
class AdminPositionPeriod {
  final int? id;
  final String role;

  /// วันแรกที่ดำรงตำแหน่ง (null = ก่อนเริ่มบันทึกประวัติ)
  final DateTime? start;

  /// วันแรกที่ไม่ได้ดำรงตำแหน่งแล้ว (null = ยังดำรงอยู่)
  final DateTime? end;

  final String note;

  const AdminPositionPeriod({
    this.id,
    required this.role,
    this.start,
    this.end,
    this.note = '',
  });

  /// ดำรงตำแหน่งนี้อยู่ในวันที่ [day] หรือไม่
  bool covers(DateTime day) {
    final d = _day(day);
    return (start == null || !d.isBefore(start!)) &&
        (end == null || d.isBefore(end!));
  }

  /// ช่วงนี้ทับกับช่วง [from, untilExclusive) หรือไม่
  bool overlaps(DateTime from, DateTime untilExclusive) =>
      (start == null || start!.isBefore(untilExclusive)) &&
      (end == null || end!.isAfter(from));

  static AdminPositionPeriod? fromMap(Map<dynamic, dynamic> m) {
    final role = (m['role'] ?? '').toString().trim();
    if (role.isEmpty) return null;
    return AdminPositionPeriod(
      id: int.tryParse('${m['id'] ?? ''}'),
      role: role,
      start: _parse(m['start']),
      end: _parse(m['end']),
      note: (m['note'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'start': start == null ? null : _iso(start!),
        'end': end == null ? null : _iso(end!),
        'note': note,
      };
}

class AdminPosition {
  const AdminPosition._();

  /// ค่าในทะเบียนที่แปลว่า "ไม่มีตำแหน่ง"
  static const none = 'ไม่มีตำแหน่งบริหาร';

  static bool isNone(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty || v == none || v == '-';
  }

  /// ประวัติของคนนี้ เรียงจากเก่าไปใหม่
  static List<AdminPositionPeriod> historyOf(Map<String, dynamic> user) {
    final raw = user['adminPositionHistory'];
    if (raw is! List) return const [];
    final list = raw
        .whereType<Map>()
        .map(AdminPositionPeriod.fromMap)
        .whereType<AdminPositionPeriod>()
        .toList()
      ..sort((a, b) {
        if (a.start == null) return b.start == null ? 0 : -1;
        if (b.start == null) return 1;
        return a.start!.compareTo(b.start!);
      });
    return list;
  }

  /// ตำแหน่งบริหารของคนนี้ในวันที่ [date] ('' = ไม่มี)
  ///
  /// คนที่พ้นสภาพแล้วไม่มีตำแหน่งตั้งแต่วันที่พ้นสภาพ — ผอ. เกษียณ 1 ต.ค.
  /// ใบลาวันที่ 2 ต.ค. ต้องไม่ขึ้นชื่อ ผอ. คนเดิมเป็นผู้ลงนาม
  static String positionOn(Map<String, dynamic> user, DateTime date) {
    final day = _day(date);
    final left = StaffStatus.leftDateOf(user);
    if (left != null && !day.isBefore(left)) return '';

    final history = historyOf(user);
    if (history.isEmpty) {
      final current = (user['ตำแหน่งงานบริหาร'] ?? '').toString().trim();
      return isNone(current) ? '' : current;
    }
    for (final p in history.reversed) {
      if (p.covers(day)) return p.role;
    }
    return '';
  }

  /// ตำแหน่งที่ดำรงในช่วง [from, untilExclusive) — ใช้กับรายงานรอบ/ปีงบ
  ///
  /// คืนข้อความพร้อมวันที่เมื่อเปลี่ยนกลางช่วง เช่น
  /// "ผู้อำนวยการโรงเรียน (ถึง 25 ต.ค. 2569)"
  static String describeDuring(
    Map<String, dynamic> user,
    DateTime from,
    DateTime untilExclusive, {
    required String Function(DateTime) formatDate,
  }) {
    final history = historyOf(user);
    if (history.isEmpty) {
      // ไม่มีประวัติ: ตอบได้แค่ "ตอนนี้" — ใช้ได้ถ้าช่วงที่ถามคือปัจจุบัน
      return positionOn(user, DateTime.now());
    }
    final left = StaffStatus.leftDateOf(user);
    final parts = <String>[];
    for (final p in history) {
      final end = left != null && (p.end == null || left.isBefore(p.end!))
          ? left
          : p.end;
      final clipped = AdminPositionPeriod(role: p.role, start: p.start, end: end);
      if (end != null && p.start != null && !end.isAfter(p.start!)) continue;
      if (!clipped.overlaps(from, untilExclusive)) continue;

      final startsInside = p.start != null && p.start!.isAfter(from);
      final endsInside = end != null && end.isBefore(untilExclusive);
      final lastDay = end?.subtract(const Duration(days: 1));
      if (startsInside && endsInside) {
        parts.add('${p.role} (${formatDate(p.start!)} – ${formatDate(lastDay!)})');
      } else if (startsInside) {
        parts.add('${p.role} (ตั้งแต่ ${formatDate(p.start!)})');
      } else if (endsInside) {
        parts.add('${p.role} (ถึง ${formatDate(lastDay!)})');
      } else {
        parts.add(p.role);
      }
    }
    return parts.join(' · ');
  }

  /// ผู้ดำรงตำแหน่ง [title] ในวันที่ [date] — ใช้กับช่องเซ็นของใบลา
  ///
  /// เทียบแบบไม่สนช่องว่าง ตรงตัวก่อน แล้วค่อยยอมให้ยาว/สั้นกว่า
  /// (เช่น 'ผู้อำนวยการโรงเรียน' กับ 'ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม')
  static Map<String, dynamic>? holderOn(
    Iterable<Map<String, dynamic>> users,
    String title,
    DateTime date,
  ) {
    String norm(String v) => v.replaceAll(RegExp(r'\s+'), '').trim();
    final target = norm(title);
    if (target.isEmpty) return null;

    Map<String, dynamic>? find(bool Function(String) match) {
      for (final u in users) {
        final role = norm(positionOn(u, date));
        if (role.isNotEmpty && match(role)) return u;
      }
      return null;
    }

    return find((v) => v == target) ??
        find((v) => v.contains(target) || target.contains(v));
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _parse(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString().trim());
  return d == null ? null : _day(d);
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
