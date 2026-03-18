/// Represents a UI or system resource that permissions are checked against.
///
/// A [Resource] is anything that can be guarded:
///   - A widget area ('dashboard.analytics')
///   - A route ('/admin/users')
///   - A button ('invoice.delete')
///
/// Supports hierarchical dot-notation for wildcard matching.
library;

class Resource {
  const Resource({
    required this.id,
    this.type = ResourceType.widget,
    this.attributes = const {},
  });

  /// Dot-separated identifier (e.g. 'dashboard.analytics.chart')
  final String id;

  /// Category of resource for semantic grouping
  final ResourceType type;

  /// ABAC context attributes attached to this resource
  final Map<String, dynamic> attributes;

  /// Returns the hierarchical segments of the resource id.
  /// e.g. 'dashboard.analytics' → ['dashboard', 'analytics']
  List<String> get segments => id.split('.');

  /// Convenience: root namespace (first segment)
  String get namespace => segments.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Resource && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Resource(id: $id, type: ${type.name})';
}

enum ResourceType {
  widget,
  route,
  action,
  data,
}
