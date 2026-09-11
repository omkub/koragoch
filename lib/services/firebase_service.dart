import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseService {
  static Map<String, String> _configCache = {};
  static bool _configLoaded = false;
  static bool _dualWriteEnabled = true; // ✅ Enable dual-write to Supabase

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
    if (value is FieldValue) {
      // serverTimestamp ฯลฯ → ใช้เวลาปัจจุบันแทน
      return DateTime.now().toIso8601String();
    }
    if (value is Timestamp) return value.toDate().toIso8601String();
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
  Future<void> _dualWriteSet(
    String collectionName,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    try {
      await _supabaseUpsert(
          collectionName.toLowerCase(), _toSupabaseRecord(data, docId));
    } catch (e) {
      debugPrint('❌ Supabase write error in _dualWriteSet ($collectionName): $e');
      rethrow;
    }
  }

  // 🚀 Supabase-only update (ห้ามเขียน Firebase — production hosting ใช้อยู่)
  Future<void> _dualWriteUpdate(
    String collectionName,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _supabaseUpsert(
          collectionName.toLowerCase(), _toSupabaseRecord(data, docId));
    } catch (e) {
      debugPrint('❌ Supabase write error in _dualWriteUpdate ($collectionName): $e');
      rethrow;
    }
  }

  // 🚀 Supabase-only add (ห้ามเขียน Firebase — production hosting ใช้อยู่)
  Future<String> _dualWriteAdd(
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

  FirebaseFirestore? _firestoreInstance;

  FirebaseFirestore get _db {
    _firestoreInstance ??= FirebaseFirestore.instanceFor(
        app: Firebase.app(), databaseId: 'school');
    return _firestoreInstance!;
  }

  FirebaseFirestore get db => _db;

  static bool isLikelyAppsScriptWebAppUrl(String value) {
    return RegExp(r'^https:\/\/script\.google\.com\/macros\/s\/[^\s\/]+\/exec$')
        .hasMatch(value.trim());
  }

  Future<Map<String, dynamic>> getLineMessagingSettings() async {
    final snap = await db.collection('Settings').doc('line_messaging').get();
    return snap.data() ?? <String, dynamic>{};
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

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  static String generateResetCode() {
    final random = DateTime.now().microsecondsSinceEpoch;
    final code = ((random % 900000) + 100000).toString();
    return code;
  }

  String _resolveEffectiveRole(Iterable<dynamic> values) {
    final roles = values
        .where((value) => value != null)
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (roles.contains('ผู้ดูแลระบบ')) return 'ผู้ดูแลระบบ';
    if (roles.contains('ผู้บริหาร')) return 'ผู้บริหาร';
    if (roles.contains('ครู')) return 'ครู';
    return roles.isNotEmpty ? roles.first : 'ครู';
  }

  // 🛡️ ฟังก์ชันผูก UID เข้ากับชื่อครู และซิงค์สิทธิ์ไปยัง UserRoles (Phase 3 Fix) 🥇🏆
  Future<bool> linkTeacherWithUid(
    String fullName,
    String uid, {
    String? teacherDocId,
    String? username,
    String? preferredRole,
    Map<String, dynamic>? teacherData,
  }) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? teacherDoc;

      // ⚡ ถ้า caller ส่งข้อมูลมาแล้ว ไม่ต้องดึงซ้ำจากฐานข้อมูล
      if (teacherData != null && teacherDocId != null && teacherDocId.trim().isNotEmpty) {
        final docData = teacherData;
        final role = _resolveEffectiveRole([
          docData['role'],
          docData['permission'],
          preferredRole,
        ]);
        final resolvedFullName =
            (docData['fullName'] ?? docData['name'] ?? fullName).toString();

        // Login must not depend on Supabase readiness; sync Firebase first.
        await Future.wait([
          _db.collection('Teachers').doc(teacherDocId.trim()).update({
            'firebase_uid': uid,
            'role': role,
            'permission': role,
            'lastSyncAt': FieldValue.serverTimestamp(),
          }),
          _db.collection('UserRoles').doc(uid).set({
            'role': role,
            'permission': role,
            'fullName': resolvedFullName,
            'teacherDocId': teacherDocId.trim(),
            'lastSyncAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        ]);

        debugPrint(
            "Successfully linked UID and Sync Roles for: $resolvedFullName");
        return true;
      }

      // Fallback: query ถ้าไม่ได้รับข้อมูล (สำหรับ backward compatibility)
      if (teacherDocId != null && teacherDocId.trim().isNotEmpty) {
        final snap =
            await _db.collection('Teachers').doc(teacherDocId.trim()).get();
        if (snap.exists) {
          teacherDoc = snap;
        }
      }

      if (teacherDoc == null &&
          username != null &&
          username.trim().isNotEmpty) {
        final query = await _db
            .collection('Teachers')
            .where('username', isEqualTo: username.trim())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) teacherDoc = query.docs.first;
      }

      if (teacherDoc == null && fullName.trim().isNotEmpty) {
        final query = await _db
            .collection('Teachers')
            .where('fullName', isEqualTo: fullName.trim())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) teacherDoc = query.docs.first;
      }

      if (teacherDoc != null) {
        final docData = teacherDoc.data() ?? <String, dynamic>{};
        final role = _resolveEffectiveRole([
          docData['role'],
          docData['permission'],
          preferredRole,
        ]);
        final resolvedFullName =
            (docData['fullName'] ?? docData['name'] ?? fullName).toString();

        // ⚡ ยิง 2 writes พร้อมกันแทนการ await ต่อกัน
        await Future.wait([
          _db.collection('Teachers').doc(teacherDoc.id).update({
            'firebase_uid': uid,
            'role': role,
            'permission': role,
            'lastSyncAt': FieldValue.serverTimestamp(),
          }),
          _db.collection('UserRoles').doc(uid).set({
            'role': role,
            'permission': role,
            'fullName': resolvedFullName,
            'teacherDocId': teacherDoc.id,
            'lastSyncAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        ]);

        debugPrint(
            "Successfully linked UID and Sync Roles for: $resolvedFullName");
        return true;
      }
    } catch (e) {
      debugPrint("Error linking UID and Roles: $e");
    }
    return false;
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return Stream.fromFuture(getUsersFromSupabase());
  }

  Stream<List<Map<String, dynamic>>> getUsersStreamFromSupabase() {
    return Stream.fromFuture(getUsersFromSupabase());
  }

  // ดึงรายชื่อครูแบบครั้งเดียว — อ่านจาก Supabase เป็นหลัก
  Future<List<Map<String, dynamic>>> getUsers() async {
    final supaList = await getUsersFromSupabase();
    if (supaList.isNotEmpty) return supaList;

    // กรณีสำรอง: อ่านเปรียบเทียบจาก Firebase
    final snapshot = await _db.collection('Teachers').get();
    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      final sanitized = Map<String, dynamic>.from(data);
      sanitized.forEach((key, value) {
        if (value is Timestamp)
          sanitized[key] = value.toDate().toIso8601String();
      });
      return {
        'id': doc.id,
        ...sanitized,
        'fullName': sanitized['fullName'] ??
            sanitized['name'] ??
            sanitized['Name'] ??
            doc.id,
        'academicStanding': sanitized['academicStanding'] ??
            sanitized['academic'] ??
            sanitized['วิทยฐานะ'] ??
            '',
      };
    }).toList();
    list.sort((a, b) => (a['fullName'] ?? '')
        .toString()
        .compareTo((b['fullName'] ?? '').toString()));
    return list;
  }

  // เพิ่มรายชื่อครูคนใหม่ลงฐานข้อมูลครับ 🏎️🏆
  Future<void> addUser(Map<String, dynamic> data) async {
    await _dualWriteAdd('Teachers', data);
  }

  // แก้ไขข้อมูลครูครับ 🏎️🏆
  Future<void> updateUser(String docId, Map<String, dynamic> data) async {
    await _dualWriteUpdate('Teachers', docId, data);
  }

  // 🚀 ลบข้อมูลครู (Supabase-only)
  Future<void> deleteUser(String docId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from('teachers').delete().eq('id', docId);
  }

  // 🛠️ ฟังก์ชันช่วยหาฟิลด์ที่เป็นค่า String (หาฟิลด์ Value/Name แบบไม่สนตัวเล็กตัวใหญ่) 🥇🏆
  String _extractValue(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return doc.id;

    // 1. ลองหาฟิลด์ที่ชื่อตรงกับที่ต้องการก่อน (Value, Name, name, Type Name แบบไม่สน Case)
    for (String key in data.keys) {
      final k = key.toLowerCase();
      if (k == 'value' ||
          k == 'name' ||
          k.contains('name') ||
          k.contains('value')) {
        final val = data[key]?.toString() ?? '';
        final cleanVal = val.trim().toUpperCase();
        if (val.trim().isNotEmpty &&
            cleanVal != 'TRUE' &&
            cleanVal != 'FALSE') {
          return val.trim();
        }
      }
    }

    // 2. ถ้าไม่เจอ ให้เลือกฟิลด์แรกที่เป็น String และชื่อไม่มีคำว่า ID
    for (var entry in data.entries) {
      if (entry.value is String && !entry.key.toUpperCase().contains('ID')) {
        final val = entry.value.toString().trim();
        if (val.isNotEmpty &&
            val.toUpperCase() != 'TRUE' &&
            val.toUpperCase() != 'FALSE') {
          return val;
        }
      }
    }

    return doc.id;
  }

  int _toIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<List<String>> _getOrderedMasterValues(
    String collection,
    String idField, {
    bool excludeBooleanText = false,
  }) async {
    final snapshot = await _db.collection(collection).get();
    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aFieldOrder = _toIntValue(aData[idField]);
        final bFieldOrder = _toIntValue(bData[idField]);
        final aOrder = aFieldOrder > 0 ? aFieldOrder : _toIntValue(a.id);
        final bOrder = bFieldOrder > 0 ? bFieldOrder : _toIntValue(b.id);

        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        return a.id.compareTo(b.id);
      });

    final seen = <String>{};
    final values = <String>[];
    for (final doc in docs) {
      final value = _extractValue(doc);
      final upperValue = value.toUpperCase();
      if (value.isEmpty) continue;
      if (excludeBooleanText &&
          (upperValue == 'TRUE' || upperValue == 'FALSE')) {
        continue;
      }
      if (seen.add(value)) values.add(value);
    }
    return values;
  }

  // ดึงตำแหน่งงานบริหาร — อ่านจาก Supabase ก่อน
  Future<List<String>> getAdminRoles() async {
    final supa = await getAdminRolesFromSupabase();
    if (supa.isNotEmpty) return supa;
    final List<String> roles =
        await _getOrderedMasterValues('AdminRoles', 'ID_AdminRoles');
    if (!roles.contains('ไม่มีตำแหน่งบริหาร'))
      roles.insert(0, 'ไม่มีตำแหน่งบริหาร');
    return roles;
  }

  // ดึงตำแหน่งงานทั่วไป — อ่านจาก Supabase ก่อน
  Future<List<String>> getPositions() async {
    final supa = await getPositionsFromSupabase();
    if (supa.isNotEmpty) return supa;
    return _getOrderedMasterValues('Positions', 'ID_Positions');
  }

  // ดึงสิทธิ์การเข้าถึง (Roles) — อ่านจาก Supabase ก่อน
  Future<List<String>> getPermissions() async {
    final supa = await getPermissionsFromSupabase();
    if (supa.isNotEmpty) return supa;
    return _getOrderedMasterValues(
      'Roles',
      'ID_Roles',
      excludeBooleanText: true,
    );
  }

  // ดึงวิทยฐานะ — อ่านจาก Supabase ก่อน
  Future<List<String>> getAcademics() async {
    final supa = await getAcademicsFromSupabase();
    if (supa.isNotEmpty) return supa;
    return _getOrderedMasterValues('Academics', 'ID_Academics');
  }

  // ดึงประเภทการลา — อ่านจาก Supabase ก่อน
  Future<List<String>> getLeaveTypes() async {
    final supa = await getLeaveTypesFromSupabase();
    if (supa.isNotEmpty) return supa;
    return _getOrderedMasterValues('LeaveTypes', 'ID_LeaveTypes');
  }

  // ดึงกลุ่มสาระการเรียนรู้ — อ่านจาก Supabase ก่อน
  Future<List<String>> getDepartments() async {
    final supa = await getDepartmentsFromSupabase();
    if (supa.isNotEmpty) return supa;
    return _getOrderedMasterValues('Departments', 'ID_Departments');
  }

  // ดึงรายการวิชาที่สอนจากฐานข้อมูล Subjects ครับ 🕵️‍♂️🏎️🏆
  Future<List<String>> getSubjects() async {
    final snapshot = await _db.collection('Subjects').get();
    return snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(); // ป้องกันซ้ำ
  }

  // 📅 ระบบจัดการรอบงบประมาณ (Fiscal Rounds) 🥇🏆
  Stream<List<Map<String, dynamic>>> getFiscalRoundsStream() {
    return Stream.fromFuture(getFiscalRoundsFromSupabase());
  }

  Future<void> addFiscalRound(Map<String, dynamic> data) async {
    await _dualWriteAdd('FiscalRounds', {
      ...data,
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 🚀 ลบรอบงบประมาณ (Supabase-only)
  Future<void> deleteFiscalRound(String docId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from('fiscalrounds').delete().eq('id', docId);
  }

  // ดึงรายการรอบงบประมาณที่ตรงกับปฏิทินปัจจุบัน (Auto-match) 🥇🏎️🏆
  Future<Map<String, dynamic>?> getActiveFiscalRound() async {
    final supaActive = await getActiveFiscalRoundFromSupabase();
    if (supaActive != null) return supaActive;
    try {
      final snapshot = await _db
          .collection('FiscalRounds')
          .orderBy('year', descending: true)
          .orderBy('round', descending: true)
          .get();
      final now = DateTime.now();
      // แปลงปีเป็น พ.ศ. เพื่อเทียบกับข้อมูลในระบบครับ 🇹🇭
      final todayStr = "${now.day}/${now.month}/${now.year + 543}";

      for (var doc in snapshot.docs) {
        final r = doc.data();
        if (isDateInRange(todayStr, r['startDate'] ?? '', r['endDate'] ?? '')) {
          return {...r, 'id': doc.id, 'isAutoSelected': true};
        }
      }
    } catch (e) {
      debugPrint("Error in getActiveFiscalRound: $e");
    }
    return null;
  }

  // ดึงรายการรอบงบประมาณทั้งหมดครับ 🕵️‍♂️🏎️🏆
  Future<List<Map<String, dynamic>>> getFiscalRounds() async {
    final supaRounds = await getFiscalRoundsFromSupabase();
    if (supaRounds.isNotEmpty) return supaRounds;
    try {
      final snapshot = await _db
          .collection('FiscalRounds')
          .orderBy('year', descending: true)
          .get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint("Error in getFiscalRounds: $e");
      return [];
    }
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
    if (value is Timestamp) return value.toDate();
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
    final supa = await getLeaveRequestsFromSupabase(year: year);
    if (supa.isNotEmpty) return supa;
    Query<Map<String, dynamic>> query = _db.collection('Leaves');
    if (year != null) query = query.where('year', isEqualTo: year);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'requestId': doc.id})
        .toList()
      ..sort(FirebaseService.compareLeaveRecency);
  }

  Stream<List<Map<String, dynamic>>> getMyLeaveRequestsStream(String fullName) {
    return Stream.fromFuture(getMyLeaveRequestsFromSupabase(fullName));
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequests(String fullName) async {
    final supa = await getMyLeaveRequestsFromSupabase(fullName);
    if (supa.isNotEmpty) return supa;
    final snapshot = await _db
        .collection('Leaves')
        .where('fullName', isEqualTo: fullName)
        .get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'requestId': doc.id})
        .toList()
      ..sort(FirebaseService.compareLeaveRecency);
  }

  // ดึงประวัติการลา "ล่าสุด" ของครู — อ่านจาก Supabase ก่อน
  Future<Map<String, dynamic>?> getLastLeaveRequest(String fullName) async {
    final supa = await getLastLeaveRequestFromSupabase(fullName);
    if (supa != null) return supa;
    final snapshot = await _db
        .collection('Leaves')
        .where('fullName', isEqualTo: fullName)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return {...doc.data(), 'requestId': doc.id};
    }
    return null;
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
    await _dualWriteSet('Leaves', docId, {
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
    await _dualWriteUpdate('Leaves', requestId, {
      ...data,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 🚀 นับเลขรับจาก Supabase (อ่าน Firebase เป็น fallback)
  Future<int> generateReceiveNumber() async {
    final client = _supabaseIfReady;
    final fiscalYear = DateTime.now().year + 543;
    if (client != null) {
      try {
        final rows = await client
            .from('leaves')
            .select('receivenumber')
            .eq('year', fiscalYear)
            .not('receivenumber', 'is', null);
        return (rows as List).length + 1;
      } catch (e) {
        debugPrint('generateReceiveNumber Supabase error: $e');
      }
    }
    // Fallback: read from Firebase (allowed)
    final snapshot = await _db.collection('Leaves')
        .where('year', isEqualTo: fiscalYear)
        .get();
    return snapshot.docs
        .where((d) => d.data()['receiveNumber'] != null)
        .length + 1;
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
    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is DateTime) {
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

      await ensureConfigLoaded();
      final snap = await db.collection('Settings').doc('line_messaging').get();
      final settings = snap.data() ?? <String, dynamic>{};
      final bridgeUrl = _appsScriptUrlFromSettings(settings);

      String to = (settings['groupId'] ?? '').toString().trim();
      String template = (settings['template'] ?? '').toString();

      if (snap.exists && snap.data() != null) {
        final settings = snap.data()!;
        to = settings['groupId'] ?? '';
        template = settings['template'] ?? '';
        debugPrint(
            "📍 Settings found: GroupID length=${to.length}, Template length=${template.length}");
      } else {
        debugPrint(
            "⚠️ LINE Notification Warning: 'Settings/line_messaging' document not found.");
      }

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
      final snap = await db.collection('Settings').doc('line_messaging').get();
      if (!snap.exists) return;

      final settings = snap.data() ?? <String, dynamic>{};
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
    await _dualWriteUpdate('Teachers', docId, newData);
  }

  // 👨‍🏫 อัปเดตข้อมูลบุคลากร (ใช้สำหรับหน้า Profile มือถือครับ) 🥇🏆🏎️
  Future<void> updateTeacherData(
      String fullName, Map<String, dynamic> newData) async {
    final query = await db
        .collection('Teachers')
        .where('fullName', isEqualTo: fullName)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await _dualWriteUpdate('Teachers', query.docs.first.id, newData);
    }
  }

  // 🕵️‍♂️ ค้นหาข้อมูลบุคลากรด้วย UID (เสถียรกว่าการหาด้วยชื่อครับ) 🥇🏆
  Future<Map<String, dynamic>?> searchTeacherByUid(String uid) async {
    final query = await db
        .collection('Teachers')
        .where('firebase_uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      // 🛡️ ฟอกข้อมูล Timestamp ทุกตัวให้เป็น String ป้องกัน Error JSON (minified:hl) 🥇🏆🏎️
      data.forEach((key, value) {
        if (value is Timestamp) {
          data[key] = value.toDate().toIso8601String();
        }
      });

      return {...data, 'docId': query.docs.first.id};
    }
    return null;
  }

  // 🕵️‍♂️ ค้นหาข้อมูลบุคลากรด้วยชื่อ (ใช้ดึงข้อมูลมาแก้ในโปรไฟล์ครับ)
  Future<Map<String, dynamic>?> searchTeacherByName(String fullName) async {
    final query = await db
        .collection('Teachers')
        .where('fullName', isEqualTo: fullName.trim())
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      // 🛡️ ฟอกข้อมูลให้สะอาด 100% ครับ 🥇🏆
      data.forEach((key, value) {
        if (value is Timestamp) {
          data[key] = value.toDate().toIso8601String();
        }
      });

      return {...data, 'docId': query.docs.first.id};
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

  // 🛡️ ดึงข้อมูลประวัติการการเข้าใช้งาน (สำหรับ Admin) 🥇🏆
  Stream<List<Map<String, dynamic>>> getLoginLogsStream({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _db.collection('LoginLogs');

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    return query
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...Map<String, dynamic>.from(doc.data() as Map),
                  'id': doc.id,
                })
            .toList());
  }

  // 📅 ดึงกิจกรรมทั้งหมดเพื่อแสดงในปฏิทิน (Admin เห็นทุกคน / User เห็นเฉพาะของตัวเอง) 🥇🏆🏎️
  Stream<List<Map<String, dynamic>>> getCalendarActivitiesStream(
      {String? fullName}) {
    Query query = _db.collection('Leaves');
    if (fullName != null && fullName != 'ผู้ดูแลระบบ') {
      query = query.where('fullName', isEqualTo: fullName);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  // 📲 ส่งแจ้งเตือนการ "ขอรีเซ็ตรหัสผ่าน" ไปยังแอดมินทาง LINE ครับ 🥇🏆🏎️
  Future<void> sendLinePasswordResetNotification(
      String username, String fullName) async {
    try {
      await ensureConfigLoaded();
      final snap = await db.collection('Settings').doc('line_messaging').get();
      if (!snap.exists) return;

      final settings = snap.data() ?? <String, dynamic>{};
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
