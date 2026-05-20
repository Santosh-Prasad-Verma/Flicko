import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/repositories/server_repository.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/data/models/channel_model.dart';
import 'servers_state.dart';

/// Provider for [ServersNotifier].
/// Uses [serverRepositoryProvider] and provides the [ServersState].
final serversNotifierProvider =
    NotifierProvider<ServersNotifier, ServersState>(ServersNotifier.new);

/// Notifier for managing the Servers tab state.
///
/// Handles fetching the user's servers, tracking the selected server,
/// and fetching channels when a server is selected.
class ServersNotifier extends Notifier<ServersState> {
  late final ServerRepository _repository;

  @override
  ServersState build() {
    _repository = ref.watch(serverRepositoryProvider);
    _init();
    return const ServersState();
  }

  /// Initializes the notifier by fetching joined servers for the current user.
  Future<void> _init() async {
    final authState = ref.read(authNotifierProvider);

    authState.maybeWhen(
      authenticated: (user, _) async {
        await _loadCachedServers(user.id);
        await fetchServers(user.id);
      },
      orElse: () {},
    );

    // Listen for auth changes to refetch servers if user logs in/out
    ref.listen(authNotifierProvider, (previous, next) {
      next.maybeWhen(
        authenticated: (user, _) async {
          await _loadCachedServers(user.id);
          fetchServers(user.id);
        },
        unauthenticated: () => state = const ServersState(),
        orElse: () {},
      );
    });
  }

  /// Loads locally cached servers for instant display.
  Future<void> _loadCachedServers(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_servers_$userId');
      if (cachedJson != null) {
        final list = jsonDecode(cachedJson) as List;
        final cachedServers = list
            .map((item) => ServerModel.fromJson(item as Map<String, dynamic>))
            .toList();
        if (cachedServers.isNotEmpty) {
          state = state.copyWith(servers: cachedServers);
          if (state.selectedServerId == null) {
            await selectServer(cachedServers.first.id);
          }
        }
      }
    } catch (_) {}
  }

  /// Loads locally cached channels for instant display on server selection.
  Future<void> _loadCachedChannels(String serverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_channels_$serverId');
      if (cachedJson != null) {
        final list = jsonDecode(cachedJson) as List;
        final cachedChannels = list
            .map((item) => ChannelModel.fromJson(item as Map<String, dynamic>))
            .toList();
        if (cachedChannels.isNotEmpty) {
          state = state.copyWith(selectedServerChannels: cachedChannels);
        }
      }
    } catch (_) {}
  }

  /// Fetches the list of servers the user is a member of.
  Future<void> fetchServers(String userId) async {
    if (state.servers.isEmpty) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    } else {
      state = state.copyWith(errorMessage: null);
    }
    try {
      final servers = await _repository.getUserServers(userId);
      state = state.copyWith(servers: servers, isLoading: false);

      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(servers.map((s) => s.toJson()).toList());
      await prefs.setString('cached_servers_$userId', encoded);

      if (servers.isNotEmpty) {
        final hasSelected = servers.any((s) => s.id == state.selectedServerId);
        if (state.selectedServerId == null || !hasSelected) {
          await selectServer(servers.first.id);
        }
      } else {
        state = state.copyWith(
          selectedServerId: null,
          selectedServerChannels: [],
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load servers: $e',
      );
    }
  }

  /// Refreshes servers for the currently authenticated user.
  Future<void> refresh() async {
    final userId = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user.id,
          orElse: () => null,
        );

    if (userId == null) {
      state = const ServersState();
      return;
    }

    await fetchServers(userId);
  }

  /// Selects a server and fetches its channels.
  /// Pass `null` to switch back to the "Home/DMs" view.
  Future<void> selectServer(String? serverId) async {
    if (state.selectedServerId == serverId &&
        state.selectedServerChannels.isNotEmpty) return;

    state = state.copyWith(
      selectedServerId: serverId,
      isLoading: serverId != null && state.selectedServerChannels.isEmpty,
    );

    if (serverId != null) {
      await _loadCachedChannels(serverId);

      try {
        final channels = await _repository.getServerChannels(serverId);
        state = state.copyWith(
          selectedServerChannels: channels,
          isLoading: false,
        );

        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        final encoded = jsonEncode(channels.map((c) => c.toJson()).toList());
        await prefs.setString('cached_channels_$serverId', encoded);
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load channels: $e',
        );
      }
    }
  }
}
