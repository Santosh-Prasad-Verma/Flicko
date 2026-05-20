import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/data/clients/dio_client.dart';

/// Snapshot of server-driven feature flags for the current user.
///
/// All v2 features are gated behind individual flags for safe,
/// data-preserving rollbacks (R16, design.md §11).
class E2EEFlags {
  /// Server allows v2 at all. If false, clients SHALL stay on v1 (R16.2).
  final bool v2Enabled;

  /// This specific user is in the rollout cohort.
  final bool v2ForUser;

  /// Double Ratchet enabled (Phase 1).
  final bool ratchetEnabled;

  /// X3DH session establishment (Phase 2).
  final bool x3dhEnabled;

  /// WAL-based crash-safe persistence (Phase 3).
  final bool walEnabled;

  /// Identity rotation & verification features (Phase 4).
  final bool verificationEnabled;

  /// Sealed sender envelopes (Phase 5).
  final bool sealedSenderEnabled;

  /// Multi-device sessions (Phase 6).
  final bool multiDeviceEnabled;

  /// Encrypted backup & recovery (Phase 7).
  final bool backupEnabled;

  /// Compliance escrow (Phase 8, org-only).
  final bool escrowEnabled;

  /// E2EE telemetry collection (Phase 10).
  final bool telemetryEnabled;

  const E2EEFlags({
    required this.v2Enabled,
    required this.v2ForUser,
    this.ratchetEnabled = false,
    this.x3dhEnabled = false,
    this.walEnabled = false,
    this.verificationEnabled = false,
    this.sealedSenderEnabled = false,
    this.multiDeviceEnabled = false,
    this.backupEnabled = false,
    this.escrowEnabled = false,
    this.telemetryEnabled = false,
  });

  /// Conservative default: everything OFF until the server confirms.
  static const E2EEFlags off = E2EEFlags(v2Enabled: false, v2ForUser: false);

  bool get useV2 => v2Enabled && v2ForUser;

  /// Whether a specific v2 sub-feature is active.
  bool get useRatchet => useV2 && ratchetEnabled;
  bool get useX3dh => useV2 && x3dhEnabled;
  bool get useWal => useV2 && walEnabled;
  bool get useVerification => useV2 && verificationEnabled;
  bool get useSealedSender => useV2 && sealedSenderEnabled;
  bool get useMultiDevice => useV2 && multiDeviceEnabled;
  bool get useBackup => useV2 && backupEnabled;
  bool get useEscrow => useV2 && escrowEnabled;
  bool get useTelemetry => useV2 && telemetryEnabled;
}

class FeatureFlagsRepository {
  final Dio _dio;
  FeatureFlagsRepository(this._dio);

  /// Fetches `/users/@me/config`. Returns [E2EEFlags.off] on any error so
  /// failures fall back to v1 silently.
  Future<E2EEFlags> fetch() async {
    try {
      final res = await _dio.get('/users/@me/config');
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
      return E2EEFlags(
        v2Enabled: data['e2ee_v2_enabled'] == true,
        v2ForUser: data['e2ee_v2_for_user'] == true,
        ratchetEnabled: data['e2ee_v2_ratchet'] == true,
        x3dhEnabled: data['e2ee_v2_x3dh'] == true,
        walEnabled: data['e2ee_v2_wal'] == true,
        verificationEnabled: data['e2ee_v2_verification'] == true,
        sealedSenderEnabled: data['e2ee_v2_sealed_sender'] == true,
        multiDeviceEnabled: data['e2ee_v2_multi_device'] == true,
        backupEnabled: data['e2ee_v2_backup'] == true,
        escrowEnabled: data['e2ee_v2_escrow'] == true,
        telemetryEnabled: data['e2ee_v2_telemetry'] == true,
      );
    } catch (_) {
      return E2EEFlags.off;
    }
  }
}

final featureFlagsRepositoryProvider = Provider<FeatureFlagsRepository>((ref) {
  return FeatureFlagsRepository(ref.watch(dioProvider));
});

/// Caches the latest fetched flags. Bootstraps to [E2EEFlags.off] and
/// updates when the auth notifier triggers a refresh.
class E2EEFlagsNotifier extends Notifier<E2EEFlags> {
  @override
  E2EEFlags build() => E2EEFlags.off;

  void update(E2EEFlags flags) => state = flags;
}

final e2eeFlagsProvider =
    NotifierProvider<E2EEFlagsNotifier, E2EEFlags>(E2EEFlagsNotifier.new);
