/// Full demo dashboard with role-switcher and all widget types exercised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbac_flutter/rbac_ui_engine.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _roleOptions = [
    ('admin', 'Administrator'),
    ('editor', 'Editor'),
    ('viewer', 'Viewer'),
    ('guest', 'Guest'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RBAC Engine Demo'),
        actions: [const _RoleSwitcher(roleOptions: _roleOptions)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active role display
            RoleBuilder(
              loading: const LinearProgressIndicator(),
              builder: (ctx, roles) => Card(
                color: Colors.deepPurple.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.deepPurple),
                  title: Text(
                    'Role: ${roles.map((r) => r).join(", ")}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Switch role via top-right menu'),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Analytics: viewer + above ──────────────────────────────────
            const _SectionHeader('Analytics (read • viewer+)'),
            PermissionGate(
              action: 'read',
              resource: 'dashboard',
              fallback: const _LockedCard('Requires at least viewer role'),
              child: _AnalyticsCard(),
            ),
            const SizedBox(height: 16),

            // ── Invoice actions ────────────────────────────────────────────
            const _SectionHeader(
              'Invoice (write • editor+  |  delete • admin)',
            ),
            Row(
              children: [
                Expanded(
                  child: RestrictedWidget(
                    action: 'write',
                    resource: 'invoice',
                    tooltip: 'Editor or admin role required',
                    child: FilledButton.icon(
                      onPressed: () => _snack(context, 'Invoice created!'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PermissionGate(
                    action: 'delete',
                    resource: 'invoice',
                    // disabledChild: grey locked button shown instead of hiding
                    disabledChild: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.grey,
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Delete'),
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _snack(context, 'Invoice deleted!'),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Admin panel: admin only ────────────────────────────────────
            const _SectionHeader('User Management (admin only)'),
            PermissionGate(
              action: 'write',
              resource: 'users',
              fallback: const _LockedCard('Admin access required'),
              child: Card(
                color: Colors.orange.shade50,
                child: const ListTile(
                  leading:
                      Icon(Icons.admin_panel_settings, color: Colors.orange),
                  title: Text('User Management'),
                  subtitle: Text('Create, update, delete user accounts'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── ABAC example ───────────────────────────────────────────────
            const _SectionHeader('Conditional Access (ABAC)'),
            PermissionGate(
              action: 'read',
              resource: 'report',
              // Only admins have * on *, which covers this
              abacContext: const {'env': 'production'},
              fallback:
                  const _LockedCard('No conditional access for this role'),
              child: Card(
                color: Colors.teal.shade50,
                child: const ListTile(
                  leading: Icon(Icons.analytics, color: Colors.teal),
                  title: Text('Production Report'),
                  subtitle: Text('env=production context satisfied'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _RoleSwitcher extends ConsumerWidget {
  const _RoleSwitcher({required this.roleOptions});
  final List<(String, String)> roleOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.switch_account),
      tooltip: 'Switch role',
      onSelected: (roleId) {
        final name = roleOptions
            .firstWhere(
              (r) => r.$1 == roleId,
              orElse: () => (roleId, roleId),
            )
            .$2;
        ref.read(rbacNotifierProvider.notifier).setRoles(
          [Role(id: roleId, name: name)],
        );
      },
      itemBuilder: (_) => roleOptions
          .map((r) => PopupMenuItem(value: r.$1, child: Text(r.$2)))
          .toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Colors.grey.shade600),
        ),
      );
}

class _AnalyticsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.bar_chart, size: 40, color: Colors.deepPurple),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue: \$42,000',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text('Monthly active users: 1,234'),
                ],
              ),
            ],
          ),
        ),
      );
}

class _LockedCard extends StatelessWidget {
  const _LockedCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.grey.shade100,
        child: ListTile(
          leading: Icon(Icons.lock_outline, color: Colors.grey.shade400),
          title: Text(message, style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
}
