// test/domain/interfaces_test.dart
//
// TASK 1.2 — TDD: Interface contract tests.
// Uses fake/stub implementations to verify interface contracts are correct.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/rbac_ui_engine.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────

class FakePolicyRepository implements PolicyRepository {
  final Map<String, Policy> _store;

  FakePolicyRepository(this._store);

  @override
  Future<Either<PolicyFailure, Policy>> getPolicyForRole(String roleId) async {
    final policy = _store[roleId];
    if (policy == null) {
      return Left(PolicyFailure.notFound('No policy for role: $roleId'));
    }
    return Right(policy);
  }

  @override
  Future<Either<PolicyFailure, void>> cachePolicy(
    String roleId,
    Policy policy,
  ) async {
    _store[roleId] = policy;
    return const Right(null);
  }

  @override
  Future<Either<PolicyFailure, void>> invalidateCache(String roleId) async {
    _store.remove(roleId);
    return const Right(null);
  }
}

class FakePermissionEvaluator implements PermissionEvaluator {
  final bool _defaultResult;

  FakePermissionEvaluator({bool defaultResult = true})
      : _defaultResult = defaultResult;

  @override
  bool evaluate({
    required List<Policy> policies,
    required String resource,
    required ActionType action,
    Map<String, dynamic> context = const {},
  }) {
    return _defaultResult;
  }
}

class FakeRoleProvider implements RoleProvider {
  Role? _currentRole;

  FakeRoleProvider(this._currentRole);

  @override
  Role? get currentRole => _currentRole;

  @override
  Stream<Role?> get roleStream => Stream.value(_currentRole);

  @override
  Future<void> setRole(Role role) async => _currentRole = role;

  @override
  Future<void> clearRole() async => _currentRole = null;
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('PolicyRepository contract', () {
    late FakePolicyRepository repo;
    late Policy testPolicy;

    setUp(() {
      testPolicy = Policy(
        id: 'admin_policy',
        version: '1',
        statements: [
          const Permission(
            resource: '*',
            action: ActionType.read,
            effect: Effect.allow,
          ),
        ],
      );
      repo = FakePolicyRepository({'admin': testPolicy});
    });

    test('getPolicyForRole returns Right(Policy) when found', () async {
      final result = await repo.getPolicyForRole('admin');
      expect(result.isRight(), isTrue);
      result.fold(
        (l) => fail('Expected Right'),
        (r) => expect(r, equals(testPolicy)),
      );
    });

    test('getPolicyForRole returns Left(PolicyFailure) when not found',
        () async {
      final result = await repo.getPolicyForRole('unknown_role');
      expect(result.isLeft(), isTrue);
    });

    test('cachePolicy stores policy retrievable by roleId', () async {
      const newPolicy =
          Policy(id: 'viewer_policy', version: '1', statements: []);
      await repo.cachePolicy('viewer', newPolicy);
      final result = await repo.getPolicyForRole('viewer');
      expect(result.isRight(), isTrue);
    });

    test('invalidateCache removes policy from store', () async {
      await repo.invalidateCache('admin');
      final result = await repo.getPolicyForRole('admin');
      expect(result.isLeft(), isTrue);
    });
  });

  group('PermissionEvaluator contract', () {
    test('evaluate returns true when allowed', () {
      final evaluator = FakePermissionEvaluator();
      final result = evaluator.evaluate(
        policies: [],
        resource: 'dashboard',
        action: ActionType.read,
      );
      expect(result, isTrue);
    });

    test('evaluate returns false when denied', () {
      final evaluator = FakePermissionEvaluator(defaultResult: false);
      final result = evaluator.evaluate(
        policies: [],
        resource: 'admin_panel',
        action: ActionType.delete,
      );
      expect(result, isFalse);
    });
  });

  group('RoleProvider contract', () {
    test('currentRole returns the set role', () {
      const role = Role(id: 'viewer', name: 'Viewer');
      final provider = FakeRoleProvider(role);
      expect(provider.currentRole, equals(role));
    });

    test('setRole updates currentRole', () async {
      final provider = FakeRoleProvider(null);
      const admin = Role(id: 'admin', name: 'Admin');
      await provider.setRole(admin);
      expect(provider.currentRole, equals(admin));
    });

    test('clearRole sets currentRole to null', () async {
      const role = Role(id: 'viewer', name: 'Viewer');
      final provider = FakeRoleProvider(role);
      await provider.clearRole();
      expect(provider.currentRole, isNull);
    });

    test('roleStream emits current role', () async {
      const role = Role(id: 'editor', name: 'Editor');
      final provider = FakeRoleProvider(role);
      await expectLater(provider.roleStream, emits(role));
    });
  });

  group('PolicyFailure', () {
    test('notFound factory provides meaningful message', () {
      final failure = PolicyFailure.notFound('No policy for role: viewer');
      expect(failure.message, contains('viewer'));
      expect(failure.type, PolicyFailureType.notFound);
    });

    test('networkError factory wraps network failures', () {
      final failure = PolicyFailure.networkError('Timeout');
      expect(failure.type, PolicyFailureType.networkError);
    });

    test('cacheError factory wraps cache failures', () {
      final failure = PolicyFailure.cacheError('Disk full');
      expect(failure.type, PolicyFailureType.cacheError);
    });
  });
}
