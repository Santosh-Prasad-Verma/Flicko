class ChannelBackground {
  final String id;
  final String channelId;
  final String serverId;
  final String? uploaderId;
  final String fileIdOriginal;
  final String? fileIdMobile;
  final String? fileIdBlurred;
  final String blurhash;
  final int widthPx;
  final int heightPx;
  final int bytesOriginal;
  final String mimeType;
  final String sha256;
  final String dominantColor;
  final double meanLuminance;
  final double? minTextContrast;
  final double focalX;
  final double focalY;
  final String status;

  ChannelBackground({
    required this.id,
    required this.channelId,
    required this.serverId,
    this.uploaderId,
    required this.fileIdOriginal,
    this.fileIdMobile,
    this.fileIdBlurred,
    required this.blurhash,
    required this.widthPx,
    required this.heightPx,
    required this.bytesOriginal,
    required this.mimeType,
    required this.sha256,
    required this.dominantColor,
    required this.meanLuminance,
    this.minTextContrast,
    required this.focalX,
    required this.focalY,
    required this.status,
  });

  factory ChannelBackground.fromJson(Map<String, dynamic> json) {
    return ChannelBackground(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      serverId: json['server_id'] as String,
      uploaderId: json['uploader_id'] as String?,
      fileIdOriginal: json['file_id_original'] as String,
      fileIdMobile: json['file_id_mobile'] as String?,
      fileIdBlurred: json['file_id_blurred'] as String?,
      blurhash: json['blurhash'] as String,
      widthPx: json['width_px'] as int,
      heightPx: json['height_px'] as int,
      bytesOriginal: json['bytes_original'] as int,
      mimeType: json['mime_type'] as String,
      sha256: json['sha256'] as String,
      dominantColor: json['dominant_color'] as String,
      meanLuminance: (json['mean_luminance'] as num).toDouble(),
      minTextContrast: (json['min_text_contrast'] as num?)?.toDouble(),
      focalX: (json['focal_x'] as num).toDouble(),
      focalY: (json['focal_y'] as num).toDouble(),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channel_id': channelId,
      'server_id': serverId,
      'uploader_id': uploaderId,
      'file_id_original': fileIdOriginal,
      'file_id_mobile': fileIdMobile,
      'file_id_blurred': fileIdBlurred,
      'blurhash': blurhash,
      'width_px': widthPx,
      'height_px': heightPx,
      'bytes_original': bytesOriginal,
      'mime_type': mimeType,
      'sha256': sha256,
      'dominant_color': dominantColor,
      'mean_luminance': meanLuminance,
      'min_text_contrast': minTextContrast,
      'focal_x': focalX,
      'focal_y': focalY,
      'status': status,
    };
  }
}

class ChannelBackgroundUserOverride {
  final String userId;
  final String channelId;
  final double opacity;
  final bool enabled;

  ChannelBackgroundUserOverride({
    required this.userId,
    required this.channelId,
    required this.opacity,
    required this.enabled,
  });

  factory ChannelBackgroundUserOverride.fromJson(Map<String, dynamic> json) {
    return ChannelBackgroundUserOverride(
      userId: json['user_id'] as String,
      channelId: json['channel_id'] as String,
      opacity: (json['opacity'] as num).toDouble(),
      enabled: json['enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'channel_id': channelId,
      'opacity': opacity,
      'enabled': enabled,
    };
  }
}
