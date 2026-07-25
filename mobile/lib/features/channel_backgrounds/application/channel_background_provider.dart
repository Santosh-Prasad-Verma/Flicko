import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/channel_backgrounds/data/channel_background_repository.dart';
import 'package:mobile/features/channel_backgrounds/domain/channel_background.dart';

final channelBackgroundRepositoryProvider = Provider<ChannelBackgroundRepository>((ref) {
  return ChannelBackgroundRepository();
});

final channelBackgroundProvider = FutureProvider.family<ChannelBackground?, String>((ref, channelId) async {
  final repo = ref.watch(channelBackgroundRepositoryProvider);
  return repo.fetchBackground(channelId);
});

final channelBackgroundOverrideProvider = FutureProvider.family<ChannelBackgroundUserOverride?, String>((ref, channelId) async {
  final repo = ref.watch(channelBackgroundRepositoryProvider);
  return repo.fetchOverride(channelId);
});
