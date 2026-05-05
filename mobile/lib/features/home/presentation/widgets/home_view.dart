import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/server_model.dart';

class HomeView extends StatelessWidget {
  final String username;
  final List<ServerModel> servers;
  final bool isLoading;

  const HomeView({
    super.key,
    required this.username,
    required this.servers,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(title: 'Flicko', subtitle: 'Welcome back, $username'),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _WelcomeCard(textTheme: textTheme),
              const SizedBox(height: 24),

              if (servers.isNotEmpty) ...[
                Text(
                  'YOUR SERVERS',
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(FlickoColors.textMuted),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...servers.map((s) => _ServerListRow(server: s)).toList(),
              ] else if (isLoading) ...[
                const Center(
                  child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
                ),
              ] else ...[
                const Center(
                  child: Text(
                    'No servers yet',
                    style: TextStyle(color: Color(FlickoColors.textMuted)),
                  ),
                ),
              ],
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _Header({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(FlickoColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final TextTheme textTheme;
  const _WelcomeCard({required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.blurple),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Flicko',
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Connect with friends, join communities, and explore servers',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerListRow extends StatelessWidget {
  final ServerModel server;
  const _ServerListRow({required this.server});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgPrimary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.blurple),
              borderRadius: BorderRadius.circular(8),
            ),
            child: server.iconUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(server.iconUrl!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      server.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (server.description != null)
                  Text(
                    server.description!,
                    style: const TextStyle(
                      color: Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(FlickoColors.textMuted), size: 18),
        ],
      ),
    );
  }
}
