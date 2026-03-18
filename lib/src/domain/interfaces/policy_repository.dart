/// Abstract repository contract for fetching and persisting policies.
///
/// Follows the Repository pattern from DDD. Concrete implementations
/// live in the data layer and are injected at runtime.
library;

import 'package:dartz/dartz.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';

abstract interface class PolicyRepository {
  /// Fetch the active policy, preferring cache, falling back to remote.
  Future<Either<RbacFailure, Policy>> getPolicy();

  /// Force a fresh fetch from the remote source, updating cache.
  Future<Either<RbacFailure, Policy>> refreshPolicy();

  /// Clear the locally cached policy.
  Future<Either<RbacFailure, Unit>> clearCache();

  /// Stream that emits whenever the policy changes.
  Stream<Policy> get policyChanges;
}
