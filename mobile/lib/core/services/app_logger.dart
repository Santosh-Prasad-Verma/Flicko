import 'package:logger/logger.dart';

class AppLogger {
  static final List<RegExp> _secretPatterns = [
    RegExp(
      r'(Authorization:\s*Bearer\s+)[^\s,}]+',
      caseSensitive: false,
    ),
    RegExp(
      r'(Bearer\s+)[A-Za-z0-9._~-]+',
      caseSensitive: false,
    ),
    RegExp(
      r'((?:Cookie|Set-Cookie):\s*)[^\n\r]+',
      caseSensitive: false,
    ),
    RegExp(
      r'((?:sp_dc|sp_key|sp_t|__Secure-TPASESSION|__Host-device_id)\s*[:=]\s*)[^,\s}]+',
      caseSensitive: false,
    ),
    RegExp(
      r'((?:access[_-]?token|refresh[_-]?token|id[_-]?token|api[_-]?key|anon[_-]?key|service[_-]?role[_-]?key)\s*[:=]\s*)[^,\s}]+',
      caseSensitive: false,
    ),
  ];

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static String redact(Object? value) {
    var message = value?.toString() ?? '';
    for (final pattern in _secretPatterns) {
      message = message.replaceAllMapped(pattern, (match) {
        final prefix = match.group(1) ?? '';
        return '$prefix<redacted>';
      });
    }
    return message;
  }

  static Object? _redactedObject(Object? value) {
    if (value == null) return null;
    return redact(value);
  }

  static void d(String message) => _logger.d(redact(message));
  static void debug(String message) => d(message);
  static void i(String message) => _logger.i(redact(message));
  static void w(String message) => _logger.w(redact(message));
  static void e(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(redact(message),
          error: _redactedObject(error), stackTrace: stackTrace);
  static void v(String message) => _logger.t(redact(message));
}
