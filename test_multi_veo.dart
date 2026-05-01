import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:chemivision/config/api_config.dart';
import 'package:chemivision/services/ai_video_service.dart';

void main() async {
  print('==== BẮT ĐẦU TẠO 5 VIDEO CÙNG LÚC VỚI VEO_3_1 ====');
  print('Độ phân giải: ${APIConfig.aiVideoResolution}');
  print('API Model: ${APIConfig.aiVideoModel}');

  // ignore: unused_local_variable
  final masterPrompt =
      '''Cùng một nhân vật xuyên suốt tất cả các cảnh: Một người đàn ông Việt Nam trẻ, 25 tuổi, tóc đen ngắn, gương mặt sạch, đường nét hàm sắc nét, mặc áo sơ mi trắng và quần đen.

Phong cách đồng nhất: điện ảnh, siêu chân thực, 4K, ánh sáng tự nhiên mềm, độ sâu trường ảnh nông, chuyển động mượt, màu phim, chi tiết da cao

Phong cách camera: chuyển động camera chậm, điện ảnh, ổn định, chuyên nghiệp

Bối cảnh: căn hộ hiện đại tối giản, ánh nắng ấm chiếu qua cửa sổ, hướng ánh sáng nhất quán

Cảm xúc: bình tĩnh, tự tin, hơi cảm xúc

QUAN TRỌNG: cùng một nhân vật, cùng trang phục, cùng ánh sáng, cùng bối cảnh xuyên suốt cùng khuôn mặt, cùng danh tính, không thay đổi, nhân vật nhất quán''';

  final scenes = [
    'Người đàn ông đứng gần cửa sổ, nhìn ra ngoài đầy suy tư. Ánh nắng nhẹ chiếu vào mặt. Camera di chuyển chậm từ phía sau ra góc nghiêng khuôn mặt. Rèm cửa lay nhẹ theo gió.',
    'Người đàn ông xoay nhẹ về phía camera. Cảnh trung cận. Anh hít sâu, ánh mắt tập trung, thể hiện sự quyết tâm. Camera từ từ tiến gần.',
    'Người đàn ông đi chậm trong phòng. Camera tracking ngang theo chuyển động. Ánh sáng thay đổi nhẹ khi anh di chuyển, vẫn giữ cùng bối cảnh. Chuyển động tự nhiên, mượt mà.',
    'Cận cảnh khuôn mặt. Anh mỉm cười nhẹ đầy tự tin. Ánh mắt phản chiếu ánh sáng từ cửa sổ. Độ sâu trường ảnh rất nông. Camera tiến nhẹ vào.',
    'Người đàn ông đứng yên, nhìn thẳng vào camera. Ánh nắng trở nên ấm hơn. Camera từ từ lùi ra, lộ toàn thân. Kết thúc điện ảnh, cảm xúc mạnh mẽ nhưng bình tĩnh.',
  ];

  final timer = Stopwatch()..start();

  // Khởi tạo các promises (Future) chạy song song với các instance service độc lập
  final futures = scenes.asMap().entries.map((entry) async {
    final index = entry.key + 1;
    // ignore: unused_local_variable
    final scene = entry.value;

    final fullPrompt = '''$masterPrompt

------------------------------------------------------------------------
SCENE $index: $scene''';

    // Tạo Service riêng biệt cho mỗi video để tránh ghi đè trạng thái (state) nội bộ của class
    final service = AIVideoService(accessToken: APIConfig.aiVideoAccessToken);

    print('🟢 [SCENE $index] Đang gửi job...');
    try {
      final resultUrl = await service.generateVideoFromText(fullPrompt);
      print('✅ [SCENE $index] Hoàn thành: $resultUrl');
      return {'scene': index, 'status': 'Thành công', 'url': resultUrl};
    } catch (e) {
      print('❌ [SCENE $index] Lỗi: $e');
      return {'scene': index, 'status': 'Lỗi', 'url': e.toString()};
    }
  });

  // Future.wait sẽ chạy đồng thời 5 request
  final results = await Future.wait(futures);

  timer.stop();

  print('\\n==== KẾT QUẢ TỔNG HỢP VÀO LÚC ${DateTime.now()} ====');
  print('Tổng thời gian hoàn thành 5 video: ${timer.elapsed.inSeconds} giây');

  for (var res in results) {
    if (res['status'] == 'Thành công') {
      print("🎬 SCENE ${res['scene']}: ${res['url']}");
    } else {
      print("❌ SCENE ${res['scene']} (Lỗi): ${res['url']}");
    }
  }

  print('\\n==== TIẾN HÀNH TẢI VÀ GHÉP VIDEO BẰNG FFMPEG ====');
  final downloadedFiles = <String>[];

  for (var res in results) {
    if (res['status'] == 'Thành công') {
      final url = res['url'] as String;
      final sceneIndex = res['scene'];
      final fileName = 'veo_scene_$sceneIndex.mp4';

      print('⏳ Đang tải file $fileName...');
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final file = File(fileName);
          await file.writeAsBytes(response.bodyBytes);
          print('✅ Đã tải xong $fileName');
          downloadedFiles.add(fileName);
        } else {
          print('❌ Lỗi tải $fileName (Mã lỗi: ${response.statusCode})');
        }
      } catch (e) {
        print('❌ Lỗi tải $fileName: $e');
      }
    }
  }

  if (downloadedFiles.isEmpty) {
    print('❌ Không có video nào được tạo thành công để ghép.');
    return;
  }

  // Sắp xếp file theo thứ tự scene
  downloadedFiles.sort();

  // Tạo file list txt cho ffmpeg
  final listFile = File('ffmpeg_list.txt');
  final listContent = downloadedFiles.map((e) => "file '$e'").join('\\n');
  await listFile.writeAsString(listContent);

  // Ghép video
  final outputFile = 'veo_final_merged.mp4';
  if (File(outputFile).existsSync()) {
    await File(outputFile).delete();
  }

  print('\\n⏳ Đang ghép ${downloadedFiles.length} video bằng FFmpeg...');
  try {
    final process = await Process.run('ffmpeg', [
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      'ffmpeg_list.txt',
      '-c',
      'copy',
      outputFile,
    ]);

    if (process.exitCode == 0) {
      print('✅ GHÉP VIDEO THÀNH CÔNG: $outputFile');
    } else {
      print('❌ Lỗi khi ghép video FFmpeg (Mã lỗi ${process.exitCode})');
      print(process.stderr);
    }
  } catch (e) {
    print(
      '❌ Lỗi thực thi FFmpeg: $e\\n(Có thể do máy tính của bạn chưa được cài FFmpeg vào biến môi trường Path)',
    );
  }

  // Dọn dẹp file rác
  print('\\n🧹 Đang dọn dẹp các tệp tạm thời...');
  if (listFile.existsSync()) await listFile.delete();
  // Bỏ comment đoạn dưới để xóa các video lẻ
  /*
  for (var f in downloadedFiles) {
    final tempFile = File(f);
    if (tempFile.existsSync()) await tempFile.delete();
  }
  */
  print('==== KẾT THÚC ====');
}
