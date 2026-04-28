class Env {
  // We use standard .env file handling. This can later be expanded
  // to toggle dev/staging/prod through Dart environment variables (--dart-define)
  static const String fileName = '.env';

  static bool get isDev => const bool.fromEnvironment('ENV_DEV', defaultValue: true);
  static bool get isProd => const bool.fromEnvironment('ENV_PROD', defaultValue: false);
}
