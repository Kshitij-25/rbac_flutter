/// Contract for the permission evaluation engine.
///
/// Separating evaluation from policy storage allows the evaluator
/// to be swapped (local rules vs remote OPA call) without changing
/// anything in the presentation or application layers.
library;

import 'package:rbac_ui_engine/src/domain/entities/permission.dart';
import 'package:rbac_ui_engine/src/domain/entities/policy.dart';
import 'package:rbac_ui_engine/src/domain/entities/resource.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';

abstract interface class PermissionEvaluator {
  /// Returns [PermissionEffect.allow] or [PermissionEffect.deny] for
  /// the given [role] attempting [action] on [resource] under [policy].
  ///
  /// Evaluation order (OPA-inspired):
  ///   1. Explicit deny rules take precedence (fail-closed)
  ///   2. Explicit allow rules
  ///   3. Wildcard matches
  ///   4. Role hierarchy (inherited permissions)
  ///   5. Policy default effect
  PermissionEffect evaluate({
    required Policy policy,
    required Role role,
    required String action,
    required Resource resource,
    Map<String, dynamic> context,
  });

  /// Convenience: returns true if [evaluate] → allow.
  bool isAllowed({
    required Policy policy,
    required Role role,
    required String action,
    required Resource resource,
    Map<String, dynamic> context,
  });
}
