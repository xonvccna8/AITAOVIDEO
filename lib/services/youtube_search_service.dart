import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chemivision/core/config/api_keys.dart';

class YouTubeVideoItem {
  final String id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String channelTitle;

  const YouTubeVideoItem({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.channelTitle,
  });
}

class YouTubeSearchService {
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  static Future<List<YouTubeVideoItem>> searchTopVideos(
    String query, {
    int maxResults = 5,
    String language = 'vi',
  }) async {
    if (ApiKeys.youtubeApiKey.isEmpty) return [];

    final qp = {
      'key': ApiKeys.youtubeApiKey,
      'part': 'snippet',
      'q': query,
      'maxResults': '$maxResults',
      'type': 'video',
      'order': 'relevance',
      'relevanceLanguage': language,
      'safeSearch': 'moderate',
    };

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: qp);
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];

    final data = json.decode(utf8.decode(resp.bodyBytes));
    final List items = data['items'] ?? [];
    final List<YouTubeVideoItem> videos = [];
    for (final item in items) {
      final videoId = item['id']?['videoId'];
      final snippet = item['snippet'] ?? {};
      if (videoId == null) continue;
      videos.add(
        YouTubeVideoItem(
          id: videoId,
          title: (snippet['title'] ?? '').toString(),
          url: 'https://www.youtube.com/watch?v=$videoId',
          thumbnailUrl:
              snippet['thumbnails']?['high']?['url'] ??
              snippet['thumbnails']?['medium']?['url'] ??
              '',
          channelTitle: (snippet['channelTitle'] ?? '').toString(),
        ),
      );
    }
    return videos;
  }
}


