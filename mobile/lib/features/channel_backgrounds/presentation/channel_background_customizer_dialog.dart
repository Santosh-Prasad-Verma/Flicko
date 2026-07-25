import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/channel_backgrounds/application/channel_background_provider.dart';

class ChannelBackgroundCustomizerDialog extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelBackgroundCustomizerDialog({
    super.key,
    required this.channelId,
  });

  @override
  ConsumerState<ChannelBackgroundCustomizerDialog> createState() =>
      _ChannelBackgroundCustomizerDialogState();
}

class _ChannelBackgroundCustomizerDialogState
    extends ConsumerState<ChannelBackgroundCustomizerDialog> {
  bool _isUploading = false;
  double _opacity = 0.3;
  bool _enabled = true;
  bool _hasLoadedOverride = false;

  static const Color lime = Color(0xFF52B788);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final repo = ref.read(channelBackgroundRepositoryProvider);
      final bg = await repo.uploadBackground(widget.channelId, image.path);
      if (bg != null) {
        ref.invalidate(channelBackgroundProvider(widget.channelId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background uploaded successfully!'),
              backgroundColor: lime,
            ),
          );
        }
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload background: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteBackground() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final repo = ref.read(channelBackgroundRepositoryProvider);
      final success = await repo.deleteBackground(widget.channelId);
      if (success) {
        ref.invalidate(channelBackgroundProvider(widget.channelId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background removed successfully.'),
              backgroundColor: lime,
            ),
          );
        }
      } else {
        throw Exception("Deletion failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete background: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _saveOverride() async {
    final repo = ref.read(channelBackgroundRepositoryProvider);
    final success = await repo.setOverride(widget.channelId, _opacity, _enabled);
    if (success) {
      ref.invalidate(channelBackgroundOverrideProvider(widget.channelId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgState = ref.watch(channelBackgroundProvider(widget.channelId));
    final overrideState = ref.watch(channelBackgroundOverrideProvider(widget.channelId));

    // Initialize state from override once loaded
    if (!_hasLoadedOverride && overrideState.hasValue && overrideState.value != null) {
      final override = overrideState.value!;
      _opacity = override.opacity;
      _enabled = override.enabled;
      _hasLoadedOverride = true;
    }

    final bg = bgState.value;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 380,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: lime.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: lime.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.image_outlined, color: lime, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'CUSTOM BACKGROUND',
                          style: GoogleFonts.spaceGrotesk(
                            color: white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Personalize this channel by setting a custom high-fidelity background image. This image will only display inside this channel.',
                    style: GoogleFonts.spaceGrotesk(
                      color: white.withValues(alpha: 0.65),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (bg != null) ...[
                    // Preview container
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: white.withValues(alpha: 0.1)),
                        image: DecorationImage(
                          image: (bg.fileIdOriginal.startsWith('http') || (bg.fileIdMobile?.startsWith('http') ?? false))
                              ? NetworkImage(bg.fileIdMobile ?? bg.fileIdOriginal)
                              : FileImage(File(bg.fileIdOriginal)) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${bg.widthPx}x${bg.heightPx}',
                          style: GoogleFonts.spaceGrotesk(color: white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Enable/Disable switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enable Background',
                          style: GoogleFonts.spaceGrotesk(color: white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Switch(
                          value: _enabled,
                          activeThumbColor: lime,
                          activeTrackColor: lime.withValues(alpha: 0.3),
                          inactiveThumbColor: white.withValues(alpha: 0.5),
                          inactiveTrackColor: white.withValues(alpha: 0.1),
                          onChanged: (val) {
                            setState(() {
                              _enabled = val;
                            });
                            _saveOverride();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Opacity slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Background Opacity',
                              style: GoogleFonts.spaceGrotesk(color: white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              '${(_opacity * 100).toInt()}%',
                              style: GoogleFonts.spaceGrotesk(color: lime, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        Slider(
                          value: _opacity,
                          min: 0.05,
                          max: 1.0,
                          activeColor: lime,
                          inactiveColor: white.withValues(alpha: 0.1),
                          onChanged: _enabled
                              ? (val) {
                                  setState(() {
                                    _opacity = val;
                                  });
                                }
                              : null,
                          onChangeEnd: _enabled
                              ? (val) {
                                  _saveOverride();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ] else ...[
                    // Selection placeholder
                    GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: white.withValues(alpha: 0.12),
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: _isUploading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(lime),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, color: white.withValues(alpha: 0.4), size: 40),
                                    const SizedBox(height: 12),
                                    Text(
                                      'SELECT IMAGE',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: lime,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PNG, JPG up to 8MB',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: white.withValues(alpha: 0.3),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (bg != null)
                        TextButton.icon(
                          onPressed: _isUploading ? null : _deleteBackground,
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          label: Text(
                            'Remove',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else
                        const SizedBox(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lime,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 4,
                          shadowColor: lime.withValues(alpha: 0.2),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.spaceGrotesk(
                            color: black,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
