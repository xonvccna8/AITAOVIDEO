import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Model for a saved video in the gallery
class SavedVideo {
  final String id;
  final String videoUrl;
  final String title; // Text input or description
  final String sourceType; // 'text' or 'image'
  final DateTime createdAt;
  final String? thumbnailUrl; // Optional thumbnail URL

  SavedVideo({
    required this.id,
    required this.videoUrl,
    required this.title,
    required this.sourceType,
    required this.createdAt,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'title': title,
      'sourceType': sourceType,
      'createdAt': createdAt.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
    };
  }

  factory SavedVideo.fromJson(Map<String, dynamic> json) {
    return SavedVideo(
      id: json['id'] as String,
      videoUrl: json['videoUrl'] as String,
      title: json['title'] as String,
      sourceType: json['sourceType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}

/// Service to manage saved videos in the gallery
class GalleryService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final GalleryService _instance = GalleryService._internal();
  factory GalleryService() => _instance;
  GalleryService._internal();
  // ──────────────────────────────────────────────────────────────────────────

  static const String _fileName = 'gallery_videos.json';
  List<SavedVideo> _videos = [];

  /// Get all saved videos
  Future<List<SavedVideo>> getVideos() async {
    await _loadVideos();
    // Sort by creation date, newest first
    _videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(_videos);
  }

  /// Save a new video to the gallery
  Future<void> saveVideo({
    required String videoUrl,
    required String title,
    required String sourceType,
    String? thumbnailUrl,
  }) async {
    await _loadVideos();

    final video = SavedVideo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      videoUrl: videoUrl,
      title: title.isNotEmpty ? title : 'Video không có tiêu đề',
      sourceType: sourceType,
      createdAt: DateTime.now(),
      thumbnailUrl: thumbnailUrl,
    );

    _videos.add(video);
    await _saveVideos();
    notifyListeners();

    print('✅ [Gallery] Video saved: ${video.id} - $title');
  }

  /// Delete a video from the gallery
  Future<bool> deleteVideo(String videoId) async {
    await _loadVideos();
    final initialLength = _videos.length;
    _videos.removeWhere((video) => video.id == videoId);

    if (_videos.length < initialLength) {
      await _saveVideos();
      notifyListeners();
      print('✅ [Gallery] Video deleted: $videoId');
      return true;
    }
    return false;
  }

  /// Get video file path
  Future<File> _getVideoFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Load videos from storage
  Future<void> _loadVideos() async {
    try {
      final file = await _getVideoFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        final List<SavedVideo> loaded = [];
        for (final item in jsonList) {
          try {
            loaded.add(SavedVideo.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            print('⚠️ [Gallery] Skipped corrupted entry: $e');
          }
        }
        _videos = loaded;
        print('✅ [Gallery] Loaded ${_videos.length} videos');
      } else {
        _videos = [];
        print('ℹ️ [Gallery] No saved videos found');
      }
    } catch (e) {
      print('❌ [Gallery] Error loading videos: $e');
      _videos = [];
    }
  }

  /// Save videos to storage
  Future<void> _saveVideos() async {
    try {
      final file = await _getVideoFile();
      final jsonList = _videos.map((video) => video.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
      print('✅ [Gallery] Saved ${_videos.length} videos');
    } catch (e) {
      print('❌ [Gallery] Error saving videos: $e');
      rethrow;
    }
  }

  /// Clear all videos (for testing/debugging)
  Future<void> clearAll() async {
    _videos = [];
    await _saveVideos();
    print('✅ [Gallery] All videos cleared');
  }
}
