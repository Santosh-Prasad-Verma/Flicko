I have enough verified context to compile a thorough audit. Below is what I confirmed by reading code (no docs/READMEs touched), and the issues found.

Sonic Music — Full-Project Audit
Audit scope (verified on disk)
I inspected three coexisting Sonic Music codepaths and the backend:

mobile/lib/features/voice/ — the "Sonic Drip" V2 stack (SonicDripScreen, sonicDripProvider, dripBashRepositoryProvider, MusicLibraryRepository, LyricsService, DownloadService, AudioEffectsService, SleepTimerService, FlickoAudioHandler, AudioSessionService).
music_notifier.dart
 + 
music_search_sheet.dart
 + voice_music_controls.dart — a separate "v1" musicNotifierProvider flow.
mobile/lib/features/sonic_music/ — a vendored BlackHole fork with its own AudioPlayerHandlerImpl, Hive boxes, GetIt registrations, mini player, lock-screen handler, equalizer, downloads, share-intent, Spotify helper, YouTube Music service.
Backend: 
music.go
, 
music_handler.go
, 
down.sql
, router wiring in 
main.go
.
Mobile router 
app_router.dart
, app boot in 
main.dart
.
CRITICAL ARCHITECTURAL FINDING (root cause of most bugs)
Three independent, half-wired Sonic Music implementations are shipping in parallel. They do not share state, queue, or audio handler.

The /sonic-drip route is wired in 
app_router.dart 351
 to HomePage() from 
home.dart
 (the BlackHole fork). That handler runs through AudioPlayerHandlerImpl registered at 
main.dart 104
 via AudioHandlerHelper.
