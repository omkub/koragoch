/// แบบใบลาราชการฉบับกลาง — วาดเอกสารขนาด A4 จาก [LeaveFormData]
///
/// เดิมเอกสารใบเดียวกันถูกวาดไว้ 3 ที่ (หน้าส่งใบลา, หน้าพรีวิว, HTML สำหรับพิมพ์)
/// แก้ทีต้องไล่แก้ครบสามที่ ลืมที่ใดที่หนึ่งแล้วใบที่กรอกกับใบที่พิมพ์จะไม่ตรงกัน
/// ไฟล์นี้คือฉบับกลางที่ตั้งใจให้ทุกหน้าเรียกใช้ร่วมกันในที่สุด
///
/// ตอนนี้รองรับโหมดอ่านอย่างเดียวก่อน (ดูและพิมพ์) ส่วนโหมดกรอกจะเพิ่มทีหลัง
/// เมื่อยืนยันแล้วว่าโหมดนี้แสดงผลตรงกับของเดิมทุกประการ
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/school_info.dart';
import 'leave_form_data.dart';

/// สไตล์ตัวอักษรมาตรฐานของเอกสาร
TextStyle get _docBaseStyle =>
    GoogleFonts.sarabun(fontSize: 14, color: Colors.black, height: 1.5);

/// เอกสารใบลาเต็มหน้า A4 (โหมดอ่านอย่างเดียว)
///
/// วาดเฉพาะตัวกระดาษ ไม่มีแถบเครื่องมือ เพื่อให้เอาไปใส่ในหน้าจอแบบไหนก็ได้
class LeaveFormDocument extends StatelessWidget {
  final LeaveFormData data;

