import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_download_manager_notification_service/flutter_download_manager_notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DownloadManagerApp());
}

class DownloadManagerApp extends StatelessWidget {
  const DownloadManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Downloader',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const DownloadHomePage(),
    );
  }
}

class DownloadHomePage extends StatefulWidget {
  const DownloadHomePage({super.key});

  @override
  State<DownloadHomePage> createState() => _DownloadHomePageState();
}

class _DownloadHomePageState extends State<DownloadHomePage> {
  static const String _defaultUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';

  late final TextEditingController _urlController;
  final DownloadService _downloadService = DownloadService();
  StreamSubscription<DownloadTaskUpdate>? _updateSubscription;
  final Map<String, DownloadItem> _activeDownloads = {};

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _defaultUrl);
    _initDownloader();
  }

  Future<void> _initDownloader() async {
    await _downloadService.initialize();
    await _requestPermissions();

    _updateSubscription = _downloadService.updates.listen((update) {
      final item = _activeDownloads[update.taskId];
      if (item != null) {
        item.status = update.status;
        item.progress = update.progress;

        if (update.status == DownloadStatus.completed) {
          _activeDownloads.remove(update.taskId);
          if (mounted) {
            _downloadService.openFile(item: item, context: context);
          }
        }
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.notification,
      Permission.storage,
    ].request();
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _downloadService.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
        _clearError();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted URL from clipboard!'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _startDownload() async {
    _clearError();
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or paste an image or video URL.';
      });
      return;
    }

    try {
      final item = await _downloadService.download(
        url: url,
      );

      _activeDownloads[item.taskId] = item;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading ${item.fileName} with notification...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ArgumentError: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.photo_library_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Media Downloader',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Input Box
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste Image or Video Link',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paste a link below to download with live progress bar notification and save to Gallery.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),

                  // URL Input TextField with Paste Button
                  TextField(
                    controller: _urlController,
                    onChanged: (_) => _clearError(),
                    decoration: InputDecoration(
                      hintText: 'Paste image (.jpg, .png) or video (.mp4) URL...',
                      prefixIcon: const Icon(Icons.link_rounded, color: Colors.deepPurple),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_urlController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                              onPressed: () {
                                _urlController.clear();
                                _clearError();
                                setState(() {});
                              },
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade100,
                              foregroundColor: Colors.deepPurple,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_rounded, size: 16),
                            label: const Text(
                              'Paste',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download_rounded, size: 24),
                      label: const Text(
                        'Download to Gallery',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Validation Error Message Banner
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
