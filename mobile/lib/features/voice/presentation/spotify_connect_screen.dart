import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/config/app_config.dart';
import '../application/sonic_drip_notifier.dart';
import '../data/spotify_api_client.dart';
import '../domain/music_models.dart';

/// Spotify Connect Screen
///
/// Opens Spotify's login page in an embedded WebView.
/// The user enters their credentials and solves CAPTCHA themselves.
/// On successful login, we capture the session cookies and send them
/// to the backend — we NEVER store or see the password.
class SpotifyConnectScreen extends ConsumerStatefulWidget {
  const SpotifyConnectScreen({super.key});

  @override
  ConsumerState<SpotifyConnectScreen> createState() =>
      _SpotifyConnectScreenState();
}

class _SpotifyConnectScreenState extends ConsumerState<SpotifyConnectScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  static const _spotifyLoginUrl = 'https://accounts.spotify.com/en/login';
  static const _lime = Color(0xFFCBEF17);
  static const _black = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(_spotifyLoginUrl),
            ),
            initialSettings: InAppWebViewSettings(
              userAgent:
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
              javaScriptEnabled: true,
              domStorageEnabled: true,
              clearCache: true,
            ),
            onLoadStart: (_, __) => setState(() => _isLoading = true),
            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);
              await _handleNavigation(controller, url);
            },
            onReceivedError: (_, __, error) {
              setState(() {
                _isLoading = false;
                _error = 'Failed to load: ${error.description}';
              });
            },
          ),
          if (_isLoading || _isSaving) _buildOverlay(),
          if (_error != null) _buildErrorBanner(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        decoration: const BoxDecoration(
          color: _black,
          border: Border(bottom: BorderSide(color: _lime, width: 2.5)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _lime, width: 1.5),
                ),
                child: const Icon(Icons.close, color: _lime, size: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CONNECT SPOTIFY',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Login with your Spotify account',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Spotify logo indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF1DB954), width: 1.5),
              ),
              child: Text(
                'SPOTIFY',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF1DB954),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _lime),
            const SizedBox(height: 16),
            Text(
              _isSaving ? 'CONNECTING...' : 'LOADING...',
              style: GoogleFonts.robotoMono(
                color: _lime,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.red.withValues(alpha: 0.9),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _error = null),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// Called on every page navigation — detects successful Spotify login.
  Future<void> _handleNavigation(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (url == null) return;

    // Spotify redirects to open.spotify.com on successful login
    final isSuccess = url.host == 'open.spotify.com' ||
        url.host == 'accounts.spotify.com' && url.path.contains('status');

    if (!isSuccess) return;

    setState(() => _isSaving = true);

    try {
      // Extract session cookies
      final cookieManager = CookieManager.instance();
      final rawCookies = await cookieManager.getCookies(url: url);

      final cookies = <String, String>{
        for (final c in rawCookies) c.name: c.value,
      };

      if (cookies.isEmpty) {
        setState(() {
          _isSaving = false;
          _error = 'No session cookies found. Please try again.';
        });
        return;
      }

      // Get display name from page if possible
      final displayName = await _extractDisplayName(controller);

      // Save session locally first (works without backend)
      ref.read(sonicDripProvider.notifier).saveSession(
            SpotifySession(
              userId: 'me',
              displayName: displayName,
              status: ConnectionStatus.connected,
            ),
          );

      // Try to save to backend (optional — fails gracefully if not configured)
      try {
        await ref.read(spotifyApiClientProvider).saveSession(
              cookies: cookies,
              displayName: displayName,
            );
      } catch (_) {
        // Backend not configured — session saved locally only
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Spotify connected as $displayName',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF1DB954),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'Failed to capture session. Please try again.';
      });
    }
  }

  Future<String> _extractDisplayName(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source:
            "document.querySelector('[data-testid=\"user-widget-name\"]')?.textContent || ''",
      );
      if (result is String && result.isNotEmpty) return result;
    } catch (_) {}
    return 'Spotify User';
  }
}
