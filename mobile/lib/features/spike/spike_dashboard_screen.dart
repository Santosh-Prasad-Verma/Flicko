import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SpikeDashboardScreen extends StatelessWidget {
  const SpikeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 0: Technical Spikes')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSpikeCard(
            context,
            title: 'LiveKit WebRTC',
            description: 'Test joining rooms, publishing tracks, and remote subscription.',
            onTap: () => context.go('/spike/livekit'),
            status: 'Pending',
          ),

          _buildSpikeCard(
            context,
            title: 'Supabase Realtime',
            description: 'Test channel subscriptions and presence.',
            onTap: () => context.go('/spike/supabase'),
            status: 'Pending',
          ),
        ],
      ),
    );
  }

  Widget _buildSpikeCard(
    BuildContext context, {
    required String title,
    required String description,
    required VoidCallback onTap,
    required String status,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 8),
              Chip(
                label: Text(status),
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                labelStyle: const TextStyle(color: Colors.orange),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
