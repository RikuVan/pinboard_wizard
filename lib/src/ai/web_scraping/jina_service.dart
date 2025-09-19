import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pinboard_wizard/src/ai/web_scraping/models/scraped_content.dart';

class JinaService {
  static const String _baseUrl = 'https://r.jina.ai';
  final http.Client _client;
  String? _apiKey;

  JinaService({http.Client? client}) : _client = client ?? http.Client();

  void initialize(String? apiKey) {
    _apiKey = apiKey;
  }

  bool get isInitialized => true; // Jina works without API key (with limits)
  bool get hasApiKey => _apiKey?.isNotEmpty == true;

  Future<ScrapedContent> scrapeUrl(String url) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'User-Agent': 'Pinboard-Wizard/1.0',
      };

      // Add API key to headers if available
      if (hasApiKey) {
        headers['Authorization'] = 'Bearer $_apiKey';
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/$url'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return _parseJinaResponse(data, url);
      } else if (response.statusCode == 401) {
        throw JinaException('Invalid API key');
      } else if (response.statusCode == 429) {
        throw JinaException(
          'Rate limit exceeded. Consider adding an API key for higher limits.',
        );
      } else if (response.statusCode == 404) {
        throw JinaException('URL not found or not accessible');
      } else {
        throw JinaException(
          'Failed to scrape URL: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      if (e is JinaException) rethrow;
      throw JinaException('Network error: $e');
    }
  }

  ScrapedContent _parseJinaResponse(Map<String, dynamic> data, String url) {
    try {
      // Jina AI returns markdown content directly in the response body
      // along with some metadata

      final String content = data['content'] ?? data['data'] ?? '';
      final Map<String, dynamic> metadata = data['meta'] ?? <String, dynamic>{};

      // Extract title from content if not in metadata
      String? title = metadata['title'] as String?;
      if (title == null && content.isNotEmpty) {
        // Try to extract title from first heading in markdown
        final lines = content.split('\n');
        for (final line in lines.take(5)) {
          if (line.startsWith('# ')) {
            title = line.substring(2).trim();
            break;
          }
        }
      }

      // Extract description from metadata or first paragraph
      String? description = metadata['description'] as String?;
      if (description == null && content.isNotEmpty) {
        final lines = content.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty &&
              !trimmed.startsWith('#') &&
              !trimmed.startsWith('*') &&
              !trimmed.startsWith('-') &&
              trimmed.length > 50) {
            description = trimmed.length > 200
                ? '${trimmed.substring(0, 200)}...'
                : trimmed;
            break;
          }
        }
      }

      return ScrapedContent(
        url: url,
        title: title,
        content: content,
        description: description,
        images: _extractImages(metadata),
        metadata: _buildMetadata(metadata),
        scrapedAt: DateTime.now(),
        source: ScrapingSource.jina,
      );
    } catch (e) {
      throw JinaException('Failed to parse Jina response: $e');
    }
  }

  List<String> _extractImages(Map<String, dynamic> metadata) {
    final images = <String>[];

    // Try different possible image fields
    final imageFields = ['images', 'image', 'og_image', 'twitter_image'];

    for (final field in imageFields) {
      final value = metadata[field];
      if (value != null) {
        if (value is List) {
          images.addAll(value.cast<String>());
        } else if (value is String) {
          images.add(value);
        }
      }
    }

    return images.where((img) => img.isNotEmpty).take(5).toList();
  }

  Map<String, String> _buildMetadata(Map<String, dynamic> data) {
    final metadata = <String, String>{};

    final stringFields = [
      'author',
      'published_time',
      'site_name',
      'lang',
      'canonical_url',
      'og_type',
      'twitter_card',
    ];

    for (final field in stringFields) {
      final value = data[field];
      if (value != null && value.toString().isNotEmpty) {
        metadata[field] = value.toString();
      }
    }

    return metadata;
  }

  Future<bool> testConnection() async {
    try {
      // Test with a simple, reliable URL
      await scrapeUrl('https://example.com');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed information about the API key including quota and rate limits
  Future<JinaKeyInfo> getApiKeyInfo() async {
    try {
      // For Jina AI, we'll test with a simple request and check response headers
      final headers = <String, String>{
        'Accept': 'application/json',
        'User-Agent': 'Pinboard-Wizard/1.0',
      };

      if (hasApiKey) {
        headers['Authorization'] = 'Bearer $_apiKey';
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/https://example.com'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Check rate limit headers if available
        final remainingRequests = response.headers['x-ratelimit-remaining'];
        final resetTime = response.headers['x-ratelimit-reset'];
        final dailyLimit = response.headers['x-ratelimit-limit'];

        return JinaKeyInfo(
          isValid: true,
          hasApiKey: hasApiKey,
          remainingRequests: remainingRequests != null
              ? int.tryParse(remainingRequests)
              : null,
          dailyLimit: dailyLimit != null ? int.tryParse(dailyLimit) : null,
          resetTime: resetTime != null ? int.tryParse(resetTime) : null,
        );
      } else if (response.statusCode == 401) {
        // Only show error if we actually provided an API key
        if (hasApiKey) {
          return JinaKeyInfo.invalid('Invalid API key');
        } else {
          // No API key provided - this is fine for Jina, use free tier
          return JinaKeyInfo(isValid: true, hasApiKey: false);
        }
      } else if (response.statusCode == 429) {
        return JinaKeyInfo.invalid(
          'Rate limit exceeded. Consider adding an API key for higher limits.',
        );
      } else if (response.statusCode == 403) {
        return JinaKeyInfo.invalid('API key lacks required permissions');
      } else {
        return JinaKeyInfo.invalid('API error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is JinaException) {
        return JinaKeyInfo.invalid(e.message);
      }
      return JinaKeyInfo.invalid('Network error: $e');
    }
  }

  void dispose() {
    _client.close();
    _apiKey = null;
  }
}

class JinaException implements Exception {
  final String message;

  const JinaException(this.message);

  @override
  String toString() => 'JinaException: $message';
}

class JinaKeyInfo {
  final bool isValid;
  final String? errorMessage;
  final bool hasApiKey;
  final int? remainingRequests;
  final int? dailyLimit;
  final int? resetTime;

  const JinaKeyInfo({
    required this.isValid,
    this.errorMessage,
    required this.hasApiKey,
    this.remainingRequests,
    this.dailyLimit,
    this.resetTime,
  });

  const JinaKeyInfo.invalid(String error)
    : isValid = false,
      errorMessage = error,
      hasApiKey = false,
      remainingRequests = null,
      dailyLimit = null,
      resetTime = null;

  String get statusMessage {
    if (!isValid) {
      return errorMessage ?? 'Connection failed';
    }

    if (!hasApiKey) {
      return 'Free tier access (with rate limits)';
    }

    final parts = <String>['Premium access with API key'];

    if (remainingRequests != null && dailyLimit != null) {
      parts.add('$remainingRequests/$dailyLimit requests remaining');
    } else if (dailyLimit != null) {
      parts.add('$dailyLimit requests per day');
    }

    return parts.join(' • ');
  }
}
