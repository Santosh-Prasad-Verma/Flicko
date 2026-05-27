import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/music_models.dart';

/// Download status
enum DownloadStatus { pending, downloading, completed, failed, paused }

/// Download task
class DownloadTask {
  final Track track;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? localPath;
  final String? error;
  final DateTime startedAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.track,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.localPath,
    this.error,
    required this.startedAt,
    this.completedAt,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? error,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      track: track,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Downloads state
class DownloadsState {
  final Map<String, DownloadTask> tasks;
  final List<Track> downloadedTracks;
  final bool isDownloading;

  const DownloadsState({
    this.tasks = const {},
    this.downloadedTracks = const [],
    this.isDownloading = false,
  });

  DownloadTask? getTask(String trackId) => tasks[trackId];
  bool isDownloaded(String trackId) => downloadedTracks.any((t) => t.id == trackId);
  String? getLocalPath(String trackId) => tasks[trackId]?.localPath;

  DownloadsState copyWith({
    Map<String, DownloadTask>? tasks,
    List<Track>? downloadedTracks,
    bool? isDownloading,
  }) {
    return DownloadsState(
      tasks: tasks ?? this.tasks,
      downloadedTracks: downloadedTracks ?? this.downloadedTracks,
      isDownloading: isDownloading ?? this.isDownloading,
    );
  }
}

/// Service for downloading tracks for offline playback
abstract class DownloadService {
  Future<void> download(Track track, String streamUrl);
  Future<void> pause(String trackId);
  Future<void> resume(String trackId);
  Future<void> cancel(String trackId);
  Future<void> delete(String trackId);
  Future<String?> getLocalPath(String trackId);
  Future<List<Track>> getDownloadedTracks();
  Future<int> getTotalDownloadSize();
  Future<void> clearAllDownloads();
}

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadServiceImpl(ref);
});

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, DownloadsState>(DownloadsNotifier.new);

class DownloadsNotifier extends Notifier<DownloadsState> {
  late final DownloadService _service;

  @override
  DownloadsState build() {
    _service = ref.read(downloadServiceProvider);
    _loadDownloads();
    return const DownloadsState();
  }

  Future<void> _loadDownloads() async {
    final tracks = await _service.getDownloadedTracks();
    state = state.copyWith(downloadedTracks: tracks);
  }

  Future<void> download(Track track, String streamUrl) async {
    if (state.isDownloaded(track.id)) return;

    // Add pending task
    state = state.copyWith(
      tasks: {...state.tasks, track.id: DownloadTask(
        track: track,
        status: DownloadStatus.pending,
        startedAt: DateTime.now(),
      )},
    );

    await _service.download(track, streamUrl);
    await _loadDownloads();
  }

  Future<void> pause(String trackId) async {
    await _service.pause(trackId);
    final task = state.tasks[trackId];
    if (task != null) {
      state = state.copyWith(
        tasks: {...state.tasks, trackId: task.copyWith(status: DownloadStatus.paused)},
      );
    }
  }

  Future<void> resume(String trackId) async {
    await _service.resume(trackId);
    final task = state.tasks[trackId];
    if (task != null) {
      state = state.copyWith(
        tasks: {...state.tasks, trackId: task.copyWith(status: DownloadStatus.downloading)},
      );
    }
  }

  Future<void> cancel(String trackId) async {
    await _service.cancel(trackId);
    final newTasks = Map<String, DownloadTask>.from(state.tasks);
    newTasks.remove(trackId);
    state = state.copyWith(tasks: newTasks);
  }

  Future<void> delete(String trackId) async {
    await _service.delete(trackId);
    final newTasks = Map<String, DownloadTask>.from(state.tasks);
    newTasks.remove(trackId);
    final newTracks = state.downloadedTracks.where((t) => t.id != trackId).toList();
    state = state.copyWith(tasks: newTasks, downloadedTracks: newTracks);
  }

  void updateProgress(String trackId, double progress) {
    final task = state.tasks[trackId];
    if (task != null) {
      state = state.copyWith(
        tasks: {...state.tasks, trackId: task.copyWith(
          status: DownloadStatus.downloading,
          progress: progress,
        )},
      );
    }
  }

  void complete(String trackId, String localPath) {
    final task = state.tasks[trackId];
    if (task != null) {
      final newTask = task.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: localPath,
        completedAt: DateTime.now(),
      );
      state = state.copyWith(
        tasks: {...state.tasks, trackId: newTask},
        downloadedTracks: [...state.downloadedTracks.where((t) => t.id != trackId), task.track],
      );
    }
  }

  void fail(String trackId, String error) {
    final task = state.tasks[trackId];
    if (task != null) {
      state = state.copyWith(
        tasks: {...state.tasks, trackId: task.copyWith(
          status: DownloadStatus.failed,
          error: error,
        )},
      );
    }
  }

  Future<void> clearAll() async {
    await _service.clearAllDownloads();
    state = const DownloadsState();
  }
}

class DownloadServiceImpl implements DownloadService {
  final Ref _ref;
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  static const _downloadsDir = 'music_downloads';

  DownloadServiceImpl(this._ref);

  Future<Directory> _getDownloadsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_downloadsDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _filenameFor(Track track) => '${track.id}.m4a';

