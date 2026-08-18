import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_download_manager_notification_service/flutter_download_manager_notification_service.dart';

void main() {
  test('DownloadService can be instantiated', () {
    final service = DownloadService();
    expect(service, isNotNull);
  });

  group('FileValidator Tests', () {
    test('Identifies supported media URLs correctly', () {
      expect(FileValidator.isSupportedMediaUrl('https://example.com/image.png'), isTrue);
      expect(FileValidator.isSupportedMediaUrl('https://example.com/video.mp4'), isTrue);
      expect(FileValidator.isSupportedMediaUrl('https://example.com/file.zip'), isFalse);
    });

    test('Detects archive and webpage URLs', () {
      expect(FileValidator.isZipOrArchive('https://example.com/file.zip'), isTrue);
      expect(FileValidator.isWebpageUrl('https://github.com/user/repo'), isTrue);
      expect(FileValidator.isWebpageUrl('https://raw.githubusercontent.com/user/repo/main/image.png'), isFalse);
    });

    test('Identifies Pinterest pin URLs as supported', () {
      expect(FileValidator.isSupportedMediaUrl('https://pin.it/3XG5abc'), isTrue);
      expect(FileValidator.isSupportedMediaUrl('https://www.pinterest.com/pin/1234567890/'), isTrue);
    });

    test('Generates sanitized filenames', () {
      final name = FileValidator.getSanitizedFileName('https://example.com/photos/cat.png');
      expect(name, equals('cat.png'));
    });
  });

  group('DownloadItem Tests', () {
    test('Calculates media type and filePath accurately', () {
      final item = DownloadItem(
        taskId: 'test_task_1',
        url: 'https://example.com/video.mp4',
        fileName: 'video.mp4',
        savedDir: '/tmp',
      );

      expect(item.isVideo, isTrue);
      expect(item.isImage, isFalse);
      expect(item.filePath, isNotNull);
    });
  });
}
