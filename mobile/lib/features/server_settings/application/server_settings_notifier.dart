import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/repositories/server_settings_repository.dart';

class ServerSettingsState {
  final String serverId;
  final String? name;
  final String? description;
  final String? iconUrl;
  final String? bannerUrl;
  final bool isLoading;
  final bool isSaving;
  final bool isOwner;
  final int membersCount;
  final int channelsCount;
  final int rolesCount;
  final String? errorMessage;

  const ServerSettingsState({
    required this.serverId,
    this.name,
    this.description,
    this.iconUrl,
    this.bannerUrl,
    this.isLoading = true,
    this.isSaving = false,
    this.isOwner = false,
    this.membersCount = 0,
    this.channelsCount = 0,
    this.rolesCount = 0,
    this.errorMessage,
  });

  ServerSettingsState copyWith({
    String? name,
    String? description,
    String? iconUrl,
    String? bannerUrl,
    bool? isLoading,
    bool? isSaving,
    bool? isOwner,
    int? membersCount,
    int? channelsCount,
    int? rolesCount,
    String? errorMessage,
  }) {
    return ServerSettingsState(
      serverId: serverId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isOwner: isOwner ?? this.isOwner,
      membersCount: membersCount ?? this.membersCount,
      channelsCount: channelsCount ?? this.channelsCount,
      rolesCount: rolesCount ?? this.rolesCount,
      errorMessage: errorMessage,
    );
  }
}

final serverSettingsNotifierProvider =
    NotifierProvider.family<ServerSettingsNotifier, ServerSettingsState, String>(
        ServerSettingsNotifier.new);

class ServerSettingsNotifier extends Notifier<ServerSettingsState> {
  late final ServerSettingsRepository _repository;
  late final String _serverId;

  ServerSettingsNotifier(this._serverId);

  @override
  ServerSettingsState build() {
    _repository = ref.watch(serverSettingsRepositoryProvider);
    _loadServer();
    return ServerSettingsState(serverId: _serverId);
  }

  void _loadServer() {
    Future.microtask(() async {
      await loadServer();
    });
  }

  Future<void> loadServer() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([
        _repository.getServerDetails(_serverId),
        _repository.getMembersCount(_serverId),
        _repository.getChannelsCount(_serverId),
        _repository.getRolesCount(_serverId),
        _repository.isServerOwner(_serverId),
      ]);

      final details = results[0] as Map<String, dynamic>;
      final members = results[1] as int;
      final channels = results[2] as int;
      final roles = results[3] as int;
      final owner = results[4] as bool;

      state = ServerSettingsState(
        serverId: _serverId,
        name: details['name'] as String?,
        description: details['description'] as String?,
        iconUrl: details['icon_url'] as String?,
        bannerUrl: details['banner_url'] as String?,
        isLoading: false,
        isOwner: owner,
        membersCount: members,
        channelsCount: channels,
        rolesCount: roles,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> saveOverview({
    String? name,
    String? description,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (updates.isNotEmpty) {
        await _repository.updateServer(_serverId, updates);
      }
      await loadServer();
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
    }
  }
}
