/// Widget tests for [RoleBuilder] and [RestrictedWidget].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_flutter/src/presentation/builders/role_builder.dart';
import 'package:rbac_flutter/src/presentation/widgets/restricted_widget.dart';

// ---------------------------------------------------------------------------
// Shared stub notifier
// ---------------------------------------------------------------------------

class _StubRbacNotifier extends Notifier<RbacState> {
  _StubRbacNotifier(this._state);
  final RbacState _state;
  @override
  RbacState build() => _state;
}

Widget _app({required RbacState state, required Widget child}) => ProviderScope(
      overrides: [
        rbacNotifierProvider.overrideWith(() => _StubRbacNotifier(state)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

RbacReady _readyWithRoles(List<Role> roles, {bool allowWrite = false}) =>
    RbacReady(
      policy: Policy(
        id: 'test',
        version: '1.0',
        rolePermissions: {
          for (final r in roles)
            r.id: [
              const Permission(action: 'read', resource: 'dashboard'),
              if (allowWrite)
                const Permission(action: 'write', resource: 'dashboard'),
            ],
        },
      ),
      roles: roles,
    );

// ---------------------------------------------------------------------------
// RoleBuilder tests
// ---------------------------------------------------------------------------

void main() {
  group('RoleBuilder', () {
    testWidgets('calls builder with roles in Ready state', (tester) async {
      const adminRole = Role(id: 'admin', name: 'Admin');

      await tester.pumpWidget(
        _app(
          state: _readyWithRoles([adminRole]),
          child: RoleBuilder(
            builder: (ctx, roles) => Text(roles.map((r) => r.id).join(',')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('admin'), findsOneWidget);
    });

    testWidgets('shows default loading indicator in Loading state',
        (tester) async {
      await tester.pumpWidget(
        _app(
          state: const RbacLoading(),
          child: RoleBuilder(
            builder: (_, __) => const Text('Never shown'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Never shown'), findsNothing);
    });

    testWidgets('shows custom loading widget when provided', (tester) async {
      await tester.pumpWidget(
        _app(
          state: const RbacLoading(),
          child: RoleBuilder(
            loading: const Text('Loading policies…'),
            builder: (_, __) => const Text('Never shown'),
          ),
        ),
      );

      expect(find.text('Loading policies…'), findsOneWidget);
    });

    testWidgets('shows nothing in Initial state (default)', (tester) async {
      await tester.pumpWidget(
        _app(
          state: const RbacInitial(),
          child: RoleBuilder(
            builder: (_, __) => const Text('Never shown'),
          ),
        ),
      );

      expect(find.text('Never shown'), findsNothing);
    });

    testWidgets('shows error widget in Error state when provided',
        (tester) async {
      await tester.pumpWidget(
        _app(
          state: const RbacError(CacheFailure('disk error')),
          child: RoleBuilder(
            error: (msg) => Text('Error: $msg'),
            builder: (_, __) => const Text('Never shown'),
          ),
        ),
      );

      expect(find.textContaining('disk error'), findsOneWidget);
      expect(find.text('Never shown'), findsNothing);
    });

    testWidgets('passes all roles to builder for multi-role user',
        (tester) async {
      const admin = Role(id: 'admin', name: 'Admin');
      const viewer = Role(id: 'viewer', name: 'Viewer');

      await tester.pumpWidget(
        _app(
          state: _readyWithRoles([admin, viewer]),
          child: RoleBuilder(
            builder: (ctx, roles) => Column(
              children: roles.map((r) => Text(r.id)).toList(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('admin'), findsOneWidget);
      expect(find.text('viewer'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('RestrictedWidget', () {
    testWidgets('renders child normally when permission granted',
        (tester) async {
      const role = Role(id: 'admin', name: 'Admin');
      await tester.pumpWidget(
        _app(
          state: _readyWithRoles([role], allowWrite: true),
          child: RestrictedWidget(
            action: 'write',
            resource: 'dashboard',
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Save'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Child button is present and interactive
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('wraps child in Opacity + IgnorePointer when denied',
        (tester) async {
      const role = Role(id: 'viewer', name: 'Viewer');
      await tester.pumpWidget(
        _app(
          state: _readyWithRoles([role]),
          child: RestrictedWidget(
            action: 'write',
            resource: 'dashboard',
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Save'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Button text still visible (opacity, not hidden)
      expect(find.text('Save'), findsOneWidget);
      // Wrapped in IgnorePointer to block taps
      expect(find.byType(IgnorePointer), findsOneWidget);
      // Opacity widget wraps it
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets('applies custom disabledOpacity', (tester) async {
      const role = Role(id: 'viewer', name: 'Viewer');
      await tester.pumpWidget(
        _app(
          state: _readyWithRoles([role]),
          child: const RestrictedWidget(
            action: 'write',
            resource: 'dashboard',
            disabledOpacity: 0.2,
            child: Text('Button'),
          ),
        ),
      );
      await tester.pump();

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, equals(0.2));
    });

    testWidgets('shows Tooltip with default message when denied',
        (tester) async {
      const role = Role(id: 'viewer', name: 'Viewer');
      await tester.pumpWidget(
        _app(
          state: _readyWithRoles([role]),
          child: const RestrictedWidget(
            action: 'write',
            resource: 'dashboard',
            child: Text('Click me'),
          ),
        ),
      );
      await tester.pump();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals("You don't have permission"));
    });

    testWidgets('shows custom Tooltip message when denied', (tester) async {
      const role = Role(id: 'viewer', name: 'Viewer');
      await tester.pumpWidget(
        _app(
          state: _readyWithRoles([role]),
          child: const RestrictedWidget(
            action: 'write',
            resource: 'dashboard',
            tooltip: 'Editor role required',
            child: Text('Click me'),
          ),
        ),
      );
      await tester.pump();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals('Editor role required'));
    });
  });
}
