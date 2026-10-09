/// บันทึกข้อความขออนุญาตไปราชการ — วาดเอกสารขนาด A4 สำหรับพรีวิว
///
/// รูปแบบเดียวกับแม่แบบเริ่มต้นของใบขออนุญาตไปราชการใน web
/// (central/src/forms/tripTemplate.ts) ช่องที่ยังไม่กรอกแสดงเป็นจุดไข่ปลา
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/firebase_service.dart';
import '../utils/school_info.dart';

const _blank = '..............................';

/// ข้อมูลที่เอกสารใช้ — ค่าที่ยังไม่ได้กรอกให้เป็นสตริงว่าง / null
class TripFormData {
  final String ownerName;
  final String ownerPosition;
  final String title;
  final String tripType;
  final String organizer;
  final String location;
  final String province;
  final String docNumber;
  final DateTime? docDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isHalfDay;
  final String halfDayPeriod;
  final num? totalDays;
  final String travelMode;
  final String budgetSource;
  final num? estimatedCost;
  final List<({String name, String position})> members;
  final String directorName;

  /// วันที่บันทึก — รายการใหม่ที่ยังไม่บันทึกไม่มีวันที่ (เว้นเป็นเส้นไว้)
  final DateTime? createdAt;

  const TripFormData({
    this.ownerName = '',
    this.ownerPosition = '',
    this.title = '',
    this.tripType = '',
    this.organizer = '',
    this.location = '',
    this.province = '',
    this.docNumber = '',
    this.docDate,
    this.startDate,
    this.endDate,
    this.isHalfDay = false,
    this.halfDayPeriod = 'morning',
    this.totalDays,
    this.travelMode = '',
    this.budgetSource = '',
    this.estimatedCost,
    this.members = const [],
    this.directorName = '',
    this.createdAt,
  });
}

String _thaiDate(DateTime? d) =>
    d == null ? '' : FirebaseService.formatThaiDate(d);

class TripFormDocument extends StatelessWidget {
  final TripFormData data;

  const TripFormDocument({super.key, required this.data});

  TextStyle get _base =>
      GoogleFonts.sarabun(fontSize: 15, color: Colors.black, height: 1.6);
  TextStyle get _bold => _base.copyWith(fontWeight: FontWeight.bold);

