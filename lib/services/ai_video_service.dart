import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chemivision/config/api_config.dart';
import 'package:chemivision/services/openai_service.dart';

class GenerationCancelledException implements Exception {
  final String message;
  GenerationCancelledException([this.message = 'Generation cancelled by user']);
  @override
  String toString() => 'GenerationCancelledException: $message';
}

class HumanFaceRejectedException implements Exception {
  final String message;
  final File? imageFile;
  HumanFaceRejectedException(this.message, [this.imageFile]);
  @override
  String toString() => 'HumanFaceRejectedException: $message';
}

class VideoApiDebugException implements Exception {
  final String stage;
  final String url;
  final int statusCode;
  final String responseSnippet;

  VideoApiDebugException({
    required this.stage,
    required this.url,
    required this.statusCode,
    required this.responseSnippet,
  });

  @override
  String toString() {
    return 'Lỗi API video khi $stage\n\n'
        'URL: $url\n'
        'HTTP status: $statusCode\n\n'
        'Response:\n$responseSnippet';
  }
}

class VideoJobFailedException implements Exception {
  final String message;

  VideoJobFailedException(this.message);

  @override
  String toString() => 'VideoJobFailedException: $message';
}

class AIVideoService {
  final String accessToken;
  final String baseUrl;
  final String domain;
  final String projectId;
  final String modelId;
  final String resolution;
  final String mode;
  final OpenAIService? openAIService;

  // Cancellation controls
  bool _isCancelled = false;
  String? _currentPredictionId;
  int _requestSequence = 0;

  AIVideoService({
    required this.accessToken,
    this.baseUrl = APIConfig.aiVideoBaseUrl,
    this.domain = APIConfig.aiVideoDomain,
    this.projectId = APIConfig.aiVideoProjectId,
    this.modelId = APIConfig.aiVideoModel,
    this.resolution = APIConfig.aiVideoResolution,
    this.mode = 'normal',
    this.openAIService,
  });

  /// Cancel the current generation if any
  void cancelGeneration() {
    _isCancelled = true;
    if (_currentPredictionId != null) {
      print(
        '🛑 [AIVideo] Cancel requested for jobId=$_currentPredictionId (local cancel only)',
      );
    } else {
      print('🛑 [AIVideo] Cancel requested (no active jobId yet)');
    }
  }

  /// Generate a standard 10-second Grok video.
  Future<String> generateVideoFromText(String prompt) async {
    print('🟢 [AIVideo] Starting generateVideoFromText...');
    print('🟢 [AIVideo] Prompt: $prompt');

    try {
      return await _generateVideoWithRecovery(
        prompt: prompt,
        seconds: 10,
        aspectRatio: 'portrait',
      );
    } catch (e) {
      print('❌ [AIVideo] Exception in generateVideoFromText: $e');
      rethrow;
    }
  }

  /// Generate a longer Grok video (15s).
  Future<String> generateVideoFromText15s(String prompt) async {
    print('🟢 [AIVideo] Starting generateVideoFromText15s...');
    print('🟢 [AIVideo] Prompt: $prompt');

    try {
      return await _generateVideoWithRecovery(
        prompt: prompt,
        seconds: 15,
        aspectRatio: 'portrait',
      );
    } catch (e) {
      print('❌ [AIVideo] Exception in generateVideoFromText10s: $e');
      rethrow;
    }
  }

  /// Generate video from image only
  /// The Grok video API currently receives a text prompt; image flows first
  /// convert the image into a prompt using OpenAI/Gemini, then submit the job.
  /// This will use the image to generate a prompt via GPT, then generate video
  Future<String> generateVideoFromImage(File image) async {
    print('🟢 [AIVideo] Starting generateVideoFromImage...');

    if (openAIService == null) {
      // Fallback: generate with a generic prompt
      return await _createPrediction(
        prompt:
            'Create a cinematic video with smooth camera movements and dramatic lighting.',
        seconds: 10,
        aspectRatio: 'portrait',
      );
    }

    try {
      // Use GPT to generate a prompt from the image
      print('🟢 [AIVideo] Generating prompt from image via GPT...');
      final prompt = await openAIService!.generatePromptFromImage(image.path);

      return await _generateVideoWithRecovery(
        prompt: prompt,
        seconds: 10,
        aspectRatio: 'portrait',
      );
    } catch (e) {
      print('❌ [AIVideo] Exception in generateVideoFromImage: $e');
      rethrow;
    }
  }

