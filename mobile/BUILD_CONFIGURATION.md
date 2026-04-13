# Mobile App Build Configuration

## Overview
This document describes the build tools and dependencies configured for the Flicko mobile application.

## Expo SDK Version
- **Version**: 54.0.33 (meets requirement of SDK 51 or later)

## Build Configuration (eas.json)

### Development Profile
- Development client enabled
- Internal distribution
- iOS simulator support enabled

### Preview Profile
- Internal distribution
- iOS simulator disabled (for real device testing)

### Production Profile
- Automatic version increment enabled
- Ready for app store submission

## Metro Bundler Configuration (metro.config.js)

### Monorepo Support
- Configured to watch parent directory for shared code
- Node modules resolution includes both mobile and root node_modules
- Enables importing from `shared/` directory

## Installed Dependencies

### Shared Dependencies
- `@supabase/supabase-js@^2.97.0` - Backend client library
- `zustand@^5.0.2` - State management (shared with web)
- `@tanstack/react-query@^5.62.11` - Server state management and caching

### Expo Packages
- `expo-secure-store@~15.0.8` - Encrypted storage for authentication tokens
- `expo-local-authentication@~17.0.8` - Biometric authentication (Face ID, Touch ID, Fingerprint)
- `expo-notifications@~0.32.16` - Push notifications
- `expo-image-picker@~17.0.10` - Camera and photo library access
- `expo-router@~6.0.23` - File-based routing system

### React Native Packages
- `@react-native-async-storage/async-storage@2.2.0` - Persistent storage
- `@react-native-community/netinfo@11.4.1` - Network connectivity detection

## TypeScript Configuration

### Path Aliases
The following path aliases are configured for importing shared code:
- `@shared/*` → `../shared/*`
- `@services/*` → `../shared/services/*`
- `@stores/*` → `../shared/stores/*`
- `@hooks/*` → `../shared/hooks/*`
- `@types/*` → `../shared/types/*`
- `@utils/*` → `../shared/utils/*`
- `@lib/*` → `../shared/lib/*`

### Example Usage
```typescript
import { useAuthStore } from '@stores/authStore';
import { authService } from '@services/auth.service';
import { useMessages } from '@hooks/useMessages';
import type { User } from '@types/models';
import { cn } from '@utils/cn';
```

## Verification

All configurations have been verified:
- ✅ EAS build profiles configured (development, preview, production)
- ✅ Metro bundler configured for monorepo structure
- ✅ All required dependencies installed
- ✅ TypeScript path aliases configured
- ✅ Expo SDK 54 (meets requirement of 51+)
- ✅ Shared code imports working correctly

## Next Steps

To build the app:
- Development: `eas build --profile development --platform ios/android`
- Preview: `eas build --profile preview --platform ios/android`
- Production: `eas build --profile production --platform ios/android`

To run locally:
- `npm start` - Start Expo development server
- `npm run ios` - Run on iOS simulator
- `npm run android` - Run on Android emulator
