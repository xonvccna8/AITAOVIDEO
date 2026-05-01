import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chemivision/config/api_config.dart';
import 'package:chemivision/services/openai_service.dart';
import 'package:chemivision/services/gemini_service.dart';
import 'package:chemivision/services/ai_video_service.dart';
import 'package:chemivision/services/gallery_service.dart';
import 'package:chemivision/screens/video_player_screen.dart';

class HistoricalEventScreen extends StatefulWidget {
  const HistoricalEventScreen({super.key});

  @override
  State<HistoricalEventScreen> createState() => _HistoricalEventScreenState();
}

class _HistoricalEventScreenState extends State<HistoricalEventScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final GalleryService _galleryService = GalleryService();

  File? _selectedImage;
  bool _isGenerating = false;

  final OpenAIService _openAIService =
      OpenAIService(apiKey: APIConfig.openAIKey);

  late final AIVideoService _videoService;
  late final GeminiService _geminiService;

  @override
  void initState() {
    super.initState();
    _videoService = AIVideoService(
      accessToken: APIConfig.aiVideoAccessToken,
      openAIService: _openAIService,
    );
    _geminiService = GeminiService.fromEnvironment(modelName: 'gemini-2.5-pro');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      final pickedPath = result?.files.single.path;
      if (pickedPath != null) {
        final cropped = await _cropTo169(File(pickedPath));
        if (!mounted || cropped == null) return;
        setState(() {
          _selectedImage = cropped;
        });
      }
    } catch (e) {
      _showErrorDialog('Lỗi khi chọn ảnh: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (image != null) {
        final cropped = await _cropTo169(File(image.path));
        if (!mounted || cropped == null) return;
        setState(() {
          _selectedImage = cropped;
        });
      }
    } catch (e) {
      _showErrorDialog('Lỗi khi chụp ảnh: $e');
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<File?> _cropTo169(File input) async {
    try {
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: input.path,
        // Không lock aspect ratio để user có thể crop chính xác phần muốn phân tích
        aspectRatio: null, // Free crop mode
        compressQuality: 90, // Giữ chất lượng cao cho Gemini phân tích tốt
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Chỉnh sửa ảnh để phân tích',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false, // Cho phép crop tự do
            hideBottomControls: false,
            showCropGrid: true, // Hiển thị lưới để crop chính xác
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white70,
            cropGridStrokeWidth: 2,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
            dimmedLayerColor: Colors.black87,
            statusBarColor: Theme.of(context).colorScheme.primary,
          ),
          IOSUiSettings(
            title: 'Chỉnh sửa ảnh để phân tích',
            aspectRatioLockEnabled: false, // Cho phép crop tự do
            resetAspectRatioEnabled: true,
            rotateButtonsHidden: false, // Cho phép xoay ảnh
            rotateClockwiseButtonHidden: false,
            hidesNavigationBar: false,
          ),
        ],
      );
      if (cropped != null) {
        return File(cropped.path);
      }
      return null;
    } catch (e) {
      _showErrorDialog('Lỗi khi chỉnh sửa ảnh: $e');
      return null;
    }
  }

  Future<void> _generateVideo() async {
    final text = _normalizeDescription(_textController.text.trim());
    final hasText = text.isNotEmpty;
    final hasImage = _selectedImage != null;

    if (!hasText && !hasImage) {
      _showErrorDialog('Vui lòng nhập text hoặc chọn ảnh');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    // Retry logic for unsafe generation
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        String? videoUrl;

        // Only handle Case 3: Both text and image
        if (hasText && hasImage) {
          if (retryCount > 0) {
            _showLoadingMessage(
              'Đang tạo lại prompt (lần ${retryCount + 1})...',
            );
          } else {
            _showLoadingMessage('Đang phân tích ảnh và tạo prompt...');
          }

          // Gemini phân tích ảnh -> tạo prompt -> gửi text lên Grok (không upload ảnh)
          try {
            final rawPrompt = await _geminiService.generateVideoPromptFromImage(
              _selectedImage!.path,
              userText: text,
            );
            String safePrompt;
            try {
              safePrompt = await _geminiService.rewritePromptSafer(rawPrompt);
            } catch (_) {
              safePrompt = rawPrompt;
            }

            _showLoadingMessage('Đang tạo video từ mô tả AI...');
            videoUrl = await _videoService.generateVideoFromText(safePrompt);
          } catch (geminiError) {
            final errorMsg = geminiError.toString().toLowerCase();
            if (errorMsg.contains('quá tải') ||
                errorMsg.contains('overloaded') ||
                errorMsg.contains('503')) {
              // Re-throw với message thân thiện hơn để catch block bên ngoài xử lý
              throw Exception(
                'Gemini đang quá tải sau nhiều lần thử.\n\n'
                'Vui lòng đợi 1-2 phút rồi thử lại.\n\n'
                'Lỗi: $geminiError',
              );
            }
            rethrow;
          }
        } else if (hasText && !hasImage) {
          _showErrorDialog(
            'Chế độ này yêu cầu cả text và ảnh.\n\n'
            'Vui lòng chọn/chụp ảnh để tiếp tục.',
          );
          break;
        } else if (!hasText && hasImage) {
          _showErrorDialog(
            'Chế độ này yêu cầu cả text và ảnh.\n\n'
            'Vui lòng nhập text để tiếp tục.',
          );
          break;
        }

        if (videoUrl != null && mounted) {
          // Auto-save video to gallery
          try {
            final title = text.isNotEmpty ? text : 'Video từ hình ảnh Toán học';
            await _galleryService.saveVideo(
              videoUrl: videoUrl,
              title: title,
              sourceType: 'image',
            );
            print('✅ [HistoricalEventScreen] Video auto-saved to gallery');
          } catch (e) {
            print(
              '⚠️ [HistoricalEventScreen] Failed to save video to gallery: $e',
            );
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

          // Navigate to video player screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(videoUrl: videoUrl!),
            ),
          );
        }

        // Success - break out of retry loop
        break;
      } on UnsafeGenerationException {
        retryCount++;
        // Unsafe generation detected, retry with new prompt from GPT

        if (retryCount >= maxRetries) {
          _showErrorDialog(
            'Video không thể tạo sau $maxRetries lần thử.\n\n'
            'Prompt bị coi là không an toàn. Vui lòng thử lại với nội dung khác.',
          );
          break;
        } else {
          _showLoadingMessage('⚠️ Prompt không an toàn, đang thử lại...');
          // Wait a bit before retry
          await Future.delayed(const Duration(seconds: 2));
          // Continue to next iteration
        }
      } on GenerationCancelledException {
        if (!mounted) return;
        _showLoadingMessage('Đã hủy quá trình tạo video');
        break;
      } on HumanFaceRejectedException catch (e) {
        // Show confirmation dialog for fallback
        if (!mounted) return;
        final shouldFallback = await _showHumanFaceRejectionDialog(e.message);
        if (shouldFallback) {
          try {
            _showLoadingMessage('Đang phân tích ảnh (Gemini) và tạo mô tả...');
            final rawPrompt = await _geminiService.generateVideoPromptFromImage(
              _selectedImage!.path,
              userText: text,
            );
            String safePrompt;
            try {
              safePrompt = await _geminiService.rewritePromptSafer(rawPrompt);
            } catch (_) {
              safePrompt = rawPrompt;
            }
            _showLoadingMessage('Đang tạo video từ mô tả AI...');
            final videoUrl = await _videoService.generateVideoFromText(
              safePrompt,
            );

            if (mounted) {
              try {
                final title =
                    text.isNotEmpty ? text : 'Video từ hình ảnh Toán học';
                await _galleryService.saveVideo(
                  videoUrl: videoUrl,
                  title: title,
                  sourceType: 'image',
                );
              } catch (_) {}
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
                ),
              );
            }
          } catch (fallbackError) {
            final errorMsg = fallbackError.toString().toLowerCase();
            if (errorMsg.contains('quá tải') ||
                errorMsg.contains('overloaded') ||
                errorMsg.contains('503')) {
              _showErrorDialog(
                'Gemini đang quá tải sau nhiều lần thử.\n\n'
                'Vui lòng đợi 1-2 phút rồi nhấn nút "Tạo video" lại.\n\n'
                'Hoặc thử lại sau vài phút khi server ít tải hơn.',
              );
            } else {
              _showErrorDialog('Lỗi khi tạo video từ mô tả: $fallbackError');
            }
          }
        }
        break;
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('quá tải') ||
            errorMsg.contains('overloaded') ||
            errorMsg.contains('503')) {
          _showErrorDialog(
            'Gemini đang quá tải sau nhiều lần thử.\n\n'
            'Vui lòng đợi 1-2 phút rồi nhấn nút "Tạo video" lại.\n\n'
            'Hoặc thử lại sau vài phút khi server ít tải hơn.',
          );
        } else {
          _showErrorDialog('Lỗi khi tạo video: $e');
        }
        break;
      }
    }

    setState(() {
      _isGenerating = false;
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

  Future<bool> _showHumanFaceRejectionDialog(String errorMessage) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Nhà cung cấp không chấp nhận ảnh'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhà cung cấp không hỗ trợ tải lên hình ảnh có hình người chân thực.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn có muốn tạo video mô tả theo ảnh bằng AI không?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI sẽ phân tích ảnh và tạo video dựa trên mô tả, không cần gửi ảnh lên server.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tạo video từ mô tả'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo video từ ảnh Toán học'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Description card
              Card(
                elevation: 2,
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
                            'Chế độ tạo video Toán học từ ảnh',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nhập mô tả và chọn/chụp ảnh bài toán, hình vẽ, công thức hoặc trang vở Toán học.\n'
                        'AI sẽ phân tích ảnh để xác định chủ đề, sau đó tạo video minh họa.\n\n'
                        'Enter a description and select/take a photo of a math problem, diagram, formula, or notebook page.\n'
                        'AI will analyze the image and create a math explainer video.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Input text box
              TextField(
                controller: _textController,
                maxLines: 5,
                enabled: !_isGenerating,
                decoration: InputDecoration(
                  hintText: 'Nhập mô tả/ý tưởng cho bài Toán...\n\nEnter description/idea for the math topic...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 24),

              // Image preview
              if (_selectedImage != null)
                Stack(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _clearImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),

              if (_selectedImage != null) const SizedBox(height: 24),

              // Image buttons row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Import ảnh'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Chụp ảnh'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Generate video button
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateVideo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isGenerating
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Tạo video',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),

              const SizedBox(height: 12),

              if (_isGenerating)
                OutlinedButton.icon(
                  onPressed: () {
                    _videoService.cancelGeneration();
                    setState(() {
                      _isGenerating = false;
                    });
                  },
                  icon: const Icon(Icons.stop_circle, color: Colors.red),
                  label: const Text(
                    'Hủy tạo',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}