  /// ค่าที่กรอกแล้วเน้นสีเข้ม ยังไม่กรอกเป็นจุดไข่ปลาสีจาง
  InlineSpan _v(String value) {
    final v = value.trim();
    return v.isEmpty
        ? TextSpan(text: _blank, style: _base.copyWith(color: Colors.black38))
        : TextSpan(
            text: v,
            style: _base.copyWith(
                fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)));
  }

  TextSpan _t(String text) => TextSpan(text: text);

  Widget _para(List<InlineSpan> spans) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text.rich(
          TextSpan(style: _base, children: [
            const WidgetSpan(child: SizedBox(width: 95)),
            ...spans,
          ]),
          textAlign: TextAlign.justify,
        ),
      );

  /// หัวข้อตัวหนา + ค่าบนเส้นประยาวถึงขอบขวา
  Widget _labeled(String label, String value, {List<Widget> tail = const []}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: _bold),
          const SizedBox(width: 6),
          Expanded(child: _dotted(value)),
          ...tail,
        ],
      ),
    );
  }

  Widget _dotted(String value, {double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.black38, style: BorderStyle.solid, width: 0.6)),
      ),
      child: Text(value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _base.copyWith(
              fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = _thaiDate(data.startDate);
    final end = _thaiDate(data.endDate);
    final range = start.isEmpty
        ? ''
        : (end.isEmpty || start == end ? start : '$start ถึงวันที่ $end');
    final period = !data.isHalfDay
        ? 'เต็มวัน'
        : data.halfDayPeriod == 'afternoon'
            ? 'ครึ่งวันบ่าย'
            : 'ครึ่งวันเช้า';
    final province = data.province.trim().isEmpty
        ? ''
        : 'จังหวัด${data.province.trim().replaceFirst(RegExp('^จังหวัด'), '')}';
    final cost = data.estimatedCost ?? 0;
    final members = data.members.isEmpty
        ? [(name: data.ownerName, position: data.ownerPosition)]
        : data.members;

    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20))
        ],
      ),
      // ขอบกระดาษ บน 20 ขวา 20 ล่าง 20 ซ้าย 30 มม. ตามแม่แบบใน web
      padding: const EdgeInsets.fromLTRB(113, 76, 76, 76),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('บันทึกข้อความ',
                style: GoogleFonts.sarabun(
                    fontSize: 26, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          _labeled('ส่วนราชการ',
              '${SchoolInfo.fullName} ${SchoolInfo.address}'.trim()),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ที่', style: _bold),
                const SizedBox(width: 6),
                _dotted('', width: 226),
                const SizedBox(width: 12),
                Text('วันที่', style: _bold),
                const SizedBox(width: 6),
                Expanded(child: _dotted(_thaiDate(data.createdAt))),
              ],
            ),
          ),
          _labeled('เรื่อง', 'ขออนุญาตไปราชการ'),
          const SizedBox(height: 14),
          Text('เรียน ${SchoolInfo.addressee}', style: _base),
          const SizedBox(height: 8),
          _para([
            _t('ด้วย '),
            _v(data.organizer),
            _t(' ได้มีหนังสือที่ '),
            _v(data.docNumber),
            _t(' ลงวันที่ '),
            _v(_thaiDate(data.docDate)),
            _t(' แจ้งให้เข้าร่วม${data.tripType.isEmpty ? 'ประชุม' : data.tripType} เรื่อง '),
            _v(data.title),
            _t(' ณ '),
            _v(data.location),
            if (province.isNotEmpty) ...[_t(' '), _v(province)],
            _t(' ในวันที่ '),
            _v(range),
            _t(' ($period) รวม '),
            _v(data.totalDays == null
                ? ''
                : FirebaseService.formatLeaveDayCount(data.totalDays!)),
            _t(' วันทำการ'),
          ]),
          _para([
            _t('ในการนี้ ข้าพเจ้าจึงขออนุญาตไปราชการดังกล่าว พร้อมด้วยผู้มีรายชื่อต่อไปนี้ รวม '),
            _v('${members.length}'),
            _t(' คน'),
          ]),
          const SizedBox(height: 10),
          _memberTable(members),
          const SizedBox(height: 10),
          _para([
            _t('โดยเดินทางด้วย '),
            _v(data.travelMode),
            _t(' ค่าใช้จ่าย '),
            _v(data.budgetSource),
            if (cost > 0)
              _t(' ประมาณ ${FirebaseService.formatLeaveDayCount(cost)} บาท'),
          ]),
          const SizedBox(height: 10),
          _para([_t('จึงเรียนมาเพื่อโปรดพิจารณาอนุญาต')]),
          const SizedBox(height: 30),
          _signature([
            Text('ลงชื่อ ..................................................',
                style: _base),
            Text.rich(TextSpan(style: _base, children: [
              _t('( '),
              _v(data.ownerName),
              _t(' )'),
            ])),
            Text.rich(TextSpan(style: _base, children: [
              _t('ตำแหน่ง '),
              _v(data.ownerPosition),
            ])),
          ]),
          const SizedBox(height: 22),
          Text('ความเห็นของผู้บังคับบัญชา', style: _bold),
          Text(
              '..................................................................................................',
              style: _base.copyWith(color: Colors.black38)),
          const SizedBox(height: 14),
          Row(children: [
            Text('คำสั่ง', style: _bold),
            const SizedBox(width: 16),
            _checkBox('อนุญาต'),
            _checkBox('ไม่อนุญาต'),
          ]),
          const SizedBox(height: 22),
          _signature([
            Text('ลงชื่อ ..................................................',
                style: _base),
            if (data.directorName.trim().isNotEmpty)
              Text(data.directorName, style: _base),
            Text(SchoolInfo.directorTitle,
                style: _base, textAlign: TextAlign.center),
            Text('........../........../..........', style: _base),
          ]),
        ],
      ),
    );
  }

  /// ช่องติ๊กว่าง (ผู้บังคับบัญชาติ๊กด้วยมือ)
  Widget _checkBox(String label) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4, right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    border: Border.all(width: 1, color: Colors.black))),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.sarabun(fontSize: 14)),
          ],
        ),
      );

  Widget _signature(List<Widget> lines) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 340,
          child: Column(children: lines),
        ),
      );

  Widget _memberTable(List<({String name, String position})> members) {
    Widget cell(String text, {bool head = false, TextAlign? align}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(text.isEmpty ? '-' : text,
              textAlign: align ?? (head ? TextAlign.center : TextAlign.left),
              style: head
                  ? _bold.copyWith(fontSize: 14)
                  : _base.copyWith(fontSize: 14)),
        );
    return Table(
      border: TableBorder.all(width: 0.6),
      columnWidths: const {
        0: FixedColumnWidth(44),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(children: [
          cell('ที่', head: true),
          cell('ชื่อ - สกุล', head: true),
          cell('ตำแหน่ง', head: true),
        ]),
        for (var i = 0; i < members.length; i++)
          TableRow(children: [
            cell('${i + 1}', align: TextAlign.center),
            cell(members[i].name),
            cell(members[i].position),
          ]),
      ],
    );
  }
}
