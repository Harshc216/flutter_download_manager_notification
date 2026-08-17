import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/download_item.dart';

class InAppMediaViewer {
  static void open(BuildContext context, {required DownloadItem item}) {
    final filePath = item.filePath;
    if (filePath == null || !File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File not found at: ${filePath ?? "unknown path"}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (item.isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InAppImageViewer(
            filePath: filePath,
            title: item.fileName,
          ),
        ),
      );
    } else if (item.isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InAppVideoViewer(
            filePath: filePath,
            title: item.fileName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unsupported preview type'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }
}

class InAppImageViewer extends StatefulWidget {
  const InAppImageViewer({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<InAppImageViewer> createState() => _InAppImageViewerState();
}

class _InAppImageViewerState extends State<InAppImageViewer> {
  final TransformationController _transformationController = TransformationController();

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Zoom',
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: Center(
        child: GestureDetector(
          onDoubleTap: () {
            if (_transformationController.value != Matrix4.identity()) {
              _resetZoom();
            } else {
              _transformationController.value = Matrix4.identity()..scale(2.0, 2.0, 1.0);
            }
          },
          child: InteractiveViewer(
            transformationController: _transformationController,
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(
              File(widget.filePath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to render image: $error',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class InAppVideoViewer extends StatefulWidget {
  const InAppVideoViewer({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<InAppVideoViewer> createState() => _InAppVideoViewerState();
}

class _InAppVideoViewerState extends State<InAppVideoViewer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final file = File(widget.filePath);
      _controller = VideoPlayerController.file(file);
      await _controller.initialize();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _isInitialized = true;
      });
      _controller.play();
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load video: $e';
      });
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : !_isInitialized
                ? const CircularProgressIndicator(color: Colors.deepPurpleAccent)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio > 0
                                ? _controller.value.aspectRatio
                                : 16 / 9,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.deepPurpleAccent,
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white10,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_controller.value.position),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _controller.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (_controller.value.isPlaying) {
                                            _controller.pause();
                                          } else {
                                            _controller.play();
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _controller.value.volume == 0
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _controller.setVolume(
                                            _controller.value.volume == 0 ? 1.0 : 0.0,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  _formatDuration(_controller.value.duration),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
