/// Contract for the current-user's role source.
///
/// In a real app this bridges to Firebase Auth, a JWT decoder,
/// or a custom auth provider. Keeping it abstract means the domain
/// stays completely decoupled from the auth system.
library;

import 'package:dartz/dartz.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';

abstract interface class RoleProvider {
  /// Returns the currently active roles for the authenticated user.
  /// A user can hold multiple roles simultaneously.
  Future<Either<RbacFailure, List<Role>>> getCurrentRoles();

  /// Stream of role changes — widgets observe this to reactively rebuild.
  Stream<List<Role>> get roleChanges;

  /// Replaces the current roles (useful in tests / role-switcher).
  Future<Either<RbacFailure, Unit>> setRoles(List<Role> roles);
}
