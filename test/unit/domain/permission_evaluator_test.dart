/// TDD tests for [RbacPermissionEvaluator].
/// Tests written BEFORE the evaluator implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/resource.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/evaluator/rbac_permission_evaluator.dart';

void main() {
  late RbacPermissionEvaluator evaluator;

  const adminRole = Role(id: 'admin', name: 'Admin');
  const viewerRole = Role(id: 'viewer', name: 'Viewer');
  const editorRole = Role(id: 'editor', name: 'Editor', parentRoleId: 'viewer');
  const guestRole = Role(id: 'guest', name: 'Guest');

  const dashboardResource = Resource(id: 'dashboard');
  const invoiceResource = Resource(id: 'invoice');
  const settingsResource = Resource(id: 'settings');

  late Policy policy;

  setUp(() {
    evaluator = const RbacPermissionEvaluator();
    policy = const Policy(
      id: 'p1',
      version: '1.0',
      rolePermissions: {
        'admin': [
          Permission(action: 'read', resource: 'dashboard'),
          Permission(action: 'write', resource: 'dashboard'),
          Permission(action: 'delete', resource: 'invoice'),
          Permission(action: '*', resource: 'settings'),
          Permission(action: 'read', resource: '*'),
        ],
        'viewer': [
          Permission(action: 'read', resource: 'dashboard'),
        ],
        'editor': [
          Permission(action: 'write', resource: 'invoice'),
        ],
      },
    );
  });

  // ── Basic evaluation ────────────────────────────────────────────────────
  group('Basic evaluation', () {
    test('allows when exact permission matches', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: adminRole,
          action: 'read',
          resource: dashboardResource,
          context: {},
        ),
        isTrue,
      );
    });

    test('denies when no matching permission exists', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: viewerRole,
          action: 'write',
          resource: dashboardResource,
          context: {},
        ),
        isFalse,
      );
    });

    test('denies for role with no permissions', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: guestRole,
          action: 'read',
          resource: dashboardResource,
          context: {},
        ),
        isFalse,
      );
    });

    test('explicit deny wins over allow for same action+resource', () {
      final denyPolicy = const Policy(
        id: 'p2',
        version: '1.0',
        rolePermissions: {
          'admin': [
            Permission(action: 'read', resource: 'dashboard'),
            Permission(
              action: 'read',
              resource: 'dashboard',
              effect: PermissionEffect.deny,
            ),
          ],
        },
      );
      expect(
        evaluator.isAllowed(
          policy: denyPolicy,
          role: adminRole,
          action: 'read',
          resource: dashboardResource,
          context: {},
        ),
        isFalse,
      );
    });
  });

  // ── Wildcard evaluation ─────────────────────────────────────────────────
  group('Wildcard evaluation', () {
    test('wildcard action (*) allows any action on that resource', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: adminRole,
          action: 'purge',
          resource: settingsResource,
          context: {},
        ),
        isTrue,
      );
    });

    test('wildcard resource (*) allows action on any resource', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: adminRole,
          action: 'read',
          resource: invoiceResource,
          context: {},
        ),
        isTrue,
      );
    });

    test('wildcard does not grant non-matching action', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: viewerRole,
          action: 'delete',
          resource: dashboardResource,
          context: {},
        ),
        isFalse,
      );
    });
  });

  // ── Role hierarchy ──────────────────────────────────────────────────────
  group('Role hierarchy', () {
    test('child role inherits parent permissions', () {
      // editor.parentRoleId = 'viewer'; viewer can read dashboard
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: editorRole,
          action: 'read',
          resource: dashboardResource,
          context: {},
        ),
        isTrue,
      );
    });

    test('child role retains its own permissions', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: editorRole,
          action: 'write',
          resource: invoiceResource,
          context: {},
        ),
        isTrue,
      );
    });

    test('parent does NOT inherit child permissions', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: viewerRole,
          action: 'write',
          resource: invoiceResource,
          context: {},
        ),
        isFalse,
      );
    });
  });

  // ── ABAC conditions ─────────────────────────────────────────────────────
  group('Conditional / ABAC rules', () {
    const analystRole = Role(id: 'analyst', name: 'Analyst');

    Policy conditionalPolicy() => const Policy(
          id: 'cp',
          version: '1.0',
          rolePermissions: {
            'analyst': [
              Permission(
                action: 'read',
                resource: 'report',
                conditions: {'department': 'engineering'},
              ),
            ],
          },
        );

    test('allows when condition attributes match context', () {
      expect(
        evaluator.isAllowed(
          policy: conditionalPolicy(),
          role: analystRole,
          action: 'read',
          resource: const Resource(id: 'report'),
          context: {'department': 'engineering'},
        ),
        isTrue,
      );
    });

    test('denies when condition attributes do not match context', () {
      expect(
        evaluator.isAllowed(
          policy: conditionalPolicy(),
          role: analystRole,
          action: 'read',
          resource: const Resource(id: 'report'),
          context: {'department': 'marketing'},
        ),
        isFalse,
      );
    });

    test('permission with no conditions matches any context', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: adminRole,
          action: 'write',
          resource: dashboardResource,
          context: {'anything': 'at all'},
        ),
        isTrue,
      );
    });
  });

  // ── evaluate() return type ──────────────────────────────────────────────
  group('evaluate() returns PermissionEffect', () {
    test('returns allow for permitted action', () {
      final effect = evaluator.evaluate(
        policy: policy,
        role: viewerRole,
        action: 'read',
        resource: dashboardResource,
        context: {},
      );
      expect(effect, equals(PermissionEffect.allow));
    });

    test('returns deny for unpermitted action', () {
      final effect = evaluator.evaluate(
        policy: policy,
        role: guestRole,
        action: 'read',
        resource: dashboardResource,
        context: {},
      );
      expect(effect, equals(PermissionEffect.deny));
    });
  });
}
