import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chemivision/screens/stereo_video_screen.dart';
import 'package:chemivision/widgets/math_text.dart';
import 'package:chemivision/services/openai_service.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
// Removed video merge feature

Map<String, dynamic> _decodeLessonJson(String raw) {
  String cleaned = raw.trim();
  if (cleaned.contains('```')) {
    cleaned = cleaned.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').trim();
  }

  try {
    return json.decode(cleaned) as Map<String, dynamic>;
  } catch (_) {
    String fixed = cleaned.replaceAll("'", '"');
    fixed = fixed.replaceAll('\\\\', '\\');
    fixed = fixed.replaceAll('\\', '\\\\');
    return json.decode(fixed) as Map<String, dynamic>;
  }
}

String _cleanMathText(Object? value) {
  var text = (value ?? '').toString();
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll(r'\\$', r'$').replaceAll(r'\$', r'$');
  text = text.replaceAll(r'\\[', r'$$').replaceAll(r'\\]', r'$$');
  text = text.replaceAll(r'\[', r'$$').replaceAll(r'\]', r'$$');
  text = text.replaceAll(r'\\(', r'$').replaceAll(r'\\)', r'$');
  text = text.replaceAll(r'\(', r'$').replaceAll(r'\)', r'$');
  text = text.replaceAll('\\\\', '\\');
  return text.trim();
}

