/// Tests for the [RbacFailure] sealed class hierarchy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rbac_ui_engine/src/domain/exceptions/rbac_failure.dart';

void main() {
  group('RbacFailure sealed hierarchy', () {
    test('PolicyFetchFailure carries message and statusCode', () {
      const f = PolicyFetchFailure('HTTP 401', statusCode: 401);
      expect(f.message, equals('HTTP 401'));
      expect(f.statusCode, equals(401));
      expect(f.toString(), contains('PolicyFetchFailure'));
    });

    test('PolicyParseFailure carries message and rawJson', () {
      const f = PolicyParseFailure('Bad JSON', rawJson: '{broken}');
      expect(f.rawJson, equals('{broken}'));
      expect(f, isA<RbacFailure>());
    });

    test('CacheFailure has message', () {
      const f = CacheFailure('Disk full');
      expect(f.message, equals('Disk full'));
    });

    test('RoleProviderFailure has message', () {
      const f = RoleProviderFailure('No auth token');
      expect(f, isA<RbacFailure>());
    });

    test('UnexpectedFailure carries original error', () {
      final error = Exception('unknown');
      final f = UnexpectedFailure('Unexpected', error: error);
      expect(f.error, equals(error));
    });

    test('sealed class exhaustive match compiles correctly', () {
      // This test verifies that all subtypes are covered in a switch.
      const RbacFailure failure = CacheFailure('test');
      final label = switch (failure) {
        PolicyFetchFailure() => 'fetch',
        PolicyParseFailure() => 'parse',
        CacheFailure() => 'cache',
        RoleProviderFailure() => 'role',
        EvaluationFailure() => 'eval',
        UnexpectedFailure() => 'unexpected',
      };
      expect(label, equals('cache'));
    });
  });
}
