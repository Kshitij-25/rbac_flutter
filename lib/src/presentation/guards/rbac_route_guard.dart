/// GoRouter-compatible route guard.
///
/// Usage with go_router:
/// ```dart
/// GoRoute(
///   path: '/admin',
///   redirect: (ctx, state) => RbacRouteGuard(
///     ref: ref,
///     action: 'view',
///     resource: 'admin_panel',
///     redirectTo: '/unauthorized',
///   ).redirect(ctx, state),
///   builder: (_, __) => AdminScreen(),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_ui_engine/src/application/providers/rbac_providers.dart';
import 'package:rbac_ui_engine/src/application/state/rbac_state.dart';
import 'package:rbac_ui_engine/src/domain/entities/resource.dart';
import 'package:rbac_ui_engine/src/domain/evaluator/rbac_permission_evaluator.dart';

class RbacRouteGuard {
  const RbacRouteGuard({
    required this.ref,
    required this.action,
    required this.resource,
    this.redirectTo = '/unauthorized',
    this.context = const {},
  });

  final WidgetRef ref;
  final String action;
  final String resource;
  final String redirectTo;
  final Map<String, dynamic> context;

  /// Returns null (allow navigation) or [redirectTo] (deny navigation).
  /// Compatible with GoRouter's redirect callback signature.
  String? redirect(BuildContext ctx, Object routerState) {
    final rbacState = ref.read(rbacNotifierProvider);

    if (rbacState is! RbacReady) return redirectTo;

    const evaluator = RbacPermissionEvaluator();
    final resourceObj = Resource(
      id: resource,
      type: ResourceType.route,
    );

    final allowed = rbacState.roles.any(
      (role) => evaluator.isAllowed(
        policy: rbacState.policy,
        role: role,
        action: action,
        resource: resourceObj,
        context: context,
      ),
    );

    return allowed ? null : redirectTo;
  }

  /// Synchronous check — useful when you don't need a redirect path,
  /// only a boolean decision.
  bool isAllowed() {
    final rbacState = ref.read(rbacNotifierProvider);
    if (rbacState is! RbacReady) return false;

    const evaluator = RbacPermissionEvaluator();
    final resourceObj = Resource(id: resource, type: ResourceType.route);

    return rbacState.roles.any(
      (role) => evaluator.isAllowed(
        policy: rbacState.policy,
        role: role,
        action: action,
        resource: resourceObj,
        context: context,
      ),
    );
  }
}

/// Imperative navigator-based guard for apps not using GoRouter.
/// Pushes [redirectTo] route if permission is denied.
class RbacNavigatorGuard {
  const RbacNavigatorGuard({
    required this.ref,
    required this.action,
    required this.resource,
    this.redirectTo = '/unauthorized',
  });

  final WidgetRef ref;
  final String action;
  final String resource;
  final String redirectTo;

  void guard(BuildContext context) {
    final guard = RbacRouteGuard(
      ref: ref,
      action: action,
      resource: resource,
      redirectTo: redirectTo,
    );
    if (!guard.isAllowed()) {
      Navigator.of(context).pushReplacementNamed(redirectTo);
    }
  }
}
