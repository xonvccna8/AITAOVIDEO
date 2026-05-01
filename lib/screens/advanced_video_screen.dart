import 'package:flutter/material.dart';
import 'package:chemivision/config/api_config.dart';
import 'package:chemivision/services/openai_service.dart';
import 'package:chemivision/services/ai_video_service.dart';
import 'package:chemivision/services/gallery_service.dart';
import 'package:chemivision/services/video_merge_service.dart';
import 'package:chemivision/screens/video_player_screen.dart';

class AdvancedVideoScreen extends StatefulWidget {
  // Screen no longer used, kept for reference

  @override
  State<AdvancedVideoScreen> createState() => _AdvancedVideoScreenState();
}

class _AdvancedVideoScreenState extends State<AdvancedVideoScreen> {
  final TextEditingController _controller = TextEditingController();
  final OpenAIService _openAIService = OpenAIService(
    apiKey: APIConfig.openAIKey,
  );
  final GalleryService _galleryService = GalleryService();

  bool _isGenerating = false;
  bool _isMerging = false;
  String _currentStep = '';
  List<String> _generatedPrompts = [];
  List<String> _videoUrls = [];
  List<bool> _videoStatus = [
    false,
    false,
    false,
  ]; // Track which videos are done
  String? _mergedVideoPath;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateVideos() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showErrorDialog('Vui lòng nhập chủ đề Toán học');
      return;
    }

    setState(() {
      _isGenerating = true;
      _currentStep = 'Đang tạo 3 prompt đồng nhất từ GPT-5.4-mini...';
      _generatedPrompts = [];
      _videoUrls = [];
      _videoStatus = [false, false, false];
      _mergedVideoPath = null;
    });

    try {
      // Step 1: Generate 3 unified prompts
      _showLoadingMessage(_currentStep);
      final prompts = await _openAIService.generateThreeUnifiedPrompts(text);

      if (prompts.length != 3) {
        throw Exception('Không tạo được đủ 3 prompt. Vui lòng thử lại.');
      }

      setState(() {
        _generatedPrompts = prompts;
        _currentStep =
            'Đang tạo 3 video Grok song song (mỗi video 10 giây, tỉ lệ 9:16)...';
      });
      _showLoadingMessage(_currentStep);

      // Step 2: Generate 3 videos in parallel like the old behavior.
      // Each job uses its own AIVideoService instance to avoid shared mutable state.
      final List<Future<String>> videoFutures = [];
      for (int i = 0; i < 3; i++) {
        videoFutures.add(_generateSingleVideo(prompts[i], i));
      }
      final results = await Future.wait(videoFutures);

      setState(() {
        _videoUrls = results;
        _isGenerating = false;
        _currentStep = 'Hoàn thành! Đã tạo 3 video thành công.';
      });

      // Auto-save all videos to gallery
      for (int i = 0; i < _videoUrls.length; i++) {
        try {
          await _galleryService.saveVideo(
            videoUrl: _videoUrls[i],
            title: '$text - Video ${i + 1}',
            sourceType: 'advanced',
          );
          print('✅ [AdvancedVideo] Video ${i + 1} auto-saved to gallery');
        } catch (e) {
          print('⚠️ [AdvancedVideo] Failed to save video ${i + 1}: $e');
        }
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
      _showErrorDialog('Lỗi khi tạo video: $e');
    }
  }

  Future<String> _generateSingleVideo(String prompt, int index) async {
    try {
      setState(() {
        _currentStep = 'Đang tạo video ${index + 1}/3...';
      });
      _showLoadingMessage(_currentStep);

      final videoService = AIVideoService(
        accessToken: APIConfig.aiVideoAccessToken,
        openAIService: null,
      );

      // Tạo video 10 giây
      final videoUrl = await videoService.generateVideoFromText(prompt);

      setState(() {
        _videoStatus[index] = true;
      });

      print('✅ [AdvancedVideo] Video ${index + 1} created: $videoUrl');
      return videoUrl;
    } catch (e) {
      print('❌ [AdvancedVideo] Error creating video ${index + 1}: $e');
      rethrow;
    }
  }

  void _showLoadingMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Lỗi'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Thành công'),
              ],
            ),
            content: const Text(
              'Đã tạo thành công 3 video!\n\nBạn có thể xem từng video bằng cách nhấn vào nút tương ứng.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _openVideo(int index) {
    if (index < _videoUrls.length && _videoUrls[index].isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoUrl: _videoUrls[index]),
        ),
      );
    }
  }

  Future<void> _mergeVideos() async {
    if (_videoUrls.length < 3) return;
    setState(() {
      _isMerging = true;
      _currentStep = 'Đang tải và ghép 3 video...';
      _mergedVideoPath = null;
    });
    try {
      final merged = await VideoMergeService.mergeThreeVideos(
        v1: _videoUrls[0],
        v2: _videoUrls[1],
        v3: _videoUrls[2],
        onProgress: (step) {
          if (mounted) setState(() => _currentStep = step);
        },
      );
      setState(() {
        _mergedVideoPath = merged;
        _isMerging = false;
        _currentStep = 'Ghép video thành công!';
      });
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(videoUrl: merged),
          ),
        );
      }
    } catch (e) {
      setState(() => _isMerging = false);
      _showErrorDialog('Lỗi khi ghép video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIDEO NGẮN TOÁN HỌC NÂNG CAO'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFEA580C), // Orange 600
              const Color(0xFFFB923C), // Orange 400
              const Color(0xFFFDBA74), // Orange 300
              const Color(0xFFFFEDD5), // Orange 100
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VIDEO NGẮN TOÁN HỌC NÂNG CAO',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nhập một chủ đề Toán học. GPT-5.4-mini sẽ tạo 3 prompt đồng nhất (cùng chủ đề và bối cảnh), sau đó Grok sẽ tạo 3 video dọc 10 giây cùng lúc.\n\n'
                          'Enter one mathematics topic. GPT-5.4-mini will create 3 unified prompts (same topic and context), then Grok will generate 3 vertical 10-second videos simultaneously.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Input field
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  enabled: !_isGenerating,
                  decoration: InputDecoration(
                    hintText:
                        'Ví dụ: Định lý Pytago, phương trình bậc 2, tích phân suy rộng...\n\nExample: Pythagorean theorem, quadratic equation, improper integral...',
                    labelText: 'Chủ đề Toán học / Mathematics Topic',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 24),

                // Generate button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateVideos,
                    icon:
                        _isGenerating
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.video_library, size: 28),
                    label: Text(
                      _isGenerating ? 'Đang tạo video...' : 'Tạo video',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),

                if (_isGenerating) ...[
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _currentStep,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_generatedPrompts.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Đã tạo ${_generatedPrompts.length}/3 prompt',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (_videoUrls.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Đã tạo ${_videoUrls.length}/3 video',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // Video results
                if (_videoUrls.isNotEmpty && !_isGenerating) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'Video đã tạo:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    _videoUrls.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.play_circle_filled,
                              color: Color(0xFFEA580C),
                              size: 32,
                            ),
                          ),
                          title: Text('Video ${index + 1}'),
                          subtitle: const Text('10 giây dọc - Nhấn để xem'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => _openVideo(index),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Merge button — visible when all 3 videos are ready
                  if (_videoUrls.length == 3)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isMerging ? null : _mergeVideos,
                        icon:
                            _isMerging
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.merge_type),
                        label: Text(
                          _isMerging ? _currentStep : 'Ghép 3 video thành 1',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (_mergedVideoPath != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => VideoPlayerScreen(
                                      videoUrl: _mergedVideoPath!,
                                    ),
                              ),
                            ),
                        icon: const Icon(Icons.movie, color: Color(0xFFEA580C)),
                        label: const Text(
                          'Xem lại video đã ghép',
                          style: TextStyle(color: Color(0xFFEA580C)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
