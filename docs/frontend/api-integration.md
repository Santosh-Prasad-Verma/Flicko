# Frontend API Integration
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Service Layer
Location: `shared/services/` — 51 service files

### Key Services (by size/complexity)
| Service | File | Size | Purpose |
|---------|------|------|---------|
| `messageService.ts` | Message CRUD | 26 KB | Send, edit, delete, fetch messages |
| `botService.ts` | Bot management | 19 KB | Bot settings, commands |
| `mediaService.ts` | Media handling | 20 KB | Image/video processing |
| `realtimeService.ts` | Real-time subs | 14 KB | Supabase realtime subscriptions |
| `cloudinaryService.ts` | Media uploads | 12 KB | Signed Cloudinary uploads |
| `stripePaymentService.ts` | Payments | 12 KB | Subscription billing |
| `commandService.ts` | Slash commands | 10 KB | Command execution |
| `offlineService.ts` | Offline support | 9 KB | Offline message queue |
| `inviteService.ts` | Invites | 9 KB | Server invite management |
| `roleService.ts` | Roles | 9 KB | Role CRUD and permissions |
| `forumService.ts` | Forums | 9 KB | Forum channel support |
| `fileUploadService.ts` | File uploads | 9 KB | General file upload |

### API Client Pattern
All services use Supabase client for database operations:
```typescript
import { supabase } from '@shared/lib/supabase';

const { data, error } = await supabase
  .from('messages')
  .select('*')
  .eq('channel_id', channelId)
  .order('created_at', { ascending: false });
```

For Go backend calls:
```typescript
const response = await fetch(`${API_URL}/api/v1/endpoint`, {
  headers: { Authorization: `Bearer ${token}` }
});
```
