-- Rollback migration 071
DROP TABLE IF EXISTS music_events;
DROP TABLE IF EXISTS shared_playlists;
DROP TABLE IF EXISTS playback_idempotency;
DROP TABLE IF EXISTS spotify_sessions;
