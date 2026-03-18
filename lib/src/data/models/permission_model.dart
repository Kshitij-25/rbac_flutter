/// JSON-serializable DTO for [Permission].
/// The data layer owns this model; mappers convert to/from domain entities.
library;

import 'package:rbac_flutter/src/domain/entities/permission.dart';

class PermissionModel {
  const PermissionModel({
    required this.action,
    required this.resource,
    this.effect = 'allow',
    this.conditions = const {},
  });

  final String action;
  final String resource;
  final String effect;
  final Map<String, dynamic> conditions;

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      action: json['action'] as String,
      resource: json['resource'] as String,
      effect: (json['effect'] as String?) ?? 'allow',
      conditions: (json['conditions'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'resource': resource,
        'effect': effect,
        'conditions': conditions,
      };

  Permission toDomain() => Permission(
        action: action,
        resource: resource,
        effect:
            effect == 'deny' ? PermissionEffect.deny : PermissionEffect.allow,
        conditions: conditions,
      );

  factory PermissionModel.fromDomain(Permission p) => PermissionModel(
        action: p.action,
        resource: p.resource,
        effect: p.effect == PermissionEffect.deny ? 'deny' : 'allow',
        conditions: p.conditions,
      );
}
