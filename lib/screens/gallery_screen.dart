import 'package:flutter/material.dart';
import 'package:chemivision/services/gallery_service.dart';
import 'package:chemivision/screens/video_player_screen.dart';
import 'package:chemivision/config/api_config.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryService _galleryService = GalleryService();
  List<SavedVideo> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    // Lắng nghe mọi thay đổi từ GalleryService (singleton)
    _galleryService.addListener(_onGalleryChanged);
  }

  @override
  void dispose() {
    _galleryService.removeListener(_onGalleryChanged);
    super.dispose();
  }

  void _onGalleryChanged() {
    // Tự động tải lại khi có video mới được lưu / xóa
    if (mounted) _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final videos = await _galleryService.getVideos();
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorDialog('Lỗi khi tải danh sách video: $e');
      }
    }
  }

  Future<void> _deleteVideo(SavedVideo video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc muốn xóa video "${video.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final deleted = await _galleryService.deleteVideo(video.id);
      if (deleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa video'),
            backgroundColor: Colors.green,
          ),
        );
        _loadVideos();
      }
    }
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _getSourceTypeLabel(String sourceType) {
    switch (sourceType) {
      case 'text':
        return 'Từ văn bản';
      case 'image':
        return 'Từ hình ảnh';
      default:
        return sourceType;
    }
  }

  IconData _getSourceTypeIcon(String sourceType) {
    switch (sourceType) {
      case 'text':
        return Icons.edit_note;
      case 'image':
        return Icons.image;
      default:
        return Icons.video_library;
    }
  }

  Color _getSourceTypeColor(String sourceType) {
    switch (sourceType) {
      case 'text':
        return const Color(0xFF2E7D32); // Indigo
      case 'image':
        return const Color(0xFFD97706); // Amber
      default:
        return Colors.grey;
    }
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
              const Color(0xFF2E7D32), // Teal 700
              const Color(0xFF4CAF50), // Teal 400
              const Color(0xFFAED6B0), // Teal 300
              const Color(0xFFCCFBF1), // Teal 100
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
                  vertical: 20,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF388E3C), // Teal 600
                      const Color(0xFF4CAF50), // Teal 400
                      const Color(0xFF2DD4BF), // Teal 300
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
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
                        'Phòng triển lãm Toán học',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadVideos,
                      tooltip: 'Làm mới',
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : _videos.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 80,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có video nào',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Các video đã tạo sẽ được lưu tự động ở đây',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                        : RefreshIndicator(
                          onRefresh: _loadVideos,
                          color: Colors.white,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _videos.length,
                            itemBuilder: (context, index) {
                              final video = _videos[index];
                              return _buildVideoCard(video);
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(SavedVideo video) {
    final sourceColor = _getSourceTypeColor(video.sourceType);
    final sourceIcon = _getSourceTypeIcon(video.sourceType);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => VideoPlayerScreen(
                    videoUrl: video.videoUrl,
                    videoTitle: video.title,
                    openAIApiKey: APIConfig.openAIKey,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Source type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sourceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sourceColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sourceIcon, color: sourceColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _getSourceTypeLabel(video.sourceType),
                          style: TextStyle(
                            color: sourceColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteVideo(video),
                    tooltip: 'Xóa video',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                video.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Date
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(video.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Play button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [sourceColor.withOpacity(0.8), sourceColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Xem video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
