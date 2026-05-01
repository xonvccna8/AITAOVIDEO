import 'package:flutter/material.dart';
import 'package:chemivision/services/gemini_service.dart';

class InfographicScreen extends StatefulWidget {
  const InfographicScreen({super.key});

  @override
  State<InfographicScreen> createState() => _InfographicScreenState();
}

class _InfographicScreenState extends State<InfographicScreen> {
  final TextEditingController _topicController = TextEditingController();
  late final GeminiService _geminiService;
  
  bool _isGenerating = false;
  String? _generatedContent;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService.fromEnvironment();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateInfographic() async {
    final topic = _topicController.text.trim();
    
    if (topic.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập chủ đề Toán học';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedContent = null;
    });

    try {
      final prompt = '''
Tạo nội dung infographic về Toán học với chủ đề: "$topic"

Hãy tạo nội dung theo cấu trúc sau:
1. Tiêu đề chính (ngắn gọn, thu hút)
2. 5-7 điểm thông tin quan trọng (mỗi điểm 1-2 câu)
3. Công thức/định lý liên quan
4. Ví dụ minh họa ngắn
5. Ứng dụng hoặc ý nghĩa Toán học

Định dạng rõ ràng, dễ đọc, phù hợp để hiển thị dạng infographic.
''';

      final content = await _geminiService.askChemistry(prompt);
      
      setState(() {
        _generatedContent = content;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tạo infographic: ${e.toString()}';
        _isGenerating = false;
      });
    }
  }

  void _clearContent() {
    setState(() {
      _generatedContent = null;
      _errorMessage = null;
      _topicController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2E7D32),
              const Color(0xFF4CAF50),
              const Color(0xFFAED6B0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF388E3C),
                      const Color(0xFF4CAF50),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '📊 Tạo Infographic Toán học',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      // Input Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.topic,
                                    color: const Color(0xFF388E3C),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Chủ đề Infographic',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _topicController,
                                maxLines: 3,
                                enabled: !_isGenerating,
                                decoration: InputDecoration(
                                  hintText:
                                      'Nhập chủ đề Toán học...\nVí dụ: "Định lý sin", "Định lý cô-sin", "Công thức Heron"...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF388E3C),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Generate Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isGenerating ? null : _generateInfographic,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF388E3C),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: _isGenerating
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Đang tạo...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.auto_awesome, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              'Tạo Infographic',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Error Message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Card(
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Generated Content
                      if (_generatedContent != null) ...[
                        const SizedBox(height: 20),
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.teal.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF388E3C).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.article,
                                        color: Color(0xFF388E3C),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Nội dung Infographic',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      color: const Color(0xFF388E3C),
                                      onPressed: _clearContent,
                                      tooltip: 'Tạo mới',
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),
                                Text(
                                  _generatedContent!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Instructions Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Hướng dẫn',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionItem(
                                '1. Nhập chủ đề Toán học bạn muốn tạo infographic',
                              ),
                              _buildInstructionItem(
                                '2. Nhấn "Tạo Infographic" để AI tạo nội dung',
                              ),
                              _buildInstructionItem(
                                '3. Xem và sử dụng nội dung được tạo',
                              ),
                              _buildInstructionItem(
                                '4. Có thể chụp màn hình hoặc sao chép nội dung',
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF388E3C),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


