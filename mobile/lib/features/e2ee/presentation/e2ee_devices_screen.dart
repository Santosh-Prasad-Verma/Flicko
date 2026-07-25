import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import '../application/e2ee_session.dart';
import '../data/e2ee_repository.dart';
import '../data/secure_keystore.dart';
import '../domain/e2ee_models.dart';
import '../domain/identity_verification.dart';

class E2EEDevicesScreen extends ConsumerStatefulWidget {
  const E2EEDevicesScreen({super.key});

  @override
  ConsumerState<E2EEDevicesScreen> createState() => _E2EEDevicesScreenState();
}

class _E2EEDevicesScreenState extends ConsumerState<E2EEDevicesScreen> {
  List<IdentityKey> _devices = [];
  String? _myDeviceId;
  Uint8List? _myIdentityPub;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = ref.read(e2eeSessionProvider);
      await session.ensureBootstrapped();

      final myDeviceId = await session.getMyDeviceId();
      final myIdentityPub = await ref.read(secureKeystoreProvider).loadIdentityPub();
      final myFp = await session.getMyFingerprint();

      final userId = ref.read(currentUserIdProvider) ?? 'guest_user';
      List<IdentityKey> devices = [];
      try {
        devices = await ref.read(e2eeRepositoryProvider).fetchDevices(userId);
      } catch (_) {}

      if (devices.isEmpty && myIdentityPub != null) {
        devices = [
          IdentityKey(
            userId: userId,
            deviceId: myDeviceId,
            identityPub: base64Encode(myIdentityPub),
            signingPub: '',
            fingerprint: myFp,
          ),
        ];
      }

      if (mounted) {
        setState(() {
          _devices = devices;
          _myDeviceId = myDeviceId;
          _myIdentityPub = myIdentityPub;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showVerificationDialog(IdentityKey device) async {
    if (_myIdentityPub == null) return;

    final remoteIdentityPubBytes = base64Decode(device.identityPub);
    final safetyNumber = await SafetyNumber.compute(
      localIdentityPub: _myIdentityPub!,
      remoteIdentityPub: remoteIdentityPubBytes,
    );
    final sasPhrase = await SasVerification.generate(
      localPub: _myIdentityPub!,
      remotePub: remoteIdentityPubBytes,
    );

    final formattedSafety = SafetyNumber.format(safetyNumber);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DEVICE VERIFICATION',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify this session out-of-band to confirm encryption integrity.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 24),
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: safetyNumber,
                  version: QrVersions.auto,
                  size: 180.0,
                  gapless: false,
                ),
              ),
              const SizedBox(height: 24),
              // Safety Number
              Text(
                'SAFETY NUMBER',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(FlickoColors.brandLime),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                formattedSafety,
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              // SAS Phrase
              Text(
                'VERBAL PHRASE (SAS)',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(FlickoColors.brandLime),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sasPhrase,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CLOSE',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.black),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.black),
        title: Text(
          'DEVICES',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Failed to load devices',
                          style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDevices,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _devices.isEmpty
                  ? Center(
                      child: Text(
                        'No E2EE sessions initialized.',
                        style: GoogleFonts.inter(color: Colors.white60),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isCurrent = device.deviceId == _myDeviceId;

                        return GestureDetector(
                          onTap: () => _showVerificationDialog(device),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(FlickoColors.bgSecondary),
                              border: Border.all(
                                color: isCurrent
                                    ? const Color(FlickoColors.brandLime).withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: isCurrent ? 1.5 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCurrent ? Icons.phone_android : Icons.devices,
                                  color: isCurrent
                                      ? const Color(FlickoColors.brandLime)
                                      : Colors.white60,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Device: ${device.deviceId.substring(0, (device.deviceId.length).clamp(0, 8))}',
                                              style: GoogleFonts.spaceGrotesk(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(FlickoColors.brandLime).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'THIS DEVICE',
                                                style: GoogleFonts.spaceGrotesk(
                                                  color: const Color(FlickoColors.brandLime),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Fingerprint: ${device.fingerprint.substring(0, (device.fingerprint.length).clamp(0, 16))}...',
                                        style: GoogleFonts.robotoMono(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.qr_code, color: Color(FlickoColors.brandLime)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
