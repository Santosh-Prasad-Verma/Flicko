import 'dart:convert';

String formatDMMessagePreview(String rawContent) {
  if (rawContent.isEmpty) return '';

  // Check if content is JSON encoded (attachments / metadata)
  if (rawContent.startsWith('{') || rawContent.startsWith('[')) {
    try {
      final decoded = jsonDecode(rawContent);
      if (decoded is Map<String, dynamic>) {
        if (decoded['is_view_once'] == true) {
          return '📷 View Once Media';
        }
        if (decoded['type'] == 'sticker' || decoded['is_sticker'] == true) {
          return '👾 Sticker';
        }
        if (decoded['type'] == 'gif' || decoded['is_gif'] == true) {
          return '👾 GIF';
        }
        if (decoded['type'] == 'voice') {
          return '🎤 Voice message';
        }
        if (decoded['type'] == 'video') {
          return '🎥 Video';
        }
        if (decoded['type'] == 'image') {
          return '📷 Photo';
        }
      }
    } catch (_) {}
  }

  final lower = rawContent.toLowerCase().trim();

  // 1. Check View Once
  if (lower.contains('is_view_once:true') || lower.contains('"is_view_once":true')) {
    return '📷 View Once Media';
  }

  // 2. Check Stickers BEFORE general image file extensions (.png, .webp, .jpg)
  if (lower.contains('[sticker:') ||
      lower.contains('/stickers/') ||
      lower.contains('/sticker/') ||
      lower.startsWith('sticker_') ||
      lower.contains('type:sticker') ||
      lower.contains('"type":"sticker"') ||
      lower.contains('is_sticker') ||
      lower.contains('sticker_id')) {
    return '👾 Sticker';
  }

  // 3. Check GIFs
  if (lower.contains('tenor.com') ||
      lower.contains('giphy.com') ||
      lower.contains('.gif') ||
      lower.contains('type:gif') ||
      lower.contains('"type":"gif"')) {
    return '👾 GIF';
  }

  // 4. Check Photos / Images
  if (lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.webp') ||
      lower.contains('/attachments/') ||
      lower.contains('/avatars/')) {
    return '📷 Photo';
  }

  // 5. Check Videos
  if (lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm')) {
    return '🎥 Video';
  }

  // 6. Check Voice messages
  if (lower.contains('.aac') ||
      lower.contains('.m4a') ||
      lower.contains('.ogg') ||
      lower.contains('.mp3') ||
      lower.contains('voice_recording')) {
    return '🎤 Voice message';
  }

  // 7. Check Links
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return '🔗 Link';
  }

  return rawContent;
}
