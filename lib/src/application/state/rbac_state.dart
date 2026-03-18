/// Immutable state model for the RBAC engine's reactive state.
library;

import 'package:rbac_ui_engine/src/domain/entities/policy.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';

sealed class RbacState {
  const RbacState();
}

/// Engine hasn't been initialised yet.
final class RbacInitial extends RbacState {
  const RbacInitial();
}

/// Policy/role loading in progress.
final class RbacLoading extends RbacState {
  const RbacLoading();
}

/// Policy and roles loaded successfully — engine is ready.
final class RbacReady extends RbacState {
  const RbacReady({
    required this.policy,
    required this.roles,
  });

  final Policy policy;
  final List<Role> roles;

  RbacReady copyWith({Policy? policy, List<Role>? roles}) => RbacReady(
        policy: policy ?? this.policy,
        roles: roles ?? this.roles,
      );
}

/// A failure occurred during initialisation or refresh.
final class RbacError extends RbacState {
  const RbacError(this.failure);
  final RbacFailure failure;
}
