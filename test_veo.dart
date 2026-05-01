import 'package:chemivision/config/api_config.dart';
import 'package:chemivision/services/ai_video_service.dart';

void main() async {
  print('==== Bắt đầu Test Model API ====');
  print('Model đang cấu hình: ${APIConfig.aiVideoModel}');
  print('Độ phân giải: ${APIConfig.aiVideoResolution}');
  print('URL API: ${APIConfig.aiVideoBaseUrl}');

  final service = AIVideoService(accessToken: APIConfig.aiVideoAccessToken);
  try {
    print('\nĐang gửi request tạo video dài 6s để test model...');
    final resultUrl = await service.generateVideoFromText(
      'Một chiếc ô tô thể thao màu đỏ đang lướt đi trên đường cao tốc ven biển, cinematic, 4k',
    );
    print('\n==== THÀNH CÔNG ====');
    print(
      '✅ Video đã được tạo xong thành công với model ${APIConfig.aiVideoModel}!',
    );
    print('🔗 Link Video: $resultUrl');
  } catch (e) {
    print('\n==== THẤT BẠI ====');
    print('❌ Lỗi khi tạo video: $e');
  }
}
