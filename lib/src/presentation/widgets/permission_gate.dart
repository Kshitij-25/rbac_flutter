/// Declarative permission gate widget.
///
/// Renders [child] only when the current user's roles have permission
/// to perform [action] on [resource].  Handles loading / error / deny
/// states gracefully via optional [fallback] and [disabledChild] slots.
///
/// ```dart
/// PermissionGate(
///   action: 'delete',
///   resource: 'invoice',
///   fallback: const Text('No access'),
///   child: DeleteInvoiceButton(),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/resource.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/evaluator/rbac_permission_evaluator.dart';

class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.action,
    required this.resource,
    required this.child,
    this.fallback,
    this.disabledChild,
    this.loadingWidget,
    this.abacContext = const {},
  });

  /// The action to check (e.g. 'read', 'delete', 'write').
  final String action;

  /// The resource id to guard (e.g. 'dashboard', 'invoice').
  final String resource;

  /// Shown when permission is GRANTED.
  final Widget child;

  /// Shown when permission is DENIED.
  /// When both [fallback] and [disabledChild] are null, renders [SizedBox.shrink].
  final Widget? fallback;

  /// A visually-disabled version of [child] shown on DENY.
  /// Takes precedence over [fallback] when both are provided.
  final Widget? disabledChild;

  /// Shown while RBAC state is loading (default: [CircularProgressIndicator]).
  final Widget? loadingWidget;

  /// Optional ABAC attribute context for conditional permission rules.
  /// Named [abacContext] to avoid shadowing [BuildContext] in [build].
  final Map<String, dynamic> abacContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbacState = ref.watch(rbacNotifierProvider);

    return switch (rbacState) {
      RbacInitial() || RbacError() => fallback ?? const SizedBox.shrink(),
      RbacLoading() => loadingWidget ??
          const Center(child: CircularProgressIndicator.adaptive()),
      RbacReady(:final policy, :final roles) => _evaluate(policy, roles),
    };
  }

  Widget _evaluate(Policy policy, List<Role> roles) {
    const evaluator = RbacPermissionEvaluator();
    final resourceObj = Resource(id: resource);

    final allowed = roles.any(
      (role) => evaluator.isAllowed(
        policy: policy,
        role: role,
        action: action,
        resource: resourceObj,
        context: abacContext,
      ),
    );

    if (allowed) return child;
    if (disabledChild != null) return disabledChild!;
    return fallback ?? const SizedBox.shrink();
  }
}
