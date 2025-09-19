import 'package:flutter/foundation.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/ai/openai/models/bookmark_suggestions.dart';
import 'package:pinboard_wizard/src/ai/openai/openai_service.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/jina_service.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/models/scraped_content.dart';
import 'package:pinboard_wizard/src/service_locator.dart';

class AiBookmarkService extends ChangeNotifier {
  final AiSettingsService _settingsService;
  final OpenAiService _openAiService;
  final JinaService _jinaService;

  AiBookmarkService()
    : _settingsService = locator.get<AiSettingsService>(),
      _openAiService = locator.get<OpenAiService>(),
      _jinaService = locator.get<JinaService>();

  bool get canUseAi => _settingsService.canUseAi;
  bool get isEnabled => _settingsService.isEnabled;

  /// Analyzes a URL using Jina for scraping and OpenAI for generating suggestions
  /// Returns BookmarkSuggestions with title, description, and tags based on user settings
  Future<BookmarkSuggestions> analyzeUrl(String url) async {
    if (!canUseAi) {
      throw AiBookmarkException('AI service is not enabled or configured');
    }

    try {
      // Step 1: Scrape the URL using Jina
      final scrapedContent = await _scrapeUrl(url);

      // Step 2: Analyze content using OpenAI
      final suggestions = await _analyzeContent(url, scrapedContent);

      return suggestions;
    } catch (e) {
      if (e is AiBookmarkException) rethrow;
      throw AiBookmarkException('Failed to analyze URL: $e');
    }
  }

  Future<ScrapedContent> _scrapeUrl(String url) async {
    try {
      // Initialize Jina service with API key (if available)
      final jinaApiKey = _settingsService.webScrapingSettings.jinaApiKey;
      _jinaService.initialize(jinaApiKey?.isEmpty == true ? null : jinaApiKey);

      return await _jinaService.scrapeUrl(url);
    } catch (e) {
      throw AiBookmarkException('Failed to scrape URL content: $e');
    }
  }

  Future<BookmarkSuggestions> _analyzeContent(
    String url,
    ScrapedContent scrapedContent,
  ) async {
    try {
      // Initialize OpenAI service with API key
      final openAiApiKey = _settingsService.openaiSettings.apiKey;
      if (openAiApiKey?.isEmpty != false) {
        throw AiBookmarkException('OpenAI API key not configured');
      }

      _openAiService.initialize(openAiApiKey!);

      // Use user's settings for description length and tag count
      final descriptionMaxLength =
          _settingsService.openaiSettings.descriptionMaxLength;
      final maxTags = _settingsService.openaiSettings.maxTags;

      return await _openAiService.analyzeContent(
        url: url,
        content: scrapedContent,
        maxDescriptionLength: descriptionMaxLength,
        maxTags: maxTags,
      );
    } catch (e) {
      throw AiBookmarkException('Failed to analyze content with AI: $e');
    }
  }

  /// Validates that a URL can be processed
  bool isValidUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.hasScheme && uri.scheme.startsWith('http');
  }

  /// Tests the AI service connectivity
  Future<AiServiceTestResult> testConnection() async {
    if (!isEnabled) {
      return AiServiceTestResult(
        isWorking: false,
        message: 'AI service is disabled',
      );
    }

    try {
      final openAiApiKey = _settingsService.openaiSettings.apiKey;
      if (openAiApiKey?.isEmpty != false) {
        return AiServiceTestResult(
          isWorking: false,
          message: 'OpenAI API key not configured',
        );
      }

      // Test OpenAI connection
      _openAiService.initialize(openAiApiKey!);
      final openAiWorks = await _openAiService.testConnection();

      if (!openAiWorks) {
        return AiServiceTestResult(
          isWorking: false,
          message: 'OpenAI connection failed',
        );
      }

      // Test Jina connection
      final jinaApiKey = _settingsService.webScrapingSettings.jinaApiKey;
      _jinaService.initialize(jinaApiKey?.isEmpty == true ? null : jinaApiKey);
      final jinaWorks = await _jinaService.testConnection();

      if (!jinaWorks) {
        return AiServiceTestResult(
          isWorking: false,
          message: 'Jina web scraping service connection failed',
        );
      }

      return AiServiceTestResult(
        isWorking: true,
        message: 'AI bookmark service is working properly',
      );
    } catch (e) {
      return AiServiceTestResult(
        isWorking: false,
        message: 'Service test failed: $e',
      );
    }
  }

  @override
  void dispose() {
    _openAiService.dispose();
    _jinaService.dispose();
    super.dispose();
  }
}

class AiBookmarkException implements Exception {
  final String message;

  const AiBookmarkException(this.message);

  @override
  String toString() => 'AiBookmarkException: $message';
}

class AiServiceTestResult {
  final bool isWorking;
  final String message;

  const AiServiceTestResult({required this.isWorking, required this.message});
}
