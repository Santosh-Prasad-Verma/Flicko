import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Service managing encrypted offline track downloads and local storage
class OfflineDownloaderService {
  static final OfflineDownloaderService instance = OfflineDownloaderService._internal();
  OfflineDownloaderService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Dio _dio = Dio();
  
  static const String _downloadsKeyPrefix = 'offline_track_';
  static const String _indexKey = 'offline_tracks_index';

  final _downloadProgressController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get downloadProgressStream => _downloadProgressController.stream;
  
  final Map<String, double> _activeProgress = {};

  /// Get the directory path for offline music storage
  Future<Directory> _getOfflineDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${docsDir.path}/sonic_offline_music');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }

  /// Download a track and save encrypted metadata
  Future<String?> downloadTrack({
    required String trackId,
    required String downloadUrl,
    required String title,
    required String artist,
    String? album,
    String? image,
    Duration? duration,
  }) async {
    try {
      final offlineDir = await _getOfflineDirectory();
      final filePath = '${offlineDir.path}/$trackId.m4a';

      _activeProgress[trackId] = 0.0;
      _downloadProgressController.add(Map.from(_activeProgress));

      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            _activeProgress[trackId] = progress;
            _downloadProgressController.add(Map.from(_activeProgress));
          }
        },
      );

      _activeProgress.remove(trackId);
      _downloadProgressController.add(Map.from(_activeProgress));

      // Save encrypted metadata in Secure Storage
      final metadata = {
        'id': trackId,
        'title': title,
        'artist': artist,
        'album': album ?? '',
        'image': image ?? '',
        'localPath': filePath,
        'durationMs': duration?.inMilliseconds ?? 0,
        'downloadedAt': DateTime.now().toIso8601String(),
      };

      await _secureStorage.write(
        key: '$_downloadsKeyPrefix$trackId',
        value: jsonEncode(metadata),
      );

      // Update index
      final indexStr = await _secureStorage.read(key: _indexKey);
      final Set<String> index = indexStr != null ? Set<String>.from(jsonDecode(indexStr)) : {};
      index.add(trackId);
      await _secureStorage.write(key: _indexKey, value: jsonEncode(index.toList()));

      debugPrint('🎵 Track downloaded and encrypted successfully: $title -> $filePath');
      return filePath;
    } catch (e, stack) {
      debugPrint('❌ Failed to download track $trackId: $e\n$stack');
      _activeProgress.remove(trackId);
      _downloadProgressController.add(Map.from(_activeProgress));
      return null;
    }
  }

  /// Check if a track is downloaded
  Future<bool> isTrackDownloaded(String trackId) async {
    final metadataStr = await _secureStorage.read(key: '$_downloadsKeyPrefix$trackId');
    if (metadataStr == null) return false;
    try {
      final map = jsonDecode(metadataStr);
      final file = File(map['localPath']);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Get local file URI/path if downloaded
  Future<String?> getDownloadedTrackPath(String trackId) async {
    final metadataStr = await _secureStorage.read(key: '$_downloadsKeyPrefix$trackId');
    if (metadataStr == null) return null;
    try {
      final map = jsonDecode(metadataStr);
      final filePath = map['localPath'] as String;
      if (await File(filePath).exists()) {
        return filePath;
      }
    } catch (_) {}
    return null;
  }

  /// Get list of all downloaded track metadata
  Future<List<Map<String, dynamic>>> getDownloadedTracks() async {
    final indexStr = await _secureStorage.read(key: _indexKey);
    if (indexStr == null) return [];
    try {
      final List<dynamic> ids = jsonDecode(indexStr);
      final List<Map<String, dynamic>> tracks = [];
      for (final id in ids) {
        final metaStr = await _secureStorage.read(key: '$_downloadsKeyPrefix$id');
        if (metaStr != null) {
          final map = jsonDecode(metaStr) as Map<String, dynamic>;
          if (await File(map['localPath']).exists()) {
            tracks.add(map);
          }
        }
      }
      return tracks;
    } catch (e) {
      debugPrint('Error loading downloaded tracks: $e');
      return [];
    }
  }

  /// Delete a downloaded track
  Future<bool> deleteDownloadedTrack(String trackId) async {
    final metadataStr = await _secureStorage.read(key: '$_downloadsKeyPrefix$trackId');
    if (metadataStr != null) {
      try {
        final map = jsonDecode(metadataStr);
        final file = File(map['localPath']);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      await _secureStorage.delete(key: '$_downloadsKeyPrefix$trackId');
    }

    final indexStr = await _secureStorage.read(key: _indexKey);
    if (indexStr != null) {
      final List<dynamic> ids = jsonDecode(indexStr);
      ids.remove(trackId);
      await _secureStorage.write(key: _indexKey, value: jsonEncode(ids));
    }
    return true;
  }
}
