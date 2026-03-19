// Example app demonstrating the RBAC UI Engine.
///
/// Features:
///   - Role switching (admin / editor / viewer / guest)
///   - Dynamic widget show/hide based on permissions
///   - Disabled interaction for unauthorised users (RestrictedWidget)
///   - Debug inspector overlay (RbacInspector)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_flutter/rbac_ui_engine.dart';
import 'package:rbac_flutter_example/screens/dashboard_screen.dart';

void main() {
  // Demo policy — in production, fetch via HttpPolicyRemoteSource.
  final demoPolicy = const Policy(
    id: 'demo-policy',
    version: '1.0.0',
    rolePermissions: {
      'admin': [
        Permission(action: '*', resource: '*'),
      ],
      'editor': [
        Permission(action: 'read', resource: '*'),
        Permission(action: 'write', resource: 'invoice'),
        Permission(action: 'write', resource: 'dashboard'),
      ],
      'viewer': [
        Permission(action: 'read', resource: '*'),
      ],
      'guest': [],
    },
  );

  final roleProvider = InMemoryRoleProvider(
    initialRoles: [const Role(id: 'viewer', name: 'Viewer')],
  );
  final policyRepository = StaticPolicyRepository(demoPolicy);

  runApp(
    ProviderScope(
      overrides: [
        policyRepositoryProvider.overrideWithValue(policyRepository),
        roleProviderProvider.overrideWithValue(roleProvider),
      ],
      child: const DemoApp(),
    ),
  );
}

class DemoApp extends ConsumerWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RbacInspector(
      child: MaterialApp(
        title: 'RBAC Engine Demo',
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const _DemoInit(),
      ),
    );
  }
}

/// Initialises the RBAC engine once, after the first frame.
class _DemoInit extends ConsumerStatefulWidget {
  const _DemoInit();
  @override
  ConsumerState<_DemoInit> createState() => _DemoInitState();
}

class _DemoInitState extends ConsumerState<_DemoInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rbacNotifierProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) => const DashboardScreen();
}
