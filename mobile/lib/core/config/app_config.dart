import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;

  static const String _definedApiBaseUrl = String.fromEnvironment(
    'FLICKO_API_URL',
  );
  static const String _definedGiphyApiKey = String.fromEnvironment(
    'FLICKO_GIPHY_API_KEY',
  );
  static const String _definedAppwriteProjectId = String.fromEnvironment(
    'FLICKO_APPWRITE_PROJECT_ID',
  );
  static const String _definedAppwriteProjectName = String.fromEnvironment(
    'FLICKO_APPWRITE_PROJECT_NAME',
  );
  static const String _definedAppwritePublicEndpoint = String.fromEnvironment(
    'FLICKO_APPWRITE_PUBLIC_ENDPOINT',
  );
  static const String _definedAppwriteBucketId = String.fromEnvironment(
    'FLICKO_APPWRITE_BUCKET_ID',
  );
  static const String _definedRazorpayKeyId = String.fromEnvironment(
    'FLICKO_RAZORPAY_KEY_ID',
  );
  static const String _definedGoogleClientId = String.fromEnvironment(
    'FLICKO_GOOGLE_CLIENT_ID',
  );
  static const String _definedSentryDsn = String.fromEnvironment(
    'FLICKO_SENTRY_DSN',
  );
  static const String _definedGeminiApiKey = String.fromEnvironment(
    'FLICKO_GEMINI_API_KEY',
  );
  static const String _definedDeepgramApiKey = String.fromEnvironment(
    'FLICKO_DEEPGRAM_API_KEY',
  );
  static const String _definedTavilyApiKey = String.fromEnvironment(
    'FLICKO_TAVILY_API_KEY',
  );
  static const String _definedSerperApiKey = String.fromEnvironment(
    'FLICKO_SERPER_API_KEY',
  );
  static const String _definedGeminiTextModel = String.fromEnvironment(
    'FLICKO_GEMINI_TEXT_MODEL',
  );
  static const String _definedGeminiLiveModel = String.fromEnvironment(
    'FLICKO_GEMINI_LIVE_MODEL',
  );
  static const String _definedRtcStunUrls = String.fromEnvironment(
    'FLICKO_RTC_STUN_URLS',
  );
  static const String _definedRtcTurnUrl = String.fromEnvironment(
    'FLICKO_RTC_TURN_URL',
  );
  static const String _definedRtcTurnUsername = String.fromEnvironment(
    'FLICKO_RTC_TURN_USERNAME',
  );
  static const String _definedRtcTurnCredential = String.fromEnvironment(
    'FLICKO_RTC_TURN_CREDENTIAL',
  );
  static const String _definedCurrentsApiKey = String.fromEnvironment(
    'FLICKO_CURRENTS_API_KEY',
  );

  static const String _definedLegacyApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _definedLegacyGiphyApiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
  );
  static const String _definedLegacyAppwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
  );
  static const String _definedLegacyAppwriteProjectName =
      String.fromEnvironment('APPWRITE_PROJECT_NAME');
  static const String _definedLegacyAppwritePublicEndpoint =
      String.fromEnvironment('APPWRITE_PUBLIC_ENDPOINT');
  static const String _definedLegacyAppwriteBucketId = String.fromEnvironment(
    'APPWRITE_BUCKET_ID',
  );
  static const String _definedLegacyRazorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
  );
  static const String _definedLegacyGoogleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );
  static const String _definedLegacySentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
  );
  static const String _definedLegacyGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );
  static const String _definedLegacyDeepgramApiKey = String.fromEnvironment(
    'DEEPGRAM_API_KEY',
  );
  static const String _definedLegacyTavilyApiKey = String.fromEnvironment(
    'TAVILY_API_KEY',
  );
  static const String _definedLegacySerperApiKey = String.fromEnvironment(
    'SERPER_API_KEY',
  );
  static const String _definedLegacyGeminiTextModel = String.fromEnvironment(
    'GEMINI_TEXT_MODEL',
  );
  static const String _definedLegacyGeminiLiveModel = String.fromEnvironment(
    'GEMINI_LIVE_MODEL',
  );
  static const String _definedLegacyRtcStunUrls = String.fromEnvironment(
    'RTC_STUN_URLS',
  );
  static const String _definedLegacyRtcTurnUrl = String.fromEnvironment(
    'RTC_TURN_URL',
  );
  static const String _definedLegacyRtcTurnUsername = String.fromEnvironment(
    'RTC_TURN_USERNAME',
  );
  static const String _definedLegacyRtcTurnCredential = String.fromEnvironment(
    'RTC_TURN_CREDENTIAL',
  );
  static const String _definedLegacyCurrentsApiKey = String.fromEnvironment(
    'CURRENTS_API_KEY',
  );

  /// Centrifugo websocket endpoint used by realtime gaming (Ludo board sync).
  /// Expected form: `wss://host/connection/websocket`.
  static const String _definedCentrifugoUrl = String.fromEnvironment(
    'FLICKO_CENTRIFUGO_URL',
  );
  static const String _definedLegacyCentrifugoUrl = String.fromEnvironment(
    'CENTRIFUGO_URL',
  );

  static late final String realtimeWsUrl;
  static late final String apiBaseUrl;
  static late final String giphyApiKey;

  // Appwrite
  static late final String appwriteProjectId;
  static late final String appwriteProjectName;
  static late final String appwritePublicEndpoint;
  static late final String appwriteBucketId;
  static late final String razorpayKeyId;
  static late final String googleClientId;
  static late final String sentryDsn;
  static late final String geminiApiKey;
  static late final String deepgramApiKey;
  static late final String tavilyApiKey;
  static late final String serperApiKey;
  static late final String geminiTextModel;
  static late final String geminiLiveModel;
  static late final String rtcStunUrls;
  static late final String rtcTurnUrl;
  static late final String rtcTurnUsername;
  static late final String rtcTurnCredential;
  static late final String currentsApiKey;

  /// Centrifugo websocket URL for realtime gaming. Empty when unconfigured —
  /// callers must check [hasCentrifugoUrl] and degrade to offline/local play
  /// rather than dialing a hardcoded host.
  static late final String centrifugoUrl;

  static void init() {
    apiBaseUrl = _normalizeBaseUrl(
      _read(
        _definedApiBaseUrl,
        _definedLegacyApiBaseUrl,
        'FLICKO_API_URL',
        'API_BASE_URL',
      ),
    );

    if (apiBaseUrl.isNotEmpty) {
      final host = apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final wsHost = host.startsWith('https://')
          ? host.replaceFirst('https://', 'wss://')
          : host.replaceFirst('http://', 'wss://');
      realtimeWsUrl = '$wsHost/ws';
    } else {
      realtimeWsUrl = 'wss://localhost:8080/ws';
    }
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
    sentryDsn = _read(
      _definedSentryDsn,
      _definedLegacySentryDsn,
      'FLICKO_SENTRY_DSN',
      'SENTRY_DSN',
    );
    geminiApiKey = _read(
      _definedGeminiApiKey,
      _definedLegacyGeminiApiKey,
      'FLICKO_OPENROUTER_API_KEY',
      'OPENROUTER_API_KEY',
    );
    if (geminiApiKey.isEmpty) {
      geminiApiKey = _read(
        _definedGeminiApiKey,
        _definedLegacyGeminiApiKey,
        'FLICKO_GEMINI_API_KEY',
        'GEMINI_API_KEY',
      );
    }
    deepgramApiKey = _firstNonEmpty([
      _definedDeepgramApiKey,
      _definedLegacyDeepgramApiKey,
      dotenv.env['FLICKO_DEEPGRAM_API_KEY'],
      dotenv.env['DEEPGRAM_API_KEY'],
      '1fa6f8e6e73afa1b071df94b77450c216f2e4c6d',
    ]);
    tavilyApiKey = _firstNonEmpty([
      _definedTavilyApiKey,
      _definedLegacyTavilyApiKey,
      dotenv.env['FLICKO_TAVILY_API_KEY'],
      dotenv.env['TAVILY_API_KEY'],
      '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',
    ]);
    serperApiKey = _firstNonEmpty([
      _definedSerperApiKey,
      _definedLegacySerperApiKey,
      dotenv.env['FLICKO_SERPER_API_KEY'],
      dotenv.env['SERPER_API_KEY'],
      '049f558ea6932c85ab7dcb3a30f6fdefd719a2f3',
    ]);
    geminiTextModel = _firstNonEmpty([
      _definedGeminiTextModel,
      _definedLegacyGeminiTextModel,
      dotenv.env['OPENROUTER_MODEL'],
      dotenv.env['FLICKO_OPENROUTER_MODEL'],
      dotenv.env['FLICKO_GEMINI_TEXT_MODEL'],
      dotenv.env['GEMINI_TEXT_MODEL'],
      'nvidia/nemotron-3-ultra-550b-a55b:free',
    ]);
    geminiLiveModel = _firstNonEmpty([
      _definedGeminiLiveModel,
      _definedLegacyGeminiLiveModel,
      dotenv.env['OPENROUTER_MODEL'],
      dotenv.env['FLICKO_OPENROUTER_MODEL'],
      dotenv.env['FLICKO_GEMINI_LIVE_MODEL'],
      dotenv.env['GEMINI_LIVE_MODEL'],
      'nvidia/nemotron-3-ultra-550b-a55b:free',
    ]);
    rtcStunUrls = _firstNonEmpty([
      _definedRtcStunUrls,
      _definedLegacyRtcStunUrls,
      dotenv.env['FLICKO_RTC_STUN_URLS'],
      dotenv.env['RTC_STUN_URLS'],
      'stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302',
    ]);
    rtcTurnUrl = _read(
      _definedRtcTurnUrl,
      _definedLegacyRtcTurnUrl,
      'FLICKO_RTC_TURN_URL',
      'RTC_TURN_URL',
    );
    rtcTurnUsername = _read(
      _definedRtcTurnUsername,
      _definedLegacyRtcTurnUsername,
      'FLICKO_RTC_TURN_USERNAME',
      'RTC_TURN_USERNAME',
    );
    rtcTurnCredential = _read(
      _definedRtcTurnCredential,
      _definedLegacyRtcTurnCredential,
      'FLICKO_RTC_TURN_CREDENTIAL',
      'RTC_TURN_CREDENTIAL',
    );
    currentsApiKey = _read(
      _definedCurrentsApiKey,
      _definedLegacyCurrentsApiKey,
      'FLICKO_CURRENTS_API_KEY',
      'CURRENTS_API_KEY',
    );
    centrifugoUrl = _normalizeCentrifugoUrl(
      _read(
        _definedCentrifugoUrl,
        _definedLegacyCentrifugoUrl,
        'FLICKO_CENTRIFUGO_URL',
        'CENTRIFUGO_URL',
      ),
    );
  }

  static List<String> get missingStartupConfig {
    final missing = <String>[];
    if (apiBaseUrl.isEmpty) {
      missing.add('FLICKO_API_URL or API_BASE_URL');
    }
    return missing;
  }

  static bool get hasApiBaseUrl => apiBaseUrl.isNotEmpty;

  static bool get hasCentrifugoUrl => centrifugoUrl.isNotEmpty;

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
    var trimmed = value.trim();
    if (trimmed.isEmpty) return 'https://flicko.dev/api/v1';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      if (trimmed.startsWith('/')) {
        trimmed = 'https://flicko.dev$trimmed';
      } else {
        trimmed = 'https://$trimmed';
      }
    }
    if (trimmed.startsWith('http://flicko.') || trimmed.startsWith('http://api.flicko.')) {
      trimmed = trimmed.replaceFirst('http://', 'https://');
    }
    var url = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    if (!url.endsWith('/api/v1') && !url.contains('/api/v1')) {
      url = '$url/api/v1';
    }
    return url;
  }

  /// Coerces a configured Centrifugo value into a websocket URL.
  ///
  /// Accepts an http(s) origin, a ws(s) origin, or a full endpoint, so the
  /// deploy can set `CENTRIFUGO_URL=https://rt.flicko.dev` and still get
  /// `wss://rt.flicko.dev/connection/websocket`. Returns '' when unset so
  /// callers can detect "not configured" instead of dialing a bad host.
  static String _normalizeCentrifugoUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) return '';

    if (url.startsWith('https://')) {
      url = url.replaceFirst('https://', 'wss://');
    } else if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'wss://');
    } else if (!url.startsWith('wss://')) {
      url = 'wss://${url.replaceFirst(RegExp(r'^wss?:\/\/'), '')}';
    }

    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/connection/websocket')) {
      url = '$url/connection/websocket';
    }
    return url;
  }
}

class BackendConfigurationException implements Exception {
  const BackendConfigurationException();

  String get message =>
      'Backend URL is not configured. Set FLICKO_API_URL or API_BASE_URL to your backend URL, for example http://<your-computer-lan-ip>:8090 when running on a physical phone.';

  @override
  String toString() => message;
}
