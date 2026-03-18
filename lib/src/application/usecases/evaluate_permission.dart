/// Use case: check whether the current user may perform an action.
///
/// Orchestrates: RoleProvider → PolicyRepository → PermissionEvaluator.
/// Returns a typed result so callers don't need to handle Either directly.
library;

import 'package:rbac_ui_engine/src/domain/entities/permission.dart';
import 'package:rbac_ui_engine/src/domain/entities/resource.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/permission_evaluator.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/policy_repository.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/role_provider.dart';

sealed class EvaluationResult {
  const EvaluationResult();
}

final class AllowedResult extends EvaluationResult {
  const AllowedResult();
}

final class DeniedResult extends EvaluationResult {
  const DeniedResult({this.reason});
  final String? reason;
}

final class ErrorResult extends EvaluationResult {
  const ErrorResult(this.failure);
  final RbacFailure failure;
}

class EvaluatePermission {
  const EvaluatePermission({
    required PolicyRepository policyRepository,
    required RoleProvider roleProvider,
    required PermissionEvaluator evaluator,
  })  : _policyRepository = policyRepository,
        _roleProvider = roleProvider,
        _evaluator = evaluator;

  final PolicyRepository _policyRepository;
  final RoleProvider _roleProvider;
  final PermissionEvaluator _evaluator;

  Future<EvaluationResult> call({
    required String action,
    required Resource resource,
    Map<String, dynamic> context = const {},
  }) async {
    final rolesResult = await _roleProvider.getCurrentRoles();
    if (rolesResult.isLeft()) {
      return ErrorResult(
        rolesResult.fold((f) => f, (_) => throw StateError('unreachable')),
      );
    }
    final roles = rolesResult.getOrElse(() => []);

    final policyResult = await _policyRepository.getPolicy();
    if (policyResult.isLeft()) {
      return ErrorResult(
        policyResult.fold((f) => f, (_) => throw StateError('unreachable')),
      );
    }
    final policy =
        policyResult.getOrElse(() => throw StateError('unreachable'));

    // A user with multiple roles is allowed if ANY role grants access
    for (final role in roles) {
      final effect = _evaluator.evaluate(
        policy: policy,
        role: role,
        action: action,
        resource: resource,
        context: context,
      );
      if (effect == PermissionEffect.allow) return const AllowedResult();
    }

    return const DeniedResult(reason: 'No matching allow rule found');
  }
}
