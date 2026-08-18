import 'dart:async';
import 'dart:io';
import 'file_validator.dart';

/// Holds information about a resolved direct media URL.
class MediaUrlResult {
  const MediaUrlResult({
    required this.originalUrl,
    required this.resolvedUrl,
    required this.mediaType,
    required this.mimeType,
    required this.fileName,
    this.isResolvedFromWebpage = false,
  });

  final String originalUrl;
  final String resolvedUrl;
  final MediaType mediaType;
  final String mimeType;
  final String fileName;
  final bool isResolvedFromWebpage;
}

class MediaUrlResolver {
  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  /// Resolves an input URL (including Pinterest pin links, short links, or general media URLs)
  /// into a direct image/video URL that can be directly downloaded as a binary file.
  static Future<MediaUrlResult> resolveMediaUrl(String rawUrl) async {
    final cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) {
      throw ArgumentError('URL cannot be empty.');
    }

    Uri uri;
    try {
      uri = Uri.parse(cleanUrl);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$cleanUrl');
      }
    } catch (_) {
      throw ArgumentError('Invalid URL format: $cleanUrl');
    }

    final lowerHost = uri.host.toLowerCase();
    final lowerPath = uri.path.toLowerCase();

    // Check if URL is a Pinterest short link or pin page link
    final isPinterest = lowerHost.contains('pinterest.') ||
        lowerHost == 'pin.it' ||
        lowerPath.contains('/pin/');

    if (isPinterest) {
      return await _resolvePinterestUrl(uri.toString());
    }

    // Try standard direct URL or inspect headers/OG tags
    return await _resolveGeneralUrl(uri.toString());
  }

  /// Extracts the direct high-res photo URL from a Pinterest link.
  static Future<MediaUrlResult> _resolvePinterestUrl(String pinterestUrl) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(Uri.parse(pinterestUrl));
      request.headers.set('User-Agent', _defaultUserAgent);
      request.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8');
      request.headers.set('Accept-Language', 'en-US,en;q=0.9');

      final response = await request.close();

      // Get final redirected URL if any
      final redirectUrl = response.redirects.isNotEmpty
          ? response.redirects.last.location.toString()
          : pinterestUrl;

      final contentType = response.headers.contentType?.mimeType.toLowerCase() ?? '';

      // If the response is directly an image (e.g. direct i.pinimg.com link)
      if (contentType.startsWith('image/')) {
        final fileName = FileValidator.getSanitizedFileName(redirectUrl);
        return MediaUrlResult(
          originalUrl: pinterestUrl,
          resolvedUrl: redirectUrl,
          mediaType: MediaType.image,
          mimeType: contentType.isNotEmpty ? contentType : FileValidator.getMimeType(redirectUrl),
          fileName: fileName,
        );
      }

      // Read HTML string
      final html = await response.transform(const SystemEncoding().decoder).join();
      client.close();

      final directImageUrl = _extractPinterestImageFromHtml(html);
      if (directImageUrl != null && directImageUrl.isNotEmpty) {
        final highResUrl = _upgradePinterestResolution(directImageUrl);
        final fileName = FileValidator.getSanitizedFileName(highResUrl);
        final mimeType = FileValidator.getMimeType(highResUrl);

        return MediaUrlResult(
          originalUrl: pinterestUrl,
          resolvedUrl: highResUrl,
          mediaType: MediaType.image,
          mimeType: mimeType.contains('image/') ? mimeType : 'image/jpeg',
          fileName: fileName,
          isResolvedFromWebpage: true,
        );
      }

      throw ArgumentError(
        'Could not extract a photo from this Pinterest link. Please ensure the link is a public Pinterest pin.',
      );
    } catch (e) {
      client.close();
      if (e is ArgumentError) rethrow;
      throw ArgumentError('Failed to resolve Pinterest photo link: $e');
    }
  }

  /// Inspects general URLs, follows redirects, checks Content-Type, and extracts OG media tags if HTML.
  static Future<MediaUrlResult> _resolveGeneralUrl(String inputUrl) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(Uri.parse(inputUrl));
      request.headers.set('User-Agent', _defaultUserAgent);

      final response = await request.close();
      final contentType = response.headers.contentType?.mimeType.toLowerCase() ?? '';
      final finalUrl = response.redirects.isNotEmpty
          ? response.redirects.last.location.toString()
          : inputUrl;

      if (contentType.startsWith('image/')) {
        client.close();
        return MediaUrlResult(
          originalUrl: inputUrl,
          resolvedUrl: finalUrl,
          mediaType: MediaType.image,
          mimeType: contentType,
          fileName: FileValidator.getSanitizedFileName(finalUrl),
        );
      }

      if (contentType.startsWith('video/')) {
        client.close();
        return MediaUrlResult(
          originalUrl: inputUrl,
          resolvedUrl: finalUrl,
          mediaType: MediaType.video,
          mimeType: contentType,
          fileName: FileValidator.getSanitizedFileName(finalUrl),
        );
      }

      // If Content-Type is HTML, check for OpenGraph image/video tags
      if (contentType.contains('html') || contentType.contains('text')) {
        final html = await response.transform(const SystemEncoding().decoder).join();
        client.close();

        final ogVideo = _extractOgContent(html, 'og:video') ?? _extractOgContent(html, 'og:video:url');
        if (ogVideo != null && ogVideo.isNotEmpty) {
          return MediaUrlResult(
            originalUrl: inputUrl,
            resolvedUrl: ogVideo,
            mediaType: MediaType.video,
            mimeType: FileValidator.getMimeType(ogVideo),
            fileName: FileValidator.getSanitizedFileName(ogVideo),
            isResolvedFromWebpage: true,
          );
        }

        final ogImage = _extractOgContent(html, 'og:image') ?? _extractOgContent(html, 'twitter:image');
        if (ogImage != null && ogImage.isNotEmpty) {
          return MediaUrlResult(
            originalUrl: inputUrl,
            resolvedUrl: ogImage,
            mediaType: MediaType.image,
            mimeType: FileValidator.getMimeType(ogImage),
            fileName: FileValidator.getSanitizedFileName(ogImage),
            isResolvedFromWebpage: true,
          );
        }

        throw ArgumentError(
          'The provided URL is a web page and does not contain a direct downloadable image or video.',
        );
      }

      client.close();

      // Fallback based on extension
      final mediaType = FileValidator.getMediaType(finalUrl);
      if (mediaType == MediaType.unsupported) {
        throw ArgumentError(
          'Unsupported file format. Please provide a direct URL to an image (.jpg, .png, .webp) or video (.mp4).',
        );
      }

      return MediaUrlResult(
        originalUrl: inputUrl,
        resolvedUrl: finalUrl,
        mediaType: mediaType,
        mimeType: FileValidator.getMimeType(finalUrl),
        fileName: FileValidator.getSanitizedFileName(finalUrl),
      );
    } catch (e) {
      client.close();
      if (e is ArgumentError) rethrow;

      // Fallback if network head/get fails but URL extension is recognized
      final mediaType = FileValidator.getMediaType(inputUrl);
      if (mediaType != MediaType.unsupported) {
        return MediaUrlResult(
          originalUrl: inputUrl,
          resolvedUrl: inputUrl,
          mediaType: mediaType,
          mimeType: FileValidator.getMimeType(inputUrl),
          fileName: FileValidator.getSanitizedFileName(inputUrl),
        );
      }

      throw ArgumentError('Unable to resolve media URL: $e');
    }
  }

  /// Scrapes Pinterest direct image URLs from HTML document.
  static String? _extractPinterestImageFromHtml(String html) {
    // 1. Check og:image
    final ogImage = _extractOgContent(html, 'og:image');
    if (ogImage != null && ogImage.contains('pinimg.com')) {
      return ogImage;
    }

    // 2. Check twitter:image
    final twitterImage = _extractOgContent(html, 'twitter:image');
    if (twitterImage != null && twitterImage.contains('pinimg.com')) {
      return twitterImage;
    }

    // 3. Regex search for direct i.pinimg.com links in JSON/scripts
    final regex = RegExp(r'https:\\/\\/i\.pinimg\.com\\/[0-9x]+\\/[a-zA-Z0-9_\-\\/]+\.(?:jpg|jpeg|png|webp)');
    final match = regex.firstMatch(html);
    if (match != null) {
      return match.group(0)!.replaceAll(r'\/', '/');
    }

    final rawRegex = RegExp(r'https://i\.pinimg\.com/[0-9x]+/[a-zA-Z0-9_\-/]+\.(?:jpg|jpeg|png|webp)');
    final rawMatch = rawRegex.firstMatch(html);
    if (rawMatch != null) {
      return rawMatch.group(0);
    }

    return ogImage ?? twitterImage;
  }

  /// Extracts Open Graph meta content from HTML string.
  static String? _extractOgContent(String html, String propertyName) {
    final reg1 = RegExp(
      '<meta[^>]*property=["\']$propertyName["\'][^>]*content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    var match = reg1.firstMatch(html);
    if (match != null) return match.group(1);

    final reg2 = RegExp(
      '<meta[^>]*content=["\']([^"\']+)["\'][^>]*property=["\']$propertyName["\']',
      caseSensitive: false,
    );
    match = reg2.firstMatch(html);
    if (match != null) return match.group(1);

    final reg3 = RegExp(
      '<meta[^>]*name=["\']$propertyName["\'][^>]*content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    match = reg3.firstMatch(html);
    if (match != null) return match.group(1);

    return null;
  }

  /// Upgrades Pinterest thumbnail dimensions (e.g. /736x/, /564x/, /236x/) to /originals/ for full quality.
  static String _upgradePinterestResolution(String pinUrl) {
    return pinUrl.replaceAll(RegExp(r'/(?:[0-9]{2,4}x)/'), '/originals/');
  }
}
