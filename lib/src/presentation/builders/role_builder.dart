/// Builds UI based on the current user's role(s).
///
/// Usage:
/// ```dart
/// RoleBuilder(
///   builder: (context, roles) {
///     if (roles.any((r) => r.id == 'admin')) return AdminDashboard();
///     return ViewerDashboard();
///   },
///   loading: CircularProgressIndicator(),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';

typedef RoleWidgetBuilder = Widget Function(
  BuildContext context,
  List<Role> roles,
);

class RoleBuilder extends ConsumerWidget {
  const RoleBuilder({
    super.key,
    required this.builder,
    this.loading,
    this.error,
  });

  final RoleWidgetBuilder builder;
  final Widget? loading;
  final Widget Function(String message)? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rbacNotifierProvider);

    return switch (state) {
      RbacInitial() ||
      RbacLoading() =>
        loading ?? const CircularProgressIndicator.adaptive(),
      RbacError(:final failure) =>
        error?.call(failure.message) ?? const SizedBox.shrink(),
      RbacReady(:final roles) => builder(context, roles),
    };
  }
}
