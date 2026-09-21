import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/services/migration_service.dart';

void main() {
  test('all eight tables omit supplied IDs and preserve destination names', () {
    const fixtures = <String, Map<String, dynamic>>{
      'SpecialHolidays': {
        'date': '7/9/2569',
        'title': 'holiday',
        'id_holiday': 99
      },
      'SpecialWorkingDays': {
        'date': '7/9/2569',
        'title': 'work',
        'id_SpecialWorkingDays': 99
      },
      'Settings': {'year': 2569, 'id_Settings': 99},
      'Academics': {'วิทยฐานะ': 'senior', 'ID_Academics': 99},
      'AdminRoles': {'ตำแหน่งบริหาร': 'head', 'ID_AdminRoles': 99},
      'AppConfig': {
        'Key AppTitle': 'title',
        'Value': 'school',
        'ID_AppConfig': 99
      },
      'Departments': {'แผนก_กลุ่มสาระ': 'science', 'ID_Departments': 99},
      'Positions': {'ตำแหน่ง': 'teacher', 'ID_Positions': 99},
    };
    for (final entry in fixtures.entries) {
      final record = MigrationService.buildIdentityImportRecord(entry.key, {
        ...entry.value,
        'id': 'firebase-document-id',
      });
      expect(record, isNotEmpty, reason: entry.key);
      expect(
          record.keys.any((key) =>
              key.toLowerCase() == 'id' || key.toLowerCase().startsWith('id_')),
          isFalse,
          reason: entry.key);
      expect(
          record.keys.every(
              MigrationService.importColumnsForCollection(entry.key)!.contains),
          isTrue,
          reason: entry.key);
    }
    expect(MigrationService.tableNameForCollection('SpecialHolidays'),
        'SpecialHolidays');
    expect(MigrationService.tableNameForCollection('Settings'), 'Settings');
    expect(MigrationService.tableNameForCollection('Academics'), 'academics');
    expect(MigrationService.tableNameForCollection('Leaves'), 'Leaves');
    expect(MigrationService.importColumnsForCollection('Leaves'),
        contains('id_user'));
    expect(MigrationService.importColumnsForCollection('Leaves'),
        isNot(contains('id_leaves')));
  });

  test('maps current Thai master names and legacy Value without selecting IDs',
      () {
    const names = {
      'Academics': ['วิทยฐานะ', 'AcademicsName'],
      'AdminRoles': ['ตำแหน่งบริหาร', 'AdminRolesName'],
      'Departments': ['แผนก_กลุ่มสาระ', 'DepartmentsName'],
      'Positions': ['ตำแหน่ง', 'positionName'],
    };
    for (final entry in names.entries) {
      final current = MigrationService.buildIdentityImportRecord(entry.key, {
        'id': 'wrong value',
        entry.value[0]: 'correct value',
      });
      expect(current[entry.value[1]], 'correct value');
      final legacy = MigrationService.buildIdentityImportRecord(entry.key, {
        'id': 'wrong value',
        'Value': 'legacy value',
      });
      expect(legacy[entry.value[1]], 'legacy value');
    }
    expect(
        () => MigrationService.buildIdentityImportRecord(
            'Academics', {'id': 'wrong value'}),
        throwsFormatException);
  });

  test('converts Buddhist calendar dates and rejects invalid dates', () {
    final record =
        MigrationService.buildIdentityImportRecord('SpecialHolidays', {
      'date': '7/9/2569',
      'createdAt': DateTime.utc(2026, 9, 7),
    });
    expect(record['date'], '2026-09-07');
    expect(record['createdAt'], '2026-09-07T00:00:00.000Z');
    expect(
        () => MigrationService.buildIdentityImportRecord(
            'SpecialWorkingDays', {'date': '31/2/2569'}),
        throwsFormatException);
  });

  test('preserves Settings arrays as JSON text and rejects empty mappings', () {
    final record = MigrationService.buildIdentityImportRecord('Settings', {
      'positions': ['teacher', 'head'],
      'departments': {'main': 'science'},
      'secretKey': 'test-only',
      'id_Settings': 8,
    });
    expect(jsonDecode(record['positions'] as String), ['teacher', 'head']);
    expect(jsonDecode(record['departments'] as String), {'main': 'science'});
    expect(record['secretKey'], 'test-only');
    expect(
        () => MigrationService.buildIdentityImportRecord(
            'AppConfig', {'id': 'old-id'}),
        throwsFormatException);
  });

  test('additional master tables preserve display names and fiscal values', () {
    final role = MigrationService.buildIdentityImportRecord('Roles', {
      'ID_Roles': 90,
      'สิทธิ์การเข้าถึง': 'teacher',
      'License': 'staff',
    });
    // คอลัมน์จริงในตาราง roles ของ Supabase ชื่อ 'Accessrights' ติดกันไม่มีเว้นวรรค
    // (ยืนยันจากฐานข้อมูลจริงแล้ว) เทสเดิมคาดหวัง 'Access rights' ซึ่งไม่เคยมีอยู่จริง
    expect(role, {'Accessrights': 'teacher', 'License': 'staff'});
    final type = MigrationService.buildIdentityImportRecord('LeaveTypes', {
      'id_leaveType': 90,
      'ประเภทการลา': 'sick leave',
    });
    expect(type, {'leaveName': 'sick leave'});
    final fiscal = MigrationService.buildIdentityImportRecord('FiscalRounds', {
      'id_year': 90,
      'year': '2569',
      'round': '1',
      'startDate': '1/10/2568',
      'endDate': '30/9/2569',
      'isActive': true,
    });
    expect(fiscal, {
      'year': 2569,
      'round': 1,
      'startDate': '2025-10-01',
      'endDate': '2026-09-30',
      'isActive': true,
    });
  });

  test('all 17 tables have a plan and import order respects dependencies', () {
    expect(MigrationService.allCollections.length, 17);
    for (final table in MigrationService.allCollections) {
      expect(MigrationService.importColumnsForCollection(table), isNotNull);
    }
    final ordered = MigrationService.orderedCollectionsForImport(
      ['Leaves', 'Teachers', 'Roles', 'FiscalRounds', 'LeaveTypes', 'Roles'],
    );
    expect(
        ordered, ['Roles', 'LeaveTypes', 'FiscalRounds', 'Teachers', 'Leaves']);
    expect(() => MigrationService.orderedCollectionsForImport(['Unknown']),
        throwsArgumentError);
  });

  test('unconfirmed schema and FK mappings fail before building a payload', () {
    for (final table in [
      'Teachers',
      'Permissions',
      'Leaves',
      'LoginLogs',
    ]) {
      expect(MigrationService.importBlockerForCollection(table), isNotEmpty);
      expect(
        () => MigrationService.buildIdentityImportRecord(table, {
          'id': 1,
          'id_user': 2,
          'id_role': 3,
          'id_year': 4,
          'status': '1',
          'fullName': 'test',
        }),
        throwsStateError,
        reason: table,
      );
    }
  });

  test('Teachers metadata accepts public qualified and lower-case table names',
      () {
    final schema = MigrationService.parseTableColumns([
      {
        'table_schema': 'public',
        'table_name': 'public."Teachers"',
        'column_name': 'id_user'
      },
      {
        'table_schema': 'public',
        'table_name': 'Teachers',
        'column_name': 'fullName'
      },
      {
        'table_schema': 'private',
        'table_name': 'Teachers',
        'column_name': 'privateOnly'
      },
    ]);
    expect(schema, {
      'Teachers': {'id_user', 'fullName'}
    });
    expect(MigrationService.resolveTableNameForCollection('Teachers', schema),
        'Teachers');
    expect(
        MigrationService.importBlockerForCollection('Teachers', schema: schema),
        isNull);
    expect(
        MigrationService.importColumnsForCollection('Teachers', schema: schema),
        ['fullName']);

    final lowerCaseSchema = <String, Set<String>>{
      'teachers': {'ID_USER', 'fullname', 'email'},
    };
    expect(
        MigrationService.resolveTableNameForCollection(
            'Teachers', lowerCaseSchema),
        'teachers');
    expect(
        MigrationService.importBlockerForCollection('Teachers',
            schema: lowerCaseSchema),
        isNull);
    final record = MigrationService.buildIdentityImportRecord(
        'Teachers',
        {
          'id': 'old-document',
          'id_user': 50,
          'fullName': 'Example',
          'email': 'example@test.invalid',
        },
        schema: lowerCaseSchema);
    expect(record, {'fullname': 'Example', 'email': 'example@test.invalid'});
  });

  test('Teachers validator requires id_user rather than a generic id', () {
    final wrongPk = <String, Set<String>>{
      'Teachers': {'id', 'fullName'}
    };
    expect(
        MigrationService.importBlockerForCollection('Teachers',
            schema: wrongPk),
        contains('id_user'));
    expect(
      () => MigrationService.buildIdentityImportRecord(
          'Teachers', {'fullName': 'Example'},
          schema: wrongPk),
      throwsStateError,
    );
    expect(MigrationService.importBlockerForCollection('Teachers', schema: {}),
        contains('Teachers'));
  });

  test(
      'table resolution preserves exact names and rejects ambiguous case variants',
      () {
    expect(
        MigrationService.resolveTableNameForCollection('Teachers', {
          'Teachers': {'id_user'},
          'teachers': {'id_user'},
        }),
        'Teachers');
    expect(
      () => MigrationService.resolveTableNameForCollection('Teachers', {
        'TEACHERS': {'id_user'},
        'teachers': {'id_user'},
      }),
      throwsStateError,
    );
  });

  test('checkbox selection targets UserRoles without adding MobilePermissions',
      () {
    final selection = {'MobilePermissions': false, 'UserRoles': true};
    final targets = MigrationService.collectionsFromSelection(selection);
    expect(targets, ['UserRoles']);
    selection['MobilePermissions'] = true;
    expect(targets, ['UserRoles'],
        reason: 'The submitted selection is a snapshot');
    expect(() => targets.add('MobilePermissions'), throwsUnsupportedError);
    expect(MigrationService.orderedCollectionsForImport(['UserRoles']),
        ['UserRoles']);
    expect(
        MigrationService.collectionsFromSelection({
          'MobilePermissions': true,
          'UserRoles': false,
        }),
        ['MobilePermissions']);
  });

  test('UserRoles skip reports only UserRoles without accessing a database',
      () async {
    final logs = <String>[];
    final steps = <String>[];
    final total = await MigrationService.exportAndImportToSupabase(
      collections: ['UserRoles'],
      onLog: logs.add,
      onStep: (done, count, current) {
        expect(count, 1);
        steps.add(current);
      },
    );
    expect(total, 0);
    expect(logs.join('\n'), contains('UserRoles'));
    expect(logs.join('\n'), isNot(contains('MobilePermissions')));
    expect(steps, contains('UserRoles'));
    expect(steps.any((step) => step.startsWith('ข้าม UserRoles:')), isTrue);
    expect(MigrationService.importBlockerForCollection('UserRoles'),
        contains('UserRoles'));
  });

  test(
      'explicit empty selection fails before database access rather than importing all',
      () async {
    await expectLater(
      MigrationService.exportAndImportToSupabase(collections: []),
      throwsArgumentError,
    );
  });
}
