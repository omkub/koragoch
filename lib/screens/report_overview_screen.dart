import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/firebase_service.dart';

class ReportOverviewScreen extends StatefulWidget {
  const ReportOverviewScreen({super.key});

  @override
  State<ReportOverviewScreen> createState() => _ReportOverviewScreenState();
}

class _ReportOverviewScreenState extends State<ReportOverviewScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _allLeaves = [];
  List<Map<String, dynamic>> _allRounds = []; // 📅 รายการรอบงบประมาณทั้งหมดครับ
  Map<String, dynamic>? _selectedRound; // 📅 รอบที่เลือกดูอยู่ครับ
  Map<String, dynamic>? _activeRound; // 📅 รอบปัจจุบัน (Default)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final teachers = await _firebaseService.getUsers();
      final leaves = await _firebaseService.getLeaveRequests();
      final rounds = await _firebaseService.getFiscalRounds();
      final activeRound = await _firebaseService.getActiveFiscalRound();
      
      if (mounted) {
        // หากยังไม่ได้เลือก ให้ใช้ Active Round เป็นค่าเริ่มต้นครับ 🥇
        _allRounds = rounds;
        
        // 🥇 เชื่อมโยง Instance ของ Active Round ให้ตรงกับที่มีใน Dropdown (ป้องกัน Error Crash) 🕵️‍♂️
        if (activeRound != null) {
          _activeRound = _allRounds.firstWhere(
            (r) => r['id'] == activeRound['id'], 
            orElse: () => activeRound
          );
        } else {
          _activeRound = null;
        }

        if (_selectedRound != null) {
          _selectedRound = _allRounds.firstWhere(
            (r) => r['id'] == _selectedRound!['id'], 
            orElse: () => _selectedRound!
          );
        } else {
          _selectedRound = _activeRound;
        }

        // 🕵️‍♂️ หาทุกชื่อที่มีใบลาในช่วงนี้ (Inclusive Logic) 🥇🏆
        final List<Map<String, dynamic>> allDisplayTeachers = teachers
            .where((u) => u['fullName'] != 'ผู้ดูแลระบบ')
            .toList();
            
        final currentViewRound = _selectedRound ?? activeRound;

        final activeLeaves = leaves.where((l) {
          if (currentViewRound == null) return false;
          return FirebaseService.isDateInRange(
            (l['startDate'] ?? '').toString(),
            currentViewRound['startDate'],
            currentViewRound['endDate']
          );
        }).toList();

        final Set<String> registeredNames = allDisplayTeachers
            .map((t) => (t['fullName'] ?? '').toString().trim())
            .toSet();
        
        for (var l in activeLeaves) {
          String name = (l['fullName'] ?? '').toString().trim();
          if (name.isNotEmpty && !registeredNames.contains(name)) {
            allDisplayTeachers.add({
              'fullName': name,
              'position': 'บุคลากร (ยังไม่มีในระบบ)',
              'department': l['department'] ?? '-',
              'isShadow': true, 
            });
            registeredNames.add(name);
          }
        }

        // 🚀 จัดเรียงคุณครูตามกลุ่มสาระเดียวกันให้อยู่ด้วยกันครับ 🥇
        allDisplayTeachers.sort((a, b) {
          final deptA = (a['department'] ?? '').toString();
          final deptB = (b['department'] ?? '').toString();
          return deptA.compareTo(deptB);
        });

        setState(() {
          _teachers = allDisplayTeachers;
          _allLeaves = leaves;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;

    return Material(
      color: const Color(0xFFF1F5F9),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('รายงานสรุปการลา', style: GoogleFonts.sarabun(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    if (_selectedRound != null)
                      _buildRoundDropdown()
                    else
                      Text('ข้อมูลการลาสะสมของคุณครูทั้งหมด (กรุณาตั้งค่ารอบงบประมาณ)', style: GoogleFonts.sarabun(fontSize: 14, color: Colors.blueGrey)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.download, size: 18),
                      label: Text('ไฟล์ PDF', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _exportExcel,
                      icon: const Icon(Icons.table_view_rounded, size: 18),
                      label: Text('Export Excel', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: isMobile ? 1000 : MediaQuery.of(context).size.width - (isMobile ? 32 : 320), // Responsive width
                      child: Column(
                        children: [
                          // Grouped Header
                          Container(
                            color: const Color(0xFFF8FAFC),
                            child: Row(
                              children: [
                                _buildHeaderCell('ชื่อ - สกุล / ตำแหน่ง', flex: 3),
                                _buildGroupedHeaderCell('ลาป่วย', flex: 2),
                                _buildGroupedHeaderCell('ลากิจ', flex: 2),
                                _buildGroupedHeaderCell('ลาคลอด', flex: 2),
                                _buildHeaderCell('รวม (ครั้ง / วัน)', flex: 2),
                              ],
                            ),
                          ),
                          // Sub Header
                          Container(
                            color: const Color(0xFFF1F5F9),
                            child: Row(
                              children: [
                                const Expanded(flex: 3, child: SizedBox()),
                                _buildSubHeaderCell(['ครั้ง', 'วัน'], flex: 2),
                                _buildSubHeaderCell(['ครั้ง', 'วัน'], flex: 2),
                                _buildSubHeaderCell(['ครั้ง', 'วัน'], flex: 2),
                                const Expanded(flex: 2, child: SizedBox()),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Column(
                                children: [
                                  if (_isLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(100),
                                      child: Center(child: CircularProgressIndicator(color: Colors.black)),
                                    )
                                  else if (_activeRound == null)
                                    _buildNoBudgetWarning()
                                  else
                                    ..._teachers.map((t) => _buildTeacherRow(t)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedHeaderCell(String title, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.black.withOpacity(0.03)))),
        child: Text(title, style: GoogleFonts.sarabun(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ),
    );
  }

  Widget _buildHeaderCell(String title, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.black.withOpacity(0.03)))),
        child: Text(title, style: GoogleFonts.sarabun(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ),
    );
  }

  Widget _buildSubHeaderCell(List<String> titles, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 36,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.black.withOpacity(0.03)))),
        child: Row(
          children: titles.map((t) => Expanded(child: Center(child: Text(t, style: GoogleFonts.sarabun(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))))).toList(),
        ),
      ),
    );
  }

  Widget _buildTeacherRow(Map<String, dynamic> teacher) {
    final name = teacher['fullName'] ?? '-';
    
    // Filter approved leaves for this teacher in the current view round 🥇🏆
    final currentViewRound = _selectedRound ?? _activeRound;
    
    final approvedLeaves = _allLeaves.where((l) {
      if (currentViewRound == null) return false;
      
      // 🕵️‍♂️ กรองด้วยชื่อแบบไม่สนใจช่องว่างหัวท้ายครับ (Robust Name Matching) 🥇🏆
      final String leaveName = (l['fullName'] ?? '').toString().trim();
      final String teacherName = name.trim();
      
      if (leaveName != teacherName) return false;

      // 🕵️‍♂️ กรองสถานะที่ได้รับอนุญาตแล้ว (ใช้ contains เพื่อความยืดหยุ่นครับ) 🥇
      final String status = (l['status'] ?? '').toString();
      final bool isApproved = status.contains('อนุญาต') || 
                              status.contains('ส่งใบลาแล้ว') || 
                              status.contains('ส่งใบแล้ว') ||
                              status.contains('อนุมัติ');
      
      if (!isApproved) return false;

      final String startDate = (l['startDate'] ?? '').toString();
      return FirebaseService.isDateInRange(startDate, currentViewRound['startDate'], currentViewRound['endDate']);
    }).toList();

    final sick = _calcType(approvedLeaves, "ป่วย");
    final personal = _calcType(approvedLeaves, "กิจ");
    final maternity = _calcType(approvedLeaves, "คลอด");

    final totalTimes = sick['times']!.toInt() + personal['times']!.toInt() + maternity['times']!.toInt();
    final totalDays = sick['days']! + personal['days']! + maternity['days']!;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.03)))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(_getPositionAndDept(teacher), style: GoogleFonts.sarabun(fontSize: 11, color: Colors.blueGrey)),
                ],
              ),
            ),
          ),
          _buildValueCell(_formatNumber(sick['times']!), _formatNumber(sick['days']!), flex: 2, color: Colors.blue.shade700),
          _buildValueCell(_formatNumber(personal['times']!), _formatNumber(personal['days']!), flex: 2, color: Colors.orange.shade700),
          _buildValueCell(_formatNumber(maternity['times']!), _formatNumber(maternity['days']!), flex: 2, color: Colors.purple.shade700),
          Expanded(
            flex: 2,
            child: Container(
              height: 64,
              alignment: Alignment.center,
              child: Text('$totalTimes / ${_formatNumber(totalDays)}', style: GoogleFonts.sarabun(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedRound,
          dropdownColor: Colors.white,
          hint: Text("เลือกรอบงบประมาณ", style: GoogleFonts.sarabun(fontSize: 14)),
          items: _allRounds.map((round) {
            return DropdownMenuItem(
              value: round,
              child: Text(
                'ปี ${round['year']} รอบที่ ${round['round']}',
                style: GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedRound = val;
              _loadData();
            });
          },
        ),
      ),
    );
  }

  Widget _buildNoBudgetWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
            child: Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 24),
          Text('ไม่พบรอบงบประมาณที่เปิดใช้งาน', 
            style: GoogleFonts.sarabun(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'กรุณาติดต่อผู้ดูแลระบบเพื่อเปิดใช้งานรอบงบประมาณ\nข้อมูลตารางสรุปจะแสดงผลตามช่วงเวลาของรอบที่เลือกครับ',
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(fontSize: 15, color: Colors.blueGrey, height: 1.6),
          ),
        ],
      ),
    );
  }

  void _exportPdf() {
    final currentViewRound = _selectedRound ?? _activeRound;
    if (currentViewRound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรอบงบประมาณสำหรับออกรายงาน')),
      );
      return;
    }

    final htmlContent = _buildReportHtml(currentViewRound);
    final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final popup = html.window.open(url, '_blank');

    if (popup == null) {
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เบราว์เซอร์บล็อกหน้าต่าง PDF กรุณาอนุญาต pop-up')),
      );
      return;
    }

    Future.delayed(const Duration(seconds: 20), () => html.Url.revokeObjectUrl(url));
  }

  String _htmlEscape(dynamic value) => const HtmlEscape().convert(value?.toString() ?? '');

  void _exportExcel() {
    final currentViewRound = _selectedRound ?? _activeRound;
    if (currentViewRound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรอบงบประมาณสำหรับออกรายงาน')),
      );
      return;
    }

    final bytes = _buildXlsxBytes(currentViewRound);
    final year = (currentViewRound['year'] ?? '').toString();
    final round = (currentViewRound['round'] ?? '').toString();
    final fileName = 'leave_summary_${year}_round_$round.xlsx';
    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  List<_ReportSummaryRow> _buildSummaryRows(Map<String, dynamic> currentViewRound) {
    return _teachers.map((teacher) {
      final name = (teacher['fullName'] ?? '-').toString();
      final position = (teacher['position'] ?? '-').toString();
      final department = (teacher['department'] ?? '-').toString();
      final approvedLeaves = _allLeaves.where((l) {
        final leaveName = (l['fullName'] ?? '').toString().trim();
        if (leaveName != name.trim()) return false;

        final status = (l['status'] ?? '').toString();
        final isApproved = status.contains('อนุญาต') ||
            status.contains('ส่งใบลาแล้ว') ||
            status.contains('ส่งใบแล้ว') ||
            status.contains('อนุมัติ');
        if (!isApproved) return false;

        return FirebaseService.isDateInRange(
          (l['startDate'] ?? '').toString(),
          currentViewRound['startDate'],
          currentViewRound['endDate'],
        );
      }).toList();

      final sick = _calcType(approvedLeaves, 'ป่วย');
      final personal = _calcType(approvedLeaves, 'กิจ');
      final maternity = _calcType(approvedLeaves, 'คลอด');
      final totalTimes = sick['times']!.toInt() +
          personal['times']!.toInt() +
          maternity['times']!.toInt();
      final totalDays = sick['days']! + personal['days']! + maternity['days']!;

      return _ReportSummaryRow(
        name: name,
        position: position,
        department: department,
        sickTimes: sick['times']!.toInt(),
        sickDays: sick['days']!,
        personalTimes: personal['times']!.toInt(),
        personalDays: personal['days']!,
        maternityTimes: maternity['times']!.toInt(),
        maternityDays: maternity['days']!,
        totalTimes: totalTimes,
        totalDays: totalDays,
      );
    }).toList();
  }

  Uint8List _buildXlsxBytes(Map<String, dynamic> currentViewRound) {
    final rows = _buildSummaryRows(currentViewRound);
    final roundTitle = 'ปีงบ ${currentViewRound['year'] ?? ''} - รอบที่ ${currentViewRound['round'] ?? ''}';
    final dateRange =
        '${FirebaseService.formatThaiDate(currentViewRound['startDate'])} - ${FirebaseService.formatThaiDate(currentViewRound['endDate'])}';

    final sheetRows = <List<dynamic>>[
      ['รายงานสรุปการลา'],
      [roundTitle],
      ['ช่วงวันที่ $dateRange'],
      const [],
      ['ชื่อ - สกุล', 'ตำแหน่ง', 'กลุ่มสาระ', 'ลาป่วย ครั้ง', 'ลาป่วย วัน', 'ลากิจ ครั้ง', 'ลากิจ วัน', 'ลาคลอด ครั้ง', 'ลาคลอด วัน', 'รวม ครั้ง', 'รวม วัน'],
      ...rows.map((r) => [
            r.name,
            r.position,
            r.department,
            r.sickTimes,
            r.sickDays,
            r.personalTimes,
            r.personalDays,
            r.maternityTimes,
            r.maternityDays,
            r.totalTimes,
            r.totalDays,
          ]),
    ];

    final files = <String, Uint8List>{
      '[Content_Types].xml': _utf8Bytes(_contentTypesXml),
      '_rels/.rels': _utf8Bytes(_rootRelsXml),
      'xl/workbook.xml': _utf8Bytes(_workbookXml),
      'xl/_rels/workbook.xml.rels': _utf8Bytes(_workbookRelsXml),
      'xl/styles.xml': _utf8Bytes(_stylesXml),
      'xl/worksheets/sheet1.xml': _utf8Bytes(_worksheetXml(sheetRows)),
    };
    return _ZipWriter.store(files);
  }

  Uint8List _utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value.trim()));

  String _cellRef(int row, int col) {
    var column = '';
    var n = col;
    while (n > 0) {
      final remainder = (n - 1) % 26;
      column = String.fromCharCode(65 + remainder) + column;
      n = (n - remainder - 1) ~/ 26;
    }
    return '$column$row';
  }

  String _worksheetXml(List<List<dynamic>> rows) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<cols>')
      ..write('<col min="1" max="1" width="28" customWidth="1"/>')
      ..write('<col min="2" max="2" width="20" customWidth="1"/>')
      ..write('<col min="3" max="3" width="22" customWidth="1"/>')
      ..write('<col min="4" max="11" width="13" customWidth="1"/>')
      ..write('</cols>')
      ..write('<sheetData>');

    for (var r = 0; r < rows.length; r++) {
      final rowNumber = r + 1;
      buffer.write('<row r="$rowNumber">');
      for (var c = 0; c < rows[r].length; c++) {
        final value = rows[r][c];
        if (value == null || value == '') continue;
        final ref = _cellRef(rowNumber, c + 1);
        final style = rowNumber == 1 ? 2 : (rowNumber == 5 ? 1 : 0);
        if (value is num) {
          buffer.write('<c r="$ref" s="$style"><v>${_formatNumber(value)}</v></c>');
        } else {
          buffer.write('<c r="$ref" s="$style" t="inlineStr"><is><t>${_xmlEscape(value)}</t></is></c>');
        }
      }
      buffer.write('</row>');
    }

    buffer
      ..write('</sheetData>')
      ..write('<mergeCells count="3"><mergeCell ref="A1:K1"/><mergeCell ref="A2:K2"/><mergeCell ref="A3:K3"/></mergeCells>')
      ..write('</worksheet>');
    return buffer.toString();
  }

  String _xmlEscape(dynamic value) => const HtmlEscape().convert(value?.toString() ?? '');

  static const String _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>
