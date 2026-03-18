/// Unit tests for [RbacNotifier] state transitions.
///
/// Key pattern: [Notifier] subclasses must run inside a [ProviderContainer].
/// Accessing [state] or calling methods on a bare [RbacNotifier()] instance
/// will throw because [Notifier.state] is wired by the Riverpod framework.
///
/// Correct pattern:
///   final container = ProviderContainer(overrides: [...]);
///   addTearDown(container.dispose);
///   await container.read(rbacNotifierProvider.notifier).initialize();
///   expect(container.read(rbacNotifierProvider), isA<RbacReady>());
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_flutter/src/domain/interfaces/policy_repository.dart';
import 'package:rbac_flutter/src/domain/interfaces/role_provider.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPolicyRepository extends Mock implements PolicyRepository {}

class MockRoleProvider extends Mock implements RoleProvider {}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

final _testPolicy = const Policy(
  id: 'p1',
  version: '1.0',
  rolePermissions: {
    'admin': [Permission(action: 'read', resource: 'dashboard')],
  },
);
const _adminRole = Role(id: 'admin', name: 'Admin');
const _viewerRole = Role(id: 'viewer', name: 'Viewer');

// ---------------------------------------------------------------------------
// Helper — builds a ProviderContainer with mocked infrastructure providers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({
  required MockPolicyRepository policyRepo,
  required MockRoleProvider roleProvider,
}) {
  return ProviderContainer(
    overrides: [
      policyRepositoryProvider.overrideWithValue(policyRepo),
      roleProviderProvider.overrideWithValue(roleProvider),
    ],
  );
}

