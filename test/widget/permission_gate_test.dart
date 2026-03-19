/// Widget tests for [PermissionGate].
///
/// ## Riverpod 3.x stub pattern
/// `NotifierProvider<RbacNotifier, RbacState>.overrideWith()` requires the
/// factory to return the *exact* declared notifier type (`RbacNotifier`).
/// `_StubRbacNotifier` therefore extends `RbacNotifier` (not the base
/// `Notifier<RbacState>`) and overrides `build()` without calling `super`,
/// so none of the real infrastructure providers are ever touched.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_notifier.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_flutter/src/presentation/widgets/permission_gate.dart';

// ---------------------------------------------------------------------------
// Stub — extends RbacNotifier so overrideWith type-checks correctly
// ---------------------------------------------------------------------------

class _StubRbacNotifier extends RbacNotifier {
  _StubRbacNotifier(this._fixedState);
  final RbacState _fixedState;

  /// Override completely — never call super.build() so no ref.read happens.
  @override
  RbacState build() => _fixedState;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _app({required RbacState state, required Widget child}) => ProviderScope(
      overrides: [
        rbacNotifierProvider.overrideWith(() => _StubRbacNotifier(state)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

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
    // ── Allowed ─────────────────────────────────────────────────────────────
    group('RbacReady — allowed', () {
      testWidgets('renders child when permission is granted', (tester) async {
        await tester.pumpWidget(
          _app(
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
          _app(
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

    // ── Denied ──────────────────────────────────────────────────────────────
    group('RbacReady — denied', () {
      testWidgets('hides child when permission is denied', (tester) async {
        await tester.pumpWidget(
          _app(
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
          _app(
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

      testWidgets('renders disabledChild over fallback when both provided',
          (tester) async {
        await tester.pumpWidget(
          _app(
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

      testWidgets('renders SizedBox when denied with no fallback',
          (tester) async {
        await tester.pumpWidget(
          _app(
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
        expect(find.byType(SizedBox), findsWidgets);
      });
    });

    // ── Loading ─────────────────────────────────────────────────────────────
    group('Loading state', () {
      testWidgets('renders CircularProgressIndicator while loading',
          (tester) async {
        await tester.pumpWidget(
          _app(
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
          _app(
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

    // ── Fail-safe states ────────────────────────────────────────────────────
    group('Initial / Error states (fail-safe)', () {
      testWidgets('hides child in Initial state', (tester) async {
        await tester.pumpWidget(
          _app(
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
          _app(
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

    // ── ABAC context ─────────────────────────────────────────────────────────
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
          _app(
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
          _app(
            state: conditionalState,
            child: const PermissionGate(
              action: 'read',
              resource: 'report',
              abacContext: {'dept': 'marketing'},
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

    // ── Multi-role ───────────────────────────────────────────────────────────
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
          _app(
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
