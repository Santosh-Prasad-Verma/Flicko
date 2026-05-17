import 'package:freezed_annotation/freezed_annotation.dart';

part 'spotify_models.freezed.dart';
part 'spotify_models.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SpotifySession — stores the authenticated session (cookies only, never passwords)
// ─────────────────────────────────────────────────────────────────────────────

@freezed
abstract class SpotifySession with _$SpotifySession {
  const factory SpotifySession({
    /// Encrypted session cookies from Spotify WebView login
    required Map<String, String> cookies,

    /// When the session was established
    required DateTime connectedAt,

    /// Optional display name of the connected Spotify account
    String? displayName,

    /// Optional Spotify user ID
    String? spotifyUserId,
  }) = _SpotifySession;

  factory SpotifySession.fromJson(Map<String, dynamic> json) =>
      _$SpotifySessionFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// SpotifyTrack — a single track returned from search or playback state
// ─────────────────────────────────────────────────────────────────────────────

@freezed
abstract class SpotifyTrack with _$SpotifyTrack {
  const factory SpotifyTrack({
    /// Spotify track ID (e.g. "6l8GvAyoUZwFDuSbsxDpSR")
    required String id,

    /// Track display name
    required String name,

    /// Primary artist name
    required String artistName,

    /// Album name, if available
    String? albumName,

    /// Track duration in milliseconds
    @Default(0) int durationMs,

    /// Album artwork URL (300x300 preferred)
    String? imageUrl,

    /// Spotify deep-link URL
    String? externalUrl,

    /// URI used for playback (e.g. "spotify:track:6l8GvAyoUZwFDuSbsxDpSR")
    String? uri,
  }) = _SpotifyTrack;

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) =>
      _$SpotifyTrackFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// PlaybackState — current player state from the backend
// ─────────────────────────────────────────────────────────────────────────────

@freezed
abstract class PlaybackState with _$PlaybackState {
  const factory PlaybackState({
    /// Whether music is currently playing
    @Default(false) bool isPlaying,

    /// Current playback position in milliseconds
    @Default(0) int positionMs,

    /// Total track duration in milliseconds
    @Default(0) int durationMs,

    /// The track currently playing (null if nothing is playing)
    SpotifyTrack? currentTrack,

    /// Name of the active playback device
    String? deviceName,

    /// Current volume level (0–100)
    @Default(50) int volumePercent,

    /// Whether shuffle is enabled
    @Default(false) bool shuffleState,

    /// Repeat mode: "off", "track", "context"
    @Default('off') String repeatState,
  }) = _PlaybackState;

  factory PlaybackState.fromJson(Map<String, dynamic> json) =>
      _$PlaybackStateFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// SpotifyPlaylist — a user playlist
// ─────────────────────────────────────────────────────────────────────────────

@freezed
abstract class SpotifyPlaylist with _$SpotifyPlaylist {
  const factory SpotifyPlaylist({
    /// Playlist ID
    required String id,

    /// Playlist display name
    required String name,

    /// Optional description
    String? description,

    /// Cover image URL
    String? imageUrl,

    /// Number of tracks in the playlist
    @Default(0) int trackCount,

    /// Whether this playlist is public
    @Default(false) bool isPublic,

    /// Spotify deep-link URL
    String? externalUrl,
  }) = _SpotifyPlaylist;

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) =>
      _$SpotifyPlaylistFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// SpotifyDevice — a Spotify-connected playback device
// ─────────────────────────────────────────────────────────────────────────────

@freezed
abstract class SpotifyDevice with _$SpotifyDevice {
  const factory SpotifyDevice({
    /// Device ID
    required String id,

    /// Human-readable device name (e.g. "iPhone 15 Pro")
    required String name,

    /// Device type: "Computer", "Smartphone", "Speaker", etc.
    required String type,

    /// Whether this is the currently active device
    @Default(false) bool isActive,

    /// Current volume (0–100)
    @Default(50) int volumePercent,
  }) = _SpotifyDevice;

  factory SpotifyDevice.fromJson(Map<String, dynamic> json) =>
      _$SpotifyDeviceFromJson(json);
}
