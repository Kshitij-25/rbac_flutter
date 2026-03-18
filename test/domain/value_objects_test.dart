/// Tests for domain value objects: [ActionType] and [Effect].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/src/domain/value_objects/action_type.dart';
import 'package:rbac_ui_engine/src/domain/value_objects/effect.dart';

void main() {
  group('ActionType', () {
    group('fromString', () {
      test('parses all named actions', () {
        expect(ActionType.fromString('create'), ActionType.create);
        expect(ActionType.fromString('read'), ActionType.read);
        expect(ActionType.fromString('update'), ActionType.update);
        expect(ActionType.fromString('delete'), ActionType.delete);
        expect(ActionType.fromString('execute'), ActionType.execute);
      });

      test('parses wildcard from asterisk', () {
        expect(ActionType.fromString('*'), ActionType.wildcard);
      });

      test('parses wildcard from "wildcard" string', () {
        expect(ActionType.fromString('wildcard'), ActionType.wildcard);
      });

      test('is case-insensitive', () {
        expect(ActionType.fromString('READ'), ActionType.read);
        expect(ActionType.fromString('Delete'), ActionType.delete);
      });

      test('throws ArgumentError for unknown value', () {
        expect(() => ActionType.fromString('fly'), throwsArgumentError);
      });
    });

    group('toJson', () {
      test('serialises wildcard to asterisk', () {
        expect(ActionType.wildcard.toJson(), equals('*'));
      });

      test('serialises named actions to lowercase string', () {
        expect(ActionType.read.toJson(), equals('read'));
        expect(ActionType.delete.toJson(), equals('delete'));
      });

      test('round-trip: fromString(toJson()) == original', () {
        for (final action in ActionType.values) {
          expect(ActionType.fromString(action.toJson()), equals(action));
        }
      });
    });
  });

  group('Effect', () {
    group('fromString', () {
      test('parses allow', () {
        expect(Effect.fromString('allow'), Effect.allow);
      });

      test('parses deny', () {
        expect(Effect.fromString('deny'), Effect.deny);
      });

      test('is case-insensitive', () {
        expect(Effect.fromString('ALLOW'), Effect.allow);
        expect(Effect.fromString('Deny'), Effect.deny);
      });

      test('throws ArgumentError for unknown value', () {
        expect(() => Effect.fromString('maybe'), throwsArgumentError);
      });
    });

    group('toJson', () {
      test('serialises to lowercase name', () {
        expect(Effect.allow.toJson(), equals('allow'));
        expect(Effect.deny.toJson(), equals('deny'));
      });

      test('round-trip: fromString(toJson()) == original', () {
        for (final e in Effect.values) {
          expect(Effect.fromString(e.toJson()), equals(e));
        }
      });
    });
  });
}
