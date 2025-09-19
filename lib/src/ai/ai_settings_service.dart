import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinboard_wizard/src/ai/ai_settings.dart';
import 'package:pinboard_wizard/src/ai/openai/openai_service.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/jina_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';

class AiSettingsService extends ChangeNotifier {
  static const String _aiSettingsKey = 'ai_settings';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  AiSettings _settings = const AiSettings();

  AiSettings get settings => _settings;

  bool get isEnabled => _settings.isEnabled;
  bool get canUseAi => _settings.canUseAi;
  OpenAiSettings get openaiSettings => _settings.openai;
  WebScrapingSettings get webScrapingSettings => _settings.webScraping;

  AiSettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settingsJson = await _secureStorage.read(key: _aiSettingsKey);
      if (settingsJson != null && settingsJson.isNotEmpty) {
        final Map<String, dynamic> settingsMap = json.decode(settingsJson);
        _settings = AiSettings.fromJson(settingsMap);
        notifyListeners();
      }
    } catch (e) {
      // If loading fails, keep default settings
      debugPrint('Failed to load AI settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final settingsJson = json.encode(_settings.toJson());
      await _secureStorage.write(key: _aiSettingsKey, value: settingsJson);
    } catch (e) {
      throw AiSettingsException('Failed to save AI settings: $e');
    }
  }

  Future<void> setAiEnabled(bool enabled) async {
    _settings = _settings.copyWith(isEnabled: enabled);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setOpenAiApiKey(String? apiKey) async {
    final updatedOpenAi = _settings.openai.copyWith(apiKey: apiKey?.trim());
    _settings = _settings.copyWith(openai: updatedOpenAi);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setJinaApiKey(String? apiKey) async {
    final updatedWebScraping = _settings.webScraping.copyWith(
      jinaApiKey: apiKey?.trim(),
    );
    _settings = _settings.copyWith(webScraping: updatedWebScraping);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDescriptionMaxLength(int length) async {
    if (length < 20 || length > 300) {
      throw AiSettingsException(
        'Description max length must be between 20 and 300 characters',
      );
    }
    final updatedOpenAi = _settings.openai.copyWith(
      descriptionMaxLength: length,
    );
    _settings = _settings.copyWith(openai: updatedOpenAi);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMaxTags(int maxTags) async {
    if (maxTags < 0 || maxTags > 10) {
      throw AiSettingsException('Max tags must be between 0 and 10');
    }
    final updatedOpenAi = _settings.openai.copyWith(maxTags: maxTags);
    _settings = _settings.copyWith(openai: updatedOpenAi);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> clearOpenAiSettings() async {
    final clearedOpenAi = const OpenAiSettings();
    _settings = _settings.copyWith(openai: clearedOpenAi);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> clearWebScrapingSettings() async {
    final clearedWebScraping = const WebScrapingSettings();
    _settings = _settings.copyWith(webScraping: clearedWebScraping);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> clearAllAiSettings() async {
    _settings = const AiSettings();
    try {
      await _secureStorage.delete(key: _aiSettingsKey);
    } catch (e) {
      throw AiSettingsException('Failed to clear AI settings: $e');
    }
    notifyListeners();
  }

  Future<bool> validateOpenAiApiKey(String apiKey) async {
    // Basic validation - OpenAI keys start with 'sk-' and are 51 characters
    final trimmedKey = apiKey.trim();
    return trimmedKey.startsWith('sk-') && trimmedKey.length == 51;
  }

  Future<bool> validateJinaApiKey(String apiKey) async {
    // Jina AI keys are optional - empty is valid (free tier)
    final trimmedKey = apiKey.trim();
    return trimmedKey.isEmpty || trimmedKey.length > 10;
  }

  /// Test OpenAI API key by making an actual API call and getting detailed info
  Future<OpenAiTestResult> testOpenAiConnection(String apiKey) async {
    try {
      final openAiService = locator.get<OpenAiService>();
      openAiService.initialize(apiKey);

      final keyInfo = await openAiService.getApiKeyInfo();

      return OpenAiTestResult(
        isValid: keyInfo.isValid,
        message: keyInfo.statusMessage,
        hasGpt35Turbo: keyInfo.hasGpt35Turbo,
        hasGpt4: keyInfo.hasGpt4,
        canCreateCompletions: keyInfo.canCreateCompletions,
        totalModels: keyInfo.totalModels,
      );
    } catch (e) {
      return OpenAiTestResult(
        isValid: false,
        message: 'Error testing API key: ${e.toString()}',
      );
    }
  }

  /// Test Jina AI connection (works with or without API key)
  Future<JinaTestResult> testJinaConnection(String? apiKey) async {
    try {
      final jinaService = locator.get<JinaService>();
      final cleanApiKey = apiKey?.trim();
      jinaService.initialize(cleanApiKey?.isEmpty == true ? null : cleanApiKey);

      final keyInfo = await jinaService.getApiKeyInfo();

      return JinaTestResult(
        isValid: keyInfo.isValid,
        message: keyInfo.statusMessage,
        hasApiKey: keyInfo.hasApiKey,
        remainingRequests: keyInfo.remainingRequests,
        dailyLimit: keyInfo.dailyLimit,
      );
    } catch (e) {
      // For Jina, if no API key is provided, it should still work with free tier
      if (apiKey?.trim().isEmpty == true) {
        return JinaTestResult(
          isValid: true,
          message: 'Free tier access (with rate limits)',
          hasApiKey: false,
        );
      }
      return JinaTestResult(
        isValid: false,
        message: 'Error testing connection: ${e.toString()}',
      );
    }
  }
}

class AiSettingsException implements Exception {
  final String message;

  const AiSettingsException(this.message);

  @override
  String toString() => 'AiSettingsException: $message';
}

class OpenAiTestResult {
  final bool isValid;
  final String message;
  final bool hasGpt35Turbo;
  final bool hasGpt4;
  final bool canCreateCompletions;
  final int totalModels;

  const OpenAiTestResult({
    required this.isValid,
    required this.message,
    this.hasGpt35Turbo = false,
    this.hasGpt4 = false,
    this.canCreateCompletions = false,
    this.totalModels = 0,
  });
}

class JinaTestResult {
  final bool isValid;
  final String message;
  final bool hasApiKey;
  final int? remainingRequests;
  final int? dailyLimit;

  const JinaTestResult({
    required this.isValid,
    required this.message,
    this.hasApiKey = false,
    this.remainingRequests,
    this.dailyLimit,
  });
}
