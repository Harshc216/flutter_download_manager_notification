import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_download_manager_notification_service/flutter_download_manager_notification_service.dart';

void main() {
  group('FileValidator Tests', () {
    test('Image URLs are validated correctly', () {
      expect(FileValidator.isSupportedMediaUrl('https://example.com/photo.jpg'), isTrue);
      expect(FileValidator.isSupportedMediaUrl('https://example.com/photo.png?size=large'), isTrue);
      expect(FileValidator.isSupportedMediaUrl('https://example.com/image.webp'), isTrue);
      expect(FileValidator.getMediaType('https://example.com/photo.png'), equals(MediaType.image));
    });

    test('Video URLs are validated correctly', () {
      expect(FileValidator.isSupportedMediaUrl('https://example.com/movie.mp4'), isTrue);
      expect(FileValidator.isSupportedMediaUrl('https://example.com/clip.mkv'), isTrue);
      expect(FileValidator.isSupportedMediaUrl('https://example.com/video.webm?quality=hd'), isTrue);
      expect(FileValidator.getMediaType('https://example.com/movie.mp4'), equals(MediaType.video));
    });

    test('Zip and archive URLs are rejected', () {
      expect(FileValidator.isZipOrArchive('https://example.com/file.zip'), isTrue);
      expect(FileValidator.isZipOrArchive('https://example.com/archive.rar?dl=1'), isTrue);
      expect(FileValidator.isZipOrArchive('https://example.com/package.7z'), isTrue);

      expect(FileValidator.isSupportedMediaUrl('https://example.com/file.zip'), isFalse);
      expect(FileValidator.isSupportedMediaUrl('https://example.com/archive.rar'), isFalse);
      expect(FileValidator.getMediaType('https://example.com/file.zip'), equals(MediaType.unsupported));
    });

    test('Sanitized filenames are generated properly', () {
      final imgName = FileValidator.getSanitizedFileName('https://example.com/nature.png?v=1');
      expect(imgName, equals('nature.png'));

      final vidName = FileValidator.getSanitizedFileName('https://example.com/trailer.mp4');
      expect(vidName, equals('trailer.mp4'));
    });
  });
}
