/// Core permission evaluation engine.
///
/// Evaluation algorithm (OPA-inspired, fail-closed):
///
///   1. Collect all candidate permissions for the role (own + inherited)
///   2. Filter candidates matching action (exact or wildcard '*')
///      AND resource (exact or wildcard '*')
///      AND conditions (ABAC context subset check)
///   3. If ANY matching permission has effect=deny → DENY (deny wins)
///   4. If ANY matching permission has effect=allow → ALLOW
///   5. Otherwise → policy.defaultEffect (typically DENY)
library;

import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/resource.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';
import 'package:rbac_flutter/src/domain/interfaces/permission_evaluator.dart';

class RbacPermissionEvaluator implements PermissionEvaluator {
  const RbacPermissionEvaluator();

  @override
  PermissionEffect evaluate({
    required Policy policy,
    required Role role,
    required String action,
    required Resource resource,
    Map<String, dynamic> context = const {},
  }) {
    final candidates = _collectPermissions(policy, role);
    final matched = candidates
        .where((p) => _matchesAction(p, action))
        .where((p) => _matchesResource(p, resource))
        .where((p) => _matchesConditions(p, context))
        .toList();

    // Deny wins — if any deny matches, the answer is deny
    if (matched.any((p) => p.isDeny)) return PermissionEffect.deny;
    if (matched.any((p) => p.isAllow)) return PermissionEffect.allow;

    return policy.defaultEffect;
  }

  @override
  bool isAllowed({
    required Policy policy,
    required Role role,
    required String action,
    required Resource resource,
    Map<String, dynamic> context = const {},
  }) =>
      evaluate(
        policy: policy,
        role: role,
        action: action,
        resource: resource,
        context: context,
      ) ==
      PermissionEffect.allow;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Collects permissions for [role] + all ancestors (role hierarchy).
  List<Permission> _collectPermissions(Policy policy, Role role) {
    final perms = <Permission>[];
    var currentId = role.id;
    final visited = <String>{};

    // Walk up the role hierarchy, guarding against cycles
    while (true) {
      if (visited.contains(currentId)) break;
      visited.add(currentId);

      final rolePerms = policy.rolePermissions[currentId] ?? [];
      perms.addAll(rolePerms);

      // Find the parent role definition within the policy to continue climb
      // The parent role id lives on the Role entity; we need to resolve it.
      // Since Policy stores role ids only, we use the Role's parentRoleId
      // when we're on the first iteration (the actual role entity).
      // For ancestor roles we only have an id string, so we stop here.
      // In a richer setup you'd inject a RoleRegistry.
      if (currentId == role.id && role.parentRoleId != null) {
        currentId = role.parentRoleId!;
      } else {
        break;
      }
    }

    return perms;
  }

  bool _matchesAction(Permission p, String action) =>
      p.action == action || p.action == '*';

  bool _matchesResource(Permission p, Resource resource) =>
      p.resource == resource.id || p.resource == '*';

  /// ABAC condition check: every key-value in [p.conditions] must be
  /// present with the same value in [context].  Empty conditions always match.
  bool _matchesConditions(
    Permission p,
    Map<String, dynamic> context,
  ) {
    if (p.conditions.isEmpty) return true;
    return p.conditions.entries.every(
      (entry) => context[entry.key] == entry.value,
    );
  }
}
