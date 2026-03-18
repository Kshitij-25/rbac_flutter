// test/data/policy_model_test.dart
//
// TASK 2.1 — TDD: JSON parsing tests written BEFORE implementation.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/rbac_ui_engine.dart';

void main() {
  group('PolicyModel JSON parsing', () {
    const validPolicyJson = '''
    {
      "id": "admin_policy_v1",
      "version": "2024-01-01",
      "description": "Full admin access policy",
      "statements": [
        {
          "resource": "*",
          "action": "read",
          "effect": "allow"
        },
        {
          "resource": "secret_vault",
          "action": "delete",
          "effect": "deny"
        },
        {
          "resource": "invoice",
          "action": "create",
          "effect": "allow",
          "conditions": { "department": "finance" }
        }
      ]
    }
    ''';

    test('fromJson parses id, version, description', () {
      final model = PolicyModel.fromJson(
        jsonDecode(validPolicyJson) as Map<String, dynamic>,
      );
      expect(model.id, 'admin_policy_v1');
      expect(model.version, '2024-01-01');
      expect(model.description, 'Full admin access policy');
    });

    test('fromJson parses all statements', () {
      final model = PolicyModel.fromJson(
        jsonDecode(validPolicyJson) as Map<String, dynamic>,
      );
      expect(model.statements, hasLength(3));
    });

    test('fromJson parses wildcard resource statement', () {
      final model = PolicyModel.fromJson(
        jsonDecode(validPolicyJson) as Map<String, dynamic>,
      );
      final stmt = model.statements.first;
      expect(stmt.resource, '*');
      expect(stmt.action, ActionType.read);
      expect(stmt.effect, Effect.allow);
    });

    test('fromJson parses deny statement', () {
      final model = PolicyModel.fromJson(
        jsonDecode(validPolicyJson) as Map<String, dynamic>,
      );
      final stmt = model.statements[1];
      expect(stmt.resource, 'secret_vault');
      expect(stmt.effect, Effect.deny);
    });

    test('fromJson parses conditional statement', () {
      final model = PolicyModel.fromJson(
        jsonDecode(validPolicyJson) as Map<String, dynamic>,
      );
      final stmt = model.statements[2];
      expect(stmt.conditions, containsPair('department', 'finance'));
    });

    test('toJson produces round-trippable output', () {
      final model = PolicyModel.fromJson(
        jsonDecode(validPolicyJson) as Map<String, dynamic>,
      );
      final json = model.toJson();
      final reparsed = PolicyModel.fromJson(json);
      expect(reparsed, equals(model));
    });

    test('toDomain converts to pure Policy domain entity', () {
      final model = PolicyModel.fromJson(
        jsonDecode(validPolicyJson) as Map<String, dynamic>,
      );
      final domain = model.toDomain();
      expect(domain, isA<Policy>());
      expect(domain.id, model.id);
      expect(domain.statements, hasLength(model.statements.length));
    });

    test('fromJson throws FormatException for missing required fields', () {
      const badJson = '{"version": "1"}'; // missing id and statements
      expect(
        () => PolicyModel.fromJson(
          jsonDecode(badJson) as Map<String, dynamic>,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson handles empty statements array', () {
      const emptyStmts = '{"id":"p1","version":"1","statements":[]}';
      final model = PolicyModel.fromJson(
        jsonDecode(emptyStmts) as Map<String, dynamic>,
      );
      expect(model.statements, isEmpty);
    });
  });

  group('PermissionModel JSON parsing', () {
    test('parses all ActionType values from string', () {
      for (final entry in {
        'create': ActionType.create,
        'read': ActionType.read,
        'update': ActionType.update,
        'delete': ActionType.delete,
        'execute': ActionType.execute,
        '*': ActionType.wildcard,
      }.entries) {
        final model = PermissionModel.fromJson({
          'resource': 'res',
          'action': entry.key,
          'effect': 'allow',
        });
        expect(model.action, entry.value);
      }
    });

    test('parses both Effect values', () {
      final allow = PermissionModel.fromJson(
        {'resource': 'r', 'action': 'read', 'effect': 'allow'},
      );
      final deny = PermissionModel.fromJson(
        {'resource': 'r', 'action': 'read', 'effect': 'deny'},
      );
      expect(allow.effect, Effect.allow);
      expect(deny.effect, Effect.deny);
    });

    test('unknown action throws ArgumentError', () {
      expect(
        () => PermissionModel.fromJson(
          {'resource': 'r', 'action': 'fly', 'effect': 'allow'},
        ),
        throwsArgumentError,
      );
    });
  });

  group('RoleModel JSON parsing', () {
    test('parses id, name, and parentIds', () {
      final model = RoleModel.fromJson({
        'id': 'editor',
        'name': 'Editor',
        'parentIds': ['viewer'],
        'policyId': 'editor_policy_v1',
      });
      expect(model.id, 'editor');
      expect(model.name, 'Editor');
      expect(model.parentIds, contains('viewer'));
      expect(model.policyId, 'editor_policy_v1');
    });

    test('parentIds defaults to empty when absent', () {
      final model = RoleModel.fromJson(
        {'id': 'admin', 'name': 'Admin', 'policyId': 'p1'},
      );
      expect(model.parentIds, isEmpty);
    });

    test('toDomain converts to pure Role entity', () {
      final model = RoleModel.fromJson(
        {'id': 'admin', 'name': 'Admin', 'policyId': 'p1'},
      );
      final domain = model.toDomain();
      expect(domain, isA<Role>());
      expect(domain.id, 'admin');
    });
  });
}
