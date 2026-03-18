/// A [PolicyRepository] backed by an in-memory [Policy].
/// Useful for tests, demos, and apps that hard-code a policy.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rbac_ui_engine/src/domain/entities/policy.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/policy_repository.dart';

class StaticPolicyRepository implements PolicyRepository {
  StaticPolicyRepository(this._policy);

  Policy _policy;
  final _controller = StreamController<Policy>.broadcast();

  void updatePolicy(Policy policy) {
    _policy = policy;
    _controller.add(policy);
  }

  @override
  Stream<Policy> get policyChanges => _controller.stream;

  @override
  Future<Either<RbacFailure, Policy>> getPolicy() async => Right(_policy);

  @override
  Future<Either<RbacFailure, Policy>> refreshPolicy() async => Right(_policy);

  @override
  Future<Either<RbacFailure, Unit>> clearCache() async => const Right(unit);

  void dispose() => _controller.close();
}
