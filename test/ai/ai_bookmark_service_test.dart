import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:pinboard_wizard/src/ai/ai_bookmark_service.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/ai/openai/models/bookmark_suggestions.dart';
import 'package:pinboard_wizard/src/ai/openai/openai_service.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/jina_service.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/models/scraped_content.dart';
import 'package:pinboard_wizard/src/ai/ai_settings.dart';
import 'package:get_it/get_it.dart';

import 'ai_bookmark_service_test.mocks.dart';

@GenerateMocks([AiSettingsService, OpenAiService, JinaService])
void main() {
  late AiBookmarkService aiBookmarkService;
  late MockAiSettingsService mockAiSettingsService;
  late MockOpenAiService mockOpenAiService;
  late MockJinaService mockJinaService;

  setUp(() {
    // Reset GetIt
    if (GetIt.instance.isRegistered<AiSettingsService>()) {
      GetIt.instance.unregister<AiSettingsService>();
    }
    if (GetIt.instance.isRegistered<OpenAiService>()) {
      GetIt.instance.unregister<OpenAiService>();
    }
    if (GetIt.instance.isRegistered<JinaService>()) {
      GetIt.instance.unregister<JinaService>();
    }

    // Create mocks
    mockAiSettingsService = MockAiSettingsService();
    mockOpenAiService = MockOpenAiService();
    mockJinaService = MockJinaService();

    // Register mocks with GetIt
    GetIt.instance.registerSingleton<AiSettingsService>(mockAiSettingsService);
    GetIt.instance.registerSingleton<OpenAiService>(mockOpenAiService);
    GetIt.instance.registerSingleton<JinaService>(mockJinaService);

    // Create service under test
    aiBookmarkService = AiBookmarkService();
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  group('AiBookmarkService', () {
    group('canUseAi', () {
      test('returns true when AI settings service allows AI usage', () {
        when(mockAiSettingsService.canUseAi).thenReturn(true);

        expect(aiBookmarkService.canUseAi, isTrue);
      });

      test(
        'returns false when AI settings service does not allow AI usage',
        () {
          when(mockAiSettingsService.canUseAi).thenReturn(false);

          expect(aiBookmarkService.canUseAi, isFalse);
        },
      );
    });

    group('isEnabled', () {
      test('returns enabled state from settings service', () {
        when(mockAiSettingsService.isEnabled).thenReturn(true);

        expect(aiBookmarkService.isEnabled, isTrue);

        when(mockAiSettingsService.isEnabled).thenReturn(false);

        expect(aiBookmarkService.isEnabled, isFalse);
      });
    });

    group('isValidUrl', () {
      test('returns true for valid HTTP URLs', () {
        expect(aiBookmarkService.isValidUrl('https://example.com'), isTrue);
        expect(aiBookmarkService.isValidUrl('http://test.org'), isTrue);
        expect(
          aiBookmarkService.isValidUrl('https://subdomain.example.com/path'),
          isTrue,
        );
      });

      test('returns false for invalid URLs', () {
        expect(aiBookmarkService.isValidUrl('not-a-url'), isFalse);
        expect(aiBookmarkService.isValidUrl('ftp://example.com'), isFalse);
        expect(aiBookmarkService.isValidUrl(''), isFalse);
        expect(aiBookmarkService.isValidUrl('example.com'), isFalse);
      });
    });

    group('analyzeUrl', () {
      const testUrl = 'https://example.com';
      final testScrapedContent = ScrapedContent(
        url: testUrl,
        title: 'Example Site',
        content: 'This is example content from the website.',
        description: 'An example website for testing',
        images: [],
        metadata: {},
        scrapedAt: DateTime.now(),
        source: ScrapingSource.jina,
      );

      final testSuggestions = BookmarkSuggestions(
        title: 'Example Site',
        description: 'An example website for testing',
        tags: ['example', 'test'],
        confidence: 0.8,
        generatedAt: DateTime.now(),
        sourceUrl: testUrl,
      );

      setUp(() {
        // Setup default mocks for successful flow
        when(mockAiSettingsService.canUseAi).thenReturn(true);
        when(
          mockAiSettingsService.webScrapingSettings,
        ).thenReturn(const WebScrapingSettings(jinaApiKey: 'test-jina-key'));
        when(mockAiSettingsService.openaiSettings).thenReturn(
          const OpenAiSettings(
            apiKey: 'test-openai-key',
            descriptionMaxLength: 80,
            maxTags: 3,
          ),
        );
      });

      test('successfully analyzes URL when AI is enabled', () async {
        when(
          mockJinaService.scrapeUrl(testUrl),
        ).thenAnswer((_) async => testScrapedContent);

        when(
          mockOpenAiService.analyzeContent(
            url: testUrl,
            content: testScrapedContent,
            maxDescriptionLength: 80,
            maxTags: 3,
          ),
        ).thenAnswer((_) async => testSuggestions);

        final result = await aiBookmarkService.analyzeUrl(testUrl);

        expect(result, equals(testSuggestions));

        verify(mockJinaService.initialize('test-jina-key')).called(1);
        verify(mockOpenAiService.initialize('test-openai-key')).called(1);
        verify(mockJinaService.scrapeUrl(testUrl)).called(1);
        verify(
          mockOpenAiService.analyzeContent(
            url: testUrl,
            content: testScrapedContent,
            maxDescriptionLength: 80,
            maxTags: 3,
          ),
        ).called(1);
      });

      test('throws exception when AI is not enabled', () async {
        when(mockAiSettingsService.canUseAi).thenReturn(false);

        expect(
          () => aiBookmarkService.analyzeUrl(testUrl),
          throwsA(isA<AiBookmarkException>()),
        );
      });

      test('throws exception when Jina scraping fails', () async {
        when(
          mockJinaService.scrapeUrl(testUrl),
        ).thenThrow(Exception('Scraping failed'));

        expect(
          () => aiBookmarkService.analyzeUrl(testUrl),
          throwsA(isA<AiBookmarkException>()),
        );
      });

      test('throws exception when OpenAI analysis fails', () async {
        when(
          mockJinaService.scrapeUrl(testUrl),
        ).thenAnswer((_) async => testScrapedContent);

        when(
          mockOpenAiService.analyzeContent(
            url: anyNamed('url'),
            content: anyNamed('content'),
            maxDescriptionLength: anyNamed('maxDescriptionLength'),
            maxTags: anyNamed('maxTags'),
          ),
        ).thenThrow(Exception('OpenAI analysis failed'));

        expect(
          () => aiBookmarkService.analyzeUrl(testUrl),
          throwsA(isA<AiBookmarkException>()),
        );
      });

      test('throws exception when OpenAI API key is missing', () async {
        when(
          mockAiSettingsService.openaiSettings,
        ).thenReturn(const OpenAiSettings(apiKey: null));

        expect(
          () => aiBookmarkService.analyzeUrl(testUrl),
          throwsA(isA<AiBookmarkException>()),
        );
      });

      test('uses empty Jina API key when not provided', () async {
        when(
          mockAiSettingsService.webScrapingSettings,
        ).thenReturn(const WebScrapingSettings(jinaApiKey: ''));

        when(
          mockJinaService.scrapeUrl(testUrl),
        ).thenAnswer((_) async => testScrapedContent);

        when(
          mockOpenAiService.analyzeContent(
            url: testUrl,
            content: testScrapedContent,
            maxDescriptionLength: 80,
            maxTags: 3,
          ),
        ).thenAnswer((_) async => testSuggestions);

        await aiBookmarkService.analyzeUrl(testUrl);

        verify(mockJinaService.initialize(null)).called(1);
      });
    });

    group('testConnection', () {
      test('returns failure when AI is disabled', () async {
        when(mockAiSettingsService.isEnabled).thenReturn(false);

        final result = await aiBookmarkService.testConnection();

        expect(result.isWorking, isFalse);
        expect(result.message, contains('disabled'));
      });

      test('returns failure when OpenAI API key is missing', () async {
        when(mockAiSettingsService.isEnabled).thenReturn(true);
        when(
          mockAiSettingsService.openaiSettings,
        ).thenReturn(const OpenAiSettings(apiKey: null));

        final result = await aiBookmarkService.testConnection();

        expect(result.isWorking, isFalse);
        expect(result.message, contains('OpenAI API key not configured'));
      });

      test('returns failure when OpenAI connection fails', () async {
        when(mockAiSettingsService.isEnabled).thenReturn(true);
        when(
          mockAiSettingsService.openaiSettings,
        ).thenReturn(const OpenAiSettings(apiKey: 'test-key'));
        when(mockOpenAiService.testConnection()).thenAnswer((_) async => false);

        final result = await aiBookmarkService.testConnection();

        expect(result.isWorking, isFalse);
        expect(result.message, contains('OpenAI connection failed'));
      });

      test('returns failure when Jina connection fails', () async {
        when(mockAiSettingsService.isEnabled).thenReturn(true);
        when(
          mockAiSettingsService.openaiSettings,
        ).thenReturn(const OpenAiSettings(apiKey: 'test-key'));
        when(
          mockAiSettingsService.webScrapingSettings,
        ).thenReturn(const WebScrapingSettings(jinaApiKey: 'test-jina-key'));
        when(mockOpenAiService.testConnection()).thenAnswer((_) async => true);
        when(mockJinaService.testConnection()).thenAnswer((_) async => false);

        final result = await aiBookmarkService.testConnection();

        expect(result.isWorking, isFalse);
        expect(
          result.message,
          contains('Jina web scraping service connection failed'),
        );
      });

      test('returns success when all connections work', () async {
        when(mockAiSettingsService.isEnabled).thenReturn(true);
        when(
          mockAiSettingsService.openaiSettings,
        ).thenReturn(const OpenAiSettings(apiKey: 'test-key'));
        when(
          mockAiSettingsService.webScrapingSettings,
        ).thenReturn(const WebScrapingSettings(jinaApiKey: 'test-jina-key'));
        when(mockOpenAiService.testConnection()).thenAnswer((_) async => true);
        when(mockJinaService.testConnection()).thenAnswer((_) async => true);

        final result = await aiBookmarkService.testConnection();

        expect(result.isWorking, isTrue);
        expect(result.message, contains('working properly'));
      });
    });
  });
}
