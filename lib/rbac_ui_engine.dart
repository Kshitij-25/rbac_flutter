/// RBAC UI Engine — Production-grade Role-Based UI Rendering for Flutter.
///
/// Quick start:
/// ```dart
/// ProviderScope(
///   overrides: [
///     policyRepositoryProvider.overrideWithValue(myPolicyRepository),
///     roleProviderProvider.overrideWithValue(myRoleProvider),
///   ],
///   child: MyApp(),
/// )
/// ```
library;

// Application — providers
export 'src/application/providers/rbac_providers.dart';
// Application — state
export 'src/application/state/rbac_logger.dart';
export 'src/application/state/rbac_notifier.dart';
export 'src/application/state/rbac_state.dart';
// Application — use cases
export 'src/application/usecases/evaluate_permission.dart';
export 'src/application/usecases/get_policy.dart';
export 'src/application/usecases/update_role.dart';
// Data — models
export 'src/data/models/permission_model.dart';
export 'src/data/models/policy_model.dart';
// Data — repositories (built-in implementations)
export 'src/data/repositories/policy_repository_impl.dart';
export 'src/data/repositories/role_provider_impl.dart';
export 'src/data/repositories/static_policy_repository.dart';
// Data — sources
export 'src/data/sources/local/policy_cache_source.dart';
export 'src/data/sources/remote/policy_remote_source.dart'; // includes RbacHttpClient + DioRbacHttpClient
// Domain — entities
export 'src/domain/entities/permission.dart';
export 'src/domain/entities/policy.dart';
export 'src/domain/entities/resource.dart';
export 'src/domain/entities/role.dart';
// Domain — evaluator
export 'src/domain/evaluator/rbac_permission_evaluator.dart';
// Domain — exceptions
export 'src/domain/exceptions/rbac_failure.dart';
// Domain — interfaces (ports)
export 'src/domain/interfaces/permission_evaluator.dart';
export 'src/domain/interfaces/policy_repository.dart';
export 'src/domain/interfaces/role_provider.dart';
// Presentation — builders
export 'src/presentation/builders/role_builder.dart';
// Presentation — guards
export 'src/presentation/guards/rbac_route_guard.dart';
// Presentation — widgets
export 'src/presentation/widgets/permission_gate.dart';
export 'src/presentation/widgets/rbac_inspector.dart';
export 'src/presentation/widgets/restricted_widget.dart';
