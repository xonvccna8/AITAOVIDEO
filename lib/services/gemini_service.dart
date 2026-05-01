import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'package:chemivision/services/secrets.dart';

/// A thin wrapper around Gemini 2.5 Pro for Mathematics Q&A
class GeminiService {
  final String _apiKey;
  final String _modelName;
  late final GenerativeModel _model;

  GeminiService._(this._apiKey, this._modelName) {
    _model = _buildModel(_modelName);
  }

  /// Factory that reads API key from --dart-define=GEMINI_API_KEY=...
  /// Throws if missing.
  factory GeminiService.fromEnvironment({String modelName = 'gemini-2.5-pro'}) {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    final key = envKey.isNotEmpty ? envKey : kGeminiApiKeyLocal;
    if (key.isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not set. Add to launch args or set kGeminiApiKeyLocal in services/secrets.dart',
      );
    }
    return GeminiService._(key, modelName);
  }

  /// Ask a question about Vietnamese Mathematics. Returns the model's text.
  Future<String> askChemistry(String question) async {
    final prompt = _buildPrompt(question);
    final text = await _generateChemistryAnswer(
      prompt,
      fallbackModels: const ['gemini-1.5-flash', 'gemini-1.5-flash-8b'],
    );
    if (text == null || text.isEmpty) {
      throw Exception('No answer returned from Gemini');
    }
    return text;
  }

  /// Ask a question about Vietnamese Mathematics in English. Returns the model's text.
  Future<String> askChemistryEnglish(String question) async {
    final prompt = _buildPromptEnglish(question);
    final text = await _generateChemistryAnswer(
      prompt,
      fallbackModels: const ['gemini-1.5-flash', 'gemini-1.5-flash-8b'],
    );
    if (text == null || text.isEmpty) {
      throw Exception('No answer returned from Gemini');
    }
    return text;
  }

  GenerativeModel _buildModel(String modelName) {
    return GenerativeModel(model: modelName, apiKey: _apiKey);
  }

  Future<String?> _generateChemistryAnswer(
    String prompt, {
    required List<String> fallbackModels,
  }) async {
    final triedModels = <String>{_modelName, ...fallbackModels};
    Exception? lastException;

    for (final modelName in triedModels) {
      try {
        final model = modelName == _modelName ? _model : _buildModel(modelName);
        final response = await _withRetry(
          () => model.generateContent([Content.text(prompt)]),
        );
        final text = _sanitizeMarkdown(response.text)?.trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (!_isQuotaOrRateLimitError(e)) {
          rethrow;
        }
        print(
          '⚠️ [Gemini] Model $modelName hit quota/rate limit, trying fallback model...',
        );
      }
    }

    throw lastException ??
        Exception(
          'Gemini hiện đang hết quota hoặc bị giới hạn tạm thời. Vui lòng thử lại sau.',
        );
  }

  String _buildPrompt(String userQuestion) {
    return '''Bạn là chuyên gia Toán học Việt Nam, giải thích CHÍNH XÁC, NGẮN GỌN, dễ hiểu.
Yêu cầu:
- Trả lời bằng tiếng Việt.
- Dẫn chứng công thức, định lý, ví dụ minh họa khi có thể.
- Tránh suy đoán không có nguồn.
- Nếu câu hỏi mơ hồ, hãy đặt câu hỏi làm rõ.

Câu hỏi: ${userQuestion.trim()}''';
  }

  String _buildPromptEnglish(String userQuestion) {
    return '''You are an expert in Vietnamese Mathematics. Explain ACCURATELY, CONCISELY, and clearly.
Requirements:
- Answer in English.
- Cite formulas, theorems, and worked examples when possible.
- Avoid unsourced speculation.
- If the question is vague, ask for clarification.

Question: ${userQuestion.trim()}''';
  }

  String? _sanitizeMarkdown(String? raw) {
    if (raw == null) return null;
    String s = raw;
    // Remove markdown headings like ### Title
    s = s.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    // Remove bold/italic markers
    s = s.replaceAll('**', '');
    s = s.replaceAll(RegExp(r'(^|\s)_([^_]+)_'), r'$1$2');
    // Normalize multiple blank lines
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s;
  }

  // -------- Video prompt helpers for image analysis --------

  static const String _videoPromptTemplate =
      '''You are a prompt engineer for AI text-to-video Grok.
Create a concise, cinematic English prompt (70-100 words) focusing on a single, visually striking moment.

Structure:
[1. SCENE SETUP]\n[Shot type] + [Time/lighting] + [Vietnam location details]
[2. CONTEXT & ENVIRONMENT]\nVietnamese architecture/landscape; historical era
[3. MAIN CHARACTERS]\nCount/age/gender; appearance; clothing of the era; emotions
[4. KEY ACTION]\nDescribe the central action (dynamic, precise)
[5. DIALOGUE]\n"One Vietnamese line of 5-12 words"

Rules:
- Emphasize Vietnamese cultural elements
- Keep safe for all audiences; avoid gore/explicit violence
- Keep within a short 10-second vertical clip scope
- Prompt in English; dialogue in Vietnamese in quotes

TOPIC: [topic]
''';

  Future<String> generateVideoPromptFromImage(
    String imagePath, {
    String? userText,
  }) async {
    // Validate file exists first
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('File ảnh không tồn tại: $imagePath');
    }

    final fileSize = await imageFile.length();
    if (fileSize > 20 * 1024 * 1024) {
      // 20MB limit
      throw Exception(
        'File ảnh quá lớn: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB (tối đa 20MB)',
      );
    }

    return await _withRetry(() async {
      final bytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', bytes);

      final analysisInstruction = Content.text(
        'Phân tích ảnh: 1) Đọc mọi chữ/công thức; 2) Nêu khái niệm/chủ đề Toán học có liên quan; 3) Trả về một dòng ngắn tên chủ đề.',
      );

      final resp = await _model.generateContent([
        Content.multi([analysisInstruction.parts.first, imagePart]),
      ]);
      final eventLine = (resp.text ?? '').trim();
      if (eventLine.isEmpty) {
        throw Exception('Gemini không trả về sự kiện/chủ đề từ ảnh');
      }

      final topic =
          userText == null || userText.trim().isEmpty
              ? eventLine
              : '${userText.trim()} (Sự kiện trong ảnh: $eventLine)';

      final prompt = _videoPromptTemplate.replaceAll('[topic]', topic);
      final resp2 = await _model.generateContent([Content.text(prompt)]);
      final out = _sanitizeMarkdown(resp2.text)?.trim();
      if (out == null || out.isEmpty) {
        throw Exception('Gemini không tạo được prompt video từ ảnh');
      }
      return out;
    });
  }

  Future<String> rewritePromptSafer(String originalPrompt) async {
    if (originalPrompt.trim().isEmpty) {
      throw Exception('Prompt không được để trống');
    }

    return await _withRetry(() async {
      final instr =
          '''Rewrite this prompt to be SAFE FOR ALL AUDIENCES while preserving intent and cinematic quality.
- Remove or soften explicit violence, gore, blood, weapon detail, dangerous acts, hate speech, adult content.
- Prefer symbolic/inspirational visuals.
- Keep the Vietnamese dialogue in quotes, if any.
- Keep concise for an 8-10s clip.
Return ONLY the rewritten prompt.

PROMPT:
${originalPrompt.trim()}''';
      final resp = await _model.generateContent([Content.text(instr)]);
      final out = _sanitizeMarkdown(resp.text)?.trim();
      if (out == null || out.isEmpty) {
        throw Exception(
          'Gemini không thể làm sạch prompt. Prompt có thể không hợp lệ.',
        );
      }
      return out;
    });
  }

  /// Retry wrapper with exponential backoff for overloaded server errors
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 5, // Increased from 3 to 5 for better resilience
  }) async {
    Exception? lastException;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation().timeout(
          const Duration(seconds: 90), // Increased timeout to 90s
          onTimeout:
              () => throw TimeoutException('Request timeout after 90 seconds'),
        );
      } on GenerativeAIException catch (e) {
        lastException = e;
        final errorMsg = e.toString().toLowerCase();
        final isOverloaded =
            errorMsg.contains('503') ||
            errorMsg.contains('overloaded') ||
            errorMsg.contains('unavailable') ||
            errorMsg.contains('quá tải');
        final isQuotaLimited = _isQuotaOrRateLimitError(e);

        if (isOverloaded && attempt < maxRetries - 1) {
          // Longer delays: 5, 10, 20, 30 seconds for better recovery
          final delaySeconds =
              attempt == 0 ? 5 : (attempt == 1 ? 10 : (attempt == 2 ? 20 : 30));
          print(
            '⚠️ [Gemini] Model overloaded (503), retrying in ${delaySeconds}s (attempt ${attempt + 1}/$maxRetries)...',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }

        // Map to user-friendly error after all retries exhausted
        if (isOverloaded) {
          throw Exception(
            'Mô hình Gemini đang quá tải sau ${maxRetries} lần thử.\n\n'
            'Vui lòng đợi 1-2 phút rồi thử lại.\n\n'
            'Lỗi: ${e.toString()}',
          );
        }

        if (isQuotaLimited) {
          throw Exception(
            'Gemini đang vượt quota hoặc rate limit của API key hiện tại.\n\n'
            'Vui lòng thử lại sau ít phút hoặc đổi sang API key/project khác còn quota.\n\n'
            'Lỗi: ${e.toString()}',
          );
        }

        throw Exception('Lỗi Gemini API: ${e.toString()}');
      } on TimeoutException catch (e) {
        lastException = e;
        if (attempt < maxRetries - 1) {
          final delaySeconds =
              attempt == 0 ? 5 : (attempt == 1 ? 10 : (attempt == 2 ? 20 : 30));
          print(
            '⚠️ [Gemini] Timeout, retrying in ${delaySeconds}s (attempt ${attempt + 1}/$maxRetries)...',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        throw Exception(
          'Hết thời gian chờ phản hồi từ Gemini sau ${maxRetries} lần thử. Vui lòng thử lại sau.',
        );
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        final errorStr = e.toString().toLowerCase();
        final isRetriable =
            errorStr.contains('timeout') ||
            errorStr.contains('503') ||
            errorStr.contains('overloaded') ||
            errorStr.contains('network');

        if (isRetriable && attempt < maxRetries - 1) {
          final delaySeconds =
              attempt == 0 ? 5 : (attempt == 1 ? 10 : (attempt == 2 ? 20 : 30));
          print(
            '⚠️ [Gemini] Error detected, retrying in ${delaySeconds}s (attempt ${attempt + 1}/$maxRetries)...',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        rethrow;
      }
    }

    // Should not reach here, but just in case
    throw Exception(
      'Đã thử lại $maxRetries lần nhưng vẫn lỗi. Vui lòng đợi 1-2 phút rồi thử lại.\n\n'
      'Lỗi cuối cùng: ${lastException?.toString() ?? "Unknown"}',
    );
  }

  bool _isQuotaOrRateLimitError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('quota') ||
        msg.contains('rate limit') ||
        msg.contains('resource_exhausted') ||
        msg.contains('429') ||
        msg.contains('billing') ||
        msg.contains('exceeded your current quota');
  }
}
