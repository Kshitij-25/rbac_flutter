/// TDD tests for [HttpPolicyRemoteSource].
///
/// We test against [RbacHttpClient] — not Dio directly — because:
///   a) Mocking Dio's 20+ abstract methods is brittle and noisy.
///   b) [RbacHttpClient] is the real seam: it owns the Dio → Map conversion.
///   c) [DioRbacHttpClient] has its own minimal tests below.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rbac_flutter/src/data/sources/remote/policy_remote_source.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockRbacHttpClient extends Mock implements RbacHttpClient {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _endpoint = 'https://api.example.com/policies/active';

final _validPolicyJson = <String, dynamic>{
  'id': 'pol-001',
  'version': '1.0.0',
  'default_effect': 'deny',
  'role_permissions': {
    'admin': [
      {
        'action': 'read',
        'resource': 'dashboard',
        'effect': 'allow',
        'conditions': <String, dynamic>{},
      },
    ],
  },
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockRbacHttpClient mockClient;
  late HttpPolicyRemoteSource source;

  setUp(() {
    mockClient = MockRbacHttpClient();
    source = HttpPolicyRemoteSource(
      endpoint: _endpoint,
      httpClient: mockClient,
    );
  });

  group('HttpPolicyRemoteSource.fetchPolicy', () {
    test('returns Right(PolicyModel) on successful response', () async {
      when(
        () => mockClient.get(
          any(),
          headers: any(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).thenAnswer((_) async => _validPolicyJson);

      final result = await source.fetchPolicy();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (model) {
          expect(model.id, equals('pol-001'));
          expect(model.version, equals('1.0.0'));
          expect(model.rolePermissions.keys, contains('admin'));
        },
      );
    });

    test('returns PolicyParseFailure when JSON is missing required fields',
        () async {
      when(
        () => mockClient.get(
          any(),
          headers: any(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).thenAnswer((_) async => <String, dynamic>{'no_id': true});
      // 'id' and 'version' are required — fromJson will throw

      final result = await source.fetchPolicy();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<PolicyParseFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns PolicyFetchFailure on 401 DioException', () async {
      when(
        () => mockClient.get(
          any(),
          headers: any(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _endpoint),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: _endpoint),
          ),
          type: DioExceptionType.badResponse,
          message: 'Unauthorized',
        ),
      );

      final result = await source.fetchPolicy();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) {
          expect(f, isA<PolicyFetchFailure>());
          expect((f as PolicyFetchFailure).statusCode, equals(401));
        },
        (_) => fail('Expected Left'),
      );
    });

    test('returns PolicyFetchFailure on 500 DioException', () async {
      when(
        () => mockClient.get(
          any(),
          headers: any(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _endpoint),
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: _endpoint),
          ),
          type: DioExceptionType.badResponse,
          message: 'Server Error',
        ),
      );

      final result = await source.fetchPolicy();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect((f as PolicyFetchFailure).statusCode, equals(500)),
        (_) => fail('Expected Left'),
      );
    });

    test('returns UnexpectedFailure on connection timeout', () async {
      when(
        () => mockClient.get(
          any(),
          headers: any(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _endpoint),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
        ),
      );

      final result = await source.fetchPolicy();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns UnexpectedFailure on non-Dio exception', () async {
      when(
        () => mockClient.get(
          any(),
          headers: any(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).thenThrow(Exception('Unknown socket error'));

      final result = await source.fetchPolicy();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('merges custom headers with default headers', () async {
      final secureSource = HttpPolicyRemoteSource(
        endpoint: _endpoint,
        httpClient: mockClient,
        headers: {'Authorization': 'Bearer my-token'},
      );

      when(
        () => mockClient.get(
          any(),
          headers: any(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).thenAnswer((_) async => _validPolicyJson);

      await secureSource.fetchPolicy();

      final captured = verify(
        () => mockClient.get(
          any(),
          headers: captureAny(named: 'headers'),
          connectTimeout: any(named: 'connectTimeout'),
          receiveTimeout: any(named: 'receiveTimeout'),
        ),
      ).captured;

      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], equals('Bearer my-token'));
      expect(headers['Content-Type'], equals('application/json'));
    });
  });
}
