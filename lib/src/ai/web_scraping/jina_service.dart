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
        'Accept': 'text/plain',
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
        return ScrapedContent(
          url: url,
          title: null, // Let OpenAI extract the title
          content: response.body,
          description: null,
          images: [],
          metadata: {},
          scrapedAt: DateTime.now(),
          source: ScrapingSource.jina,
        );
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
      final headers = <String, String>{
        'Accept': 'text/plain',
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
        final dailyLimit = response.headers['x-ratelimit-limit'];

        return JinaKeyInfo(
          isValid: true,
          hasApiKey: hasApiKey,
          remainingRequests: remainingRequests != null
              ? int.tryParse(remainingRequests)
              : null,
          dailyLimit: dailyLimit != null ? int.tryParse(dailyLimit) : null,
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

  const JinaKeyInfo({
    required this.isValid,
    this.errorMessage,
    required this.hasApiKey,
    this.remainingRequests,
    this.dailyLimit,
  });

  const JinaKeyInfo.invalid(String error)
    : isValid = false,
      errorMessage = error,
      hasApiKey = false,
      remainingRequests = null,
      dailyLimit = null;

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
