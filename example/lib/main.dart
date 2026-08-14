import 'package:flutter/material.dart';
import 'package:flutter_download_manager_notification_service/flutter_download_manager_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DownloadManager());
}

class DownloadManager extends StatelessWidget {
  const DownloadManager({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Download Manager',
      theme: ThemeData(useMaterial3: true),
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
  final TextEditingController _urlController = TextEditingController();
  final DownloadService _downloadService = DownloadService();
  String? _taskId;
  String _status = 'No Download Started';

  @override
  void initState() {
    super.initState();
    _initializeDownloader();
  }

  Future<void> _initializeDownloader() async {
    await _downloadService.initialize();
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _status = 'Please enter a download URL';
      });
      return;
    }

    try {
      final taskId = await _downloadService.download(
        url: url,
        fileName: 'downloaded_file',
      );
      setState(() {
        _taskId = taskId;
        _status = 'Download Started';
      });
    } catch (e) {
      setState(() {
        _status = 'Download failed to start';
      });
    }
  }

  Future<void> _pauseDownload() async {
    if (_taskId == null) return;

    await _downloadService.pause(_taskId!);

    setState(() {
      _status = 'Download paused';
    });
  }

  Future<void> _resumeDownload() async {
    if (_taskId == null) return;

    final newTaskId = await _downloadService.resume(_taskId!);
    if (newTaskId != null) {
      _taskId = newTaskId;
    }

    setState(() {
      _status = 'Download Resumed';
    });
  }

  Future<void> _cancelDownload() async {
    if (_taskId == null) return;

    await _downloadService.cancel(_taskId!);

    setState(() {
      _taskId = null;
      _status = 'Download Cancelled';
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download Manager')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Download URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startDownload,
              child: const Text('Start Download'),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: $_status',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_taskId != null) ...[
              OutlinedButton(
                onPressed: _pauseDownload,
                child: const Text('Pause'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _resumeDownload,
                child: const Text('Resume'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _cancelDownload,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