  const LeaveFormDocument({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildSchoolBlock(),
          const SizedBox(height: 35),
          _buildSubjectBlock(),
          const SizedBox(height: 18),
          _buildLeaveTypeBlock(),
          const SizedBox(height: 18),
          _buildDateBlock(),
          const SizedBox(height: 25),
          Center(
              child:
                  Text('จึงเรียนมาเพื่อโปรดพิจารณา', style: _docBaseStyle)),
          const SizedBox(height: 40),
          _buildSignatureBlock(),
        ],
      ),
    );
  }

  /// หัวเอกสาร: ชื่อแบบฟอร์ม + กล่อง "รับที่" มุมขวาบน
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 180),
        Expanded(
          child: Column(
            children: [
              Text('แบบใบลา',
                  style: GoogleFonts.sarabun(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline)),
              Text('ลาป่วย/ลากิจ/ลาคลอดบุตร',
                  style: GoogleFonts.sarabun(fontSize: 14)),
            ],
          ),
        ),
        Container(
          width: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(width: 0.8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LeaveFormDottedLabel('รับที่', value: data.receiveNumber),
              const SizedBox(height: 6),
              LeaveFormDottedLabel('วันที่', value: data.receiveDate),
              const SizedBox(height: 6),
              LeaveFormDottedLabel('เวลา', value: data.receiveTime),
            ],
          ),
        ),
      ],
    );
  }

  /// ชื่อโรงเรียน ที่อยู่ และวันที่เขียนใบลา (ชิดขวา)
  Widget _buildSchoolBlock() {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(SchoolInfo.fullName,
              style: _docBaseStyle.copyWith(fontWeight: FontWeight.bold)),
          Text(SchoolInfo.address, style: _docBaseStyle),
          const SizedBox(height: 20),
          Text(
              'วันที่  ${data.requestDay}  เดือน  ${data.requestMonth}  พ.ศ.  ${data.requestYear}',
              style: _docBaseStyle),
        ],
      ),
    );
  }

  /// เรื่อง / เรียน / ข้าพเจ้า ... ตำแหน่ง ...
  Widget _buildSubjectBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeaveFormRow([
          Text('เรื่อง ',
              style: _docBaseStyle.copyWith(fontWeight: FontWeight.bold)),
          LeaveFormDottedLine(value: data.subject),
        ]),
        Text('เรียน ${SchoolInfo.addressee}', style: _docBaseStyle),
        const SizedBox(height: 18),
        LeaveFormRow([
          const SizedBox(width: 60),
          Text('ข้าพเจ้า', style: _docBaseStyle),
          LeaveFormDottedLine(value: data.fullName, flex: 8),
          Text('ตำแหน่ง', style: _docBaseStyle),
          LeaveFormDottedLine(value: data.positionWithStanding, flex: 5),
          Text(SchoolInfo.namePart1, style: _docBaseStyle),
        ]),
        Text('${SchoolInfo.namePart2} ${SchoolInfo.affiliation}',
            style: _docBaseStyle),
      ],
    );
  }

  /// ช่องติ๊กประเภทการลา + ปีกกา + เหตุผล
  Widget _buildLeaveTypeBlock() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 80,
            child: Text('ขอลา',
                style: _docBaseStyle.copyWith(fontWeight: FontWeight.bold))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.printableLeaveTypes
              .map((t) =>
                  LeaveFormCheckBox(t, checked: data.isSelectedLeaveType(t)))
              .toList(),
        ),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Text('}',
                style: TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.w100,
                    height: 1.1,
                    fontFamily: 'serif'))),
        Expanded(
          child: Column(children: [
            const SizedBox(height: 35),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เนื่องจาก', style: _docBaseStyle),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.reason,
                    style: _docBaseStyle,
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    textWidthBasis: TextWidthBasis.parent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const LeaveFormDottedLine(width: double.infinity, flex: 0),
          ]),
        ),
      ],
    );
  }

  /// ช่วงวันลาครั้งนี้ และการลาครั้งล่าสุด
  Widget _buildDateBlock() {
    final latestLabel = data.latestLeaveLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeaveFormRow([
          Text('ตั้งแต่วันที่', style: _docBaseStyle),
          LeaveFormDottedLine(value: data.startDateText),
          Text('ถึงวันที่', style: _docBaseStyle),
          LeaveFormDottedLine(value: data.endDateText),
          Text('มีกำหนด', style: _docBaseStyle),
          LeaveFormDottedLine(flex: 0, width: 60, value: data.totalDaysText),
          Text('วัน', style: _docBaseStyle),
        ]),
        LeaveFormRow([
          Text('ข้าพเจ้าได้ลา', style: _docBaseStyle),
          LeaveFormCheckBox('ป่วย', checked: latestLabel == 'ป่วย'),
          LeaveFormCheckBox('ลากิจส่วนตัว',
              checked: latestLabel == 'ลากิจส่วนตัว'),
          LeaveFormCheckBox('ลาคลอดบุตร', checked: latestLabel == 'ลาคลอดบุตร'),
          Text('ครั้งสุดท้ายตั้งแต่วันที่', style: _docBaseStyle),
          LeaveFormDottedLine(value: data.latestStartText, flex: 1),
          Text('ถึงวันที่', style: _docBaseStyle),
          LeaveFormDottedLine(value: data.latestEndText, flex: 1),
        ]),
        LeaveFormRow([
          Text('มีกำหนด', style: _docBaseStyle),
          LeaveFormDottedLine(flex: 0, width: 40, value: data.latestDaysText),
          Text('วัน ในระหว่างที่ลาติดต่อข้าพเจ้าได้ที่', style: _docBaseStyle),
          LeaveFormDottedLine(flex: 4, value: data.phone),
        ]),
      ],
    );
  }

  /// ครึ่งล่างของเอกสาร: ตารางสถิติ (ซ้าย) และช่องเซ็นอนุมัติ (ขวา)
  Widget _buildSignatureBlock() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 1, child: _buildStatsColumn()),
          const SizedBox(width: 45),
          Expanded(flex: 1, child: _buildApprovalColumn()),
        ],
      ),
    );
  }

  Widget _buildStatsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        Text('สถิติวันลาในปีงบประมาณนี้',
            style:
                GoogleFonts.sarabun(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(width: 0.6),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.0),
          },
          children: [
            const TableRow(children: [
              LeaveFormTableCell('ประเภท\nการลา',
                  bold: true, size: 10, height: 60),
              LeaveFormTableCell('ลามาแล้ว\nครั้ง/วัน\n(วันทำการ)',
                  bold: true, size: 10, height: 60),
              LeaveFormTableCell('ลาครั้งนี้\nครั้ง/วัน\n(วันทำการ)',
                  bold: true, size: 10, height: 60),
              LeaveFormTableCell('รวมเป็น\nครั้ง/วัน\n(วันทำการ)',
                  bold: true, size: 10, height: 60),
            ]),
            for (final row in data.statRows)
              TableRow(children: [
                LeaveFormTableCell(row.label, size: 10),
                LeaveFormSplitCell(row.previousTimes, row.previousDays),
                LeaveFormSplitCell(row.currentTimes, row.currentDays),
                LeaveFormSplitCell(row.totalTimes, row.totalDays),
              ]),
          ],
        ),
        const SizedBox(height: 20),
        _signatureLines(
          name: data.hrName,
          title: 'หัวหน้ากลุ่มบริหารงานบุคคล',
        ),
      ],
    );
  }

  Widget _buildApprovalColumn() {
    final applicantPosition =
        data.position.isEmpty ? '................................' : data.position;
    final applicantName =
        data.fullName.isEmpty ? '................................' : data.fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('ขอแสดงความนับถือ', style: _docBaseStyle),
        const SizedBox(height: 15),
        Text('ลงชื่อ ..................................................',
            style: _docBaseStyle),
        Text('($applicantName)',
            style:
                GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('ตำแหน่ง $applicantPosition', style: _docBaseStyle),
        const SizedBox(height: 35),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ความคิดเห็น',
                style: GoogleFonts.sarabun(
                    fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
                '................................................................................',
                style: GoogleFonts.sarabun(
                    color: Colors.black26, fontSize: 13, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 20),
        _signatureLines(
          name: data.deputyName,
          title: 'รองผู้อำนวยการกลุ่มบริหารงานบุคคล',
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('คำสั่ง',
                style: GoogleFonts.sarabun(
                    fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 15),
            const LeaveFormCheckBox('อนุญาต', checked: false),
            const LeaveFormCheckBox('ไม่อนุญาต', checked: false),
          ],
        ),
        const SizedBox(height: 15),
        _signatureLines(
          name: data.directorName,
          title: SchoolInfo.directorTitle,
          centerTitle: true,
        ),
      ],
    );
  }

  /// ชุดบรรทัด "ลงชื่อ ... / (ชื่อ) / ตำแหน่ง / วันที่"
  Widget _signatureLines({
    required String name,
    required String title,
    bool centerTitle = false,
  }) {
    return Column(
      children: [
        Text('ลงชื่อ ..................................................',
            style: _docBaseStyle),
        Text(name,
            style: _docBaseStyle.copyWith(fontWeight: FontWeight.bold)),
        Text(title,
            style: _docBaseStyle,
            textAlign: centerTitle ? TextAlign.center : null),
        Text('........../........../..........', style: _docBaseStyle),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ชิ้นส่วนย่อยของเอกสาร
//
// เดิมทั้งสี่ตัวนี้ถูกก๊อปไว้ในสองไฟล์แบบเหมือนกันทุกตัวอักษร
// ═══════════════════════════════════════════════════════════════

/// ป้ายกำกับพร้อมจุดไข่ปลา ใช้ในกล่อง "รับที่" มุมขวาบน
class LeaveFormDottedLabel extends StatelessWidget {
  final String label;
  final String? value;

  const LeaveFormDottedLabel(this.label, {super.key, this.value});

  @override
  Widget build(BuildContext context) {
    final display = value != null && value!.isNotEmpty
        ? '$label $value'
        : '$label .............................';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(display,
          style: GoogleFonts.sarabun(
              fontSize: 12, color: Colors.blueGrey.shade800)),
    );
  }
}

/// แถวหนึ่งบรรทัดของเอกสาร พร้อมระยะห่างบน-ล่างมาตรฐาน
class LeaveFormRow extends StatelessWidget {
  final List<Widget> children;

  const LeaveFormRow(this.children, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: children),
      );
}

/// เส้นจุดไข่ปลาที่มีข้อความลอยอยู่ด้านบน
///
/// [flex] มากกว่า 0 จะยืดตามพื้นที่ที่เหลือ ถ้าเป็น 0 ต้องกำหนด [width] เอง
class LeaveFormDottedLine extends StatelessWidget {
  final int flex;
  final double? width;
  final String? value;

  const LeaveFormDottedLine({
    super.key,
    this.flex = 1,
    this.width,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final line = Container(
      width: width,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
                '......................................................................................................................................',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: GoogleFonts.sarabun(
                    color: Colors.black26, fontSize: 18, letterSpacing: 2)),
          ),
          if (value != null && value!.isNotEmpty)
            Positioned(
                bottom: 10,
                child: Text(value!,
                    style: GoogleFonts.sarabun(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A)))),
        ],
      ),
    );
    return flex > 0 ? Expanded(flex: flex, child: line) : line;
  }
}

