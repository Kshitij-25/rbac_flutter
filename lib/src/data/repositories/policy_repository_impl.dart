/// Concrete [PolicyRepository] wiring together cache + remote source.
///
/// Strategy:
///   getPolicy()    → cache-first, fallback remote, update cache
///   refreshPolicy() → remote-first, update cache
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rbac_ui_engine/src/data/sources/local/policy_cache_source.dart';
import 'package:rbac_ui_engine/src/data/sources/remote/policy_remote_source.dart';
import 'package:rbac_ui_engine/src/domain/entities/policy.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/policy_repository.dart';

class PolicyRepositoryImpl implements PolicyRepository {
  PolicyRepositoryImpl({
    required this.remoteSource,
    required this.cacheSource,
    required this.cacheKey,
  });

  final PolicyRemoteSource remoteSource;
  final PolicyCacheSource cacheSource;
  final String cacheKey;

  final _policyController = StreamController<Policy>.broadcast();

  @override
  Stream<Policy> get policyChanges => _policyController.stream;

  @override
  Future<Either<RbacFailure, Policy>> getPolicy() async {
    // 1. Try cache
    final cached = await cacheSource.getCachedPolicy(cacheKey);
    return cached.fold(
      (failure) => _fetchAndCacheRemote(), // cache error → try remote
      (model) async {
        if (model != null) {
          final domain = model.toDomain();
          // If policy is expired, refresh silently
          if (domain.isExpired) return _fetchAndCacheRemote();
          return Right(domain);
        }
        return _fetchAndCacheRemote();
      },
    );
  }

  @override
  Future<Either<RbacFailure, Policy>> refreshPolicy() => _fetchAndCacheRemote();

  @override
  Future<Either<RbacFailure, Unit>> clearCache() =>
      cacheSource.clearCache(cacheKey);

  Future<Either<RbacFailure, Policy>> _fetchAndCacheRemote() async {
    final result = await remoteSource.fetchPolicy();
    return result.fold(
      Left.new,
      (model) async {
        await cacheSource.cachePolicy(cacheKey, model);
        final domain = model.toDomain();
        _policyController.add(domain);
        return Right(domain);
      },
    );
  }

  void dispose() => _policyController.close();
}
