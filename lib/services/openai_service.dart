import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

/// Exception for unsafe generation detection
class UnsafeGenerationException implements Exception {
  final String message;
  UnsafeGenerationException([this.message = 'Unsafe generation detected']);
  @override
  String toString() => 'UnsafeGenerationException: $message';
}

enum LearningSupportType { auto, experiment, miniLesson, realWorldReport }

/// Service để tương tác với OpenAI API
/// Ưu tiên GPT-5.4-mini cho prompt giáo dục.
class OpenAIService {
  final String _apiKey;

  OpenAIService({required String apiKey}) : _apiKey = _validateApiKey(apiKey);

  /// Validate API key format
  /// OpenAI API keys typically start with 'sk-' or 'sk-proj-'
  static String _validateApiKey(String apiKey) {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }
    if (apiKey.trim() != apiKey) {
      throw ArgumentError('API key should not have leading or trailing spaces');
    }
    if (!apiKey.startsWith('sk-')) {
      throw ArgumentError(
        'Invalid API key format. OpenAI API keys should start with "sk-"',
      );
    }
    return apiKey;
  }

  /// Get the API key (read-only access)
  String get apiKey => _apiKey;

  static const String _baseUrl = 'https://api.openai.com/v1';
  // Ưu tiên GPT-5.4-mini cho chất lượng sư phạm.
  static const String _model = 'gpt-5.4-mini';
  static const String _fallbackModel = 'gpt-5.4-mini';
  static const String _modelMini = 'gpt-5.4-mini';

  // Prompt lock: chỉ tạo prompt video ngắn cho nội dung Hệ thức lượng trong tam giác (Toán 10).
  static const String _userPromptTemplate =
      """Bạn là trợ lý sư phạm Toán 10 tối ưu cho GPT-5.4-mini.

PHẠM VI KIẾN THỨC DỤY: CHƯƠNG HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10)
Chỉ được dạy và giải thích các kiến thức thuộc chương này:
- Giá trị lượng giác của một góc từ 0° đến 180° (sin, cos, tan, cot)
- Định lý cô-sin: a² = b² + c² – 2bc·cos A
- Định lý sin: a/sin A = b/sin B = c/sin C = 2R
- Diện tích tam giác: S = ½·b·c·sin A
- Công thức Heron: S = √[p(p−a)(p−b)(p−c)], p = (a+b+c)/2
- Bán kính đường tròn ngoại tiếp R = a/(2 sin A)
- Bán kính đường tròn nội tiếp r = S/p

BỐI CẢNH:
- Học sinh đang KHÔNG HIỂU một phần kiến thức và nhập câu hỏi/mô tả.
- Nhiệm vụ của bạn là biến phần khó hiểu thành video ngắn trực quan để tăng hứng thú học tập.

KIỂU HỖ TRỢ ĐÃ CHỌN: [support_mode]
HƯỚNG DẪN KIỂU HỖ TRỢ:
[support_instruction]

KIỂM ĐỊNH CHÍNH XÁC TOÁN HỌC:
[accuracy_instruction]

YÊU CẦU SƯ PHẠM BẮT BUỘC:
1) CHỆ dùng kiến thức thuộc chương HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10).
2) Nếu input vượt ngoài phạm vi chương này, từ chối lịch lạng và nhắc học sinh chỉ hỏi về chương này.
3) Xác định rõ "điểm học sinh chưa hiểu" từ input và bám sát điểm đó.
4) Nếu có công thức: nêu rõ ký hiệu, điều kiện áp dụng, bước giải minh họa.
5) Ngôn ngữ tiếng Việt, ngắn, dễ hiểu, phù hợp học sinh lớp 10.

ĐỊNH DẠNG TRẢ VỀ (giữ đúng format):
Điểm học sinh chưa hiểu: [một câu ngắn]
Kiểu hỗ trợ đã áp dụng: [[support_mode]]

Cảnh 1 (0-3s):
- Chủ đề Hệ thức lượng:
- Bối cảnh:
- Góc máy:
- Hành động/minh họa:

Cảnh 2 (3-6s):
- Chủ đề Hệ thức lượng:
- Bối cảnh:
- Góc máy:
- Hành động/minh họa:

Câu hỏi gợi mở cuối video: [1 câu hỏi ngắn để học sinh tự nghĩ]
Nhãn kiến thức: [Tên công thức/khái niệm trong chương]
Công thức gợi ý (nếu có): [Ví dụ: a/sin A = 2R]

CHỦ ĐỀ HỌC SINH GÕ: [topic]
""";

  // Preset chủ đề cụ thể trong chương HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10).
  static const Map<String, String> _mathTopicPresets = {
    'dinh ly sin':
        'Nhấn mạnh định lý sin: a/sin A = b/sin B = c/sin C = 2R. Áp dụng tính cạnh khi biết góc đối diện hoặc tính góc khi biết hai cạnh và góc đối.',
    'dinh ly cosin':
        'Nhấn mạnh định lý cô-sin: a² = b² + c² – 2bc·cos A. Dùng tính cạnh khi biết hai cạnh và góc xẹp hoặc tính góc khi biết ba cạnh.',
    'cos':
        'Nhấn mạnh định lý cô-sin: a² = b² + c² – 2bc·cos A. Dùng tính cạnh khi biết hai cạnh và góc xẹp hoặc tính góc khi biết ba cạnh.',
    'sin':
        'Nhấn mạnh định lý sin: a/sin A = b/sin B = c/sin C = 2R. Dung để tính cạnh/góc chưa biết trong tam giác.',
    'dien tich':
        'Diện tích tam giác: S = ½b·c·sin A. Kết hợp với công thức Heron khi biết ba cạnh: S = √[p(p−a)(p−b)(p−c)].',
    'heron':
        'Công thức Heron: S = √[p(p−a)(p−b)(p−c)] với p = (a+b+c)/2. Dùng khi biết ba cạnh mà không biết góc.',
    'ngoai tiep':
        'Bán kính đường tròn ngoại tiếp: R = a/(2 sin A). Trâm ở giao đường trung trực ba cạnh.',
    'noi tiep':
        'Bán kính đường tròn nội tiếp: r = S/p, tâm là giao điểm ba đường phân giác trong.',
    'gia tri luong giac':
        'Giá trị lượng giác của góc từ 0° đến 180°: sin(180°−α)=sinα, cos(180°−α)=−cosα. Bảng giá trị đặc biệt 0°, 30°, 45°, 60°, 90°, 120°, 150°, 180°.',
    'luong giac':
        'Giá trị lượng giác sin/cos/tan của góc tù và góc nhọn trong tam giác, phạm vi Toán 10.',
  };

  String _normalizeForMatch(String input) {
    return input
        .toLowerCase()
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
  }

  String _buildFigurePresetBlock(String text) {
    final normalized = _normalizeForMatch(text);
    final matches = <String>{};

    for (final entry in _mathTopicPresets.entries) {
      if (normalized.contains(entry.key)) {
        matches.add(entry.value);
      }
    }

    if (matches.isEmpty) return '';

    final lines = matches.map((m) => '- $m').join('\n');
    return '\n\nPRESET CHUYEN DE TOAN HOC:\n'
        '$lines\n'
        '- Giu nguyen tinh chinh xac toan hoc va ngon ngu de hieu cho hoc sinh.';
  }

  String _compactAdvancedPrompt(String prompt) {
    var result = prompt.trim();

    // Remove markdown noise to make Grok render requests lighter/faster.
    result = result
        .replaceAll('**', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ');

    // Keep prompts compact to reduce backend processing time.
    const maxLength = 900;
    if (result.length > maxLength) {
      final cutIndex = result.lastIndexOf('\n', maxLength);
      if (cutIndex > 0) {
        result = result.substring(0, cutIndex).trim();
      } else {
        result = result.substring(0, maxLength).trim();
      }
    }

    return result;
  }

  LearningSupportType _inferSupportTypeFromText(String text) {
    final normalized = _normalizeForMatch(text);
    if (normalized.contains('ung dung') ||
        normalized.contains('thuc te') ||
        normalized.contains('doi song') ||
        normalized.contains('bai toan thuc te')) {
      return LearningSupportType.realWorldReport;
    }
    if (normalized.contains('mo phong') ||
        normalized.contains('demo') ||
        normalized.contains('hinh dung') ||
        normalized.contains('truc quan')) {
      return LearningSupportType.experiment;
    }
    if (normalized.contains('bai giang') ||
        normalized.contains('giai thich') ||
        normalized.contains('ly thuyet')) {
      return LearningSupportType.miniLesson;
    }
    return LearningSupportType.auto;
  }

  String _supportTypeLabel(LearningSupportType type) {
    switch (type) {
      case LearningSupportType.auto:
        return 'Tự chọn thông minh';
      case LearningSupportType.experiment:
        return 'Mô phỏng trực quan';
      case LearningSupportType.miniLesson:
        return 'Bài giảng ngắn';
      case LearningSupportType.realWorldReport:
        return 'Ứng dụng thực tế';
    }
  }

  String _supportTypeInstruction(LearningSupportType type) {
    switch (type) {
      case LearningSupportType.auto:
        return '''- Tự chọn 1 trong 3 kiểu phù hợp nhất với phần học sinh chưa hiểu.
- Nếu input chứa từ khóa mô phỏng/bài giảng/ứng dụng thì ưu tiên đúng từ khóa đó.
- Ưu tiên nội dung gây tò mò, có tính trực quan và giúp học sinh "à ha" nhanh.''';
      case LearningSupportType.experiment:
        return '''- Dẫn dắt theo dạng mô phỏng trực quan bằng sơ đồ, lưới tọa độ, compa, thước đo hoặc chuyển động điểm.
- Nhấn mạnh điều học sinh nhìn thấy trên hình và liên hệ ngay với công thức.
- Tránh hình ảnh phòng thí nghiệm hoặc đạo cụ không liên quan đến Toán học.''';
      case LearningSupportType.miniLesson:
        return '''- Dẫn dắt theo dạng bài giảng cực ngắn: khái niệm cốt lõi -> ví dụ -> chốt nhớ.
- Mỗi cảnh chỉ 1 ý chính, câu văn dễ hiểu cho học sinh.
- Cuối video có câu hỏi tự kiểm tra nhanh.''';
      case LearningSupportType.realWorldReport:
        return '''- Dẫn dắt theo dạng ứng dụng thực tế: đo đạc, bản đồ, kiến trúc, thiết kế, thể thao hoặc bài toán đời sống.
- Liên hệ ứng dụng thực tế với kiến thức Toán học đang học.
- Tạo cảm giác "học để dùng được" nhằm tăng hứng thú học tập.''';
    }
  }

  String _buildScientificAccuracyBlock(String text) {
    final normalized = _normalizeForMatch(text);
    final rules = <String>[
      'Chỉ dùng kiến thức thuộc chương HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10).',
      'Không bịa công thức hoặc kết quả không thuộc phạm vi chương này.',
      'Nếu có công thức, phải kiểm tra điều kiện áp dụng (ví dụ: góc có thuộc [0°,180°] không).',
      'Bài toán minh họa phải dùng số đẹp, thỏa mãn điều kiện tồn tại tam giác.',
      'Nếu nội dung nhập mơ hồ, ưu tiên định lý sin hoặc cô-sin gần nhất.',
    ];

    if (normalized.contains('sin') || normalized.contains('dinh ly sin')) {
      rules.add(
        'Nếu dùng định lý sin, kiểm tra: đảm bảo góc và cạnh đối diện tương ứng đúng.',
      );
    }

    if (normalized.contains('cos') || normalized.contains('dinh ly cosin')) {
      rules.add(
        'Nếu dùng định lý cô-sin, xác định rõ góc xẹp giữa hai cạnh đã biết.',
      );
    }

    if (normalized.contains('dien tich') || normalized.contains('heron')) {
      rules.add(
        'Diện tích tam giác phải dương; kiểm tra điều kiện tồn tại tam giác trước khi tính.',
      );
    }

    return rules.map((r) => '- $r').join('\n');
  }

  Future<String> _reviewPromptForScientificAccuracy({
    required String draftPrompt,
    required String userTopic,
    required LearningSupportType supportType,
  }) async {
    const reviewSystem =
        '''Bạn là chuyên gia phản biện chương HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10), nhiệm vụ kiểm định prompt video trước khi gửi cho Grok.

PHẠM VI KIẾN THỨC HỢP LỆ: Chỉ định lý sin, định lý cô-sin, diện tích tam giác, Heron, bán kính ngoại/nội tiếp, giá trị lượng giác góc 0°–180°.

MỤC TIÊU:
- Loại bỏ sai lệch toán học.
- Loại bỏ nội dung vượt ngoài phạm vi chương.
- Giữ đúng định dạng sẵn có của prompt.
- Chỉ sửa phần sai hoặc mơ hồ, không viết lại lan man.

QUY TẮC:
1) Kiểm tra tính hợp lý của công thức, giá trị số, điều kiện tam giác.
2) Nếu công thức sai hoặc góc/cạnh không hợp lệ, sửa lại cho đúng.
3) Nếu nội dung không thuộc phạm vi chương này, thay bằng minh họa định lý sin/cô-sin an toàn.
4) Không thêm kiến thức ngoài chương Hệ thức lượng trong tam giác.
5) Trả về DUY NHẤT prompt đã hiệu chỉnh, không thêm giải thích bên ngoài.''';

    final reviewUser =
        '''Hãy kiểm định và hiệu chỉnh prompt sau để đảm bảo chính xác khoa học.

Chủ đề học sinh: $userTopic
Kiểu hỗ trợ: ${_supportTypeLabel(supportType)}

PROMPT NHÁP CẦN KIỂM ĐỊNH:
$draftPrompt''';

    final messages = [
      {'role': 'system', 'content': reviewSystem},
      {'role': 'user', 'content': reviewUser},
    ];

    final reviewed = await _sendRequestWithModel(messages, _model);
    return reviewed.trim();
  }

  /// Generate a prompt based on user text input
  /// This will call GPT to enhance the text into a better prompt for video generation
  Future<String> generatePrompt(
    String userText, {
    LearningSupportType supportType = LearningSupportType.auto,
  }) async {
    print('🔵 [OpenAI] Starting generatePrompt...');
    print('🔵 [OpenAI] User text: $userText');

    try {
      final inferred = _inferSupportTypeFromText(userText);
      final resolvedType =
          supportType == LearningSupportType.auto ? inferred : supportType;

      final userPrompt =
          _userPromptTemplate
              .replaceAll('[topic]', userText)
              .replaceAll('[support_mode]', _supportTypeLabel(resolvedType))
              .replaceAll(
                '[support_instruction]',
                _supportTypeInstruction(resolvedType),
              )
              .replaceAll(
                '[accuracy_instruction]',
                _buildScientificAccuracyBlock(userText),
              ) +
          _buildFigurePresetBlock(userText);

      final List<Map<String, dynamic>> messages = [
        {'role': 'user', 'content': userPrompt},
      ];

      final draftPrompt = await _sendRequest(messages);
      String finalPrompt = draftPrompt;

      try {
        finalPrompt = await _reviewPromptForScientificAccuracy(
          draftPrompt: draftPrompt,
          userTopic: userText,
          supportType: resolvedType,
        );
      } catch (reviewError) {
        print(
          '⚠️ [OpenAI] Scientific review failed, fallback to draft prompt: $reviewError',
        );
      }

      print('✅ [OpenAI] Generated prompt: $finalPrompt');
      return finalPrompt;
    } catch (e) {
      print('❌ [OpenAI] Error: $e');
      rethrow;
    }
  }

  /// Generate 3 unified prompts for advanced math short videos.
  /// All 3 prompts share the same math topic, context, and visual style.
  /// Uses gpt-5.4-mini for unified math prompts
  Future<List<String>> generateThreeUnifiedPrompts(String mathTopic) async {
    print('🔵 [OpenAI] Starting generateThreeUnifiedPrompts...');
    print('🔵 [OpenAI] Math topic: $mathTopic');

    try {
      const systemPrompt =
          '''You are an expert in Vietnamese Grade 10 Mathematics — specifically the chapter "Hệ thức lượng trong tam giác" (Trigonometric Relations in Triangles) — and a compact prompt engineer for Grok.
Create 3 SHORT production-ready prompts for ONE topic from this chapter only.

ALLOWED KNOWLEDGE SCOPE (strictly this chapter only):
- Law of Sines: a/sin A = b/sin B = c/sin C = 2R
- Law of Cosines: a² = b² + c² – 2bc·cos A
- Triangle area: S = ½b·c·sin A
- Heron’s formula: S = √[p(p-a)(p-b)(p-c)]
- Circumradius R = a/(2 sin A), Inradius r = S/p
- Trigonometric values of angles 0° to 180°

TOP PRIORITIES:
1) SAME topic from the chapter across all 3 prompts.
2) SAME classroom/whiteboard setting and visual style across all 3 prompts.
3) 3 prompts must be CONTINUOUS: Part 1 -> Part 2 -> Part 3.
4) NO dialogue, NO speech, NO audio cues — Grok generates silent video only.
5) Keep prompts COMPACT for fastest video generation.

STRICT RULES:
- Mathematical accuracy first.
- Only content from the chapter "Hệ thức lượng trong tam giác" (Grade 10).
- Show triangle diagrams with clearly labeled sides a, b, c and angles A, B, C.

OUTPUT RULES:
- Return exactly 3 prompts separated by "===PROMPT_END===".
- Each prompt should be short, roughly 450-700 characters if possible.
- Each prompt MUST contain:
  PART x/3
  TOPIC LOCK
  SETTING LOCK
  ACTION/DEMONSTRATION
  NO audio or dialogue — silent visual only.''';

      final userPrompt =
          '''Tạo 3 prompt ngắn, thống nhất và nhanh để render cho chủ đề: $mathTopic

Yêu cầu bắt buộc:
- Chỉ dùng kiến thức thuộc chương HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10).
- Không bịa công thức hoặc kết quả trái với định lý sin/cô-sin.
- Cả 3 prompt cùng một chủ đề, là 3 phần liên tiếp theo tiến trình giải thích.
- Giữ nguyên cùng bối cảnh bảng đen/lớp học với tam giác vẽ sẵn.
- Prompt phải NGẮN GỌN để render nhanh, bỏ chi tiết không cần thiết.
- Mỗi prompt 10 giây, KHÔNG có thoại hay âm thanh (Grok chỉ tạo video câm).
- Ở cả 3 prompt phải lặp lại cùng TOPIC LOCK và SETTING LOCK.
- Ưu tiên hình ảnh tam giác với nhãn cạnh a, b, c và góc A, B, C rõ ràng.''' +
          _buildFigurePresetBlock(mathTopic);

      final List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ];

      final result = await _sendRequestWithModel(messages, _modelMini);

      // Parse the 3 prompts
      final prompts =
          result
              .split('===PROMPT_END===')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();

      // Clean up prompt labels
      final cleanedPrompts =
          prompts
              .map((p) {
                // Remove "PROMPT 1:", "PROMPT 2:", etc. if present
                return p
                    .replaceAll(
                      RegExp(r'^PROMPT\s+\d+:\s*', multiLine: true),
                      '',
                    )
                    .trim();
              })
              .map((p) {
                return _compactAdvancedPrompt(p);
              })
              .toList();

      if (cleanedPrompts.length != 3) {
        throw Exception('Expected 3 prompts but got ${cleanedPrompts.length}');
      }

      print('✅ [OpenAI] Generated 3 unified prompts');
      return cleanedPrompts;
    } catch (e) {
      print('❌ [OpenAI] Error generating 3 prompts: $e');
      rethrow;
    }
  }

  /// Generate 5 GPT-verified prompts for a math topic.
  /// Each prompt covers a different learning stage:
  ///   1. Giới thiệu  2. Lý thuyết  3. Minh họa trực quan  4. Bài toán mẫu  5. Tổng kết
  /// Uses GPT-5.4-mini with mathematical accuracy review.
  Future<List<String>> generateFiveUnifiedPrompts(String mathTopic) async {
    print('🔵 [OpenAI] Starting generateFiveUnifiedPrompts...');
    print('🔵 [OpenAI] Math topic: $mathTopic');

    try {
      const systemPrompt =
          '''You are a Vietnamese Grade 10 Mathematics teacher specializing in "Hệ thức lượng trong tam giác" (Trigonometric Relations in Triangles) AND a video prompt engineer for Grok.
Your role: given a topic from this chapter, create 5 MATHEMATICALLY ACCURATE, SHORT video prompts for Grok.

ALLOWED KNOWLEDGE SCOPE (strictly this chapter only):
- Law of Sines: a/sin A = b/sin B = c/sin C = 2R
- Law of Cosines: a² = b² + c² – 2bc·cos A
- Triangle area: S = ½b·c·sin A
- Heron’s formula: S = √[p(p-a)(p-b)(p-c)]
- Circumradius R = a/(2 sin A), Inradius r = S/p
- Trigonometric values of angles 0° to 180°

STRICT MATHEMATICAL RULES:
1) Identify the exact concept from the chapter based on the topic.
2) DIAGRAMS BE EXTREMELY PRECISE: label triangle vertices A, B, C and sides a, b, c opposite to them. Show angles clearly.
3) FORMULAS must match exactly: Law of Sines or Cosines as relevant, not mixed up.
4) Specify exact diagram elements. Describe exactly what is drawn and labeled.
5) All 5 prompts must describe the SAME exact concept from this chapter.

VISUAL STYLE (apply to all 5 prompts consistently):
- Same setting: modern Vietnamese classroom, clean whiteboard, ruler and compass visible.
- Same presenter: Vietnamese male Grade 10 math teacher, formal attire, professional.
- Same lighting: bright, educational, studio-quality.
- Camera: cinematic, slow, smooth tracking shots.

5 LEARNING STAGES (apply in order):
STAGE 1 — INTRODUCTION: Real-world context where the concept appears (surveying, architecture, navigation).
STAGE 2 — FORMULA: The specific law/formula written clearly on whiteboard with all variable labels.
STAGE 3 — DIAGRAM: CLOSE-UP on a triangle diagram with all sides and angles labeled correctly.
STAGE 4 — WORKED EXAMPLE: Step-by-step numerical calculation on whiteboard.
STAGE 5 — SUMMARY: Zoom-out showing the formula and diagram together as a visual summary.

OUTPUT FORMAT:
- Return exactly 5 prompts separated by "===PROMPT_END===".
- Each prompt: 300-500 characters, in English (Grok understands English better).
- Each prompt starts with: STAGE x/5 | TOPIC: [identified topic name]
- Each prompt must include: SETTING LOCK | ACTION/DEMONSTRATION.
- NO dialogue, NO speech, NO audio — Grok generates silent video only.
- DO NOT add any text outside the prompts.''';

      final userPrompt =
          '''Tạo 5 prompt video Grok cho chủ đề sau: "$mathTopic"

Xác định chính xác khái niệm thuộc chương HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10) từ chủ đề trên.
Kiểm tra lại: công thức, nhãn cạnh/góc, bước tính phải đúng với ĐÚNG chủ đề đó và không vượt phạm vi chương.''' +
          _buildFigurePresetBlock(mathTopic);

      final List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ];

      // Use primary model for scientific accuracy; _model has review built-in
      final result = await _sendRequestWithModel(messages, _model);

      // Parse 5 prompts
      final prompts =
          result
              .split('===PROMPT_END===')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();

      final cleanedPrompts =
          prompts
              .map(
                (p) =>
                    p
                        .replaceAll(
                          RegExp(r'^PROMPT\s+\d+:\s*', multiLine: true),
                          '',
                        )
                        .trim(),
              )
              .map(_compactAdvancedPrompt)
              .toList();

      if (cleanedPrompts.length < 5) {
        // If GPT returns fewer than 5 (e.g. fallback merged some), pad with last
        while (cleanedPrompts.length < 5) {
          cleanedPrompts.add(cleanedPrompts.last);
        }
      }

      final five = cleanedPrompts.take(5).toList();
      print('✅ [OpenAI] Generated ${five.length} unified prompts');
      return five;
    } catch (e) {
      print('❌ [OpenAI] Error generating 5 prompts: $e');
      rethrow;
    }
  }

  /// Send request with specific model
  Future<String> _sendRequestWithModel(
    List<Map<String, dynamic>> messages,
    String model,
  ) async {
    print('🔵 [OpenAI] Sending request to OpenAI with model: $model');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: json.encode({
              'model': model,
              'messages': messages,
              'max_completion_tokens':
                  900, // GPT-5.4-mini dùng max_completion_tokens
              'temperature':
                  0.4, // giảm độ ngẫu nhiên để nhân vật/bối cảnh nhất quán
            }),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Request timeout after 60 seconds');
            },
          );

      print('🔵 [OpenAI] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final content = data['choices'][0]['message']['content'] as String;
        print('🔵 [OpenAI] Response length: ${content.length} characters');
        return content.trim();
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        print('❌ [OpenAI] Error response: $errorBody');

        final lowerBody = errorBody.toLowerCase();
        final isModelUnavailable =
            (response.statusCode == 400 || response.statusCode == 404) &&
            lowerBody.contains('model') &&
            (lowerBody.contains('does not exist') ||
                lowerBody.contains('not found') ||
                lowerBody.contains('unsupported') ||
                lowerBody.contains('invalid'));

        if (isModelUnavailable && model != _fallbackModel) {
          print('⚠️ [OpenAI] $model unavailable, fallback to $_fallbackModel');
          return _sendRequestWithModel(messages, _fallbackModel);
        }

        // Handle specific HTTP status codes
        if (response.statusCode == 401) {
          throw Exception(
            'OpenAI API key không hợp lệ.\n\n'
            'Vui lòng kiểm tra lại API key trong Settings.',
          );
        } else if (response.statusCode == 429) {
          throw Exception(
            'OpenAI API đang quá tải.\n\n'
            'Vui lòng đợi 1-2 phút rồi thử lại.',
          );
        } else if (response.statusCode == 500) {
          throw Exception(
            'Máy chủ OpenAI đang gặp sự cố.\n\n'
            'Vui lòng thử lại sau vài phút.',
          );
        } else if (response.statusCode == 502 || response.statusCode == 503) {
          throw Exception(
            'OpenAI đang bảo trì hoặc quá tải.\n\n'
            'Vui lòng thử lại sau 2-3 phút.',
          );
        } else if (response.statusCode == 504) {
          throw Exception(
            'Yêu cầu quá lâu, OpenAI không phản hồi.\n\n'
            'Vui lòng thử lại với mô tả ngắn gọn hơn.',
          );
        }

        // Try to parse error message
        try {
          final errorData = json.decode(errorBody);
          final errorMessage = errorData['error']['message'] ?? 'Unknown error';
          throw Exception(
            'Lỗi OpenAI (${response.statusCode}):\n\n$errorMessage',
          );
        } catch (e) {
          if (e is Exception && e.toString().contains('Lỗi OpenAI')) {
            rethrow;
          }
          throw Exception(
            'Lỗi kết nối OpenAI (${response.statusCode}).\n\n'
            'Vui lòng thử lại sau vài phút.',
          );
        }
      }
    } catch (e) {
      print('❌ [OpenAI] Request error: $e');
      rethrow;
    }
  }

  Future<String> rewritePromptSafer(String originalPrompt) async {
    // existing method body
    print('🔵 [OpenAI] Starting rewritePromptSafer...');
    // ...

    print('🔵 [OpenAI] Original prompt length: ${originalPrompt.length}');

    try {
      const rewriteSystem =
          'You are a senior safety editor for AI text-to-video Grok prompts. Your job is to preserve meaning, scene structure, and cinematic quality while removing or softening unsafe elements.';
      final rewriteUser =
          '''Rewrite this Grok video prompt to be SAFE FOR ALL AUDIENCES while preserving the intent and format.

Rules:
- MUST preserve the exact scene structure format with all 5 elements: Environment, Camera Directions, Character/Action, Soundtrack/SFX, Visual Style
- Remove or soften explicit violence, gore, blood, detailed weapon usage, dangerous acts, hate speech, and adult content
- Replace violent actions with symbolic, inspirational, and peaceful visuals (e.g., "raising swords" instead of "stabbing", "soldiers advancing" instead of "killing")
- Remove any dialogue, speech lines, or audio cues — Grok generates silent video only
- Keep scene time markers (e.g., "0-4s", "4-8s")
- Keep all Vietnamese cultural elements: traditional clothing, architecture, locations
- Return ONLY the rewritten scenes in the same format

PROMPT:
${originalPrompt.trim()}''';

      final List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': rewriteSystem},
        {'role': 'user', 'content': rewriteUser},
      ];

      final result = await _sendRequest(messages);
      print('✅ [OpenAI] Safer prompt generated (${result.length} chars)');
      return result.trim();
    } catch (e) {
      print('❌ [OpenAI] rewritePromptSafer error: $e');
      rethrow;
    }
  }

  /// Generate a prompt that combines text and image context
  /// Used when user provides both text and image
  /// Step 1: Analyze image to identify math topic
  /// Step 2: Combine with user text and generate prompt using template
  Future<String> generatePromptWithImage(
    String userText,
    String imagePath,
  ) async {
    print('🔵 [OpenAI] Starting generatePromptWithImage...');
    print('🔵 [OpenAI] User text: $userText');
    print('🔵 [OpenAI] Image path: $imagePath');

    try {
      // STEP 1: Analyze image to identify math topic
      const analyzeInstruction =
          'Bạn là trợ lý Toán học. Hãy phân tích bức ảnh này và: 1) Đọc kỹ tất cả chữ/công thức trong ảnh; 2) Xác định chủ đề Toán học chính (khái niệm, định lý, bài tập hoặc công thức); 3) Trả về một dòng ngắn dạng "Tên chủ đề - nội dung chính". Chỉ trả về 1 dòng, không giải thích dài.';

      // Build multimodal message with base64 data URL for analysis
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      final List<Map<String, dynamic>> analyzeMessages = [
        {'role': 'system', 'content': analyzeInstruction},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  'Phân tích bức ảnh này và cho biết chủ đề Toán học chính.',
            },
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl, 'detail': 'high'},
            },
          ],
        },
      ];

      // Get math topic from image analysis
      final chemistryTopicFromImage = await _sendRequest(analyzeMessages);
      print(
        '✅ [OpenAI] Identified math topic from image: $chemistryTopicFromImage',
      );

      // STEP 2: Combine image topic with user text, then generate prompt using template
      final combinedTopic =
          '$userText (Chủ đề từ ảnh: $chemistryTopicFromImage)';
      final userPrompt = _userPromptTemplate.replaceAll(
        '[topic]',
        combinedTopic.trim(),
      );

      final List<Map<String, dynamic>> promptMessages = [
        {'role': 'user', 'content': userPrompt},
      ];

      final result = await _sendRequest(promptMessages);

      print('✅ [OpenAI] Generated prompt with image: $result');
      return result;
    } catch (e) {
      print('❌ [OpenAI] Error: $e');
      rethrow;
    }
  }

  /// Generate a cinematic math video prompt by analyzing a single image
  /// Uses multimodal chat with an embedded base64 data URL
  /// Step 1: Analyze image to identify math topic
  /// Step 2: Use the identified topic to generate prompt using template
  Future<String> generatePromptFromImage(String imagePath) async {
    print('🔵 [OpenAI] Starting generatePromptFromImage...');
    print('🔵 [OpenAI] Image path: $imagePath');

    try {
      // STEP 1: Analyze image to identify math topic
      const analyzeInstruction =
          'Bạn là trợ lý Toán học. Hãy phân tích bức ảnh này và: 1) Đọc kỹ tất cả chữ/công thức trong ảnh; 2) Xác định chủ đề Toán học chính (khái niệm, định lý, bài tập hoặc công thức); 3) Trả về một dòng ngắn dạng "Tên chủ đề - nội dung chính". Chỉ trả về 1 dòng, không giải thích dài.';

      // Build multimodal message with base64 data URL for analysis
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      final List<Map<String, dynamic>> analyzeMessages = [
        {'role': 'system', 'content': analyzeInstruction},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  'Phân tích bức ảnh này và cho biết chủ đề Toán học chính.',
            },
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl, 'detail': 'high'},
            },
          ],
        },
      ];

      // Get math topic from image analysis
      final chemistryTopicFromImage = await _sendRequest(analyzeMessages);
      print('✅ [OpenAI] Identified math topic: $chemistryTopicFromImage');

      // STEP 2: Generate prompt using the identified topic with template
      final userPrompt = _userPromptTemplate.replaceAll(
        '[topic]',
        chemistryTopicFromImage.trim(),
      );

      final List<Map<String, dynamic>> promptMessages = [
        {'role': 'user', 'content': userPrompt},
      ];

      final result = await _sendRequest(promptMessages);
      print('✅ [OpenAI] Generated prompt from image (${result.length} chars)');
      return result.trim();
    } catch (e) {
      print('❌ [OpenAI] generatePromptFromImage error: $e');
      rethrow;
    }
  }

  /// Private method to send request to OpenAI API
  /// Accepts string-only messages or multimodal message objects
  Future<String> _sendRequest(List<Map<String, dynamic>> messages) async {
    print('🔵 [OpenAI] Sending request to OpenAI...');
    print('🔵 [OpenAI] Model: $_model');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: json.encode({
              'model': _model,
              'messages': messages,
              'max_completion_tokens':
                  700, // GPT-5.4-mini dùng max_completion_tokens
              'temperature': 0.7, // cân bằng sáng tạo/tốc độ
            }),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Request timeout after 60 seconds');
            },
          );

      print('🔵 [OpenAI] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Decode response body with UTF-8 explicitly
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final content = data['choices'][0]['message']['content'] as String;
        print('🔵 [OpenAI] Response length: ${content.length} characters');
        return content.trim();
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        print('❌ [OpenAI] Error response: $errorBody');

        final lowerBody = errorBody.toLowerCase();
        final isModelUnavailable =
            (response.statusCode == 400 || response.statusCode == 404) &&
            lowerBody.contains('model') &&
            (lowerBody.contains('does not exist') ||
                lowerBody.contains('not found') ||
                lowerBody.contains('unsupported') ||
                lowerBody.contains('invalid'));

        if (isModelUnavailable) {
          print('⚠️ [OpenAI] $_model unavailable, fallback to $_fallbackModel');
          return _sendRequestWithModel(messages, _fallbackModel);
        }

        // Handle specific HTTP status codes
        if (response.statusCode == 401) {
          throw Exception(
            'OpenAI API key không hợp lệ.\n\n'
            'Vui lòng kiểm tra lại API key trong Settings.',
          );
        } else if (response.statusCode == 429) {
          throw Exception(
            'OpenAI API đang quá tải.\n\n'
            'Vui lòng đợi 1-2 phút rồi thử lại.',
          );
        } else if (response.statusCode == 500) {
          throw Exception(
            'Máy chủ OpenAI đang gặp sự cố.\n\n'
            'Vui lòng thử lại sau vài phút.',
          );
        } else if (response.statusCode == 502 || response.statusCode == 503) {
          throw Exception(
            'OpenAI đang bảo trì hoặc quá tải.\n\n'
            'Vui lòng thử lại sau 2-3 phút.\n\n'
            'Nếu vẫn lỗi, hãy kiểm tra trạng thái OpenAI tại:\n'
            'https://status.openai.com',
          );
        } else if (response.statusCode == 504) {
          throw Exception(
            'Yêu cầu quá lâu, OpenAI không phản hồi.\n\n'
            'Vui lòng thử lại với mô tả ngắn gọn hơn.',
          );
        }

        // Try to parse error message from response
        try {
          final errorData = json.decode(errorBody);
          final errorMessage = errorData['error']['message'] ?? 'Unknown error';
          throw Exception(
            'Lỗi OpenAI (${response.statusCode}):\n\n$errorMessage',
          );
        } catch (e) {
          // If it's already our custom exception, rethrow it
          if (e is Exception && e.toString().contains('Lỗi OpenAI')) {
            rethrow;
          }
          // If can't parse, show generic error
          throw Exception(
            'Lỗi kết nối OpenAI (${response.statusCode}).\n\n'
            'Vui lòng thử lại sau vài phút.',
          );
        }
      }
    } on http.ClientException catch (e) {
      print('❌ [OpenAI] Network error: $e');
      throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra kết nối Internet.');
    } on SocketException catch (e) {
      print('❌ [OpenAI] Socket error: $e');
      throw Exception(
        'Không thể kết nối đến OpenAI. Vui lòng kiểm tra kết nối Internet.',
      );
    } catch (e) {
      print('❌ [OpenAI] Exception: $e');
      // If it's already a formatted exception, rethrow it
      if (e is Exception &&
          (e.toString().contains('không hợp lệ') ||
              e.toString().contains('vượt quá giới hạn') ||
              e.toString().contains('máy chủ'))) {
        rethrow;
      }
      throw Exception('Lỗi khi gọi OpenAI API: $e');
    }
  }

  /// Sinh bài giảng và câu hỏi trắc nghiệm dưới dạng JSON có cấu trúc
  Future<String> generateVideoLesson(String mathTopic) async {
    try {
      final messages = [
        {
          "role": "system",
          "content":
              r"""Bạn là giáo viên Toán 10 chuyên chương HỆ THỨC LƯỢNG TRONG TAM GIÁC.
Nhiệm vụ: Dựa vào chủ đề học sinh cung cấp, hãy trả về MỘT JSON hợp lệ theo đúng cấu trúc sau (KHÔNG có text nào bên ngoài JSON):
{
  "explanation": "Giải thích 3-5 câu tiếng Việt. Công thức LaTeX dùng $...$ (inline) và $$...$$ (display).",
  "questions": [
    {
      "question": "Câu hỏi? Công thức dùng $...$",
      "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "correct": 0
    }
  ]
}

QUAN TRỌNG – ĐỊNH DẠNG JSON HỢP LỆ:
- Dùng DẤU NHÁY KÉP " cho tất cả key và string value (KHÔNG dùng dấu nháy đơn ')
- Trong JSON string, mọi dấu \ của LaTeX phải viết là \\ (double backslash)
- Ví dụ ĐÚNG:  "$$\\frac{a}{\\sin A} = 2R$$"
- Ví dụ SAI:   "$$\frac{a}{\sin A} = 2R$$"

QUY TẮC CÔNG THỨC (bắt buộc dùng double backslash \\):
- Phân số: \\frac{tử}{mẫu}  →  ví dụ: $\\frac{a}{\\sin A}$
- Căn bậc 2: \\sqrt{x}  →  ví dụ: $\\sqrt{3}$
- Số mũ: x^{2}  →  ví dụ: $a^{2}$
- Lượng giác: \\sin, \\cos, \\tan, \\cot
- Hằng số: \\pi
- Công thức chính đặt trên dòng riêng: $$...$$

Ví dụ explanation đúng chuẩn (chú ý double backslash \\):
"Định lý sin: $$\\frac{a}{\\sin A} = \\frac{b}{\\sin B} = \\frac{c}{\\sin C} = 2R$$ với $R$ là bán kính đường tròn ngoại tiếp."

Yêu cầu: soạn ĐÚNG 10 câu hỏi, chỉ thuộc chương HỆ THỨC LƯỢNG TRONG TAM GIÁC (Toán 10), đa dạng từ dễ đến khó: giá trị lượng giác, định lý sin, định lý cô-sin, diện tích, Heron, ngoại tiếp, nội tiếp.
CHỈ trả về JSON, KHÔNG markdown, KHÔNG text ngoài JSON.""",
        },
        {
          "role": "user",
          "content": "Soạn bài giảng cho chủ đề sau:\n$mathTopic",
        },
      ];

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: json.encode({
              'model': _model,
              'messages': messages,
              'max_completion_tokens': 2500,
              'temperature': 0.7,
            }),
          )
          .timeout(
            const Duration(seconds: 40),
            onTimeout: () {
              throw Exception('Request timeout after 40 seconds');
            },
          );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        throw Exception(
          'OpenAI API lỗi (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('❌ [OpenAI] Failed to generate lesson: $e');
      return "Không thể tạo bài giảng ngay lúc này. Vui lòng thử lại sau.\nLỗi: $e";
    }
  }

  /// Test API key validity by making a simple request
  /// Returns true if API key is valid, false otherwise
  Future<bool> validateApiKey() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/models'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ [OpenAI] API key validation failed: $e');
      return false;
    }
  }
}
