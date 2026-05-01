import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class VideoMergeService {
  /// Download a network video to a temp file; if already a local path, return as-is.
  static Future<String> _ensureLocal(String videoUrl, {String? suffix}) async {
    if (!videoUrl.startsWith('http')) {
      return videoUrl;
    }
    final tmpDir = await getTemporaryDirectory();
    final ts = DateTime.now().microsecondsSinceEpoch;
    final tag = suffix ?? ts.toString();
    final out = File('${tmpDir.path}/clip_$tag.mp4');
    if (out.existsSync()) {
      await out.delete();
    }
    final resp = await http.get(Uri.parse(videoUrl));
    if (resp.statusCode != 200) {
      throw Exception('Không thể tải video: HTTP ${resp.statusCode}');
    }
    await out.writeAsBytes(resp.bodyBytes);
    return out.path;
  }

  /// Merge 3 mp4 files sequentially into one mp4. Returns local output path.
  static Future<String> mergeThreeVideos({
    required String v1,
    required String v2,
    required String v3,
    void Function(String step)? onProgress,
  }) async {
    return mergeVideos(videos: [v1, v2, v3], onProgress: onProgress);
  }

  /// Merge N mp4 files sequentially into one mp4. Returns local output path.
  static Future<String> mergeVideos({
    required List<String> videos,
    void Function(String step)? onProgress,
  }) async {
    final total = videos.length;
    final mergeId = DateTime.now().microsecondsSinceEpoch.toString();
    final List<String> localPaths = [];
    for (int i = 0; i < total; i++) {
      onProgress?.call('Đang tải video ${i + 1}/$total...');
      final path = await _ensureLocal(
        videos[i],
        suffix: '${mergeId}_v${i + 1}',
      );
      localPaths.add(path);
    }

    // Write concat list file
    final tmpDir = await getTemporaryDirectory();
    final listFile = File('${tmpDir.path}/concat_list_$mergeId.txt');
    final buffer = StringBuffer();
    for (final p in localPaths) {
      buffer.writeln("file '${p.replaceAll("'", "\\'")}'");
    }
    await listFile.writeAsString(buffer.toString());

    final outputPath = '${tmpDir.path}/merged_$mergeId.mp4';

    onProgress?.call('Đang ghép $total video...');

    // Use concat demuxer (no re-encode, very fast)
    final cmd = '-f concat -safe 0 -i "${listFile.path}" -c copy "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getLogsAsString();
      throw Exception('FFmpeg ghép video thất bại:\n$logs');
    }

    // Clean up temp list file
    try {
      listFile.deleteSync();
    } catch (_) {}

    return outputPath;
  }
}