// Stubs policyChanges + roleChanges streams on both mocks to avoid hanging.
void _stubIdleStreams(
  MockPolicyRepository policyRepo,
  MockRoleProvider roleProvider,
) {
  when(() => policyRepo.policyChanges).thenAnswer((_) => const Stream.empty());
  when(() => roleProvider.roleChanges).thenAnswer((_) => const Stream.empty());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPolicyRepository mockPolicyRepo;
  late MockRoleProvider mockRoleProvider;

  setUp(() {
    mockPolicyRepo = MockPolicyRepository();
    mockRoleProvider = MockRoleProvider();
    _stubIdleStreams(mockPolicyRepo, mockRoleProvider);
  });

  // -------------------------------------------------------------------------
  group('initialize()', () {
    test('transitions Initial → Loading → Ready on success', () async {
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([_adminRole]));

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      // Before initialize: Initial
      expect(container.read(rbacNotifierProvider), isA<RbacInitial>());

      await container.read(rbacNotifierProvider.notifier).initialize();

      final state = container.read(rbacNotifierProvider);
      expect(state, isA<RbacReady>());

      final ready = state as RbacReady;
      expect(ready.policy.id, equals('p1'));
      expect(ready.roles, contains(_adminRole));
    });

    test('transitions to RbacError when policy fetch fails', () async {
      when(() => mockPolicyRepo.getPolicy()).thenAnswer(
        (_) async => const Left(PolicyFetchFailure('Timeout', statusCode: 0)),
      );

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      await container.read(rbacNotifierProvider.notifier).initialize();

      final state = container.read(rbacNotifierProvider);
      expect(state, isA<RbacError>());
      expect((state as RbacError).failure, isA<PolicyFetchFailure>());
    });

    test('transitions to RbacError when role provider fails', () async {
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles()).thenAnswer(
        (_) async => const Left(RoleProviderFailure('No auth')),
      );

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      await container.read(rbacNotifierProvider.notifier).initialize();

      expect(container.read(rbacNotifierProvider), isA<RbacError>());
    });

    test('does not call role provider when policy fails', () async {
      when(() => mockPolicyRepo.getPolicy()).thenAnswer(
        (_) async => const Left(PolicyFetchFailure('Error')),
      );

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      await container.read(rbacNotifierProvider.notifier).initialize();

      verifyNever(() => mockRoleProvider.getCurrentRoles());
    });
  });

  // -------------------------------------------------------------------------
  group('setRoles()', () {
    test('updates roles in Ready state and notifies listeners', () async {
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([_adminRole]));
      when(() => mockRoleProvider.setRoles(any()))
          .thenAnswer((_) async => const Right(unit));

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      await container.read(rbacNotifierProvider.notifier).initialize();
      await container
          .read(rbacNotifierProvider.notifier)
          .setRoles([_viewerRole]);

      final state = container.read(rbacNotifierProvider) as RbacReady;
      expect(state.roles, contains(_viewerRole));
      expect(state.roles, isNot(contains(_adminRole)));
      // Policy unchanged
      expect(state.policy.id, equals('p1'));
    });

    test('sets RbacError when role provider setRoles fails', () async {
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([_adminRole]));
      when(() => mockRoleProvider.setRoles(any())).thenAnswer(
        (_) async => const Left(RoleProviderFailure('Write error')),
      );

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      await container.read(rbacNotifierProvider.notifier).initialize();
      await container
          .read(rbacNotifierProvider.notifier)
          .setRoles([_viewerRole]);

      expect(container.read(rbacNotifierProvider), isA<RbacError>());
    });
  });

  // -------------------------------------------------------------------------
  group('refresh()', () {
    test('updates policy version while keeping roles', () async {
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([_adminRole]));

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      await container.read(rbacNotifierProvider.notifier).initialize();

      final newPolicy = _testPolicy.copyWith(version: '2.0');
      when(() => mockPolicyRepo.refreshPolicy())
          .thenAnswer((_) async => Right(newPolicy));

      await container.read(rbacNotifierProvider.notifier).refresh();

      final state = container.read(rbacNotifierProvider) as RbacReady;
      expect(state.policy.version, equals('2.0'));
      expect(state.roles, contains(_adminRole));
    });

    test('sets RbacError when refresh fetch fails', () async {
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([_adminRole]));
      when(() => mockPolicyRepo.refreshPolicy()).thenAnswer(
        (_) async => const Left(PolicyFetchFailure('Network down')),
      );

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(container.dispose);

      await container.read(rbacNotifierProvider.notifier).initialize();
      await container.read(rbacNotifierProvider.notifier).refresh();

      expect(container.read(rbacNotifierProvider), isA<RbacError>());
    });
  });

  // -------------------------------------------------------------------------
  group('Stream reactivity', () {
    test('policy stream change updates policy in Ready state', () async {
      final policyController = StreamController<Policy>.broadcast();

      when(() => mockPolicyRepo.policyChanges)
          .thenAnswer((_) => policyController.stream);
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([_adminRole]));

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(() async {
        container.dispose();
        await policyController.close();
      });

      await container.read(rbacNotifierProvider.notifier).initialize();

      // Simulate server push
      final pushedPolicy = _testPolicy.copyWith(version: '99.0');
      policyController.add(pushedPolicy);
      // Let microtask queue flush
      await Future<void>.delayed(Duration.zero);

      final state = container.read(rbacNotifierProvider) as RbacReady;
      expect(state.policy.version, equals('99.0'));
    });

    test('role stream change updates roles in Ready state', () async {
      final roleController = StreamController<List<Role>>.broadcast();

      when(() => mockRoleProvider.roleChanges)
          .thenAnswer((_) => roleController.stream);
      when(() => mockPolicyRepo.getPolicy())
          .thenAnswer((_) async => Right(_testPolicy));
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([_adminRole]));

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(() async {
        container.dispose();
        await roleController.close();
      });

      await container.read(rbacNotifierProvider.notifier).initialize();

      roleController.add([_viewerRole]);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(rbacNotifierProvider) as RbacReady;
      expect(state.roles, contains(_viewerRole));
      expect(state.roles, isNot(contains(_adminRole)));
    });

    test('stream events are ignored when not in Ready state', () async {
      final policyController = StreamController<Policy>.broadcast();
      when(() => mockPolicyRepo.policyChanges)
          .thenAnswer((_) => policyController.stream);

      final container = _makeContainer(
        policyRepo: mockPolicyRepo,
        roleProvider: mockRoleProvider,
      );
      addTearDown(() async {
        container.dispose();
        await policyController.close();
      });

      // State is still Initial — stream event should be ignored
      policyController.add(_testPolicy);
      await Future<void>.delayed(Duration.zero);

      // Should remain Initial, not crash or change state
      expect(container.read(rbacNotifierProvider), isA<RbacInitial>());
    });
  });
}
