import 'download_status.dart';

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.savedDir,
  });

  final int id;
  final String url;
  final String fileName;
  DownloadStatus status;
  int progress;
  final String? savedDir;
}
