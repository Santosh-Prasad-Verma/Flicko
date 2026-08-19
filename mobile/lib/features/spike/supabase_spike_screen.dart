import 'package:flutter/material.dart';

class SupabaseSpikeScreen extends StatelessWidget {
  const SupabaseSpikeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase Spike')),
      body: const Center(child: Text('Supabase has been fully migrated to Azure.')),
    );
  }
}
