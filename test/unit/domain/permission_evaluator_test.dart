/// TDD tests for the permission evaluator.
/// Tests are written BEFORE the evaluator implementation.
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

  final dashboardResource = const Resource(id: 'dashboard');
  final invoiceResource = const Resource(id: 'invoice');
  final analyticsResource = const Resource(id: 'dashboard.analytics');

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
          Permission(action: '*', resource: 'settings'), // wildcard action
          Permission(action: 'read', resource: '*'), // wildcard resource
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

    test('deny effect overrides allow — explicit deny wins', () {
      final denyPolicy = const Policy(
        id: 'p2',
        version: '1.0',
        rolePermissions: {
          'admin': [
            Permission(action: 'read', resource: 'dashboard'),
            Permission(
              action: 'read',
              resource: 'dashboard',
              effect: PermissionEffect.deny, // explicit deny wins
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

  group('Wildcard evaluation', () {
    test('wildcard action (*) allows any action on that resource', () {
      expect(
        evaluator.isAllowed(
          policy: policy,
          role: adminRole,
          action: 'purge', // not listed explicitly
          resource: const Resource(id: 'settings'),
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
          resource: invoiceResource, // not listed explicitly for read
          context: {},
        ),
        isTrue,
      );
    });

    test('wildcard does not grant non-matching action on resource', () {
      // viewer only has read on dashboard
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

  group('Role hierarchy', () {
    test('child role inherits parent permissions', () {
      // editor has parentRoleId = viewer; viewer can read dashboard
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

    test('child role keeps its own permissions', () {
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

  group('Conditional / ABAC rules', () {
    test('allows when condition attributes match context', () {
      final conditionalPolicy = const Policy(
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
      const analystRole = Role(id: 'analyst', name: 'Analyst');

      expect(
        evaluator.isAllowed(
          policy: conditionalPolicy,
          role: analystRole,
          action: 'read',
          resource: const Resource(id: 'report'),
          context: {'department': 'engineering'},
        ),
        isTrue,
      );
    });

    test('denies when condition attributes do not match context', () {
      final conditionalPolicy = const Policy(
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
      const analystRole = Role(id: 'analyst', name: 'Analyst');

      expect(
        evaluator.isAllowed(
          policy: conditionalPolicy,
          role: analystRole,
          action: 'read',
          resource: const Resource(id: 'report'),
          context: {'department': 'marketing'}, // wrong dept
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
