import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// In-app browser screen for reading news articles within the app.
class InAppBrowserScreen extends StatefulWidget {
  final String url;
  final String title;

  const InAppBrowserScreen({
    super.key,
    required this.url,
    this.title = '',
  });

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  double _progress = 0;
  String _currentTitle = '';
  InAppWebViewController? _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png',
              width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTitle.isNotEmpty ? _currentTitle : 'Loading...',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              Uri.tryParse(widget.url)?.host ?? widget.url,
              style: GoogleFonts.spaceMono(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Navigation buttons
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white54, size: 18),
              onPressed: () => _controller?.goBack(),
            ),
          if (_canGoForward)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white54, size: 18),
              onPressed: () => _controller?.goForward(),
            ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share_rounded,
                color: Colors.white70, size: 20),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text: widget.url,
                  title: _currentTitle,
                ),
              );
            },
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white70, size: 20),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(FlickoColors.brandLime)),
              minHeight: 2,
            ),
          // WebView
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: false,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                if (mounted) {
                  setState(() => _progress = 0);
                }
              },
              onProgressChanged: (controller, progress) {
                if (mounted) {
                  setState(() => _progress = progress / 100);
                }
              },
              onTitleChanged: (controller, title) {
                if (mounted && title != null && title.isNotEmpty) {
                  setState(() => _currentTitle = title);
                }
              },
              onLoadStop: (controller, url) async {
                if (mounted) {
                  final back = await controller.canGoBack();
                  final forward = await controller.canGoForward();
                  setState(() {
                    _progress = 1.0;
                    _canGoBack = back;
                    _canGoForward = forward;
                  });
                }
              },
              onReceivedError: (controller, request, error) {
                if (mounted) {
                  setState(() => _progress = 1.0);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
