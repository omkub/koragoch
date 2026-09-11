import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/services/mobile_permission_migration.dart';

void main() {
  test('preserves each menu and false values, including account', () {
    final rows = MobilePermissionMigration.records(
        {'0': true, '1': false, '-1': false, 'updatedAt': 'ignored'}, 7);
    expect(rows, [
      {'id_role': 7, 'menu_id': 0, 'status': '1'},
      {'id_role': 7, 'menu_id': 1, 'status': '0'},
      {'id_role': 7, 'menu_id': -1, 'status': '0'},
    ]);
  });
  test('legacy aliases follow existing OR behavior without duplicate rows', () {
    expect(MobilePermissionMigration.records(
        {'4': false, 'จัดการระบบ': 'TRUE'}, 2), [
      {'id_role': 2, 'menu_id': 4, 'status': '1'},
    ]);
  });
  test('does not invent absent menu values', () {
    expect(MobilePermissionMigration.records({'2': '0'}, 1), [
      {'id_role': 1, 'menu_id': 2, 'status': '0'},
    ]);
  });
  test('invalid permission fails the whole role before writing', () {
    expect(() => MobilePermissionMigration.records({'0': true, '1': 'bad'}, 1),
        throwsFormatException);
    expect(() => MobilePermissionMigration.records({'0': null}, 1),
        throwsFormatException);
  });
  test('role-level fallback uses explicit status when present', () {
    expect(MobilePermissionMigration.roleRecord({'status': false, '0': true}, 3),
        {'id_role': 3, 'status': '0'});
  });

  test('role-level fallback aggregates menu permissions when status is absent', () {
    expect(MobilePermissionMigration.roleRecord({'0': false, '2': true}, 4),
        {'id_role': 4, 'status': '1'});
    expect(MobilePermissionMigration.roleRecord({'0': false, '2': false}, 4),
        {'id_role': 4, 'status': '0'});
  });
  test('unidentified status cannot silently become a menu permission', () {
    expect(() => MobilePermissionMigration.records({'status': true}, 1),
        throwsFormatException);
  });
}

