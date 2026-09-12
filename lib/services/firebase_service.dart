import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

class FirebaseService {
  static Map<String, String> _configCache = {};
  static bool _configLoaded = false;

  static SupabaseClient? get _supabaseIfReady {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient? get supabaseClient => _supabaseIfReady;

  // แปลงข้อมูล Firebase → รูปแบบที่ Supabase รับได้
  // (key เป็น lowercase, FieldValue/Timestamp → ISO string)
  static Map<String, dynamic> _toSupabaseRecord(
      Map<String, dynamic> data, String docId) {
    final record = <String, dynamic>{'id': docId};
    data.forEach((key, value) {
      record[key.toLowerCase()] = _toSupabaseValue(value);
    });
    return record;
  }

  static dynamic _toSupabaseValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is List) return value.map(_toSupabaseValue).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toSupabaseValue(v)));
    }
    if (value is bool || value is num || value is String) return value;
    return value.toString();
  }

  // Upsert ไป Supabase แบบตัดคอลัมน์ที่ไม่มีในตารางออกแล้วลองใหม่
  static Future<void> _supabaseUpsert(
      String table, Map<String, dynamic> record) async {
    final client = _supabaseIfReady;
    if (client == null) {
      debugPrint('⚠️  Supabase is not initialized; skip sync for $table');
      return;
    }

    final rec = Map<String, dynamic>.from(record);

    // userroles: uid เป็น NOT NULL และคือ doc id
    if (table == 'userroles') {
      rec.putIfAbsent('uid', () => rec['id']);
    }
    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        await client.from(table).upsert(rec, onConflict: 'id');
        return;
      } on PostgrestException catch (e) {
        final match =
            RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
        if (match != null && rec.containsKey(match.group(1))) {
          rec.remove(match.group(1));
          continue;
        }
        rethrow;
      }
    }
  }

  // 🚀 Supabase-only write (ห้ามเขียน Firebase — production hosting ใช้อยู่)
  Future<void> _supabaseSet(
    String collectionName,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    try {
      await _supabaseUpsert(
          collectionName.toLowerCase(), _toSupabaseRecord(data, docId));
    } catch (e) {
      debugPrint('❌ Supabase write error in _supabaseSet ($collectionName): $e');
      rethrow;
    }
  }

  // 🚀 Supabase-only update (ห้ามเขียน Firebase — production hosting ใช้อยู่)
  Future<void> _supabaseUpdate(
    String collectionName,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _supabaseUpsert(
          collectionName.toLowerCase(), _toSupabaseRecord(data, docId));
    } catch (e) {
      debugPrint('❌ Supabase write error in _supabaseUpdate ($collectionName): $e');
      rethrow;
    }
  }

  // 🚀 Supabase-only add (ห้ามเขียน Firebase — production hosting ใช้อยู่)
  Future<String> _supabaseAdd(
    String collectionName,
    Map<String, dynamic> data,
  ) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized; cannot add to $collectionName');
    final prefix = collectionName.length >= 2
        ? collectionName.substring(0, 2).toUpperCase()
        : collectionName.toUpperCase();
    final docId = '$prefix-${DateTime.now().millisecondsSinceEpoch}';
    try {
      final record = _toSupabaseRecord(data, docId);
      await client.from(collectionName.toLowerCase()).insert(record);
      return docId;
    } catch (e) {
      debugPrint('❌ Supabase insert error ($collectionName): $e');
      rethrow;
    }
  }

  // 🚀 โหลด config จาก Supabase (ตาราง Settings) — Supabase แตกเป็นหลายแถว
  // จึง merge ค่าที่ไม่ใช่ null จากทุกแถวเข้าเป็น key/value เดียว
  Future<void> ensureConfigLoaded() async {
    if (_configLoaded) return;
    try {
      final client = _supabaseIfReady;
      if (client != null) {
        final rows = await client.from('Settings').select();
        final merged = <String, String>{};
        for (final row in (rows as List)) {
          (row as Map).forEach((k, v) {
            if (v != null && v is! Map && v is! List) {
              merged[k.toString()] = v.toString();
            }
          });
        }
        _configCache = merged;
      }
    } catch (e) {
      debugPrint('Failed to load config from Supabase Settings: $e');
    }
    _configLoaded = true;
  }

  static String config(String key) => _configCache[key] ?? '';

  static String get secretKey => config('secretKey');
  static String get appsScriptUrl => config('appsScriptUrl');
  static String get driveProfileFolderId => config('driveProfileFolderId');
  static String get driveLeaveFolderId => config('driveLeaveFolderId');

  static bool isLikelyAppsScriptWebAppUrl(String value) {
    return RegExp(r'^https:\/\/script\.google\.com\/macros\/s\/[^\s\/]+\/exec$')
        .hasMatch(value.trim());
  }

  Future<Map<String, dynamic>> getLineMessagingSettings() async {
    return getLineMessagingSettingsFromSupabase();
  }

  String _appsScriptUrlFromSettings(Map<String, dynamic> settings) {
    final savedUrl = (settings['webhookUrl'] ?? '').toString().trim();
    if (isLikelyAppsScriptWebAppUrl(savedUrl)) return savedUrl;
    final fallback = appsScriptUrl;
    return isLikelyAppsScriptWebAppUrl(fallback) ? fallback : savedUrl;
  }

  Future<String> getAppsScriptUrl() async {
    await ensureConfigLoaded();
    return _appsScriptUrlFromSettings(await getLineMessagingSettings());
  }

  String _buildAppsScriptGetUrl(
    String baseUrl,
    Map<String, String> queryParameters,
  ) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParameters,
    }).toString();
  }

  static String generateResetCode() {
    final random = DateTime.now().microsecondsSinceEpoch;
    final code = ((random % 900000) + 100000).toString();
    return code;
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return Stream.fromFuture(getUsersFromSupabase());
  }

  Stream<List<Map<String, dynamic>>> getUsersStreamFromSupabase() {
    return Stream.fromFuture(getUsersFromSupabase());
  }

  // ดึงรายชื่อครูแบบครั้งเดียว — อ่านจาก Supabase
  Future<List<Map<String, dynamic>>> getUsers() async {
    return getUsersFromSupabase();
  }

  // เพิ่มรายชื่อครูคนใหม่ลงฐานข้อมูลครับ 🏎️🏆
  Future<void> addUser(Map<String, dynamic> data) async {
    await _supabaseAdd('Teachers', data);
  }

  // แก้ไขข้อมูลครูครับ 🏎️🏆
  Future<void> updateUser(String docId, Map<String, dynamic> data) async {
    await _supabaseUpdate('Teachers', docId, data);
  }

  // 🚀 ลบข้อมูลครู (Supabase-only)
  Future<void> deleteUser(String docId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from('teachers').delete().eq('id', docId);
  }

  // ดึงตำแหน่งงานบริหาร — Supabase
  Future<List<String>> getAdminRoles() async {
    return getAdminRolesFromSupabase();
  }

  // ดึงตำแหน่งงานทั่วไป — Supabase
  Future<List<String>> getPositions() async {
    return getPositionsFromSupabase();
  }

  // ดึงสิทธิ์การเข้าถึง (Roles) — Supabase
  Future<List<String>> getPermissions() async {
    return getPermissionsFromSupabase();
  }

  // ดึงวิทยฐานะ — Supabase
  Future<List<String>> getAcademics() async {
    return getAcademicsFromSupabase();
  }

  // ดึงประเภทการลา — Supabase
  Future<List<String>> getLeaveTypes() async {
    return getLeaveTypesFromSupabase();
  }

  // ดึงกลุ่มสาระการเรียนรู้ — Supabase
  Future<List<String>> getDepartments() async {
    return getDepartmentsFromSupabase();
  }

  // ดึงรายการวิชาที่สอนจาก Supabase
  Future<List<String>> getSubjects() async {
    return getSubjectsFromSupabase();
  }

  Future<List<String>> getSubjectsFromSupabase() async {
    return _getMasterListFromSupabase(
        'subjects', ['subjectname', 'name', 'value', 'subject', 'วิชา']);
  }

  // 📅 ระบบจัดการรอบงบประมาณ (Fiscal Rounds) 🥇🏆
  Stream<List<Map<String, dynamic>>> getFiscalRoundsStream() {
    return Stream.fromFuture(getFiscalRoundsFromSupabase());
  }

  Future<void> addFiscalRound(Map<String, dynamic> data) async {
    await _supabaseAdd('FiscalRounds', {
      ...data,
      'isActive': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // 🚀 ลบรอบงบประมาณ (Supabase-only)
  Future<void> deleteFiscalRound(String docId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from('fiscalrounds').delete().eq('id', docId);
  }

  // ดึงรายการรอบงบประมาณที่ตรงกับปฏิทินปัจจุบัน (Auto-match) — Supabase
  Future<Map<String, dynamic>?> getActiveFiscalRound() async {
    return getActiveFiscalRoundFromSupabase();
  }

  // ดึงรายการรอบงบประมาณทั้งหมด — Supabase
  Future<List<Map<String, dynamic>>> getFiscalRounds() async {
    return getFiscalRoundsFromSupabase();
  }

  // 🛠️ ฟังก์ชันช่วยตรวจสอบว่าวันที่อยู่ในช่วงงบประมาณหรือไม่ (รูปแบบ วว/ดด/ปปปป) 🥇
  static bool isDateInRange(String dateStr, String startStr, String endStr) {
    try {
      if (dateStr.isEmpty || startStr.isEmpty || endStr.isEmpty) return false;

      DateTime parse(String s) {
        // 🕵️‍♂️ ตัดช่องว่างและจัดการรูปแบบที่ซับซ้อนครับ 🥇🏆
        final cleanS = s.trim().replaceAll(' ', '');
        final p = cleanS.split('/');
        if (p.length != 3) throw Exception('Invalid date format: $s');

        int year = int.parse(p[2]);
        // 🛡️ ระบบตรวจจับปีอัตโนมัติ: ถ้า < 2400 ให้ถือว่าเป็น ค.ศ. แล้วบวก 543 เพื่อเทียบเป็น พ.ศ. ทั้งหมดครับ 🕵️‍♂️🥇
        if (year < 2400) year += 543;

        return DateTime(year, int.parse(p[1]), int.parse(p[0]));
      }

      final date = parse(dateStr);
      final start = parse(startStr);
      final end = parse(endStr);

      // 🛡️ ปรับเวลาเป็น 00:00 - 23:59 เพื่อความแม่นยำในการเปรียบเทียบข้ามวันครับ 🥇🏆
      final d = DateTime(date.year, date.month, date.day);
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);

      return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
          (d.isAtSameMomentAs(e) || d.isBefore(e));
    } catch (e) {
      debugPrint(
          "isDateInRange Error: $e (input: $dateStr, range: $startStr - $endStr)");
      return false;
    }
  }

  // 🛠️ ฟังก์ชันพาร์สวันที่แบบรวดเร็ว เพื่อลดการสร้าง Object ซ้ำซ้อนครับ 🏎️🏆
  static DateTime? parseFast(String s) {
    try {
      final cleanS = s.trim().replaceAll(' ', '');
      final p = cleanS.split('/');
      if (p.length != 3) return null;
      int year = int.parse(p[2]);
      if (year < 2400) year += 543;
      return DateTime(year, int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseLeaveDateValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? leaveCreatedDate(Map<String, dynamic> leave) {
    return _parseLeaveDateValue(leave['createdAt']);
  }

  static int _leaveStatusWeight(String status) {
    if (status.contains('รอ') || status.contains('พิจารณา')) return 0;
    if (status.contains('ส่งใบ') ||
        status.contains('อนุมัติ') ||
        status.contains('อนุญาต')) {
      return 1;
    }
    if (status.contains('ยังไม่ส่ง') || status.contains('ไม่อนุญาต')) return 2;
    return 3;
  }

  static int compareLeaveRecency(
      Map<String, dynamic> a, Map<String, dynamic> b) {
    final dateA = leaveCreatedDate(a);
    final dateB = leaveCreatedDate(b);
    if (dateA != null && dateB != null) {
      final dateCompare = dateB.compareTo(dateA);
      if (dateCompare != 0) return dateCompare;
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }

    final statusCompare = _leaveStatusWeight((a['status'] ?? '').toString())
        .compareTo(_leaveStatusWeight((b['status'] ?? '').toString()));
    if (statusCompare != 0) return statusCompare;

    return (b['requestId'] ?? b['id'] ?? '')
        .toString()
        .compareTo((a['requestId'] ?? a['id'] ?? '').toString());
  }

  static String formatLeaveDayCount(dynamic value) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (number == null) return '-';
    return number % 1 == 0 ? number.toInt().toString() : number.toString();
  }

  static bool isHalfDayLeave(Map<String, dynamic> leave) {
    final raw = leave['isHalfDay'];
    if (raw is bool) return raw;
    return raw?.toString().toLowerCase() == 'true';
  }

  static String halfDayPeriodText(dynamic value) {
    final period = value?.toString().toLowerCase() ?? '';
    if (period == 'morning') return 'ครึ่งเช้า';
    if (period == 'afternoon') return 'ครึ่งบ่าย';
    return 'ครึ่งวัน';
  }

  static String leaveTypeWithHalfDay(Map<String, dynamic> leave) {
    final type = (leave['leaveType'] ?? 'ไม่ระบุ').toString();
    if (!isHalfDayLeave(leave)) return type;
    return '$type (${halfDayPeriodText(leave['halfDayPeriod'])})';
  }

  // 🛠️ รวมข้อมูลรอบงบประมาณ ข้อมูลใบลา และประเภทการลาจาก Supabase 🥇🏆🏎️
  Future<Map<String, dynamic>> getDashboardDataFromSupabase() async {
    final results = await Future.wait([
      getFiscalRoundsFromSupabase(),
      getLeaveRequestsFromSupabase(),
      getLeaveTypesRawFromSupabase(),
    ]);
    return {
      'rounds': results[0],
      'allLeaves': results[1],
      'leaveTypes': results[2],
    };
  }

  Stream<Map<String, dynamic>> getDashboardDataStream() {
    return Stream.fromFuture(getDashboardDataFromSupabase());
  }

  // ดึงประเภทการลาทั้งหมดจากฐานข้อมูลครับ 🕵️‍♂️🏎️🏆
  Stream<List<Map<String, dynamic>>> getLeaveTypesStream() {
    return Stream.fromFuture(getLeaveTypesRawFromSupabase());
  }

  // ดึงประวัติการลาแบบเรียลไทม์จาก Supabase
  Stream<List<Map<String, dynamic>>> getLeaveRequestsStream({int? year}) {
    return Stream.fromFuture(getLeaveRequestsFromSupabase(year: year));
  }

  Future<List<Map<String, dynamic>>> getLeaveRequests({int? year}) async {
    return getLeaveRequestsFromSupabase(year: year);
  }

  Stream<List<Map<String, dynamic>>> getMyLeaveRequestsStream(String fullName) {
    return Stream.fromFuture(getMyLeaveRequestsFromSupabase(fullName));
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequests(String fullName) async {
    return getMyLeaveRequestsFromSupabase(fullName);
  }

  // ดึงประวัติการลา "ล่าสุด" ของครู — Supabase
  Future<Map<String, dynamic>?> getLastLeaveRequest(String fullName) async {
    return getLastLeaveRequestFromSupabase(fullName);
  }

  // 🚀 ล้างเลขรับทั้งหมด (Supabase-only)
  Future<void> clearAllReceiveNumbers() async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client
        .from('leaves')
        .update({'receivenumber': null, 'receivedate': null, 'receivetime': null})
        .not('receivenumber', 'is', null);
  }

  // 🚀 ส่งใบลาเข้าระบบ (Supabase-only) 🏎️🏁
  Future<void> submitLeaveRequest(Map<String, dynamic> data) async {
    final String docId = 'LV-${DateTime.now().millisecondsSinceEpoch}';
    await _supabaseSet('Leaves', docId, {
      ...data,
      // ตัด uid/currentUid ออก — เลิกพึ่ง FirebaseAuth
      'requestId': docId,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'รอพิจารณา',
    });
  }

  // แก้ไขใบลาครับ 🏎️🏁
  Future<void> updateLeaveRequest(
      String requestId, Map<String, dynamic> data) async {
    await _supabaseUpdate('Leaves', requestId, {
      ...data,
      'lastUpdatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // 🚀 นับเลขรับจาก Supabase
  Future<int> generateReceiveNumber() async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    final fiscalYear = DateTime.now().year + 543;
    final rows = await client
        .from('leaves')
        .select('receivenumber')
        .eq('year', fiscalYear)
        .not('receivenumber', 'is', null);
    return (rows as List).length + 1;
  }

  // 🔥 ลบไฟล์ใน Google Drive ผ่าน Apps Script ครับ 🥇🏆🏎️
  Future<Map<String, dynamic>> uploadDriveFile({
    required String fileData,
    required String fileName,
    required String mimeType,
    required String folderType,
    String? folderId,
  }) async {
    final bridgeUrl = await getAppsScriptUrl();
    final response = await http
        .post(
          Uri.parse(bridgeUrl),
          body: jsonEncode({
            'action': 'upload',
            'folderType': folderType,
            'folderId': folderId ??
                (folderType == 'profile'
                    ? driveProfileFolderId
                    : driveLeaveFolderId),
            'fileName': fileName,
            'name': fileName,
            'mimeType': mimeType,
            'file64': _stripDataUrlPrefix(fileData),
            'secretKey': secretKey,
          }),
        )
        .timeout(const Duration(minutes: 2));

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Drive upload failed with status ${response.statusCode}');
    }

    final resData = jsonDecode(response.body) as Map<String, dynamic>;
    if (resData['status'] != 'success' ||
        (resData['url']?.toString().isEmpty ?? true)) {
      throw Exception(resData['message'] ?? 'Drive upload failed');
    }

    return resData;
  }

  String _stripDataUrlPrefix(String value) {
    const marker = 'base64,';
    final index = value.indexOf(marker);
    if (index == -1) return value;
    return value.substring(index + marker.length);
  }

  Future<bool> deleteDriveFileStrict(String? fileUrlOrId) async {
    final source = fileUrlOrId?.trim() ?? '';
    if (source.isEmpty) return false;

    final fileId = _extractDriveFileId(source);
    if (fileId == null) {
      var checkSource = source.toLowerCase();
      try {
        checkSource = Uri.decodeFull(checkSource);
      } catch (_) {
        // Keep the original value when it is not URI-encoded.
      }

      final looksLikeDriveUrl = checkSource.contains('drive.google.com') ||
          checkSource.contains('googleusercontent.com');
      if (looksLikeDriveUrl) {
        throw Exception('Cannot find Google Drive file ID from URL');
      }
      return false;
    }

    final bridgeUrl = await getAppsScriptUrl();
    final response = await http
        .post(
          Uri.parse(bridgeUrl),
          body: jsonEncode({
            'action': 'delete',
            'fileId': fileId,
            'secretKey': secretKey,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Drive delete failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Drive delete returned an invalid response');
    }

    final resData = Map<String, dynamic>.from(decoded);
    if (resData['status'] != 'success') {
      throw Exception(resData['message'] ?? 'Drive delete failed');
    }

    debugPrint("Drive Delete Result: ${resData['status']} ($fileId)");
    return true;
  }

  String? _extractDriveFileId(String value) {
    var source = value.trim();
    if (source.isEmpty) return null;

    final rawId = RegExp(r'^[a-zA-Z0-9_-]{20,}$');
    if (!source.contains('/') &&
        !source.contains('?') &&
        !source.contains('&') &&
        !source.contains('=') &&
        rawId.hasMatch(source)) {
      return source;
    }

    try {
      source = Uri.decodeFull(source);
    } catch (_) {
      // Keep the original value when it is not URI-encoded.
    }

    final uri = Uri.tryParse(source);
    final queryId = uri?.queryParameters['id'];
    if (queryId != null && rawId.hasMatch(queryId)) {
      return queryId;
    }

    final patterns = [
      RegExp(r'/d/([a-zA-Z0-9_-]{20,})'),
      RegExp(r'[?&]id=([a-zA-Z0-9_-]{20,})'),
      RegExp(r'googleusercontent\.com/d/([a-zA-Z0-9_-]{20,})'),
      RegExp(r'id%3D([a-zA-Z0-9_-]{20,})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(source);
      final fileId = match?.group(1);
      if (fileId != null && rawId.hasMatch(fileId)) {
        return fileId;
      }
    }

    return null;
  }

  Future<void> deleteDriveFile(String? fileUrl) async {
    if (fileUrl == null ||
        fileUrl.isEmpty ||
        !fileUrl.contains('drive.google.com')) return;

    final fileId = _extractFileId(fileUrl);
    if (fileId == null) return;

    try {
      final bridgeUrl = await getAppsScriptUrl();
      final response = await http.post(
        Uri.parse(bridgeUrl),
        body: jsonEncode({
          'action': 'delete',
          'fileId': fileId,
          'secretKey': secretKey, // 🛡️ แนบรหัสลับไปด้วยครับ (Phase 4) 🥇🏆
        }),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        print("Drive Delete Result: ${resData['status']}");
      }
    } catch (e) {
      print("Error deleting drive file: $e");
    }
  }

  // Helper สำหรับแคะ ID ออกจากลิ้งครับ 🕵️‍♂️
  String? _extractFileId(String url) {
    RegExp regExp = RegExp(r'(?:id=|\/d\/)([a-zA-Z0-9-_]+)');
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }

  static String formatThaiDate(dynamic dateValue) {
    if (dateValue == null || dateValue == "") return '-';

    DateTime? date;
    if (dateValue is DateTime) {
      date = dateValue;
    } else if (dateValue is String) {
      try {
        final parts = dateValue.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 2100)
            year += 543; // 🛡️ รองรับกรณีฐานข้อมูลดันเก็บเป็นปี ค.ศ. 🥇🏆
          date = DateTime(year - 543, month, day);
        }
      } catch (e) {
        return dateValue;
      }
    }

    if (date == null) return dateValue.toString();

    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  // 📲 ส่งแจ้งเตือนผ่าน LINE Messaging API แบบปลอดภัยสูง (Phase 4.8 Update) 🥇🏆🏎️
  Future<bool> sendLineNotification(Map<String, dynamic> leaveData) async {
    try {
      debugPrint("🔔 Starting LINE Notification process...");

      final settings = await getLineMessagingSettingsFromSupabase();
      final bridgeUrl = _appsScriptUrlFromSettings(settings);

      String to = (settings['groupId'] ?? '').toString().trim();
      String template = (settings['template'] ?? '').toString();
      debugPrint(
          "📍 Settings found: GroupID length=${to.length}, Template length=${template.length}");

      // 🛡️ Fallback: ถ้าในใบลาแนบ To มาให้ (เผื่ออนาคต) ให้ใช้ตัวนั้นครับ
      if (to.isEmpty && leaveData['to'] != null) to = leaveData['to'];

      if (to.isEmpty) {
        debugPrint(
            "❌ LINE Notification Aborted: No Group ID found. Please check Line Settings.");
        return false;
      }

      // 🕵️‍♂️ 2. สร้างข้อความ: ใช้ Template จากระบบ หรือใช้แบบ Standard ถ้าไม่ได้ตั้งค่าไว้ครับ 🥇🏆
      String msg = "";
      if (template.isNotEmpty) {
        msg = template
            .replaceAll('{name}',
                (leaveData['fullName'] ?? leaveData['name'] ?? '-').toString())
            .replaceAll('{type}', leaveData['leaveType'] ?? '-')
            .replaceAll('{startDate}', leaveData['startDate'] ?? '-')
            .replaceAll('{endDate}', leaveData['endDate'] ?? '-')
            .replaceAll('{days}', (leaveData['totalDays'] ?? '-').toString())
            .replaceAll('{reason}', leaveData['reason'] ?? '-');
        debugPrint("📝 Message generated from Template");
      } else {
        msg = "📋 แจ้งเตือนผลการพิจารณาใบลา\n"
            "👤 ชื่อ: ${leaveData['fullName'] ?? leaveData['name'] ?? '-'}\n"
            "📅 ประเภทลา: ${leaveData['leaveType'] ?? '-'}\n"
            "🗓️ ตั้งแต่: ${leaveData['startDate'] ?? '-'}\n"
            "🗓️ ถึง: ${leaveData['endDate'] ?? '-'}\n"
            "📆 จำนวน: ${leaveData['totalDays'] ?? '-'} วัน\n"
            "✍️ เหตุผล: ${leaveData['reason'] ?? '-'}";
        debugPrint("📝 Message generated from Standard layout");
      }

      // 📲 3. เตรียมส่งผ่าน Secure Bridge (Apps Script)
      final String url = _buildAppsScriptGetUrl(bridgeUrl, {
        'action': 'line_notification',
        'secretKey': FirebaseService.secretKey,
        'to': to,
        'message': msg,
      });

      if (kIsWeb) {
        // Mobile web/LINE browser can cancel fire-and-forget fetches. Await the
        // browser promise and fall back to an image beacon so the GET is flushed.
        final result = await _getWebJsonp(url);
        if (result['status'] != 'success') {
          debugPrint(
              "⚠️ Web fetch failed, retrying LINE notify via image beacon.");
          debugPrint(
              "LINE Notification failed: ${result['message'] ?? result}");
          return false;
        }
        debugPrint("🚀 LINE Notification triggered via Web Fetch (no-cors)");
        return true;
      } else {
        // 📱 บนมือถือ: ใช้ http.get ปกติ (ขยายเป็น 30 วินาที)
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        debugPrint("📱 LINE Notification status code: ${response.statusCode}");
        return response.statusCode >= 200 && response.statusCode < 400;
      }
    } catch (e) {
      debugPrint("❌ LINE Notification Critical Exception: $e");
      return false;
    }
  }

  Future<bool> _sendWebNoCorsGet(String url) async {
    try {
      final String jsCode = """
        fetch(${jsonEncode(url)}, {
          method: 'GET',
          mode: 'no-cors',
          cache: 'no-store',
          keepalive: true
        }).then(function() {
          return true;
        }).catch(function(e) {
          console.error('Notify Error:', e);
          return false;
        });
      """;
      final result = await (globalContext.callMethod<JSAny>('eval'.toJS, jsCode.toJS) as JSPromise)
          .toDart
          .timeout(const Duration(seconds: 12), onTimeout: () => false.toJS);
      return result == true.toJS;
    } catch (e) {
      debugPrint("❌ Web LINE fetch exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> _getWebJsonp(String url) async {
    final completer = Completer<String>();
    final callbackName = 'lineCb_${DateTime.now().microsecondsSinceEpoch}';
    final separator = url.contains('?') ? '&' : '?';
    final callbackUrl = '$url${separator}callback=$callbackName';

    globalContext[callbackName] = ((JSAny? data) {
      if (!completer.isCompleted) {
        completer.complete(data != null ? jsonEncode((data as JSObject).dartify()) : '{}');
      }
    }).toJS;

    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..src = callbackUrl
      ..async = true;

    script.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(jsonEncode({
          'status': 'error',
          'message': 'Cannot reach Apps Script',
        }));
      }
    });

    web.document.body?.append(script);

    Future.delayed(const Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        completer.complete(jsonEncode({
          'status': 'error',
          'message': 'Apps Script timeout',
        }));
      }
    });

    try {
      final result = await completer.future;
      final decoded = jsonDecode(result);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{'status': 'error', 'message': 'Invalid response'};
    } finally {
      globalContext[callbackName] = null;
      script.remove();
    }
  }

  Future<bool> _sendWebImageBeacon(String url) async {
    try {
      final String jsCode = """
        new Promise(function(resolve) {
          var img = new Image();
          var done = false;
          var finish = function(value) {
            if (!done) {
              done = true;
              resolve(value);
            }
          };
          img.onload = function() { finish(true); };
          img.onerror = function() { finish(true); };
          setTimeout(function() { finish(false); }, 12000);
          img.src = ${jsonEncode(url + '&_ts=${DateTime.now().millisecondsSinceEpoch}')};
        });
      """;
      final result = await (globalContext.callMethod<JSAny>('eval'.toJS, jsCode.toJS) as JSPromise)
          .toDart
          .timeout(const Duration(seconds: 13), onTimeout: () => false.toJS);
      return result == true.toJS;
    } catch (e) {
      debugPrint("❌ Web LINE image beacon exception: $e");
      return false;
    }
  }

  // 📲 ส่งแจ้งเตือนการ "เปลี่ยนสถานะ" เช่น อนุญาต/ไม่อนุญาต ไปที่ LINE กลุ่มครับ 🥇🏆🏎️
  Future<void> sendLineStatusNotification(
      Map<String, dynamic> leaveData, String newStatus) async {
    try {
      await ensureConfigLoaded();
      final settings = await getLineMessagingSettingsFromSupabase();
      final bridgeUrl = _appsScriptUrlFromSettings(settings);
      final to = (settings['groupId'] ?? '').toString().trim();
      if (to.isEmpty) return;

      // 📝 สร้างข้อความแจ้งการเปลี่ยนสถานะแบบพรีเมียมครับ 🥇🏆
      String msg = "🔔 อัพเดทสถานะใบลาครับ\n"
          "👤 ชื่อ: ${leaveData['fullName'] ?? '-'}\n"
          "📅 ประเภท: ${leaveData['leaveType'] ?? '-'}\n"
          "📍 สถานะใหม่: $newStatus\n"
          "📆 วันลา: ${leaveData['startDate']} - ${leaveData['endDate']}\n"
          "------------------\n"
          "ตรวจสอบรายละเอียดได้ในระบบครับ";

      final String url = _buildAppsScriptGetUrl(bridgeUrl, {
        'action': 'line_notification',
        'secretKey': FirebaseService.secretKey,
        'to': to,
        'message': msg,
      });

      if (kIsWeb) {
        final String jsCode =
            "fetch(${jsonEncode(url)}, {method:'GET', mode:'no-cors'}).catch(function(e){});";
        globalContext.callMethod<JSAny>('eval'.toJS, jsCode.toJS);
      } else {
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("❌ Status Notification Error: $e");
    }
  }

  // 👨‍🏫 อัปเดตข้อมูลบุคลากรด้วย ID (เร็วกว่าการหาด้วยชื่อครับ) 🥇🏆🏎️
  Future<void> updateTeacherById(
      String docId, Map<String, dynamic> newData) async {
    await _supabaseUpdate('Teachers', docId, newData);
  }

  Future<void> updateTeacherData(
      String fullName, Map<String, dynamic> newData) async {
    final client = _supabaseIfReady;
    if (client == null) return;
    final rows = await client
        .from('Teachers')
        .select('id')
        .eq('fullName', fullName)
        .limit(1);
    if ((rows as List).isNotEmpty) {
      await _supabaseUpdate('Teachers', rows.first['id'].toString(), newData);
    }
  }

  Future<Map<String, dynamic>?> searchTeacherByUid(String uid) async {
    final client = _supabaseIfReady;
    if (client == null) return null;
    final rows = await client
        .from('Teachers')
        .select()
        .eq('firebase_uid', uid)
        .limit(1);
    if ((rows as List).isNotEmpty) {
      return {...rows.first, 'docId': rows.first['id'].toString()};
    }
    return null;
  }

  Future<Map<String, dynamic>?> searchTeacherByName(String fullName) async {
    final client = _supabaseIfReady;
    if (client == null) return null;
    final rows = await client
        .from('Teachers')
        .select()
        .eq('fullName', fullName.trim())
        .limit(1);
    if ((rows as List).isNotEmpty) {
      return {...rows.first, 'docId': rows.first['id'].toString()};
    }
    return null;
  }

  // 🛡️ บันทึกประวัติการเข้าใช้งาน (Login Logging) 🥇🏆🏎️
  // 🚀 บันทึกประวัติการเข้าใช้งานลง Supabase (LoginLogs) เท่านั้น — ห้ามแตะ Firebase
  // (Firebase มี production hosting ใช้งานอยู่ จึงเขียนไม่ได้ทุกกรณี)
  // LoginLogs ฝั่ง Supabase ใช้ id_user (FK) ไม่ได้เก็บ username/fullName/role
  Future<void> logLogin(dynamic idUser) async {
    final client = _supabaseIfReady;
    if (client == null) {
      debugPrint('⚠️  Supabase not ready; skip login log');
      return;
    }
    try {
      await client.from('LoginLogs').insert({
        if (idUser != null) 'id_user': idUser,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': kIsWeb ? 'Web' : 'Mobile',
        'userAgent': kIsWeb ? web.window.navigator.userAgent : 'Mobile App',
      });
      debugPrint('✅ Login logged to Supabase (id_user=$idUser)');
    } catch (e) {
      debugPrint('❌ Error logging login to Supabase: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getLoginLogsStream({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Stream.fromFuture(
        getLoginLogsFromSupabase(startDate: startDate, endDate: endDate));
  }

  Future<List<Map<String, dynamic>>> getLoginLogsFromSupabase({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      var query = client.from('LoginLogs').select();
      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }
      final rows = await query.order('timestamp', ascending: false);
      return (rows as List).map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        return {
          ...r,
          'id': r['id']?.toString() ?? '',
          'fullName': r['fullname'] ?? r['fullName'] ?? '',
          'timestamp': r['timestamp'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getLoginLogsFromSupabase error: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getCalendarActivitiesStream(
      {String? fullName}) {
    return Stream.fromFuture(
        getCalendarActivitiesFromSupabase(fullName: fullName));
  }

  Future<List<Map<String, dynamic>>> getCalendarActivitiesFromSupabase(
      {String? fullName}) async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      var query = client.from('Leaves').select();
      if (fullName != null && fullName != 'ผู้ดูแลระบบ') {
        query = query.eq('fullname', fullName);
      }
      final rows = await query;
      return (rows as List)
          .map((row) => _fromSupabaseLeave(row as Map))
          .toList();
    } catch (e) {
      debugPrint('❌ getCalendarActivitiesFromSupabase error: $e');
      return [];
    }
  }

  // 📲 ส่งแจ้งเตือนการ "ขอรีเซ็ตรหัสผ่าน" ไปยังแอดมินทาง LINE ครับ 🥇🏆🏎️
  Future<void> sendLinePasswordResetNotification(
      String username, String fullName) async {
    try {
      final settings = await getLineMessagingSettingsFromSupabase();
      final bridgeUrl = _appsScriptUrlFromSettings(settings);
      final to = (settings['groupId'] ?? '').toString().trim();
      if (to.isEmpty) return;

      // 📝 สร้างข้อความแจ้งขอรีเซ็ตรหัสผ่านครับ 🥇🏆
      String msg = "⚠️ แจ้งเตือน: มีการขอรีเซ็ตรหัสผ่าน\n"
          "👤 ชื่อผู้ใช้: $username\n"
          "👤 ชื่อ-นามสกุล: $fullName\n"
          "------------------\n"
          "โปรดดำเนินการตรวจสอบและรีเซ็ตในเมนูจัดการผู้ใช้ครับ";

      final String url = _buildAppsScriptGetUrl(bridgeUrl, {
        'action': 'line_notification',
        'secretKey': FirebaseService.secretKey,
        'to': to,
        'message': msg,
      });

      if (kIsWeb) {
        final String jsCode =
            "fetch(${jsonEncode(url)}, {method:'GET', mode:'no-cors'}).catch(function(e){});";
        globalContext.callMethod<JSAny>('eval'.toJS, jsCode.toJS);
      } else {
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("❌ Password Reset Notify Error: $e");
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SUPABASE READ LAYER — Part 3 Migration
  // ═══════════════════════════════════════════════════════════════

  // ── Normalizer helpers ──────────────────────────────────────────

  /// แปลง row จาก Supabase Teachers → format ที่ UI คาดหวัง
  static Map<String, dynamic> _fromSupabaseTeacher(Map<dynamic, dynamic> row) {
    final r = Map<String, dynamic>.from(row);
    final docId = r['firebase_uid']?.toString().isNotEmpty == true
        ? r['firebase_uid'].toString()
        : r['id']?.toString() ?? r['id_user']?.toString() ?? '';
    return {
      ...r,
      'id': docId,
      'fullName': r['fullname'] ?? r['fullName'] ?? r['name'] ?? '',
      'academicStanding':
          r['academicstanding'] ?? r['academicStanding'] ?? r['academic'] ?? '',
      'position': r['position'] ?? '',
      'department': r['department'] ?? '',
      'role': r['role'] ?? '',
      'permission': r['permission'] ?? r['role'] ?? '',
      'phone': r['phone'] ?? '',
      'profileImage': r['profileimage'] ?? r['profileImage'] ?? '',
    };
  }

  /// แปลง row จาก Supabase Leaves → format ที่ UI คาดหวัง
  static Map<String, dynamic> _fromSupabaseLeave(Map<dynamic, dynamic> row) {
    final r = Map<String, dynamic>.from(row);
    return {
      ...r,
      'requestId': r['id']?.toString() ?? r['requestid']?.toString() ?? '',
      'fullName': r['fullname'] ?? r['fullName'] ?? '',
      'leaveType': r['leavetype'] ?? r['leaveType'] ?? '',
      'startDate': r['startdate'] ?? r['startDate'] ?? '',
      'endDate': r['enddate'] ?? r['endDate'] ?? '',
      'totalDays': r['totaldays'] ?? r['totalDays'] ?? 0,
      'isHalfDay': r['ishalfday'] ?? r['isHalfDay'] ?? false,
      'halfDayPeriod': r['halfdayperiod'] ?? r['halfDayPeriod'] ?? '',
      'createdAt': r['createdat'] ?? r['createdAt'] ?? '',
      'medicalCertificate':
          r['medicalcertificate'] ?? r['medicalCertificate'] ?? '',
      'academicStanding':
          r['academicstanding'] ?? r['academicStanding'] ?? '',
      'receiveNumber': r['receivenumber'] ?? r['receiveNumber'],
      'receiveDate': r['receivedate'] ?? r['receiveDate'],
      'receiveTime': r['receivetime'] ?? r['receiveTime'],
      'lastUpdatedAt': r['lastupdatedat'] ?? r['lastUpdatedAt'],
    };
  }

  /// แปลง row จาก Supabase FiscalRounds → format ที่ UI คาดหวัง
  static Map<String, dynamic> _fromSupabaseFiscalRound(
      Map<dynamic, dynamic> row) {
    final r = Map<String, dynamic>.from(row);
    return {
      ...r,
      'startDate': r['startdate'] ?? r['startDate'] ?? '',
      'endDate': r['enddate'] ?? r['endDate'] ?? '',
      'isActive': r['isactive'] ?? r['isActive'] ?? false,
      'createdAt': r['createdat'] ?? r['createdAt'],
    };
  }

  // ── Teachers ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsersFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) {
      debugPrint('⚠️  Supabase not ready — falling back to Firebase getUsers');
      return getUsers();
    }
    try {
      final rows = await client.from('Teachers').select();
      final list = (rows as List)
          .map((row) => _fromSupabaseTeacher(row as Map))
          .toList();
      list.sort((a, b) => (a['fullName'] ?? '')
          .toString()
          .compareTo((b['fullName'] ?? '').toString()));
      return list;
    } catch (e) {
      debugPrint('❌ getUsersFromSupabase error: $e');
      return [];
    }
  }

  // ── Leaves ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaveRequestsFromSupabase(
      {int? year}) async {
    final client = _supabaseIfReady;
    if (client == null) return getLeaveRequests(year: year);
    try {
      var query = client.from('Leaves').select();
      if (year != null) query = query.eq('year', year);
      final rows = await query;
      return (rows as List)
          .map((row) => _fromSupabaseLeave(row as Map))
          .toList()
        ..sort(compareLeaveRecency);
    } catch (e) {
      debugPrint('❌ getLeaveRequestsFromSupabase error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequestsFromSupabase(
      String fullName) async {
    final client = _supabaseIfReady;
    if (client == null) return getMyLeaveRequests(fullName);
    try {
      final rows = await client
          .from('Leaves')
          .select()
          .eq('fullname', fullName);
      return (rows as List)
          .map((row) => _fromSupabaseLeave(row as Map))
          .toList()
        ..sort(compareLeaveRecency);
    } catch (e) {
      debugPrint('❌ getMyLeaveRequestsFromSupabase error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLastLeaveRequestFromSupabase(
      String fullName) async {
    final client = _supabaseIfReady;
    if (client == null) return getLastLeaveRequest(fullName);
    try {
      final rows = await client
          .from('Leaves')
          .select()
          .eq('fullname', fullName)
          .order('createdat', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) return null;
      return _fromSupabaseLeave(rows.first as Map);
    } catch (e) {
      debugPrint('❌ getLastLeaveRequestFromSupabase error: $e');
      return null;
    }
  }

  /// อัปเดตเลขรับใบลาใน Supabase
  Future<void> updateLeaveReceiveNumberInSupabase(
      String requestId, String receiveNumber, String receiveDate,
      String receiveTime) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from('leaves').update({
      'receivenumber': receiveNumber,
      'receivedate': receiveDate,
      'receivetime': receiveTime,
    }).eq('id', requestId);
  }

  /// ลบใบลาจาก Supabase
  Future<void> deleteLeaveFromSupabase(String requestId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from('leaves').delete().eq('id', requestId);
  }

  // ── FiscalRounds ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFiscalRoundsFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return getFiscalRounds();
    try {
      final rows = await client
          .from('FiscalRounds')
          .select()
          .order('year', ascending: false);
      return (rows as List)
          .map((row) => _fromSupabaseFiscalRound(row as Map))
          .toList();
    } catch (e) {
      debugPrint('❌ getFiscalRoundsFromSupabase error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getActiveFiscalRoundFromSupabase() async {
    try {
      final rounds = await getFiscalRoundsFromSupabase();
      final now = DateTime.now();
      final todayStr = '${now.day}/${now.month}/${now.year + 543}';
      for (final r in rounds) {
        if (isDateInRange(
            todayStr, r['startDate'] ?? '', r['endDate'] ?? '')) {
          return {...r, 'isAutoSelected': true};
        }
      }
    } catch (e) {
      debugPrint('❌ getActiveFiscalRoundFromSupabase error: $e');
    }
    return null;
  }

  // ── Special dates ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSpecialHolidaysFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      final rows = await client.from('SpecialHolidays').select();
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('❌ getSpecialHolidaysFromSupabase error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSpecialWorkingDaysFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      final rows = await client.from('SpecialWorkingDays').select();
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('❌ getSpecialWorkingDaysFromSupabase error: $e');
      return [];
    }
  }

  // ── Master data ─────────────────────────────────────────────────

  Future<List<String>> _getMasterListFromSupabase(
      String table, List<String> nameCandidates) async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      final rows = await client.from(table).select();
      final seen = <String>{};
      final result = <String>[];
      for (final row in (rows as List)) {
        final r = Map<String, dynamic>.from(row as Map);
        String value = '';
        for (final col in nameCandidates) {
          final v = r[col]?.toString().trim() ?? '';
          if (v.isNotEmpty) {
            value = v;
            break;
          }
        }
        if (value.isNotEmpty && seen.add(value)) result.add(value);
      }
      return result;
    } catch (e) {
      debugPrint('❌ getMasterList($table) error: $e');
      return [];
    }
  }

  Future<List<String>> getLeaveTypesFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return getLeaveTypes();
    try {
      final rows = await client.from('LeaveTypes').select();
      final seen = <String>{};
      final result = <String>[];
      for (final row in (rows as List)) {
        final r = Map<String, dynamic>.from(row as Map);
        final value = (r['value'] ??
                r['Value'] ??
                r['name'] ??
                r['typename'] ??
                r['leavetypename'] ??
                '')
            .toString()
            .trim();
        if (value.isNotEmpty && seen.add(value)) result.add(value);
      }
      return result;
    } catch (e) {
      debugPrint('❌ getLeaveTypesFromSupabase error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLeaveTypesRawFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      final rows = await client.from('LeaveTypes').select();
      return (rows as List).map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        final name =
            (r['value'] ?? r['Value'] ?? r['name'] ?? '').toString().trim();
        return {...r, 'Value': name};
      }).toList();
    } catch (e) {
      debugPrint('❌ getLeaveTypesRawFromSupabase error: $e');
      return [];
    }
  }

  Future<List<String>> getAdminRolesFromSupabase() async {
    final roles = await _getMasterListFromSupabase('adminroles',
        ['adminrolename', 'name', 'value', 'adminrole', 'ตำแหน่งบริหาร']);
    if (!roles.contains('ไม่มีตำแหน่งบริหาร')) {
      roles.insert(0, 'ไม่มีตำแหน่งบริหาร');
    }
    return roles;
  }

  Future<List<String>> getPositionsFromSupabase() async {
    return _getMasterListFromSupabase(
        'positions', ['positionname', 'name', 'value', 'position', 'ตำแหน่ง']);
  }

  Future<List<String>> getDepartmentsFromSupabase() async {
    return _getMasterListFromSupabase('departments', [
      'departmentname',
      'name',
      'value',
      'department',
      'แผนก_กลุ่มสาระ',
    ]);
  }

  Future<List<String>> getAcademicsFromSupabase() async {
    return _getMasterListFromSupabase(
        'academics', ['academicname', 'name', 'value', 'academic', 'วิทยฐานะ']);
  }

  Future<List<String>> getPermissionsFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return getPermissions();
    try {
      final rows = await client
          .from('roles')
          .select('Accessrights')
          .order('ID_Roles');
      final seen = <String>{};
      final result = <String>[];
      for (final row in (rows as List)) {
        final v = (row['Accessrights'] ?? '').toString().trim();
        if (v.isNotEmpty &&
            v.toUpperCase() != 'TRUE' &&
            v.toUpperCase() != 'FALSE') {
          if (seen.add(v)) result.add(v);
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ getPermissionsFromSupabase error: $e');
      return [];
    }
  }

  // ── Master data write (Supabase-only) ───────────────────────────

  Future<void> addMasterItemToSupabase(
      String supabaseTable, Map<String, dynamic> record) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from(supabaseTable).insert(record);
  }

  Future<void> updateMasterItemInSupabase(
      String supabaseTable, String id, Map<String, dynamic> data) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from(supabaseTable).update(data).eq('id', id);
  }

  Future<void> deleteMasterItemFromSupabase(
      String supabaseTable, String id) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from(supabaseTable).delete().eq('id', id);
  }

  // ── Permissions doc (for menu access) ────────────────────────────

  Future<Map<String, dynamic>?> getPermissionDocFromSupabase(
      String collection, String role) async {
    final client = _supabaseIfReady;
    if (client == null) return null;
    try {
      final rows =
          await client.from(collection).select().eq('id', role).limit(1);
      if ((rows as List).isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
      return null;
    } catch (e) {
      debugPrint('❌ getPermissionDocFromSupabase($collection/$role) error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPermissionDocsFromSupabase(
      String collection) async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      final rows = await client.from(collection).select();
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('❌ getAllPermissionDocsFromSupabase($collection) error: $e');
      return [];
    }
  }

  Future<int> getPendingResetCountFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return 0;
    try {
      final rows = await client
          .from('Teachers')
          .select('id')
          .eq('forgotPasswordStatus', 'waiting');
      return (rows as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingResetsFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      final rows = await client
          .from('Teachers')
          .select()
          .eq('forgotPasswordStatus', 'waiting');
      return (rows as List)
          .map((r) => _fromSupabaseTeacher(r as Map))
          .toList();
    } catch (e) {
      debugPrint('❌ getPendingResetsFromSupabase error: $e');
      return [];
    }
  }

  // ── LINE Settings ───────────────────────────────────────────────

  /// ดึง LINE messaging settings จาก Supabase Settings cache
  Future<Map<String, dynamic>> getLineMessagingSettingsFromSupabase() async {
    await ensureConfigLoaded();
    // ensureConfigLoaded() merge ทุก row จาก Supabase Settings table แล้ว
    return {
      'groupId': config('groupid').isNotEmpty ? config('groupid') : config('groupId'),
      'webhookUrl': config('webhookurl').isNotEmpty
          ? config('webhookurl')
          : config('webhookUrl').isNotEmpty
              ? config('webhookUrl')
              : config('appsScriptUrl'),
      'template': config('template'),
    };
  }
}
