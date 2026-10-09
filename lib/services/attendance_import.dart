import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════
// นำเข้าเวลาสแกนจากไฟล์ที่ export จากเครื่องสแกนหน้า
// (CSV / TXT / DAT — คั่นด้วย , ; หรือ tab) → ตาราง AttendanceLogs
//
// เครื่องแต่ละยี่ห้อ export คอลัมน์ไม่เหมือนกัน จึงเดาคอลัมน์ให้ก่อน
// แล้วให้แอดมินเลือกเองได้ในหน้าตัวอย่าง:
//   - รหัสพนักงาน (ตรงกับ Teachers.device_code)
//   - วันเวลา ในช่องเดียว หรือแยก "วันที่" กับ "เวลา" คนละช่อง
//
// เวลาในไฟล์ถือเป็นเวลาไทยเสมอ ส่งเข้าฐานข้อมูลพร้อม +07:00
// การกันข้อมูลซ้ำ/จับคู่รหัสกับครู ทำในฐานข้อมูล (supabase/attendance.sql)
// ═══════════════════════════════════════════════════════════════

/// ตารางที่อ่านจากไฟล์ + คอลัมน์ที่เดาไว้
class ParsedTable {
  final List<String> header;
  final List<List<String>> rows;
  final int? codeColumn;
  final int? dateTimeColumn;
  final int? timeColumn; // มีค่าเมื่อวันที่กับเวลาอยู่คนละช่อง

  const ParsedTable({
    required this.header,
    required this.rows,
    this.codeColumn,
    this.dateTimeColumn,
    this.timeColumn,
  });

  int get columnCount => header.length;
}

/// 1 การสแกนที่อ่านได้ (เวลาไทย ไม่มีโซน)
class ScanRow {
  final String code;
  final DateTime localTime;
  const ScanRow(this.code, this.localTime);
}

class ImportResult {
  final int sent;
  final int inserted;
  final int unmatched;
  const ImportResult(
      {required this.sent, required this.inserted, required this.unmatched});
  int get duplicates => sent - inserted;
}

class AttendanceImport {
  static const _chunkSize = 500;

  // ─── อ่านไฟล์ ───────────────────────────────────────────────

  static ParsedTable parse(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    final lines = const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const ParsedTable(header: [], rows: []);

    final delimiter = _detectDelimiter(lines.take(20).toList());
    var rows = lines.map((l) => _splitLine(l, delimiter)).toList();

    // แถวแรกเป็นหัวตารางถ้าไม่มีช่องไหนอ่านเป็นวันที่ได้
    final firstHasDate = rows.first.any((c) => parseDate(c) != null);
    final width = rows.fold<int>(0, (w, r) => r.length > w ? r.length : w);
    final header = firstHasDate
        ? List.generate(width, (i) => 'คอลัมน์ ${i + 1}')
        : [
            for (var i = 0; i < width; i++)
              i < rows.first.length && rows.first[i].isNotEmpty
                  ? rows.first[i]
                  : 'คอลัมน์ ${i + 1}'
          ];
    if (!firstHasDate) rows = rows.sublist(1);
    rows = [
      for (final r in rows) [...r, for (var i = r.length; i < width; i++) '']
    ];

    final guess = _guessColumns(rows.take(200).toList(), width);
    return ParsedTable(
      header: header,
      rows: rows,
      codeColumn: guess.code,
      dateTimeColumn: guess.dateTime,
      timeColumn: guess.time,
    );
  }

  /// แปลงตารางเป็นรายการสแกนตามคอลัมน์ที่เลือก
  /// คืน (แถวที่อ่านได้, จำนวนแถวที่อ่านไม่ได้)
  static (List<ScanRow>, int) toScans(ParsedTable table,
      {required int codeColumn, required int dateTimeColumn, int? timeColumn}) {
    final scans = <ScanRow>[];
    final seen = <String>{};
    var invalid = 0;
    for (final row in table.rows) {
      final code = row[codeColumn].trim();
      final raw = timeColumn == null
          ? row[dateTimeColumn]
          : '${row[dateTimeColumn]} ${row[timeColumn]}';
      final time = parseDateTime(raw);
      if (code.isEmpty || code.length > 50 || time == null) {
        invalid++;
        continue;
      }
      if (seen.add('$code|${time.toIso8601String()}')) {
        scans.add(ScanRow(code, time));
      }
    }
    scans.sort((a, b) => a.localTime.compareTo(b.localTime));
    return (scans, invalid);
  }

  // ─── บันทึก ─────────────────────────────────────────────────

  /// ส่งเข้า AttendanceLogs ทีละชุด — แถวที่มีอยู่แล้วถูกข้าม (ไม่เบิ้ล)
  static Future<ImportResult> upload(
      SupabaseClient client, List<ScanRow> scans,
      {void Function(int done)? onProgress}) async {
    var inserted = 0;
    var unmatched = 0;
    for (var i = 0; i < scans.length; i += _chunkSize) {
      final chunk = scans.skip(i).take(_chunkSize);
      final rows = await client
          .from('AttendanceLogs')
          .upsert(
            [
              for (final s in chunk)
                {
                  'device_code': s.code,
                  'scanned_at': toBangkokIso(s.localTime),
                  'source': 'import',
                }
            ],
            onConflict: 'id_school,id_user,device_code,scanned_at',
            ignoreDuplicates: true,
          )
          .select('id_user');
      inserted += rows.length;
      unmatched += rows.where((r) => r['id_user'] == null).length;
      onProgress?.call(i + chunk.length);
    }
    return ImportResult(
        sent: scans.length, inserted: inserted, unmatched: unmatched);
  }

