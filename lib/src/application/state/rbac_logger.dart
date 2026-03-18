/// Structured logger for permission evaluation events.
///
/// Outputs structured log lines that can be parsed by log aggregators.
/// Disable in production by passing [level: Level.off] or
/// setting [RbacLogger.enabled = false].
library;

import 'package:logger/logger.dart';
import 'package:rbac_ui_engine/src/domain/entities/permission.dart';
import 'package:rbac_ui_engine/src/domain/entities/resource.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';

class RbacLogger {
  RbacLogger({Logger? logger})
      : _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 5,
                lineLength: 80,
              ),
            );

  static bool enabled = true;

  final Logger _logger;

  void logEvaluation({
    required Role role,
    required String action,
    required Resource resource,
    required PermissionEffect effect,
    String? reason,
  }) {
    if (!enabled) return;
    final allowed = effect == PermissionEffect.allow;
    final emoji = allowed ? '✅' : '🚫';
    _logger.d(
      '$emoji [RBAC] ${allowed ? "ALLOW" : "DENY"} '
      '| role=${role.id} | action=$action | resource=${resource.id}'
      '${reason != null ? " | reason=$reason" : ""}',
    );
  }

  void logPolicyFetch({
    required String source,
    required String policyId,
    required String version,
  }) {
    if (!enabled) return;
    _logger.i(
      '📋 [RBAC] Policy loaded | source=$source '
      '| id=$policyId | version=$version',
    );
  }

  void logFailure(RbacFailure failure) {
    if (!enabled) return;
    _logger.e('❌ [RBAC] Failure: ${failure.message}', error: failure);
  }

  void logRoleChange(List<Role> roles) {
    if (!enabled) return;
    _logger.i(
      '👤 [RBAC] Roles changed → ${roles.map((r) => r.id).join(", ")}',
    );
  }
}
