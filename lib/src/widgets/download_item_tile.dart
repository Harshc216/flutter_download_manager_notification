import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../models/download_status.dart';

class DownloadItemTile extends StatelessWidget {
  const DownloadItemTile({
    super.key,
    required this.item,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
    required this.onOpen,
    required this.onToggleOpenMode,
  });

  final DownloadItem item;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggleOpenMode;

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
      case DownloadStatus.queued:
        return Colors.purple;
    }
  }

  IconData _getMediaIcon(DownloadItem item) {
    if (item.isImage) return Icons.image_rounded;
    if (item.isVideo) return Icons.video_library_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.status);
    final mediaIcon = _getMediaIcon(item);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(mediaIcon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.url,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (item.isDownloading || item.isPaused || item.status == DownloadStatus.queued) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.isDownloading
                        ? 'Downloading... ${item.progress}%'
                        : item.isPaused
                            ? 'Paused (${item.progress}%)'
                            : 'Queued...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    '${item.progress}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress / 100 : null,
                  backgroundColor: Colors.grey.shade200,
                  color: statusColor,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Control Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.isDownloading) ...[
                  OutlinedButton.icon(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    tooltip: 'Cancel',
                  ),
                ] else if (item.isPaused) ...[
                  ElevatedButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    tooltip: 'Cancel',
                  ),
                ] else if (item.isFailed || item.status == DownloadStatus.cancelled) ...[
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ] else if (item.isCompleted) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onOpen,
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Open Media',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
