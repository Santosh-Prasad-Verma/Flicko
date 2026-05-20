import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;

  static const String _definedSupabaseUrl =
      String.fromEnvironment('FLICKO_SUPABASE_URL');
  static const String _definedSupabaseAnonKey =
      String.fromEnvironment('FLICKO_SUPABASE_ANON_KEY');
  static const String _definedLivekitUrl =
      String.fromEnvironment('FLICKO_LIVEKIT_URL');
  static const String _definedApiBaseUrl =
      String.fromEnvironment('FLICKO_API_URL');
  static const String _definedGiphyApiKey =
      String.fromEnvironment('FLICKO_GIPHY_API_KEY');
  static const String _definedAppwriteProjectId =
      String.fromEnvironment('FLICKO_APPWRITE_PROJECT_ID');
  static const String _definedAppwriteProjectName =
      String.fromEnvironment('FLICKO_APPWRITE_PROJECT_NAME');
  static const String _definedAppwritePublicEndpoint =
      String.fromEnvironment('FLICKO_APPWRITE_PUBLIC_ENDPOINT');
  static const String _definedAppwriteBucketId =
      String.fromEnvironment('FLICKO_APPWRITE_BUCKET_ID');
  static const String _definedRazorpayKeyId =
      String.fromEnvironment('FLICKO_RAZORPAY_KEY_ID');
  static const String _definedGoogleClientId =
      String.fromEnvironment('FLICKO_GOOGLE_CLIENT_ID');

  static const String _definedLegacySupabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _definedLegacySupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _definedLegacyLivekitUrl =
      String.fromEnvironment('LIVEKIT_URL');
  static const String _definedLegacyApiBaseUrl =
      String.fromEnvironment('API_BASE_URL');
  static const String _definedLegacyGiphyApiKey =
      String.fromEnvironment('GIPHY_API_KEY');
  static const String _definedLegacyAppwriteProjectId =
      String.fromEnvironment('APPWRITE_PROJECT_ID');
  static const String _definedLegacyAppwriteProjectName =
      String.fromEnvironment('APPWRITE_PROJECT_NAME');
  static const String _definedLegacyAppwritePublicEndpoint =
      String.fromEnvironment('APPWRITE_PUBLIC_ENDPOINT');
  static const String _definedLegacyAppwriteBucketId =
      String.fromEnvironment('APPWRITE_BUCKET_ID');
  static const String _definedLegacyRazorpayKeyId =
      String.fromEnvironment('RAZORPAY_KEY_ID');
  static const String _definedLegacyGoogleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID');

  static late final String supabaseUrl;
  static late final String supabaseAnonKey;
  static late final String livekitUrl;
  static late final String apiBaseUrl;
  static late final String giphyApiKey;

  // Appwrite
  static late final String appwriteProjectId;
  static late final String appwriteProjectName;
  static late final String appwritePublicEndpoint;
  static late final String appwriteBucketId;
  static late final String razorpayKeyId;
  static late final String googleClientId;

  static void init() {
    supabaseUrl = _read(
      _definedSupabaseUrl,
      _definedLegacySupabaseUrl,
      'FLICKO_SUPABASE_URL',
      'SUPABASE_URL',
    );
    supabaseAnonKey = _read(
      _definedSupabaseAnonKey,
      _definedLegacySupabaseAnonKey,
      'FLICKO_SUPABASE_ANON_KEY',
      'SUPABASE_ANON_KEY',
    );
    livekitUrl = _read(
      _definedLivekitUrl,
      _definedLegacyLivekitUrl,
      'FLICKO_LIVEKIT_URL',
      'LIVEKIT_URL',
    );
    apiBaseUrl = _normalizeBaseUrl(
      _read(
        _definedApiBaseUrl,
        _definedLegacyApiBaseUrl,
        'FLICKO_API_URL',
        'API_BASE_URL',
      ),
    );
    giphyApiKey = _read(
      _definedGiphyApiKey,
      _definedLegacyGiphyApiKey,
      'FLICKO_GIPHY_API_KEY',
      'GIPHY_API_KEY',
    );

    appwriteProjectId = _read(
      _definedAppwriteProjectId,
      _definedLegacyAppwriteProjectId,
      'FLICKO_APPWRITE_PROJECT_ID',
      'APPWRITE_PROJECT_ID',
    );
    appwriteProjectName = _read(
      _definedAppwriteProjectName,
      _definedLegacyAppwriteProjectName,
      'FLICKO_APPWRITE_PROJECT_NAME',
      'APPWRITE_PROJECT_NAME',
    );
    appwritePublicEndpoint = _read(
      _definedAppwritePublicEndpoint,
      _definedLegacyAppwritePublicEndpoint,
      'FLICKO_APPWRITE_PUBLIC_ENDPOINT',
      'APPWRITE_PUBLIC_ENDPOINT',
    );
    appwriteBucketId = _read(
      _definedAppwriteBucketId,
      _definedLegacyAppwriteBucketId,
      'FLICKO_APPWRITE_BUCKET_ID',
      'APPWRITE_BUCKET_ID',
    );
    razorpayKeyId = _read(
      _definedRazorpayKeyId,
      _definedLegacyRazorpayKeyId,
      'FLICKO_RAZORPAY_KEY_ID',
      'RAZORPAY_KEY_ID',
    );
    googleClientId = _read(
      _definedGoogleClientId,
      _definedLegacyGoogleClientId,
      'FLICKO_GOOGLE_CLIENT_ID',
      'GOOGLE_CLIENT_ID',
    );
  }

  static List<String> get missingStartupConfig {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) {
      missing.add('FLICKO_SUPABASE_URL or SUPABASE_URL');
    }
    if (supabaseAnonKey.isEmpty) {
      missing.add('FLICKO_SUPABASE_ANON_KEY or SUPABASE_ANON_KEY');
    }
    return missing;
  }

  static bool get hasApiBaseUrl => apiBaseUrl.isNotEmpty;

  static void requireBackendBaseUrl() {
    if (!hasApiBaseUrl) {
      throw const BackendConfigurationException();
    }
  }

  static String _read(
    String definedValue,
    String legacyDefinedValue,
    String envKey,
    String legacyEnvKey,
  ) {
    return _firstNonEmpty([
      definedValue,
      legacyDefinedValue,
      dotenv.env[envKey],
      dotenv.env[legacyEnvKey],
    ]);
  }

  static String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

class BackendConfigurationException implements Exception {
  const BackendConfigurationException();

  String get message =>
      'Backend URL is not configured. Set FLICKO_API_URL or API_BASE_URL to your backend URL, for example http://<your-computer-lan-ip>:8090 when running on a physical phone.';

  @override
  String toString() => message;
}
