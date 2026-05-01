import 'package:flutter/material.dart';

class ChemistryGameScreen extends StatefulWidget {
  const ChemistryGameScreen({super.key});

  @override
  State<ChemistryGameScreen> createState() => _ChemistryGameScreenState();
}

class _ChemistryGameScreenState extends State<ChemistryGameScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedAnswer;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Công thức tính diện tích hình tròn có bán kính r là gì?',
      'answers': ['πr', 'πr²', '2πr', '2πr²'],
      'correctAnswer': 1,
    },
    {
      'question': 'Nghiệm của phương trình 2x + 6 = 0 là bao nhiêu?',
      'answers': ['x = 3', 'x = -3', 'x = 6', 'x = -6'],
      'correctAnswer': 1,
    },
    {
      'question':
          'Định lý Pytago phát biểu: trong tam giác vuông, bình phương cạnh huyền bằng...',
      'answers': [
        'Tổng bình phương hai cạnh góc vuông',
        'Tích hai cạnh góc vuông',
        'Hiệu bình phương hai cạnh góc vuông',
        'Tổng hai cạnh góc vuông',
      ],
      'correctAnswer': 0,
    },
    {
      'question': 'Số nguyên tố nào sau đây lớn nhất?',
      'answers': ['11', '13', '17', '19'],
      'correctAnswer': 3,
    },
    {
      'question': 'Giới hạn của (sin x)/x khi x tiến tới 0 là bao nhiêu?',
      'answers': ['0', '1', '∞', 'Không xác định'],
      'correctAnswer': 1,
    },
  ];

  void _selectAnswer(int index) {
    if (_answered) return;

    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_currentQuestionIndex]['correctAnswer']) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answered = false;
        _selectedAnswer = null;
      });
    } else {
      _showResultDialog();
    }
  }

  void _resetGame() {
    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _answered = false;
      _selectedAnswer = null;
    });
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text(
              '🎉 Kết quả',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Điểm của bạn:',
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                const SizedBox(height: 10),
                Text(
                  '$_score/${_questions.length}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _getResultMessage(),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetGame();
                },
                child: const Text('Chơi lại'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Thoát'),
              ),
            ],
          ),
    );
  }

  String _getResultMessage() {
    final percentage = (_score / _questions.length) * 100;
    if (percentage >= 80) {
      return 'Xuất sắc! Bạn là chuyên gia Toán học! 🏆';
    } else if (percentage >= 60) {
      return 'Tốt lắm! Tiếp tục phát huy! 👍';
    } else if (percentage >= 40) {
      return 'Khá ổn! Hãy cố gắng thêm! 💪';
    } else {
      return 'Cần học thêm về Toán học nhé! 📚';
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestionIndex];
    final answers = question['answers'] as List<String>;
    final correctAnswer = question['correctAnswer'] as int;

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
                    colors: [const Color(0xFF388E3C), const Color(0xFF4CAF50)],
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
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            '🎮 Trò chơi Toán học',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoChip(
                          'Câu ${_currentQuestionIndex + 1}/${_questions.length}',
                          Icons.quiz,
                        ),
                        _buildInfoChip('Điểm: $_score', Icons.star),
                      ],
                    ),
                  ],
                ),
              ),

              // Question and Answers
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Question Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, Colors.teal.shade50],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            question['question'] as String,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Answer Options
                      ...List.generate(
                        answers.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildAnswerButton(
                            answers[index],
                            index,
                            correctAnswer,
                          ),
                        ),
                      ),

                      if (_answered) ...[
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _nextQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388E3C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            _currentQuestionIndex < _questions.length - 1
                                ? 'Câu tiếp theo →'
                                : 'Xem kết quả',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(String answer, int index, int correctAnswer) {
    Color? backgroundColor;
    Color? borderColor;
    IconData? icon;

    if (_answered) {
      if (index == correctAnswer) {
        backgroundColor = Colors.green.shade100;
        borderColor = Colors.green.shade600;
        icon = Icons.check_circle;
      } else if (index == _selectedAnswer) {
        backgroundColor = Colors.red.shade100;
        borderColor = Colors.red.shade600;
        icon = Icons.cancel;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? const Color(0xFF388E3C).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (borderColor ?? const Color(0xFF388E3C)).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color:
                        borderColor?.withOpacity(0.2) ??
                        const Color(0xFF388E3C).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: borderColor ?? const Color(0xFF388E3C),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    answer,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: borderColor ?? Colors.black87,
                    ),
                  ),
                ),
                if (icon != null) Icon(icon, color: borderColor, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
