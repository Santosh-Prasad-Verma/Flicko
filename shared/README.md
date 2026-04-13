# Shared Code Directory

This directory contains code shared between the web and mobile applications, enabling 70-80% code reuse across platforms.

## Directory Structure

```
shared/
├── services/     # API integration layer (Supabase, REST APIs)
├── stores/       # Zustand state management stores
├── hooks/        # Custom React hooks for business logic
├── types/        # TypeScript type definitions and interfaces
├── utils/        # Helper functions and utilities
└── lib/          # Library configurations (Supabase client, React Query)
```

## Usage

### In Web Application (src/)

```typescript
import { authService } from '@services/auth.service';
import { useAuthStore } from '@stores/authStore';
import { useMessages } from '@hooks/useMessages';
import type { User, Message } from '@types/models';
import { validateEmail } from '@utils/validation.utils';
```

### In Mobile Application (mobile/)

```typescript
import { authService } from '@services/auth.service';
import { useAuthStore } from '@stores/authStore';
import { useMessages } from '@hooks/useMessages';
import type { User, Message } from '@types/models';
import { validateEmail } from '@utils/validation.utils';
```

## Path Aliases

The following TypeScript path aliases are configured for easy imports:

- `@shared/*` - Root shared directory
- `@services/*` - Shared services
- `@stores/*` - Shared stores
- `@hooks/*` - Shared hooks
- `@types/*` - Shared types
- `@utils/*` - Shared utilities
- `@lib/*` - Shared library configurations

## Guidelines

1. **Platform-Agnostic Code**: All code in this directory must work on both web and mobile platforms
2. **No Platform-Specific Dependencies**: Avoid importing React DOM or React Native specific modules
3. **Pure Business Logic**: Keep UI components separate in platform-specific directories
4. **Type Safety**: Use TypeScript for all shared code
5. **Testing**: Write unit tests for all shared services, hooks, and utilities

## What Goes Here

### Services (100% shared)
- API integration with Supabase
- Authentication logic
- Data fetching and mutations
- Real-time subscriptions
- File upload/download

### Stores (100% shared)
- Global state management with Zustand
- User authentication state
- Application settings
- Notification state
- Voice/video call state

### Hooks (90% shared)
- Data fetching hooks
- Real-time subscription hooks
- Business logic hooks
- Utility hooks (debounce, etc.)

### Types (100% shared)
- Database models
- API request/response types
- Application state types
- Utility types

### Utils (100% shared)
- Validation functions
- Error handling utilities
- Logging utilities
- Rate limiting
- Helper functions

### Lib (100% shared)
- Supabase client configuration
- React Query client configuration
- Other library configurations

## What Doesn't Go Here

- UI Components (use `src/components/` for web, `mobile/components/` for mobile)
- Navigation logic (use React Router for web, Expo Router for mobile)
- Platform-specific features (camera, biometrics, etc.)
- Styling (CSS for web, StyleSheet for mobile)
