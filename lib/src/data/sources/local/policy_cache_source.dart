/// SharedPreferences-backed local cache for policy bundles.
///
/// The cache key is namespaced to avoid collisions in apps with
/// multiple policy endpoints.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:rbac_ui_engine/src/data/models/policy_model.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PolicyCacheSource {
  Future<Either<RbacFailure, PolicyModel?>> getCachedPolicy(String key);
  Future<Either<RbacFailure, Unit>> cachePolicy(
    String key,
    PolicyModel model,
  );
  Future<Either<RbacFailure, Unit>> clearCache(String key);
  Future<Either<RbacFailure, Unit>> clearAll();
}

class SharedPrefsPolicyCacheSource implements PolicyCacheSource {
  SharedPrefsPolicyCacheSource({
    required this.preferences,
    this.keyPrefix = 'rbac_policy_',
  });

  final SharedPreferences preferences;
  final String keyPrefix;

  String _buildKey(String raw) {
    // Hash the raw key so URL characters don't break prefs keys
    final bytes = utf8.encode('$keyPrefix$raw');
    final hash = sha256.convert(bytes);
    return '$keyPrefix${hash.toString().substring(0, 16)}';
  }

  @override
  Future<Either<RbacFailure, PolicyModel?>> getCachedPolicy(
    String key,
  ) async {
    try {
      final stored = preferences.getString(_buildKey(key));
      if (stored == null) return const Right(null);

      final json = jsonDecode(stored) as Map<String, dynamic>;
      return Right(PolicyModel.fromJson(json));
    } catch (e) {
      return Left(CacheFailure('Failed to read cached policy: $e'));
    }
  }

  @override
  Future<Either<RbacFailure, Unit>> cachePolicy(
    String key,
    PolicyModel model,
  ) async {
    try {
      final json = jsonEncode(model.toJson());
      await preferences.setString(_buildKey(key), json);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Failed to write policy to cache: $e'));
    }
  }

  @override
  Future<Either<RbacFailure, Unit>> clearCache(String key) async {
    try {
      await preferences.remove(_buildKey(key));
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Failed to clear cache key: $e'));
    }
  }

  @override
  Future<Either<RbacFailure, Unit>> clearAll() async {
    try {
      final keys = preferences.getKeys();
      for (final k in keys.where((k) => k.startsWith(keyPrefix))) {
        await preferences.remove(k);
      }
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Failed to clear all cache: $e'));
    }
  }
}
