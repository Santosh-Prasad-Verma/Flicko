import 'package:flutter/foundation.dart';

/// Typed API exception hierarchy for Flicko mobile app.
@immutable
sealed class FlickoApiException implements Exception {
  final String message;
  final String? requestId;
  final int? statusCode;

  const FlickoApiException(this.message, {this.requestId, this.statusCode});

  factory FlickoApiException.timeout({String? requestId}) = TimeoutApiException;

  factory FlickoApiException.noConnection({String? requestId}) = NoConnectionApiException;

  factory FlickoApiException.serverError(String message, {String? requestId, int? statusCode}) = ServerErrorApiException;

  factory FlickoApiException.unauthorized({String? requestId}) = UnauthorizedApiException;

  factory FlickoApiException.forbidden({String? requestId}) = ForbiddenApiException;

  factory FlickoApiException.notFound({String? requestId}) = NotFoundApiException;

  factory FlickoApiException.rateLimited(Duration retryAfter, {String? requestId}) = RateLimitedApiException;

  factory FlickoApiException.validation(Map<String, String> fieldErrors, {String? requestId}) = ValidationApiException;

  @override
  String toString() => 'FlickoApiException: $message (statusCode: $statusCode, requestId: $requestId)';
}

class TimeoutApiException extends FlickoApiException {
  const TimeoutApiException({super.requestId})
      : super(
          'Request timed out. Please check your internet connection and try again.',
          statusCode: 408,
        );
}

class NoConnectionApiException extends FlickoApiException {
  const NoConnectionApiException({super.requestId})
      : super(
          'No internet connection. Please check your network settings.',
          statusCode: 0,
        );
}

class ServerErrorApiException extends FlickoApiException {
  const ServerErrorApiException(
    super.message, {
    super.requestId,
    super.statusCode = 500,
  });
}

class UnauthorizedApiException extends FlickoApiException {
  const UnauthorizedApiException({super.requestId})
      : super(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
}

class ForbiddenApiException extends FlickoApiException {
  const ForbiddenApiException({super.requestId})
      : super(
          'You do not have permission to perform this action.',
          statusCode: 403,
        );
}

class NotFoundApiException extends FlickoApiException {
  const NotFoundApiException({super.requestId})
      : super(
          'The requested resource was not found.',
          statusCode: 404,
        );
}

class RateLimitedApiException extends FlickoApiException {
  final Duration retryAfter;

  RateLimitedApiException(this.retryAfter, {super.requestId})
      : super(
          'Too many requests. Please try again later.',
          statusCode: 429,
        );
}

class ValidationApiException extends FlickoApiException {
  final Map<String, String> fieldErrors;

  const ValidationApiException(this.fieldErrors, {super.requestId})
      : super(
          'Validation failed. Please check your input.',
          statusCode: 400,
        );
}
