import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/src/domain/entities/permission.dart';

void main() {
  group('Permission', () {
    const readDashboard = Permission(
      action: 'read',
      resource: 'dashboard',
    );
    const denyDelete = Permission(
      action: 'delete',
      resource: 'invoice',
      effect: PermissionEffect.deny,
    );

    group('effect defaults', () {
      test('default effect is allow', () {
        expect(readDashboard.effect, equals(PermissionEffect.allow));
        expect(readDashboard.isAllow, isTrue);
        expect(readDashboard.isDeny, isFalse);
      });

      test('explicit deny sets effect correctly', () {
        expect(denyDelete.isDeny, isTrue);
        expect(denyDelete.isAllow, isFalse);
      });
    });

    group('equality', () {
      test('same action+resource+effect are equal', () {
        const p2 = Permission(action: 'read', resource: 'dashboard');
        expect(readDashboard, equals(p2));
      });

      test('different action makes permissions unequal', () {
        const p2 = Permission(action: 'write', resource: 'dashboard');
        expect(readDashboard, isNot(equals(p2)));
      });

      test('different effect makes permissions unequal', () {
        const p2 = Permission(
          action: 'read',
          resource: 'dashboard',
          effect: PermissionEffect.deny,
        );
        expect(readDashboard, isNot(equals(p2)));
      });

      test('hashCode is consistent with equality', () {
        const p1 = Permission(action: 'read', resource: 'dashboard');
        const p2 = Permission(action: 'read', resource: 'dashboard');
        expect(p1.hashCode, equals(p2.hashCode));
      });
    });

    group('conditions', () {
      test('default conditions map is empty', () {
        expect(readDashboard.conditions, isEmpty);
      });

      test('copyWith preserves conditions', () {
        const p = Permission(
          action: 'read',
          resource: 'report',
          conditions: {'department': 'eng'},
        );
        final copy = p.copyWith(action: 'write');
        expect(copy.conditions, equals({'department': 'eng'}));
      });
    });

    group('toString', () {
      test('includes effect name and action', () {
        expect(readDashboard.toString(), contains('allow'));
        expect(readDashboard.toString(), contains('read'));
        expect(readDashboard.toString(), contains('dashboard'));
      });
    });
  });
}