/// ช่องติ๊กสี่เหลี่ยมพร้อมข้อความกำกับ
class LeaveFormCheckBox extends StatelessWidget {
  final String label;
  final bool checked;

  const LeaveFormCheckBox(this.label, {super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.black)),
              child: checked
                  ? const Icon(Icons.check,
                      size: 14, color: Colors.black, weight: 800)
                  : null),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.sarabun(fontSize: 14)),
        ],
      ),
    );
  }
}

/// ช่องหนึ่งช่องของตารางสถิติ
class LeaveFormTableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final double size;
  final double? height;

  const LeaveFormTableCell(this.text,
      {super.key, this.bold = false, this.size = 12, this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4.0),
        child: Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(
                fontSize: size,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}

/// ช่องตารางที่แบ่งครึ่งเป็น "ครั้ง | วัน"
class LeaveFormSplitCell extends StatelessWidget {
  final String left;
  final String right;

  const LeaveFormSplitCell(this.left, this.right, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      child: Row(
        children: [
          Expanded(
              child: Center(
                  child: Text(left, style: GoogleFonts.sarabun(fontSize: 10)))),
          Container(width: 0.6, color: Colors.black),
          Expanded(
              child: Center(
                  child:
                      Text(right, style: GoogleFonts.sarabun(fontSize: 10)))),
        ],
      ),
    );
  }
}
