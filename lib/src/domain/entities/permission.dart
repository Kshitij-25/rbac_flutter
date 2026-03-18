/// Represents a discrete action a role may perform on a resource.
///
/// A [Permission] models RBAC "what can you do?" as a triplet:
///   action × resource × effect
///
/// e.g. action='read', resource='dashboard', effect=allow
library;

/// Whether a permission grants or denies access.
enum PermissionEffect { allow, deny }

class Permission {
  const Permission({
    required this.action,
    required this.resource,
    this.effect = PermissionEffect.allow,
    this.conditions = const {},
  });

  /// The operation (e.g. 'read', 'write', 'delete', '*')
  final String action;

  /// The resource being acted upon (e.g. 'dashboard', 'user:*')
  final String resource;

  /// Whether this permission allows or explicitly denies
  final PermissionEffect effect;

  /// ABAC-style attribute conditions (e.g. {'department': 'engineering'})
  final Map<String, dynamic> conditions;

  bool get isAllow => effect == PermissionEffect.allow;
  bool get isDeny => effect == PermissionEffect.deny;

  Permission copyWith({
    String? action,
    String? resource,
    PermissionEffect? effect,
    Map<String, dynamic>? conditions,
  }) =>
      Permission(
        action: action ?? this.action,
        resource: resource ?? this.resource,
        effect: effect ?? this.effect,
        conditions: conditions ?? this.conditions,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission &&
          other.action == action &&
          other.resource == resource &&
          other.effect == effect;

  @override
  int get hashCode => Object.hash(action, resource, effect);

  @override
  String toString() => 'Permission(${effect.name}: $action on $resource)';
}
