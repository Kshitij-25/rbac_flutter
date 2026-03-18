/// Typed failure hierarchy for the RBAC engine.
///
/// Using a sealed class hierarchy instead of raw exceptions lets us
/// exhaustively pattern-match failures in use cases and the UI.
library;

sealed class RbacFailure {
  const RbacFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Policy could not be fetched from the remote source.
final class PolicyFetchFailure extends RbacFailure {
  const PolicyFetchFailure(super.message, {this.statusCode});
  final int? statusCode;
}

/// Policy JSON was malformed or schema validation failed.
final class PolicyParseFailure extends RbacFailure {
  const PolicyParseFailure(super.message, {this.rawJson});
  final String? rawJson;
}

/// Cache read/write failed.
final class CacheFailure extends RbacFailure {
  const CacheFailure(super.message);
}

/// Role provider returned no roles or an error.
final class RoleProviderFailure extends RbacFailure {
  const RoleProviderFailure(super.message);
}

/// Permission evaluation resulted in an unexpected state.
final class EvaluationFailure extends RbacFailure {
  const EvaluationFailure(super.message);
}

/// Generic / unexpected failure — always carry the original error.
final class UnexpectedFailure extends RbacFailure {
  const UnexpectedFailure(super.message, {this.error, this.stackTrace});
  final Object? error;
  final StackTrace? stackTrace;
}
