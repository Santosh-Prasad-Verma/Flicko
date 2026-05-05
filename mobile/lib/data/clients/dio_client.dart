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
      baseUrl: AppConfig.apiBaseUrl,
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
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => AppLogger.debug(obj.toString()),
      ),
    );
  }

  return dio;
});
