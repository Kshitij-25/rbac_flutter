/// Tests for [InMemoryRoleProvider].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/src/data/repositories/role_provider_impl.dart';
import 'package:rbac_ui_engine/src/domain/entities/role.dart';

void main() {
  const admin = Role(id: 'admin', name: 'Admin');
  const viewer = Role(id: 'viewer', name: 'Viewer');
  const editor = Role(id: 'editor', name: 'Editor');

  group('InMemoryRoleProvider', () {
    group('getCurrentRoles', () {
      test('returns empty list when no initial roles set', () async {
        final provider = InMemoryRoleProvider();
        final result = await provider.getCurrentRoles();
        result.fold(
          (_) => fail('Expected Right'),
          (roles) => expect(roles, isEmpty),
        );
      });

      test('returns initial roles when provided', () async {
        final provider = InMemoryRoleProvider(initialRoles: [admin, viewer]);
        final result = await provider.getCurrentRoles();
        result.fold(
          (_) => fail('Expected Right'),
          (roles) {
            expect(roles, containsAll([admin, viewer]));
            expect(roles.length, equals(2));
          },
        );
      });

      test('returned list is unmodifiable', () async {
        final provider = InMemoryRoleProvider(initialRoles: [admin]);
        final result = await provider.getCurrentRoles();
        result.fold(
          (_) => fail('Expected Right'),
          (roles) => expect(
            () => (roles as dynamic).add(viewer),
            throwsA(anything),
          ),
        );
      });
    });

    group('setRoles', () {
      test('replaces current roles and returns Right(unit)', () async {
        final provider = InMemoryRoleProvider(initialRoles: [admin]);
        final setResult = await provider.setRoles([viewer, editor]);
        expect(setResult.isRight(), isTrue);

        final getResult = await provider.getCurrentRoles();
        getResult.fold(
          (_) => fail('Expected Right'),
          (roles) {
            expect(roles, containsAll([viewer, editor]));
            expect(roles, isNot(contains(admin)));
          },
        );
      });

      test('can set empty roles list', () async {
        final provider = InMemoryRoleProvider(initialRoles: [admin]);
        await provider.setRoles([]);
        final result = await provider.getCurrentRoles();
        result.fold((_) => fail('Expected Right'), (r) => expect(r, isEmpty));
      });
    });

    group('roleChanges stream', () {
      test('emits new roles after setRoles is called', () async {
        final provider = InMemoryRoleProvider(initialRoles: [admin]);
        final emitted = <List<Role>>[];

        final sub = provider.roleChanges.listen(emitted.add);

        await provider.setRoles([viewer]);
        await provider.setRoles([editor]);
        await Future<void>.delayed(Duration.zero);

        expect(emitted.length, equals(2));
        expect(emitted[0], contains(viewer));
        expect(emitted[1], contains(editor));

        await sub.cancel();
        provider.dispose();
      });

      test('multiple listeners all receive updates', () async {
        final provider = InMemoryRoleProvider();
        final received1 = <List<Role>>[];
        final received2 = <List<Role>>[];

        final sub1 = provider.roleChanges.listen(received1.add);
        final sub2 = provider.roleChanges.listen(received2.add);

        await provider.setRoles([admin]);
        await Future<void>.delayed(Duration.zero);

        expect(received1.length, equals(1));
        expect(received2.length, equals(1));

        await sub1.cancel();
        await sub2.cancel();
        provider.dispose();
      });

      test('no events emitted before setRoles is called', () async {
        final provider = InMemoryRoleProvider(initialRoles: [admin]);
        final emitted = <List<Role>>[];
        final sub = provider.roleChanges.listen(emitted.add);
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isEmpty);

        await sub.cancel();
        provider.dispose();
      });
    });
  });
}
