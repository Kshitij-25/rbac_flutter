# rbac_ui_engine

A production-grade **Role-Based UI Rendering Engine** for Flutter — Clean Architecture, TDD, Riverpod, RBAC + ABAC.

## Features

- 🔐 **RBAC + ABAC** — Role-based + attribute-based access control (OPA-inspired)
- ⚡ **Reactive** — Widgets auto-rebuild when roles or policies change via Riverpod
- 🏗️ **Clean Architecture** — Domain, Data, Application, Presentation layers
- 🧪 **TDD-first** — 18 test files covering unit, widget, and integration scenarios
- 🌐 **Dio-powered** — Remote policy fetching via `DioRbacHttpClient`
- 🗄️ **Cache-first** — `SharedPreferences` policy cache with SHA-256 key hashing
- 🛡️ **Fail-closed** — Deny by default; explicit allows required
- 🔌 **Extensible** — Swap auth providers, policy sources, or evaluators via interfaces

---

## Quick Start

### 1. Add dependency

```yaml
dependencies:
  rbac_ui_engine: ^1.0.0
```

### 2. Provide infrastructure + initialise

```dart
void main() {
  final policy = Policy(
    id: 'my-policy',
    version: '1.0',
    rolePermissions: {
      'admin': [const Permission(action: '*', resource: '*')],
      'viewer': [const Permission(action: 'read', resource: 'dashboard')],
    },
  );

  runApp(
    ProviderScope(
      overrides: [
        policyRepositoryProvider.overrideWithValue(StaticPolicyRepository(policy)),
        roleProviderProvider.overrideWithValue(
          InMemoryRoleProvider(initialRoles: [const Role(id: 'viewer', name: 'Viewer')]),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

### 3. Initialise the engine (call once after first frame)

```dart
class MyHomePage extends ConsumerStatefulWidget { ... }

class _MyHomePageState extends ConsumerState<MyHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rbacNotifierProvider.notifier).initialize();
    });
  }
}
```

### 4. Guard widgets declaratively

```dart
// Show child only when allowed, show fallback when denied
PermissionGate(
  action: 'delete',
  resource: 'invoice',
  fallback: const Text('No access'),
  child: DeleteInvoiceButton(),
)

// Show a visually-disabled version of the child when denied
RestrictedWidget(
  action: 'write',
  resource: 'invoice',
  tooltip: 'Editor role required',
  child: CreateInvoiceButton(),
)

// Build different UI per role
RoleBuilder(
  builder: (context, roles) {
    final isAdmin = roles.any((r) => r.id == 'admin');
    return isAdmin ? AdminDashboard() : ViewerDashboard();
  },
)
```

### 5. Protect routes (GoRouter)

```dart
GoRoute(
  path: '/admin',
  redirect: (ctx, state) => RbacRouteGuard(
    ref: ref,
    action: 'view',
    resource: 'admin_panel',
    redirectTo: '/unauthorized',
  ).redirect(ctx, state),
  builder: (_, __) => AdminScreen(),
)
```

---

## Architecture

```
lib/src/
├── domain/           # Zero external dependencies
│   ├── entities/     # Role, Permission, Policy, Resource
│   ├── interfaces/   # PolicyRepository, PermissionEvaluator, RoleProvider
│   ├── evaluator/    # RbacPermissionEvaluator
│   ├── value_objects/# ActionType, Effect
│   └── exceptions/   # RbacFailure sealed class hierarchy
├── data/             # DTOs, Dio client, cache, repository implementations
│   ├── models/       # PolicyModel, PermissionModel
│   ├── sources/      # HttpPolicyRemoteSource (Dio), SharedPrefsCacheSource
│   └── repositories/ # PolicyRepositoryImpl, InMemoryRoleProvider,
│                     #   StaticPolicyRepository
├── application/      # Use cases + Riverpod state
│   ├── usecases/     # GetPolicy, EvaluatePermission, UpdateRole
│   ├── state/        # RbacNotifier, RbacState, RbacLogger
│   └── providers/    # Riverpod provider declarations
└── presentation/     # Flutter widgets and guards
    ├── widgets/      # PermissionGate, RestrictedWidget, RbacInspector
    ├── builders/     # RoleBuilder
    └── guards/       # RbacRouteGuard, RbacNavigatorGuard
```

---

## Permission Evaluation Algorithm

Evaluation follows an **OPA-inspired deny-wins** model:

1. Collect permissions for role + all ancestors (hierarchy walk)
2. Filter by action match (exact or `*` wildcard)
3. Filter by resource match (exact or `*` wildcard)
4. Filter by ABAC conditions (`context` must be a superset of `conditions`)
5. **If ANY matched permission is `deny` → DENY** (deny always wins)
6. If ANY matched permission is `allow` → ALLOW
7. Otherwise → `policy.defaultEffect` (default: `deny` — fail-closed)

---

## Remote Policy Source (Dio)

```dart
import 'package:dio/dio.dart';

final source = HttpPolicyRemoteSource(
  endpoint: 'https://api.example.com/rbac/policy',
  httpClient: DioRbacHttpClient(
    Dio()..options = BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ),
  ),
  headers: {'Authorization': 'Bearer \$token'},
);

final repo = PolicyRepositoryImpl(
  remoteSource: source,
  cacheSource: SharedPrefsPolicyCacheSource(preferences: prefs),
  cacheKey: 'my_app_policy',
);
```

Expected JSON format:

```json
{
  "id": "policy-001",
  "version": "1.0.0",
  "default_effect": "deny",
  "expires_at": "2026-01-01T00:00:00Z",
  "role_permissions": {
    "admin": [
      { "action": "*", "resource": "*", "effect": "allow", "conditions": {} }
    ],
    "viewer": [
      { "action": "read", "resource": "dashboard", "effect": "allow", "conditions": {} }
    ]
  }
}
```

---

## ABAC Conditional Permissions

```dart
// Policy
Permission(
  action: 'read',
  resource: 'report',
  conditions: {'clearance': 'top-secret', 'region': 'eu'},
)

// Widget — must pass matching abacContext
PermissionGate(
  action: 'read',
  resource: 'report',
  abacContext: {'clearance': 'top-secret', 'region': 'eu'},
  child: ConfidentialReportWidget(),
)
```

---

## Role Hierarchy

```dart
// Parent
const Role(id: 'viewer', name: 'Viewer')

// Child inherits all viewer permissions
const Role(id: 'editor', name: 'Editor', parentRoleId: 'viewer')
```

---

## Debug Inspector

```dart
RbacInspector(child: MyApp())  // shows a FAB overlay in debug builds
```

Shows active policy version, current roles, and all defined role IDs.
Hidden automatically in release builds.

---

## Testing

```bash
flutter test                        # all tests
flutter test test/unit/             # unit tests only
flutter test test/widget/           # widget tests only
flutter test test/integration/      # integration tests
```

### Stub pattern for widget tests

```dart
class _StubRbacNotifier extends Notifier<RbacState> {
  _StubRbacNotifier(this._state);
  final RbacState _state;
  @override
  RbacState build() => _state;
}

ProviderScope(
  overrides: [
    rbacNotifierProvider.overrideWith(() => _StubRbacNotifier(myState)),
  ],
  child: MaterialApp(home: MyWidget()),
)
```

---

## Security Notes

> **Client-side enforcement is not a security boundary.**
>
> This package controls UI visibility and UX interactions.
> Always enforce permissions server-side. Never rely solely on
> client-side RBAC to protect sensitive data or operations.

---

## License

MIT
