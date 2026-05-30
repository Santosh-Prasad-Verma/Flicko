# Gesture Controls — Schema

Client-only feature. Preferences stored on `user_settings.gestures` JSONB column.

```sql
ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS gestures JSONB NOT NULL DEFAULT '{
    "swipeReply": {"enabled": true, "direction": "rtl"},
    "doubleTapReact": {"enabled": true, "defaultEmoji": "❤"},
    "longPressMenu": {"enabled": true},
    "threeFingerUndo": {"enabled": true},
    "twoFingerNav": {"enabled": true},
    "haptics": {"enabled": true}
  }'::jsonb;
```

No RLS change (user_settings already self-only). No new tables. Local Hive box for in-session undo stack:

```dart
@HiveType(typeId: 91)
class UndoableAction {
  @HiveField(0) String kind; // delete | edit | react
  @HiveField(1) String messageId;
  @HiveField(2) Map<String,dynamic> payload;
  @HiveField(3) DateTime at;
}
```
TTL: keep last 20 actions, drop after 5 min.

## Cache
- None server-side.

## Storage
- None.

## Migration
- `supabase/migrations/146_gestures_pref.up.sql`
