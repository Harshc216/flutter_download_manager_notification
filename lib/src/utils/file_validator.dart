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
        final ext = path.substring(lastDotIndex + 1).toLowerCase();
        // Remove trailing slashes or path segments if any
        return ext.split('/').first;
      }
    } catch (_) {
      final cleanPath = urlOrPath.split('?').first.split('#').first;
      final lastDotIndex = cleanPath.lastIndexOf('.');
      if (lastDotIndex != -1 && lastDotIndex < cleanPath.length - 1) {
        return cleanPath.substring(lastDotIndex + 1).toLowerCase();
      }
    }
    return '';
  }

  /// Returns true if the URL points to a supported image or video file or a resolvable Pinterest pin.
  static bool isSupportedMediaUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('pinterest.') || lower.contains('pin.it')) {
      return true;
    }

    final ext = getExtension(url);
    if (ext.isEmpty) {
      return !isZipOrArchive(url);
    }
    return _imageExtensions.contains(ext) || _videoExtensions.contains(ext);
  }

  /// Returns true if the URL points to a web page (e.g. GitHub repository page) rather than a direct media file or resolvable media page.
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
        var lastSegment = Uri.decodeComponent(pathSegments.last);
        lastSegment = lastSegment.split('?').first.split('#').first;
        if (lastSegment.contains('.')) {
          final ext = getExtension(lastSegment);
          if (_imageExtensions.contains(ext) || _videoExtensions.contains(ext)) {
            return lastSegment;
          }
        }
      }
    } catch (_) {}

    final type = getMediaType(url);
    final ext = getExtension(url);
    final finalExt = ext.isNotEmpty && (_imageExtensions.contains(ext) || _videoExtensions.contains(ext))
        ? ext
        : (type == MediaType.video ? 'mp4' : 'jpg');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${defaultPrefix}_$timestamp.$finalExt';
  }

  /// Returns the exact MIME type string for a given path or URL extension.
  static String getMimeType(String pathOrUrl) {
    final ext = getExtension(pathOrUrl);
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        return 'video/webm';
      case '3gp':
        return 'video/3gpp';
      default:
        final type = getMediaType(pathOrUrl);
        if (type == MediaType.image) return 'image/jpeg';
        if (type == MediaType.video) return 'video/mp4';
        return '*/*';
    }
  }
}

