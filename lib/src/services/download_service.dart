import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_item.dart';
import '../models/download_status.dart';
import '../utils/file_validator.dart';
import '../widgets/in_app_media_viewer.dart';

class DownloadTaskUpdate {
  DownloadTaskUpdate({
    required this.taskId,
    required this.status,
    required this.progress,
  });

  final String taskId;
  final DownloadStatus status;
  final int progress;
}

@pragma('vm:entry-point')
void _downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}

@pragma('vm:entry-point')
class DownloadService {
  static const String _portName = 'downloader_send_port';
  final ReceivePort _port = ReceivePort();
  final StreamController<DownloadTaskUpdate> _updateController =
      StreamController<DownloadTaskUpdate>.broadcast();

  Stream<DownloadTaskUpdate> get updates => _updateController.stream;

  Future<void> initialize() async {
    await FlutterDownloader.initialize(debug: false, ignoreSsl: true);

    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _portName);

    _port.listen((dynamic data) {
      final String id = data[0] as String;
      final DownloadTaskStatus rawStatus = DownloadTaskStatus.fromInt(data[1] as int);
      final int progress = data[2] as int;

      DownloadStatus status = DownloadStatus.queued;
      if (rawStatus == DownloadTaskStatus.running) {
        status = DownloadStatus.downloading;
      } else if (rawStatus == DownloadTaskStatus.complete) {
        status = DownloadStatus.completed;
      } else if (rawStatus == DownloadTaskStatus.paused) {
        status = DownloadStatus.paused;
      } else if (rawStatus == DownloadTaskStatus.failed) {
        status = DownloadStatus.failed;
      } else if (rawStatus == DownloadTaskStatus.canceled) {
        status = DownloadStatus.cancelled;
      }

      _updateController.add(
        DownloadTaskUpdate(
          taskId: id,
          status: status,
          progress: progress,
        ),
      );
    });

    FlutterDownloader.registerCallback(_downloadCallback);
  }

  /// Downloads media (images/videos only). Rejects zip and unsupported formats.
  Future<DownloadItem> download({
    required String url,
    String? fileName,
    bool openWithSystemApp = true,
    bool saveInPublicStorage = false,
  }) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      throw ArgumentError('Please enter a valid URL.');
    }

    if (FileValidator.isWebpageUrl(cleanUrl)) {
      throw ArgumentError(
        'GitHub repository page URLs cannot be downloaded as media files. Please enter a direct URL to a video (.mp4) or image (.png, .jpg) file.',
      );
    }

    if (FileValidator.isZipOrArchive(cleanUrl)) {
      throw ArgumentError(
        'Zip and archive files (.zip, .rar, .7z) are not supported. Only image and video downloads are permitted.',
      );
    }

    if (!FileValidator.isSupportedMediaUrl(cleanUrl)) {
      throw ArgumentError(
        'Unsupported file format. Please provide a direct URL to an image (.jpg, .png, etc.) or video (.mp4, .mkv, etc.).',
      );
    }

    final sanitizedFileName = fileName != null && fileName.trim().isNotEmpty
        ? fileName.trim()
        : FileValidator.getSanitizedFileName(cleanUrl);

    final mediaType = FileValidator.getMediaType(sanitizedFileName);

    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    }
    directory ??= await getApplicationDocumentsDirectory();

    final taskId = await FlutterDownloader.enqueue(
      url: cleanUrl,
      savedDir: directory.path,
      fileName: sanitizedFileName,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: saveInPublicStorage,
    );

    if (taskId == null) {
      throw Exception('Failed to enqueue download task.');
    }

    return DownloadItem(
      taskId: taskId,
      url: cleanUrl,
      fileName: sanitizedFileName,
      mediaType: mediaType,
      savedDir: directory.path,
      status: DownloadStatus.queued,
      progress: 0,
      openWithSystemApp: openWithSystemApp,
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
    return await FlutterDownloader.retry(taskId: taskId);
  }

  /// Opens the downloaded file according to the selected mode.
  /// If [item.openWithSystemApp] is true, opens using system intent (`OpenFilex`).
  /// If system opening fails or no external app exists, falls back to built-in `InAppMediaViewer`.
  Future<void> openFile({
    required DownloadItem item,
    required BuildContext context,
  }) async {
    final filePath = item.filePath;
    if (filePath == null || !File(filePath).existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded file not found at: ${filePath ?? "unknown path"}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (item.openWithSystemApp) {
      try {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No external app found to open this file (${result.message}). Opening in default in-app viewer...',
                ),
                backgroundColor: Colors.orangeAccent,
                duration: const Duration(seconds: 3),
              ),
            );
            InAppMediaViewer.open(context, item: item);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('System open error: $e. Opening in default in-app viewer...'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          InAppMediaViewer.open(context, item: item);
        }
      }
    } else {
      InAppMediaViewer.open(context, item: item);
    }
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping(_portName);
    _port.close();
    _updateController.close();
  }
}

