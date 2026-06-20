import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/repositories/server_repository.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class CreateServerDialog extends ConsumerStatefulWidget {
  const CreateServerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const CreateServerDialog(),
    );
  }

  @override
  ConsumerState<CreateServerDialog> createState() => _CreateServerDialogState();
}

class _CreateServerDialogState extends ConsumerState<CreateServerDialog> {
  final _nameController = TextEditingController();
  XFile? _selectedIcon;
  bool _isLoading = false;

  Future<void> _pickIcon() async {
    final picker = ImagePicker();
    final icon = await picker.pickImage(source: ImageSource.gallery);
    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final userId = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user.id,
          orElse: () => null,
        );

    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      String? iconUrl;
      if (_selectedIcon != null) {
        // Future expansion: upload icon and get public URL
      }

      final server = await ref.read(serverRepositoryProvider).createServer(
            name: name,
            ownerId: userId,
            iconUrl: iconUrl,
          );

      // Refresh servers and select the new one
      await ref.read(serversNotifierProvider.notifier).refresh();
      ref.read(serversNotifierProvider.notifier).selectServer(server.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server "${server.name}" created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create server: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Create a Server',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your server is where you and your friends hang out. Customize it with a name and an icon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickIcon,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgTertiary),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(FlickoColors.blurple).withValues(alpha: 0.3),
                        width: 2,
                      ),
                      image: _selectedIcon != null
                          ? DecorationImage(
                              image: FileImage(File(_selectedIcon!.path)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedIcon == null
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            size: 32,
                            color: Color(FlickoColors.blurple),
                          )
                        : null,
                  ),
                  if (_selectedIcon != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(FlickoColors.blurple),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
              ),
              decoration: InputDecoration(
                labelText: 'SERVER NAME',
                labelStyle: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(FlickoColors.blurple),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.blurple),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(130, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create Server',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
