/// Wraps a child with disabled visual styling when permission is denied.
/// Useful for buttons that should be visible but non-interactive for
/// unauthorised users.
library;

import 'package:flutter/material.dart';
import 'package:rbac_ui_engine/src/presentation/widgets/permission_gate.dart';

class RestrictedWidget extends StatelessWidget {
  const RestrictedWidget({
    super.key,
    required this.action,
    required this.resource,
    required this.child,
    this.disabledOpacity = 0.4,
    this.tooltip,
    this.abacContext = const {},
  });

  final String action;
  final String resource;
  final Widget child;
  final double disabledOpacity;
  final String? tooltip;
  final Map<String, dynamic> abacContext;

  @override
  Widget build(BuildContext buildContext) {
    final disabledVersion = Tooltip(
      message: tooltip ?? 'You don\'t have permission',
      child: Opacity(
        opacity: disabledOpacity,
        child: IgnorePointer(child: child),
      ),
    );

    return PermissionGate(
      action: action,
      resource: resource,
      disabledChild: disabledVersion,
      abacContext: abacContext,
      child: child,
    );
  }
}
