import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/errors/flicko_api_exception.dart';
import 'package:mobile/core/services/app_logger.dart';

/// Provides a global implementation of Dio for external API calls.
///
/// Pre-configured with:
///   - Backend base URL from [AppConfig.apiBaseUrl]
///   - JSON content-type header
///   - Reasonable timeouts
///   - Automatic retry for transient errors
///   - Automatic error transformation to [FlickoApiException]
///   - Client-side GET response caching
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl.endsWith('/')
          ? AppConfig.apiBaseUrl
          : '${AppConfig.apiBaseUrl}/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // 1. Auth interceptor to inject Supabase JWT
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_requiresBackendBaseUrl(options)) {
          if (!AppConfig.hasApiBaseUrl) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: const BackendConfigurationException(),
              ),
            );
          }
          // Strip leading slash from path to prevent replacing baseUrl's subpath
          if (options.path.startsWith('/')) {
            options.path = options.path.substring(1);
          }
        }

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        return handler.next(options);
      },
    ),
  );

  // 2. Client-side response cache interceptor
  dio.interceptors.add(_ClientCacheInterceptor());

  // 3. Automatic retry interceptor for network timeouts & 5xx server errors
  dio.interceptors.add(_RetryInterceptor(dio: dio, maxRetries: 3));

  // 4. Error mapping interceptor
  dio.interceptors.add(_ErrorMappingInterceptor());

  // 5. Logging interceptor for debug builds
  if (AppConfig.isDebug) {
    dio.interceptors.add(_DioLogInterceptor());
  }

  return dio;
});

bool _requiresBackendBaseUrl(RequestOptions options) {
  final uri = Uri.tryParse(options.path);
  return !(uri?.hasScheme ?? false);
}

/// In-memory LRU GET response cache
class _ClientCacheInterceptor extends Interceptor {
  static const int _maxCacheSize = 100;
  final Map<String, _CacheEntry> _cache = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() != 'GET') {
      return handler.next(options);
    }

    // Check no-cache request header
    if (options.headers['Cache-Control'] == 'no-cache') {
      return handler.next(options);
    }

    final key = options.uri.toString();
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      options.headers['If-None-Match'] = entry.eTag;
      return handler.resolve(
        Response(
          requestOptions: options,
          data: entry.data,
          statusCode: 304,
          statusMessage: 'Not Modified (Cached)',
        ),
      );
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method.toUpperCase() == 'GET' &&
        response.statusCode == 200 &&
        response.data != null) {
      final eTag = response.headers.value('etag') ?? '';
      final cacheControl = response.headers.value('cache-control') ?? '';

      // Parse max-age if present, default to 30 seconds
      int maxAgeSeconds = 30;
      if (cacheControl.contains('max-age=')) {
        final match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
        if (match != null) {
          maxAgeSeconds = int.tryParse(match.group(1) ?? '30') ?? 30;
        }
      }

      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }

      _cache[response.requestOptions.uri.toString()] = _CacheEntry(
        data: response.data,
        eTag: eTag,
        expiry: DateTime.now().add(Duration(seconds: maxAgeSeconds)),
      );
    }

    handler.next(response);
  }
}

class _CacheEntry {
  final dynamic data;
  final String eTag;
  final DateTime expiry;

  _CacheEntry({required this.data, required this.eTag, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Automatic retry interceptor with exponential backoff for transient failures
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  _RetryInterceptor({required this.dio, this.maxRetries = 3});

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra = err.requestOptions.extra;
    final retries = (extra['retry_count'] as int?) ?? 0;

    if (_shouldRetry(err) && retries < maxRetries) {
      extra['retry_count'] = retries + 1;
      final delay = Duration(milliseconds: 500 * (1 << retries));
      AppLogger.debug('Retrying request ${err.requestOptions.path} (attempt ${retries + 1}/$maxRetries) after ${delay.inMilliseconds}ms');

      await Future.delayed(delay);

      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (retryErr) {
        if (retryErr is DioException) {
          return handler.next(retryErr);
        }
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.extra['no_retry'] == true) return false;
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.error is SocketException) ||
        (err.response != null && err.response!.statusCode != null && err.response!.statusCode! >= 500);
  }
}

/// Maps DioException to typed [FlickoApiException]
class _ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.response?.headers.value('x-request-id');
    final statusCode = err.response?.statusCode;

    FlickoApiException apiException;

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      apiException = FlickoApiException.timeout(requestId: requestId);
    } else if (err.type == DioExceptionType.connectionError ||
        err.error is SocketException ||
        err.error is HttpException ||
        err.error is HandshakeException ||
        (statusCode == null && err.response == null)) {
      apiException = FlickoApiException.noConnection(requestId: requestId);
    } else if (statusCode == 401) {
      apiException = FlickoApiException.unauthorized(requestId: requestId);
    } else if (statusCode == 403) {
      apiException = FlickoApiException.forbidden(requestId: requestId);
    } else if (statusCode == 404) {
      apiException = FlickoApiException.notFound(requestId: requestId);
    } else if (statusCode == 429) {
      final retryAfterHeader = err.response?.headers.value('retry-after');
      final retrySeconds = int.tryParse(retryAfterHeader ?? '5') ?? 5;
      apiException = FlickoApiException.rateLimited(Duration(seconds: retrySeconds), requestId: requestId);
    } else if (statusCode != null && statusCode >= 500) {
      final msg = _extractErrorMessage(err.response?.data) ?? 'Server error ($statusCode). Please try again later.';
      apiException = FlickoApiException.serverError(msg, requestId: requestId, statusCode: statusCode);
    } else if (statusCode == 400 && err.response?.data is Map) {
      final map = err.response!.data as Map;
      if (map.containsKey('error') && map['error'] is Map) {
        final errObj = map['error'] as Map;
        apiException = FlickoApiException.serverError(errObj['message']?.toString() ?? 'Bad request', requestId: requestId, statusCode: 400);
      } else {
        apiException = FlickoApiException.serverError(_extractErrorMessage(err.response?.data) ?? 'Invalid request', requestId: requestId, statusCode: 400);
      }
    } else {
      apiException = FlickoApiException.serverError(
        _extractErrorMessage(err.response?.data) ?? err.message ?? 'An unexpected network error occurred',
        requestId: requestId,
        statusCode: statusCode ?? 500,
      );
    }

    // Wrap in modified DioException with FlickoApiException inside error
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,
        message: apiException.message,
      ),
    );
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      if (data['error'] is String) return data['error'];
      if (data['error'] is Map && data['error']['message'] is String) {
        return data['error']['message'];
      }
      if (data['message'] is String) return data['message'];
    }
    return null;
  }
}

class _DioLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Avoid double printing for prekey polling to keep log readable
    if (!options.path.contains('one-time-prekeys/count')) {
      print('🌐 [HTTP] ${options.method} -> ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!response.requestOptions.path.contains('one-time-prekeys/count')) {
      print('✅ [HTTP] ${response.statusCode} <- ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final extra = err.requestOptions.extra;
    final isSilent = extra['silent'] == true ||
        (extra['no_retry'] == true && (err.type == DioExceptionType.connectionError || err.response == null));

    if (!isSilent) {
      print('❌ [HTTP] ${err.response?.statusCode ?? 'unknown'} <- ${err.requestOptions.uri} | ${err.message}');
    }
    handler.next(err);
  }
}