''';

  static const String _rootRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
''';

  static const String _workbookXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="รายงานสรุปการลา" sheetId="1" r:id="rId1"/></sheets>
</workbook>
''';

  static const String _workbookRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
''';

  static const String _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="3"><font><sz val="11"/><name val="Sarabun"/></font><font><b/><sz val="11"/><name val="Sarabun"/></font><font><b/><sz val="16"/><name val="Sarabun"/></font></fonts>
  <fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFF1F5F9"/><bgColor indexed="64"/></patternFill></fill></fills>
  <borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/><xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf></cellXfs>
</styleSheet>
''';

  String _buildReportHtml(Map<String, dynamic> currentViewRound) {
    final roundTitle =
        'ปีงบ ${_htmlEscape(currentViewRound['year'])} - รอบที่ ${_htmlEscape(currentViewRound['round'])}';
    final dateRange =
        '${_htmlEscape(FirebaseService.formatThaiDate(currentViewRound['startDate']))} - ${_htmlEscape(FirebaseService.formatThaiDate(currentViewRound['endDate']))}';

    final rows = _teachers.map((teacher) {
      final name = (teacher['fullName'] ?? '-').toString();
      final position = (teacher['position'] ?? '-').toString();
      final approvedLeaves = _allLeaves.where((l) {
        final leaveName = (l['fullName'] ?? '').toString().trim();
        if (leaveName != name.trim()) return false;

        final status = (l['status'] ?? '').toString();
        final isApproved = status.contains('อนุญาต') ||
            status.contains('ส่งใบลาแล้ว') ||
            status.contains('ส่งใบแล้ว') ||
            status.contains('อนุมัติ');
        if (!isApproved) return false;

        return FirebaseService.isDateInRange(
          (l['startDate'] ?? '').toString(),
          currentViewRound['startDate'],
          currentViewRound['endDate'],
        );
      }).toList();

      final sick = _calcType(approvedLeaves, 'ป่วย');
      final personal = _calcType(approvedLeaves, 'กิจ');
      final maternity = _calcType(approvedLeaves, 'คลอด');
      final totalTimes = sick['times']!.toInt() + personal['times']!.toInt() + maternity['times']!.toInt();
      final totalDays = sick['days']! + personal['days']! + maternity['days']!;

      return '''
        <tr>
          <td class="name"><strong>${_htmlEscape(name)}</strong><br><span>${_htmlEscape(_getPositionAndDept(teacher))}</span></td>
          <td>${_formatPdfNumber(sick['times']!)}</td>
          <td>${_formatPdfNumber(sick['days']!)}</td>
          <td>${_formatPdfNumber(personal['times']!)}</td>
          <td>${_formatPdfNumber(personal['days']!)}</td>
          <td>${_formatPdfNumber(maternity['times']!)}</td>
          <td>${_formatPdfNumber(maternity['days']!)}</td>
          <td><strong>$totalTimes / ${_formatNumber(totalDays)}</strong></td>
        </tr>
      ''';
    }).join();

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>รายงานสรุปการลา</title>
  <style>
    @page { size: A4 landscape; margin: 12mm; }
    body { font-family: "Sarabun", Arial, sans-serif; color: #0f172a; margin: 0; }
    .toolbar { padding: 12px; background: #0f172a; text-align: right; }
    .toolbar button { background: white; border: 0; border-radius: 8px; padding: 9px 14px; font-weight: 700; cursor: pointer; }
    h1 { margin: 18px 0 4px; font-size: 22px; text-align: center; }
    .subtitle { text-align: center; color: #475569; margin-bottom: 18px; font-size: 13px; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; }
    th, td { border: 1px solid #cbd5e1; padding: 7px 8px; text-align: center; vertical-align: middle; }
    th { background: #f1f5f9; font-weight: 700; }
    .name { text-align: left; min-width: 190px; }
    .name span { color: #64748b; font-size: 11px; }
    @media print { .toolbar { display: none; } h1 { margin-top: 0; } }
  </style>
</head>
<body>
  <div class="toolbar"><button onclick="window.print()">พิมพ์ / บันทึก PDF</button></div>
  <h1>รายงานสรุปการลา</h1>
  <div class="subtitle">$roundTitle<br>ช่วงวันที่ $dateRange</div>
  <table>
    <thead>
      <tr>
        <th rowspan="2">ชื่อ - สกุล / ตำแหน่ง</th>
        <th colspan="2">ลาป่วย</th>
        <th colspan="2">ลากิจ</th>
        <th colspan="2">ลาคลอด</th>
        <th rowspan="2">รวม (ครั้ง / วัน)</th>
      </tr>
      <tr>
        <th>ครั้ง</th><th>วัน</th>
        <th>ครั้ง</th><th>วัน</th>
        <th>ครั้ง</th><th>วัน</th>
      </tr>
    </thead>
    <tbody>$rows</tbody>
  </table>
  <script>setTimeout(function(){ window.print(); }, 400);</script>
</body>
</html>
''';
  }

  Map<String, double> _calcType(List<Map<String, dynamic>> leaves, String typePart) {
    final filtered = leaves.where((l) => (l['leaveType'] ?? '').toString().contains(typePart)).toList();
    final days = filtered.fold<double>(0, (sum, l) {
      // 🕵️‍♂️ รองรับทั้งฟิลด์ totalDays และ days เพื่อความครอบคลุมครับ 🥇🏆
      var dValue = l['totalDays'] ?? l['days'];
      return sum + (double.tryParse(dValue?.toString() ?? '0') ?? 0);
    });
    return {'times': filtered.length.toDouble(), 'days': days};
  }

  String _formatNumber(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  String _formatPdfNumber(num value) {
    return value == 0 ? '-' : _formatNumber(value);
  }

  String _getPositionAndDept(Map<String, dynamic> teacher) {
    final pos = (teacher['position'] ?? '-').toString();
    final dept = (teacher['department'] ?? '').toString().trim();
    if (dept.isEmpty || dept == '-') {
      return pos;
    }
    return '$pos ($dept)';
  }

  Widget _buildValueCell(String v1, String v2, {required int flex, Color? color}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 64,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.black.withOpacity(0.02)))),
        child: Row(
          children: [
            Expanded(child: Center(child: Text(v1 == '0' ? '-' : v1, style: TextStyle(fontSize: 13, color: color ?? Colors.black38, fontWeight: v1 == '0' ? FontWeight.normal : FontWeight.bold)))),
            Expanded(child: Center(child: Text(v2 == '0' ? '-' : v2, style: TextStyle(fontSize: 13, color: color ?? Colors.black38, fontWeight: v2 == '0' ? FontWeight.normal : FontWeight.bold)))),
          ],
        ),
      ),
    );
  }
}

