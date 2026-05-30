import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/data/clients/dio_client.dart';
import '../domain/e2ee_models.dart';

/// HTTP client for the Go backend's `/e2ee/*` endpoints.
/// Only public-key material flows through here.
class E2EERepository {
  final Dio _dio;
  E2EERepository(this._dio);

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
      return IdentityKey.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Fetch all devices owned by [userId]. Used by senders to fan-out a
  /// message so every device the recipient owns can decrypt.
  Future<List<IdentityKey>> fetchDevices(String userId) async {
    try {
      final res = await _dio.get('/e2ee/devices/$userId');
      final list = ((res.data as Map)['devices'] as List? ?? []);
      return list
          .map((e) => IdentityKey.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
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
      return RemoteIdentityAttestation.fromJson(
          (res.data as Map).cast<String, dynamic>());
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
    return ((res.data as Map)['remaining'] as num?)?.toInt() ?? 0;
  }

  Future<({int count, bool low})> getOneTimePrekeyCount(String deviceId) async {
    final res = await _dio
        .get('/e2ee/one-time-prekeys/count', queryParameters: {'device_id': deviceId});
    final m = (res.data as Map).cast<String, dynamic>();
    return (
      count: (m['count'] as num?)?.toInt() ?? 0,
      low: m['low'] == true,
    );
  }

  // ── Bundle ──────────────────────────────────────────────────────────────

  Future<PrekeyBundle?> fetchBundle(String userId, {String? deviceId}) async {
    try {
      final res = await _dio.get('/e2ee/bundle/$userId',
          queryParameters: deviceId != null ? {'device_id': deviceId} : null);
      return PrekeyBundle.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Conversation state ──────────────────────────────────────────────────

  Future<void> enableConversation(String otherUserId) async {
    await _dio.post('/e2ee/conversations/$otherUserId/enable');
  }

  Future<bool> isConversationEnabled(String otherUserId) async {
    try {
      final res = await _dio.get('/e2ee/conversations/$otherUserId/state');
      return (res.data as Map)['enabled'] == true;
    } on DioException catch (_) {
      return false;
    }
  }
}

final e2eeRepositoryProvider = Provider<E2EERepository>((ref) {
  return E2EERepository(ref.watch(dioProvider));
});
