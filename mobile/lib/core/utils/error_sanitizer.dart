import 'dart:io';

/// Error Sanitizer
/// Converts raw system/database exceptions into clean, user-friendly strings.
/// Prevents internal file paths, Supabase URLs, and table schemas from leaking in the UI.
class ErrorSanitizer {
  static String sanitize(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';

    final str = error.toString();

    // Check for offline / network errors
    if (error is SocketException ||
        str.contains('SocketException') ||
        str.contains('ClientException') ||
        str.contains('Failed host lookup') ||
        str.contains('NetworkImage') ||
        str.contains('connection closed') ||
        str.contains('Connection refused')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Check for Supabase / Auth / Database errors
    if (str.contains('PostgrestException') || str.contains('AuthException')) {
      if (str.contains('Invalid login credentials')) {
        return 'Invalid email or password.';
      }
      if (str.contains('User already registered') || str.contains('already exists')) {
        return 'An account with this email already exists.';
      }
      return 'Database service temporarily unavailable. Please try again.';
    }

    // Generic fallback for any other system errors
    return 'Operation failed. Please try again.';
  }
}
