import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/web_platform.dart' as platform;

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
  static String? _thaiDateToIso(String? value) {
    if (value == null || value.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) return value;
    final parts = value.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      var year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        if (year > 2400) year -= 543;
        return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }
    }
    return value;
  }

  static Map<String, dynamic> _toSupabaseRecord(
      Map<String, dynamic> data, String docId) {
    final record = <String, dynamic>{'id': docId};
    data.forEach((key, value) {
      record[key] = _toSupabaseValue(value);
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
        final match = RegExp(r"Could not find the '([^']+)' column")
            .firstMatch(e.message);
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
    Map<String, dynamic> data) async {
    try {
      await _supabaseUpsert(collectionName, _toSupabaseRecord(data, docId));
    } catch (e) {
      debugPrint(
          '❌ Supabase write error in _supabaseSet ($collectionName): $e');
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
      await _supabaseUpsert(collectionName, _toSupabaseRecord(data, docId));
    } catch (e) {
      debugPrint(
          '❌ Supabase write error in _supabaseUpdate ($collectionName): $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ชื่อคอลัมน์ Primary Key ของแต่ละตาราง
  //
  // Firebase ใช้ document id ตัวเดียวชื่อ 'id' ทุก collection โค้ดเดิมจึง
  // เขียน .eq('id', ...) ไว้ทั่ว แต่ Supabase ตั้งชื่อ PK แยกกันทุกตาราง
  // และ "ไม่มีตารางไหนมีคอลัมน์ชื่อ id เลย" ทำให้คำสั่ง insert/update/delete
  // ที่อ้าง 'id' ล้มเหลวทั้งหมด (PostgREST ตอบ 400) 🥇🏆
  // ═══════════════════════════════════════════════════════════════
  static const Map<String, String> _primaryKeyByTable = {
    'Teachers': 'id_user',
    'Leaves': 'id_leaves',
    'FiscalRounds': 'id_year',
    'LeaveTypes': 'id_leaveType',
    'LeaveReasons': 'id_leaveReason',
    'SpecialHolidays': 'id_holiday',
    'SpecialWorkingDays': 'id_SpecialWorkingDays',
    'Settings': 'id_Settings',
    'LoginLogs': 'id_LoginLogs',
    'UserRoles': 'id_UserRole',
    'Permissions': 'id_Permissions',
    'MobilePermissions': 'id_MobilePermissions',
    'academics': 'ID_Academics',
    'adminroles': 'ID_AdminRoles',
    'departments': 'ID_Departments',
    'positions': 'ID_Positions',
    'roles': 'ID_Roles',
    'appconfig': 'ID_AppConfig',
  };

  /// ชื่อคอลัมน์ PK ของตารางนั้น (ไม่รู้จัก = เดาว่า 'id' ไว้ก่อน)
  static String primaryKeyFor(String table) =>
      _primaryKeyByTable[table] ?? 'id';

  // ═══════════════════════════════════════════════════════════════
  // Supabase Auth
  //
  // ครูส่วนใหญ่ไม่มีอีเมลจริง (มีแค่ 1 คนจาก 68) จึงประกอบอีเมลสังเคราะห์
  // จาก username ให้ Auth ใช้เป็นตัวระบุตัวตน ครูไม่เห็นและไม่ต้องรู้
  // ยังพิมพ์แค่ username กับรหัสผ่านเหมือนเดิม
  //
  // ⚠️ สูตรนี้ต้องตรงกับ tools/create_auth_users.mjs เป๊ะ ๆ (รวมการแปลง
  // เป็นตัวพิมพ์เล็ก) ไม่งั้นครูที่ username ขึ้นต้นด้วยตัวใหญ่จะล็อกอินไม่ได้
  // ═══════════════════════════════════════════════════════════════
  static const String authEmailDomain = 'leave.local';

  static String authEmailForUsername(String username) =>
      '${username.trim().toLowerCase()}@$authEmailDomain';

  /// ชื่อ (slug) ของ Edge Function ที่ทำงานต้องใช้สิทธิ์ระดับแอดมิน
  ///
  /// ⚠️ ชื่อที่แสดงในแดชบอร์ดคือ "admin-users" แต่ Supabase ตรึง slug/URL ไว้
  /// ตั้งแต่ตอนสร้าง เปลี่ยนชื่อทีหลังไม่เปลี่ยน URL จึงยังต้องเรียกด้วยชื่อสุ่ม
  /// ที่ระบบตั้งให้ตอนแรก ถ้าวันหลังลบแล้วสร้างใหม่ให้แก้ค่านี้ตามด้วย
  static const String adminUsersFunction = 'clever-responder';

  /// เรียก Edge Function ที่ทำงานแทนแอดมิน (รีเซ็ตรหัส / สร้างบัญชี Auth)
  ///
  /// service_role key อยู่ฝั่งเซิร์ฟเวอร์เท่านั้น ฝั่งเว็บส่งแค่ token ของคนที่
  /// ล็อกอินอยู่ไปให้ฟังก์ชันตรวจสิทธิ์เอง
  Future<Map<String, dynamic>> _callAdminUsersFunction({
    required String action,
    required dynamic idUser,
    String? password,
    String? adminPassword,
  }) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');

    final parsedId = int.tryParse(idUser?.toString() ?? '');
    if (parsedId == null) {
      throw Exception('ไม่พบรหัสผู้ใช้ (id_user) ที่จะดำเนินการครับ');
    }

    final response = await client.functions.invoke(
      adminUsersFunction,
      body: {
        'action': action,
        'id_user': parsedId,
        if (password != null && password.isNotEmpty) 'password': password,
        if (adminPassword != null && adminPassword.isNotEmpty)
          'admin_password': adminPassword,
      },
    );

    final data = response.data;
    if (response.status >= 400) {
      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'ดำเนินการไม่สำเร็จ (รหัส ${response.status})';
      throw Exception(message);
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// เรียก Edge Function สำหรับการกู้รหัสผ่าน — ใช้ได้ทั้งที่ยังไม่ได้ล็อกอิน
  ///
  /// ครูที่ลืมรหัสย่อมล็อกอินไม่ได้ ฝั่งเซิร์ฟเวอร์จึงตรวจสิทธิ์ด้วยรหัสชั่วคราว
  /// ที่แอดมินออกให้แทน และเป็นคนตั้งรหัสใน Supabase Auth ให้ด้วย
  Future<Map<String, dynamic>> _callResetFunction(
      Map<String, dynamic> body) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');

    final response =
        await client.functions.invoke(adminUsersFunction, body: body);
    final data = response.data;
    if (response.status >= 400) {
      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'ดำเนินการไม่สำเร็จ (รหัส ${response.status})';
      throw Exception(message);
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// ครูแจ้งแอดมินว่าลืมรหัสผ่าน — ตั้งสถานะรอการอนุมัติ
  Future<void> requestPasswordReset(String username) async {
    await _callResetFunction({
      'action': 'request_password_reset',
      'username': username,
    });
  }

  /// ตรวจว่าแอดมินอนุมัติการกู้รหัสแล้ว และรหัสชั่วคราวถูกต้อง — คืนชื่อ-นามสกุล
  Future<String> checkPasswordResetStatus(String username, String code) async {
    final result = await _callResetFunction({
      'action': 'check_reset_status',
      'username': username,
      'code': code,
    });
    return (result['fullName'] ?? '').toString();
  }

  /// ตั้งรหัสผ่านใหม่หลังกู้รหัส — ตั้งทั้งใน Supabase Auth และคอลัมน์สำเนา
  Future<void> completePasswordReset(
      String username, String code, String newPassword) async {
    await _callResetFunction({
      'action': 'complete_password_reset',
      'username': username,
      'code': code,
      'new_password': newPassword,
    });
  }

  /// ดูรหัสผ่านของครู โดยยืนยันตัวตนด้วยรหัสผ่านของแอดมินเอง
  ///
  /// รหัสผ่านของแอดมินถูกส่งไปตรวจที่ Edge Function เท่านั้น ฝั่งเว็บไม่ได้
  /// ตัดสินใจอะไรเอง และไม่มีทางข้ามด่านนี้จากหน้าเว็บได้
  Future<String> viewTeacherPassword(
      dynamic idUser, String adminPassword) async {
    final result = await _callAdminUsersFunction(
      action: 'view_password',
      idUser: idUser,
      adminPassword: adminPassword,
    );
    return (result['password'] ?? '').toString();
  }

  /// ตั้งรหัสผ่านใหม่ให้ครูคนอื่น — ใช้ตอนแอดมินช่วยครูที่ลืมรหัส
  Future<void> adminResetPassword(dynamic idUser, String newPassword) =>
      _callAdminUsersFunction(
        action: 'reset_password',
        idUser: idUser,
        password: newPassword,
      );

  /// สร้างบัญชี Supabase Auth ให้ครูที่เพิ่งถูกเพิ่มเข้าตาราง Teachers
  Future<void> adminCreateAuthAccount(dynamic idUser, String password) =>
      _callAdminUsersFunction(
        action: 'create_auth',
        idUser: idUser,
        password: password,
      );

  /// PK ทุกตัวเป็น bigint แต่ UI ส่งมาเป็น String จึงแปลงให้ก่อนถ้าแปลงได้
  static dynamic _pkValue(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return int.tryParse(text) ?? text;
  }

  /// ดึงชื่อคอลัมน์ที่ไม่มีอยู่จริงออกจากข้อความ error ของ PostgREST
  static String? _missingColumnFromError(String message) {
    final missing = RegExp(r"Could not find the '([^']+)' column")
            .firstMatch(message)
            ?.group(1) ??
        RegExp(r'column "?([^"\s]+)"? does not exist')
            .firstMatch(message)
            ?.group(1);
    return missing?.split('.').last;
  }

  /// insert พร้อมตัดคอลัมน์ที่ตารางไม่มีออกทีละตัวแล้วลองใหม่
  /// (ใช้ตรรกะเดียวกับ updateTeacherById เพื่อให้ข้อมูลส่วนที่ลงได้ไม่ตกหล่น)
  static Future<Map<String, dynamic>?> _insertWithColumnRetry(
    SupabaseClient client,
    String table,
    Map<String, dynamic> record,
  ) async {
    final rec = Map<String, dynamic>.from(record);
    // PK เป็น identity ฐานข้อมูลออกเลขให้เอง ห้ามส่งไปเอง
    rec.remove('id');
    rec.remove('docId');
    rec.remove(primaryKeyFor(table));

    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final rows = await client.from(table).insert(rec).select();
        final list = rows as List;
        return list.isEmpty
            ? null
            : Map<String, dynamic>.from(list.first as Map);
      } on PostgrestException catch (e) {
        final key = _missingColumnFromError(e.message);
        if (key == null || !rec.containsKey(key)) rethrow;
        debugPrint('⚠️  $table ไม่มีคอลัมน์ $key — ข้ามคอลัมน์นี้');
        rec.remove(key);
        if (rec.isEmpty) return null;
      }
    }
    return null;
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
  //
  // เดิมส่ง data ดิบเข้า insert ตรง ๆ ทำให้ล้มทุกครั้ง เพราะ
  //   1) แนบคอลัมน์ 'id' ที่ตาราง Teachers ไม่มี
  //   2) ส่ง position/department/วิทยฐานะ เป็นข้อความ แต่ตารางเก็บเป็น FK ตัวเลข
  // ตอนนี้ใช้ตัวแปลงชุดเดียวกับตอนแก้ไขผู้ใช้ และตัดคอลัมน์ส่วนเกินให้อัตโนมัติ
  Future<void> addUser(Map<String, dynamic> data) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');

    final username = (data['username'] ?? '').toString().trim();
    if (username.isEmpty) {
      throw Exception('กรุณาระบุชื่อผู้ใช้ (username) ก่อนบันทึกครับ');
    }

    // กันชื่อผู้ใช้ซ้ำตั้งแต่ต้นทาง จะได้ขึ้นข้อความที่อ่านรู้เรื่อง
    final duplicated = await client
        .from('Teachers')
        .select('id_user')
        .eq('username', username)
        .limit(1);
    if ((duplicated as List).isNotEmpty) {
      throw Exception(
          'ชื่อผู้ใช้ "$username" ถูกใช้ไปแล้ว กรุณาตั้งชื่อใหม่ครับ');
    }

    final rec = await _teacherRecordForSupabase(client, data);
    final now = DateTime.now().toIso8601String();
    rec['created_at'] = rec['created_at'] ?? now;
    rec['updated_at'] = now;

    final inserted = await _insertWithColumnRetry(client, 'Teachers', rec);

    // สร้างบัญชี Supabase Auth ให้ด้วย ไม่งั้นครูใหม่จะล็อกอินไม่ได้
    // หลังปิดทางถอย (ตอนเปิด RLS)
    final newId = inserted?['id_user'];
    if (newId != null) {
      final password = (data['password'] ?? '').toString().trim().isEmpty
          ? '123456'
          : data['password'].toString().trim();
      try {
        await adminCreateAuthAccount(newId, password);
      } catch (e) {
        // แถวใน Teachers สร้างสำเร็จแล้ว จึงไม่ควรล้มทั้งรายการ
        // แต่ต้องบอกให้ผู้ใช้รู้ว่ายังล็อกอินไม่ได้จนกว่าจะแก้
        throw Exception(
            'บันทึกข้อมูลครูเรียบร้อย แต่สร้างบัญชีเข้าสู่ระบบไม่สำเร็จ: $e\n'
            'ให้แอดมินกด "รีเซ็ตรหัสผ่าน" ของครูคนนี้อีกครั้งเพื่อสร้างบัญชีครับ');
      }
    }
  }

  // แก้ไขข้อมูลครูครับ 🏎️🏆
  Future<void> updateUser(String docId, Map<String, dynamic> data) async {
    await updateTeacherById(docId, data);
  }

  /// แปลงข้อมูลครูจากหน้าจอ (ที่ส่งตำแหน่ง/กลุ่มสาระ/สิทธิ์มาเป็น "ชื่อภาษาไทย")
  /// ให้เป็น record ที่ตาราง Teachers รับได้จริง (FK เป็นตัวเลข)
  ///
  /// ใช้ร่วมกันทั้งตอนเพิ่มผู้ใช้ใหม่และตอนแก้ไข เพื่อไม่ให้ตรรกะสองทางหลุดจากกัน
  Future<Map<String, dynamic>> _teacherRecordForSupabase(
      SupabaseClient client, Map<String, dynamic> newData) async {
    final rec = Map<String, dynamic>.from(newData);
    rec.remove('id');
    rec.remove('docId');
    // Teachers ใช้ชื่อคอลัมน์ updated_at (snake_case)
    if (rec.containsKey('updatedAt')) {
      rec['updated_at'] = rec.remove('updatedAt');
    }

    // ถ้ามีการส่งตำแหน่ง/กลุ่มสาระ/สิทธิ์เป็นชื่อ ให้แปลงเป็น FK
    if (rec.containsKey('position')) {
      final posName = rec['position']?.toString().trim();
      if (posName != null && posName.isNotEmpty) {
        final posRows = await client
            .from('positions')
            .select('ID_Positions')
            .ilike('positionName', posName)
            .limit(1);
        if ((posRows as List).isNotEmpty) {
          rec['id_position'] = posRows.first['ID_Positions'];
        }
      }
      rec.remove('position'); // Teachers เก็บเป็น FK id_position เท่านั้น
    }
    if (rec.containsKey('department')) {
      final deptName = rec['department']?.toString().trim();
      if (deptName != null && deptName.isNotEmpty) {
        final deptRows = await client
            .from('departments')
            .select('ID_Departments')
            .ilike('DepartmentsName', deptName)
            .limit(1);
        if ((deptRows as List).isNotEmpty) {
          rec['id_department'] = deptRows.first['ID_Departments'];
        }
      }
      rec.remove('department'); // Teachers เก็บเป็น FK id_department เท่านั้น
    }
    if (rec.containsKey('role')) {
      final roleName = rec['role']?.toString().trim();
      if (roleName != null && roleName.isNotEmpty) {
        final roleRows = await client
            .from('roles')
            .select('ID_Roles')
            .ilike('Accessrights', roleName)
            .limit(1);
        if ((roleRows as List).isNotEmpty) {
          rec['id_role'] = roleRows.first['ID_Roles'];
          rec['id_permission'] = roleRows.first['ID_Roles'];
        }
      }
    }
    // ตำแหน่งงานบริหาร: UI ส่งมาเป็นชื่อภาษาไทย ต้องแปลงเป็น FK id_adminrole
    // (ถ้าเลือก 'ไม่มีตำแหน่งบริหาร' หรือเว้นว่าง ให้ล้างค่าเป็น null)
    if (rec.containsKey('ตำแหน่งงานบริหาร') || rec.containsKey('adminRole')) {
      final adminName =
          (rec['ตำแหน่งงานบริหาร'] ?? rec['adminRole'])?.toString().trim();
      rec.remove('ตำแหน่งงานบริหาร');
      rec.remove('adminRole');
      if (adminName == null ||
          adminName.isEmpty ||
          adminName == 'ไม่มีตำแหน่งบริหาร') {
        rec['id_adminrole'] = null;
      } else {
        final adminRows = await client
            .from('adminroles')
            .select('ID_AdminRoles')
            .ilike('AdminRolesName', adminName)
            .limit(1);
        if ((adminRows as List).isNotEmpty) {
          rec['id_adminrole'] = adminRows.first['ID_AdminRoles'];
        }
      }
    }

    // วิทยฐานะ: ตรวจสอบและแปลงทั้ง ID_Academics และ academicStanding
    if (rec.containsKey('academicStanding') ||
        rec.containsKey('ID_Academics') ||
        rec.containsKey('วิทยฐานะ')) {
      final rankName =
          (rec['academicStanding'] ?? rec['วิทยฐานะ'] ?? rec['ID_Academics'])
              ?.toString()
              .trim();
      if (rankName != null && rankName.isNotEmpty) {
        final rankRows = await client
            .from('academics')
            .select('ID_Academics, AcademicsName')
            .or('AcademicsName.ilike.$rankName,ID_Academics.eq.${int.tryParse(rankName) ?? -1}')
            .limit(1);
        if ((rankRows as List).isNotEmpty) {
          rec['ID_Academics'] = rankRows.first['ID_Academics'];
        }
      }
      rec.remove('academicStanding');
      rec.remove('วิทยฐานะ');
    }

    return rec;
  }

  Future<void> updateTeacherById(
      String docId, Map<String, dynamic> newData) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    final parsedId = int.tryParse(docId);
    final rec = await _teacherRecordForSupabase(client, newData);

    // ตัดคอลัมน์ที่ตาราง Teachers ไม่มีจริงออกทีละตัวแล้วลองใหม่
    // (เดิมลองใหม่ได้ครั้งเดียว ถ้ามีคีย์ส่วนเกินมากกว่าหนึ่งตัวจะล้มทันที)
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (parsedId != null) {
          await client.from('Teachers').update(rec).eq('id_user', parsedId);
        } else {
          await client.from('Teachers').update(rec).eq('firebase_uid', docId);
        }
        return;
      } on PostgrestException catch (e) {
        final key = _missingColumnFromError(e.message);
        if (key == null || !rec.containsKey(key)) rethrow;
        debugPrint('⚠️  Teachers ไม่มีคอลัมน์ $key — ข้ามคอลัมน์นี้');
        rec.remove(key);
        if (rec.isEmpty) return;
      }
    }
  }

  Future<void> updateTeacherData(
      String fullName, Map<String, dynamic> newData) async {
    final client = _supabaseIfReady;
    if (client == null) return;
    final rows = await client
        .from('Teachers')
        .select('id_user, firebase_uid')
        .eq('fullName', fullName)
        .limit(1);
    if ((rows as List).isNotEmpty) {
      final docId =
          (rows.first['id_user'] ?? rows.first['firebase_uid']).toString();
      await updateTeacherById(docId, newData);
    }
  }

  // 🚀 ลบข้อมูลครู (Supabase-only)
  Future<void> deleteUser(String docId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    final parsedId = int.tryParse(docId);
    if (parsedId != null) {
      await client.from('Teachers').delete().eq('id_user', parsedId);
    } else {
      await client.from('Teachers').delete().eq('firebase_uid', docId);
    }
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

  // ดึงเหตุผลการลาที่ตั้งไว้เป็นตัวเลือกด่วน — Supabase
  Future<List<String>> getLeaveReasons() async {
    return getLeaveReasonsFromSupabase();
  }

  Future<List<String>> getLeaveReasonsFromSupabase() async {
    return _getMasterListFromSupabase(
        'LeaveReasons', ['reasonName', 'reasonname', 'name', 'value']);
  }

  /// ดึงเหตุผลการลาที่ครูเคยกรอกไว้จริงในตาราง Leaves (ไม่ซ้ำ)
  /// ใช้สำหรับวิเคราะห์หาเหตุผลใหม่มาเติมในตาราง LeaveReasons
  Future<List<String>> getUsedLeaveReasonsFromLeaves() async {
    final client = _supabaseIfReady;
    if (client == null) return [];
    try {
      final rows = await client.from('Leaves').select('reason');
      final seen = <String>{};
      final result = <String>[];
      for (final row in (rows as List)) {
        final value = (row['reason'] ?? '').toString().trim();
        if (value.isEmpty) continue;
        if (seen.add(value)) result.add(value);
      }
      return result;
    } catch (e) {
      debugPrint('❌ getUsedLeaveReasonsFromLeaves error: $e');
      return [];
    }
  }

  /// เพิ่มเหตุผลการลาใหม่ลงตาราง LeaveReasons
  /// (PK เป็น identity GENERATED ALWAYS จึงไม่ส่งค่า id ไปเอง)
  Future<void> addLeaveReasons(List<String> names) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    if (names.isEmpty) return;
    await client
        .from('LeaveReasons')
        .insert(names.map((n) => {'reasonName': n}).toList());
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
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await _insertWithColumnRetry(client, 'FiscalRounds', {
      ...data,
      'isActive': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // 🚀 ลบรอบงบประมาณ (Supabase-only) — PK คือ id_year ไม่ใช่ id
  Future<void> deleteFiscalRound(String docId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client
        .from('FiscalRounds')
        .delete()
        .eq(primaryKeyFor('FiscalRounds'), _pkValue(docId));
  }

  // ดึงรายการรอบงบประมาณที่ตรงกับปฏิทินปัจจุบัน (Auto-match) — Supabase
  Future<Map<String, dynamic>?> getActiveFiscalRound() async {
    return getActiveFiscalRoundFromSupabase();
  }

  // ดึงรายการรอบงบประมาณทั้งหมด — Supabase
  Future<List<Map<String, dynamic>>> getFiscalRounds() async {
    return getFiscalRoundsFromSupabase();
  }

  /// แปลงวันที่รูปแบบใดๆ (ISO YYYY-MM-DD หรือ DD/MM/YYYY) เป็น DD/MM/YYYY (พ.ศ.)
  static String formatToThaiSlashDate(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';

    final slashParts = s.split('/');
    if (slashParts.length == 3) {
      final d = int.tryParse(slashParts[0]);
      final m = int.tryParse(slashParts[1]);
      var y = int.tryParse(slashParts[2]);
      if (d != null && m != null && y != null) {
        if (y < 2400) y += 543;
        return '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/$y';
      }
    }

    final date = DateTime.tryParse(s);
    if (date != null) {
      final y = date.year < 2400 ? date.year + 543 : date.year;
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$y';
    }

    return s;
  }

  /// แปลงเวลาจาก DB (เช่น '09:41:00') → รูปแบบไทย '09:41 น.'
  static String formatToThaiTime(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    if (s.contains('น.')) return s; // ข้อมูลเก่าที่เป็นข้อความอยู่แล้ว
    final p = s.split(':');
    if (p.length >= 2) {
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      if (h != null && m != null) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} น.';
      }
    }
    return s;
  }

  /// วันที่สำหรับเขียนลงคอลัมน์ date ของ Supabase (ค.ศ. รูปแบบ ISO)
  static String toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// เวลาสำหรับเขียนลงคอลัมน์ time ของ Supabase
  static String toIsoTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

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
    if (_supabaseIfReady == null) {
      throw StateError('Supabase not initialized');
    }
    final results = await Future.wait([
      _fetchFiscalRoundsFromSupabase(throwOnError: true),
      getLeaveRequestsFromSupabase(throwOnError: true),
      getLeaveTypesRawFromSupabase(throwOnError: true),
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
    await client.from('Leaves').update({
      'receiveNumber': null,
      'receiveDate': null,
      'receiveTime': null
    }).not('receiveNumber', 'is', null);
  }

  /// แปลงข้อมูลใบลาจากหน้าจอ → คอลัมน์จริงของตาราง Leaves
  ///
  /// หน้าจอส่ง ชื่อครู / ประเภทลา / ปีงบ มาเป็น "ข้อความ" แต่ตารางเก็บเป็น FK
  /// และยังส่งบางคีย์ที่ไม่มีคอลัมน์รองรับ (เช่น phone) มาด้วย ถ้าส่งเข้า
  /// Supabase ตรง ๆ จะได้ error PGRST204 "Could not find the 'x' column"
  ///
  /// คืนเฉพาะคีย์ที่ผู้เรียกส่งมาจริง จะได้ใช้กับ update ได้โดยไม่ไปล้าง
  /// ค่าคอลัมน์อื่นที่ผู้ใช้ไม่ได้แก้ 🥇🏆
  Future<Map<String, dynamic>> _leaveRecordForSupabase(
      SupabaseClient client, Map<String, dynamic> data) async {
    final record = <String, dynamic>{};

    // ชื่อครู → id_user
    final fullName = data['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) {
      final row = await client
          .from('Teachers')
          .select('id_user')
          .eq('fullName', fullName)
          .limit(1)
          .maybeSingle();
      final idUser = row?['id_user'];
      if (idUser != null) record['id_user'] = idUser;
    }

    // ประเภทการลา → id_leaveType (เทียบแบบยืดหยุ่น เช่น "ลาป่วย" กับ "ป่วย")
    final leaveTypeName = data['leaveType']?.toString().trim() ?? '';
    if (leaveTypeName.isNotEmpty) {
      final ltRows =
          await client.from('LeaveTypes').select('id_leaveType, leaveName');
      for (final lt in ltRows) {
        final name = (lt['leaveName'] ?? '').toString();
        if (name.isEmpty) continue;
        if (name == leaveTypeName ||
            name.contains(leaveTypeName) ||
            leaveTypeName.contains(name)) {
          record['id_leaveType'] = lt['id_leaveType'];
          break;
        }
      }
    }

    // ปีงบประมาณ → id_year
    final yearText = data['year']?.toString().trim() ?? '';
    if (yearText.isNotEmpty) {
      final row = await client
          .from('FiscalRounds')
          .select('id_year')
          .eq('year', yearText)
          .limit(1)
          .maybeSingle();
      final idYear = row?['id_year'];
      if (idYear != null) record['id_year'] = idYear;
    }

    // เผื่อผู้เรียกส่ง FK มาให้ตรง ๆ อยู่แล้ว
    for (final key in ['id_user', 'id_leaveType', 'id_year']) {
      if (data[key] != null) record[key] = data[key];
    }

    // วันที่: หน้าจอส่งเป็น พ.ศ. (dd/MM/yyyy) แต่คอลัมน์เป็น date ต้องแปลงก่อน
    if (data.containsKey('startDate')) {
      final iso = _thaiDateToIso(data['startDate']?.toString());
      record['startDate'] = iso;
      record['leaveDate'] = iso; // leaveDate ยึดตามวันเริ่มลาเสมอ
    }
    if (data.containsKey('endDate')) {
      record['endDate'] = _thaiDateToIso(data['endDate']?.toString());
    }

    // คอลัมน์ที่ชื่อตรงกันอยู่แล้ว เอามาเฉพาะที่ส่งมาจริง
    const sameNameColumns = [
      'reason',
      'status',
      'totalDays',
      'isHalfDay',
      'halfDayPeriod',
      'medicalCertificate',
      'receiveNumber',
      'receiveDate',
      'receiveTime',
    ];
    for (final key in sameNameColumns) {
      if (data.containsKey(key)) record[key] = data[key];
    }

    return record;
  }

  // 🚀 ส่งใบลาเข้าระบบ (Supabase-only) 🏎️🏁
  Future<void> submitLeaveRequest(Map<String, dynamic> data) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');

    final record = await _leaveRecordForSupabase(client, data);
    record['status'] = data['status'] ?? 'รอพิจารณา';
    record['timestamp'] = DateTime.now().toIso8601String();
    record.removeWhere((_, v) => v == null);

    await client.from('Leaves').insert(record);
  }

  // แก้ไขใบลาครับ 🏎️🏁
  // หมายเหตุ: Leaves ใช้ primary key ชื่อ id_leaves (ไม่ใช่ id)
  // จึงต้อง update ตรง ๆ แทนการ upsert ด้วยคีย์ 'id'
  Future<void> updateLeaveRequest(
      String requestId, Map<String, dynamic> data) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');

    final record = await _leaveRecordForSupabase(client, data);
    record['lastUpdatedAt'] = DateTime.now().toUtc().toIso8601String();
    if (record.isEmpty) return;

    await client
        .from('Leaves')
        .update(record)
        .eq('id_leaves', _pkValue(requestId));
  }

  // 🚀 นับเลขรับจาก Supabase
  Future<int> generateReceiveNumber() async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    final fiscalYear = DateTime.now().year + 543;

    // Leaves ไม่มีคอลัมน์ year — ต้องหา id_year จาก FiscalRounds ก่อน
    final yearRow = await client
        .from('FiscalRounds')
        .select('id_year')
        .eq('year', fiscalYear.toString())
        .limit(1)
        .maybeSingle();
    final idYear = yearRow?['id_year'];

    var query = client.from('Leaves').select('receiveNumber');
    if (idYear != null) query = query.eq('id_year', idYear);
    final rows = await query.not('receiveNumber', 'is', null);
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
        !fileUrl.contains('drive.google.com')) {
      return;
    }

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
        debugPrint("Drive Delete Result: ${resData['status']}");
      }
    } catch (e) {
      debugPrint("Error deleting drive file: $e");
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
          if (year < 2100) {
            year += 543; // 🛡️ รองรับกรณีฐานข้อมูลดันเก็บเป็นปี ค.ศ. 🥇🏆
          }
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
  static bool lineNotifyEnabled = false;

  Future<bool> sendLineNotification(Map<String, dynamic> leaveData) async {
    if (!lineNotifyEnabled) {
      debugPrint("🔕 LINE Notification disabled (session toggle off)");
      return false;
    }
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

  Future<Map<String, dynamic>> _getWebJsonp(String url) =>
      platform.jsonpGet(url);

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

      platform.fireAndForgetGet(url);
    } catch (e) {
      debugPrint("❌ Status Notification Error: $e");
    }
  }

  Future<Map<String, dynamic>?> searchTeacherByUid(String uid) async {
    final client = _supabaseIfReady;
    if (client == null) return null;
    final rows =
        await client.from('Teachers').select().eq('firebase_uid', uid).limit(1);
    if ((rows as List).isNotEmpty) {
      final enriched =
          await enrichTeacher(Map<String, dynamic>.from(rows.first as Map));
      return {
        ...enriched,
        'docId':
            (rows.first['id_user'] ?? rows.first['firebase_uid']).toString()
      };
    }
    return null;
  }

  /// หาข้อมูลครูจากตัวระบุที่มีอยู่ ไล่จากที่แม่นที่สุดก่อน
  /// (id_user → username → fullName) ใช้ตอนต้องรีเฟรชข้อมูลผู้ใช้ที่ล็อกอินอยู่
  /// เพราะการเทียบด้วย fullName อย่างเดียวพลาดได้ถ้าชื่อในเครื่องกับในฐานข้อมูล
  /// ไม่ตรงกันเป๊ะ (เช่น มีช่องว่างเกิน หรือเพิ่งเปลี่ยนชื่อ)
  Future<Map<String, dynamic>?> findTeacher({
    dynamic idUser,
    String? username,
    String? fullName,
  }) async {
    final client = _supabaseIfReady;
    if (client == null) return null;

    Future<Map<String, dynamic>?> byColumn(String column, dynamic value) async {
      if (value == null || value.toString().trim().isEmpty) return null;
      try {
        final rows =
            await client.from('Teachers').select().eq(column, value).limit(1);
        if ((rows as List).isEmpty) return null;
        final enriched =
            await enrichTeacher(Map<String, dynamic>.from(rows.first as Map));
        return {
          ...enriched,
          'docId':
              (rows.first['id_user'] ?? rows.first['firebase_uid']).toString()
        };
      } catch (e) {
        debugPrint('⚠️  findTeacher($column) error: $e');
        return null;
      }
    }

    final id = idUser is int ? idUser : int.tryParse(idUser?.toString() ?? '');
    return await byColumn('id_user', id) ??
        await byColumn('username', username?.trim()) ??
        await byColumn('fullName', fullName?.trim());
  }

  /// ผู้ใช้ปัจจุบันมีตำแหน่งบริหารที่ยังอยู่ในตาราง adminroles หรือไม่
  Future<bool> currentUserHasAdminRole() async {
    final client = _supabaseIfReady;
    final authUid = client?.auth.currentUser?.id;
    if (client == null || authUid == null || authUid.isEmpty) return false;

    try {
      final teacher = await client
          .from('Teachers')
          .select('id_adminrole')
          .eq('auth_uid', authUid)
          .maybeSingle();
      final adminRoleId = teacher?['id_adminrole'];
      if (adminRoleId == null || adminRoleId.toString().trim().isEmpty) {
        return false;
      }

      final adminRole = await client
          .from('adminroles')
          .select('ID_AdminRoles')
          .eq('ID_AdminRoles', adminRoleId)
          .maybeSingle();
      return adminRole != null;
    } catch (e) {
      debugPrint('currentUserHasAdminRole error: $e');
      return false;
    }
  }

  /// เติมชื่อจริงของ ตำแหน่ง/กลุ่มสาระ/วิทยฐานะ/สิทธิ์ ให้แถวครูหนึ่งแถว
  ///
  /// ตาราง Teachers เก็บค่าพวกนี้เป็น FK ตัวเลข (id_position, id_department,
  /// ID_Academics, id_role, id_adminrole) หน้าจอที่ดึงแถวดิบไปใช้ตรง ๆ จึงได้
  /// ค่าว่างแล้วแสดงเป็น "-" เช่นการ์ดผู้ยื่นใบลา
  ///
  /// getUsersFromSupabase() แปลงให้อยู่แล้วโดยโหลดตาราง master ทั้งใบ แต่สำหรับ
  /// ครูคนเดียวใช้วิธียิงถามเฉพาะ id ที่ต้องการ จะเบากว่ามาก
  Future<Map<String, dynamic>> enrichTeacher(Map<String, dynamic> row) async {
    final client = _supabaseIfReady;
    final r = Map<String, dynamic>.from(row);
    if (client == null) return _fromSupabaseTeacher(r);

    Future<String> nameOf(
        String table, String idColumn, String nameColumn, dynamic id) async {
      if (id == null || id.toString().trim().isEmpty) return '';
      try {
        final found = await client
            .from(table)
            .select(nameColumn)
            .eq(idColumn, id)
            .limit(1)
            .maybeSingle();
        return (found?[nameColumn] ?? '').toString().trim();
      } catch (e) {
        debugPrint('⚠️  enrichTeacher: อ่าน $table ไม่สำเร็จ: $e');
        return '';
      }
    }

    /// ค่าที่ติดมากับแถวอยู่แล้วให้ชนะ FK ที่เพิ่งไปหามา
    String pick(dynamic existing, String resolved) {
      final value = (existing ?? '').toString().trim();
      if (value.isNotEmpty && value != '-' && value != '---เลือก---') {
        return value;
      }
      return resolved;
    }

    final names = await Future.wait([
      nameOf('positions', 'ID_Positions', 'positionName', r['id_position']),
      nameOf('departments', 'ID_Departments', 'DepartmentsName',
          r['id_department']),
      nameOf('roles', 'ID_Roles', 'Accessrights', r['id_role']),
      nameOf('academics', 'ID_Academics', 'AcademicsName',
          r['ID_Academics'] ?? r['id_academic'] ?? r['id_academics']),
      nameOf(
          'adminroles', 'ID_AdminRoles', 'AdminRolesName', r['id_adminrole']),
    ]);

    final role = pick(r['role'], names[2]);
    final academic = pick(r['academicStanding'] ?? r['วิทยฐานะ'], names[3]);

    return _fromSupabaseTeacher({
      ...r,
      'position': pick(r['position'], names[0]),
      'department': pick(r['department'], names[1]),
      'role': role,
      'permission': pick(r['permission'], role),
      'academicStanding': academic,
      'วิทยฐานะ': academic,
      'ตำแหน่งงานบริหาร': pick(r['ตำแหน่งงานบริหาร'], names[4]),
    });
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
      return {
        ...rows.first,
        'docId':
            (rows.first['id_user'] ?? rows.first['firebase_uid']).toString()
      };
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
        'userAgent': platform.platformUserAgent,
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

      // LoginLogs เก็บแค่ id_user (FK) ไม่มีชื่อ/username อยู่ในตาราง
      // จึงต้องดึง Teachers มาเทียบเอง ไม่งั้นหน้าประวัติการเข้าใช้งาน
      // จะแสดง 'ไม่ระบุชื่อ' ทุกแถว
      final teacherById = <String, Map<String, dynamic>>{};
      final roleNameById = <String, String>{};
      try {
        final results = await Future.wait([
          client.from('Teachers').select('id_user,fullName,username,id_role'),
          client.from('roles').select('ID_Roles,Accessrights'),
        ]);
        for (final t in results[0] as List) {
          final t2 = Map<String, dynamic>.from(t as Map);
          final id = t2['id_user']?.toString();
          if (id != null && id.isNotEmpty) teacherById[id] = t2;
        }
        for (final r in results[1] as List) {
          final r2 = Map<String, dynamic>.from(r as Map);
          final id = r2['ID_Roles']?.toString();
          final name = r2['Accessrights']?.toString().trim();
          if (id != null && name != null && name.isNotEmpty) {
            roleNameById[id] = name;
          }
        }
      } catch (e) {
        debugPrint('⚠️  getLoginLogsFromSupabase: ดึงรายชื่อครูไม่สำเร็จ: $e');
      }

      return (rows as List).map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        final teacher = teacherById[r['id_user']?.toString() ?? ''];
        final fullName =
            (r['fullname'] ?? r['fullName'] ?? teacher?['fullName'] ?? '')
                .toString()
                .trim();
        final username =
            (r['username'] ?? teacher?['username'] ?? '').toString().trim();
        final role = (r['role'] ??
                roleNameById[teacher?['id_role']?.toString() ?? ''] ??
                '')
            .toString()
            .trim();
        return {
          ...r,
          'id': (r['id'] ?? r['id_LoginLogs'])?.toString() ?? '',
          'fullName': fullName,
          'username': username,
          if (role.isNotEmpty) 'role': role,
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
      final futureLeaves = client.from('Leaves').select();
      final futureTeachers =
          client.from('Teachers').select('id_user, fullName');
      final futureLeaveTypes = getLeaveTypesRawFromSupabase();
      final results =
          await Future.wait([futureLeaves, futureTeachers, futureLeaveTypes]);
      final rows = results[0] as List;
      final teachers = results[1] as List;
      final leaveTypes = results[2];

      final userMap = <String, Map<String, dynamic>>{};
      for (final t in teachers) {
        final uid = t['id_user']?.toString();
        if (uid != null && uid.isNotEmpty) {
          userMap[uid] = Map<String, dynamic>.from(t as Map);
        }
      }

      final typeMap = <String, String>{};
      for (final t in leaveTypes) {
        final tid = (t['id_leaveType'] ?? t['id'])?.toString();
        final name =
            (t['leaveName'] ?? t['name'] ?? t['Value'] ?? '').toString();
        if (tid != null && tid.isNotEmpty && name.isNotEmpty) {
          typeMap[tid] = name;
        }
      }

      var mapped = rows.map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        final userId = r['id_user']?.toString() ?? '';
        final typeId = r['id_leaveType']?.toString() ?? '';
        final teacher = userMap[userId] ?? {};
        final resolvedName =
            (teacher['fullName'] ?? teacher['name'] ?? '').toString();
        final resolvedType = (typeMap[typeId] ?? '').toString();
        return _fromSupabaseLeave({
          ...r,
          'fullName': resolvedName,
          'leaveType': resolvedType,
        });
      }).toList();

      if (fullName != null && fullName != 'ผู้ดูแลระบบ') {
        final target = fullName.trim();
        mapped = mapped
            .where((l) => (l['fullName'] ?? '').toString().trim() == target)
            .toList();
      }

      return mapped;
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

      platform.fireAndForgetGet(url);
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
    final academicVal = r['academicStanding'] ??
        r['academicstanding'] ??
        r['วิทยฐานะ'] ??
        r['academic'] ??
        '';
    return {
      ...r,
      'id': docId,
      'fullName': r['fullname'] ?? r['fullName'] ?? r['name'] ?? '',
      'ID_Academics':
          r['ID_Academics'] ?? r['id_academic'] ?? r['id_academics'],
      'academicStanding': academicVal,
      'วิทยฐานะ': academicVal,
      'position': r['position'] ?? '',
      'department': r['department'] ?? '',
      'role': r['role'] ?? '',
      'permission': r['permission'] ?? r['role'] ?? '',
      'phone': r['phone'] ?? '',
      'profileImage': [
        r['profileImage'],
        r['profileimage'],
        r['photoUrl'],
        r['profilePhoto']
      ]
          .map((value) => value?.toString().trim() ?? '')
          .firstWhere((value) => value.isNotEmpty, orElse: () => ''),
    };
  }

  /// แปลง row จาก Supabase Leaves → format ที่ UI คาดหวัง
  static Map<String, dynamic> _fromSupabaseLeave(Map<dynamic, dynamic> row) {
    final r = Map<String, dynamic>.from(row);
    final id =
        (r['id'] ?? r['id_leaves'] ?? r['requestId'] ?? r['requestid'] ?? '')
            .toString();
    final academicVal =
        r['academicstanding'] ?? r['academicStanding'] ?? r['วิทยฐานะ'] ?? '';
    return {
      ...r,
      'id': id,
      'requestId': id.isNotEmpty ? id : (r['id']?.toString() ?? ''),
      'fullName': r['fullname'] ?? r['fullName'] ?? '',
      'leaveType': r['leavetype'] ?? r['leaveType'] ?? '',
      'startDate':
          formatToThaiSlashDate(r['startdate'] ?? r['startDate'] ?? ''),
      'endDate': formatToThaiSlashDate(r['enddate'] ?? r['endDate'] ?? ''),
      'leaveDate':
          formatToThaiSlashDate(r['leavedate'] ?? r['leaveDate'] ?? ''),
      'totalDays': r['totaldays'] ?? r['totalDays'] ?? 0,
      'isHalfDay': r['ishalfday'] ?? r['isHalfDay'] ?? false,
      'halfDayPeriod': r['halfdayperiod'] ?? r['halfDayPeriod'] ?? '',
      'createdAt': r['createdat'] ?? r['createdAt'] ?? r['timestamp'] ?? '',
      'medicalCertificate':
          r['medicalcertificate'] ?? r['medicalCertificate'] ?? '',
      'academicStanding': academicVal,
      'ID_Academics':
          r['ID_Academics'] ?? r['id_academic'] ?? r['id_academics'],
      'วิทยฐานะ': academicVal,
      'receiveNumber': r['receivenumber'] ?? r['receiveNumber'],
      'receiveDate':
          formatToThaiSlashDate(r['receivedate'] ?? r['receiveDate'] ?? ''),
      'receiveTime':
          formatToThaiTime(r['receivetime'] ?? r['receiveTime'] ?? ''),
      'lastUpdatedAt': r['lastupdatedat'] ?? r['lastUpdatedAt'],
    };
  }

  /// แปลง row จาก Supabase FiscalRounds → format ที่ UI คาดหวัง
  static Map<String, dynamic> _fromSupabaseFiscalRound(
      Map<dynamic, dynamic> row) {
    final r = Map<String, dynamic>.from(row);
    final rawId =
        (r['id'] ?? r['id_year'] ?? r['id_Year'] ?? '').toString().trim();
    final effectiveId =
        rawId.isNotEmpty ? rawId : '${r['year'] ?? ''}_${r['round'] ?? ''}';
    return {
      ...r,
      'id': effectiveId,
      'id_year': r['id_year'] ?? r['id_Year'] ?? r['id'],
      'year': r['year'],
      'round': r['round'],
      'startDate':
          formatToThaiSlashDate(r['startdate'] ?? r['startDate'] ?? ''),
      'endDate': formatToThaiSlashDate(r['enddate'] ?? r['endDate'] ?? ''),
      'isActive': r['isactive'] ?? r['isActive'] ?? false,
      'createdAt': r['createdat'] ?? r['createdAt'] ?? '',
    };
  }

  // ── Teachers ────────────────────────────────────────────────────

  /// อ่านค่าจาก row โดยเทียบชื่อคีย์แบบไม่สนตัวพิมพ์เล็ก/ใหญ่
  static dynamic _pickValueIgnoreCase(
      Map<String, dynamic> row, List<String> candidates) {
    for (final key in row.keys) {
      final normalized = key.toLowerCase();
      if (candidates.contains(normalized)) {
        final value = row[key];
        if (value != null && value.toString().trim().isNotEmpty) return value;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUsersFromSupabase() async {
    final client = _supabaseIfReady;
    if (client == null) {
      debugPrint('⚠️  Supabase not ready — falling back to Firebase getUsers');
      return getUsers();
    }
    try {
      final futureTeachers = client.from('Teachers').select();
      final futureDepts = client.from('departments').select();
      final futurePos = client.from('positions').select();
      final futureRoles = client.from('roles').select();
      final futureAcademics = client.from('academics').select();
      final futureAdminRoles = client.from('adminroles').select();

      final results = await Future.wait([
        futureTeachers,
        futureDepts,
        futurePos,
        futureRoles,
        futureAcademics,
        futureAdminRoles,
      ]);

      final rows = results[0] as List;
      final depts = results[1] as List;
      final positions = results[2] as List;
      final roles = results[3] as List;
      final academics = results[4] as List;
      final adminRoles = results[5] as List;

      final deptMap = <String, String>{};
      for (final d in depts) {
        final id = (d['ID_Departments'] ?? d['id'])?.toString();
        final name = (d['DepartmentsName'] ?? d['name'] ?? '').toString();
        if (id != null && name.isNotEmpty) deptMap[id] = name;
      }

      final posMap = <String, String>{};
      for (final p in positions) {
        final id = (p['ID_Positions'] ?? p['id'])?.toString();
        final name = (p['positionName'] ?? p['name'] ?? '').toString();
        if (id != null && name.isNotEmpty) posMap[id] = name;
      }

      final roleMap = <String, String>{};
      for (final r in roles) {
        final id = (r['ID_Roles'] ?? r['id'])?.toString();
        final name = (r['Accessrights'] ?? r['name'] ?? '').toString();
        if (id != null && name.isNotEmpty) roleMap[id] = name;
      }

      final academicMap = <String, String>{};
      for (final a in academics) {
        final id = (a['ID_Academics'] ?? a['id'])?.toString();
        final name =
            (a['AcademicsName'] ?? a['academicsname'] ?? a['name'] ?? '')
                .toString();
        if (id != null && name.isNotEmpty) academicMap[id] = name;
      }

      final adminRoleMap = <String, String>{};
      for (final ar in adminRoles) {
        final row = Map<String, dynamic>.from(ar as Map);
        final id = _pickValueIgnoreCase(
            row, const ['id_adminroles', 'id_adminrole', 'id'])?.toString();
        final name = _pickValueIgnoreCase(
                row, const ['adminrolesname', 'adminrolename', 'name', 'value'])
            ?.toString()
            .trim();
        if (id != null && name != null && name.isNotEmpty) {
          adminRoleMap[id] = name;
        }
      }

      final list = rows.map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        final deptId = r['id_department']?.toString() ?? '';
        final posId = r['id_position']?.toString() ?? '';
        final roleId = r['id_role']?.toString() ?? '';
        final academicId =
            (r['ID_Academics'] ?? r['id_academic'] ?? r['id_academics'])
                    ?.toString() ??
                '';
        // ชื่อคอลัมน์ FK ของตำแหน่งบริหารสะกดไม่เหมือนกันในแต่ละชุดข้อมูล
        // (id_adminrole / id_adminRole / id_AdminRoles / ID_AdminRoles / ...)
        // จึงหาแบบไม่สนตัวพิมพ์ เพื่อไม่ให้ตำแหน่งหลุดหายตอนขึ้นฟอร์มใบลา
        final adminRoleId = _pickValueIgnoreCase(
                    r, const ['id_adminrole', 'id_adminroles', 'id_admin_role'])
                ?.toString() ??
            '';

        final resolvedDept =
            (r['department'] ?? deptMap[deptId] ?? '').toString();
        final resolvedPos = (r['position'] ?? posMap[posId] ?? '').toString();
        final resolvedRole = (r['role'] ?? roleMap[roleId] ?? '').toString();
        final resolvedAcademic = (r['academicStanding'] ??
                r['academicstanding'] ??
                academicMap[academicId] ??
                '')
            .toString();

        final resolvedAdminRole =
            (r['ตำแหน่งงานบริหาร'] ?? adminRoleMap[adminRoleId] ?? '')
                .toString()
                .trim();

        return _fromSupabaseTeacher({
          ...r,
          'department': resolvedDept,
          'position': resolvedPos,
          'role': resolvedRole,
          'permission': r['permission'] ?? resolvedRole,
          'ID_Academics':
              r['ID_Academics'] ?? r['id_academic'] ?? r['id_academics'],
          'academicStanding': resolvedAcademic.isNotEmpty
              ? resolvedAcademic
              : (academicMap[academicId] ?? ''),
          'วิทยฐานะ': resolvedAcademic.isNotEmpty
              ? resolvedAcademic
              : (academicMap[academicId] ?? ''),
          'ตำแหน่งงานบริหาร': resolvedAdminRole,
        });
      }).toList();

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
      {int? year, bool throwOnError = false}) async {
    final client = _supabaseIfReady;
    // Supabase ยังไม่พร้อม — คืนค่าว่างไปก่อน
    // (ของเดิมเรียกฟังก์ชันที่เรียกตัวเองกลับมา กลายเป็นวนไม่รู้จบจนแอปค้าง)
    if (client == null) return [];
    try {
      final futureTeachers =
          client.from('Teachers').select('id_user, fullName');
      final futureLeaveTypes =
          getLeaveTypesRawFromSupabase(throwOnError: throwOnError);
      final futureFiscalRounds = throwOnError
          ? _fetchFiscalRoundsFromSupabase(throwOnError: true)
          : getFiscalRoundsFromSupabase();
      var query = client.from('Leaves').select();
      final results = await Future.wait(
          [query, futureTeachers, futureLeaveTypes, futureFiscalRounds]);
      final rows = results[0] as List;
      final teachers = results[1] as List;
      final leaveTypes = results[2];
      final fiscalRounds = results[3];

      final userMap = <String, Map<String, dynamic>>{};
      for (final t in teachers) {
        final uid = t['id_user']?.toString();
        if (uid != null && uid.isNotEmpty) {
          userMap[uid] = Map<String, dynamic>.from(t as Map);
        }
      }

      final typeMap = <String, String>{};
      for (final t in leaveTypes) {
        final tid = (t['id_leaveType'] ?? t['id'])?.toString();
        final name =
            (t['leaveName'] ?? t['name'] ?? t['Value'] ?? '').toString();
        if (tid != null && tid.isNotEmpty && name.isNotEmpty) {
          typeMap[tid] = name;
        }
      }

      final yearMap = <String, dynamic>{};
      for (final fr in fiscalRounds) {
        final id = (fr['id_year'] ?? fr['id'])?.toString();
        if (id != null && id.isNotEmpty) yearMap[id] = fr['year'];
      }

      return rows.map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        final userId = r['id_user']?.toString() ?? '';
        final typeId = r['id_leaveType']?.toString() ?? '';
        final yearId = r['id_year']?.toString() ?? '';
        final teacher = userMap[userId] ?? {};
        final resolvedName = (r['fullname'] ??
                r['fullName'] ??
                teacher['fullName'] ??
                teacher['name'] ??
                '')
            .toString();
        final resolvedType =
            (r['leavetype'] ?? r['leaveType'] ?? typeMap[typeId] ?? '')
                .toString();
        final resolvedYear = yearMap[yearId] ?? r['year'] ?? r['id_year'];
        return _fromSupabaseLeave({
          ...r,
          'fullName': resolvedName,
          'leaveType': resolvedType,
          'year': resolvedYear,
          'department': teacher['department'] ?? '',
          'position': teacher['position'] ?? '',
          'academicStanding':
              teacher['academicStanding'] ?? teacher['วิทยฐานะ'] ?? '',
          'ID_Academics': teacher['ID_Academics'],
          'วิทยฐานะ': teacher['academicStanding'] ?? teacher['วิทยฐานะ'] ?? '',
        });
      }).toList()
        ..sort(compareLeaveRecency);
    } catch (e) {
      debugPrint('❌ getLeaveRequestsFromSupabase error: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequestsFromSupabase(
      String fullName) async {
    final client = _supabaseIfReady;
    // Supabase ยังไม่พร้อม — คืนค่าว่างไปก่อน
    // (ของเดิมเรียกฟังก์ชันที่เรียกตัวเองกลับมา กลายเป็นวนไม่รู้จบจนแอปค้าง)
    if (client == null) return [];
    try {
      final all = await getLeaveRequestsFromSupabase();
      final target = fullName.trim();
      return all
          .where((l) =>
              (l['fullName'] ?? '').toString().trim() == target ||
              (l['name'] ?? '').toString().trim() == target)
          .toList();
    } catch (e) {
      debugPrint('❌ getMyLeaveRequestsFromSupabase error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLastLeaveRequestFromSupabase(
      String fullName) async {
    final client = _supabaseIfReady;
    if (client == null) return null;
    try {
      // ตาราง Leaves ไม่มีคอลัมน์ชื่อครู มีแต่ id_user (FK) และไม่มี createdat
      // ของเดิมยิง .eq('fullname').order('createdat') จึงได้ HTTP 400 ทุกครั้ง
      // แล้วถูก catch กลืนไว้ — ฟังก์ชันนี้คืน null มาตลอดโดยไม่มีใครรู้
      final teacherRows = await client
          .from('Teachers')
          .select('id_user')
          .eq('fullName', fullName.trim())
          .limit(1);
      if ((teacherRows as List).isEmpty) return null;

      final idUser = teacherRows.first['id_user'];
      if (idUser == null) return null;

      final rows = await client
          .from('Leaves')
          .select()
          .eq('id_user', idUser)
          .order('timestamp', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) return null;
      return _fromSupabaseLeave(rows.first as Map);
    } catch (e) {
      debugPrint('❌ getLastLeaveRequestFromSupabase error: $e');
      return null;
    }
  }

  /// อัปเดตเลขรับใบลาใน Supabase
  Future<void> updateLeaveReceiveNumberInSupabase(String requestId,
      String receiveNumber, String receiveDate, String receiveTime) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client.from('Leaves').update({
      'receiveNumber': receiveNumber,
      'receiveDate': receiveDate,
      'receiveTime': receiveTime,
    }).eq('id_leaves', requestId);
  }

  /// ลบใบลาจาก Supabase — PK คือ id_leaves ไม่ใช่ id
  Future<void> deleteLeaveFromSupabase(String requestId) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client
        .from('Leaves')
        .delete()
        .eq(primaryKeyFor('Leaves'), _pkValue(requestId));
  }

  // ── FiscalRounds ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>>? _fiscalRoundsInFlight;

  // Share concurrent reads only; subsequent refreshes still fetch current data.
  Future<List<Map<String, dynamic>>> getFiscalRoundsFromSupabase() {
    return _fiscalRoundsInFlight ??= _fetchFiscalRoundsFromSupabase()
        .whenComplete(() => _fiscalRoundsInFlight = null);
  }

  Future<List<Map<String, dynamic>>> _fetchFiscalRoundsFromSupabase(
      {bool throwOnError = false}) async {
    final client = _supabaseIfReady;
    // Supabase ยังไม่พร้อม — คืนค่าว่างไปก่อน
    // (ของเดิมเรียกฟังก์ชันที่เรียกตัวเองกลับมา กลายเป็นวนไม่รู้จบจนแอปค้าง)
    if (client == null) return [];
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
      if (throwOnError) rethrow;
      return [];
    }
  }

  Future<Map<String, dynamic>?> getActiveFiscalRoundFromSupabase() async {
    try {
      final rounds = await getFiscalRoundsFromSupabase();
      final now = DateTime.now();
      final todayStr = '${now.day}/${now.month}/${now.year + 543}';
      for (final r in rounds) {
        if (isDateInRange(todayStr, r['startDate'] ?? '', r['endDate'] ?? '')) {
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
      // เติมคีย์ 'id' ให้หน้าจอใช้ได้เหมือนสมัย Firebase (PK จริงคือ id_holiday)
      // ไม่งั้นปุ่มลบจะส่ง null ไปลบ แล้วไม่มีอะไรเกิดขึ้น
      return (rows as List).map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        row['id'] = row['id_holiday'];
        return row;
      }).toList();
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
      // เติมคีย์ 'id' ด้วยเหตุผลเดียวกับ SpecialHolidays
      return (rows as List).map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        row['id'] = row['id_SpecialWorkingDays'];
        return row;
      }).toList();
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
    // Supabase ยังไม่พร้อม — คืนค่าว่างไปก่อน
    // (ของเดิมเรียกฟังก์ชันที่เรียกตัวเองกลับมา กลายเป็นวนไม่รู้จบจนแอปค้าง)
    if (client == null) return [];
    try {
      final rows = await client.from('LeaveTypes').select();
      final seen = <String>{};
      final result = <String>[];
      for (final row in (rows as List)) {
        final r = Map<String, dynamic>.from(row as Map);
        final value = (r['leaveName'] ??
                r['value'] ??
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

  Future<List<Map<String, dynamic>>> getLeaveTypesRawFromSupabase(
      {bool throwOnError = false}) async {
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
      if (throwOnError) rethrow;
      return [];
    }
  }

  Future<List<String>> getAdminRolesFromSupabase() async {
    final roles = await _getMasterListFromSupabase('adminroles', [
      'AdminRolesName',
      'adminrolename',
      'name',
      'value',
      'adminrole',
      'ตำแหน่งบริหาร'
    ]);
    if (!roles.contains('ไม่มีตำแหน่งบริหาร')) {
      roles.insert(0, 'ไม่มีตำแหน่งบริหาร');
    }
    return roles;
  }

  Future<List<String>> getPositionsFromSupabase() async {
    return _getMasterListFromSupabase('positions', [
      'positionName',
      'positionname',
      'name',
      'value',
      'position',
      'ตำแหน่ง'
    ]);
  }

  Future<List<String>> getDepartmentsFromSupabase() async {
    return _getMasterListFromSupabase('departments', [
      'DepartmentsName',
      'departmentname',
      'name',
      'value',
      'department',
      'แผนก_กลุ่มสาระ',
    ]);
  }

  Future<List<String>> getAcademicsFromSupabase() async {
    return _getMasterListFromSupabase('academics', [
      'AcademicsName',
      'academicname',
      'name',
      'value',
      'academic',
      'วิทยฐานะ'
    ]);
  }

  Future<List<String>> getPermissionsFromSupabase() async {
    final client = _supabaseIfReady;
    // Supabase ยังไม่พร้อม — คืนค่าว่างไปก่อน
    // (ของเดิมเรียกฟังก์ชันที่เรียกตัวเองกลับมา กลายเป็นวนไม่รู้จบจนแอปค้าง)
    if (client == null) return [];
    try {
      final rows =
          await client.from('roles').select('Accessrights').order('ID_Roles');
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
    await client
        .from(supabaseTable)
        .update(data)
        .eq(primaryKeyFor(supabaseTable), _pkValue(id));
  }

  Future<void> deleteMasterItemFromSupabase(
      String supabaseTable, String id) async {
    final client = _supabaseIfReady;
    if (client == null) throw Exception('Supabase not initialized');
    await client
        .from(supabaseTable)
        .delete()
        .eq(primaryKeyFor(supabaseTable), _pkValue(id));
  }

  // ── Permissions doc (for menu access) ────────────────────────────

  Future<Map<String, dynamic>?> getPermissionDocFromSupabase(
      String collection, String role) async {
    final client = _supabaseIfReady;
    if (client == null) return null;
    try {
      final roleRow = await client
          .from('roles')
          .select('ID_Roles')
          .eq('Accessrights', role)
          .maybeSingle();
      if (roleRow == null) return null;
      final idRole = roleRow['ID_Roles'];

      final rows = await client
          .from(collection)
          .select('menu_id, status')
          .eq('id_role', idRole);

      final result = <String, dynamic>{};
      for (final row in (rows as List)) {
        final menuId = row['menu_id']?.toString();
        final status = row['status'];
        if (menuId != null) {
          result[menuId] = status == true ||
              status == 1 ||
              status.toString() == '1' ||
              status.toString().toUpperCase() == 'TRUE';
        }
      }
      return result.isNotEmpty ? result : null;
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
      final rolesRows =
          await client.from('roles').select('ID_Roles, Accessrights');

      final roleNameMap = <String, String>{};
      for (final r in (rolesRows as List)) {
        final id = r['ID_Roles']?.toString();
        final name = (r['Accessrights'] ?? '').toString();
        if (id != null && name.isNotEmpty) roleNameMap[id] = name;
      }

      final grouped = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final idRole = row['id_role']?.toString() ?? '';
        final menuId = row['menu_id']?.toString();
        final status = row['status'];
        if (idRole.isEmpty || menuId == null) continue;
        final roleName = roleNameMap[idRole] ?? idRole;
        grouped.putIfAbsent(
            roleName, () => {'id': roleName, 'id_role': idRole});
        grouped[roleName]![menuId] = status == true ||
            status == 1 ||
            status.toString() == '1' ||
            status.toString().toUpperCase() == 'TRUE';
      }

      return grouped.values.toList();
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
          .select('id_user') // Teachers ไม่มีคอลัมน์ 'id' — PK คือ id_user
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
      return (rows as List).map((r) => _fromSupabaseTeacher(r as Map)).toList();
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
      'groupId':
          config('groupid').isNotEmpty ? config('groupid') : config('groupId'),
      'webhookUrl': config('webhookurl').isNotEmpty
          ? config('webhookurl')
          : config('webhookUrl').isNotEmpty
              ? config('webhookUrl')
              : config('appsScriptUrl'),
      'template': config('template'),
    };
  }
}
