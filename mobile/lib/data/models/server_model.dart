import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_model.freezed.dart';
part 'server_model.g.dart';

@freezed
class ServerModel with _$ServerModel {
  const factory ServerModel({
    required String id,
    required String name,
    String? description,
    @JsonKey(name: 'icon') String? iconUrl,
    @JsonKey(name: 'banner') String? bannerUrl,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'member_count') @Default(0) int memberCount,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _ServerModel;

  factory ServerModel.fromJson(Map<String, dynamic> json) => _$ServerModelFromJson(json);
}
