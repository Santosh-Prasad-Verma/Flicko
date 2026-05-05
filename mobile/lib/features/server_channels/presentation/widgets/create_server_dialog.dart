import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

  static const Color _neon = Color(0xFFC0F500);
  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFBF9FA);
  static const Color _muted = Color(0xFF71717A);

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
      // In a real app, upload icon here

      final server = await ref.read(serverRepositoryProvider).createServer(
        name: name,
        ownerId: userId,
        iconUrl: iconUrl,
      );

      // Refresh servers and select the new one
      final uid = ref.read(authNotifierProvider).maybeWhen(authenticated: (u,_)=>u.id, orElse: ()=>'');
      if (uid.isNotEmpty) await ref.read(serversNotifierProvider.notifier).fetchServers(uid);
      ref.read(serversNotifierProvider.notifier).selectServer(server.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SERVER "${server.name.toUpperCase()}" SECURED!', style: GoogleFonts.spaceMono(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: _neon,
            shape: const RoundedRectangleBorder(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.spaceMono(color: _white)),
            backgroundColor: const Color(0xFFED4245),
            shape: const RoundedRectangleBorder(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: Border.all(color: _white.withValues(alpha: 0.1), width: 1),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CREATE SERVER',
                style: GoogleFonts.epilogue(
                  color: _white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Define your space. Upload an icon and name your new community.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: _pickIcon,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: _bg,
                          border: Border.all(color: _neon, width: 2),
                          image: _selectedIcon != null
                              ? DecorationImage(
                                  image: FileImage(File(_selectedIcon!.path)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedIcon == null
                            ? const Icon(Icons.add_a_photo, size: 32, color: _neon)
                            : null,
                      ),
                      if (_selectedIcon != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _surface,
                            border: Border.all(color: _neon),
                          ),
                          child: const Icon(Icons.edit, size: 16, color: _neon),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'SERVER NAME',
                style: GoogleFonts.spaceMono(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: GoogleFonts.spaceGrotesk(color: _white, fontSize: 16, fontWeight: FontWeight.w600),
                cursorColor: _neon,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _bg,
                  hintText: 'e.g. Neon District',
                  hintStyle: GoogleFonts.spaceGrotesk(color: _white.withValues(alpha: 0.2)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: _white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: _white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: _neon, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _surface,
                          border: Border.all(color: _white.withValues(alpha: 0.1)),
                        ),
                        child: Center(
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.spaceGrotesk(color: _white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading ? null : _handleCreate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _isLoading ? _neon.withValues(alpha: 0.5) : _neon,
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : Text(
                                  'CREATE',
                                  style: GoogleFonts.spaceGrotesk(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
