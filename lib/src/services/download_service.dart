import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  Future<void> initialize() async {
    await FlutterDownloader.initialize(debug: false, ignoreSsl: true);
  }

  Future<String?> download({
    required String url,
    required String fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();

    return await FlutterDownloader.enqueue(
      url: url,
      savedDir: directory.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
    );
  }

  Future<void> pause(String taskId) async {
    await FlutterDownloader.pause(taskId: taskId);
  }

  Future<String?> resume(String taskId) async {
    return await FlutterDownloader.resume(taskId: taskId);
  }

  Future<void> cancel(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  Future<String?> retry(String taskId) async {
    return FlutterDownloader.retry(taskId: taskId);
  }
}
