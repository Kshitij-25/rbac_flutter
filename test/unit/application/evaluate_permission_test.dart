import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rbac_ui_engine/src/application/usecases/evaluate_permission.dart';
import 'package:rbac_ui_engine/src/domain/entities/permission.dart';
import 'package:rbac_ui_engine/src/domain/entities/policy.dart';
import 'package:rbac_ui_engine/src/domain/entities/resource.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/permission_evaluator.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/policy_repository.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/role_provider.dart';

class MockPolicyRepository extends Mock implements PolicyRepository {}
class MockRoleProvider extends Mock implements RoleProvider {}
class MockPermissionEvaluator extends Mock implements PermissionEvaluator {}

void main() {
  late MockPolicyRepository mockRepo;
  late MockRoleProvider mockRoleProvider;
  late MockPermissionEvaluator mockEvaluator;
  late EvaluatePermission useCase;

  const adminRole = Role(id: 'admin', name: 'Admin');
  final dashboardResource = const Resource(id: 'dashboard');
  final testPolicy = Policy(
    id: 'p1', version: '1.0',
    rolePermissions: {'admin': [const Permission(action: 'read', resource: 'dashboard')]},
  );

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

  group('EvaluatePermission', () {
    test('returns AllowedResult when evaluator returns allow', () async {
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => Right([adminRole]));
      when(() => mockRepo.getPolicy())
          .thenAnswer((_) async => Right(testPolicy));
      when(() => mockEvaluator.evaluate(
            policy: any(named: 'policy'),
            role: any(named: 'role'),
            action: any(named: 'action'),
            resource: any(named: 'resource'),
            context: any(named: 'context'),
          )).thenReturn(PermissionEffect.allow);

      final result = await useCase(action: 'read', resource: dashboardResource);
      expect(result, isA<AllowedResult>());
    });

    test('returns DeniedResult when evaluator returns deny', () async {
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => Right([adminRole]));
      when(() => mockRepo.getPolicy())
          .thenAnswer((_) async => Right(testPolicy));
      when(() => mockEvaluator.evaluate(
            policy: any(named: 'policy'),
            role: any(named: 'role'),
            action: any(named: 'action'),
            resource: any(named: 'resource'),
            context: any(named: 'context'),
          )).thenReturn(PermissionEffect.deny);

      final result = await useCase(action: 'delete', resource: dashboardResource);
      expect(result, isA<DeniedResult>());
    });

    test('returns AllowedResult if ANY role grants access (multi-role)', () async {
      const guestRole = Role(id: 'guest', name: 'Guest');
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => Right([guestRole, adminRole]));
      when(() => mockRepo.getPolicy())
          .thenAnswer((_) async => Right(testPolicy));
      when(() => mockEvaluator.evaluate(
            policy: any(named: 'policy'),
            role: guestRole,
            action: any(named: 'action'),
            resource: any(named: 'resource'),
            context: any(named: 'context'),
          )).thenReturn(PermissionEffect.deny);
      when(() => mockEvaluator.evaluate(
            policy: any(named: 'policy'),
            role: adminRole,
            action: any(named: 'action'),
            resource: any(named: 'resource'),
            context: any(named: 'context'),
          )).thenReturn(PermissionEffect.allow);

      final result = await useCase(action: 'read', resource: dashboardResource);
      expect(result, isA<AllowedResult>());
    });

    test('returns ErrorResult when role provider fails', () async {
      when(() => mockRoleProvider.getCurrentRoles()).thenAnswer(
        (_) async => const Left(RoleProviderFailure('Auth error')),
      );

      final result = await useCase(action: 'read', resource: dashboardResource);
      expect(result, isA<ErrorResult>());
      expect((result as ErrorResult).failure, isA<RoleProviderFailure>());
    });

    test('returns ErrorResult when policy fetch fails', () async {
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => Right([adminRole]));
      when(() => mockRepo.getPolicy()).thenAnswer(
        (_) async => const Left(PolicyFetchFailure('Network error')),
      );

      final result = await useCase(action: 'read', resource: dashboardResource);
      expect(result, isA<ErrorResult>());
    });

    test('returns DeniedResult when user has no roles', () async {
      when(() => mockRoleProvider.getCurrentRoles())
          .thenAnswer((_) async => const Right([]));
      when(() => mockRepo.getPolicy())
          .thenAnswer((_) async => Right(testPolicy));

      final result = await useCase(action: 'read', resource: dashboardResource);
      expect(result, isA<DeniedResult>());
    });
  });
}
