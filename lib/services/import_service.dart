import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImportService {
  static final supabase = Supabase.instance.client;

  static Future<void> importCSVToSupabase(String csvDataStr) async {
    debugPrint('\n🔄 เริ่ม Import CSV Data ไป Supabase...\n');

    try {
      // Parse CSV string
      final List<List<dynamic>> csvData =
          const CsvToListConverter().convert(csvDataStr);

      if (csvData.isEmpty) {
        debugPrint('❌ CSV data is empty');
        return;
      }

      // ตรวจหา collection name จาก first row (header)
      final headers = csvData[0].cast<String>();
      final collectionName = _getCollectionName(headers);

      if (collectionName.isEmpty) {
        debugPrint('❌ Cannot determine collection name from headers');
        return;
      }

      debugPrint('📊 Collection: $collectionName');
      debugPrint('📋 Columns: ${headers.join(", ")}');
      debugPrint('📈 Rows: ${csvData.length - 1}\n');

      // Import data rows
      int successCount = 0;
      for (int i = 1; i < csvData.length; i++) {
        try {
          final row = csvData[i];
          final id = row.isNotEmpty ? row[0].toString() : '';

          if (id.isEmpty) continue;

          // Build record map
          final record = <String, dynamic>{'id': id};

          for (int j = 1; j < headers.length && j < row.length; j++) {
            final key = headers[j];
            final value = row[j];

            // Convert to appropriate type
            if (value == null || value.toString().isEmpty) {
              record[key] = null;
            } else if (value is bool) {
              record[key] = value;
            } else if (int.tryParse(value.toString()) != null) {
              record[key] = int.parse(value.toString());
            } else if (double.tryParse(value.toString()) != null) {
              record[key] = double.parse(value.toString());
            } else if (_isValidDateTime(value.toString())) {
              record[key] = value.toString();
            } else {
              record[key] = value.toString();
            }
          }

          // Insert/Upsert ไป Supabase
          await supabase
              .from(collectionName.toLowerCase())
              .upsert(record, onConflict: 'id');

          successCount++;

          if (successCount % 10 == 0) {
            debugPrint('✅ Imported $successCount records...');
          }
        } catch (e) {
          debugPrint('⚠️  Row $i Error: $e');
        }
      }

      debugPrint('\n✅ Import Complete!');
      debugPrint('📈 Total: $successCount records imported to $collectionName\n');
    } catch (e) {
      debugPrint('❌ Import Error: $e');
    }
  }

  // Determine collection name from CSV headers
  static String _getCollectionName(List<String> headers) {
    // Firebase collections จาก export
    final headerStr = headers.join(',').toLowerCase();

    if (headerStr.contains('username') && headerStr.contains('fullname')) {
      return 'Teachers';
    } else if (headerStr.contains('leavetype') && headerStr.contains('userid')) {
      return 'Leaves';
    } else if (headerStr.contains('platform') && headerStr.contains('useragent')) {
      return 'LoginLogs';
    } else if (headerStr.contains('teacherdocid')) {
      return 'UserRoles';
    } else if (headerStr.contains('key') && headerStr.contains('value')) {
      return 'Settings';
    } else if (headerStr.contains('startdate') && headerStr.contains('enddate') &&
        headerStr.contains('isactive')) {
      return 'FiscalRounds';
    } else if (headerStr.contains('datevalue') && headerStr.contains('title')) {
      return 'SpecialHolidays';
    } else if (headerStr.contains('round') && headerStr.contains('year')) {
      return 'FiscalRounds';
    } else if (headerStr.contains('role_name') || headerStr.contains('field_0')) {
      return 'Permissions';
    } else if (headerStr.contains('adminpositions')) {
      return 'Settings';
    }

    return '';
  }

  // Check if value is valid datetime format
  static bool _isValidDateTime(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Import all collections from CSV strings map
  static Future<void> importAllCollections(
    Map<String, String> csvDataMap,
  ) async {
    debugPrint('\n🔄 เริ่ม Import ทั้งหมด ${csvDataMap.length} Collections...\n');

    int totalImported = 0;

    for (final entry in csvDataMap.entries) {
      final collectionName = entry.key;
      final csvData = entry.value;

      try {
        final List<List<dynamic>> rows =
            const CsvToListConverter().convert(csvData);

        if (rows.isEmpty || rows.length < 2) {
          debugPrint('⚠️  $collectionName: No data');
          continue;
        }

        final headers = rows[0].cast<String>();
        int successCount = 0;

        for (int i = 1; i < rows.length; i++) {
          try {
            final row = rows[i];
            final id = row.isNotEmpty ? row[0].toString() : '';

            if (id.isEmpty) continue;

            final record = <String, dynamic>{'id': id};

            for (int j = 1; j < headers.length && j < row.length; j++) {
              final key = headers[j];
              final value = row[j];

              if (value == null || value.toString().isEmpty) {
                record[key] = null;
              } else if (int.tryParse(value.toString()) != null) {
                record[key] = int.parse(value.toString());
              } else if (_isValidDateTime(value.toString())) {
                record[key] = value.toString();
              } else {
                record[key] = value.toString();
              }
            }

            await supabase
                .from(collectionName.toLowerCase())
                .upsert(record, onConflict: 'id');

            successCount++;
          } catch (e) {
            debugPrint('⚠️  $collectionName Row $i Error: $e');
          }
        }

        debugPrint('✅ $collectionName: $successCount records');
        totalImported += successCount;
      } catch (e) {
        debugPrint('❌ $collectionName Error: $e');
      }
    }

    debugPrint('\n✅ Import Complete!');
    debugPrint('📈 Total: $totalImported records imported\n');
  }
}
