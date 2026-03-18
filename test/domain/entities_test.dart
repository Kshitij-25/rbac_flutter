// test/domain/entities_test.dart
//
// TASK 1.2 — TDD: Domain entity tests written BEFORE implementation.
// These tests define the contract for Role, Permission, Policy, Resource.

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/rbac_ui_engine.dart';

void main() {
  // ── Role ──────────────────────────────────────────────────────────────────

  group('Role', () {
    test('can be constructed with id and name', () {
      const role = Role(id: 'admin', name: 'Administrator');
      expect(role.id, 'admin');
      expect(role.name, 'Administrator');
    });

    test('has empty parent list by default', () {
      const role = Role(id: 'viewer', name: 'Viewer');
      expect(role.parentIds, isEmpty);
    });

    test('supports parent role hierarchy', () {
      const role = Role(id: 'editor', name: 'Editor', parentIds: ['viewer']);
      expect(role.parentIds, contains('viewer'));
    });

    test('two Roles with same id are equal (value equality)', () {
      const r1 = Role(id: 'admin', name: 'Administrator');
      const r2 = Role(id: 'admin', name: 'Administrator');
      expect(r1, equals(r2));
    });

    test('Roles with different ids are not equal', () {
      const r1 = Role(id: 'admin', name: 'Administrator');
      const r2 = Role(id: 'viewer', name: 'Viewer');
      expect(r1, isNot(equals(r2)));
    });

    test('isRoot is true when parentIds is empty', () {
      const role = Role(id: 'super_admin', name: 'Super Admin');
      expect(role.isRoot, isTrue);
    });

    test('isRoot is false when parentIds is not empty', () {
      const role = Role(id: 'editor', name: 'Editor', parentIds: ['viewer']);
      expect(role.isRoot, isFalse);
    });
  });

  // ── Permission ────────────────────────────────────────────────────────────

  group('Permission', () {
    test('can be constructed with resource and action', () {
      const p = Permission(
        resource: 'invoice',
        action: ActionType.read,
        effect: Effect.allow,
      );
      expect(p.resource, 'invoice');
      expect(p.action, ActionType.read);
      expect(p.effect, Effect.allow);
    });

    test('deny effect creates a Permission that denies access', () {
      const p = Permission(
        resource: 'invoice',
        action: ActionType.delete,
        effect: Effect.deny,
      );
      expect(p.isDeny, isTrue);
      expect(p.isAllow, isFalse);
    });

    test('allow effect marks permission as allowing access', () {
      const p = Permission(
        resource: 'dashboard',
        action: ActionType.read,
        effect: Effect.allow,
      );
      expect(p.isAllow, isTrue);
      expect(p.isDeny, isFalse);
    });

    test('wildcard resource matches any resource string', () {
      const p = Permission(
        resource: '*',
        action: ActionType.read,
        effect: Effect.allow,
      );
      expect(p.isWildcardResource, isTrue);
    });

    test('value equality for permissions', () {
      const p1 = Permission(
        resource: 'report',
        action: ActionType.write,
        effect: Effect.allow,
      );
      const p2 = Permission(
        resource: 'report',
        action: ActionType.write,
        effect: Effect.allow,
      );
      expect(p1, equals(p2));
    });
  });

  // ── Resource ──────────────────────────────────────────────────────────────

  group('Resource', () {
    test('can be created with id and optional attributes', () {
      final r = Resource(
        id: 'invoice:123',
        type: 'invoice',
        attributes: {'owner': 'user_42', 'status': 'draft'},
      );
      expect(r.id, 'invoice:123');
      expect(r.type, 'invoice');
      expect(r.attributes['owner'], 'user_42');
    });

    test('has empty attributes by default', () {
      final r = Resource(id: 'page:home', type: 'page');
      expect(r.attributes, isEmpty);
    });

    test('value equality', () {
      final r1 = Resource(id: 'invoice:1', type: 'invoice');
      final r2 = Resource(id: 'invoice:1', type: 'invoice');
      expect(r1, equals(r2));
    });
  });

  // ── Policy ────────────────────────────────────────────────────────────────

  group('Policy', () {
    test('can be constructed with id, version, and statements', () {
      final policy = Policy(
        id: 'policy_admin_v1',
        version: '2024-01-01',
        statements: [
          const Permission(
            resource: '*',
            action: ActionType.read,
            effect: Effect.allow,
          ),
        ],
      );
      expect(policy.id, 'policy_admin_v1');
      expect(policy.statements, hasLength(1));
    });

    test('hasPermissionFor returns true when matching allow statement exists', () {
      final policy = Policy(
        id: 'p1',
        version: '1',
        statements: [
          const Permission(
            resource: 'dashboard',
            action: ActionType.read,
            effect: Effect.allow,
          ),
        ],
      );
      expect(
        policy.hasPermissionFor(resource: 'dashboard', action: ActionType.read),
        isTrue,
      );
    });

    test('hasPermissionFor returns false when no matching statement', () {
      final policy = Policy(
        id: 'p1',
        version: '1',
        statements: [
          const Permission(
            resource: 'dashboard',
            action: ActionType.read,
            effect: Effect.allow,
          ),
        ],
      );
      expect(
        policy.hasPermissionFor(resource: 'invoice', action: ActionType.delete),
        isFalse,
      );
    });

    test('wildcard resource matches all resources in hasPermissionFor', () {
      final policy = Policy(
        id: 'p1',
        version: '1',
        statements: [
          const Permission(
            resource: '*',
            action: ActionType.read,
            effect: Effect.allow,
          ),
        ],
      );
      expect(
        policy.hasPermissionFor(resource: 'any_resource', action: ActionType.read),
        isTrue,
      );
    });

    test('explicit deny overrides allow (deny wins)', () {
      final policy = Policy(
        id: 'p1',
        version: '1',
        statements: [
          const Permission(
            resource: '*',
            action: ActionType.read,
            effect: Effect.allow,
          ),
          const Permission(
            resource: 'secret',
            action: ActionType.read,
            effect: Effect.deny,
          ),
        ],
      );
      // Explicit deny on 'secret' must win over wildcard allow
      expect(
        policy.isExplicitlyDenied(resource: 'secret', action: ActionType.read),
        isTrue,
      );
    });

    test('isEmpty returns true for policy with no statements', () {
      final policy = Policy(id: 'empty', version: '1', statements: []);
      expect(policy.isEmpty, isTrue);
    });

    test('value equality', () {
      final p1 = Policy(id: 'p1', version: '1', statements: []);
      final p2 = Policy(id: 'p1', version: '1', statements: []);
      expect(p1, equals(p2));
    });
  });

  // ── ActionType ────────────────────────────────────────────────────────────

  group('ActionType', () {
    test('contains standard CRUD actions', () {
      expect(ActionType.values, containsAll([
        ActionType.create,
        ActionType.read,
        ActionType.update,
        ActionType.delete,
      ]));
    });

    test('wildcard action exists', () {
      expect(ActionType.values, contains(ActionType.wildcard));
    });
  });

  // ── Effect ────────────────────────────────────────────────────────────────

  group('Effect', () {
    test('has allow and deny variants', () {
      expect(Effect.values, containsAll([Effect.allow, Effect.deny]));
    });
  });
}
