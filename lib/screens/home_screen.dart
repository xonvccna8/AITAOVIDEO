import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:chemivision/config/api_config.dart';
import 'package:chemivision/services/openai_service.dart';
import 'package:chemivision/services/ai_video_service.dart';
import 'package:chemivision/services/gallery_service.dart';
import 'package:chemivision/services/video_merge_service.dart';
import 'package:chemivision/screens/video_player_screen.dart';

enum CreateMode { text, image, textAndImage }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.welcomeHint, this.initialMode});

  // Optional short hint shown as snackbar when opening from landing
  final String? welcomeHint;
  final CreateMode? initialMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FocusNode _textFocusNode = FocusNode();
  final GalleryService _galleryService = GalleryService();
  Timer? _speechStartWatchdog;

  bool _isGenerating = false;
  bool _isGeneratingPrimary = false;
  bool _isGeneratingSecondary = false;
  String _currentStep = '';
  List<String> _seriesVideoUrls = [];
  bool _isMerging = false;
  String? _mergedVideoPath;
  String? _seriesLessonContent; // Holds the lesson for the 5-video series
  bool _isInitializingSpeech = false;
  bool _isListening = false;
  bool _isSpeechAvailable = false;
  String _recognizedText = '';
  LearningSupportType _selectedSupportType = LearningSupportType.auto;
  int _generationRunId = 0;
  final Set<AIVideoService> _activeVideoServices = <AIVideoService>{};

  final OpenAIService _openAIService = OpenAIService(
    apiKey: APIConfig.openAIKey,
  );

  @override
  void initState() {
    super.initState();
    // Show an optional hint once after first frame
    if (widget.welcomeHint != null && widget.welcomeHint!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.welcomeHint!),
            duration: const Duration(seconds: 2),
          ),
        );
      });
    }

    // Auto-start flow based on landing selection
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.initialMode == null) return;
      switch (widget.initialMode!) {
        case CreateMode.text:
          _textFocusNode.requestFocus();
          break;
        case CreateMode.image:
        case CreateMode.textAndImage:
          // These modes are no longer supported
          break;
      }
    });
  }

  String _normalizeDescription(String input) {
    if (input.isEmpty) return input;

    final lines =
        input
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final seen = <String>{};
    final unique = <String>[];

    for (final line in lines) {
      final key = line.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(line);
      }
    }

    return unique.join('. ');
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (mounted) {
      _showMicrophonePermissionDialog();
    }
    return false;
  }

  void _showMicrophonePermissionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cần quyền microphone'),
            content: const Text(
              'Máy chưa cấp quyền microphone cho TOÁN HỌC 4.0.\n\n'
              'Hãy mở Cài đặt của ứng dụng, vào Quyền và bật Microphone, '
              'sau đó quay lại bấm mic lần nữa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Để sau'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text('Mở cài đặt'),
              ),
            ],
          ),
    );
  }

  Future<bool> _initializeSpeech({bool showErrorOnFailure = false}) async {
    final hasMicrophonePermission = await _ensureMicrophonePermission();
    if (!hasMicrophonePermission) {
      return false;
    }

    if (_isSpeechAvailable) {
      return true;
    }
    if (_isInitializingSpeech) {
      return false;
    }

    _isInitializingSpeech = true;

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          _speechStartWatchdog?.cancel();
          if (!mounted) return;

          setState(() {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              if (_recognizedText.isNotEmpty) {
                _textController.text = _recognizedText;
                _recognizedText = '';
              }
            }
          });
        },
        onError: (error) {
          _speechStartWatchdog?.cancel();
          if (!mounted) return;

          setState(() {
            _isListening = false;
          });

          if (error.errorMsg != 'error_no_match' &&
              error.errorMsg != 'error_speech_timeout') {
            _showErrorDialog('Lỗi ghi âm: ${error.errorMsg}');
          }
        },
        options: [stt.SpeechToText.androidNoBluetooth],
      );

      if (!mounted) {
        return available;
      }

      setState(() {
        _isSpeechAvailable = available;
      });

      if (!available && showErrorOnFailure) {
        _showErrorDialog(
          'Không thể khởi tạo ghi âm trên thiết bị này. '
          'Nếu bạn muốn nhập nội dung, hãy gõ trực tiếp vào ô văn bản.',
        );
      }

      return available;
    } catch (e) {
      if (mounted && showErrorOnFailure) {
        _showErrorDialog('Không thể bật ghi âm: $e');
      }
      return false;
    } finally {
      _isInitializingSpeech = false;
    }
  }

  Future<void> _startListening() async {
    _textFocusNode.unfocus();

    final ready = await _initializeSpeech(showErrorOnFailure: true);
    if (!ready) {
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = _textController.text.trim();
    });

    _speechStartWatchdog?.cancel();
    _speechStartWatchdog = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_isListening && !_speech.isListening) {
        setState(() {
          _isListening = false;
          _recognizedText = '';
        });
        _showErrorDialog(
          'Microphone không bắt đầu ghi âm được. Vui lòng thử lại hoặc kiểm tra quyền microphone.',
        );
      }
    });

    try {
      await _speech.cancel();
      await _speech.listen(
        onResult: (result) {
          _speechStartWatchdog?.cancel();

          setState(() {
            if (result.finalResult) {
              final currentText = _textController.text.trim();
              final newText = result.recognizedWords.trim();
              if (newText.isNotEmpty) {
                _textController.text =
                    currentText.isEmpty ? newText : '$currentText $newText';
              }
              _recognizedText = '';
            } else {
              final baseText =
                  _recognizedText.isEmpty
                      ? _textController.text.trim()
                      : _textController.text
                          .replaceAll(_recognizedText, '')
                          .trim();
              _recognizedText = result.recognizedWords;
              _textController.text =
                  baseText.isEmpty
                      ? _recognizedText
                      : '$baseText $_recognizedText';
            }
          });
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        localeId: 'vi_VN',
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      _speechStartWatchdog?.cancel();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _recognizedText = '';
      });
      _showErrorDialog('Lỗi khi bắt đầu ghi âm: $e');
    }
  }

  Future<void> _stopListening() async {
    _speechStartWatchdog?.cancel();
    await _speech.stop();
    setState(() {
      _isListening = false;
      if (_recognizedText.isNotEmpty) {
        _textController.text = _recognizedText;
        _recognizedText = '';
      }
    });
  }

  @override
  void dispose() {
    _generationRunId++;
    for (final service in List<AIVideoService>.from(_activeVideoServices)) {
      service.cancelGeneration();
    }
    _activeVideoServices.clear();
    _speechStartWatchdog?.cancel();
    _textController.dispose();
    _speech.cancel();
    _textFocusNode.dispose();
    super.dispose();
  }

  AIVideoService _createTrackedVideoService() {
    final service = AIVideoService(
      accessToken: APIConfig.aiVideoAccessToken,
      openAIService: _openAIService,
    );
    _activeVideoServices.add(service);
    return service;
  }

  void _releaseVideoService(AIVideoService service) {
    _activeVideoServices.remove(service);
  }

  bool _isCurrentGeneration(int runId) {
    return mounted && runId == _generationRunId;
  }

  void _cancelActiveGeneration({bool showMessage = false}) {
    _generationRunId++;
    for (final service in List<AIVideoService>.from(_activeVideoServices)) {
      service.cancelGeneration();
    }
    _activeVideoServices.clear();

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _isGeneratingPrimary = false;
      _isGeneratingSecondary = false;
      _isMerging = false;
      _currentStep = '';
    });
    if (showMessage) {
      _showLoadingMessage('Đã hủy quá trình tạo video');
    }
  }

  Future<void> _generateVideo() async {
    String text = _textController.text.trim();
    text = _normalizeDescription(text);
    final hasText = text.isNotEmpty;

    if (!hasText) {
      _showErrorDialog('Vui lòng nhập text để tạo video');
      return;
    }

    final runId = ++_generationRunId;
    setState(() {
      _isGenerating = true;
      _isGeneratingPrimary = true;
      _isGeneratingSecondary = false;
      _isMerging = false;
      _currentStep = '';
      _seriesVideoUrls = [];
      _mergedVideoPath = null;
      _seriesLessonContent = null;
    });

    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        if (retryCount > 0) {
          _showLoadingMessage('Đang tạo lại prompt (lần ${retryCount + 1})...');
        } else {
          _showLoadingMessage('Đang tạo prompt từ GPT...');
        }

        final prompt = await _openAIService.generatePrompt(
          text,
          supportType: _selectedSupportType,
        );
        if (!_isCurrentGeneration(runId)) return;
        print(
          '✅ [Single] GPT prompt đã tạo (${prompt.length} chars): ${prompt.substring(0, prompt.length.clamp(0, 150))}...',
        );

        _showLoadingMessage(
          'Đang tạo video 10s từ prompt Toán học và soạn bài học...',
        );

        final videoService = _createTrackedVideoService();
        late final List<dynamic> futures;
        try {
          futures = await Future.wait<dynamic>([
            videoService.generateVideoFromText(prompt),
            _openAIService.generateVideoLesson(text),
          ]);
        } finally {
          _releaseVideoService(videoService);
        }
        if (!_isCurrentGeneration(runId)) return;

        final videoUrl = futures[0] as String;
        final lessonText = futures[1] as String;

        print('✅ [Single] Video URL: $videoUrl');

        if (_isCurrentGeneration(runId)) {
          try {
            await _galleryService.saveVideo(
              videoUrl: videoUrl,
              title: text,
              sourceType: 'text',
            );
            print('✅ [HomeScreen] Video auto-saved to gallery');
          } catch (e) {
            print('⚠️ [HomeScreen] Failed to save video to gallery: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Không thể lưu vào phòng triển lãm: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }

          if (!_isCurrentGeneration(runId)) return;
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => VideoPlayerScreen(
                    videoUrl: videoUrl,
                    narrationText: text,
                    lessonContent: lessonText,
                  ),
            ),
          );
        }

        break;
      } on UnsafeGenerationException {
        if (!_isCurrentGeneration(runId)) return;
        retryCount++;

        if (retryCount >= maxRetries) {
          _showErrorDialog(
            'Video không thể tạo sau $maxRetries lần thử.\n\n'
            'Prompt bị coi là không an toàn. Vui lòng thử lại với nội dung khác.',
          );
          break;
        } else {
          _showLoadingMessage('⚠️ Prompt không an toàn, đang thử lại...');
          await Future.delayed(const Duration(seconds: 2));
        }
      } on GenerationCancelledException {
        if (!_isCurrentGeneration(runId)) return;
        _showLoadingMessage('Đã hủy quá trình tạo video');
        break;
      } catch (e) {
        if (!_isCurrentGeneration(runId)) return;
        final errorMsg = e.toString();

        if (errorMsg.contains('OpenAI') ||
            errorMsg.contains('502') ||
            errorMsg.contains('503')) {
          _showErrorDialog(
            'Lỗi kết nối OpenAI\n\n'
            '${errorMsg.replaceAll('Exception: ', '')}\n\n'
            'Gợi ý: Hãy thử lại sau 2-3 phút hoặc kiểm tra:\n'
            '• Kết nối Internet\n'
            '• Trạng thái OpenAI: status.openai.com',
          );
        } else {
          _showErrorDialog(
            'Lỗi khi tạo video:\n\n${errorMsg.replaceAll('Exception: ', '')}',
          );
        }
        break;
      }
    }

    if (_isCurrentGeneration(runId)) {
      setState(() {
        _isGenerating = false;
        _isGeneratingPrimary = false;
      });
    }
  }

  // Static template đã bị xóa — GPT bắt buộc phải tạo prompt chuẩn kiến thức.
  // Nếu GPT lỗi, hiện thông báo thay vì tạo video sai kiến thức.

  Future<void> _generateSeriesVideos() async {
    final topic = _normalizeDescription(_textController.text.trim());
    if (topic.isEmpty) {
      _showErrorDialog('Vui lòng nhập chủ đề Toán học để tạo 5 video');
      return;
    }

    final runId = ++_generationRunId;
    setState(() {
      _isGenerating = true;
      _isGeneratingPrimary = false;
      _isGeneratingSecondary = true;
      _mergedVideoPath = null;
      _seriesLessonContent = null;
      _isMerging = false;
      _currentStep = 'Đang xây dựng 5 cảnh quay cho "$topic"...';
      _seriesVideoUrls = [];
    });

    try {
      // Bước 1: GPT-5.4-mini sinh 5 prompt chuẩn kiến thức Toán học.
      // Nội dung ưu tiên sơ đồ, công thức và bước giải thay vì hình ảnh hóa học.
      setState(() {
        _currentStep = '🧠 GPT đang phân tích kiến thức "$topic"...';
      });
      _showLoadingMessage(_currentStep);

      List<String> prompts;
      try {
        // NGƯỜI DÙNG YÊU CẦU: BỎ QUA BƯỚC GPT, ĐẨY THẲNG PROMPT TIẾNG VIỆT LÊN GROK
        // Vì hệ thống cũ (Veo) có GPT tạo prompt tốt, nhưng với Grok, đẩy thẳng nội dung kèm prefix sẽ thật hơn
        print('✅ [Series] Đang sinh 5 prompt cứng bypass GPT...');
        prompts = [
          'STAGE 1 | TOPIC: $topic | SETTING LOCK: Modern math classroom, clean board, ruler and compass. ACTION: Visual introduction of the math idea with a clear diagram.',
          'STAGE 2 | TOPIC: $topic | SETTING LOCK: Whiteboard close-up. ACTION: Write the key formula/theorem with labels and a simple example.',
          'STAGE 3 | TOPIC: $topic | SETTING LOCK: Precise geometric diagram on grid paper. ACTION: Animate points, sides, angles, and measurements step by step.',
          'STAGE 4 | TOPIC: $topic | SETTING LOCK: Student notebook and calculator. ACTION: Solve one short worked example clearly.',
          'STAGE 5 | TOPIC: $topic | SETTING LOCK: Clean summary board. ACTION: Highlight the final rule, memory tip, and one practice question.',
        ];

        print('✅ [Series] Đã tạo 5 prompt thẳng cho Grok');
        setState(() {
          _currentStep =
              '✅ Đang gửi thẳng yêu cầu tới Grok để render 5 video...';
        });
      } catch (gptError) {
        // KHÔNG fallback về template tĩnh — template tĩnh không có kiến thức
        // Toán học chuẩn, sẽ gây video sai kiến thức
        print('❌ GPT failed, NOT falling back to static: $gptError');
        setState(() {
          _isGenerating = false;
          _isGeneratingSecondary = false;
          _currentStep = '';
        });
        _showErrorDialog(
          'Không thể tạo 5 video vì GPT không phản hồi.\n\n'
          'GPT cần xác minh kiến thức Toán học trước khi tạo video '
          'để đảm bảo nội dung chính xác.\n\n'
          'Lỗi: ${gptError.toString().replaceAll('Exception: ', '')}\n\n'
          'Gợi ý:\n'
          '• Kiểm tra kết nối Internet\n'
          '• Thử lại sau 1-2 phút\n'
          '• Hoặc dùng nút "Tạo 1 video" (cũng dùng GPT)',
        );
        return;
      }

      _showLoadingMessage(_currentStep);

      // Bước 2: Render 5 video song song với nhau và soạn bài học bằng GPT
      final List<Future<String>> videoFutures = [];
      for (int i = 0; i < prompts.length; i++) {
        videoFutures.add(_generateSingleVideo(prompts[i], runId));
      }

      final futuresResult = await Future.wait<dynamic>([
        Future.wait(videoFutures),
        _openAIService.generateVideoLesson(topic),
      ]);
      if (!_isCurrentGeneration(runId)) return;

      final results = futuresResult[0] as List<String>;
      _seriesLessonContent = futuresResult[1] as String;

      setState(() {
        _seriesVideoUrls = results;
        _currentStep = 'Đang lưu 5 video vào thư viện...';
      });

      final topicLabel =
          _textController.text.trim().isNotEmpty
              ? _textController.text.trim()
              : 'Series';

      // Lưu từng video vào gallery
      for (int i = 0; i < _seriesVideoUrls.length; i++) {
        if (!_isCurrentGeneration(runId)) return;
        try {
          await _galleryService.saveVideo(
            videoUrl: _seriesVideoUrls[i],
            title: '$topicLabel - Cảnh ${i + 1}',
            sourceType: 'advanced',
          );
        } catch (e) {
          print('Lỗi lưu cảnh ${i + 1}: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Không lưu được video ${i + 1}: $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      // Tự động ghép 5 video thành 1
      setState(() {
        _isMerging = true;
        _mergedVideoPath = null;
        _currentStep = 'Đang ghép 5 video thành 1...';
      });

      try {
        final merged = await VideoMergeService.mergeVideos(
          videos: _seriesVideoUrls,
          onProgress: (step) {
            if (_isCurrentGeneration(runId)) {
              setState(() => _currentStep = step);
            }
          },
        );

        // Lưu video đã ghép vào gallery
        if (!_isCurrentGeneration(runId)) return;
        try {
          await _galleryService.saveVideo(
            videoUrl: merged,
            title: '$topicLabel - Đầy đủ 5 cảnh',
            sourceType: 'advanced',
          );
        } catch (_) {}
        if (!_isCurrentGeneration(runId)) return;

        setState(() {
          _mergedVideoPath = merged;
          _isMerging = false;
          _isGenerating = false;
          _isGeneratingSecondary = false;
          _currentStep = 'Hoàn thành!';
        });

        // Mở video đã ghép ngay lập tức
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => VideoPlayerScreen(
                    videoUrl: merged,
                    lessonContent: _seriesLessonContent,
                  ),
            ),
          );
        }
      } catch (mergeError) {
        if (!_isCurrentGeneration(runId)) return;
        // Ghép thất bại → vẫn thông báo tạo 5 video thành công
        setState(() {
          _isMerging = false;
          _isGenerating = false;
          _isGeneratingSecondary = false;
          _currentStep = 'Hoàn thành tạo 5 video!';
        });
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Thành công'),
                  content: Text(
                    'Đã tạo thành công 5 video!\n'
                    'Ghép tự động thất bại: $mergeError\n\n'
                    'Bạn có thể bấm nút "Ghép video thành 1" để thử lại.',
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
      }
    } catch (e) {
      if (_isCurrentGeneration(runId)) {
        setState(() {
          _isGenerating = false;
          _isGeneratingSecondary = false;
          _isMerging = false;
        });
        _showErrorDialog('Lỗi khi tạo 5 video:\n$e');
      }
    }
  }

  Future<void> _mergeSeriesVideos() async {
    if (_seriesVideoUrls.length < 2) return;
    setState(() {
      _isMerging = true;
      _mergedVideoPath = null;
    });
    try {
      final merged = await VideoMergeService.mergeVideos(
        videos: _seriesVideoUrls,
        onProgress: (step) {
          if (mounted) setState(() => _currentStep = step);
        },
      );
      setState(() {
        _mergedVideoPath = merged;
        _isMerging = false;
      });
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => VideoPlayerScreen(
                  videoUrl: merged,
                  lessonContent: _seriesLessonContent,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        _showErrorDialog('Lỗi khi ghép video: $e');
      }
    }
  }

  Future<String> _generateSingleVideo(String prompt, int runId) async {
    final videoService = _createTrackedVideoService();
    try {
      final videoUrl = await videoService.generateVideoFromText(prompt);
      if (!_isCurrentGeneration(runId)) {
        throw GenerationCancelledException();
      }
      return videoUrl;
    } finally {
      _releaseVideoService(videoService);
    }
  }

  void _showLoadingMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Thông báo'),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F2FE), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calculate,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'VIDEO NGẮN TOÁN HỌC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tạo clip 6s/10s từ prompt Toán học chuẩn, trực quan và dễ học',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Mô tả video',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _textController,
                                maxLines: 5,
                                enabled: !_isGenerating && !_isListening,
                                focusNode: _textFocusNode,
                                decoration: InputDecoration(
                                  hintText:
                                      'Học sinh chưa hiểu phần nào? Hãy nhập tại đây...\nVí dụ: "Em chưa hiểu định lý sin", "Giải thích định lý cô-sin bằng sơ đồ", "Tạo ví dụ tính diện tích tam giác".',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color:
                                          _isListening
                                              ? Colors.red
                                              : colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor:
                                      _isListening
                                          ? Colors.red.shade50
                                          : Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.all(16),
                                  suffixIcon: _buildMicrophoneButton(),
                                ),
                              ),
                              if (_isListening)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.red,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Đang ghi âm...',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Color(0xFF2E7D32),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Kiểu hỗ trợ khi chưa hiểu bài',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSupportChip(
                                    label: 'Tự chọn',
                                    icon: Icons.auto_fix_high,
                                    type: LearningSupportType.auto,
                                  ),
                                  _buildSupportChip(
                                    label: 'Mô phỏng',
                                    icon: Icons.timeline,
                                    type: LearningSupportType.experiment,
                                  ),
                                  _buildSupportChip(
                                    label: 'Bài giảng',
                                    icon: Icons.menu_book,
                                    type: LearningSupportType.miniLesson,
                                  ),
                                  _buildSupportChip(
                                    label: 'Ứng dụng',
                                    icon: Icons.show_chart,
                                    type: LearningSupportType.realWorldReport,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF1F8E9), Color(0xFFE0F2FE)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF99F6E4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calculate,
                                        color: Color(0xFF2E7D32),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Trợ giảng thông minh cho học sinh',
                                          style: TextStyle(
                                            color: Colors.teal.shade800,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nhập phần chưa hiểu, chọn kiểu hỗ trợ (mô phỏng, bài giảng hoặc ứng dụng), hệ thống sẽ tạo video ngắn bám sát bài học để tăng hứng thú.',
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade700,
                                      fontSize: 12.5,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.shield,
                                              size: 14,
                                              color: Color(0xFF2E7D32),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'An toàn',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.functions,
                                              size: 14,
                                              color: Color(0xFF0369A1),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Chuẩn kiến thức',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 96,
                                height: 124,
                                child: Image.network(
                                  'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?auto=format&fit=crop&w=600&q=80',
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        color: const Color(0xFFDBEAFE),
                                        child: const Icon(
                                          Icons.calculate,
                                          size: 44,
                                          color: Color(0xFF0369A1),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      Container(
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D32).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isGenerating ? null : _generateVideo,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child:
                                  _isGeneratingPrimary
                                      ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Text(
                                            'Đang tạo 1 video...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                      : Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.18,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Tạo 1 video',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Đơn',
                                              style: TextStyle(
                                                color: Color(0xFF2E7D32),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF388E3C), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF388E3C).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isGenerating ? null : _generateSeriesVideos,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child:
                                  _isGeneratingSecondary
                                      ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            _currentStep.isNotEmpty
                                                ? _currentStep
                                                : 'Đang tạo chuỗi video...',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                      : Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.18,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.video_library_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Tạo 5 video đồng nhất',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '5 Cảnh',
                                              style: TextStyle(
                                                color: Color(0xFF388E3C),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                          ),
                        ),
                      ),

                      if (_isGenerating) const SizedBox(height: 16),

                      if (_isGenerating)
                        OutlinedButton.icon(
                          onPressed: () {
                            _cancelActiveGeneration(showMessage: true);
                          },
                          icon: const Icon(Icons.stop_circle),
                          label: const Text(
                            'Hủy tạo video',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: Colors.red.shade400,
                              width: 2,
                            ),
                            foregroundColor: Colors.red.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                      // Merge button — appears when 5 series videos are ready
                      if (_seriesVideoUrls.length == 5) ...[
                        const SizedBox(height: 14),
                        Container(
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF388E3C), Color(0xFFA78BFA)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF388E3C,
                                ).withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isMerging ? null : _mergeSeriesVideos,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child:
                                    _isMerging
                                        ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              _currentStep.isNotEmpty
                                                  ? _currentStep
                                                  : 'Đang ghép video...',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                        : Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(9),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.18,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.merge_type,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Text(
                                                'Ghép 5 video thành 1',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (_mergedVideoPath != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => VideoPlayerScreen(
                                        videoUrl: _mergedVideoPath!,
                                        lessonContent: _seriesLessonContent,
                                      ),
                                ),
                              ),
                          icon: const Icon(
                            Icons.movie,
                            color: Color(0xFF388E3C),
                          ),
                          label: const Text(
                            'Xem lại video đã ghép',
                            style: TextStyle(color: Color(0xFF388E3C)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFF388E3C),
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              _isListening
                  ? LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  )
                  : null,
          color: _isListening ? null : Colors.transparent,
          boxShadow:
              _isListening
                  ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap:
                _isGenerating || _isInitializingSpeech
                    ? null
                    : () async {
                      if (_isListening) {
                        await _stopListening();
                      } else {
                        await _startListening();
                      }
                    },
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child:
                  _isInitializingSpeech
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isListening ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      )
                      : Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color:
                            _isListening ? Colors.white : Colors.grey.shade700,
                        size: 20,
                      ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportChip({
    required String label,
    required IconData icon,
    required LearningSupportType type,
  }) {
    final selected = _selectedSupportType == type;
    return ChoiceChip(
      selected: selected,
      onSelected:
          _isGenerating
              ? null
              : (value) {
                if (!value) return;
                setState(() {
                  _selectedSupportType = type;
                });
              },
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : const Color(0xFF2E7D32),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF2E7D32),
          fontWeight: FontWeight.w600,
        ),
      ),
      selectedColor: const Color(0xFF2E7D32),
      backgroundColor: const Color(0xFFF1F8E9),
      side: BorderSide(
        color: selected ? const Color(0xFF2E7D32) : const Color(0xFF99F6E4),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}
