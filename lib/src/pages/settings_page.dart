import 'package:flutter/cupertino.dart' hide OverlayVisibilityMode;
import 'dart:async';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/common/extensions/theme_extensions.dart';
import 'package:pinboard_wizard/src/common/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _jinaKeyController = TextEditingController();

  bool _validatingOpenAi = false;
  bool? _openAiKeyWorks;
  String? _openAiPermissions;
  bool _validatingJina = false;
  bool? _jinaKeyWorks;
  String? _jinaPermissions;

  late final CredentialsService _credentialsService;
  late final PinboardService _pinboardService;
  late final AiSettingsService _aiSettingsService;

  bool _testing = false;
  String? _error;
  bool? _apiKeyWorks;
  bool _validating = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _credentialsService = locator.get<CredentialsService>();
    _pinboardService = locator.get<PinboardService>();
    _aiSettingsService = locator.get<AiSettingsService>();

    _prefill();
    _apiKeyController.addListener(_onApiKeyChanged);
  }

  Future<void> _prefill() async {
    try {
      final creds = await _credentialsService.getCredentials();
      if (creds != null) {
        _apiKeyController.text = creds.apiKey;
      }

      // Load AI settings
      final aiSettings = _aiSettingsService.settings;
      _openaiKeyController.text = aiSettings.openai.apiKey ?? '';
      _jinaKeyController.text = aiSettings.webScraping.jinaApiKey ?? '';

      // Add listeners for validation
      _openaiKeyController.addListener(_onOpenAiKeyChanged);
      _jinaKeyController.addListener(_onJinaKeyChanged);

      // Automatically validate existing keys
      if (aiSettings.openai.apiKey != null &&
          aiSettings.openai.apiKey!.isNotEmpty) {
        _validateOpenAiKey(aiSettings.openai.apiKey!);
      }

      // Always validate Jina (since empty key is valid for free tier)
      _validateJinaKey(aiSettings.webScraping.jinaApiKey ?? '');
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _apiKeyController.dispose();
    _openaiKeyController.dispose();
    _jinaKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (!_credentialsService.isValidApiKey(apiKey)) {
      setState(() => _error = 'Invalid API key. Expected: username:hexstring');
      return;
    }

    setState(() => _error = null);
    try {
      await _credentialsService.saveCredentials(apiKey);
      setState(() => _testing = true);
      final ok = await _pinboardService.testConnection();
      setState(() {
        _testing = false;
        _error = ok ? null : 'Saved, but connection test failed.';
      });
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    }
  }

  Future<void> _clear() async {
    try {
      await _credentialsService.clearCredentials();
      _apiKeyController.clear();
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = 'Failed to clear: $e');
    }
  }

  void _onApiKeyChanged() {
    final apiKey = _apiKeyController.text.trim();
    _debounce?.cancel();
    if (!_credentialsService.isValidApiKey(apiKey)) {
      setState(() {
        _apiKeyWorks = null;
        _validating = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _validateApiKey(apiKey);
    });
  }

  Future<void> _validateApiKey(String apiKey) async {
    setState(() {
      _validating = true;
      _apiKeyWorks = null;
    });

    try {
      final tempStorage = InMemorySecretsStorage();
      await tempStorage.save(Credentials(apiKey: apiKey));
      final tempService = PinboardService(secretStorage: tempStorage);
      final ok = await tempService.testConnection();
      tempService.dispose();
      if (!mounted) return;
      setState(() {
        _apiKeyWorks = ok;
        _validating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiKeyWorks = false;
        _validating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppLogo.medium(),
                const SizedBox(width: 12),
                Text(
                  'Pinboard Wizard Settings',
                  style: MacosTheme.of(context).typography.largeTitle,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pinboard Settings Section
            _buildPinboardSettingsSection(context),

            const SizedBox(height: 32),

            // AI Assistance Section
            _buildAiSettingsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPinboardSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pinboard Configuration',
          style: MacosTheme.of(context).typography.title1,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Status:'),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: _credentialsService.isAuthenticatedNotifier,
              builder: (context, authed, _) {
                return Row(
                  children: [
                    MacosIcon(
                      authed
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.exclamationmark_triangle,
                      color: authed
                          ? MacosColors.systemGreenColor
                          : MacosColors.systemYellowColor,
                    ),
                    const SizedBox(width: 6),
                    Text(authed ? 'Authenticated' : 'Not authenticated'),
                  ],
                );
              },
            ),
            if (_testing) ...[const SizedBox(width: 8), const ProgressCircle()],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Pinboard API Key'),
            const SizedBox(width: 8),
            MacosIconButton(
              icon: const MacosIcon(CupertinoIcons.link, size: 14),
              onPressed: () =>
                  _launchUrl('https://pinboard.in/settings/password'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ValidatedSecretField(
          controller: _apiKeyController,
          placeholder: 'API Key',
          helperText: 'Format: username:token (e.g. user:1234abcd)',
          isValidating: _validating,
          isValid: _apiKeyWorks,
          onPressed: _apiKeyWorks != null
              ? () => _showPermissionsDialog(
                  'Pinboard API',
                  _apiKeyWorks!
                      ? 'Valid API key - connection successful'
                      : 'Connection failed',
                )
              : null,
        ),
        const SizedBox(height: 4),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(color: MacosColors.systemRedColor),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            PushButton(
              controlSize: ControlSize.large,
              onPressed: _save,
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: _clear,
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiSettingsSection(BuildContext context) {
    return ListenableBuilder(
      listenable: _aiSettingsService,
      builder: (context, _) {
        final settings = _aiSettingsService.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Assistance',
              style: MacosTheme.of(context).typography.title1,
            ),
            const SizedBox(height: 12),

            // Enable AI Toggle
            Row(
              children: [
                MacosSwitch(
                  value: settings.isEnabled,
                  onChanged: (value) async {
                    await _aiSettingsService.setAiEnabled(value);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enable AI bookmark assistance'),
                      const SizedBox(height: 4),
                      Text(
                        'Use AI to automatically generate titles, descriptions, and tags for bookmarks',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.subtitleTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (settings.isEnabled) ...[
              const SizedBox(height: 20),

              // OpenAI Settings
              Row(
                children: [
                  Text(
                    'OpenAI Configuration',
                    style: MacosTheme.of(context).typography.headline,
                  ),
                  const SizedBox(width: 8),
                  MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.link, size: 14),
                    onPressed: () =>
                        _launchUrl('https://platform.openai.com/api-keys'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Status:'),
                  const SizedBox(width: 8),
                  if (_validatingOpenAi) ...[
                    const ProgressCircle(),
                    const SizedBox(width: 6),
                    const Text('Validating...'),
                  ] else if (_openAiKeyWorks != null) ...[
                    MacosIcon(
                      _openAiKeyWorks == true
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.xmark_octagon_fill,
                      color: _openAiKeyWorks == true
                          ? MacosColors.systemGreenColor
                          : MacosColors.systemRedColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _openAiPermissions ?? 'Unknown status',
                        style: TextStyle(
                          color: _openAiKeyWorks == true
                              ? MacosColors.systemGreenColor
                              : MacosColors.systemRedColor,
                        ),
                      ),
                    ),
                  ] else ...[
                    const MacosIcon(
                      CupertinoIcons.minus_circle,
                      color: MacosColors.systemGrayColor,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Not tested',
                      style: TextStyle(color: MacosColors.systemGrayColor),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Required for AI analysis. OpenAI will process website content to generate structured bookmark metadata.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.subtitleTextColor,
                ),
              ),
              const SizedBox(height: 12),
              ValidatedSecretField(
                controller: _openaiKeyController,
                placeholder: 'OpenAI API Key',
                helperText:
                    'Format: sk-... (starts with "sk-" followed by characters)',
                isValidating: _validatingOpenAi,
                isValid: _openAiKeyWorks,
                onPressed: _openAiPermissions != null
                    ? () =>
                          _showPermissionsDialog('OpenAI', _openAiPermissions!)
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  PushButton(
                    controlSize: ControlSize.large,
                    onPressed: _saveOpenAiKey,
                    child: const Text('Save OpenAI Key'),
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.large,
                    secondary: true,
                    onPressed: () async {
                      final apiKey = _openaiKeyController.text.trim();
                      if (apiKey.isNotEmpty) {
                        await _validateOpenAiKey(apiKey);
                      }
                    },
                    child: const Text('Test'),
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.large,
                    secondary: true,
                    onPressed: _clearOpenAiKey,
                    child: const Text('Clear'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // AI Configuration Settings
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description Max Length Slider
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(
                          'Description Max Length: ${settings.openai.descriptionMaxLength}',
                        ),
                      ),
                      Expanded(
                        child: MacosSlider(
                          value: settings.openai.descriptionMaxLength
                              .toDouble(),
                          min: 20,
                          max: 300,
                          onChanged: (value) async {
                            await _aiSettingsService.setDescriptionMaxLength(
                              value.round(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '20-300 characters',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.helperTextColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Max Tags Slider
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text('Max Tags: ${settings.openai.maxTags}'),
                      ),
                      Expanded(
                        child: MacosSlider(
                          value: settings.openai.maxTags.toDouble(),
                          min: 0,
                          max: 10,
                          onChanged: (value) async {
                            await _aiSettingsService.setMaxTags(value.round());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0-10 tags',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.helperTextColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Jina AI Settings
              Row(
                children: [
                  Text(
                    'Jina AI Configuration (Optional)',
                    style: MacosTheme.of(context).typography.headline,
                  ),
                  const SizedBox(width: 8),
                  MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.link, size: 14),
                    onPressed: () => _launchUrl('https://jina.ai/'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Optional web scraping service. Jina AI converts HTML to clean markdown for better AI analysis. Free tier available.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.subtitleTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Status:'),
                  const SizedBox(width: 8),
                  if (_validatingJina) ...[
                    const ProgressCircle(),
                    const SizedBox(width: 6),
                    const Text('Validating...'),
                  ] else if (_jinaKeyWorks != null) ...[
                    MacosIcon(
                      _jinaKeyWorks == true
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.xmark_octagon_fill,
                      color: _jinaKeyWorks == true
                          ? MacosColors.systemGreenColor
                          : MacosColors.systemRedColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _jinaPermissions ?? 'Unknown status',
                        style: TextStyle(
                          color: _jinaKeyWorks == true
                              ? MacosColors.systemGreenColor
                              : MacosColors.systemRedColor,
                        ),
                      ),
                    ),
                  ] else ...[
                    const MacosIcon(
                      CupertinoIcons.minus_circle,
                      color: MacosColors.systemGrayColor,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Not tested',
                      style: TextStyle(color: MacosColors.systemGrayColor),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ValidatedSecretField(
                controller: _jinaKeyController,
                placeholder: 'Jina API Key (Optional)',
                helperText:
                    'Leave empty for free tier, or enter your Jina API key',
                isValidating: _validatingJina,
                isValid: _jinaKeyWorks,
                onPressed: _jinaPermissions != null
                    ? () => _showPermissionsDialog('Jina AI', _jinaPermissions!)
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  PushButton(
                    controlSize: ControlSize.large,
                    onPressed: _saveJinaKey,
                    child: const Text('Save Jina Key'),
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.large,
                    secondary: true,
                    onPressed: () async {
                      final apiKey = _jinaKeyController.text.trim();
                      await _validateJinaKey(apiKey);
                    },
                    child: const Text('Test'),
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.large,
                    secondary: true,
                    onPressed: _clearJinaKey,
                    child: const Text('Clear'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Clear All AI Settings Button
              PushButton(
                controlSize: ControlSize.large,
                secondary: true,
                onPressed: _clearAllAiSettings,
                child: const Text('Clear All AI Settings'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _saveOpenAiKey() async {
    final apiKey = _openaiKeyController.text.trim();
    try {
      await _aiSettingsService.setOpenAiApiKey(apiKey.isEmpty ? null : apiKey);
      if (apiKey.isNotEmpty) {
        await _validateOpenAiKey(apiKey);
      } else {
        setState(() {
          _openAiKeyWorks = null;
          _validatingOpenAi = false;
          _openAiPermissions = null;
        });
      }
    } catch (e) {
      debugPrint('Failed to save OpenAI key: $e');
    }
  }

  Future<void> _clearOpenAiKey() async {
    try {
      await _aiSettingsService.setOpenAiApiKey(null);
      _openaiKeyController.clear();
      setState(() {
        _openAiKeyWorks = null;
        _validatingOpenAi = false;
      });
    } catch (e) {
      debugPrint('Failed to clear OpenAI key: $e');
    }
  }

  Future<void> _saveJinaKey() async {
    final apiKey = _jinaKeyController.text.trim();
    try {
      await _aiSettingsService.setJinaApiKey(apiKey.isEmpty ? null : apiKey);
      // Always validate Jina key since empty is valid (free tier)
      await _validateJinaKey(apiKey.isEmpty ? '' : apiKey);
    } catch (e) {
      // Failed to save Jina key
    }
  }

  Future<void> _clearJinaKey() async {
    try {
      await _aiSettingsService.setJinaApiKey(null);
      _jinaKeyController.clear();
      setState(() {
        _jinaKeyWorks = null;
        _validatingJina = false;
      });
    } catch (e) {
      debugPrint('Failed to clear Jina key: $e');
    }
  }

  Future<void> _clearAllAiSettings() async {
    try {
      await _aiSettingsService.clearAllAiSettings();
      _openaiKeyController.clear();
      _jinaKeyController.clear();
      setState(() {
        _openAiKeyWorks = null;
        _validatingOpenAi = false;
        _openAiPermissions = null;
        _jinaKeyWorks = null;
        _validatingJina = false;
        _jinaPermissions = null;
      });
    } catch (e) {
      debugPrint('Failed to clear AI settings: $e');
    }
  }

  void _onOpenAiKeyChanged() {
    setState(() {
      _openAiKeyWorks = null;
      _validatingOpenAi = false;
      _openAiPermissions = null;
    });
  }

  void _onJinaKeyChanged() {
    setState(() {
      _jinaKeyWorks = null;
      _validatingJina = false;
      _jinaPermissions = null;
    });
  }

  Future<void> _validateOpenAiKey(String apiKey) async {
    setState(() {
      _validatingOpenAi = true;
      _openAiKeyWorks = null;
      _openAiPermissions = null;
    });

    try {
      // Test the connection using the AI settings service
      final result = await _aiSettingsService.testOpenAiConnection(apiKey);

      if (!mounted) return;

      setState(() {
        _openAiKeyWorks = result.isValid;
        _validatingOpenAi = false;
        _openAiPermissions = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openAiKeyWorks = false;
        _validatingOpenAi = false;
        _openAiPermissions = 'Error testing API key: ${e.toString()}';
      });
    }
  }

  Future<void> _validateJinaKey(String apiKey) async {
    setState(() {
      _validatingJina = true;
      _jinaKeyWorks = null;
      _jinaPermissions = null;
    });

    try {
      // Test the connection using the AI settings service
      final result = await _aiSettingsService.testJinaConnection(
        apiKey.isEmpty ? null : apiKey,
      );

      if (!mounted) return;

      setState(() {
        _jinaKeyWorks = result.isValid;
        _validatingJina = false;
        _jinaPermissions = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _jinaKeyWorks = false;
        _validatingJina = false;
        _jinaPermissions = 'Error testing connection: ${e.toString()}';
      });
    }
  }

  void _showPermissionsDialog(String service, String permissions) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: Icon(
          CupertinoIcons.info_circle_fill,
          size: 64,
          color: MacosColors.systemBlueColor,
        ),
        title: Text('$service API Status'),
        message: Text(permissions),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // Handle error - could show a dialog or copy to clipboard as fallback
      debugPrint('Could not launch $url');
    }
  }
}
