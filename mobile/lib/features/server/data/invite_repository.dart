import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/api_client.dart';

class ServerInvite {
  final String id;
  final String serverId;
  final String code;
  final String createdBy;
  final DateTime? expiresAt;
  final int? maxUses;
  final int uses;
  final DateTime createdAt;

  ServerInvite({
    required this.id,
    required this.serverId,
    required this.code,
    required this.createdBy,
    this.expiresAt,
    this.maxUses,
    required this.uses,
    required this.createdAt,
  });

  factory ServerInvite.fromJson(Map<String, dynamic> json) {
    return ServerInvite(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      code: json['code'] as String,
      createdBy: json['created_by'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      maxUses: json['max_uses'] as int?,
      uses: (json['uses'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get inviteUrl => 'https://flicko.app/invite/$code';
}

class InviteRepository {
  final SupabaseClient _supabase;

  InviteRepository(this._supabase);

  String _generateRandomCode(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<ServerInvite> getOrCreateInvite(
    String serverId, {
    Duration? duration,
    int? maxUses,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Try fetching an active existing invite for this server first
    final existing = await _supabase
        .from('invites')
        .select('*')
        .eq('server_id', serverId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final invite = ServerInvite.fromJson(Map<String, dynamic>.from(existing as Map));
      final isExpired = invite.expiresAt != null && invite.expiresAt!.isBefore(DateTime.now());
      final isMaxedOut = invite.maxUses != null && invite.uses >= invite.maxUses!;
      if (!isExpired && !isMaxedOut) {
        return invite;
      }
    }

    // Otherwise create a new invite
    final code = _generateRandomCode(8);
    final expiresAt = duration != null ? DateTime.now().add(duration) : null;

    final response = await _supabase
        .from('invites')
        .insert({
          'server_id': serverId,
          'code': code,
          'created_by': userId,
          'expires_at': expiresAt?.toIso8601String(),
          'max_uses': maxUses,
        })
        .select('*')
        .single();

    return ServerInvite.fromJson(Map<String, dynamic>.from(response as Map));
  }
}

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(Supabase.instance.client);
});
