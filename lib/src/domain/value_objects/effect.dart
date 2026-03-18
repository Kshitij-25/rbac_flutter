// lib/src/domain/value_objects/effect.dart

/// The effect of a [Permission] statement — either allow or deny.
///
/// When evaluating permissions the deny effect always wins over allow
/// (explicit deny principle, matching AWS IAM / OPA semantics).
enum Effect {
  /// Grant access.
  allow,

  /// Explicitly refuse access — wins over any allow.
  deny;

  static Effect fromString(String value) {
    return switch (value.toLowerCase()) {
      'allow' => Effect.allow,
      'deny' => Effect.deny,
      _ => throw ArgumentError('Unknown Effect: $value'),
    };
  }

  String toJson() => name;
}
