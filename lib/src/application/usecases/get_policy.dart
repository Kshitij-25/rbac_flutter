/// Use case: fetch the active policy.
///
/// Wraps the repository call behind a clean interface so that
/// the presentation layer never touches repositories directly.
library;

import 'package:dartz/dartz.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_flutter/src/domain/interfaces/policy_repository.dart';

class GetPolicy {
  const GetPolicy(this._repository);
  final PolicyRepository _repository;

  Future<Either<RbacFailure, Policy>> call({bool forceRefresh = false}) =>
      forceRefresh ? _repository.refreshPolicy() : _repository.getPolicy();
}
