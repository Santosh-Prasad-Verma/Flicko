import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Base placeholder screen for server settings
class ServerSettingsPlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const ServerSettingsPlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: const Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                description,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Remaining placeholder screens (not yet migrated) ──

class EmojisSettingsScreen extends StatelessWidget {
  final String serverId;
  const EmojisSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Emoji',
      description: 'Upload and manage custom emojis',
      icon: Icons.emoji_emotions_outlined,
    );
  }
}

class StickersSettingsScreen extends StatelessWidget {
  final String serverId;
  const StickersSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Stickers',
      description: 'Upload and manage stickers',
      icon: Icons.image_outlined,
    );
  }
}

class ModerationSettingsScreen extends StatelessWidget {
  final String serverId;
  const ModerationSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Safety Setup',
      description: 'Verification level and content filter settings',
      icon: Icons.shield_outlined,
    );
  }
}

class BotsSettingsScreen extends StatelessWidget {
  final String serverId;
  const BotsSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Bots',
      description: 'Manage server bots and automation',
      icon: Icons.memory_outlined,
    );
  }
}

class WebhooksSettingsScreen extends StatelessWidget {
  final String serverId;
  const WebhooksSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Webhooks',
      description: 'Manage incoming webhooks',
      icon: Icons.code_outlined,
    );
  }
}

class EventsSettingsScreen extends StatelessWidget {
  final String serverId;
  const EventsSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Events',
      description: 'Create and manage scheduled events',
      icon: Icons.event_outlined,
    );
  }
}

class OnboardingSettingsScreen extends StatelessWidget {
  final String serverId;
  const OnboardingSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Onboarding',
      description: 'Welcome screen and onboarding questions',
      icon: Icons.rocket_launch_outlined,
    );
  }
}

class TemplatesSettingsScreen extends StatelessWidget {
  final String serverId;
  const TemplatesSettingsScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return const ServerSettingsPlaceholderScreen(
      title: 'Server Template',
      description: 'Pre-made layouts and saves',
      icon: Icons.description_outlined,
    );
  }
}

class DeleteServerScreen extends StatelessWidget {
  final String serverId;
  const DeleteServerScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Delete Server',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.danger),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.danger).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(FlickoColors.danger).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Color(FlickoColors.danger),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Deleting this server is irreversible. All data, channels, messages, and members will be permanently lost.',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(FlickoColors.bgSecondary),
                      title: Text(
                        'Confirm Deletion',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.danger),
                        ),
                      ),
                      content: Text(
                        'Are you absolutely sure? This action cannot be undone.',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textMuted),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.go('/servers');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(FlickoColors.danger),
                          ),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.danger),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Delete Server',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Server Detail Screen - Placeholder
class ServerDetailScreen extends StatelessWidget {
  const ServerDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text(
          'Server',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(FlickoColors.textPrimary)),
            onPressed: () {
              context.push('/server/test-server-id/settings');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dns,
              size: 64,
              color: Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Server View',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Server detail screen placeholder',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.push('/server/test-server-id/settings');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.blurple),
              ),
              child: Text(
                'Open Settings',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
