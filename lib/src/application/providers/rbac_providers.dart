/// Riverpod provider declarations.
///
/// ## Consumer setup
/// In your app's [ProviderScope], override the two infrastructure providers:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     policyRepositoryProvider.overrideWithValue(myPolicyRepo),
///     roleProviderProvider.overrideWithValue(myRoleProvider),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// Everything else (use cases, evaluator, notifier) wires up automatically.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_ui_engine/src/application/state/rbac_notifier.dart';
import 'package:rbac_ui_engine/src/application/state/rbac_state.dart';
import 'package:rbac_ui_engine/src/application/usecases/evaluate_permission.dart';
import 'package:rbac_ui_engine/src/application/usecases/get_policy.dart';
import 'package:rbac_ui_engine/src/application/usecases/update_role.dart';
import 'package:rbac_ui_engine/src/domain/evaluator/rbac_permission_evaluator.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/permission_evaluator.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/policy_repository.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/role_provider.dart';

// ---------------------------------------------------------------------------
// Infrastructure — MUST be overridden in ProviderScope
// ---------------------------------------------------------------------------

/// Override with your [PolicyRepository] implementation.
final policyRepositoryProvider = Provider<PolicyRepository>(
  (ref) => throw UnimplementedError(
    'Override policyRepositoryProvider in your ProviderScope.',
  ),
  name: 'policyRepositoryProvider',
);

/// Override with your [RoleProvider] implementation.
final roleProviderProvider = Provider<RoleProvider>(
  (ref) => throw UnimplementedError(
    'Override roleProviderProvider in your ProviderScope.',
  ),
  name: 'roleProviderProvider',
);

// ---------------------------------------------------------------------------
// Domain
// ---------------------------------------------------------------------------

final permissionEvaluatorProvider = Provider<PermissionEvaluator>(
  (_) => const RbacPermissionEvaluator(),
  name: 'permissionEvaluatorProvider',
);

// ---------------------------------------------------------------------------
// Use cases
// ---------------------------------------------------------------------------

final getPolicyUseCaseProvider = Provider<GetPolicy>(
  (ref) => GetPolicy(ref.watch(policyRepositoryProvider)),
  name: 'getPolicyUseCaseProvider',
);

final updateRoleUseCaseProvider = Provider<UpdateRole>(
  (ref) => UpdateRole(ref.watch(roleProviderProvider)),
  name: 'updateRoleUseCaseProvider',
);

final evaluatePermissionUseCaseProvider = Provider<EvaluatePermission>(
  (ref) => EvaluatePermission(
    policyRepository: ref.watch(policyRepositoryProvider),
    roleProvider: ref.watch(roleProviderProvider),
    evaluator: ref.watch(permissionEvaluatorProvider),
  ),
  name: 'evaluatePermissionUseCaseProvider',
);

// ---------------------------------------------------------------------------
// RBAC engine notifier — the single source of truth for UI state
// ---------------------------------------------------------------------------

/// The top-level RBAC state notifier.
///
/// Reads [policyRepositoryProvider] and [roleProviderProvider] via [ref].
/// Consumers must override those two providers before this is accessed.
final rbacNotifierProvider = NotifierProvider<RbacNotifier, RbacState>(
  RbacNotifier.new,
  name: 'rbacNotifierProvider',
);
