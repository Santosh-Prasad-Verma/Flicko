import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class AboutDeveloperScreen extends StatefulWidget {
  const AboutDeveloperScreen({super.key});

  @override
  State<AboutDeveloperScreen> createState() => _AboutDeveloperScreenState();
}

class _AboutDeveloperScreenState extends State<AboutDeveloperScreen> {
  bool _isLoading = true;
  double _loadProgress = 0.0;

  static const Color _neonGreen = Color(0xFF2CE67F);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _textWhite = Color(0xFFFBF9FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialFile: 'assets/images/about_developer.html',
                    initialSettings: InAppWebViewSettings(
                      allowFileAccessFromFileURLs: true,
                      allowUniversalAccessFromFileURLs: true,
                      useHybridComposition: true,
                      transparentBackground: true,
                      verticalScrollBarEnabled: false,
                      horizontalScrollBarEnabled: false,
                      supportZoom: false,
                    ),
                    onLoadStart: (controller, url) {
                      setState(() {
                        _isLoading = true;
                        _loadProgress = 0.0;
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        _loadProgress = progress / 100.0;
                      });
                    },
                    onLoadStop: (controller, url) {
                      setState(() {
                        _isLoading = false;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      debugPrint("Developer Page WebView Console: ${consoleMessage.message}");
                    },
                  ),
                  if (_isLoading)
                    Container(
                      color: _bgBlack,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _loadProgress > 0 ? _loadProgress : null,
                                    strokeWidth: 3,
                                    valueColor: const AlwaysStoppedAnimation<Color>(_neonGreen),
                                    backgroundColor: _neonGreen.withValues(alpha: 0.1),
                                  ),
                                  const Icon(
                                    Icons.hexagon_outlined,
                                    color: _neonGreen,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'SYNCHRONIZING ORBIT...',
                              style: GoogleFonts.spaceMono(
                                color: _neonGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgBlack,
        border: Border(
          bottom: BorderSide(color: _neonGreen.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'About Developer',
                  style: GoogleFonts.outfit(
                    color: _textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Single Developer Project',
                  style: GoogleFonts.outfit(
                    color: _textWhite.withValues(alpha: 0.5),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}
