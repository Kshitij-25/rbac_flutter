import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';

void main() {
  group('Role', () {
    const adminRole = Role(id: 'admin', name: 'Administrator');
    const editorRole = Role(
      id: 'editor',
      name: 'Editor',
      parentRoleId: 'admin',
    );

    group('identity', () {
      test('two roles with same id are equal', () {
        const r1 = Role(id: 'admin', name: 'Administrator');
        const r2 = Role(id: 'admin', name: 'Admin'); // different name
        expect(r1, equals(r2));
      });

      test('two roles with different ids are not equal', () {
        expect(adminRole, isNot(equals(editorRole)));
      });

      test('hashCode matches for equal roles', () {
        const r1 = Role(id: 'admin', name: 'A');
        const r2 = Role(id: 'admin', name: 'B');
        expect(r1.hashCode, equals(r2.hashCode));
      });
    });

    group('hierarchy', () {
      test('root role has no parent', () {
        expect(adminRole.isRoot, isTrue);
        expect(adminRole.parentRoleId, isNull);
      });

      test('child role has parent reference', () {
        expect(editorRole.isRoot, isFalse);
        expect(editorRole.parentRoleId, equals('admin'));
      });
    });

    group('metadata', () {
      test('default metadata is empty', () {
        expect(adminRole.metadata, isEmpty);
      });

      test('copyWith preserves all fields when nothing overridden', () {
        final copy = adminRole.copyWith();
        expect(copy.id, equals(adminRole.id));
        expect(copy.name, equals(adminRole.name));
        expect(copy.parentRoleId, equals(adminRole.parentRoleId));
      });

      test('copyWith overrides only specified fields', () {
        final updated = adminRole.copyWith(name: 'Super Admin');
        expect(updated.id, equals('admin'));
        expect(updated.name, equals('Super Admin'));
      });
    });

    group('toString', () {
      test('includes id, name and parent info', () {
        final str = editorRole.toString();
        expect(str, contains('editor'));
        expect(str, contains('admin'));
      });
    });
  });
}