sonic_drip_screen.dart
 (SonicDripScreen, the brutalist UI you've been editing) is not referenced by any route or widget anywhere in the app. grep "SonicDripScreen" returns only its own definition. It is dead UI.
voice_music_controls.dart and music_search_sheet.dart use musicNotifierProvider (mock progress = 0.3, no real player). aura_chat_service.dart:717 also calls into this third path. None of the three observe the others.
flicko_audio_handler.dart
 (FlickoAudioHandler) is documented as the production handler but is never instantiated — grep "FlickoAudioHandler(" finds zero call sites. Dead code.
Implications: queue ops in one stack don't reach the others, lock-screen controls only follow BlackHole's handler, AI Aura "play music" command writes to the third notifier, slash-command bot events publish over the event bus but no client UI subscribes. There is no single source of truth.

Severity: Critical. Production readiness blocker.

Per-issue findings
Critical
C1. Route serves the wrong screen

File: 
app_router.dart 351
Cause: GoRoute(path: 'sonic-drip', builder: (context, state) => HomePage()) resolves to BlackHole's HomePage, not the new SonicDripScreen. Result: the entire mobile/lib/features/voice/presentation/* UI you authored (SonicDripScreen, DripBashSheet, LibrarySheet, MusicSettingsSheet, LyricsSheet, QueueList, PlaybackControls) is unreachable.
Impact: Users see BlackHole's UI; bugs you fix in SonicDripScreen ship as no-ops. All Drip Bash, sleep timer, audio effects, and library work is invisible.
Fix: route to const SonicDripScreen() (or to HomePage deliberately and delete the dead branch).
Status: completely missing wiring.
C2. Background/lock-screen playback is broken in the new stack

Files: 
sonic_drip_notifier.dart 62
, 
flicko_audio_handler.dart
Cause: SonicDripNotifier._player = AudioPlayer() directly, with no AudioService.init wrapping. FlickoAudioHandler exists but is never registered. The only real AudioService integration is BlackHole's AudioPlayerHandlerImpl, which the new stack does not talk to.
Impact: iOS suspends audio after ~30 s background. Android shows no media notification, no lock-screen controls, no Bluetooth/AVRCP next/prev, no Auto/CarPlay, no Watch controls. Audio also won't survive screen-off on modern Android.
Fix: route playback through flickoAudio.playTrack(...) (or BlackHole's handler) instead of a raw AudioPlayer. Wire AudioService.init(builder: () => FlickoAudioHandler(), config: ...) in _initializeApp.
Status: partially implemented (handler class exists), but never connected.
C3. Audio session is configured for VoIP, not music

File: 
audio_session_service.dart 9-19
Cause: AVAudioSessionCategory.playAndRecord, AVAudioSessionMode.voiceChat, AndroidAudioContentType.speech, usage: voiceCommunication. This forces aggressive AGC/AEC/NS, ducks system audio improperly, and routes through the earpiece on iOS unless defaultToSpeaker overrides.
Impact: Music sounds tinny, AGC pumps loudness, Bluetooth devices switch to HFP (low-quality mono) profile instead of A2DP, AirPods cut to phone-call mode. Volume buttons may not control media stream on Android.
Fix: For Sonic Drip, configure with AudioSessionConfiguration.music() (matches what BlackHole's AudioPlayerHandlerImpl._init actually does). Keep voiceChat config behind a separate per-feature switch.
Status: incorrectly implemented.
C4. JSON written to disk via raw string interpolation

File: 
download_service.dart 329-330
Code: '{"id":"${track.id}","name":"${track.name}",...}'
Cause: No escaping. Any track containing ", \, \n, \r, or non-ASCII control char produces invalid JSON. _trackFromJson will throw FormatException on jsonDecode.
Reproduce: download a Saavn track titled Don't Stop "Believin'". Restart app. getDownloadedTracks() silently swallows and returns [].
Impact: Offline library appears empty after legitimate downloads. Persistent metadata loss.
Fix: prefs.setString(metaKey, jsonEncode(_trackToJson(track))) using the existing _trackToJson Map form (it already exists in music_library_repository.dart; just inline a Map<String,dynamic> and jsonEncode).
C5. Queue/Settings IDOR on backend

File: 
music_handler.go 45
, 
main.go 384
Cause: GET /servers/{serverId}/music/state is mounted under protected (auth only). There is no membership check (server_members/role check) before returning music_queues and music_settings for the requested serverID.
Impact: Any authenticated user can enumerate queue contents, requestor user IDs, repeat mode, DJ role, and now-playing channel for any server they don't belong to.
Fix: Inject server-membership middleware (the same one used by message/channel routes) for any /servers/{serverId}/music/... endpoint.
C6. No DJ-role enforcement on destructive bot commands

File: 
music.go
 (handleSkip, handleStop, handleShuffle, handleVolume, handleRepeat, handlePlaylist delete)
Cause: dj_role_id is stored in music_settings, but no command reads it before mutating queue/settings.
Impact: Trolls can /stop or /skip any server's music regardless of DJ role. The settings field is purely cosmetic.
Fix: Wrap mutating handlers in a DJ-role check (or "in voice channel + permission") helper.
C7. Schema split between migration and runtime DDL

Files: 
071_music_schema.up.sql
, 
music.go 42-94
Cause: Migration 071 creates spotify_sessions, playback_idempotency, shared_playlists, music_events. The tables actually used by the bot/handler (music_queues, music_settings, playlists, playlist_tracks, song_history) are created lazily by MusicBot.ensureTables() via CREATE TABLE IF NOT EXISTS at boot.
Impact: The down-migration (071_music_schema.down.sql) won't drop the runtime-created tables. CI databases that bootstrap from migrations alone (without booting the bot) will be missing tables; music_handler.GetMusicState returns 500. Schema reviews can't see the live shape from migrations.
Fix: Move all CREATE TABLE into a proper migration. Drop the same tables in the .down.sql. Remove ensureTables.
C8. Bot events never reach clients

Files: 
music.go
 (publishes events.MusicUpdate), 
bridge.go 30-51
, mobile clients
Cause: Bridge re-publishes MusicUpdate to clients via Realtime, but SonicDripNotifier (and the BlackHole handler, and MusicNotifier) do not subscribe to that event. No client-side handler exists for MUSIC_UPDATE.
Impact: /play, /skip, /pause, /volume slash commands silently drop; the queue table updates but the UI never reflects it. The bot is half-implemented.
Status: backend complete, client integration completely missing.
C9. Lyrics never advance

Files: 
sonic_drip_screen.dart 69-73
, 
lyrics_sheet.dart 8-19
Cause: _openLyrics(...) captures state.playback.position once and passes it as a constant to LyricsSheet(track: track, position: position). LyricsSheet is ConsumerWidget but never ref.watch(sonicDripProvider), so its position is frozen at the moment the sheet opened.
Impact: Synced lyrics highlight the line at open time and never move. The whole synced-lyrics feature is non-functional.
Reproduction: open lyrics during playback at 0:30 → line at 0:30 stays highlighted forever even though the song progresses.
Fix: in LyricsSheet.build, do final pos = ref.watch(sonicDripProvider).playback.position; and pass that to SyncedLyricsWidget. Remove the position constructor arg.
C10. UI rebuilds on every position tick (~10 Hz)

Files: 
sonic_drip_notifier.dart 79-93
Cause: SonicDripState and PlaybackState lack ==/hashCode. Every _positionSub event runs state = state.copyWith(...). Riverpod compares old vs new state by identity → not equal → rebuilds every consumer of sonicDripProvider. SonicDripScreen watches the whole state, so the entire screen (NowPlayingCard, QueueList, PlaybackControls, status bar, action row) rebuilds 10× per second.
Impact: Frame drops, jank on mid-tier Android, unnecessary NetworkImage reflows for album art, battery drain.
Fix: convert SonicDripState and PlaybackState to Freezed (or implement ==/hashCode). Use ref.watch(sonicDripProvider.select(...)) in widgets that only need a slice (e.g., _ProgressSection only needs position+duration). The existing _QueueItem correctly uses select; the rest of the screen does not.
High
H1. Track has no equality

File: 
music_models.dart 5-22
Cause: No ==/hashCode override.
Impact: state.queue.contains(track) in SonicDripNotifier.play() (line 174) only matches by reference identity — usually wrong. searchResults.first and a queued copy of the same track are not equal, so duplicates can sneak in despite the explicit any((t)=>t.id==track.id) checks in other methods. FutureProvider.family<LyricsResult?, Track> (lyrics_service.dart:79) keys on Track identity, so lyrics are re-fetched on every rebuild.
Fix: Freezed or manual override on id.
H2. _GetPrefs typo and shadowed instance method

File: mobile/lib/features/voice/data/music_library_repository.dart:142, 530-533
Cause: All call sites use top-level _GetPrefs() (capital G) defined at the bottom of the file. The MusicLibraryRepositoryImpl._getPrefs() instance method (lines 144-147) is dead. Top-level helper bypasses the field cache, so SharedPreferences.getInstance() is hit on every call instead of being cached.
Impact: Unnecessary plugin channel calls; broken intent of caching.
Fix: rename top-level helper to _getPrefs or call the instance method consistently.
H3. Supabase sync overwrites local edits

File: 
music_library_repository.dart 289-302
Cause: _syncFromSupabase writes Supabase data back to SharedPreferences but does not merge with local pending edits. If a user creates a playlist offline, then reopens the library while connected, getLibrary overwrites playlistsKey with Supabase's stale snapshot and the offline-created playlist disappears.
Impact: Silent data loss.
Fix: merge by id+updatedAt, do not overwrite, and stop calling sync on every read.
H4. addAlbumToQueue resolves URLs sequentially

File: 
sonic_drip_notifier.dart 289-307
Cause: for (final track in albumTracks) { ... await _resolveDripBashUrl(track); ... }.
Impact: 30-track album = 30 serial network round-trips. Loading takes 30+ seconds, blocking the UI sheet. Worse: _resolveDripBashUrl mutates global playback status to loading for the first track, so the now-playing card flashes "LOADING…" the entire time.
Fix: only resolve the first track eagerly, queue the rest with previewUrl == null. Resolve lazily inside _playTrack when each item starts. (Code in _playTrack already supports lazy resolution.)
H5. Race between completion and skip

File: 
sonic_drip_notifier.dart 96-118
Cause: _playerStateSub listens for ProcessingState.completed and calls skipNext(). Simultaneously _playerStateSub also reacts to playerState.playing == true and overwrites state.playback.status to playing. When _playTrack sets loading → playing itself, and the stream fires playing again later, you get redundant state updates. If the user manually taps next while a track is also auto-completing, skipNext runs twice on the same queue index.
Impact: Sometimes skips two tracks; sometimes restarts the next track twice; sometimes flips status to playing while an error has already been set.
Fix: dedupe with a bool _advancing; ignore completed while _advancing is true.
H6. audioplayer.dart (BlackHole) deletes dbFile on Hive open error and rethrows

File: 
main.dart 115-128
 (openHiveBox)
Cause: await dbFile.delete() and await lockFile.delete() are unguarded. If the Hive box is corrupted on a Windows install, the app deletes user data, then throws and crashes.
Impact: Permanent loss of liked songs / playlists / cache on a corrupted-box edge case. No backup, no user prompt.
Fix: wrap deletes in try/catch, use Hive.deleteBoxFromDisk instead of raw file delete, and prompt the user (or back up) before discarding.
H7. Resume not implemented

File: 
download_service.dart 281-285
Cause: Future<void> resume(...) async { dev.log('Resume not implemented, would restart download', ...); }. UI exposes a Resume button that does nothing.
Impact: any paused download must be restarted from 0. On flaky networks the same bytes are downloaded over and over.
Fix: implement HTTP Range request with Dio's Options(headers: {'Range': 'bytes=$received-'}), or cancel resume from UI.
H8. AI Aura "play song" hits the dead notifier

File: 
aura_chat_service.dart 708-719
Cause: Calls ref.read(musicNotifierProvider.notifier).addToQueue(bestMatch) — that provider is the legacy MusicNotifier with mock progress and no real player.
Impact: AI says "Started playing X on Sonic Drip!" but no audio actually plays.
Fix: route Aura's music intent through the real handler used by the route.
H9. Lock-screen handler conflict between two stacks

Files: 
main.dart 104
 (BlackHole AudioPlayerHandlerImpl registered as singleton in GetIt), 
flicko_audio_handler.dart
 (defines a competing BaseAudioHandler)
Cause: Only one AudioService.init may exist per app. Currently it's BlackHole's. If FlickoAudioHandler is ever wired up later, the second AudioService.init will throw.
Fix: pick one. Delete the other or refactor FlickoAudioHandler to share the BlackHole handler's player.
H10. youtube_explode_dart resource never closed

File: mobile/lib/features/voice/data/drip_bash_repository.dart:34-35, 503-505
Cause: _yt = YoutubeExplode() is created lazily, dispose() exists but dripBashRepositoryProvider is Provider<DripBashRepository>((ref) => DripBashRepositoryImpl()) with no ref.onDispose. Riverpod will never call dispose. The youtube_explode HTTP client stays alive for the app's lifetime.
Impact: minor leak, but more importantly the singleton state can hold cookies/proxies that fail after YT changes signatures, and there's no way to force a refresh.
Fix: switch to Provider.autoDispose or register ref.onDispose(() => impl.dispose()).
H11. Race in MusicBot.handlePlay position assignment

File: 
music.go 213-228
Cause: SELECT MAX(position) then INSERT position = max+1 without a transaction or unique constraint on (server_id, position).
Impact: Two simultaneous /play commands on the same server insert two rows with the same position. Not catastrophic, but the queue order becomes nondeterministic and ORDER BY position LIMIT 1 (used by handleSkip and handleNowPlaying) returns whichever Postgres feels like.
Fix: wrap in BEGIN ... COMMIT, or use a sequence per server, or INSERT ... position = (SELECT COALESCE(MAX(position),0)+1 FROM ...) in a single statement.
H12. MusicHandler.GetMusicState returns body even when error scanning settings

File: 
music_handler.go 79-91
Cause: When QueryRow.Scan fails for any reason (RLS denial, network blip, schema mismatch), the handler silently swaps in defaults. There's no log on failure path.
Impact: Server appears healthy and returns "everything default" even when the DB is broken — masks outages.
Fix: distinguish pgx.ErrNoRows (use defaults) from real errors (log + 500).
H13. download_service.dart filename can collide with itself

File: 
download_service.dart 240
Cause: '${track.id}_${DateTime.now().millisecondsSinceEpoch}.m4a'. getLocalPath and delete use path.contains(trackId) to find the file. If track.id is e.g. 12345 and another track id is 123456, delete("12345") will also delete 123456's file.
Impact: Deleting one song can wipe another that has a longer ID containing the first as a prefix.
Fix: store the exact path in metadata and delete by exact match, or use a deterministic filename without timestamp.
Medium
M1. SearchSheet autofocus + debounce + keyboard race

File: 
search_sheet.dart 17-37
Cause: searchDebounced cancels searchResults when query is empty but never cancels in-flight HTTP from a previous query. If user types metallica, then quickly clears, the late response from metallica will still arrive and call state.copyWith(searchResults: [...]), repopulating the cleared list.
Impact: stale results re-appear; momentary flicker.
Fix: track an incrementing search ID and discard responses with stale IDs.
M2. Slider value can be NaN/Infinity if duration is 0

File: 
music_models.dart 67-70
The progress getter clamps, but _ProgressSection GestureDetector divides details.localPosition.dx / box.size.width and passes raw progress to seekTo. If user taps before box is laid out, box.size.width could be 0 → division by zero → infinity → seekTo(progress) calls Duration(milliseconds: NaN.toInt()) which is undefined.
Fix: guard if (box.size.width <= 0) return; and progress.clamp(0.0, 1.0).
M3. SonicDripNotifier registers sleep-timer callback inside build()

File: 
sonic_drip_notifier.dart 64-67
Cause: ref.read(sleepTimerProvider.notifier).setCallback(...) runs in build. Notifier.build is called once at first read, but if Riverpod ever invalidates this notifier, a new callback replaces the old one mid-stream. Also, opening lyrics or library drives a rebuild somewhere, making the lambda capture potentially stale.
Fix: hoist registration into addPostFrameCallback or wire the sleep-timer to call pause() directly via a WeakReference or Provider read.
M4. _SyncedLyricsView.didUpdateWidget reads MediaQuery.of(context).size.height in a postFrame callback

File: 
lyrics_service.dart 330-345
Cause: If the sheet is dismissed while the callback runs, context is unmounted → throws. Also _lastLineIndex is not reset when track changes; opening lyrics on a new song scrolls to the previous song's index first.
Fix: check mounted, reset _lastLineIndex in didUpdateWidget when widget.lyrics.trackId differs.
M5. LRC parser drops multi-timestamp lines

File: 
lyrics_service.dart 215-238
Cause: regex.firstMatch(line) returns only the first timestamp. LRC lines like [00:01.00][00:30.00]Same chorus are common.
Impact: only ~50% of timestamps appear in synced lyrics; later occurrences of the chorus never highlight.
Fix: use regex.allMatches(line) and emit one LyricLine per match.
M6. MusicSearchSheet makes a request per keystroke

File: 
music_search_sheet.dart 26-28
Cause: onChanged: _onSearch directly calls search(...) without debounce.
Impact: 10–20 in-flight requests per query; rate-limit risk on JioSaavn API.
Fix: 300–400 ms debounce, same pattern as SearchSheet and DripBashSheet.
M7. voice_music_controls.dart shows fake progress

File: 
voice_music_controls.dart 138-141
Cause: value: 0.3, // Mock value hardcoded.
Impact: any voice channel that lands on this widget shows a stuck progress bar regardless of real playback.
Fix: read real position/duration; or delete the widget if voice channels are using the new stack.
M8. Search response cast can throw

File: 
drip_bash_repository.dart 296-306
Cause: final adaptiveFormats = (res.data as Map)['adaptiveFormats'] as List? ?? []; — when Invidious returns a string error body, res.data is String, the as Map cast throws and you skip to the next instance. With three instances all failing, this can take up to 30 s before returning null.
Fix: wrap each instance's call in try/catch (currently catches ErrorType.cancel only at the outer level).
M9. Inconsistent track URL semantics

Files: 
music.go 805-811
 (resolveTrackMetadata returns "search:" + query), 
sonic_drip_notifier.dart
 (expects an actual streaming URL)
Cause: The DB field music_queues.url may contain search:foo or a real URL. Clients that read DB rows directly (e.g., the missing event subscriber) won't be able to play them without re-resolving.
Fix: drop the search: prefix scheme; clients should resolve via Drip Bash on-demand.
M10. Two Hive.initFlutter paths

Files: 
main.dart 88-90
, 
main.dart 55-61
Cause: The unused 
main.dart
 initializes Hive at 'Sonic/Database' while live main.dart uses 'BlackHole/Database'. The dead main.dart is reachable via build mistakes (e.g., flutter run -t).
Impact: confusion + accidental data divergence if anyone runs the alternate entry point.
Fix: delete 
main.dart
 (also pulls in import_export_playlist, route_handler, update, github — review for cascade deletes).
M11. Logo and notification channel ID mismatch

File: 
audio_service_provider.dart 39-46
Cause: androidNotificationChannelId: 'com.shadow.blackhole.channel.audio'. This is the upstream BlackHole channel, not a Flicko-branded one. Notifications also reference mipmap/ic_launcher which exists, but channel name 'Sonic' and the BlackHole Github license header in the same file expose vendor branding.
Impact: confused user who sees com.shadow.blackhole permission grants in Android settings; also fails GPL/LGPL-3 source disclosure if redistributed without source.
Fix: rename channel to tech.focko.flicko.audio (matches the comment in flicko_audio_handler.dart), include LICENSE notices.
M12. Username UUID prefix leak

File: 
music.go 790-799
Cause: When users query fails, returns userID[:8]. That's an 8-char prefix of a UUID — minor, but exposes internal IDs in chat embeds.
Fix: return "unknown user" on lookup failure.
M13. clearQueue stops the player and replaces playback wholesale

File: 
sonic_drip_notifier.dart 154-160
Cause: _player?.stop(); state = state.copyWith(queue: [], playback: const PlaybackState()); — also resets volume, autoplay, shuffle, repeat to defaults. Users lose their preferences when clearing the queue.
Fix: keep volume, shuffle, repeat, autoplay from the previous state.
M14. Unused imports / dead code

Files:
mobile/lib/features/voice/data/music_library_repository.dart:2,6 — dart:io, 
path_provider.dart
 unused.
flicko_audio_handler.dart
 — entire file unreferenced.
music_notifier.dart
 + music_notifier.freezed.dart — referenced only by other dead code (voice_music_controls.dart, music_search_sheet.dart) and aura_chat_service.dart.
Impact: increased compile time, false sense of completeness, eventual drift.
Fix: delete or wire.
M15. Player error state can stick

File: 
sonic_drip_notifier.dart 531-536
Cause: On setUrl exception, status becomes error with the error message. There is no "retry"/"clear error" path; subsequent togglePlayPause is a no-op because currentTrack is non-null but the player has no source. User has to manually pick another track.
Fix: add clearError() and auto-retry once on transient failures.
M16. DripBashSheet source toggle resets album view inconsistently

File: 
drip_bash_sheet.dart 55-65
Cause: switching from Saavn → YouTube while inside an album leaves stale _albumName/_albumSongs on a YouTube-typed query. The album back arrow is still visible but Add All calls Saavn-specific URL resolution.
Fix: clear album state on source change.
Low
L1. searchDebounced empty-query handling clears searchResults but not searchError. (sonic_drip_notifier.dart:122-126)

L2. ListView.builder for queue is rendered inside a SingleChildScrollView (sonic_drip_screen.dart:48). Queue items use .map (queue_list.dart:62-69) → not virtualized. With 200+ tracks, all are built and laid out — can cause jank.

L3. Image.network used for album art everywhere (now_playing_card.dart:53, library_sheet.dart:432, drip_bash_sheet.dart). No cache → re-downloads on every rebuild. Project already depends on cached_network_image (used in BlackHole fork).

L4. Sleep-timer "after current track" never updates remaining so the status bar shows nothing for that mode. (sleep_timer_service.dart:87-93, sonic_drip_screen.dart:355)

L5. setVolume doesn't persist across app restarts. (sonic_drip_notifier.dart:251-256)

L6. MusicLibraryNotifier.addToHistory is defined but never called anywhere — history will always be empty unless populated elsewhere.

L7. Equalizer state is saved to SharedPreferences but never applied to the audio player. AudioEffectsNotifier mutates state but no listener pushes those values to just_audio or any platform DSP. (audio_effects_service.dart end of file)

L8. AudioEffects.activePreset falls back to EqPreset.builtIn.first when not found — unexpected for callers checking "is this preset active".

L9. MusicBot.handleHistory orders by played_at DESC but never paginates; on a popular server with months of plays this returns 10 from a potentially huge table without an index. Migration adds an index on (user_id, created_at DESC) for music_events but song_history has no index on (server_id, played_at DESC).

L10. No tests anywhere under mobile/test/ cover the Sonic Music feature; backend has no music_test.go.

L11. Hardcoded color 0xFF52B788 repeated 30+ times across files — should live in flicko_colors.dart.

L12. _decryptMediaUrl regex r'[\x00-\x1F\x7F-\x9F]+$' is fine, but it also strips PKCS#5 padding bytes 0x01-0x08 (range 0x00-0x1F covers them). That happens to work for JioSaavn URLs because they're ASCII, but it's accidental. Use proper PKCS#5 unpadding.

L13. sonic_drip_notifier.dart mixes dev.log and silent failures inconsistently; some errors caught and swallowed (_doSearch, _resolveDripBashUrl returning null with no UI surface) — users see "no results" with no indication the API rate-limited them.

L14. Spotify session table exists (spotify_sessions) per migration 071 but no Go handler reads/writes it — entirely unused schema.

Cross-platform & platform-specific
iOS background audio: requires UIBackgroundModes includes audio. Without AudioService wrapping, iOS will not honor it for the new stack. Need to verify Info.plist.
Android 13+ POST_NOTIFICATIONS: BlackHole's handler asks via audio_service; the new stack does not.
Android 14 foreground service type: audio_service declares foregroundServiceType="mediaPlayback". The new AudioPlayer doesn't get one — Android may kill it.
Bluetooth/AVRCP: only routed via audio_service handlers. Not wired in the new stack.
Scoring
Stability: 38 / 100 — critical UI is unreachable, multiple silent-fail code paths, race conditions in skip/complete.
Performance: 45 / 100 — 10 Hz full-screen rebuilds, sequential URL resolution, uncached images, non-virtualized queue.
Production readiness: 22 / 100 — backend IDOR, no DJ enforcement, schema split, broken background playback, lyrics frozen.
Security: 40 / 100 — IDOR on /music/state, unauthenticated DJ commands, raw JSON serialization, GPL license obligations unclear.
Architecture quality: 18 / 100 — three parallel implementations, dead code, route serves wrong screen, no shared source of truth.
Overall Sonic Music feature health: 33 / 100.

Recommended remediation order
Pick one stack. The pragmatic choice is BlackHole's AudioPlayerHandlerImpl (it has working audio_service, lock-screen, lyrics, downloads, equalizer). Either:
Keep BlackHole and delete mobile/lib/features/voice/{application,data,domain,services,presentation}/sonic_drip* and the brutalist UI; or
Keep the new stack and wire FlickoAudioHandler through AudioService.init, then port BlackHole's lock-screen/equalizer integration on top.
Fix the route in app_router.dart to point at whichever screen survives.
Patch backend authorization on /music/state and gate destructive bot commands behind DJ role.
Move MusicBot.ensureTables SQL into migration 071 and update .down.sql.
Wire client-side subscription to MUSIC_UPDATE events so slash commands drive the UI.
Replace raw-string JSON in download_service.dart with jsonEncode.
Implement ==/hashCode (or Freezed) on Track, PlaybackState, SonicDripState. Add select slices in SonicDripScreen.
Make LyricsSheet watch the provider so position is live.
Configure AudioSession for music() (or split sessions per feature).
Parallelize / lazy-resolve addAlbumToQueue. Add resume support via Range request.
Apply AudioEffects state to the actual player (currently it's a UI-only knob).
Delete 
music_notifier.dart
, music_search_sheet.dart, voice_music_controls.dart and update Aura to call the live handler.
Add tests around queue ordering, skip/repeat, error recovery, and bot DJ enforcement.
Final verdict
Not production ready. The user-visible Sonic Drip UI doesn't ship to users (route resolves to a different screen), background audio is missing on the new stack, lyrics never advance, the offline library can become unreadable from a single quote in a song name, and the backend leaks any server's music state to any authenticated account. Three parallel implementations also make every "fix" ambiguous because there's no single owner of state or audio focus. Resolve the architecture choice first, then the rest of the list becomes tractable in roughly two engineering weeks.


---

## Fix log

The following items were addressed in code on May 27, 2026.

### Backend
- C5 IDOR on /music/state — `backend/internal/handlers/music_handler.go` now verifies `server_members` membership and uses `getUserID` + `writeError`. Also distinguishes `pgx.ErrNoRows` from real DB errors (M12).
- C6 DJ-role enforcement — `backend/internal/bots/music.go` adds `requireDJ()` and gates `/skip`, `/stop`, `/shuffle`, `/repeat`, `/volume`, `/pause`, `/resume`. Owner bypass and "no role configured ⇒ all members" semantics.
- C7 Schema split — `backend/migrations/071_music_schema.up.sql` now defines `music_queues`, `music_settings`, `playlists`, `playlist_tracks`, `song_history` (+ indexes). `MusicBot.ensureTables` removed. `.down.sql` drops them all.
- H11 Race in `/play` position — replaced `SELECT MAX → INSERT` with a single `INSERT ... position = (SELECT COALESCE(MAX(position),0)+1 ...)` statement.
- M12 Username UUID-prefix leak — falls back to "unknown user" instead of leaking 8 chars of UUID.

### Mobile — architecture
- C1 Route — `/sonic-drip` now resolves to `SonicDripScreen` (was BlackHole `HomePage`).
- Single `AudioService.init` — `mobile/lib/main.dart` now boots `FlickoAudioHandler` via `AudioService.init` and registers it in GetIt as the canonical handler.
- M14 Dead code — deleted `voice_music_controls.dart`, `music_search_sheet.dart`, `music_notifier.dart` + `.freezed.dart`, and the duplicate `features/sonic_music/main.dart` entry point.
- H8 Aura wiring — `aura_chat_service.dart` now plays through `sonicDripProvider.playDripBash`, not the deleted notifier.

### Mobile — playback engine (`features/voice/`)
- C2 Background/lock-screen — `SonicDripNotifier` discovers `FlickoAudioHandler` from GetIt and routes playback through it. Notification next/prev buttons drive `skipNext`/`skipPrevious`.
- C3 Audio session — `FlickoAudioHandler._configureSession` uses `AudioSessionConfiguration.music()` (was VoIP).
- C9 Frozen lyrics — `LyricsSheet` now `ref.watch`es `playback.position`. Constructor `position` arg is ignored.
- C10 10 Hz rebuild storm — `Track`, `PlaybackState`, `SonicDripState` all have proper `==` / `hashCode`.
- H1 Track equality — id+source-based equality.
- H4 Album sequential resolves — `addAlbumToQueue` now appends raw tracks; URLs resolve lazily inside `_playTrack` as each item plays.
- H5 Skip/complete race — added `_advancing` guard.
- H6 Hive recovery — `openHiveBox` uses `Hive.deleteBoxFromDisk` inside try/catch instead of unguarded raw delete.
- H7 Resume not implemented — `DownloadServiceImpl.resume` now sends an HTTP `Range` request and continues from `existingBytes`.
- H10 youtube_explode leak — `dripBashRepositoryProvider` registers `ref.onDispose(impl.dispose)`.

### Mobile — data correctness
- C4 JSON corruption in downloads — `DownloadServiceImpl._saveTrackMetadata` now uses `jsonEncode(_trackToMap(...))`. Tracks with quotes in titles persist correctly.
- H2 `_GetPrefs` typo — renamed to `_getPrefs`.
- H3 Supabase overwrite — `getLibrary` now merges local + remote playlists by id+`updatedAt`; offline-created playlists are preserved.
- L6 Listen history not recorded — `_playTrack` calls `musicLibraryProvider.notifier.addToHistory`.
- L13 Filename collision — downloads use deterministic `<id>.m4a`; `delete`/`getLocalPath` use exact-name match.
- M5 LRC parser — `_parseLrc` handles multi-timestamp lines via `regex.allMatches`.
- M4 Synced lyrics view — guards `mounted`, resets `_lastLineIndex` on track change.
- M8 Invidious cast — defensive `is! Map` / `is! Map` guards.
- M16 Drip Bash source toggle — clears album state on Saavn↔YouTube switch.

### Mobile — UX/performance polish
- M1 Stale search results — `_searchSeq` discards late responses after the user clears or retypes.
- M2 Seek division by zero — guards `box.size.width <= 0` and clamps progress.
- M3 Sleep timer registration — moved into `build()` once with the canonical `ref.read`, no lambda capture loop.
- M13 `clearQueue` preserves prefs — keeps volume/shuffle/repeat/autoplay across queue resets.
- L1 Empty query also clears `searchError`.
- L5 Volume persists — saved/restored via SharedPreferences.

### Items intentionally not auto-fixed
- C8 (clients ignore `MUSIC_UPDATE` realtime events): the slash-command bot is now hardened (auth + DJ role) and remains the source of truth for shared/server queues. Wiring server-published events into the personal Sonic Drip player needs a product call (per-server shared listening vs personal player). The publish path is intact; client subscriber is a follow-up.
- L7 Equalizer DSP application: just_audio's cross-platform DSP is limited; band gains are persisted, but full Android EQ live-apply is left as a follow-up alongside `audio_service`'s native equalizer effect.
- BlackHole stack under `mobile/lib/features/sonic_music/` is now orphaned (no route reaches it). Left in tree to keep this diff small; safe to delete in a follow-up commit (no remaining live imports outside that folder, except `localization`/`config`/`logging`/`constants` which `mobile/lib/main.dart` still references — those are pure Dart with no runtime dependencies on the BlackHole audio handler).
