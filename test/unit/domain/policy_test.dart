import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/src/domain/entities/permission.dart';
import 'package:rbac_ui_engine/src/domain/entities/policy.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';

void main() {
  group('Policy', () {
    final adminPermissions = [
      const Permission(action: 'read', resource: 'dashboard'),
      const Permission(action: 'write', resource: 'dashboard'),
      const Permission(action: 'delete', resource: 'invoice'),
    ];

    final viewerPermissions = [
      const Permission(action: 'read', resource: 'dashboard'),
    ];

    final policy = Policy(
      id: 'policy-v1',
      version: '1.0.0',
      rolePermissions: {
        'admin': adminPermissions,
        'viewer': viewerPermissions,
      },
    );

    group('permissionsFor', () {
      test('returns permissions for a known role', () {
        const adminRole = Role(id: 'admin', name: 'Admin');
        expect(policy.permissionsFor(adminRole), equals(adminPermissions));
      });

      test('returns empty list for unknown role', () {
        const guestRole = Role(id: 'guest', name: 'Guest');
        expect(policy.permissionsFor(guestRole), isEmpty);
      });
    });

    group('definedRoleIds', () {
      test('lists all role ids in the policy', () {
        expect(policy.definedRoleIds, containsAll(['admin', 'viewer']));
        expect(policy.definedRoleIds.length, equals(2));
      });
    });

    group('expiry', () {
      test('policy without expiry is not expired', () {
        expect(policy.isExpired, isFalse);
      });

      test('policy with past expiry is expired', () {
        final expired = policy.copyWith(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(expired.isExpired, isTrue);
      });

      test('policy with future expiry is not expired', () {
        final valid = policy.copyWith(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(valid.isExpired, isFalse);
      });
    });

    group('equality', () {
      test('same id and version are equal regardless of permissions', () {
        final p2 = Policy(
          id: 'policy-v1',
          version: '1.0.0',
          rolePermissions: const {},
        );
        expect(policy, equals(p2));
      });

      test('different version makes policies unequal', () {
        final p2 = policy.copyWith(version: '2.0.0');
        expect(policy, isNot(equals(p2)));
      });
    });

    group('defaultEffect', () {
      test('default effect is deny (fail-closed)', () {
        expect(policy.defaultEffect, equals(PermissionEffect.deny));
      });
    });
  });
}
