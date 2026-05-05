import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/data/models/server_model.dart';
import 'package:mobile/features/data/models/channel_model.dart';

part 'servers_state.freezed.dart';

@freezed
class ServersState with _$ServersState {
  const factory ServersState({
    @Default([]) List<ServerModel> servers,
    @Default([]) List<ChannelModel> selectedServerChannels,
    String? selectedServerId, // null means "Home" view
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _ServersState;
}
