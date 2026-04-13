- **BUG-062 (Voice Token Edge Function Returns 500)**
  - Added proper `console.error` logs to all `supabase.*` calls in `supabase/functions/voice-token/index.ts` to catch silent Supabase failures (e.g. `voice_states` upsert, `streams` insert, `channel` lookup) that were returning error codes without logging.
- **BUG-005 (DM Conversation List Not Updating in Real-Time)**
  - Modified `dms.tsx` active subscription to listen to `*` instead of `INSERT`. Added `filter` correctly by breaking it down into two channels (`sender_id=eq.{id}` and `recipient_id=eq.{id}`) to overcome Realtime's lack of logical `OR` filtering in a single subscription payload.

- **BUG-006 (Message Edit Not Reflecting Immediately)**
  - Fixed `EditMessage` and `DeleteMessage` inside `/services/msg-service/internal/service/message_service.go` to correctly provide `msg.ChannelID` in the `s.publisher.PublishMessageUpdated` and `PublishMessageDeleted` calls, instead of empty strings.