  @override
  Future<void> download(Track track, String streamUrl) async {
    final cancelToken = CancelToken();
    _cancelTokens[track.id] = cancelToken;

    try {
      final dir = await _getDownloadsDir();
      final fileName = _filenameFor(track);
      final localPath = '${dir.path}/$fileName';

      await _dio.download(
        streamUrl,
        localPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            _ref.read(downloadsProvider.notifier).updateProgress(track.id, progress);
          }
        },
      );

      // Save metadata
      await _saveTrackMetadata(track, localPath);

      _ref.read(downloadsProvider.notifier).complete(track.id, localPath);
      _cancelTokens.remove(track.id);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        dev.log('Download cancelled: ${track.name}', name: 'download');
      } else {
        dev.log('Download error: $e', name: 'download');
        _ref.read(downloadsProvider.notifier).fail(track.id, e.toString());
      }
    }
  }

  @override
  Future<void> pause(String trackId) async {
    _cancelTokens[trackId]?.cancel();
    _cancelTokens.remove(trackId);
  }

  @override
  Future<void> resume(String trackId) async {
    final task = _ref.read(downloadsProvider).tasks[trackId];
    if (task == null) {
      dev.log('Resume requested but no task for $trackId', name: 'download');
      return;
    }
    final dir = await _getDownloadsDir();
    final localPath = '${dir.path}/${_filenameFor(task.track)}';
    final file = File(localPath);
    int existingBytes = 0;
    if (await file.exists()) {
      existingBytes = await file.length();
    }

    final cancelToken = CancelToken();
    _cancelTokens[trackId] = cancelToken;

    final streamUrl = task.track.previewUrl;
    if (streamUrl == null || streamUrl.isEmpty) {
      _ref.read(downloadsProvider.notifier).fail(trackId, 'no source URL to resume');
      return;
    }

    try {
      _ref.read(downloadsProvider.notifier).updateProgress(trackId, task.progress);
      await _dio.download(
        streamUrl,
        localPath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(headers: {
          if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
        }),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (existingBytes + received) / (existingBytes + total);
            _ref.read(downloadsProvider.notifier).updateProgress(trackId, progress.clamp(0.0, 1.0));
          }
        },
      );
      await _saveTrackMetadata(task.track, localPath);
      _ref.read(downloadsProvider.notifier).complete(trackId, localPath);
      _cancelTokens.remove(trackId);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        dev.log('Resume paused: ${task.track.name}', name: 'download');
      } else {
        dev.log('Resume error: $e', name: 'download');
        _ref.read(downloadsProvider.notifier).fail(trackId, e.toString());
      }
    }
  }

  @override
  Future<void> cancel(String trackId) async {
    _cancelTokens[trackId]?.cancel();
    _cancelTokens.remove(trackId);
    
    // Delete partial file
    final path = await getLocalPath(trackId);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<void> delete(String trackId) async {
    await cancel(trackId);

    // Delete local file by exact name match (avoids prefix collisions where
    // trackId "12345" would also match "123456.m4a").
    final dir = await _getDownloadsDir();
    final exactName = '$trackId.m4a';
    final files = await dir.list().toList();
    for (final entity in files) {
      if (entity is File && entity.uri.pathSegments.last == exactName) {
        await entity.delete();
      }
    }

    // Remove metadata
    final prefs = await SharedPreferences.getInstance();
    final metaKey = 'download_meta_$trackId';
    await prefs.remove(metaKey);
  }

  @override
  Future<String?> getLocalPath(String trackId) async {
    final dir = await _getDownloadsDir();
    final exactName = '$trackId.m4a';
    final file = File('${dir.path}/$exactName');
    if (await file.exists()) return file.path;
    return null;
  }

  @override
  Future<List<Track>> getDownloadedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('download_meta_'));
    final tracks = <Track>[];

    for (final key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
          final track = _trackFromJson(jsonMap);
          // Verify file still exists
          final localPath = await getLocalPath(track.id);
          if (localPath != null) {
            tracks.add(track);
          }
        } catch (_) {}
      }
    }

    return tracks;
  }

  @override
  Future<int> getTotalDownloadSize() async {
    final dir = await _getDownloadsDir();
    int totalSize = 0;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  @override
  Future<void> clearAllDownloads() async {
    final dir = await _getDownloadsDir();
    await for (final entity in dir.list()) {
      await entity.delete();
    }

    // Clear metadata
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('download_meta_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> _saveTrackMetadata(Track track, String localPath) async {
    final prefs = await SharedPreferences.getInstance();
    final metaKey = 'download_meta_${track.id}';
    await prefs.setString(metaKey, jsonEncode(_trackToMap(track, localPath)));
  }

  Map<String, dynamic> _trackToMap(Track track, String? localPath) => {
        'id': track.id,
        'name': track.name,
        'artistName': track.artistName,
        'albumName': track.albumName,
        'durationMs': track.durationMs,
        'imageUrl': track.imageUrl,
        'previewUrl': track.previewUrl,
        'externalUrl': track.externalUrl,
        'source': track.source,
        if (localPath != null) 'localPath': localPath,
      };

  Track _trackFromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Unknown',
        artistName: json['artistName'] as String? ?? 'Unknown Artist',
        albumName: json['albumName'] as String?,
        durationMs: json['durationMs'] as int?,
        imageUrl: json['imageUrl'] as String?,
        previewUrl: json['previewUrl'] as String?,
        externalUrl: json['externalUrl'] as String?,
        source: json['source'] as String? ?? 'saavn',
      );
}
