/// Integration test — wires all real layers together.
///
/// Uses [StaticPolicyRepository] and [InMemoryRoleProvider] (no mocks).
/// Tests the full vertical slice: roles → policy fetch → evaluation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/rbac_ui_engine.dart';

void main() {
  group('RBAC Engine — Full Integration', () {
    late StaticPolicyRepository policyRepo;
    late InMemoryRoleProvider roleProvider;
    late EvaluatePermission evaluatePermission;

    final fullPolicy = const Policy(
      id: 'integration-policy',
      version: '1.0.0',
      rolePermissions: {
        'admin': [
          Permission(action: '*', resource: '*'),
        ],
        'editor': [
          Permission(action: 'read', resource: '*'),
          Permission(action: 'write', resource: 'invoice'),
        ],
        'viewer': [
          Permission(action: 'read', resource: 'dashboard'),
        ],
        'blocked': [
          // Explicit deny on everything — deny wins over any inherited allow
          Permission(
            action: '*',
            resource: '*',
            effect: PermissionEffect.deny,
          ),
        ],
      },
    );

    setUp(() {
      policyRepo = StaticPolicyRepository(fullPolicy);
      roleProvider = InMemoryRoleProvider();
      evaluatePermission = EvaluatePermission(
        policyRepository: policyRepo,
        roleProvider: roleProvider,
        evaluator: const RbacPermissionEvaluator(),
      );
    });

    // -----------------------------------------------------------------------
    group('Single role access', () {
      test('admin can perform any action on any resource', () async {
        await roleProvider.setRoles(
          [const Role(id: 'admin', name: 'Admin')],
        );

        final result = await evaluatePermission(
          action: 'delete',
          resource: const Resource(id: 'anything'),
        );
        expect(result, isA<AllowedResult>());
      });

      test('viewer can read dashboard', () async {
        await roleProvider.setRoles(
          [const Role(id: 'viewer', name: 'Viewer')],
        );

        final result = await evaluatePermission(
          action: 'read',
          resource: const Resource(id: 'dashboard'),
        );
        expect(result, isA<AllowedResult>());
      });

      test('viewer cannot write dashboard', () async {
        await roleProvider.setRoles(
          [const Role(id: 'viewer', name: 'Viewer')],
        );

        final result = await evaluatePermission(
          action: 'write',
          resource: const Resource(id: 'dashboard'),
        );
        expect(result, isA<DeniedResult>());
      });

      test('editor can write invoice but not delete it', () async {
        await roleProvider.setRoles(
          [const Role(id: 'editor', name: 'Editor')],
        );

        expect(
          await evaluatePermission(
            action: 'write',
            resource: const Resource(id: 'invoice'),
          ),
          isA<AllowedResult>(),
        );
        expect(
          await evaluatePermission(
            action: 'delete',
            resource: const Resource(id: 'invoice'),
          ),
          isA<DeniedResult>(),
        );
      });

      test('blocked role is denied despite wildcard (deny wins)', () async {
        await roleProvider.setRoles(
          [const Role(id: 'blocked', name: 'Blocked')],
        );

        final result = await evaluatePermission(
          action: 'read',
          resource: const Resource(id: 'dashboard'),
        );
        expect(result, isA<DeniedResult>());
      });

      test('user with no roles is always denied', () async {
        await roleProvider.setRoles([]);

        final result = await evaluatePermission(
          action: 'read',
          resource: const Resource(id: 'dashboard'),
        );
        expect(result, isA<DeniedResult>());
      });
    });

    // -----------------------------------------------------------------------
    group('Multi-role user (ANY semantics)', () {
      test('allowed if any single role grants access', () async {
        // guest (no perms) + editor (can read dashboard via wildcard)
        await roleProvider.setRoles([
          const Role(id: 'viewer', name: 'Viewer'),
          const Role(id: 'editor', name: 'Editor'),
        ]);

        // viewer grants read on dashboard
        expect(
          await evaluatePermission(
            action: 'read',
            resource: const Resource(id: 'dashboard'),
          ),
          isA<AllowedResult>(),
        );

        // editor grants write on invoice
        expect(
          await evaluatePermission(
            action: 'write',
            resource: const Resource(id: 'invoice'),
          ),
          isA<AllowedResult>(),
        );
      });

      test('denied when no role grants access', () async {
        await roleProvider.setRoles([
          const Role(id: 'viewer', name: 'Viewer'),
        ]);

        expect(
          await evaluatePermission(
            action: 'delete',
            resource: const Resource(id: 'invoice'),
          ),
          isA<DeniedResult>(),
        );
      });
    });

    // -----------------------------------------------------------------------
    group('Reactivity', () {
      test('role switch immediately changes evaluation result', () async {
        await roleProvider.setRoles(
          [const Role(id: 'viewer', name: 'Viewer')],
        );

        expect(
          await evaluatePermission(
            action: 'write',
            resource: const Resource(id: 'invoice'),
          ),
          isA<DeniedResult>(),
        );

        // Switch to editor
        await roleProvider.setRoles(
          [const Role(id: 'editor', name: 'Editor')],
        );

        expect(
          await evaluatePermission(
            action: 'write',
            resource: const Resource(id: 'invoice'),
          ),
          isA<AllowedResult>(),
        );
      });

      test('policy hot-swap propagates new rules immediately', () async {
        await roleProvider.setRoles(
          [const Role(id: 'viewer', name: 'Viewer')],
        );

        // Initially viewer cannot delete dashboard
        expect(
          await evaluatePermission(
            action: 'delete',
            resource: const Resource(id: 'dashboard'),
          ),
          isA<DeniedResult>(),
        );

        // Push updated policy granting viewer delete on dashboard
        policyRepo.updatePolicy(
          const Policy(
            id: 'integration-policy',
            version: '2.0.0',
            rolePermissions: {
              'viewer': [
                Permission(action: 'delete', resource: 'dashboard'),
              ],
            },
          ),
        );

        expect(
          await evaluatePermission(
            action: 'delete',
            resource: const Resource(id: 'dashboard'),
          ),
          isA<AllowedResult>(),
        );
      });
    });

    // -----------------------------------------------------------------------
    group('ABAC conditional permissions', () {
      test('grants access when context matches conditions', () async {
        final abacPolicy = const Policy(
          id: 'abac-policy',
          version: '1.0',
          rolePermissions: {
            'analyst': [
              Permission(
                action: 'read',
                resource: 'report',
                conditions: {'clearance': 'top-secret'},
              ),
            ],
          },
        );
        final abacRepo = StaticPolicyRepository(abacPolicy);
        await roleProvider.setRoles(
          [const Role(id: 'analyst', name: 'Analyst')],
        );

        final abacEval = EvaluatePermission(
          policyRepository: abacRepo,
          roleProvider: roleProvider,
          evaluator: const RbacPermissionEvaluator(),
        );

        expect(
          await abacEval(
            action: 'read',
            resource: const Resource(id: 'report'),
            context: {'clearance': 'top-secret'},
          ),
          isA<AllowedResult>(),
        );
      });

      test('denies access when context does not match conditions', () async {
        final abacPolicy = const Policy(
          id: 'abac-policy',
          version: '1.0',
          rolePermissions: {
            'analyst': [
              Permission(
                action: 'read',
                resource: 'report',
                conditions: {'clearance': 'top-secret'},
              ),
            ],
          },
        );
        final abacRepo = StaticPolicyRepository(abacPolicy);
        await roleProvider.setRoles(
          [const Role(id: 'analyst', name: 'Analyst')],
        );

        final abacEval = EvaluatePermission(
          policyRepository: abacRepo,
          roleProvider: roleProvider,
          evaluator: const RbacPermissionEvaluator(),
        );

        expect(
          await abacEval(
            action: 'read',
            resource: const Resource(id: 'report'),
            context: {'clearance': 'confidential'}, // wrong level
          ),
          isA<DeniedResult>(),
        );
      });
    });

    // -----------------------------------------------------------------------
    group('Role hierarchy inheritance', () {
      test('child role inherits permissions from parent', () async {
        final hierarchyPolicy = const Policy(
          id: 'hierarchy-policy',
          version: '1.0',
          rolePermissions: {
            'viewer': [
              Permission(action: 'read', resource: 'dashboard'),
            ],
            'editor': [
              Permission(action: 'write', resource: 'invoice'),
            ],
          },
        );
        final hierarchyRepo = StaticPolicyRepository(hierarchyPolicy);

        // editor has parentRoleId: 'viewer' — should inherit read on dashboard
        await roleProvider.setRoles([
          const Role(id: 'editor', name: 'Editor', parentRoleId: 'viewer'),
        ]);

        final eval = EvaluatePermission(
          policyRepository: hierarchyRepo,
          roleProvider: roleProvider,
          evaluator: const RbacPermissionEvaluator(),
        );

        // Own permission
        expect(
          await eval(
            action: 'write',
            resource: const Resource(id: 'invoice'),
          ),
          isA<AllowedResult>(),
        );

        // Inherited from viewer parent
        expect(
          await eval(
            action: 'read',
            resource: const Resource(id: 'dashboard'),
          ),
          isA<AllowedResult>(),
        );
      });
    });
  });
}
