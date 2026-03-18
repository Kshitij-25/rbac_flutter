/// Dio-backed remote policy source.
///
/// Architecture note: [HttpPolicyRemoteSource] depends on [RbacHttpClient],
/// a minimal single-method interface. This keeps the source testable without
/// requiring a full Dio mock (which has dozens of abstract methods).
///
/// In production, pass [DioRbacHttpClient(Dio())].
/// In tests, pass a [MockRbacHttpClient] via mocktail.
library;

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:rbac_flutter/src/data/models/policy_model.dart';
import 'package:rbac_flutter/src/domain/exceptions/rbac_failure.dart';

// ---------------------------------------------------------------------------
// Minimal HTTP client interface (testable seam)
// ---------------------------------------------------------------------------

abstract interface class RbacHttpClient {
  /// Performs a GET request and returns the decoded JSON body.
  /// Throws [DioException] on network / HTTP errors.
  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  });
}

/// Production implementation backed by [Dio].
class DioRbacHttpClient implements RbacHttpClient {
  DioRbacHttpClient(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final response = await _dio.get<dynamic>(
      url,
      options: Options(
        headers: headers,
        sendTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        responseType: ResponseType.json,
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: RequestOptions(path: url),
      message: 'Response body is not a JSON object: ${data.runtimeType}',
    );
  }
}

// ---------------------------------------------------------------------------
// PolicyRemoteSource contract
// ---------------------------------------------------------------------------

abstract interface class PolicyRemoteSource {
  Future<Either<RbacFailure, PolicyModel>> fetchPolicy();
}

// ---------------------------------------------------------------------------
// Concrete implementation
// ---------------------------------------------------------------------------

class HttpPolicyRemoteSource implements PolicyRemoteSource {
  HttpPolicyRemoteSource({
    required this.endpoint,
    required this.httpClient,
    this.headers = const {},
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 10),
  });

  final String endpoint;
  final RbacHttpClient httpClient;
  final Map<String, String> headers;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  @override
  Future<Either<RbacFailure, PolicyModel>> fetchPolicy() async {
    try {
      final json = await httpClient.get(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...headers,
        },
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
      );
      try {
        return Right(PolicyModel.fromJson(json));
      } catch (e) {
        return Left(
          PolicyParseFailure('Failed to parse policy JSON: $e'),
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        return Left(
          PolicyFetchFailure(
            'HTTP ${e.response?.statusCode}: ${e.message}',
            statusCode: e.response?.statusCode,
          ),
        );
      }
      return Left(
        UnexpectedFailure(
          'Network error fetching policy: ${e.message}',
          error: e,
          stackTrace: e.stackTrace,
        ),
      );
    } catch (e, st) {
      return Left(
        UnexpectedFailure(
          'Unexpected error: $e',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }
}
