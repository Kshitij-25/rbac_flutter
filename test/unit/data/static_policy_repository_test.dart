/// Tests for [StaticPolicyRepository].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/src/data/repositories/static_policy_repository.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';

void main() {
  final basePolicy = const Policy(
    id: 'base',
    version: '1.0',
    rolePermissions: {
      'admin': [Permission(action: 'read', resource: 'dashboard')],
    },
  );

  final updatedPolicy = const Policy(
    id: 'base',
    version: '2.0',
    rolePermissions: {
      'admin': [Permission(action: '*', resource: '*')],
    },
  );

  group('StaticPolicyRepository', () {
    group('getPolicy', () {
      test('returns the current in-memory policy', () async {
        final repo = StaticPolicyRepository(basePolicy);
        final result = await repo.getPolicy();
        expect(result.isRight(), isTrue);
        result.fold((_) => fail('Expected Right'), (p) {
          expect(p.id, equals('base'));
          expect(p.version, equals('1.0'));
        });
      });
    });

    group('refreshPolicy', () {
      test('returns the same policy (static source has no remote)', () async {
        final repo = StaticPolicyRepository(basePolicy);
        final result = await repo.refreshPolicy();
        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Expected Right'),
          (p) => expect(p.version, equals('1.0')),
        );
      });
    });

    group('clearCache', () {
      test('returns Right(unit) — no-op for static source', () async {
        final repo = StaticPolicyRepository(basePolicy);
        final result = await repo.clearCache();
        expect(result.isRight(), isTrue);
      });
    });

    group('updatePolicy', () {
      test('replaces current policy and getPolicy returns new version',
          () async {
        final repo = StaticPolicyRepository(basePolicy);
        repo.updatePolicy(updatedPolicy);

        final result = await repo.getPolicy();
        result.fold(
          (_) => fail('Expected Right'),
          (p) => expect(p.version, equals('2.0')),
        );
      });
    });

    group('policyChanges stream', () {
      test('emits updated policy after updatePolicy call', () async {
        final repo = StaticPolicyRepository(basePolicy);
        final emitted = <Policy>[];

        final sub = repo.policyChanges.listen(emitted.add);

        repo.updatePolicy(updatedPolicy);
        await Future<void>.delayed(Duration.zero);

        expect(emitted.length, equals(1));
        expect(emitted.first.version, equals('2.0'));

        await sub.cancel();
        repo.dispose();
      });

      test('emits multiple updates in order', () async {
        final repo = StaticPolicyRepository(basePolicy);
        final versions = <String>[];

        final sub = repo.policyChanges.listen((p) => versions.add(p.version));

        final v2 = basePolicy.copyWith(version: '2.0');
        final v3 = basePolicy.copyWith(version: '3.0');
        repo.updatePolicy(v2);
        repo.updatePolicy(v3);
        await Future<void>.delayed(Duration.zero);

        expect(versions, equals(['2.0', '3.0']));

        await sub.cancel();
        repo.dispose();
      });

      test('no events emitted before updatePolicy is called', () async {
        final repo = StaticPolicyRepository(basePolicy);
        final emitted = <Policy>[];
        final sub = repo.policyChanges.listen(emitted.add);
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isEmpty);

        await sub.cancel();
        repo.dispose();
      });
    });
  });
}
