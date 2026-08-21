import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Streaming SSE client for `/api/v1/ai/summary/stream/<request_id>`.
///
/// Browsers and Dart's stock `dart:io` give you nothing for SSE, so we parse
/// the simple "event:" / "data:" framing ourselves over a streamed response.
/// The frame parser is buffered: we only emit a complete event when an empty
/// line terminates it.
///
/// The auth token is injected from FlutterSecureStorage, matching the
/// pattern used by `dioProvider`.
class SummarySseClient {
  SummarySseClient({required Uri baseUri, http.Client? httpClient})
      : _base = baseUri,
        _http = httpClient ?? http.Client();

  final Uri _base;
  final http.Client _http;
  final _storage = const FlutterSecureStorage();

  /// One parsed SSE frame.
  ///
  /// `event` defaults to `"message"` per spec when the server omits the field.
  Stream<SsePacket> stream(String requestId) async* {
    final token = await _storage.read(key: 'auth_token');
    final url = _base.resolve('ai/summary/stream/$requestId');

    final req = http.Request('GET', url);
    req.headers['Accept'] = 'text/event-stream';
    req.headers['Cache-Control'] = 'no-cache';
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _http.send(req);
    if (response.statusCode != 200) {
      throw SummarySseException(
        'sse: status ${response.statusCode}',
        response.statusCode,
      );
    }

    String currentEvent = 'message';
    final dataBuf = StringBuffer();

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) {
        // Empty line dispatches the buffered event.
        if (dataBuf.isNotEmpty) {
          final raw = dataBuf.toString();
          dataBuf.clear();
          Map<String, dynamic>? parsed;
          try {
            parsed = jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            // Backend always sends JSON; ignore malformed frames.
            currentEvent = 'message';
            continue;
          }
          yield SsePacket(event: currentEvent, data: parsed);
        }
        currentEvent = 'message';
        continue;
      }

      if (line.startsWith(':')) {
        // Comment / heartbeat; ignore.
        continue;
      }
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        // Per spec, multi-line data joins with '\n', but the backend emits
        // single-line JSON so this branch handles both.
        if (dataBuf.isNotEmpty) {
          dataBuf.write('\n');
        }
        dataBuf.write(line.substring(5).trim());
        continue;
      }
      // Unknown field — ignore.
    }
  }

  void close() => _http.close();
}

class SsePacket {
  final String event;
  final Map<String, dynamic> data;
  SsePacket({required this.event, required this.data});
}

class SummarySseException implements Exception {
  final String message;
  final int? statusCode;
  SummarySseException(this.message, [this.statusCode]);
  @override
  String toString() => 'SummarySseException: $message';
}