List<Map<String, dynamic>> _cleanQuestions(Object? value) {
  final list = (value as List?) ?? const [];
  return list.map((item) {
    final source = Map<String, dynamic>.from(item as Map);
    final options =
        ((source['options'] as List?) ?? const [])
            .map((option) => _cleanMathText(option))
            .toList();
    return {
      'question': _cleanMathText(source['question']),
      'options': options,
      'correct': source['correct'] as int,
    };
  }).toList();
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? narrationText;
  final String? lessonContent;
  final String? openAIApiKey;
  final String? videoTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.narrationText,
    this.lessonContent,
    this.openAIApiKey,
    this.videoTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const MethodChannel _ttsChannel = MethodChannel('MathVision/tts');
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isDownloading = false;
  bool _isSpeakingVi = false;
  String? _generatedLesson;
  bool _isGeneratingLesson = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Initialize video player
      // Check if videoUrl is a network URL or local file path
      if (widget.videoUrl.startsWith('http://') ||
          widget.videoUrl.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
      } else {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      }

      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();

      setState(() {
        _isInitialized = true;
      });

      // Tự động hiện bài học sau khi video load xong
      if (widget.lessonContent != null && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showLessonSheet();
        });
      }
    } catch (e) {
      _showErrorDialog('Lỗi khi tải video: $e');
    }
  }

  @override
  void dispose() {
    _ttsChannel.invokeMethod('stop');
    _controller?.dispose();
    super.dispose();
  }

  String _buildVietnameseNarration() {
    final input = widget.narrationText?.trim() ?? '';
    if (input.isNotEmpty) {
      return 'Tóm tắt Toán học: $input. Đây là video minh họa bằng tiếng Việt.';
    }
    return 'Đây là video minh họa kiến thức Toán học. '
        'Nếu video gốc không có tiếng Việt, hệ thống sẽ đọc thuyết minh tiếng Việt cho bạn.';
  }

  Future<void> _toggleVietnameseVoice() async {
    try {
      if (_isSpeakingVi) {
        await _ttsChannel.invokeMethod('stop');
        if (mounted) setState(() => _isSpeakingVi = false);
        return;
      }
      if (mounted) setState(() => _isSpeakingVi = true);
      await _ttsChannel.invokeMethod('speakVietnamese', {
        'text': _buildVietnameseNarration(),
      });
      if (mounted) {
        // Reset button state after a short delay if user doesn't manually stop.
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _isSpeakingVi = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSpeakingVi = false);
      }
      _showErrorDialog('Không thể phát giọng Việt: $e');
    }
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      if (widget.videoUrl.startsWith('http://') ||
          widget.videoUrl.startsWith('https://')) {
        // Download from network
        final response = await http.get(Uri.parse(widget.videoUrl));

        if (response.statusCode == 200) {
          // Get temporary directory
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${tempDir.path}/video_$timestamp.mp4';

          // Save to temporary file
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          // Save to gallery using gal plugin
          await Gal.putVideo(filePath);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video đã được lưu vào thư viện'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            throw Exception('Không thể lưu video');
          }
        } else {
          throw Exception('Không thể tải video: ${response.statusCode}');
        }
      } else {
        // Local file, just save to gallery using gal plugin
        await Gal.putVideo(widget.videoUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video đã được lưu vào thư viện'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Không thể lưu video');
        }
      }
    } catch (e) {
      _showErrorDialog('Lỗi khi tải video: $e');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _generateLessonAndOpen() async {
    final apiKey = widget.openAIApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa cấu hình OpenAI API key'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isGeneratingLesson = true);
    try {
      final topic = widget.videoTitle ?? widget.narrationText ?? 'Toán học';
      final service = OpenAIService(apiKey: apiKey);
      final lesson = await service.generateVideoLesson(topic);
      if (!mounted) return;
      setState(() => _generatedLesson = lesson);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LessonQuizPage(content: lesson)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tạo bài học: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingLesson = false);
    }
  }

  void _showLessonSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return _LessonQuizSheet(
                content: _generatedLesson ?? widget.lessonContent!,
                scrollController: scrollController,
              );
            },
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

  void _togglePlayPause() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Preview'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (widget.lessonContent != null || _generatedLesson != null)
            IconButton(
              icon: const Icon(Icons.school),
              tooltip: 'Bài học & Trắc nghiệm',
              onPressed: _showLessonSheet,
            ),
        ],
      ),
      body:
          _isInitialized
              ? Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_controller!),
                              if (!_controller!.value.isPlaying)
                                const Icon(
                                  Icons.play_circle_outline,
                                  size: 80,
                                  color: Colors.white,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Video controls
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        // Progress bar
                        VideoProgressIndicator(
                          _controller!,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: Theme.of(context).colorScheme.primary,
                            bufferedColor: Colors.grey[300]!,
                            backgroundColor: Colors.grey[200]!,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Control buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              iconSize: 36,
                              onPressed: _togglePlayPause,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.replay),
                              iconSize: 36,
                              onPressed: () {
                                _controller!.seekTo(Duration.zero);
                                _controller!.play();
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _toggleVietnameseVoice,
                              icon: Icon(
                                _isSpeakingVi
                                    ? Icons.volume_off
                                    : Icons.record_voice_over,
                              ),
                              label: Text(
                                _isSpeakingVi
                                    ? 'Dừng giọng Việt'
                                    : 'Giọng Việt',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Download button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isDownloading ? null : _downloadVideo,
                            icon:
                                _isDownloading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(Icons.download),
                            label: Text(
                              _isDownloading ? 'Đang tải...' : 'Tải về',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Lesson button — luôn hiển thị nếu có content hoặc có API key
                        Builder(
                          builder: (context) {
                            final hasContent =
                                widget.lessonContent != null ||
                                _generatedLesson != null;
                            final canGenerate =
                                widget.openAIApiKey != null && !hasContent;
                            if (!hasContent && !canGenerate)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isGeneratingLesson
                                          ? null
                                          : () {
                                            if (hasContent) {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) => LessonQuizPage(
                                                        content:
                                                            _generatedLesson ??
                                                            widget
                                                                .lessonContent!,
                                                      ),
                                                ),
                                              );
                                            } else {
                                              _generateLessonAndOpen();
                                            }
                                          },
                                  icon:
                                      _isGeneratingLesson
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(Icons.menu_book_rounded),
                                  label: Text(
                                    _isGeneratingLesson
                                        ? 'Đang tạo bài học...'
                                        : 'Bài Học & Trắc Nghiệm',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 3,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => StereoVideoScreen(
                                        videoUrl: widget.videoUrl,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.vrpano),
                            label: const Text('Xem 3D'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Merge button removed
                      ],
                    ),
                  ),
                ],
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-page Lesson + Quiz screen
// ---------------------------------------------------------------------------
class LessonQuizPage extends StatefulWidget {
  final String content;
  const LessonQuizPage({super.key, required this.content});

  @override
  State<LessonQuizPage> createState() => _LessonQuizPageState();
}

class _LessonQuizPageState extends State<LessonQuizPage> {
  static const _teal = Color(0xFF2E7D32);
  static const _tealLight = Color(0xFFE8F5E9);

  String? _explanation;
  List<Map<String, dynamic>> _questions = [];
  List<int?> _selected = [];
  bool _submitted = false;
  bool _parseError = false;

  @override
  void initState() {
    super.initState();
    _parse(widget.content);
  }

  void _parse(String raw) {
    try {
      final data = _decodeLessonJson(raw);
      final qs = _cleanQuestions(data['questions']);
      _explanation = _cleanMathText(data['explanation']);
      _questions = qs;
      _selected = List<int?>.filled(qs.length, null);
    } catch (_) {
      _parseError = true;
    }
  }

  int get _score =>
      _questions
          .asMap()
          .entries
          .where((e) => _selected[e.key] == (e.value['correct'] as int))
          .length;

  void _submit() {
    if (_selected.any((s) => s == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng trả lời tất cả câu hỏi trước khi nộp bài'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _submitted = true);
  }

  void _retry() {
    setState(() {
      _submitted = false;
      _selected = List<int?>.filled(_questions.length, null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'Bài Học & Trắc Nghiệm',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
      ),
      body:
          _parseError
              ? _buildFallback()
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildExplanationCard(),
                  const SizedBox(height: 24),
                  _buildQuizSection(),
                  const SizedBox(height: 24),
                  if (_submitted) _buildScoreBanner(),
                  if (_submitted) const SizedBox(height: 16),
                  _buildActionButton(),
                  const SizedBox(height: 32),
                ],
              ),
    );
  }

  Widget _buildFallback() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MathText(
            _cleanMathText(widget.content),
            style: const TextStyle(fontSize: 15, height: 1.7),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    if (_explanation == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _teal.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 22),
                SizedBox(width: 10),
                Text(
                  'Giải Thích',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: MathText(
              _explanation!,
              style: const TextStyle(
                fontSize: 15,
                height: 1.75,
                color: Color(0xFF1A2E1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSection() {
    if (_questions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Câu Hỏi Trắc Nghiệm',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._questions.asMap().entries.map((entry) {
          return _buildQuestionCard(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildQuestionCard(int qi, Map<String, dynamic> q) {
    final options = (q['options'] as List).cast<String>();
    final correct = q['correct'] as int;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _tealLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _teal,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${qi + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MathText(
                    q['question'] as String,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children:
                  options
                      .asMap()
                      .entries
                      .map(
                        (opt) => _buildOption(qi, opt.key, opt.value, correct),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int qi, int oi, String label, int correct) {
    final isSelected = _selected[qi] == oi;
    final isCorrect = oi == correct;

    Color bg;
    Color borderColor;
    Color textColor;
    Widget leading;

    if (_submitted) {
      if (isCorrect) {
        bg = Colors.green.shade50;
        borderColor = Colors.green.shade400;
        textColor = Colors.green.shade800;
        leading = const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 20,
        );
      } else if (isSelected) {
        bg = Colors.red.shade50;
        borderColor = Colors.red.shade400;
        textColor = Colors.red.shade800;
        leading = const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
      } else {
        bg = Colors.grey.shade50;
        borderColor = Colors.grey.shade200;
        textColor = Colors.grey.shade600;
        leading = Icon(
          Icons.radio_button_unchecked_rounded,
          color: Colors.grey.shade300,
          size: 20,
        );
      }
    } else if (isSelected) {
      bg = _tealLight;
      borderColor = _teal;
      textColor = const Color(0xFF1B5E20);
      leading = const Icon(
        Icons.radio_button_checked_rounded,
        color: _teal,
        size: 20,
      );
    } else {
      bg = Colors.grey.shade50;
      borderColor = Colors.grey.shade200;
      textColor = const Color(0xFF333333);
      leading = Icon(
        Icons.radio_button_unchecked_rounded,
        color: Colors.grey.shade400,
        size: 20,
      );
    }

    return GestureDetector(
      onTap: _submitted ? null : () => setState(() => _selected[qi] = oi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: MathText(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight:
                      isSelected || (_submitted && isCorrect)
                          ? FontWeight.w600
                          : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBanner() {
    final perfect = _score == _questions.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              perfect
                  ? [Colors.green.shade400, Colors.green.shade700]
                  : [Colors.orange.shade400, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (perfect ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            perfect ? Icons.emoji_events_rounded : Icons.school_rounded,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                perfect ? '🎉 Xuất sắc! Hoàn hảo!' : 'Kết quả của bạn',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_score / ${_questions.length} câu đúng',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitted ? _retry : _submit,
        icon: Icon(_submitted ? Icons.refresh_rounded : Icons.send_rounded),
        label: Text(
          _submitted ? 'Làm lại' : 'Nộp bài',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: _submitted ? const Color(0xFF555555) : _teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _LessonQuizSheet extends StatefulWidget {
  final String content;
  final ScrollController scrollController;

  const _LessonQuizSheet({
    required this.content,
    required this.scrollController,
  });

  @override
  State<_LessonQuizSheet> createState() => _LessonQuizSheetState();
}

class _LessonQuizSheetState extends State<_LessonQuizSheet> {
  String? _explanation;
  List<Map<String, dynamic>> _questions = [];
  List<int?> _selected = [];
  bool _submitted = false;
  bool _parseError = false;

  @override
  void initState() {
    super.initState();
    _parse(widget.content);
  }

  void _parse(String raw) {
    try {
      final data = _decodeLessonJson(raw);
      final qs = _cleanQuestions(data['questions']);
      // Called from initState — set fields directly, no setState needed
      _explanation = _cleanMathText(data['explanation']);
      _questions = qs;
      _selected = List<int?>.filled(qs.length, null);
    } catch (_) {
      _parseError = true;
    }
  }

  int get _score =>
      _questions.asMap().entries.where((e) {
        final idx = e.key;
        final q = e.value;
        return _selected[idx] == (q['correct'] as int);
      }).length;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF2E7D32);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.school, color: teal, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Bài học & Trắc nghiệm',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: teal,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Expanded(
            child:
                _parseError
                    ? SingleChildScrollView(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(16),
                      child: MathText(
                        _cleanMathText(widget.content),
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    )
                    : SingleChildScrollView(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── GIẢI THÍCH ───────────────────────────────────
                          if (_explanation != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: teal.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb,
                                        color: teal,
                                        size: 20,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Giải thích',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  MathText(
                                    _explanation!,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: Color(0xFF1A2E1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // ── CÂU HỎI TRẮC NGHIỆM ─────────────────────────
                          if (_questions.isNotEmpty) ...[
                            const Row(
                              children: [
                                Icon(Icons.quiz, color: teal, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Câu hỏi trắc nghiệm',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._questions.asMap().entries.map((entry) {
                              final qi = entry.key;
                              final q = entry.value;
                              final options =
                                  (q['options'] as List).cast<String>();
                              final correct = q['correct'] as int;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MathText(
                                      'Câu ${qi + 1}: ${q['question']}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...options.asMap().entries.map((opt) {
                                      final oi = opt.key;
                                      final label = opt.value;
                                      final isSelected = _selected[qi] == oi;
                                      final isCorrect = oi == correct;
                                      Color bg = Colors.grey.shade100;
                                      Color border = Colors.grey.shade300;
                                      Color textColor = Colors.black87;
                                      if (_submitted) {
                                        if (isCorrect) {
                                          bg = Colors.green.shade50;
                                          border = Colors.green;
                                          textColor = Colors.green.shade800;
                                        } else if (isSelected && !isCorrect) {
                                          bg = Colors.red.shade50;
                                          border = Colors.red;
                                          textColor = Colors.red.shade800;
                                        }
                                      } else if (isSelected) {
                                        bg = const Color(0xFFCCECEA);
                                        border = teal;
                                        textColor = teal;
                                      }
                                      return GestureDetector(
                                        onTap:
                                            _submitted
                                                ? null
                                                : () => setState(
                                                  () => _selected[qi] = oi,
                                                ),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(color: border),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: MathText(
                                                  label,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: textColor,
                                                    fontWeight:
                                                        isSelected ||
                                                                (_submitted &&
                                                                    isCorrect)
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              if (_submitted && isCorrect)
                                                const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 18,
                                                ),
                                              if (_submitted &&
                                                  isSelected &&
                                                  !isCorrect)
                                                const Icon(
                                                  Icons.cancel,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                            // Score banner
                            if (_submitted)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color:
                                      _score == _questions.length
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _score == _questions.length
                                            ? Colors.green
                                            : Colors.orange,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _score == _questions.length
                                          ? Icons.emoji_events
                                          : Icons.school,
                                      color:
                                          _score == _questions.length
                                              ? Colors.green
                                              : Colors.orange,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Kết quả: $_score/${_questions.length} câu đúng',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _score == _questions.length
                                                ? Colors.green.shade800
                                                : Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Submit / Retry button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_submitted) {
                                    setState(() {
                                      _submitted = false;
                                      for (
                                        int i = 0;
                                        i < _selected.length;
                                        i++
                                      ) {
                                        _selected[i] = null;
                                      }
                                    });
                                  } else {
                                    if (_selected.any((s) => s == null)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Vui lòng trả lời tất cả câu hỏi',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => _submitted = true);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _submitted ? 'Làm lại' : 'Nộp bài',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