  /// Analyze the image with ChatGPT to create a cinematic prompt,
  /// then generate a video using that prompt.
  Future<String> generateVideoFromImageWithGPT(File image) async {
    print('🟢 [AIVideo] Starting generateVideoFromImageWithGPT...');

    if (openAIService == null) {
      throw Exception('OpenAIService is required for this operation');
    }

    try {
      // 1) Use GPT to craft a cinematic, safe prompt from the image
      print('🟢 [AIVideo] Step 1: Generating prompt from image via GPT...');
      final rawPrompt = await openAIService!.generatePromptFromImage(
        image.path,
      );

      // 2) Rewrite to ensure safety and add VN dialogue requirement
      print('🟢 [AIVideo] Step 2: Ensuring prompt safety...');
      String safePrompt;
      try {
        safePrompt = await openAIService!.rewritePromptSafer(rawPrompt);
      } catch (_) {
        safePrompt = _buildSaferPromptFrom(rawPrompt);
      }

      // 3) Generate video using prompt
      print('🟢 [AIVideo] Step 3: Generating video from prompt...');
      return await _generateVideoWithRecovery(
        prompt: safePrompt,
        seconds: 10,
        aspectRatio: 'portrait',
      );
    } catch (e) {
      print('❌ [AIVideo] Exception in generateVideoFromImageWithGPT: $e');
      rethrow;
    }
  }

  /// Generate video from both text prompt and image
  /// Since the Grok video API currently expects a prompt-only request,
  /// we'll combine the prompt with image description
  Future<String> generateVideoFromPromptAndImage(
    String prompt,
    File image,
  ) async {
    print('🟢 [AIVideo] Starting generateVideoFromPromptAndImage...');
    print('🟢 [AIVideo] Prompt: $prompt');

    try {
      // Validate image file
      if (!await image.exists()) {
        throw Exception('Image file does not exist: ${image.path}');
      }

      // The current Grok endpoint accepts prompt text only, so we use the
      // generated prompt and do not upload the source image directly.
      return await _generateVideoWithRecovery(
        prompt: prompt,
        seconds: 10,
        aspectRatio: 'portrait',
      );
    } catch (e) {
      print('❌ [AIVideo] Exception in generateVideoFromPromptAndImage: $e');
      rethrow;
    }
  }

  Future<String> _generateVideoWithRecovery({
    required String prompt,
    required int seconds,
    required String aspectRatio,
  }) async {
    final preparedPrompt = _preparePromptForBackend(prompt);

    try {
      return await _createPrediction(
        prompt: preparedPrompt,
        seconds: seconds,
        aspectRatio: aspectRatio,
      );
    } catch (e) {
      if (e is! VideoJobFailedException ||
          !_shouldRetryWithRecoveryProfile(e.message)) {
        rethrow;
      }

      final recoveredPrompt = await _buildRecoveryPrompt(preparedPrompt);
      print(
        '🛠️ [AIVideo] Retrying with recovery profile after backend rejection...',
      );

      return await _createPrediction(
        prompt: recoveredPrompt,
        seconds: seconds <= 10 ? 10 : 15,
        aspectRatio: aspectRatio,
      );
    }
  }

