/// Widget tests for [PermissionGate].
///
/// We inject a [_StubRbacNotifier] via [rbacNotifierProvider.overrideWith]
/// so we can force any [RbacState] without touching repositories.
///
/// Pattern:
///   rbacNotifierProvider.overrideWith(() => _StubRbacNotifier(state))
///
/// This is the idiomatic Riverpod 3.x way to stub a [NotifierProvider].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/presentation/widgets/permission_gate.dart';

// ---------------------------------------------------------------------------
// Test stub — injects a fixed RbacState with no side-effects
// ---------------------------------------------------------------------------

class _StubRbacNotifier extends Notifier<RbacState> {
  _StubRbacNotifier(this._fixedState);
  final RbacState _fixedState;

  @override
  RbacState build() => _fixedState;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({required RbacState state, required Widget child}) {
  return ProviderScope(
    overrides: [
      rbacNotifierProvider.overrideWith(() => _StubRbacNotifier(state)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Builds a [RbacReady] state.
/// [allowRead] controls whether the admin role has read on dashboard.
RbacReady _readyState({
  bool allowReadDashboard = true,
  bool allowWriteDashboard = false,
  String roleId = 'admin',
}) {
  final permissions = <Permission>[
    if (allowReadDashboard)
      const Permission(action: 'read', resource: 'dashboard'),
    if (allowWriteDashboard)
      const Permission(action: 'write', resource: 'dashboard'),
  ];

  return RbacReady(
    policy: Policy(
      id: 'test',
      version: '1.0',
      rolePermissions: {roleId: permissions},
    ),
    roles: [Role(id: roleId, name: roleId)],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PermissionGate', () {
    // -----------------------------------------------------------------------
    group('RbacReady — allowed', () {
      testWidgets('renders child when permission is granted', (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: _readyState(),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              child: Text('Protected Content'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Protected Content'), findsOneWidget);
      });

      testWidgets('does not render fallback when allowed', (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: _readyState(),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              fallback: Text('Denied'),
              child: Text('Allowed'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Allowed'), findsOneWidget);
        expect(find.text('Denied'), findsNothing);
      });
    });

    // -----------------------------------------------------------------------
    group('RbacReady — denied', () {
      testWidgets('hides child when permission is denied', (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: _readyState(allowReadDashboard: false),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              child: Text('Protected Content'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Protected Content'), findsNothing);
      });

      testWidgets('renders fallback when denied and fallback provided',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: _readyState(allowReadDashboard: false),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              fallback: Text('Access Denied'),
              child: Text('Protected Content'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Access Denied'), findsOneWidget);
        expect(find.text('Protected Content'), findsNothing);
      });

      testWidgets(
          'renders disabledChild instead of fallback when both provided',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: _readyState(allowReadDashboard: false),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              fallback: Text('Fallback'),
              disabledChild: Text('Disabled Version'),
              child: Text('Active Version'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Disabled Version'), findsOneWidget);
        expect(find.text('Fallback'), findsNothing);
        expect(find.text('Active Version'), findsNothing);
      });

      testWidgets('renders SizedBox.shrink when denied with no fallback',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: _readyState(allowReadDashboard: false),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              child: Text('Protected Content'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Protected Content'), findsNothing);
        // SizedBox.shrink has zero size — we just verify no content visible
        expect(find.byType(SizedBox), findsWidgets);
      });
    });

    // -----------------------------------------------------------------------
    group('Loading state', () {
      testWidgets('renders default CircularProgressIndicator while loading',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: const RbacLoading(),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              child: Text('Hidden'),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Hidden'), findsNothing);
      });

      testWidgets('renders custom loadingWidget when provided', (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: const RbacLoading(),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              loadingWidget: Text('Loading…'),
              child: Text('Hidden'),
            ),
          ),
        );

        expect(find.text('Loading…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    // -----------------------------------------------------------------------
    group('Initial / Error states (fail-safe)', () {
      testWidgets('hides child in Initial state (fail-closed)', (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: const RbacInitial(),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              child: Text('Protected'),
            ),
          ),
        );

        expect(find.text('Protected'), findsNothing);
      });

      testWidgets('shows fallback in Error state', (tester) async {
        await tester.pumpWidget(
          _buildApp(
            state: const RbacError(PolicyFetchFailure('Network down')),
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              fallback: Text('Service unavailable'),
              child: Text('Protected'),
            ),
          ),
        );

        expect(find.text('Service unavailable'), findsOneWidget);
        expect(find.text('Protected'), findsNothing);
      });
    });

    // -----------------------------------------------------------------------
    group('ABAC context (abacContext)', () {
      testWidgets('allows when abacContext matches policy conditions',
          (tester) async {
        final conditionalState = const RbacReady(
          policy: Policy(
            id: 'p',
            version: '1.0',
            rolePermissions: {
              'analyst': [
                Permission(
                  action: 'read',
                  resource: 'report',
                  conditions: {'dept': 'eng'},
                ),
              ],
            },
          ),
          roles: [Role(id: 'analyst', name: 'Analyst')],
        );

        await tester.pumpWidget(
          _buildApp(
            state: conditionalState,
            child: const PermissionGate(
              action: 'read',
              resource: 'report',
              abacContext: {'dept': 'eng'},
              child: Text('Confidential Report'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Confidential Report'), findsOneWidget);
      });

      testWidgets('denies when abacContext does not match conditions',
          (tester) async {
        final conditionalState = const RbacReady(
          policy: Policy(
            id: 'p',
            version: '1.0',
            rolePermissions: {
              'analyst': [
                Permission(
                  action: 'read',
                  resource: 'report',
                  conditions: {'dept': 'eng'},
                ),
              ],
            },
          ),
          roles: [Role(id: 'analyst', name: 'Analyst')],
        );

        await tester.pumpWidget(
          _buildApp(
            state: conditionalState,
            child: const PermissionGate(
              action: 'read',
              resource: 'report',
              abacContext: {'dept': 'marketing'}, // wrong dept
              fallback: Text('Not authorised'),
              child: Text('Confidential Report'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Not authorised'), findsOneWidget);
        expect(find.text('Confidential Report'), findsNothing);
      });
    });

    // -----------------------------------------------------------------------
    group('Multi-role user', () {
      testWidgets('allows if any assigned role has permission', (tester) async {
        final multiRoleState = const RbacReady(
          policy: Policy(
            id: 'p',
            version: '1.0',
            rolePermissions: {
              'guest': [],
              'editor': [
                Permission(action: 'read', resource: 'dashboard'),
              ],
            },
          ),
          roles: [
            Role(id: 'guest', name: 'Guest'),
            Role(id: 'editor', name: 'Editor'),
          ],
        );

        await tester.pumpWidget(
          _buildApp(
            state: multiRoleState,
            child: const PermissionGate(
              action: 'read',
              resource: 'dashboard',
              child: Text('Dashboard'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Dashboard'), findsOneWidget);
      });
    });
  });
}
