// lib/src/domain/value_objects/action_type.dart

/// Represents the action being performed on a [Resource].
///
/// Follows standard CRUD + wildcard modelling (OPA-compatible).
enum ActionType {
  /// Create a new resource instance.
  create,

  /// Read / view an existing resource.
  read,

  /// Modify an existing resource.
  update,

  /// Remove a resource.
  delete,

  /// Execute an operation (e.g. trigger workflow).
  execute,

  /// Any action — used in wildcard permissions.
  wildcard;

  /// Deserialise from a JSON string value.
  static ActionType fromString(String value) {
    return switch (value.toLowerCase()) {
      'create' => ActionType.create,
      'read' => ActionType.read,
      'update' => ActionType.update,
      'delete' => ActionType.delete,
      'execute' => ActionType.execute,
      '*' || 'wildcard' => ActionType.wildcard,
      _ => throw ArgumentError('Unknown ActionType: $value'),
    };
  }

  /// Serialise to JSON string value.
  String toJson() => switch (this) {
        ActionType.create => 'create',
        ActionType.read => 'read',
        ActionType.update => 'update',
        ActionType.delete => 'delete',
        ActionType.execute => 'execute',
        ActionType.wildcard => '*',
      };
}
