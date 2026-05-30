import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

/// Listens for inbound deep links and forwards Ludo-related URIs to the
/// GoRouter so taps from share sheets / SMS / browser drop the user straight
/// into the right screen.
///
/// Supported schemes:
///   * `flicko://ludo/play?gameId=<id>`              (custom scheme)
///   * `https://flicko.app/ludo/play?gameId=<id>`    (universal / app link)
///   * `https://flicko.app/ludo`                     (lobby)
///   * `https://flicko.app/ludo/leaderboard`         (leaderboard)
///
/// Anything outside the `/ludo` path is passed through verbatim so other
/// features can extend the same handler.
class LudoDeepLinks {
  LudoDeepLinks(this._router);

  final GoRouter _router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// Begins listening. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 1. Cold-start link (app was launched by tapping the URI).
    try {
      final initial = await _appLinks.getInitialAppLink();
      if (initial != null) _route(initial);
    } catch (_) {
      // ignore: app_links can throw on first launch / unsupported platforms.
    }

    // 2. Subsequent links while the app is running.
    _sub = _appLinks.uriLinkStream.listen(
      _route,
      onError: (_) {/* swallow: deep links must never crash the app */},
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }

  void _route(Uri uri) {
    // Normalise to a path + query string the router understands.
    if (!_isLudoLink(uri)) return;

    final path = uri.path.isEmpty ? '/ludo' : uri.path;
    final query = uri.queryParameters.isEmpty
        ? ''
        : '?${Uri(queryParameters: uri.queryParameters).query}';

    _router.push('$path$query');
  }

  static bool _isLudoLink(Uri uri) {
    // Custom scheme: flicko://ludo/...
    if (uri.scheme == 'flicko' && uri.host == 'ludo') return true;
    // Universal links on flicko.app/ludo*
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.host == 'flicko.app' || uri.host.endsWith('.flicko.app')) &&
        uri.path.startsWith('/ludo')) {
      return true;
    }
    return false;
  }
}
