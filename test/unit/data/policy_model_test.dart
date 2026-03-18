import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_flutter/src/data/models/permission_model.dart';
import 'package:rbac_flutter/src/data/models/policy_model.dart';
import 'package:rbac_flutter/src/domain/entities/permission.dart';
import 'package:rbac_flutter/src/domain/entities/policy.dart';

void main() {
  group('PolicyModel', () {
    final sampleJson = {
      'id': 'policy-001',
      'version': '1.2.0',
      'default_effect': 'deny',
      'expires_at': '2099-01-01T00:00:00.000Z',
      'role_permissions': {
        'admin': [
          {
            'action': 'read',
            'resource': 'dashboard',
            'effect': 'allow',
            'conditions': {},
          },
          {
            'action': 'delete',
            'resource': 'invoice',
            'effect': 'deny',
            'conditions': {},
          },
        ],
        'viewer': [
          {
            'action': 'read',
            'resource': 'dashboard',
            'effect': 'allow',
            'conditions': {},
          },
        ],
      },
    };

    group('fromJson', () {
      test('parses id and version', () {
        final model = PolicyModel.fromJson(sampleJson);
        expect(model.id, equals('policy-001'));
        expect(model.version, equals('1.2.0'));
      });

      test('parses defaultEffect', () {
        final model = PolicyModel.fromJson(sampleJson);
        expect(model.defaultEffect, equals('deny'));
      });

      test('parses expiresAt', () {
        final model = PolicyModel.fromJson(sampleJson);
        expect(model.expiresAt, equals('2099-01-01T00:00:00.000Z'));
      });

      test('parses role permissions map', () {
        final model = PolicyModel.fromJson(sampleJson);
        expect(model.rolePermissions.keys, containsAll(['admin', 'viewer']));
        expect(model.rolePermissions['admin']!.length, equals(2));
        expect(model.rolePermissions['viewer']!.length, equals(1));
      });

      test('defaults defaultEffect to deny when missing', () {
        final json = Map<String, dynamic>.from(sampleJson)
          ..remove('default_effect');
        final model = PolicyModel.fromJson(json);
        expect(model.defaultEffect, equals('deny'));
      });

      test('handles missing role_permissions gracefully', () {
        final json = {
          'id': 'x',
          'version': '1.0',
        };
        final model = PolicyModel.fromJson(json);
        expect(model.rolePermissions, isEmpty);
      });
    });

    group('toDomain', () {
      test('converts to Policy domain entity', () {
        final model = PolicyModel.fromJson(sampleJson);
        final domain = model.toDomain();
        expect(domain, isA<Policy>());
        expect(domain.id, equals('policy-001'));
        expect(domain.version, equals('1.2.0'));
      });

      test('domain defaultEffect is deny', () {
        final model = PolicyModel.fromJson(sampleJson);
        final domain = model.toDomain();
        expect(domain.defaultEffect, equals(PermissionEffect.deny));
      });

      test('domain expiresAt parses correctly', () {
        final model = PolicyModel.fromJson(sampleJson);
        final domain = model.toDomain();
        expect(domain.expiresAt, isNotNull);
        expect(domain.isExpired, isFalse);
      });

      test('admin role has 2 permissions in domain', () {
        final model = PolicyModel.fromJson(sampleJson);
        final domain = model.toDomain();
        expect(domain.rolePermissions['admin']!.length, equals(2));
      });
    });

    group('toJson round-trip', () {
      test('serializes back to equivalent JSON', () {
        final model = PolicyModel.fromJson(sampleJson);
        final json = model.toJson();
        final model2 = PolicyModel.fromJson(json);
        expect(model2.id, equals(model.id));
        expect(model2.version, equals(model.version));
        expect(
          model2.rolePermissions.keys.length,
          equals(model.rolePermissions.keys.length),
        );
      });
    });

    group('fromDomain', () {
      test('converts domain Policy back to model', () {
        final original = PolicyModel.fromJson(sampleJson);
        final domain = original.toDomain();
        final roundTripped = PolicyModel.fromDomain(domain);
        expect(roundTripped.id, equals(original.id));
        expect(roundTripped.version, equals(original.version));
      });
    });
  });

  group('PermissionModel', () {
    test('fromJson with allow effect', () {
      final json = {
        'action': 'read',
        'resource': 'dashboard',
        'effect': 'allow',
        'conditions': {'env': 'prod'},
      };
      final model = PermissionModel.fromJson(json);
      final domain = model.toDomain();
      expect(domain.isAllow, isTrue);
      expect(domain.conditions['env'], equals('prod'));
    });

    test('fromJson with deny effect', () {
      final json = {
        'action': 'delete',
        'resource': 'user',
        'effect': 'deny',
        'conditions': {},
      };
      final model = PermissionModel.fromJson(json);
      expect(model.toDomain().isDeny, isTrue);
    });

    test('defaults effect to allow when missing', () {
      final json = {'action': 'read', 'resource': 'x'};
      final model = PermissionModel.fromJson(json);
      expect(model.effect, equals('allow'));
    });
  });
}
