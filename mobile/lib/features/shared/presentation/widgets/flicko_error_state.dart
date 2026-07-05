import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/core/errors/flicko_api_exception.dart';

enum FlickoErrorType {
  serverDown,
  noConnection,
  timeout,
  unauthorized,
  forbidden,
  generic,
}

/// Glassmorphic error state widget displaying server health, connectivity,
/// and retry actions with automatic exponential backoff timer.
class FlickoErrorState extends StatefulWidget {
  final FlickoErrorType type;
  final String? customMessage;
  final VoidCallback? onRetry;
  final bool compact;

  const FlickoErrorState({
    super.key,
    this.type = FlickoErrorType.generic,
    this.customMessage,
    this.onRetry,
    this.compact = false,
  });

  factory FlickoErrorState.fromException(
    Object error, {
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    if (error is FlickoApiException) {
      if (error is NoConnectionApiException) {
        return FlickoErrorState(
          type: FlickoErrorType.noConnection,
          onRetry: onRetry,
          compact: compact,
        );
      }
      if (error is TimeoutApiException) {
        return FlickoErrorState(
          type: FlickoErrorType.timeout,
          onRetry: onRetry,
          compact: compact,
        );
      }
      if (error is ServerErrorApiException) {
        return FlickoErrorState(
          type: FlickoErrorType.serverDown,
          customMessage: error.message,
          onRetry: onRetry,
          compact: compact,
        );
      }
      if (error is UnauthorizedApiException) {
        return FlickoErrorState(
          type: FlickoErrorType.unauthorized,
          onRetry: onRetry,
          compact: compact,
        );
      }
    }
    return FlickoErrorState(
      type: FlickoErrorType.generic,
      customMessage: error.toString().replaceFirst('Exception: ', ''),
      onRetry: onRetry,
      compact: compact,
    );
  }

  @override
  State<FlickoErrorState> createState() => _FlickoErrorStateState();
}

class _FlickoErrorStateState extends State<FlickoErrorState> {
  int _countdown = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.onRetry != null && widget.type == FlickoErrorType.serverDown) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        if (mounted && widget.onRetry != null) {
          widget.onRetry!();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case FlickoErrorType.serverDown:
        return Icons.cloud_off_rounded;
      case FlickoErrorType.noConnection:
        return Icons.wifi_off_rounded;
      case FlickoErrorType.timeout:
        return Icons.timer_off_rounded;
      case FlickoErrorType.unauthorized:
        return Icons.lock_outline_rounded;
      case FlickoErrorType.forbidden:
        return Icons.gpp_bad_rounded;
      case FlickoErrorType.generic:
        return Icons.warning_amber_rounded;
    }
  }

  String _getTitle() {
    switch (widget.type) {
      case FlickoErrorType.serverDown:
        return 'Server Not Responding';
      case FlickoErrorType.noConnection:
        return 'No Internet Connection';
      case FlickoErrorType.timeout:
        return 'Request Timed Out';
      case FlickoErrorType.unauthorized:
        return 'Session Expired';
      case FlickoErrorType.forbidden:
        return 'Access Denied';
      case FlickoErrorType.generic:
        return 'Something Went Wrong';
    }
  }

  String _getSubtitle() {
    if (widget.customMessage != null && widget.customMessage!.isNotEmpty) {
      return widget.customMessage!;
    }
    switch (widget.type) {
      case FlickoErrorType.serverDown:
        return 'Flicko servers are currently unavailable or taking too long to respond. We are retrying automatically.';
      case FlickoErrorType.noConnection:
        return 'Please check your Wi-Fi or mobile data connection and try again.';
      case FlickoErrorType.timeout:
        return 'The server took too long to respond. Tap below to retry.';
      case FlickoErrorType.unauthorized:
        return 'Your session has expired. Please sign back in.';
      case FlickoErrorType.forbidden:
        return 'You do not have permission to view this content.';
      case FlickoErrorType.generic:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1416),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(_getIcon(), color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _getTitle(),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.onRetry != null)
              GestureDetector(
                onTap: widget.onRetry,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.outfit(
                      color: const Color(FlickoColors.green),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF121814).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(FlickoColors.green).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: widget.type == FlickoErrorType.serverDown
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(),
                      size: 32,
                      color: widget.type == FlickoErrorType.serverDown
                          ? Colors.orangeAccent
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getTitle(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getSubtitle(),
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.type == FlickoErrorType.serverDown && widget.onRetry != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Auto-retrying in ${_countdown}s...',
                      style: GoogleFonts.spaceMono(
                        color: Colors.orangeAccent.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(FlickoColors.green),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          _timer?.cancel();
                          widget.onRetry!();
                        },
                        child: Text(
                          'Try Again Now',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