  /// Create a video job on the Gommo/AIVideoAuto API.
  Future<String> _createPrediction({
    required String prompt,
    required int seconds,
    required String aspectRatio,
  }) async {
    final isVeo = modelId.toLowerCase().contains('veo');

    if (!isVeo) {
      prompt = _sanitizeForVietnameseSpeech(prompt);
      prompt = _wrapWithVietnamese(prompt);
    }
    prompt = _preparePromptForBackend(prompt);

    final mappedDuration =
        isVeo
            ? 5
            : _mapDuration(
              seconds,
            ); // Non-Veo short jobs use the restored 10s profile
    final mappedRatio = isVeo ? '16:9' : _mapAspectRatio(aspectRatio);
    final requestProjectId = _nextRequestProjectId();

    print('🟢 [AIVideo] Creating video job...');
    print('🟢 [AIVideo] Prompt: $prompt');
    print('🟢 [AIVideo] Request project_id: $requestProjectId');
    print(
      '🟢 [AIVideo] Duration: ${seconds}s -> ${mappedDuration}s, Aspect Ratio: $aspectRatio -> $mappedRatio',
    );

    _isCancelled = false;
    _currentPredictionId = null;

    try {
      // Always use create-video endpoint
      final url = Uri.parse('$baseUrl/create-video');
      print('🟢 [AIVideo] Request URL: $url');

      final requestBody = _buildFormBody(
        prompt: prompt,
        seconds: mappedDuration,
        aspectRatio: mappedRatio,
        isVeo: isVeo,
        requestProjectId: requestProjectId,
      );

      print('🟢 [AIVideo] Request body: $requestBody');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: requestBody,
      );

      print('🟢 [AIVideo] Response status: ${response.statusCode}');
      final responseBody = utf8.decode(response.bodyBytes);
      print(
        '🟢 [AIVideo] Response body (snippet): ${_responseSnippet(responseBody)}',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        if (data['success'] != true) {
          throw Exception(
            _formatApiError(
              stage: 'tạo job video',
              message: data['message'],
              fallback: 'Video job creation failed',
            ),
          );
        }

        // Handle new veo_3_1 response format vs old format
        final videoInfo = Map<String, dynamic>.from(
          data['videoInfo'] ?? data['data'] ?? {},
        );
        final status = videoInfo['status']?.toString().toUpperCase() ?? '';
        final idBase = videoInfo['id_base'] as String?;
        final downloadUrl =
            (videoInfo['download_url'] ?? videoInfo['result_url']) as String?;
        _currentPredictionId = idBase;

        print('🟢 [AIVideo] id_base: $idBase');
        print('🟢 [AIVideo] Status: $status');

        // If immediately completed (unlikely but handle it)
        if (status.contains('SUCCESS') &&
            downloadUrl != null &&
            downloadUrl.isNotEmpty) {
          print('');
          print('=' * 60);
          print('✅ [AIVideo] VIDEO COMPLETED INSTANTLY!');
          print('=' * 60);
          print('🎬 [AIVideo] Download URL: $downloadUrl');
          print('=' * 60);
          return downloadUrl;
        }

        if (status.contains('FAILED') ||
            status == 'ERROR' ||
            status.contains('ERROR')) {
          throw VideoJobFailedException(
            _formatApiError(
              stage: 'tạo video',
              message: data['message'] ?? videoInfo['message'],
              fallback: 'Video generation failed immediately',
            ),
          );
        }

        if (idBase != null && idBase.isNotEmpty) {
          print('🟢 [AIVideo] Job submitted, polling for completion...');
          return await _waitForPredictionCompletion(idBase, prompt);
        }

        throw VideoApiDebugException(
          stage: 'tạo job video',
          url: url.toString(),
          statusCode: response.statusCode,
          responseSnippet: _responseSnippet(responseBody),
        );
      } else {
        print('❌ [AIVideo] Request failed with status: ${response.statusCode}');
        throw VideoApiDebugException(
          stage: 'tạo job video',
          url: url.toString(),
          statusCode: response.statusCode,
          responseSnippet: _responseSnippet(responseBody),
        );
      }
    } catch (e) {
      print('❌ [AIVideo] Exception in _createPrediction: $e');
      rethrow;
    }
  }

  /// Poll interval is adaptive so long-running Veo jobs can finish without
  /// hammering the API every 5 seconds for the entire duration.
  Duration _pollInterval(int attempt) {
    if (attempt <= 12) {
      return const Duration(seconds: 5);
    }
    if (attempt <= 60) {
      return const Duration(seconds: 8);
    }
    return const Duration(seconds: 10);
  }

  /// Poll job status via POST https://api.gommo.net/ai/video
  /// until download_url is available or status contains FAILED.
  Future<String> _waitForPredictionCompletion(
    String idBase,
    String prompt,
  ) async {
    print('🟢 [AIVideo] Starting to poll job status for id_base=$idBase...');
    final isVeo = modelId.toLowerCase().contains('veo');
    final maxAttempts = isVeo ? 180 : 100;

    int elapsedTime = 0;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_isCancelled) {
        print('🛑 [AIVideo] Polling cancelled at attempt $attempt');
        throw GenerationCancelledException();
      }

      final interval = _pollInterval(attempt);
      print(
        '🟢 [AIVideo] Poll attempt $attempt/$maxAttempts (${elapsedTime}s elapsed, next in ${interval.inSeconds}s)',
      );

      await Future.delayed(interval);
      elapsedTime += interval.inSeconds;

      try {
        // Endpoint: POST /ai/video with id_base in body
        final url = Uri.parse('$baseUrl/video');
        final pollBody =
            'access_token=$accessToken'
            '&domain=${Uri.encodeQueryComponent(domain)}'
            '&id_base=${Uri.encodeQueryComponent(idBase)}';

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: pollBody,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout:
                  () =>
                      throw Exception(
                        'Polling trạng thái video quá lâu, máy chủ phản hồi chậm',
                      ),
            );

        print('🟢 [AIVideo] Poll response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final responseBody = utf8.decode(response.bodyBytes);
          final data = jsonDecode(responseBody) as Map<String, dynamic>;

          // Ensure polling caters for new return shapes
          final vInfoMap = data['videoInfo'] ?? data['data'];
          final videoInfo =
              vInfoMap != null
                  ? Map<String, dynamic>.from(vInfoMap)
                  : <String, dynamic>{};
          final status = videoInfo['status']?.toString().toUpperCase() ?? '';
          final downloadUrl =
              (videoInfo['download_url'] ?? videoInfo['result_url']) as String?;
          final percent = videoInfo['percent']?.toString() ?? '0';

          print('🟢 [AIVideo] Status: $status | percent: $percent%');

          if (status.contains('SUCCESS')) {
            if (downloadUrl != null && downloadUrl.isNotEmpty) {
              print('');
              print('=' * 60);
              print('✅ [AIVideo] VIDEO COMPLETED!');
              print('=' * 60);
              print('🎬 [AIVideo] Download URL: $downloadUrl');
              print('🆔 [AIVideo] id_base: $idBase');
              print('⏱️  [AIVideo] Total time: ${elapsedTime}s');
              print('=' * 60);
              return downloadUrl;
            } else {
              throw Exception('Video completed but no download_url available');
            }
          } else if (status.contains('FAILED') ||
              status == 'ERROR' ||
              status.contains('ERROR')) {
            final errorMsg =
                videoInfo['message'] as String? ??
                data['message'] as String? ??
                'Unknown error';
            print('❌ [AIVideo] Job failed: $errorMsg');

            if (openAIService != null &&
                (errorMsg.toLowerCase().contains('safety') ||
                    errorMsg.toLowerCase().contains('policy') ||
                    errorMsg.toLowerCase().contains('unsafe'))) {
              print('🛡️  [AIVideo] Attempting retry with safer prompt...');
              try {
                final saferPrompt = await openAIService!.rewritePromptSafer(
                  prompt,
                );
                return await _createPrediction(
                  prompt: saferPrompt,
                  seconds: 10,
                  aspectRatio: 'portrait',
                );
              } catch (_) {
                // Fall through to throw original error
              }
            }

            throw VideoJobFailedException(
              _formatApiError(
                stage: 'tạo video',
                message: errorMsg,
                fallback: 'Video generation failed',
              ),
            );
          } else if (status.contains('CANCEL')) {
            throw GenerationCancelledException('Job was cancelled');
          } else {
            // PENDING or PROCESSING – keep polling
            print(
              '⏳ [AIVideo] Still processing... waiting ${_pollInterval(attempt + 1).inSeconds}s',
            );
          }
        } else {
          print('⚠️ [AIVideo] Poll request failed: ${response.statusCode}');
          final responseBody = utf8.decode(response.bodyBytes);
          throw VideoApiDebugException(
            stage: 'kiểm tra trạng thái job',
            url: url.toString(),
            statusCode: response.statusCode,
            responseSnippet: _responseSnippet(responseBody),
          );
        }
      } catch (e) {
        if (e is GenerationCancelledException || e is VideoJobFailedException) {
          rethrow;
        }
        // Lỗi terminal từ API (FAILED/ERROR) → dừng ngay, không retry
        // Chỉ retry cho lỗi mạng tạm thời (timeout, connection reset...)
        final errStr = e.toString().toLowerCase();
        final isTerminalError =
            errStr.contains('audio_filtered') ||
            errStr.contains('#acr') ||
            errStr.contains('failed') ||
            errStr.contains('policy') ||
            errStr.contains('safety') ||
            errStr.contains('unsafe') ||
            errStr.contains('không có âm thanh') ||
            e is VideoApiDebugException;
        if (isTerminalError) {
          print('❌ [AIVideo] Terminal error, stopping poll: $e');
          rethrow;
        }
        print('⚠️ [AIVideo] Transient error in attempt $attempt: $e');
        if (attempt == maxAttempts) rethrow;
        // otherwise continue polling for transient errors
      }
    }

    print('');
    print('=' * 60);
    print('⏰ [AIVideo] TIMEOUT!');
    print('Video không hoàn thành sau ${elapsedTime}s');
    print('id_base: $idBase');
    print('💡 Video có thể vẫn đang xử lý trên máy chủ.');
    print('=' * 60);
    throw Exception(
      'Máy chủ tạo video phản hồi quá chậm sau ${elapsedTime}s. '
      'Job vẫn có thể đang xử lý trên server (id: $idBase). '
      'Vui lòng thử lại sau hoặc bấm hủy để tạo yêu cầu mới.',
    );
  }

  String _buildFormBody({
    required String prompt,
    required int seconds,
    required String aspectRatio,
    bool isVeo = false,
    String? requestProjectId,
  }) {
    final durationToUse = seconds.toString();
    final modeToUse = isVeo ? 'fast' : mode;
    final ratioToUse = aspectRatio;
    final projectIdToUse = requestProjectId ?? projectId;

    final fields = <String>[
      'domain=${Uri.encodeQueryComponent(domain)}',
      'project_id=${Uri.encodeQueryComponent(projectIdToUse)}',
      'access_token=$accessToken',
      'model=${Uri.encodeQueryComponent(modelId)}', // Always send model
      'ratio=${Uri.encodeQueryComponent(ratioToUse)}',
      'resolution=${Uri.encodeQueryComponent(resolution)}',
      'duration=${Uri.encodeQueryComponent(durationToUse)}',
      'mode=${Uri.encodeQueryComponent(modeToUse)}',
      'prompt=${Uri.encodeQueryComponent(prompt)}',
    ];
    return fields.join('&');
  }

  String _nextRequestProjectId() {
    final base = projectId.trim().isEmpty ? 'default' : projectId.trim();
    final safeBase = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final prefix = safeBase.length > 32 ? safeBase.substring(0, 32) : safeBase;
    final sequence = ++_requestSequence;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${timestamp}_$sequence';
  }

  int _mapDuration(int seconds) {
    if (seconds <= 10) {
      return 10;
    }
    return 15;
  }

  String _mapAspectRatio(String aspectRatio) {
    return '9:16';
  }

  String _formatApiError({
    required String stage,
    required Object? message,
    required String fallback,
  }) {
    final text = (message?.toString().trim() ?? '');
    if (text.isEmpty) {
      return 'Lỗi khi $stage. Vui lòng thử lại sau.';
    }
    return 'Lỗi khi $stage: $text';
  }

  String _responseSnippet(String responseBody) {
    final compact = responseBody.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 350) {
      return compact;
    }
    return '${compact.substring(0, 350)}...';
  }

  /// Remove common prompt cues that frequently trigger non-Vietnamese narration.
  String _sanitizeForVietnameseSpeech(String prompt) {
    return prompt.trim();
  }

  /// No longer injects Vietnamese speech since Grok handles silent video well.
  String _wrapWithVietnamese(String prompt) {
    return prompt.trim();
  }

  String _buildSaferPromptFrom(String basePrompt) {
    const safetyNote =
        '\n\nSAFETY REQUIREMENTS: The video must be safe for all audiences, avoiding explicit violence, gore, blood, weapons usage, dangerous acts, hate speech, or adult content. Use inspirational, symbolic, and non-violent visuals instead.';

    String result = basePrompt.trim();
    result += safetyNote;
    return result;
  }

  bool _shouldRetryWithRecoveryProfile(String message) {
    final text = message.toLowerCase();
    return text.contains('#acr') ||
        text.contains('vui lòng thử lại sau') ||
        text.contains('please try again later') ||
        text.contains('temporarily unavailable') ||
        text.contains('server is busy') ||
        text.contains('quá tải');
  }

  Future<String> _buildRecoveryPrompt(String originalPrompt) async {
    if (openAIService != null) {
      try {
        final saferPrompt = await openAIService!.rewritePromptSafer(
          originalPrompt,
        );
        return _preparePromptForBackend(saferPrompt, aggressive: true);
      } catch (e) {
        print('⚠️ [AIVideo] Recovery prompt rewrite failed: $e');
      }
    }

    return _preparePromptForBackend(
      _buildSaferPromptFrom(originalPrompt),
      aggressive: true,
    );
  }

  String _preparePromptForBackend(String prompt, {bool aggressive = false}) {
    var result = prompt.trim().replaceAll('\r', '');
    result = result.replaceAll('**', '').replaceAll('`', '');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    if (aggressive) {
      result = result
          .replaceAll(
            RegExp(
              r'^(diem hoc sinh chua hieu|điểm học sinh chưa hiểu|kieu ho tro da ap dung|kiểu hỗ trợ đã áp dụng|cau hoi goi mo cuoi video|câu hỏi gợi mở cuối video|nhan kien thuc|nhãn kiến thức|phuong trinh goi y \(neu co\)|phương trình gợi ý \(nếu có\)|canh \d+ \([^\n]*\):|cảnh \d+ \([^\n]*\):)\s*',
              caseSensitive: false,
              multiLine: true,
            ),
            '',
          )
          .replaceAll(
            RegExp(r'^-\s*', caseSensitive: false, multiLine: true),
            '',
          )
          .replaceAll('\n', '. ');
    }

    result =
        result
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .replaceAll(RegExp(r' *\n *'), '\n')
            .trim();

    final maxLength = aggressive ? 520 : 850;
    if (result.length > maxLength) {
      final boundary = aggressive ? '. ' : '\n';
      final cutIndex = result.lastIndexOf(boundary, maxLength);
      if (cutIndex > 120) {
        result = result.substring(0, cutIndex).trim();
      } else {
        result = result.substring(0, maxLength).trim();
      }
    }

    if (aggressive &&
        !result.toLowerCase().contains('safe for all audiences')) {
      result =
          '$result. Safe for all audiences. Silent educational mathematics video.';
    }

    return result;
  }
}
