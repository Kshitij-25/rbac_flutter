/// Unit tests for [EvaluatePermission] use case.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rbac_flutter/src/application/usecases/evaluate_permission.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/resource.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_flutter/src/domain/interfaces/permission_evaluator.dart';
import 'package:rbac_flutter/src/domain/interfaces/policy_repository.dart';
import 'package:rbac_flutter/src/domain/interfaces/role_provider.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPolicyRepository extends Mock implements PolicyRepository {}

class MockRoleProvider extends Mock implements RoleProvider {}

class MockPermissionEvaluator extends Mock implements PermissionEvaluator {}

// ---------------------------------------------------------------------------
// Fakes — required by mocktail when any() is used on custom types
// ---------------------------------------------------------------------------

class FakePolicy extends Fake implements Policy {}

class FakeResource extends Fake implements Resource {}

class FakeRole extends Fake implements Role {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _adminRole = Role(id: 'admin', name: 'Admin');
const _guestRole = Role(id: 'guest', name: 'Guest');
const _dashboard = Resource(id: 'dashboard');

final _testPolicy = const Policy(
  id: 'p1',
  version: '1.0',
  rolePermissions: {
    'admin': [Permission(action: 'read', resource: 'dashboard')],
  },
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPolicyRepository mockRepo;
  late MockRoleProvider mockRoleProvider;
  late MockPermissionEvaluator mockEvaluator;
  late EvaluatePermission useCase;

  // Register fallbacks for every custom type used with any() / captureAny()
  setUpAll(() {
    registerFallbackValue(FakePolicy());
    registerFallbackValue(FakeResource());
    registerFallbackValue(FakeRole());
  });

  setUp(() {
    mockRepo = MockPolicyRepository();
    mockRoleProvider = MockRoleProvider();
    mockEvaluator = MockPermissionEvaluator();
    useCase = EvaluatePermission(
      policyRepository: mockRepo,
      roleProvider: mockRoleProvider,
      evaluator: mockEvaluator,
    );
  });

  // Stub evaluator for a given role → effect.
  void stubEvaluator(Role role, PermissionEffect effect) {
    when(
      () => mockEvaluator.evaluate(
        policy: any(named: 'policy'),
        role: role,
        action: any(named: 'action'),
        resource: any(named: 'resource'),
        context: any(named: 'context'),
      ),
    ).thenReturn(effect);
  }

  // Convenience: set up the happy-path stubs so error tests can selectively
  // override only the piece they care about without leaving others null.
  void stubHappyPath() {
    when(() => mockRoleProvider.getCurrentRoles())
        .thenAnswer((_) async => const Right([_adminRole]));
    when(() => mockRepo.getPolicy())
        .thenAnswer((_) async => Right(_testPolicy));
  }

  group('EvaluatePermission', () {
    // ── Happy path ────────────────────────────────────────────────────────
    group('Happy path', () {
      test('returns AllowedResult when evaluator grants access', () async {
        stubHappyPath();
        stubEvaluator(_adminRole, PermissionEffect.allow);

        final result = await useCase(action: 'read', resource: _dashboard);

        expect(result, isA<AllowedResult>());
      });

      test('returns DeniedResult when evaluator denies access', () async {
        stubHappyPath();
        stubEvaluator(_adminRole, PermissionEffect.deny);

        final result = await useCase(action: 'delete', resource: _dashboard);

        expect(result, isA<DeniedResult>());
        expect((result as DeniedResult).reason, isNotNull);
      });
    });

    // ── Multi-role ANY semantics ──────────────────────────────────────────
    group('Multi-role ANY semantics', () {
      test('returns Allowed if any role is permitted', () async {
        when(() => mockRoleProvider.getCurrentRoles())
            .thenAnswer((_) async => const Right([_guestRole, _adminRole]));
        when(() => mockRepo.getPolicy())
            .thenAnswer((_) async => Right(_testPolicy));
        stubEvaluator(_guestRole, PermissionEffect.deny);
        stubEvaluator(_adminRole, PermissionEffect.allow);

        final result = await useCase(action: 'read', resource: _dashboard);

        expect(result, isA<AllowedResult>());
      });

      test('returns Denied if ALL roles deny', () async {
        when(() => mockRoleProvider.getCurrentRoles())
            .thenAnswer((_) async => const Right([_guestRole, _adminRole]));
        when(() => mockRepo.getPolicy())
            .thenAnswer((_) async => Right(_testPolicy));
        stubEvaluator(_guestRole, PermissionEffect.deny);
        stubEvaluator(_adminRole, PermissionEffect.deny);

        final result = await useCase(action: 'read', resource: _dashboard);

        expect(result, isA<DeniedResult>());
      });

      test('returns Denied when user has no roles', () async {
        when(() => mockRoleProvider.getCurrentRoles())
            .thenAnswer((_) async => const Right([]));
        when(() => mockRepo.getPolicy())
            .thenAnswer((_) async => Right(_testPolicy));

        final result = await useCase(action: 'read', resource: _dashboard);

        expect(result, isA<DeniedResult>());
        verifyNever(
          () => mockEvaluator.evaluate(
            policy: any(named: 'policy'),
            role: any(named: 'role'),
            action: any(named: 'action'),
            resource: any(named: 'resource'),
            context: any(named: 'context'),
          ),
        );
      });
    });

    // ── Error paths ───────────────────────────────────────────────────────
    group('Error paths', () {
      test('returns ErrorResult when role provider fails', () async {
        // Only override getCurrentRoles — leave getPolicy un-stubbed since
        // the use case short-circuits before calling it.
        when(() => mockRoleProvider.getCurrentRoles()).thenAnswer(
          (_) async => const Left(RoleProviderFailure('Auth token expired')),
        );

        final result = await useCase(action: 'read', resource: _dashboard);

        expect(result, isA<ErrorResult>());
        expect((result as ErrorResult).failure, isA<RoleProviderFailure>());
        verifyNever(() => mockRepo.getPolicy());
      });

      test('returns ErrorResult when policy repo fails', () async {
        // Roles succeed, policy fails.
        when(() => mockRoleProvider.getCurrentRoles())
            .thenAnswer((_) async => const Right([_adminRole]));
        when(() => mockRepo.getPolicy()).thenAnswer(
          (_) async => const Left(PolicyFetchFailure('Remote unavailable')),
        );

        final result = await useCase(action: 'read', resource: _dashboard);

        expect(result, isA<ErrorResult>());
        expect((result as ErrorResult).failure, isA<PolicyFetchFailure>());
      });
    });

    // ── ABAC context passthrough ──────────────────────────────────────────
    group('ABAC context passthrough', () {
      test('passes context map to evaluator', () async {
        const context = {'clearance': 'top-secret'};
        when(() => mockRoleProvider.getCurrentRoles())
            .thenAnswer((_) async => const Right([_adminRole]));
        when(() => mockRepo.getPolicy())
            .thenAnswer((_) async => Right(_testPolicy));
        when(
          () => mockEvaluator.evaluate(
            policy: any(named: 'policy'),
            role: _adminRole,
            action: 'read',
            resource: _dashboard,
            context: context,
          ),
        ).thenReturn(PermissionEffect.allow);

        final result = await useCase(
          action: 'read',
          resource: _dashboard,
          context: context,
        );

        expect(result, isA<AllowedResult>());
        verify(
          () => mockEvaluator.evaluate(
            policy: any(named: 'policy'),
            role: _adminRole,
            action: 'read',
            resource: _dashboard,
            context: context,
          ),
        ).called(1);
      });
    });
  });
}
