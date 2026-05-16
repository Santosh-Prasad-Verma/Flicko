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
        // In a real app, you would upload the icon to Supabase Storage here first
        // and get a public URL. For now, we'll just pass null or a placeholder.
        // iconUrl = await ref.read(serverRepositoryProvider).uploadIcon(_selectedIcon!);
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
      backgroundColor: const Color(FlickoColors.bgPrimary),
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.brandLime),
                  border: Border.all(
                      color: const Color(FlickoColors.black), width: 2),
                ),
                child: Text(
                  'NEW SERVER',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.black),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Create Your Server',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Give your new server a personality with a name and an icon. You can always change it later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickIcon,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgSecondary),
                      border: Border.all(
                        color: const Color(FlickoColors.brandLime),
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
                        ? const Icon(Icons.add_a_photo_outlined,
                            size: 32, color: Color(FlickoColors.brandLime))
                        : null,
                  ),
                  if (_selectedIcon != null)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.brandLime),
                        border: Border.all(
                            color: const Color(FlickoColors.black), width: 1.4),
                      ),
                      child: const Icon(Icons.edit,
                          size: 14, color: Color(FlickoColors.black)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                labelText: 'SERVER NAME',
                labelStyle: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
                filled: true,
                fillColor: const Color(FlickoColors.bgSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(
                      color: Color(FlickoColors.brandLime), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(
                      color: Color(FlickoColors.border), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(
                      color: Color(FlickoColors.brandLime), width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
                    foregroundColor: const Color(FlickoColors.black),
                    minimumSize: const Size(120, 48),
                    shape: const RoundedRectangleBorder(),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(FlickoColors.black)),
                        )
                      : Text(
                          'CREATE',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900, letterSpacing: 0.8),
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
