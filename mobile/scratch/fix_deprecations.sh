#!/bin/bash

# Target directory
TARGET_DIR="lib"

# 1. Replace withOpacity with withValues(alpha: ...)
# Case: .withOpacity(0.12) -> .withValues(alpha: 0.12)
find "$TARGET_DIR" -name "*.dart" -exec sed -i 's/\.withOpacity(\([^)]*\))/.withValues(alpha: \1)/g' {} +

# 2. Replace activeColor with activeThumbColor for Switch and SwitchListTile
# Since activeColor is still valid for Slider, we try to target common Switch patterns.
# Or we can just look for files where the analyzer complained.

# For now, let's target these files specifically which were in the analyzer output
FILES_WITH_SWITCH_DEPRECATION=(
  "lib/features/server_settings/presentation/onboarding_settings_screen.dart"
  "lib/features/server_settings/presentation/role_editor_screen.dart"
  "lib/features/server_channels/chat/presentation/widgets/poll_creator_modal.dart"
  "lib/features/settings/presentation/voice_settings_screen.dart"
  "lib/features/settings/presentation/appearance_settings_screen.dart"
)

for file in "${FILES_WITH_SWITCH_DEPRECATION[@]}"; do
  if [ -f "$file" ]; then
    # We use a pattern that matches activeColor inside Switch-like widgets
    # A simple replacement if we know those files' activeColor usage is deprecated.
    sed -i 's/activeColor:/activeThumbColor:/g' "$file"
  fi
done
