import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/services/app_logger.dart';

/// Provides a global implementation of Dio for external API calls.
///
/// Pre-configured with:
///   - Backend base URL from [AppConfig.apiBaseUrl]
///   - JSON content-type header
///   - Reasonable timeouts
///
/// Add interceptors here for auth tokens, logging, and retry logic.
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

  // Add auth interceptor to inject Supabase JWT on each request
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

  // Add logging interceptor for debug builds
  if (AppConfig.isDebug) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => AppLogger.debug(obj.toString()),
      ),
    );
  }

  return dio;
});

bool _requiresBackendBaseUrl(RequestOptions options) {
  final uri = Uri.tryParse(options.path);
  return !(uri?.hasScheme ?? false);
}
