import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../../data/services/clerk_auth_service.dart';

/// Provider for a configured Dio instance.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl.isNotEmpty ? AppConfig.apiBaseUrl : 'http://localhost:8080',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Add interceptor to inject the Supabase auth token
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final clerk = ClerkAuthService.currentAuthState;
        if (clerk != null) {
          try {
            final sessionToken = await clerk.sessionToken();
            options.headers['Authorization'] = 'Bearer ${sessionToken.jwt}';
          } catch (_) {
            // Handle error or skip
          }
        }
        return handler.next(options);
      },
    ),
  );

  return dio;
});
