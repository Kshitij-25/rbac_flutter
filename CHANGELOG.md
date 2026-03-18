## 1.0.0

* Initial release
* Clean Architecture with Domain, Data, Application, Presentation layers
* RBAC + ABAC evaluation engine (OPA-inspired deny-wins algorithm)
* Role hierarchy / permission inheritance
* Wildcard action and resource matching
* Reactive Riverpod state management
* PermissionGate, RestrictedWidget, RoleBuilder, RbacInspector widgets
* GoRouter-compatible RbacRouteGuard
* HttpPolicyRemoteSource with configurable auth headers
* SharedPreferences-backed policy cache with SHA-256 key hashing
* StaticPolicyRepository for tests and demo apps
* InMemoryRoleProvider with reactive Stream<List<Role>>
* Structured RbacLogger for permission audit trails
* Full test suite: unit, widget, and integration tests
