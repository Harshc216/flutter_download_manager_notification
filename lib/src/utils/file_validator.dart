enum MediaType {
  image,
  video,
  unsupported,
}

class FileValidator {
  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'heic',
    'ico',
  };

  static const Set<String> _videoExtensions = {
    'mp4',
    'mkv',
    'mov',
    'avi',
    'webm',
    'flv',
    '3gp',
    'm4v',
    'ts',
    'wmv',
  };

  static const Set<String> _archiveExtensions = {
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz',
    'iso',
  };

  /// Cleanly extracts file extension from URL or path (ignoring query strings/fragments).
  static String getExtension(String urlOrPath) {
    try {
      final uri = Uri.parse(urlOrPath);
      final path = uri.path;
      final lastDotIndex = path.lastIndexOf('.');
      if (lastDotIndex != -1 && lastDotIndex < path.length - 1) {
        return path.substring(lastDotIndex + 1).toLowerCase();
      }
    } catch (_) {
      // If URI parsing fails, fallback to string splitting
      final cleanPath = urlOrPath.split('?').first.split('#').first;
      final lastDotIndex = cleanPath.lastIndexOf('.');
      if (lastDotIndex != -1 && lastDotIndex < cleanPath.length - 1) {
        return cleanPath.substring(lastDotIndex + 1).toLowerCase();
      }
    }
    return '';
  }

  /// Returns true if the URL points to a supported image or video file.
  static bool isSupportedMediaUrl(String url) {
    final ext = getExtension(url);
    if (ext.isEmpty) {
      // If URL doesn't end with explicit extension, treat as potentially supported if not archive
      return !isZipOrArchive(url);
    }
    return _imageExtensions.contains(ext) || _videoExtensions.contains(ext);
  }

  /// Returns true if the URL points to a web page (e.g. GitHub repository page) rather than a direct media file.
  static bool isWebpageUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('github.com/') &&
        !lower.contains('/raw/') &&
        !lower.contains('.png') &&
        !lower.contains('.jpg') &&
        !lower.contains('.jpeg') &&
        !lower.contains('.mp4') &&
        !lower.contains('.mkv')) {
      return true;
    }
    return false;
  }

  /// Returns true if the URL points to a zip or archive file format.
  static bool isZipOrArchive(String url) {
    final ext = getExtension(url);
    return _archiveExtensions.contains(ext);
  }

  /// Returns the MediaType for a given URL or file path.
  static MediaType getMediaType(String urlOrPath) {
    final ext = getExtension(urlOrPath);
    if (_imageExtensions.contains(ext)) {
      return MediaType.image;
    }
    if (_videoExtensions.contains(ext)) {
      return MediaType.video;
    }
    return MediaType.unsupported;
  }

  /// Generates a clean, valid filename with proper extension from URL.
  static String getSanitizedFileName(String url, {String defaultPrefix = 'media_download'}) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (pathSegments.isNotEmpty) {
        final lastSegment = Uri.decodeComponent(pathSegments.last);
        if (lastSegment.contains('.')) {
          return lastSegment;
        }
      }
    } catch (_) {}

    final type = getMediaType(url);
    final ext = type == MediaType.video ? 'mp4' : 'jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${defaultPrefix}_$timestamp.$ext';
  }
}
