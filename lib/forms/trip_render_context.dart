/// รายการไปราชการ → ตัวแทนข้อมูล / ช่องติ๊ก / ผู้ร่วมเดินทาง สำหรับวาดใบขออนุญาตไปราชการ
///
/// แปลมาจาก tripContext() ใน central/src/forms/tripTemplate.ts
/// ชื่อตัวแทนข้อมูลต้องตรงกับที่หน้าแบบฟอร์มใน web ให้เลือก (TRIP_PLACEHOLDERS)
/// test/form_render_parity_test.dart เทียบผลกับ web ให้แล้ว
///
/// [trip] = แถวของ OfficialTrips แบบที่ OfficialTripService.getTrips คืนมา
/// (วันที่เป็น 'YYYY-MM-DD', members = รายการ id_user)
library;

import '../utils/school_info.dart';
import '../widgets/leave_form_data.dart';
import 'form_render.dart';

const _blank = '..............................';

const _thaiMonths = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', //
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

/// String(v) ของ JavaScript (null = '')
String _text(Object? v) => v == null ? '' : (v is num ? jsNum(v) : '$v');

/// Number(v) ของ JavaScript — แปลงไม่ได้ = NaN
double _number(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  final s = '$v'.trim();
  return s.isEmpty ? 0 : (double.tryParse(s) ?? double.nan);
}

/// 2026-10-09 → "9 ตุลาคม 2569" (เวลาเต็มใช้วันตามเวลาเครื่อง ไม่ใช่วัน UTC)
String _thaiDate(Object? value) {
  final raw = _text(value);
  String fmt(DateTime d) => '${d.day} ${_thaiMonths[d.month - 1]} ${d.year + 543}';
  if (raw.contains('T')) {
    final d = DateTime.tryParse(raw);
    if (d != null) return fmt(d.isUtc ? d.toLocal() : d);
  }
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (m == null) return '';
  return '${int.parse(m[3]!)} ${_thaiMonths[int.parse(m[2]!) - 1]} ${int.parse(m[1]!) + 543}';
}

/// toLocaleString('th-TH') — คั่นหลักพัน ทศนิยมไม่เกิน 3 ตำแหน่ง
String _thaiNumber(double n) {
  final fixed = n.abs().toStringAsFixed(3);
  var (whole, frac) = (fixed.split('.')[0], fixed.split('.')[1]);
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${n < 0 ? '-' : ''}$grouped${frac.isEmpty ? '' : '.$frac'}';
}

/// ตำแหน่ง + วิทยฐานะ (ข้ามค่าว่าง / "ไม่มีวิทยฐานะ" / "--เลือก--")
String _positionWithStanding(Map<String, dynamic>? u) {
  if (u == null) return '';
  final pos = _text(u['position']).trim();
  final rank = _text(u['academicStanding']).trim();
  final r = rank.isNotEmpty &&
          rank != 'ไม่มีวิทยฐานะ' &&
          !rank.contains('เลือก') &&
          rank != '-'
      ? rank
      : '';
  final p = pos.isNotEmpty && pos != '-' && !pos.contains('เลือก') ? pos : '';
  return [p, r].where((s) => s.isNotEmpty).join(' ');
}

/// [users] = รายชื่อบุคลากร (ใช้หาชื่อ/ตำแหน่ง และชื่อผู้อำนวยการ)
/// [school] ไม่ส่ง = โรงเรียนที่ระบบกำลังใช้งานอยู่
RenderContext tripRenderContext(
  Map<String, dynamic> trip,
  List<Map<String, dynamic>> users, {
  SchoolRecord? school,
}) {
  final byId = {for (final u in users) _text(u['id_user']): u};
  final ownerId = _text(trip['id_user']);
  final owner = byId[ownerId];
  final memberIds = trip['members'] is List ? trip['members'] as List : const [];
  final ordered = [
    ownerId,
    ...memberIds.map(_text).where((id) => id != ownerId),
  ].where((id) => id.isNotEmpty);
  final members = [
    for (final id in ordered)
      (
        name: _text(byId[id]?['fullName']).isEmpty
            ? '-'
            : _text(byId[id]?['fullName']),
        position: _positionWithStanding(byId[id]),
      ),
  ];
  final director = LeaveFormData(
    leaf: const {},
    allUsers: users,
    allLeaveRequests: const [],
  ).directorName;

  final start = _thaiDate(trip['startDate']);
  final end = _thaiDate(trip['endDate']);
  final half = trip['isHalfDay'] == true;
  final cost = _number(trip['estimatedCost']);
  String or(Object? v) {
    final t = _text(v).trim();
    return t.isEmpty ? _blank : t;
  }

  final province = _text(trip['province']);
  final s = school ?? SchoolInfo.current;
  final totalDays = trip['totalDays'];

  return RenderContext(
    title: 'OfficialTrip-${_text(trip['title'])}',
    values: {
      'ชื่อ': _text(owner?['fullName']).isEmpty ? _blank : _text(owner?['fullName']),
      'ตำแหน่ง': _positionWithStanding(owner).isEmpty
          ? _blank
          : _positionWithStanding(owner),
      'เรื่อง': or(trip['title']),
      'ประเภท': _text(trip['tripType']).isEmpty ? 'ประชุม' : _text(trip['tripType']),
      'หน่วยงานที่จัด': or(trip['organizer']),
      'สถานที่': or(trip['location']),
      'จังหวัด': province.trim().isNotEmpty
          ? 'จังหวัด${province.replaceFirst(RegExp('^จังหวัด'), '')}'
          : '',
      'เลขที่หนังสือ': or(trip['docNumber']),
      'วันที่หนังสือ':
          _thaiDate(trip['docDate']).isEmpty ? _blank : _thaiDate(trip['docDate']),
      'วันที่เริ่ม': start.isEmpty ? _blank : start,
      'วันที่สิ้นสุด': end.isEmpty ? _blank : end,
      'ช่วงวันที่': start.isEmpty
          ? _blank
          : (start == end || end.isEmpty ? start : '$start ถึงวันที่ $end'),
      'ช่วงเวลา': !half
          ? 'เต็มวัน'
          : trip['halfDayPeriod'] == 'afternoon'
              ? 'ครึ่งวันบ่าย'
              : 'ครึ่งวันเช้า',
      'จำนวนวัน':
          totalDays == null ? _blank : _text(_number(totalDays)),
      'การเดินทาง': or(trip['travelMode']),
      'แหล่งค่าใช้จ่าย': or(trip['budgetSource']),
      'ค่าใช้จ่าย': cost > 0 ? 'ประมาณ ${_thaiNumber(cost)} บาท' : '',
      'จำนวนผู้ร่วมเดินทาง': '${members.length}',
      'หมายเหตุ': _text(trip['note']),
      'สถานะ': _text(trip['status']),
      'วันที่ยื่น': _thaiDate(trip['createdAt']).isEmpty
          ? _blank
          : _thaiDate(trip['createdAt']),
      'รายงานผล': _text(trip['reportSummary']),
      'โรงเรียน': s.fullName,
      'ที่อยู่โรงเรียน': s.address,
      'สังกัด': s.affiliation,
      'ผู้อำนวยการ': director,
    },
    flags: {
      'อนุมัติแล้ว': trip['status'] == 'อนุมัติ',
      'ไม่อนุมัติ': trip['status'] == 'ไม่อนุมัติ',
      'ครึ่งวัน': half,
      'มีค่าใช้จ่าย': cost > 0,
    },
    members: members,
  );
}
