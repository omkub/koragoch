import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MigrationService {
  // แผนทั้ง 17 ตาราง; ตารางที่ยังขาด schema/FK จะหยุดก่อนเขียนข้อมูล
  static const _identityTables = <String, String>{
    'SpecialHolidays': 'SpecialHolidays',
    'SpecialWorkingDays': 'SpecialWorkingDays',
    'Settings': 'Settings',
    'Academics': 'academics',
    'AdminRoles': 'adminroles',
    'AppConfig': 'appconfig',
    'Departments': 'departments',
    'Positions': 'positions',
    'Roles': 'roles',
    'Permissions': 'Permissions',
    'LeaveTypes': 'LeaveTypes',
    'FiscalRounds': 'FiscalRounds',
    'Teachers': 'Teachers',
    'UserRoles': 'UserRoles',
    'MobilePermissions': 'MobilePermissions',
    'Leaves': 'Leaves',
    'LoginLogs': 'LoginLogs',
  };

  // ใช้ร่วมกันระหว่าง payload และหน้าต่างเปรียบเทียบ ไม่มี PK หรือ doc ID
  static const _identityImportColumns = <String, List<String>>{
    'SpecialHolidays': [
      'date',
      'dateValue',
      'title',
      'note',
      'source',
      'createdAt',
      'updatedAt',
    ],
    'SpecialWorkingDays': [
      'createdAt',
      'date',
      'dateValue',
      'note',
      'title',
      'updatedAt',
    ],
    'Settings': [
      'appsScriptUrl',
      'driveLeaveFolderId',
      'driveProfileFolderId',
      'secretKey',
      'adminPositions',
      'departments',
      'positions',
      'channelToken',
      'groupId',
      'template',
      'updatedAt',
      'webhookUrl',
      'lastNumber',
      'year',
    ],
    'Academics': ['createdAt', 'updatedAt', 'AcademicsName'],
    'AdminRoles': ['createdAt', 'updatedAt', 'AdminRolesName'],
    'AppConfig': ['Description', 'Key AppTitle', 'Value'],
    'Departments': ['createdAt', 'updatedAt', 'DepartmentsName'],
    'Positions': ['createdAt', 'positionName', 'updatedAt'],
    'Roles': ['createdAt', 'updatedAt', 'Accessrights', 'License'],
    'LeaveTypes': ['leaveName', 'createdAt', 'updatedAt'],
    'FiscalRounds': [
      'year',
      'round',
      'startDate',
      'endDate',
      'isActive',
      'createdAt'
    ],
    'Teachers': [],
    'UserRoles': [],
    'Permissions': [],
    'MobilePermissions': ['id_role', 'status', 'updatedAt'],
    'Leaves': [
      'id_user',
      'timestamp',
      'status',
      'lastUpdatedAt',
      'leaveDate',
      'id_leaveType',
      'reason',
      'startDate',
      'endDate',
      'totalDays',
      'id_year',
      'receiveNumber',
      'medicalCertificate',
    ],
    'LoginLogs': ['id_user', 'timestamp', 'platform', 'userAgent'],
  };

  // อ้างอิงชีตที่อ่านล่าสุด: ไม่เดา schema หรือคัดลอก Firebase ID เป็น FK ใหม่
  static const _importBlockers = <String, String>{
    'UserRoles': 'ชีตยังไม่ยืนยันคอลัมน์ Supabase และ FK ของ UserRoles',
    'Permissions': 'ชีตยังไม่ยืนยันคอลัมน์ Supabase ของ Permissions',
    'MobilePermissions':
        'ยังไม่มี mapping ว่าแต่ละ status เป็นสิทธิ์เมนูใดจาก 0–8',
    'Leaves':
        'ต้องยืนยันตารางผู้ใช้และ mapping ID ใหม่ของผู้ใช้/ประเภทลา/รอบงบประมาณก่อน',
    'LoginLogs':
        'ต้องยืนยันตารางผู้ใช้และ mapping Firebase user ไปยัง PK ใหม่ก่อน',
  };

  static String? importBlockerForCollection(
    String name, {
    Map<String, Set<String>>? schema,
  }) {
    if (name == 'Teachers') {
      final current = schema ?? _tableColumns;
      if (current == null) return 'ยังไม่ได้โหลด schema จริงของ Teachers';
      final table = resolveTableNameForCollection(name, current);
      if (table == null) return 'ไม่พบตาราง Teachers ใน public schema';
      if (!current[table]!.any((column) => column.toLowerCase() == 'id_user')) {
        return 'ตาราง $table ไม่มีคอลัมน์ PK id_user ที่ยืนยันไว้';
      }
      return null;
    }
    return _importBlockers[name];
  }

  // Resolve checkbox values by collection name, never by the displayed row index.
  static List<String> collectionsFromSelection(Map<String, bool> selection) {
    return List<String>.unmodifiable(orderedCollectionsForImport(
      selection.entries.where((entry) => entry.value).map((entry) => entry.key),
    ));
  }

  static List<String> orderedCollectionsForImport(Iterable<String> names) {
    final selected = names.toSet();
    final unknown = selected.difference(_collections.toSet());
    if (unknown.isNotEmpty) {
      throw ArgumentError('Unknown collections: ${unknown.join(', ')}');
    }
    return _collections.where(selected.contains).toList();
  }

  static List<String>? importColumnsForCollection(
    String name, {
    Map<String, Set<String>>? schema,
  }) {
    if (name == 'Teachers') {
      final current = schema ?? _tableColumns;
      if (current == null) return const [];
      final table = resolveTableNameForCollection(name, current);
      if (table == null) return const [];
      return current[table]!
          .where((column) => !{'id_user', 'id'}.contains(column.toLowerCase()))
          .toList();
    }
    return _identityImportColumns[name];
  }

  // Preserve the exact identifier returned by public schema metadata for PostgREST.
  static String? resolveTableNameForCollection(
    String name,
    Map<String, Set<String>> schema,
  ) {
    final expected = tableNameForCollection(name);
    if (schema.containsKey(expected)) return expected;
    final matches = schema.keys
        .where((table) => table.toLowerCase() == expected.toLowerCase())
        .toList();
    if (matches.length > 1) {
      throw StateError(
          'พบหลายตารางที่ชื่อคล้าย $expected: ${matches.join(', ')}');
    }
    return matches.isEmpty ? null : matches.single;
  }

  static String tableNameForCollection(String name) =>
      _identityTables[name] ?? name.toLowerCase();
  static const _clearPrimaryKeys = <String, List<String>>{
    'LoginLogs': ['id_LoginLogs'],
    'Leaves': ['id_leaves'],
    'MobilePermissions': ['id_MobilePermissions', 'id_role'],
    'Permissions': ['id_Permissions', 'id_role'],
    'UserRoles': ['id_UserRoles', 'id_user'],
    'Teachers': ['id_user'],
    'Settings': ['id_Settings'],
    'SpecialWorkingDays': ['id_SpecialWorkingDays'],
    'SpecialHolidays': ['id_holiday'],
    'FiscalRounds': ['id_year'],
    'LeaveTypes': ['id_leaveType'],
    'Roles': ['ID_Roles'],
    'Positions': ['ID_Positions'],
    'Departments': ['ID_Departments'],
    'AppConfig': ['ID_AppConfig'],
    'AdminRoles': ['ID_AdminRoles'],
    'Academics': ['ID_Academics'],
  };

  static Future<List<String>> clearImportTables({
    Iterable<String>? collections,
    void Function(String message)? onLog,
  }) async {
    final tableColumns = await _loadTableColumns(forceRefresh: true);
    final targets = orderedCollectionsForImport(collections ?? _collections)
        .reversed
        .toList();
    final cleared = <String>[];
    final supabase = Supabase.instance.client;

    for (final collectionName in targets) {
      final tableName =
          resolveTableNameForCollection(collectionName, tableColumns);
      if (tableName == null) {
        onLog?.call('ข้าม $collectionName: ไม่พบตารางใน Supabase');
        continue;
      }

      final columns = tableColumns[tableName]!;
      final pk = _clearPrimaryKeys[collectionName]?.firstWhere(
        (column) => columns.any((actual) => actual == column),
        orElse: () => '',
      );
      if (pk == null || pk.isEmpty) {
        onLog?.call('ข้าม $tableName: ไม่พบคอลัมน์สำหรับล้างข้อมูล');
        continue;
      }

      await supabase.from(tableName).delete().gte(pk, 0);
      cleared.add(tableName);
      onLog?.call('ล้างข้อมูล $tableName แล้ว');
    }

    return List<String>.unmodifiable(cleared);
  }

  @visibleForTesting
  static Map<String, dynamic> buildIdentityImportRecord(
    String collectionName,
    Map<String, dynamic> data, {
    Map<String, Set<String>>? schema,
  }) {
    final blocker = importBlockerForCollection(collectionName, schema: schema);
    if (blocker != null) throw StateError(blocker);
    final columns = importColumnsForCollection(collectionName, schema: schema);
    if (columns == null) {
      throw ArgumentError.value(collectionName, 'collectionName');
    }
    const masterNames = <String, String>{
      'Academics': 'AcademicsName',
      'AdminRoles': 'AdminRolesName',
      'Departments': 'DepartmentsName',
      'Positions': 'positionName',
      'Roles': 'Accessrights',
      'LeaveTypes': 'leaveName',
    };
    const firebaseMasterNames = <String, String>{
      'Academics': 'วิทยฐานะ',
      'AdminRoles': 'ตำแหน่งบริหาร',
      'Departments': 'แผนก_กลุ่มสาระ',
      'Positions': 'ตำแหน่ง',
      'Roles': 'สิทธิ์การเข้าถึง',
      'LeaveTypes': 'ประเภทการลา',
    };
    final record = <String, dynamic>{};
    for (final column in columns) {
      final matches = data.keys.where(
        (key) => key.toLowerCase() == column.toLowerCase(),
      );
      if (matches.isEmpty) continue;
      final key = data.containsKey(column) ? column : matches.first;
      final value = _convertToSupabaseType(data[key]);
      // Settings ในร่างใช้ text; JSON text ทำให้แปลง array/map กลับได้
      record[column] =
          value is List || value is Map ? jsonEncode(value) : value;
    }
    final masterName = masterNames[collectionName];
    if (masterName != null &&
        (record[masterName] is! String ||
            (record[masterName] as String).trim().isEmpty)) {
      for (final key in [
        firebaseMasterNames[collectionName]!,
        'Value',
        'value',
        'Name',
        'name',
        'Type Name',
      ]) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          record[masterName] = value;
          break;
        }
      }
      if (record[masterName] is! String ||
          (record[masterName] as String).trim().isEmpty) {
        throw FormatException('ไม่พบชื่อสำหรับ $collectionName.$masterName');
      }
    }
    if (collectionName == 'SpecialHolidays' ||
        collectionName == 'SpecialWorkingDays') {
      final value = data['date'] ?? data['dateValue'];
      if (value != null) record['date'] = _specialDateForImport(value);
    }
    if (collectionName == 'FiscalRounds') {
      for (final column in ['startDate', 'endDate']) {
        if (record[column] != null) {
          record[column] = _specialDateForImport(record[column]);
        }
      }
      for (final column in ['year', 'round']) {
        final value = record[column];
        if (value != null && value is! int) {
          final parsed = int.tryParse(value.toString());
          if (parsed == null)
            throw FormatException('ค่า $column ต้องเป็นจำนวนเต็ม');
          record[column] = parsed;
        }
      }
    }
    if (record.isEmpty) {
      throw FormatException('ไม่มีฟิลด์ตรงกับคอลัมน์ของ $collectionName');
    }
    return record;
  }

  static String _specialDateForImport(dynamic value) {
    if (value is Timestamp) value = value.toDate();
    if (value is DateTime) {
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    final text = value.toString().trim();
    final thaiDate = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
    if (thaiDate != null) {
      final day = int.parse(thaiDate[1]!);
      final month = int.parse(thaiDate[2]!);
      final storedYear = int.parse(thaiDate[3]!);
      final year = storedYear > 2400 ? storedYear - 543 : storedYear;
      final date = DateTime(year, month, day);
      if (date.year == year && date.month == month && date.day == day) {
        return _specialDateForImport(date);
      }
      throw FormatException('วันที่ไม่ถูกต้อง: $text');
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}(?:T.*)?$').hasMatch(text)) {
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return text.substring(0, 10);
    }
    throw FormatException('รูปแบบวันที่ไม่รองรับ: $text');
  }

  // คอลัมน์จริงของแต่ละตารางใน public schema; refresh ก่อนตรวจหรือนำเข้า
  static Map<String, Set<String>>? _tableColumns;

  // โหลดรายชื่อคอลัมน์ทุกตารางผ่าน SQL function get_table_columns()
  // (ต้องรัน SQL สร้าง function นี้ใน Supabase ก่อน — ดู supabase_extra_tables.sql)
  static Future<Map<String, Set<String>>> _loadTableColumns({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) _tableColumns = null;
    if (_tableColumns != null) return _tableColumns!;

    final rows =
        await Supabase.instance.client.rpc('get_table_columns') as List;
    final result = parseTableColumns(rows);
    if (result.isEmpty) {
      throw Exception('ไม่พบตารางใน public schema ของ Supabase');
    }
    _tableColumns = result;
    return result;
  }

  static Future<void> refreshTableColumns() async {
    await _loadTableColumns(forceRefresh: true);
  }

  @visibleForTesting
  static Map<String, Set<String>> parseTableColumns(List<dynamic> rows) {
    final result = <String, Set<String>>{};
    final identifier = RegExp(r'^(?:public\.)?"?([A-Za-z_][A-Za-z0-9_]*)"?$');
    for (final row in rows) {
      final namespace = row['table_schema'] ?? row['schema_name'];
      if (namespace != null && namespace != 'public') continue;
      final rawTable = row['table_name'] as String;
      final table = identifier.firstMatch(rawTable.trim())?.group(1);
      if (table == null) continue;
      final column = row['column_name'] as String;
      result.putIfAbsent(table, () => <String>{}).add(column);
    }
    return result;
  }

  // ⚠️ ต้องใช้ database 'school' เหมือน FirebaseService ไม่ใช่ (default)
  static FirebaseFirestore get _schoolDb =>
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'school');

  // Master tables precede dependent tables; unresolved FK mappings stay blocked.
  static const List<String> _collections = [
    'Settings',
    'AppConfig',
    'Academics',
    'AdminRoles',
    'Departments',
    'Positions',
    'Roles',
    'LeaveTypes',
    'FiscalRounds',
    'SpecialHolidays',
    'SpecialWorkingDays',
    'Teachers',
    'Permissions',
    'MobilePermissions',
    'UserRoles',
    'Leaves',
    'LoginLogs',
  ];

  static Future<void> exportFirebaseToCSV() async {
    final db = _schoolDb;

    debugPrint('\n🔄 เริ่ม Export Firebase Data (17 Collections)...\n');

    for (final collectionName in _collections) {
      await _exportCollection(db, collectionName);
    }

    debugPrint('\n✅ Export Complete!\n');
    debugPrint(
        '📋 CSV data ready - copy from console and import to Supabase\n');
  }

  // รายชื่อ collection ทั้งหมด (สำหรับให้ UI แสดง checkbox เลือก)
  static List<String> get allCollections => List.unmodifiable(_collections);
  static String importOrderSummary([Iterable<String>? collections]) {
    final ordered = orderedCollectionsForImport(collections ?? _collections);
    return ordered
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join(' → ');
  }

  static Future<int> exportAndImportToSupabase({
    List<String>? collections,
    void Function(String message)? onLog,
    void Function(int done, int total, String current)? onStep,
  }) async {
    final targets = List<String>.unmodifiable(
      orderedCollectionsForImport(collections ?? _collections),
    );
    if (targets.isEmpty) throw ArgumentError('ต้องเลือกอย่างน้อยหนึ่งตาราง');
    void report(String msg) {
      debugPrint(msg);
      onLog?.call(msg);
    }

    report(
        '🔄 เริ่ม Export & Import ไป Supabase (${targets.length} Collections)...');
    report('📋 ตารางที่จะนำเข้าตามลำดับ: ${targets.join(' → ')}');

    // A selection containing only blocked tables needs no database access.
    final needsDatabase =
        targets.any((name) => !_importBlockers.containsKey(name));
    onStep?.call(
        0,
        targets.length,
        needsDatabase
            ? 'กำลังโหลด schema จาก Supabase...'
            : 'กำลังตรวจตารางที่เลือก...');
    final tableColumns = needsDatabase
        ? await _loadTableColumns(forceRefresh: true)
        : <String, Set<String>>{};
    if (needsDatabase)
      report('📚 โหลด schema สำเร็จ (${tableColumns.length} ตาราง)');
    final db = needsDatabase ? _schoolDb : null;
    final supabase = needsDatabase ? Supabase.instance.client : null;

    int totalImported = 0;
    final skippedCollections = <String>[];

    for (int idx = 0; idx < targets.length; idx++) {
      final collectionName = targets[idx];
      onStep?.call(idx, targets.length, collectionName);

      try {
        final blocker = importBlockerForCollection(collectionName);
        if (blocker != null) {
          skippedCollections.add(collectionName);
          report('⏸️ $collectionName: $blocker — ยังไม่นำเข้า');
          onStep?.call(
              idx + 1, targets.length, 'ข้าม $collectionName: $blocker');
          continue;
        }
        final tableName =
            resolveTableNameForCollection(collectionName, tableColumns);
        if (tableName == null) {
          skippedCollections.add(collectionName);
          report(
              '❌ $collectionName: ไม่มีตารางใน public schema ของ Supabase — ข้าม');
          onStep?.call(idx + 1, targets.length,
              'ข้าม $collectionName: ไม่พบตารางใน Supabase');
          continue;
        }
        final columns = tableColumns[tableName]!;

        final snap = await db!.collection(collectionName).get();

        if (snap.docs.isEmpty) {
          report('⚠️ $collectionName: ไม่มีข้อมูล');
          continue;
        }

        report(
            'ℹ️ $collectionName → $tableName: INSERT โดยไม่ส่ง PK; นำเข้าซ้ำจะสร้างรายการใหม่');

        // Import directly from Firebase docs (ไม่ผ่าน CSV)
        int successCount = 0;
        final missingColumns = <String>{};

        for (var doc in snap.docs) {
          try {
            final record =
                buildIdentityImportRecord(collectionName, doc.data());

            // ไม่ตัดค่าที่ mapping แล้วทิ้งเงียบ ๆ เมื่อ schema จริงต่างจากแผน
            final unknown =
                record.keys.where((key) => !columns.contains(key)).toList();
            if (unknown.isNotEmpty) {
              missingColumns.addAll(unknown);
              throw FormatException(
                  'schema $tableName ไม่มีคอลัมน์: ${unknown.join(', ')}');
            }

            if (record.isEmpty) {
              throw FormatException(
                  'ไม่มีฟิลด์ตรงกับ schema จริงของ $tableName');
            }
            await supabase!.from(tableName).insert(record);

            successCount++;
          } on PostgrestException catch (e) {
            report(
                '⚠️ $collectionName/${doc.id}: [${e.code}] ${e.message} ${e.details ?? ""}');
          } catch (e) {
            report('⚠️ $collectionName/${doc.id} Error: $e');
          }
        }

        if (missingColumns.isNotEmpty) {
          report(
              'ℹ️ $collectionName: รายการที่ใช้คอลัมน์เหล่านี้ยังไม่นำเข้า เพราะ schema ไม่ตรง: ${missingColumns.join(", ")}');
        }
        report(
            '✅ $collectionName: ${snap.docs.length} → $successCount imported');
        totalImported += successCount;
      } catch (e) {
        report('❌ $collectionName Error: $e');
      }
    }

    onStep?.call(targets.length, targets.length, 'เสร็จสิ้น');
    report('Import เสร็จสิ้น รวม $totalImported records');
    if (skippedCollections.isNotEmpty) {
      report('ตารางที่ยังไม่นำเข้า: ${skippedCollections.join(', ')}');
    }
    return totalImported;
  }

  // Convert Firebase types to Supabase-compatible types
  static dynamic _convertToSupabaseType(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is List) {
      return value.map((v) => _convertToSupabaseType(v)).toList();
    } else if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((k, v) {
        map[k.toString()] = _convertToSupabaseType(v);
      });
      return map;
    } else if (value is bool) {
      return value;
    } else if (value is int) {
      return value;
    } else if (value is double) {
      return value;
    } else {
      return value.toString();
    }
  }

  // === GENERIC EXPORT METHOD ===
  static Future<void> _exportCollection(
    FirebaseFirestore db,
    String collectionName,
  ) async {
    try {
      final snap = await db.collection(collectionName).get();

      if (snap.docs.isEmpty) {
        debugPrint('⚠️  $collectionName: No data found');
        return;
      }

      if (snap.docs.isEmpty) return;

      // Build CSV with dynamic columns from first document
      final firstDoc = snap.docs.first.data();
      final columns = <String>['id', ...firstDoc.keys];

      final List<List<dynamic>> csvData = [columns];

      for (var doc in snap.docs) {
        final data = doc.data();
        final row = [
          doc.id,
          ...columns.skip(1).map((col) => _formatValue(data[col]))
        ];
        csvData.add(row);
      }

      final csvText = csv.encode(csvData);
      debugPrint('✅ $collectionName: ${snap.docs.length} records');
      _printCSVInfo(collectionName, csvText);
    } catch (e) {
      debugPrint('❌ $collectionName Error: $e');
    }
  }

  // === HELPERS ===
  static String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is List || value is Map) {
      return value.toString();
    }
    return value.toString();
  }

  static void _printCSVInfo(String tableName, String csv) {
    final lines = csv.split('\n');
    debugPrint('   📋 First row: ${lines[0]}');
    if (lines.length > 1) {
      debugPrint('   📋 Sample: ${lines[1]}');
    }
  }
}
