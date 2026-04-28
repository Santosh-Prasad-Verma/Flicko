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
    if (isLoading && servers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        if (servers.isNotEmpty) ...[
          Text(
            'YOUR SERVERS',
            style: textTheme.labelSmall?.copyWith(
              color: const Color(FlickoColors.textMuted),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...servers.map((s) => _ServerListRow(server: s)),
        ] else ...[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const Center(
              child: Text(
                'No servers yet',
                style: TextStyle(color: Color(FlickoColors.textMuted)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
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