class _ReportSummaryRow {
  const _ReportSummaryRow({
    required this.name,
    required this.position,
    required this.department,
    required this.sickTimes,
    required this.sickDays,
    required this.personalTimes,
    required this.personalDays,
    required this.maternityTimes,
    required this.maternityDays,
    required this.totalTimes,
    required this.totalDays,
  });

  final String name;
  final String position;
  final String department;
  final int sickTimes;
  final double sickDays;
  final int personalTimes;
  final double personalDays;
  final int maternityTimes;
  final double maternityDays;
  final int totalTimes;
  final double totalDays;
}

class _ZipWriter {
  static Uint8List store(Map<String, Uint8List> files) {
    final bytes = <int>[];
    final centralDirectory = <int>[];

    files.forEach((name, data) {
      final nameBytes = utf8.encode(name);
      final offset = bytes.length;
      final crc = _crc32(data);

      _u32(bytes, 0x04034b50);
      _u16(bytes, 20);
      _u16(bytes, 0x0800);
      _u16(bytes, 0);
      _u16(bytes, 0);
      _u16(bytes, 0);
      _u32(bytes, crc);
      _u32(bytes, data.length);
      _u32(bytes, data.length);
      _u16(bytes, nameBytes.length);
      _u16(bytes, 0);
      bytes.addAll(nameBytes);
      bytes.addAll(data);

      _u32(centralDirectory, 0x02014b50);
      _u16(centralDirectory, 20);
      _u16(centralDirectory, 20);
      _u16(centralDirectory, 0x0800);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u32(centralDirectory, crc);
      _u32(centralDirectory, data.length);
      _u32(centralDirectory, data.length);
      _u16(centralDirectory, nameBytes.length);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u32(centralDirectory, 0);
      _u32(centralDirectory, offset);
      centralDirectory.addAll(nameBytes);
    });

    final centralDirectoryOffset = bytes.length;
    bytes.addAll(centralDirectory);

    _u32(bytes, 0x06054b50);
    _u16(bytes, 0);
    _u16(bytes, 0);
    _u16(bytes, files.length);
    _u16(bytes, files.length);
    _u32(bytes, centralDirectory.length);
    _u32(bytes, centralDirectoryOffset);
    _u16(bytes, 0);

    return Uint8List.fromList(bytes);
  }

  static void _u16(List<int> out, int value) {
    out.add(value & 0xff);
    out.add((value >> 8) & 0xff);
  }

  static void _u32(List<int> out, int value) {
    out.add(value & 0xff);
    out.add((value >> 8) & 0xff);
    out.add((value >> 16) & 0xff);
    out.add((value >> 24) & 0xff);
  }

  static int _crc32(List<int> data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >> 8);
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  static final List<int> _crcTable = List<int>.generate(256, (i) {
    var crc = i;
    for (var j = 0; j < 8; j++) {
      crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
    return crc;
  });
}
