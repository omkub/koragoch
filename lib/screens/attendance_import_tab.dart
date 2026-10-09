/// แท็บ "นำเข้าเวลาสแกน" ในหน้าจัดการระบบ (แอดมินโรงเรียน)
///
/// ใช้ตอนยังไม่ได้เชื่อมเครื่องสแกนกับระบบ หรือตอนอินเทอร์เน็ตที่เครื่องล่ม:
/// export ไฟล์จากเครื่อง (CSV / TXT / DAT) แล้วนำเข้าที่นี่
///
/// นำเข้าซ้ำได้ แถวที่มีอยู่แล้วถูกข้าม — รหัสที่ยังไม่จับคู่กับครูเก็บไว้ก่อน
/// แล้วผูกให้อัตโนมัติเมื่อใส่รหัสให้ครูที่ web (ดู supabase/attendance.sql)
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/attendance_import.dart';
import '../services/firebase_service.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);

class AttendanceImportTab extends StatefulWidget {
  const AttendanceImportTab({super.key});

  @override
  State<AttendanceImportTab> createState() => _AttendanceImportTabState();
}

class _AttendanceImportTabState extends State<AttendanceImportTab> {
  String? _fileName;
  ParsedTable? _table;
  int? _codeCol;
  int? _dateTimeCol;
  int? _timeCol;
  Map<String, String> _nameByCode = {}; // device_code → ชื่อครู
  bool _uploading = false;
  int _progress = 0;
  ImportResult? _result;
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadTeacherCodes();
  }

  Future<void> _loadTeacherCodes() async {
    try {
      final rows = await FirebaseService.inSchool(_client
              .from('Teachers')
              .select('fullName, device_code'))
          .not('device_code', 'is', null);
      if (!mounted) return;
      setState(() => _nameByCode = {
            for (final r in rows)
              r['device_code'].toString(): (r['fullName'] ?? '').toString()
          });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'อ่านรหัสเครื่องสแกนของครูไม่ได้: ${e is PostgrestException ? e.message : e}'
          ' (รัน supabase/attendance.sql แล้วหรือยัง?)');
    }
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'dat', 'tsv'],
      withData: true,
    );
    final file = picked?.files.first;
    if (file?.bytes == null) return;
    final table = AttendanceImport.parse(file!.bytes!);
    setState(() {
      _fileName = file.name;
      _table = table;
      _codeCol = table.codeColumn;
      _dateTimeCol = table.dateTimeColumn;
      _timeCol = table.timeColumn;
      _result = null;
      _error = table.rows.isEmpty ? 'ไม่พบข้อมูลในไฟล์' : null;
    });
  }

  (List<ScanRow>, int)? get _scans {
    final t = _table;
    if (t == null || _codeCol == null || _dateTimeCol == null) return null;
    return AttendanceImport.toScans(t,
        codeColumn: _codeCol!,
        dateTimeColumn: _dateTimeCol!,
        timeColumn: _timeCol);
  }

  Future<void> _upload(List<ScanRow> scans) async {
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final result = await AttendanceImport.upload(_client, scans,
          onProgress: (done) {
        if (mounted) setState(() => _progress = done);
      });
      if (!mounted) return;
      setState(() {
        _result = result;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'นำเข้าไม่สำเร็จ: ${e is PostgrestException ? e.message : e}';
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _scans;
    final scans = parsed?.$1 ?? const <ScanRow>[];
    final invalid = parsed?.$2 ?? 0;
    final unknownCodes = scans
        .map((s) => s.code)
        .where((c) => !_nameByCode.containsKey(c))
        .toSet();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('นำเข้าเวลาสแกนจากไฟล์',
              style: GoogleFonts.sarabun(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 4),
          Text(
              'export ไฟล์จากเครื่องสแกนหน้า (CSV / TXT / DAT) แล้วเลือกที่นี่ — '
              'นำเข้าไฟล์เดิมซ้ำได้ ระบบไม่บันทึกเบิ้ล\n'
              'ถ้าเครื่อง export เป็น Excel ให้เปิดใน Excel แล้ว "บันทึกเป็น CSV" ก่อน',
              style: GoogleFonts.sarabun(fontSize: 13, color: _muted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _ink),
                onPressed: _uploading ? null : _pickFile,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('เลือกไฟล์'),
              ),
              if (_fileName != null)
                Text(_fileName!,
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
              Text('ครูที่มีรหัสในเครื่องแล้ว ${_nameByCode.length} คน',
                  style: GoogleFonts.sarabun(fontSize: 13, color: _muted)),
            ],
          ),
          if (_error != null) _banner(_error!, Colors.red),
          if (_result != null) _buildResult(_result!),
          if (_table != null && _table!.rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildColumnPickers(),
            const SizedBox(height: 16),
            if (parsed == null)
              _banner('เลือกคอลัมน์รหัสพนักงานและวันเวลาก่อน', Colors.orange)
            else ...[
              _buildSummary(scans, invalid, unknownCodes),
              const SizedBox(height: 12),
              _buildPreview(scans),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                    ),
                    onPressed: _uploading || scans.isEmpty
                        ? null
                        : () => _upload(scans),
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(
                        _uploading
                            ? 'กำลังนำเข้า $_progress / ${scans.length}'
                            : 'นำเข้า ${scans.length} รายการ',
                        style:
                            GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildColumnPickers() {
    final t = _table!;
    DropdownMenuItem<int?> item(int? i) => DropdownMenuItem(
        value: i,
        child: Text(i == null ? '— ไม่มี —' : t.header[i],
            overflow: TextOverflow.ellipsis));
    Widget picker(String label, int? value, ValueChanged<int?> onChanged,
            {bool optional = false}) =>
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<int?>(
            // initialValue อ่านครั้งเดียว — เปลี่ยน key เมื่อเลือกไฟล์ใหม่ให้รีเซ็ตตาม
            key: ValueKey('$label|$_fileName|$value'),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              if (optional) item(null),
              for (var i = 0; i < t.columnCount; i++) item(i),
            ],
            onChanged: _uploading ? null : onChanged,
          ),
        );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        picker('รหัสพนักงาน (User ID)', _codeCol,
            (v) => setState(() => _codeCol = v)),
        picker(_timeCol == null ? 'วันเวลาที่สแกน' : 'วันที่', _dateTimeCol,
            (v) => setState(() => _dateTimeCol = v)),
        picker('เวลา (ถ้าแยกช่องกับวันที่)', _timeCol,
            (v) => setState(() => _timeCol = v),
            optional: true),
      ],
    );
  }

  Widget _buildSummary(
      List<ScanRow> scans, int invalid, Set<String> unknownCodes) {
    String d(DateTime t) => '${t.day}/${t.month}/${t.year + 543}';
    final range = scans.isEmpty
        ? '-'
        : '${d(scans.first.localTime)} – ${d(scans.last.localTime)}';
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _chip('อ่านได้ ${scans.length} รายการ', const Color(0xFF16A34A)),
        _chip('ช่วงวันที่ $range', const Color(0xFF2563EB)),
        if (invalid > 0)
          _chip('อ่านไม่ได้ $invalid แถว (ข้าม)', Colors.red),
        if (unknownCodes.isNotEmpty)
          Tooltip(
            message: unknownCodes.take(30).join(', '),
            child: _chip(
                'รหัสที่ยังไม่จับคู่กับครู ${unknownCodes.length} รหัส — '
                'นำเข้าได้ ไปจับคู่ที่ web ทีหลัง',
                Colors.orange),
          ),
      ],
    );
  }

  Widget _buildPreview(List<ScanRow> scans) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final s in scans.take(10))
            ListTile(
              dense: true,
              leading: Text(s.code,
                  style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold)),
              title: Text(_nameByCode[s.code] ?? 'ยังไม่จับคู่',
                  style: GoogleFonts.sarabun(
                      color: _nameByCode.containsKey(s.code)
                          ? _ink
                          : Colors.orange)),
              trailing: Text(
                  '${s.localTime.day}/${s.localTime.month}/${s.localTime.year + 543}  '
                  '${two(s.localTime.hour)}:${two(s.localTime.minute)}:${two(s.localTime.second)}',
                  style: GoogleFonts.sarabun()),
            ),
          if (scans.length > 10)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('… และอีก ${scans.length - 10} รายการ',
                  style: GoogleFonts.sarabun(color: _muted)),
            ),
        ],
      ),
    );
  }

  Widget _buildResult(ImportResult r) => _banner(
      'นำเข้าแล้ว ${r.inserted} รายการ'
      '${r.duplicates > 0 ? ' · ข้ามที่มีอยู่แล้ว ${r.duplicates}' : ''}'
      '${r.unmatched > 0 ? ' · ยังไม่จับคู่กับครู ${r.unmatched} (จับคู่ที่ web)' : ''}',
      const Color(0xFF16A34A));

  Widget _banner(String text, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: GoogleFonts.sarabun(color: color)),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: GoogleFonts.sarabun(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      );
}
