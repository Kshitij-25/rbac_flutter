/// Use case: switch the active user roles (dev tools / role-switcher).
library;

import 'package:dartz/dartz.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';
import 'package:rbac_ui_engine/src/domain/interfaces/role_provider.dart';

class UpdateRole {
  const UpdateRole(this._roleProvider);
  final RoleProvider _roleProvider;

  Future<Either<RbacFailure, Unit>> call(List<Role> roles) =>
      _roleProvider.setRoles(roles);
}
