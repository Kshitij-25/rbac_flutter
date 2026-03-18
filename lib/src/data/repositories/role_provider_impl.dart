/// In-memory [RoleProvider] implementation.
///
/// In production this would delegate to Firebase Auth, JWT parsing,
/// etc. For now it's a reactive in-memory store — ideal for testing
/// and the example app's role-switcher.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/role_provider.dart';

class InMemoryRoleProvider implements RoleProvider {
  InMemoryRoleProvider({List<Role> initialRoles = const []})
      : _roles = List.of(initialRoles);

  List<Role> _roles;
  final _controller = StreamController<List<Role>>.broadcast();

  @override
  Stream<List<Role>> get roleChanges => _controller.stream;

  @override
  Future<Either<RbacFailure, List<Role>>> getCurrentRoles() async =>
      Right(List.unmodifiable(_roles));

  @override
  Future<Either<RbacFailure, Unit>> setRoles(List<Role> roles) async {
    _roles = List.of(roles);
    _controller.add(List.unmodifiable(_roles));
    return const Right(unit);
  }

  void dispose() => _controller.close();
}
