/// Represents an actor's role in the RBAC system.
///
/// A [Role] is the primary identity carrier. It can optionally inherit
/// from a parent role (role hierarchy). Roles are value objects — equality
/// is determined by [id], not object identity.
library;

class Role {
  const Role({
    required this.id,
    required this.name,
    this.parentRoleId,
    this.metadata = const {},
  });

  /// Unique identifier (e.g. 'admin', 'viewer', 'editor')
  final String id;

  /// Human-readable label
  final String name;

  /// Optional parent for hierarchical inheritance
  final String? parentRoleId;

  /// Arbitrary key-value metadata (e.g. department, region)
  final Map<String, dynamic> metadata;

  bool get isRoot => parentRoleId == null;

  Role copyWith({
    String? id,
    String? name,
    String? parentRoleId,
    Map<String, dynamic>? metadata,
  }) =>
      Role(
        id: id ?? this.id,
        name: name ?? this.name,
        parentRoleId: parentRoleId ?? this.parentRoleId,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Role && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Role(id: $id, name: $name, parent: $parentRoleId)';
}
