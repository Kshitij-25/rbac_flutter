/// Tests for PolicyRepositoryImpl cache-first strategy.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rbac_ui_engine/src/data/models/permission_model.dart';
import 'package:rbac_ui_engine/src/data/models/policy_model.dart';
import 'package:rbac_ui_engine/src/data/repositories/policy_repository_impl.dart';
import 'package:rbac_ui_engine/src/data/sources/local/policy_cache_source.dart';
import 'package:rbac_ui_engine/src/data/sources/remote/policy_remote_source.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';

class MockRemoteSource extends Mock implements PolicyRemoteSource {}
class MockCacheSource extends Mock implements PolicyCacheSource {}

void main() {
  late MockRemoteSource mockRemote;
  late MockCacheSource mockCache;
  late PolicyRepositoryImpl repo;

  final cachedModel = PolicyModel(
    id: 'cached-pol',
    version: '1.0',
    rolePermissions: {
      'admin': [const PermissionModel(action: 'read', resource: 'x')],
    },
  );
  final remoteModel = PolicyModel(
    id: 'remote-pol',
    version: '2.0',
    rolePermissions: {},
  );

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

  group('getPolicy — cache-first strategy', () {
    test('returns cached policy when cache has valid data', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => Right(cachedModel));

      final result = await repo.getPolicy();
      expect(result.isRight(), isTrue);
      result.fold((_) {}, (p) => expect(p.id, equals('cached-pol')));

      // Remote should NOT be called
      verifyNever(() => mockRemote.fetchPolicy());
    });

    test('falls back to remote when cache is empty', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => mockRemote.fetchPolicy())
          .thenAnswer((_) async => Right(remoteModel));
      when(() => mockCache.cachePolicy(any(), any()))
          .thenAnswer((_) async => const Right(unit));

      final result = await repo.getPolicy();
      expect(result.isRight(), isTrue);
      result.fold((_) {}, (p) => expect(p.id, equals('remote-pol')));

      verify(() => mockRemote.fetchPolicy()).called(1);
    });

    test('falls back to remote when cache read fails', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Left(CacheFailure('disk error')));
      when(() => mockRemote.fetchPolicy())
          .thenAnswer((_) async => Right(remoteModel));
      when(() => mockCache.cachePolicy(any(), any()))
          .thenAnswer((_) async => const Right(unit));

      final result = await repo.getPolicy();
      expect(result.isRight(), isTrue);
      verify(() => mockRemote.fetchPolicy()).called(1);
    });

    test('returns failure when both cache and remote fail', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => mockRemote.fetchPolicy()).thenAnswer(
        (_) async => const Left(PolicyFetchFailure('timeout', statusCode: 0)),
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
      when(() => mockRemote.fetchPolicy())
          .thenAnswer((_) async => Right(remoteModel));
      when(() => mockCache.cachePolicy(any(), any()))
          .thenAnswer((_) async => const Right(unit));

      await repo.getPolicy();

      verify(() => mockCache.cachePolicy(any(), any())).called(1);
    });
  });

  group('refreshPolicy — remote-first', () {
    test('always calls remote source', () async {
      when(() => mockRemote.fetchPolicy())
          .thenAnswer((_) async => Right(remoteModel));
      when(() => mockCache.cachePolicy(any(), any()))
          .thenAnswer((_) async => const Right(unit));

      await repo.refreshPolicy();
      verify(() => mockRemote.fetchPolicy()).called(1);
    });
  });

  group('policyChanges stream', () {
    test('emits new policy after successful remote fetch', () async {
      when(() => mockCache.getCachedPolicy(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => mockRemote.fetchPolicy())
          .thenAnswer((_) async => Right(remoteModel));
      when(() => mockCache.cachePolicy(any(), any()))
          .thenAnswer((_) async => const Right(unit));

      final emitted = <String>[];
      final sub = repo.policyChanges.listen((p) => emitted.add(p.id));

      await repo.getPolicy();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, contains('remote-pol'));
      await sub.cancel();
    });
  });
}