  /// เวลาไทย → '2026-10-09T07:45:12+07:00'
  static String toBangkokIso(DateTime local) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${p(local.month)}-${p(local.day)}'
        'T${p(local.hour)}:${p(local.minute)}:${p(local.second)}+07:00';
  }

  // ─── อ่านวันที่ / เวลา ───────────────────────────────────────

  static final _ymd = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})');
  static final _dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})');
  static final _time = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?\s*$');

  /// วันที่อย่างเดียว: 2026-10-09 / 9/10/2569 (วัน/เดือน/ปี แบบไทย, พ.ศ. ได้)
  static DateTime? parseDate(String raw) {
    final text = raw.trim();
    int y, m, d;
    final a = _ymd.firstMatch(text);
    final b = _dmy.firstMatch(text);
    if (a != null) {
      y = int.parse(a[1]!);
      m = int.parse(a[2]!);
      d = int.parse(a[3]!);
    } else if (b != null) {
      d = int.parse(b[1]!);
      m = int.parse(b[2]!);
      y = int.parse(b[3]!);
    } else {
      return null;
    }
    if (y > 2400) y -= 543;
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000) return null;
    final date = DateTime(y, m, d);
    return date.month == m ? date : null; // กัน 31/02
  }

  /// วันเวลา: วันที่ตามด้านบน + เวลา HH:MM[:SS] [AM/PM]
  static DateTime? parseDateTime(String raw) {
    final text = raw.trim().replaceFirst('T', ' ');
    final date = parseDate(text);
    final t = _time.firstMatch(text);
    if (date == null || t == null) return null;
    var h = int.parse(t[1]!);
    final min = int.parse(t[2]!);
    final s = int.tryParse(t[3] ?? '') ?? 0;
    final ampm = t[4]?.toLowerCase();
    if (ampm == 'pm' && h < 12) h += 12;
    if (ampm == 'am' && h == 12) h = 0;
    if (h > 23 || min > 59 || s > 59) return null;
    return DateTime(date.year, date.month, date.day, h, min, s);
  }

  static bool _isTimeOnly(String raw) =>
      RegExp(r'^\d{1,2}:\d{2}(:\d{2})?\s*([AaPp][Mm])?$').hasMatch(raw.trim());

  // ─── ตัวช่วย ────────────────────────────────────────────────

  static String _detectDelimiter(List<String> lines) {
    var best = ',';
    var bestScore = 0;
    for (final d in ['\t', ',', ';']) {
      final counts = lines.map((l) => d.allMatches(l).length).toList();
      final min = counts.reduce((a, b) => a < b ? a : b);
      if (min > bestScore) {
        best = d;
        bestScore = min;
      }
    }
    return best;
  }

  /// แยกช่องตามตัวคั่น รองรับ "ข้อความในเครื่องหมายคำพูด"
  static List<String> _splitLine(String line, String delimiter) {
    final cells = <String>[];
    final buf = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (c == delimiter && !quoted) {
        cells.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    cells.add(buf.toString().trim());
    return cells;
  }

  static ({int? code, int? dateTime, int? time}) _guessColumns(
      List<List<String>> sample, int width) {
    if (sample.isEmpty) return (code: null, dateTime: null, time: null);
    double ratio(int col, bool Function(String) test) =>
        sample.where((r) => test(r[col])).length / sample.length;

    int? best(bool Function(String) test, {Set<int> skip = const {}}) {
      int? pickCol;
      var pickRatio = 0.6;
      for (var c = 0; c < width; c++) {
        if (skip.contains(c)) continue;
        final r = ratio(c, test);
        if (r > pickRatio) {
          pickCol = c;
          pickRatio = r;
        }
      }
      return pickCol;
    }

    int? dateTime = best((v) => parseDateTime(v) != null);
    int? time;
    if (dateTime == null) {
      dateTime = best((v) => parseDate(v) != null);
      if (dateTime != null) time = best(_isTimeOnly, skip: {dateTime});
      if (time == null) dateTime = null;
    }

    // รหัสพนักงาน: ตัวเลข/ตัวอักษรสั้น ๆ ไม่ใช่วันที่ — เลือกคอลัมน์แรกที่เข้าเกณฑ์
    final used = {if (dateTime != null) dateTime, if (time != null) time};
    int? code;
    for (var c = 0; c < width && code == null; c++) {
      if (used.contains(c)) continue;
      if (ratio(c, (v) => RegExp(r'^[A-Za-z0-9_-]{1,20}$').hasMatch(v.trim()) &&
              parseDate(v) == null) >
          0.8) {
        code = c;
      }
    }
    return (code: code, dateTime: dateTime, time: time);
  }
}
