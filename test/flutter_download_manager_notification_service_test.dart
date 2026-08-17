import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_download_manager_notification_service/flutter_download_manager_notification_service.dart';

void main() {
  test('DownloadService can be instantiated', () {
    final service = DownloadService();
    expect(service, isNotNull);
  });
}
