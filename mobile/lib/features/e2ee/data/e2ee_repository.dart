import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/data/clients/dio_client.dart';
import '../domain/e2ee_models.dart';

/// HTTP client for the Go backend's `/e2ee/*` endpoints.
/// Only public-key material flows through here.
class E2EERepository {
  final Dio _dio;
  E2EERepository(this._dio);

  Map<String, dynamic> _parseMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return {};
  }

  // ── Identity ────────────────────────────────────────────────────────────

  Future<void> uploadIdentity({
    required String deviceId,
    required String identityPub,
    required String signingPub,
    required String fingerprint,
  }) async {
    await _dio.put('/e2ee/identity', data: {
      'device_id': deviceId,
      'identity_pub': identityPub,
      'signing_pub': signingPub,
      'fingerprint': fingerprint,
    });
  }

  Future<IdentityKey?> fetchIdentity(String userId, {String? deviceId}) async {
    try {
      final res = await _dio.get('/e2ee/identity/$userId',
          queryParameters: deviceId != null ? {'device_id': deviceId} : null);
      final map = _parseMap(res.data);
      if (map.isEmpty) return null;
      return IdentityKey.fromJson(map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Fetch all devices owned by [userId]. Used by senders to fan-out a
  /// message so every device the recipient owns can decrypt.
  Future<List<IdentityKey>> fetchDevices(String userId) async {
    try {
      final res = await _dio.get('/e2ee/devices/$userId');
      final map = _parseMap(res.data);
      final list = (map['devices'] as List? ?? []);
      return list
          .map((e) => IdentityKey.fromJson(_parseMap(e)))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  // ── Identity attestations ───────────────────────────────────────────────

  /// Fetch the most-recent rotation attestation for ([userId], [newPub]).
  /// Returns null when none has been published. Caller verifies the
  /// signature against the OLD signing key they already pinned.
  Future<RemoteIdentityAttestation?> fetchAttestation({
    required String userId,
    required String newIdentityPub,
  }) async {
    try {
      final res = await _dio.get(
        '/e2ee/identity/attestation/$userId',
        queryParameters: {'new_pub': newIdentityPub},
      );
      final map = _parseMap(res.data);
      if (map.isEmpty) return null;
      return RemoteIdentityAttestation.fromJson(map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Publish an attestation that we (the authenticated user) are rotating
  /// from [oldIdentityPub] to [newIdentityPub], signed by our old signing
  /// private key.
  Future<void> publishAttestation({
    required String oldIdentityPub,
    required String newIdentityPub,
    required String signatureB64,
  }) async {
    await _dio.post('/e2ee/identity/attestation', data: {
      'old_identity_pub': oldIdentityPub,
      'new_identity_pub': newIdentityPub,
      'signature': signatureB64,
    });
  }

  // ── Signed prekey ───────────────────────────────────────────────────────

  Future<void> uploadSignedPrekey({
    required String deviceId,
    required int keyId,
    required String publicKey,
    required String signature,
  }) async {
    await _dio.put('/e2ee/signed-prekey', data: {
      'device_id': deviceId,
      'key_id': keyId,
      'public_key': publicKey,
      'signature': signature,
    });
  }

  // ── One-time prekeys ────────────────────────────────────────────────────

  Future<int> uploadOneTimePrekeys({
    required String deviceId,
    required List<OneTimePrekey> prekeys,
  }) async {
    final res = await _dio.put('/e2ee/one-time-prekeys', data: {
      'device_id': deviceId,
      'prekeys': prekeys.map((p) => p.toJson()).toList(),
    });
    return (_parseMap(res.data)['remaining'] as num?)?.toInt() ?? 0;
  }

  Future<({int count, bool low})> getOneTimePrekeyCount(String deviceId) async {
    try {
      final res = await _dio.get(
        '/e2ee/one-time-prekeys/count',
        queryParameters: {'device_id': deviceId},
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          extra: {'no_retry': true},
        ),
      );
      final m = _parseMap(res.data);
      return (
        count: (m['count'] as num?)?.toInt() ?? 0,
        low: m['low'] == true,
      );
    } catch (_) {
      return (count: 25, low: false);
    }
  }

  // ── Bundle ──────────────────────────────────────────────────────────────

  Future<PrekeyBundle?> fetchBundle(String userId, {String? deviceId}) async {
    try {
      final res = await _dio.get('/e2ee/bundle/$userId',
          queryParameters: deviceId != null ? {'device_id': deviceId} : null);
      final map = _parseMap(res.data);
      if (map.isEmpty) return null;
      return PrekeyBundle.fromJson(map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    } catch (_) {
      return null;
    }
  }

  // ── Conversation state ──────────────────────────────────────────────────

  Future<void> enableConversation(String otherUserId) async {
    await _dio.post('/e2ee/conversations/$otherUserId/enable');
  }

  Future<bool> isConversationEnabled(String otherUserId) async {
    try {
      final res = await _dio.get('/e2ee/conversations/$otherUserId/state');
      return _parseMap(res.data)['enabled'] == true;
    } on DioException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}

final e2eeRepositoryProvider = Provider<E2EERepository>((ref) {
  return E2EERepository(ref.watch(dioProvider));
});
