/// Tests for [PolicyRepositoryImpl] cache-first strategy.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rbac_flutter/src/data/models/permission_model.dart';
import 'package:rbac_flutter/src/data/models/policy_model.dart';
import 'package:rbac_flutter/src/data/repositories/policy_repository_impl.dart';
import 'package:rbac_flutter/src/data/sources/local/policy_cache_source.dart';
import 'package:rbac_flutter/src/data/sources/remote/policy_remote_source.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockRemoteSource extends Mock implements PolicyRemoteSource {}

class MockCacheSource extends Mock implements PolicyCacheSource {}

// ---------------------------------------------------------------------------
// Fakes — required when any() is used on custom types
// ---------------------------------------------------------------------------

class FakePolicyModel extends Fake implements PolicyModel {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const cachedModel = PolicyModel(
  id: 'cached-pol',
  version: '1.0',
  rolePermissions: {
    'admin': [PermissionModel(action: 'read', resource: 'x')],
  },
);

const remoteModel = PolicyModel(
  id: 'remote-pol',
  version: '2.0',
  rolePermissions: {},
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockRemoteSource mockRemote;
  late MockCacheSource mockCache;
  late PolicyRepositoryImpl repo;

  setUpAll(() {
    // Required because cachePolicy(any(), any()) uses any() on PolicyModel
    registerFallbackValue(FakePolicyModel());
  });

  setUp(() {
    mockRemote = MockRemoteSource();
    mockCache = MockCacheSource();
    repo = PolicyRepositoryImpl(
      remoteSource: mockRemote,
      cacheSource: mockCache,
      cacheKey: 'test-key',
    );
  });

  tearDown(() => repo.dispose());

  // Helper: stub a fresh remote-fetch + cache-write sequence.
  void stubRemoteFetch({PolicyModel model = remoteModel}) {
    when(() => mockRemote.fetchPolicy()).thenAnswer((_) async => Right(model));
    when(() => mockCache.cachePolicy(any(), any()))
        .thenAnswer((_) async => const Right(unit));
  }

  group('getPolicy — cache-first strategy', () {
    test('returns cached policy when cache has valid data', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(cachedModel));

      final result = await repo.getPolicy();
      expect(result.isRight(), isTrue);
      result.fold((_) {}, (p) => expect(p.id, equals('cached-pol')));

      verifyNever(() => mockRemote.fetchPolicy());
    });

    test('falls back to remote when cache is empty', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(null));
      stubRemoteFetch();

      final result = await repo.getPolicy();
      expect(result.isRight(), isTrue);
      result.fold((_) {}, (p) => expect(p.id, equals('remote-pol')));

      verify(() => mockRemote.fetchPolicy()).called(1);
    });

    test('falls back to remote when cache read fails', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Left(CacheFailure('disk error')));
      stubRemoteFetch();

      final result = await repo.getPolicy();
      expect(result.isRight(), isTrue);
      verify(() => mockRemote.fetchPolicy()).called(1);
    });

    test('returns failure when both cache and remote fail', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => mockRemote.fetchPolicy()).thenAnswer(
        (_) async => const Left(PolicyFetchFailure('timeout')),
      );

      final result = await repo.getPolicy();
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<PolicyFetchFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('stores policy in cache after remote fetch', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(null));
      stubRemoteFetch();

      await repo.getPolicy();

      verify(() => mockCache.cachePolicy(any(), any())).called(1);
    });
  });

  group('refreshPolicy — remote-first', () {
    test('always calls remote source', () async {
      stubRemoteFetch();

      await repo.refreshPolicy();
      verify(() => mockRemote.fetchPolicy()).called(1);
    });
  });

  group('policyChanges stream', () {
    test('emits new policy after successful remote fetch', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(null));
      stubRemoteFetch();

      final emitted = <String>[];
      final sub = repo.policyChanges.listen((p) => emitted.add(p.id));

      await repo.getPolicy();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, contains('remote-pol'));
      await sub.cancel();
    });
  });
}
