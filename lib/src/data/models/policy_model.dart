/// JSON-serializable DTO for [Policy].
library;

import 'package:rbac_ui_engine/rbac_ui_engine.dart';

class PolicyModel {
  const PolicyModel({
    required this.id,
    required this.version,
    required this.rolePermissions,
    this.defaultEffect = 'deny',
    this.expiresAt,
  });

  final String id;
  final String version;

  /// roleId → list of permission DTOs
  final Map<String, List<PermissionModel>> rolePermissions;
  final String defaultEffect;
  final String? expiresAt; // ISO-8601

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['role_permissions'] as Map<String, dynamic>? ?? {};

    final rolePermissions = rawRoles.map((roleId, permsJson) {
      final permsList = (permsJson as List<dynamic>)
          .map((p) => PermissionModel.fromJson(p as Map<String, dynamic>))
          .toList();
      return MapEntry(roleId, permsList);
    });

    return PolicyModel(
      id: json['id'] as String,
      version: json['version'] as String,
      rolePermissions: rolePermissions,
      defaultEffect: (json['default_effect'] as String?) ?? 'deny',
      expiresAt: json['expires_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'role_permissions': rolePermissions.map(
          (k, v) => MapEntry(k, v.map((p) => p.toJson()).toList()),
        ),
        'default_effect': defaultEffect,
        if (expiresAt != null) 'expires_at': expiresAt,
      };

  Policy toDomain() {
    final domainPerms = rolePermissions.map(
      (roleId, models) =>
          MapEntry(roleId, models.map((m) => m.toDomain()).toList()),
    );

    return Policy(
      id: id,
      version: version,
      rolePermissions: domainPerms,
      defaultEffect: defaultEffect == 'allow'
          ? PermissionEffect.allow
          : PermissionEffect.deny,
      expiresAt: expiresAt != null ? DateTime.tryParse(expiresAt!) : null,
    );
  }

  factory PolicyModel.fromDomain(Policy policy) {
    final modelPerms = policy.rolePermissions.map(
      (roleId, perms) => MapEntry(
        roleId,
        perms.map(PermissionModel.fromDomain).toList(),
      ),
    );
    return PolicyModel(
      id: policy.id,
      version: policy.version,
      rolePermissions: modelPerms,
      defaultEffect:
          policy.defaultEffect == PermissionEffect.allow ? 'allow' : 'deny',
      expiresAt: policy.expiresAt?.toIso8601String(),
    );
  }
}
