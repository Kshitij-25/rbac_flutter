/// Debug overlay that shows the active policy, roles, and live
/// permission evaluation results. Only visible in debug mode.
///
/// Wrap your app root with [RbacInspector] during development:
/// ```dart
/// RbacInspector(child: MyApp())
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_flutter/src/application/providers/rbac_providers.dart';
import 'package:rbac_flutter/src/application/state/rbac_state.dart';

class RbacInspector extends ConsumerWidget {
  const RbacInspector({
    super.key,
    required this.child,
    this.showInRelease = false,
  });

  final Widget child;

  /// Set to true to show inspector in release builds (use with caution).
  final bool showInRelease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode && !showInRelease) return child;

    return Stack(
      children: [
        child,
        Positioned(
          bottom: 16,
          right: 16,
          child: _InspectorFab(),
        ),
      ],
    );
  }
}

class _InspectorFab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_InspectorFab> createState() => _InspectorFabState();
}

class _InspectorFabState extends ConsumerState<_InspectorFab> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rbacNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) _buildPanel(state),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'rbac_inspector',
          backgroundColor: Colors.deepPurple,
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Icon(
            _expanded ? Icons.close : Icons.security,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(RbacState state) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey.shade900,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header('RBAC Inspector'),
              const Divider(color: Colors.white24),
              _buildStateSection(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateSection(RbacState state) {
    return switch (state) {
      RbacInitial() => _label('State: Initial (not loaded)'),
      RbacLoading() => _label('State: Loading...'),
      RbacError(:final failure) => _label(
          'State: ERROR\n${failure.message}',
          color: Colors.redAccent,
        ),
      RbacReady(:final policy, :final roles) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('State: Ready ✓', color: Colors.greenAccent),
            const SizedBox(height: 6),
            _label('Policy: ${policy.id} v${policy.version}'),
            _label('Expires: ${policy.expiresAt ?? "never"}'),
            const SizedBox(height: 6),
            _label('Active Roles:'),
            ...roles.map((r) => _label('  • ${r.name} (${r.id})')),
            const SizedBox(height: 6),
            _label('Defined Role IDs:'),
            ...policy.definedRoleIds.map((id) => _label('  • $id')),
          ],
        ),
    };
  }

  Widget _header(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      );

  Widget _label(String text, {Color color = Colors.white70}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 11),
        ),
      );
}
