import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/repositories/server_repository.dart';
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
        await fetchServers(user.id);
      },
      orElse: () {},
    );

    // Listen for auth changes to refetch servers if user logs in/out
    ref.listen(authNotifierProvider, (previous, next) {
      next.maybeWhen(
        authenticated: (user, _) => fetchServers(user.id),
        unauthenticated: () => state = const ServersState(),
        orElse: () {},
      );
    });
  }

  /// Fetches the list of servers the user is a member of.
  Future<void> fetchServers(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final servers = await _repository.getUserServers(userId);
      state = state.copyWith(servers: servers, isLoading: false);
      if (servers.isNotEmpty && state.selectedServerId == null) {
        await selectServer(servers.first.id);
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
    if (state.selectedServerId == serverId) return;

    state = state.copyWith(
      selectedServerId: serverId,
      selectedServerChannels: [],
      isLoading: serverId != null,
    );

    if (serverId != null) {
      try {
        final channels = await _repository.getServerChannels(serverId);
        state = state.copyWith(
          selectedServerChannels: channels,
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load channels: $e',
        );
      }
    }
  }
}
