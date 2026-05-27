-- Rollback migration 071
DROP TABLE IF EXISTS song_history;
DROP TABLE IF EXISTS playlist_tracks;
DROP TABLE IF EXISTS playlists;
DROP TABLE IF EXISTS music_settings;
DROP TABLE IF EXISTS music_queues;
DROP TABLE IF EXISTS music_events;
DROP TABLE IF EXISTS shared_playlists;
DROP TABLE IF EXISTS playback_idempotency;
DROP TABLE IF EXISTS spotify_sessions;
