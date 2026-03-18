/// A [Policy] binds a [Role] to a set of [Permission]s.
///
/// Policies are the top-level unit fetched from the remote source.
/// They map directly to an OPA-like policy bundle.
library;

import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';

class Policy {
  const Policy({
    required this.id,
    required this.version,
    required this.rolePermissions,
    this.defaultEffect = PermissionEffect.deny,
    this.expiresAt,
  });

  /// Unique policy bundle identifier
  final String id;

  /// Semver string or timestamp for cache invalidation
  final String version;

  /// Maps role IDs → list of permissions
  final Map<String, List<Permission>> rolePermissions;

  /// What happens when no rule matches: deny (safe default) or allow
  final PermissionEffect defaultEffect;

  /// Optional expiry for time-bounded policies
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Returns all permissions for a given [role].
  List<Permission> permissionsFor(Role role) =>
      rolePermissions[role.id] ?? const [];

  /// Returns all roles defined in this policy.
  List<String> get definedRoleIds => rolePermissions.keys.toList();

  Policy copyWith({
    String? id,
    String? version,
    Map<String, List<Permission>>? rolePermissions,
    PermissionEffect? defaultEffect,
    DateTime? expiresAt,
  }) =>
      Policy(
        id: id ?? this.id,
        version: version ?? this.version,
        rolePermissions: rolePermissions ?? this.rolePermissions,
        defaultEffect: defaultEffect ?? this.defaultEffect,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Policy && other.id == id && other.version == version;

  @override
  int get hashCode => Object.hash(id, version);

  @override
  String toString() => 'Policy(id: $id, version: $version)';
}
