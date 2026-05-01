import 'package:flutter/material.dart';
import 'package:chemivision/services/gemini_service.dart';
import 'package:chemivision/services/youtube_search_service.dart';
import 'package:url_launcher/url_launcher.dart';

class QAScreen extends StatefulWidget {
  const QAScreen({super.key});

  @override
  State<QAScreen> createState() => _QAScreenState();
}

enum QALanguage { vietnamese, english }

class _QAScreenState extends State<QAScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_QAItem> _items = [];
  List<YouTubeVideoItem> _videos = [];
  GeminiService? _gemini;
  bool _initializing = true;
  bool _loading = false;
  String? _error;
  QALanguage _currentLanguage = QALanguage.vietnamese;

  @override
  void initState() {
    super.initState();
    _initGemini();
  }

  Future<void> _initGemini() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      _gemini = GeminiService.fromEnvironment(modelName: 'gemini-2.5-flash');
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<void> _ask() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _gemini == null) return;

    final userRole = _currentLanguage == QALanguage.vietnamese ? 'Bạn' : 'You';
    setState(() {
      _loading = true;
      _items.add(_QAItem(role: userRole, text: q));
      _controller.clear();
    });

    try {
      final a =
          _currentLanguage == QALanguage.vietnamese
              ? await _gemini!.askChemistry(q)
              : await _gemini!.askChemistryEnglish(q);
      if (!mounted) return;
      setState(() {
        _items.add(_QAItem(role: 'TOÁN HỌC 4.0', text: a));
      });
      // Tìm video YouTube liên quan
      final vids = await YouTubeSearchService.searchTopVideos(q, maxResults: 5);
      if (!mounted) return;
      setState(() {
        _videos = vids;
      });
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final rawError = e.toString();
      final isQuotaIssue =
          rawError.toLowerCase().contains('quota') ||
          rawError.toLowerCase().contains('rate limit') ||
          rawError.toLowerCase().contains('resource_exhausted') ||
          rawError.toLowerCase().contains('429') ||
          rawError.toLowerCase().contains('billing');
      final errorMsg =
          _currentLanguage == QALanguage.vietnamese
              ? (isQuotaIssue
                  ? 'Gemini hiện đang hết quota hoặc bị giới hạn tạm thời.\n'
                      'Vui lòng thử lại sau ít phút, hoặc đổi API key/project khác còn quota.\n\n'
                      '$rawError'
                  : 'Lỗi khi hỏi Gemini: $rawError')
              : (isQuotaIssue
                  ? 'Gemini is currently out of quota or temporarily rate-limited.\n'
                      'Please try again later, or switch to another API key/project with available quota.\n\n'
                      '$rawError'
                  : 'Error asking Gemini: $rawError');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF2E7D32),
              Color(0xFF4CAF50),
              Color(0xFFAED6B0),
              Color(0xFFCCFBF1),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 20,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF388E3C),
                      Color(0xFF4CAF50),
                      Color(0xFF2DD4BF),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Hỏi đáp kiến thức Toán học',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Language toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLanguageButton(
                            QALanguage.vietnamese,
                            'VI',
                            Icons.translate,
                          ),
                          _buildLanguageButton(
                            QALanguage.english,
                            'EN',
                            Icons.language,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child:
                    _initializing
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? _buildError(_error!)
                        : _buildChat(),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(QALanguage lang, String label, IconData icon) {
    final isSelected = _currentLanguage == lang;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _currentLanguage = lang;
            // Clear videos when switching language
            _videos.clear();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    final errorTitle =
        _currentLanguage == QALanguage.vietnamese
            ? 'Chưa cấu hình GEMINI_API_KEY'
            : 'GEMINI_API_KEY not configured';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 56, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              errorTitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in _items)
          Align(
            alignment:
                (item.role == 'Bạn' || item.role == 'You')
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (item.role == 'Bạn' || item.role == 'You')
                        ? Colors.white
                        : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    (item.role == 'Bạn' || item.role == 'You')
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  Text(
                    item.role,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          (item.role == 'Bạn' || item.role == 'You')
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF388E3C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.text),
                ],
              ),
            ),
          ),
        if (_videos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _currentLanguage == QALanguage.vietnamese
                ? 'Video liên quan trên YouTube'
                : 'Related YouTube Videos',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (final v in _videos)
            Card(
              child: ListTile(
                leading:
                    v.thumbnailUrl.isNotEmpty
                        ? Image.network(
                          v.thumbnailUrl,
                          width: 64,
                          height: 40,
                          fit: BoxFit.cover,
                        )
                        : const SizedBox(width: 64),
                title: Text(
                  v.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  v.channelTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _openUrl(v.url),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    _currentLanguage == QALanguage.vietnamese
                        ? 'Đặt câu hỏi về Toán học...'
                        : 'Ask a question about Mathematics...',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _loading ? null : _ask,
            icon:
                _loading
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.send),
            label: Text(
              _loading
                  ? (_currentLanguage == QALanguage.vietnamese
                      ? 'Đang hỏi...'
                      : 'Asking...')
                  : (_currentLanguage == QALanguage.vietnamese ? 'Hỏi' : 'Ask'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    // Try open in external app first
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    // Fallback: open in in-app webview
    await launchUrl(
      uri,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    );
  }
}

class _QAItem {
  final String role;
  final String text;
  _QAItem({required this.role, required this.text});
}


