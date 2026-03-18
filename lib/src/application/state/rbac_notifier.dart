/// Riverpod [Notifier] that drives the entire RBAC reactive pipeline.
///
/// ## Why constructor injection was removed
/// Riverpod's [Notifier] contract forbids constructor parameters: the
/// framework creates the instance, then calls [build], where `ref` becomes
/// available.  All dependencies must be read via [ref.read] / [ref.watch].
///
/// ## Dependency wiring
/// Override [policyRepositoryProvider] and [roleProviderProvider] in your
/// [ProviderScope] overrides.  Everything else follows automatically.
///
/// ## Why Riverpod over Bloc
/// - [Notifier] + [NotifierProvider] = zero event/state boilerplate
/// - Providers are auto-disposed and composable
/// - `ref.watch` gives reactive rebuilds without StreamBuilder boilerplate
/// - No code generation required for this pattern
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';
import 'package:rbac_flutter/src/application/usecases/get_policy.dart';
import 'package:rbac_flutter/src/application/usecases/update_role.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';
import 'package:rbac_flutter/src/domain/entities/role.dart';

class RbacNotifier extends Notifier<RbacState> {
  /// Called by the Riverpod framework — do NOT call manually.
  ///
  /// Sets up stream subscriptions so the notifier reacts to
  /// server-pushed policy changes and auth role changes.
  @override
  RbacState build() {
    final policyRepo = ref.read(policyRepositoryProvider);
    final roleProvider = ref.read(roleProviderProvider);

    final policySub = policyRepo.policyChanges.listen((policy) {
      if (state case final RbacReady ready) {
        state = ready.copyWith(policy: policy);
      }
    });

    final roleSub = roleProvider.roleChanges.listen((roles) {
      if (state case final RbacReady ready) {
        state = ready.copyWith(roles: roles);
      }
    });

    ref.onDispose(() {
      policySub.cancel();
      roleSub.cancel();
    });

    return const RbacInitial();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Load policy + roles and transition to [RbacReady].
  /// Call once in your app's startup sequence.
  Future<void> initialize() async {
    state = const RbacLoading();

    final policyRepo = ref.read(policyRepositoryProvider);
    final roleProvider = ref.read(roleProviderProvider);

    // --- fetch policy ---
    final policyResult = await GetPolicy(policyRepo)();

    Policy? policy;
    policyResult.fold(
      (failure) => state = RbacError(failure),
      (p) => policy = p,
    );
    if (policy == null) return; // error state already set

    // --- fetch roles ---
    final rolesResult = await roleProvider.getCurrentRoles();
    rolesResult.fold(
      (failure) => state = RbacError(failure),
      (roles) => state = RbacReady(policy: policy!, roles: roles),
    );
  }

  /// Force-refresh policy from the remote source.
  Future<void> refresh() async {
    final policyRepo = ref.read(policyRepositoryProvider);
    final result = await GetPolicy(policyRepo)(forceRefresh: true);
    result.fold(
      (failure) => state = RbacError(failure),
      (policy) {
        if (state case final RbacReady ready) {
          state = ready.copyWith(policy: policy);
        }
      },
    );
  }

  /// Replace the active roles (role-switcher / dev tools / sign-in events).
  Future<void> setRoles(List<Role> roles) async {
    final roleProvider = ref.read(roleProviderProvider);
    final result = await UpdateRole(roleProvider)(roles);
    result.fold(
      (failure) => state = RbacError(failure),
      (_) {
        if (state case final RbacReady ready) {
          state = ready.copyWith(roles: roles);
        }
      },
    );
  }
}
