import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';
import 'package:pinboard_wizard/src/ai/openai/models/bookmark_suggestions.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/models/scraped_content.dart';

class OpenAiService {
  OpenAIClient? _client;
  String? _apiKey;

  void initialize(String apiKey) {
    _apiKey = apiKey;
    _client = OpenAIClient(apiKey: apiKey);
  }

  bool get isInitialized => _client != null && _apiKey != null;

  Future<BookmarkSuggestions> analyzeContent({
    required String url,
    required ScrapedContent content,
    required int maxDescriptionLength,
    required int maxTags,
  }) async {
    if (!isInitialized) {
      throw OpenAiException('OpenAI service not initialized');
    }

    try {
      final prompt = _buildAnalysisPrompt(
        url: url,
        content: content,
        maxDescriptionLength: maxDescriptionLength,
        maxTags: maxTags,
      );

      final response = await _client!.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: const ChatCompletionModel.modelId('gpt-3.5-turbo'),
          messages: [
            const ChatCompletionMessage.system(
              content:
                  'You are a helpful assistant that analyzes web content and generates structured bookmark metadata. Respond only with valid JSON.',
            ),
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(prompt),
            ),
          ],
          maxTokens: 300,
          temperature: 0.3,
        ),
      );

      if (response.choices.isEmpty) {
        throw OpenAiException('No response from OpenAI');
      }

      final choice = response.choices.first;
      final responseContent = choice.message.content?.trim() ?? '';
      if (responseContent.isEmpty) {
        throw OpenAiException('Empty response from OpenAI');
      }

      return _parseResponse(responseContent, url);
    } catch (e) {
      if (e is OpenAiException) rethrow;
      throw OpenAiException('Failed to analyze content: $e');
    }
  }

  String _buildAnalysisPrompt({
    required String url,
    required ScrapedContent content,
    required int maxDescriptionLength,
    required int maxTags,
  }) {
    final contentPreview = content.cleanContent.length > 2000
        ? '${content.cleanContent.substring(0, 2000)}...'
        : content.cleanContent;

    return '''
Analyze this web page and create bookmark metadata:

URL: $url
Original Title: ${content.title ?? 'None'}
Original Description: ${content.description ?? 'None'}
Content: $contentPreview

Generate:
1. A clear, descriptive title (max 80 characters)
2. A brief description (max $maxDescriptionLength characters)
3. Up to $maxTags relevant tags (lowercase, single words)

Focus on the main topic and purpose. Be accurate and concise.

IMPORTANT: Respond ONLY with valid JSON in this exact format:
{
  "title": "your title here",
  "description": "your description here",
  "tags": ["tag1", "tag2", "tag3"]
}''';
  }

  BookmarkSuggestions _parseResponse(String responseContent, String url) {
    try {
      // Try to extract JSON from response if it contains additional text
      final jsonStart = responseContent.indexOf('{');
      final jsonEnd = responseContent.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1 || jsonStart >= jsonEnd) {
        throw OpenAiException('No valid JSON found in response');
      }

      final jsonString = responseContent.substring(jsonStart, jsonEnd + 1);
      final Map<String, dynamic> json = jsonDecode(jsonString);

      final openAiResponse = OpenAiResponse(
        title: json['title'] as String?,
        description: json['description'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      );

      return openAiResponse.toBookmarkSuggestions(url);
    } catch (e) {
      throw OpenAiException('Failed to parse OpenAI response: $e');
    }
  }

  Future<bool> testConnection() async {
    if (!isInitialized) return false;

    try {
      final response = await _client!.createChatCompletion(
        request: const CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId('gpt-3.5-turbo'),
          messages: [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('Hello'),
            ),
          ],
          maxTokens: 5,
        ),
      );

      return response.choices.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed information about the API key including available models and usage
  Future<OpenAiKeyInfo> getApiKeyInfo() async {
    if (!isInitialized) {
      throw OpenAiException('OpenAI service not initialized');
    }

    try {
      // Get available models to verify permissions
      final modelsResponse = await _client!.listModels();
      final models = modelsResponse.data;

      // Filter for models we care about
      final chatModels = models
          .where(
            (model) =>
                model.id.contains('gpt') && !model.id.contains('instruct'),
          )
          .toList();
      final hasGpt35 = models.any((model) => model.id == 'gpt-3.5-turbo');
      final hasGpt4 = models.any((model) => model.id.startsWith('gpt-4'));

      // Try a minimal completion to verify chat permissions
      bool canChat = false;
      try {
        final testResponse = await _client!.createChatCompletion(
          request: const CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId('gpt-3.5-turbo'),
            messages: [
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string('Hi'),
              ),
            ],
            maxTokens: 1,
          ),
        );
        canChat = testResponse.choices.isNotEmpty;
      } catch (e) {
        canChat = false;
      }

      return OpenAiKeyInfo(
        isValid: true,
        totalModels: models.length,
        chatModels: chatModels.length,
        hasGpt35Turbo: hasGpt35,
        hasGpt4: hasGpt4,
        canCreateCompletions: canChat,
        availableModels: chatModels.map((m) => m.id).take(5).toList(),
      );
    } catch (e) {
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        return OpenAiKeyInfo.invalid('Invalid API key or unauthorized');
      } else if (e.toString().contains('429')) {
        return OpenAiKeyInfo.invalid('Rate limit exceeded or quota reached');
      } else if (e.toString().contains('403')) {
        return OpenAiKeyInfo.invalid('API key lacks required permissions');
      } else {
        return OpenAiKeyInfo.invalid('Connection error: ${e.toString()}');
      }
    }
  }

  void dispose() {
    _client?.endSession();
    _client = null;
    _apiKey = null;
  }
}

class OpenAiException implements Exception {
  final String message;

  const OpenAiException(this.message);

  @override
  String toString() => 'OpenAiException: $message';
}

class OpenAiKeyInfo {
  final bool isValid;
  final String? errorMessage;
  final int totalModels;
  final int chatModels;
  final bool hasGpt35Turbo;
  final bool hasGpt4;
  final bool canCreateCompletions;
  final List<String> availableModels;

  const OpenAiKeyInfo({
    required this.isValid,
    this.errorMessage,
    required this.totalModels,
    required this.chatModels,
    required this.hasGpt35Turbo,
    required this.hasGpt4,
    required this.canCreateCompletions,
    required this.availableModels,
  });

  const OpenAiKeyInfo.invalid(String error)
    : isValid = false,
      errorMessage = error,
      totalModels = 0,
      chatModels = 0,
      hasGpt35Turbo = false,
      hasGpt4 = false,
      canCreateCompletions = false,
      availableModels = const [];

  String get statusMessage {
    if (!isValid) {
      return errorMessage ?? 'Invalid API key';
    }

    final features = <String>[];
    if (canCreateCompletions) features.add('Chat completions');
    if (hasGpt35Turbo) features.add('GPT-3.5 Turbo');
    if (hasGpt4) features.add('GPT-4');

    return 'Valid API key • ${features.join(' • ')} • $totalModels models available';
  }
}
