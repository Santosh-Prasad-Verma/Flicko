#!/bin/bash
# Fix broken import paths across the Flutter codebase
# Maps wrong import paths to correct ones

cd /home/tarun/Videos/Flicko/mobile/lib

# ── Fix FlickoColors/FlickoSpacing/FlickoRadius imports ──
# Wrong: package:mobile/features/core/constants/flicko_colors.dart
# Wrong: package:mobile/core/theme/flicko_colors.dart  
# Wrong: package:mobile/core/theme/flicko_spacing.dart
# Wrong: package:mobile/core/theme/flicko_radius.dart
# Correct: package:mobile/core/constants/flicko_colors.dart (contains all three classes)
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/core/constants/flicko_colors.dart|package:mobile/core/constants/flicko_colors.dart|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/core/theme/flicko_colors.dart|package:mobile/core/constants/flicko_colors.dart|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/core/theme/flicko_spacing.dart|package:mobile/core/constants/flicko_colors.dart|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/core/theme/flicko_radius.dart|package:mobile/core/constants/flicko_colors.dart|g" {} +

# ── Fix auth_notifier / auth_provider imports ──
# Wrong: package:mobile/auth/application/auth_notifier.dart
# Wrong: package:mobile/features/auth/providers/auth_provider.dart
# Wrong: package:mobile/features/features/auth/application/auth_notifier.dart
# Wrong: package:mobile/features/server_channels/auth/application/auth_notifier.dart
# Correct: package:mobile/features/auth/application/auth_notifier.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/auth/application/auth_notifier.dart|package:mobile/features/auth/application/auth_notifier.dart|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/auth/providers/auth_provider.dart|package:mobile/features/auth/application/auth_notifier.dart|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/features/auth/application/auth_notifier.dart|package:mobile/features/auth/application/auth_notifier.dart|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/server_channels/auth/application/auth_notifier.dart|package:mobile/features/auth/application/auth_notifier.dart|g" {} +

# ── Fix model imports with wrong 'features/data' prefix ──
# Wrong: package:mobile/features/data/models/X.dart
# Correct: package:mobile/data/models/X.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/data/models/|package:mobile/data/models/|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/data/services/|package:mobile/data/services/|g" {} +

# ── Fix voice controller imports ──
# Wrong: package:mobile/features/home/voice/presentation/controllers/voice_controller.dart
# Wrong: package:mobile/features/server_channels/voice/voice/presentation/controllers/voice_controller.dart
# Correct: package:mobile/features/voice/presentation/controllers/voice_controller.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/home/voice/presentation/controllers/voice_controller.dart|package:mobile/features/voice/presentation/controllers/voice_controller.dart|g" {} +

find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/server_channels/voice/voice/presentation/controllers/voice_controller.dart|package:mobile/features/voice/presentation/controllers/voice_controller.dart|g" {} +

# Wrong: package:mobile/features/server_channels/voice/voice/presentation/soundboard_sheet.dart
# Correct: package:mobile/features/voice/presentation/soundboard_sheet.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/server_channels/voice/voice/presentation/soundboard_sheet.dart|package:mobile/features/voice/presentation/soundboard_sheet.dart|g" {} +

# Wrong: ../../voice/presentation/controllers/voice_state.dart (relative from voice_channel_screen)
# This is a relative path issue in voice_channel_screen.dart - will handle per-file

# ── Fix voice models import ──
# Wrong: package:mobile/features/home/voice/domain/voice_models.dart
# Correct: package:mobile/features/voice/domain/voice_models.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/home/voice/domain/voice_models.dart|package:mobile/features/voice/domain/voice_models.dart|g" {} +

# ── Fix chat_notifier wrong path ──
# Wrong: package:mobile/features/server_channels/chat/presentation/application/chat_notifier.dart
# Correct: package:mobile/features/server_channels/chat/application/chat_notifier.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/server_channels/chat/presentation/application/chat_notifier.dart|package:mobile/features/server_channels/chat/application/chat_notifier.dart|g" {} +

# ── Fix user_avatar wrong path ──
# Wrong: package:mobile/features/server_channels/shared/presentation/widgets/user_avatar.dart
# Correct: package:mobile/features/shared/presentation/widgets/user_avatar.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/server_channels/shared/presentation/widgets/user_avatar.dart|package:mobile/features/shared/presentation/widgets/user_avatar.dart|g" {} +

# ── Fix thread screen wrong imports ──
# Wrong: package:mobile/features/server_channels/thread/chat/presentation/widgets/enhanced_message_input.dart
# Wrong: package:mobile/features/server_channels/thread/chat/presentation/widgets/enhanced_message_item.dart
# Wrong: package:mobile/features/server_channels/thread/chat/presentation/widgets/message_actions.dart
# Correct: package:mobile/features/server_channels/chat/presentation/widgets/X.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:mobile/features/server_channels/thread/chat/presentation/widgets/|package:mobile/features/server_channels/chat/presentation/widgets/|g" {} +

# ── Fix web_socket_channel import ──
# Wrong: package:web_socket_channel/io_websocket_channel.dart
# Correct: package:web_socket_channel/io.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:web_socket_channel/io_websocket_channel.dart|package:web_socket_channel/io.dart|g" {} +

# ── Fix flutter_local_notifications import ──
# Wrong: package:flutter_local_notifications/flutterLocalNotificationsPlugin.dart
# Correct: package:flutter_local_notifications/flutter_local_notifications.dart
find . -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" -exec sed -i \
  "s|package:flutter_local_notifications/flutterLocalNotificationsPlugin.dart|package:flutter_local_notifications/flutter_local_notifications.dart|g" {} +

echo "Import fixes complete!"
