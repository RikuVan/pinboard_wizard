import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/ai/ai_bookmark_service.dart';
import 'package:pinboard_wizard/src/ai/ai_settings.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/add_bookmark_dialog.dart';

import 'add_bookmark_dialog_test.mocks.dart';

@GenerateMocks(
  [AiBookmarkService, AiSettingsService],
  customMocks: [MockSpec<OpenAiSettings>(as: #MockCustomOpenAiSettings)],
)
void main() {
  late MockAiBookmarkService mockAiBookmarkService;
  late MockAiSettingsService mockAiSettingsService;
  late MockCustomOpenAiSettings mockOpenAiSettings;

  setUp(() {
    GetIt.instance.reset();

    mockAiBookmarkService = MockAiBookmarkService();
    mockAiSettingsService = MockAiSettingsService();
    mockOpenAiSettings = MockCustomOpenAiSettings();

    GetIt.instance.registerSingleton<AiBookmarkService>(mockAiBookmarkService);
    GetIt.instance.registerSingleton<AiSettingsService>(mockAiSettingsService);

    when(mockAiSettingsService.openaiSettings).thenReturn(mockOpenAiSettings);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Widget createTestWidget() {
    return MacosApp(
      home: MacosWindow(
        child: Builder(builder: (context) => AddBookmarkDialog()),
      ),
    );
  }

  testWidgets(
    'AI completion button is enabled when valid URL is loaded from clipboard',
    (WidgetTester tester) async {
      when(mockAiSettingsService.isEnabled).thenReturn(true);
      when(mockOpenAiSettings.hasApiKey).thenReturn(true);
      when(mockAiBookmarkService.isValidUrl(any)).thenReturn(true);

      const testUrl = 'https://example.com';
      const clipboardData = ClipboardData(text: testUrl);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.getData') {
              return {'text': testUrl};
            }
            return null;
          });

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final aiButton = find.byWidgetPredicate(
        (widget) =>
            widget is PushButton &&
            widget.child is Row &&
            (widget.child as Row).children.any(
              (child) => child is Text && child.data == 'Complete with AI',
            ),
      );

      expect(aiButton, findsOneWidget);

      final pushButton = tester.widget<PushButton>(aiButton);
      expect(pushButton.onPressed, isNotNull);

      verify(mockAiBookmarkService.isValidUrl(testUrl)).called(greaterThan(0));
    },
  );

  testWidgets(
    'AI completion button is disabled when AI settings are disabled',
    (WidgetTester tester) async {
      when(mockAiSettingsService.isEnabled).thenReturn(false);
      when(mockOpenAiSettings.hasApiKey).thenReturn(true);
      when(mockAiBookmarkService.isValidUrl(any)).thenReturn(true);

      const testUrl = 'https://example.com';
      const clipboardData = ClipboardData(text: testUrl);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.getData') {
              return {'text': testUrl};
            }
            return null;
          });

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final aiButton = find.byWidgetPredicate(
        (widget) =>
            widget is PushButton &&
            widget.child is Row &&
            (widget.child as Row).children.any(
              (child) => child is Text && child.data == 'Complete with AI',
            ),
      );

      expect(aiButton, findsNothing);
    },
  );

  testWidgets('AI completion button is disabled when no API key is set', (
    WidgetTester tester,
  ) async {
    when(mockAiSettingsService.isEnabled).thenReturn(true);
    when(mockOpenAiSettings.hasApiKey).thenReturn(false);
    when(mockAiBookmarkService.isValidUrl(any)).thenReturn(true);

    const testUrl = 'https://example.com';
    const clipboardData = ClipboardData(text: testUrl);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': testUrl};
          }
          return null;
        });

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    final aiButton = find.byWidgetPredicate(
      (widget) =>
          widget is PushButton &&
          widget.child is Row &&
          (widget.child as Row).children.any(
            (child) => child is Text && child.data == 'Complete with AI',
          ),
    );

    expect(aiButton, findsOneWidget);

    final pushButton = tester.widget<PushButton>(aiButton);
    expect(pushButton.onPressed, isNull);
  });

  testWidgets('AI completion button is disabled when URL is invalid', (
    WidgetTester tester,
  ) async {
    when(mockAiSettingsService.isEnabled).thenReturn(true);
    when(mockOpenAiSettings.hasApiKey).thenReturn(true);
    when(mockAiBookmarkService.isValidUrl(any)).thenReturn(false);

    const testUrl = 'not-a-valid-url';
    const clipboardData = ClipboardData(text: testUrl);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': testUrl};
          }
          return null;
        });

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    final aiButton = find.byWidgetPredicate(
      (widget) =>
          widget is PushButton &&
          widget.child is Row &&
          (widget.child as Row).children.any(
            (child) => child is Text && child.data == 'Complete with AI',
          ),
    );

    expect(aiButton, findsOneWidget);

    final pushButton = tester.widget<PushButton>(aiButton);
    expect(pushButton.onPressed, isNull);
  });

  testWidgets('AI completion button becomes enabled after typing valid URL', (
    WidgetTester tester,
  ) async {
    when(mockAiSettingsService.isEnabled).thenReturn(true);
    when(mockOpenAiSettings.hasApiKey).thenReturn(true);
    when(mockAiBookmarkService.isValidUrl(any)).thenReturn(true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return null;
          }
          return null;
        });

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    final aiButton = find.byWidgetPredicate(
      (widget) =>
          widget is PushButton &&
          widget.child is Row &&
          (widget.child as Row).children.any(
            (child) => child is Text && child.data == 'Complete with AI',
          ),
    );

    expect(aiButton, findsOneWidget);

    PushButton pushButton = tester.widget<PushButton>(aiButton);
    expect(pushButton.onPressed, isNull);

    final urlField = find.byType(MacosTextField).first;
    await tester.enterText(urlField, 'https://example.com');
    await tester.pump();

    pushButton = tester.widget<PushButton>(aiButton);
    expect(pushButton.onPressed, isNotNull);
  });
}
