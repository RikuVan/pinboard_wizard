import 'dart:async';
import 'package:flutter/cupertino.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_cubit.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_state.dart';
import 'package:pinboard_wizard/src/common/widgets/validated_secret_field.dart';
import 'package:pinboard_wizard/src/common/extensions/theme_extensions.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        credentialsService: locator.get<CredentialsService>(),
        pinboardService: locator.get<PinboardService>(),
        aiSettingsService: locator.get<AiSettingsService>(),
      )..loadSettings(),
      child: const _SettingsPageView(),
    );
  }
}

class _SettingsPageView extends StatefulWidget {
  const _SettingsPageView();

  @override
  State<_SettingsPageView> createState() => _SettingsPageViewState();
}

class _SettingsPageViewState extends State<_SettingsPageView> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _jinaKeyController = TextEditingController();
  late MacosTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = MacosTabController(length: 2);
    _apiKeyController.addListener(_onApiKeyChanged);
    _openaiKeyController.addListener(_onOpenAiKeyChanged);
    _jinaKeyController.addListener(_onJinaKeyChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiKeyController.removeListener(_onApiKeyChanged);
    _openaiKeyController.removeListener(_onOpenAiKeyChanged);
    _jinaKeyController.removeListener(_onJinaKeyChanged);
    _apiKeyController.dispose();
    _openaiKeyController.dispose();
    _jinaKeyController.dispose();
    super.dispose();
  }

  void _onApiKeyChanged() {
    context.read<SettingsCubit>().updatePinboardApiKey(_apiKeyController.text);
  }

  void _onOpenAiKeyChanged() {
    context.read<SettingsCubit>().updateOpenAiApiKey(_openaiKeyController.text);
  }

  void _onJinaKeyChanged() {
    context.read<SettingsCubit>().updateJinaApiKey(_jinaKeyController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        // Update text controllers when state changes (without triggering listeners)
        if (_apiKeyController.text != state.pinboardApiKey) {
          _apiKeyController.removeListener(_onApiKeyChanged);
          _apiKeyController.text = state.pinboardApiKey;
          _apiKeyController.addListener(_onApiKeyChanged);
        }
        if (_openaiKeyController.text != state.openAiApiKey) {
          _openaiKeyController.removeListener(_onOpenAiKeyChanged);
          _openaiKeyController.text = state.openAiApiKey;
          _openaiKeyController.addListener(_onOpenAiKeyChanged);
        }
        if (_jinaKeyController.text != state.jinaApiKey) {
          _jinaKeyController.removeListener(_onJinaKeyChanged);
          _jinaKeyController.text = state.jinaApiKey;
          _jinaKeyController.addListener(_onJinaKeyChanged);
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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

              // Tab View
              Expanded(
                child: MacosTabView(
                  controller: _tabController,
                  tabs: const [
                    MacosTab(label: 'Pinboard'),
                    MacosTab(label: 'AI Settings'),
                  ],
                  children: [
                    _buildPinboardTab(context, state),
                    _buildAiTab(context, state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPinboardTab(BuildContext context, SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
              Row(
                children: [
                  MacosIcon(
                    state.isPinboardAuthenticated
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.exclamationmark_triangle,
                    color: state.isPinboardAuthenticated
                        ? MacosColors.systemGreenColor
                        : MacosColors.systemYellowColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.isPinboardAuthenticated
                        ? 'Authenticated'
                        : 'Not authenticated',
                  ),
                ],
              ),
              if (state.isPinboardTesting) ...[
                const SizedBox(width: 8),
                const ProgressCircle(),
              ],
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
            isValidating: state.isPinboardValidating,
            isValid: state.isPinboardValid
                ? true
                : (state.isPinboardInvalid ? false : null),
            onPressed: state.pinboardValidationMessage != null
                ? () => _showPermissionsDialog(
                    'Pinboard API',
                    state.pinboardValidationMessage!,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          if (state.errorMessage != null)
            Text(
              state.errorMessage!,
              style: const TextStyle(color: MacosColors.systemRedColor),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              PushButton(
                controlSize: ControlSize.large,
                onPressed: () =>
                    context.read<SettingsCubit>().savePinboardApiKey(),
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: () =>
                    context.read<SettingsCubit>().clearPinboardApiKey(),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiTab(BuildContext context, SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
                value: state.isAiEnabled,
                onChanged: (value) =>
                    context.read<SettingsCubit>().setAiEnabled(value),
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

          if (state.isAiEnabled) ...[
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
                if (state.isOpenAiValidating) ...[
                  const ProgressCircle(),
                  const SizedBox(width: 6),
                  const Text('Validating...'),
                ] else if (state.openAiValidationStatus !=
                    ValidationStatus.initial) ...[
                  MacosIcon(
                    state.isOpenAiValid
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.xmark_octagon_fill,
                    color: state.isOpenAiValid
                        ? MacosColors.systemGreenColor
                        : MacosColors.systemRedColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.openAiValidationMessage ?? 'Unknown status',
                      style: TextStyle(
                        color: state.isOpenAiValid
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
              style: TextStyle(fontSize: 12, color: context.subtitleTextColor),
            ),
            const SizedBox(height: 12),
            ValidatedSecretField(
              controller: _openaiKeyController,
              placeholder: 'OpenAI API Key',
              helperText:
                  'Format: sk-... (starts with "sk-" followed by characters)',
              isValidating: state.isOpenAiValidating,
              isValid: state.isOpenAiValid
                  ? true
                  : (state.isOpenAiInvalid ? false : null),
              onPressed: state.openAiValidationMessage != null
                  ? () => _showPermissionsDialog(
                      'OpenAI',
                      state.openAiValidationMessage!,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () =>
                      context.read<SettingsCubit>().saveOpenAiKey(),
                  child: const Text('Save OpenAI Key'),
                ),
                const SizedBox(width: 8),
                PushButton(
                  controlSize: ControlSize.large,
                  secondary: true,
                  onPressed: () =>
                      context.read<SettingsCubit>().testOpenAiConnection(),
                  child: const Text('Test'),
                ),
                const SizedBox(width: 8),
                PushButton(
                  controlSize: ControlSize.large,
                  secondary: true,
                  onPressed: () =>
                      context.read<SettingsCubit>().clearOpenAiKey(),
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
                        'Description Max Length: ${state.descriptionMaxLength}',
                      ),
                    ),
                    Expanded(
                      child: MacosSlider(
                        value: state.descriptionMaxLength.toDouble(),
                        min: 20,
                        max: 300,
                        onChanged: (value) => context
                            .read<SettingsCubit>()
                            .setDescriptionMaxLength(value.round()),
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
                      child: Text('Max Tags: ${state.maxTags}'),
                    ),
                    Expanded(
                      child: MacosSlider(
                        value: state.maxTags.toDouble(),
                        min: 0,
                        max: 10,
                        onChanged: (value) => context
                            .read<SettingsCubit>()
                            .setMaxTags(value.round()),
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
              style: TextStyle(fontSize: 12, color: context.subtitleTextColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Status:'),
                const SizedBox(width: 8),
                if (state.isJinaValidating) ...[
                  const ProgressCircle(),
                  const SizedBox(width: 6),
                  const Text('Validating...'),
                ] else if (state.jinaValidationStatus !=
                    ValidationStatus.initial) ...[
                  MacosIcon(
                    state.isJinaValid
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.xmark_octagon_fill,
                    color: state.isJinaValid
                        ? MacosColors.systemGreenColor
                        : MacosColors.systemRedColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.jinaValidationMessage ?? 'Unknown status',
                      style: TextStyle(
                        color: state.isJinaValid
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
              isValidating: state.isJinaValidating,
              isValid: state.isJinaValid
                  ? true
                  : (state.isJinaInvalid ? false : null),
              onPressed: state.jinaValidationMessage != null
                  ? () => _showPermissionsDialog(
                      'Jina AI',
                      state.jinaValidationMessage!,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () => context.read<SettingsCubit>().saveJinaKey(),
                  child: const Text('Save Jina Key'),
                ),
                const SizedBox(width: 8),
                PushButton(
                  controlSize: ControlSize.large,
                  secondary: true,
                  onPressed: () =>
                      context.read<SettingsCubit>().testJinaConnection(),
                  child: const Text('Test'),
                ),
                const SizedBox(width: 8),
                PushButton(
                  controlSize: ControlSize.large,
                  secondary: true,
                  onPressed: () => context.read<SettingsCubit>().clearJinaKey(),
                  child: const Text('Clear'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Clear All AI Settings Button
            PushButton(
              controlSize: ControlSize.large,
              secondary: true,
              onPressed: () =>
                  context.read<SettingsCubit>().clearAllAiSettings(),
              child: const Text('Clear All AI Settings'),
            ),
          ],
        ],
      ),
    );
  }

  void _showPermissionsDialog(String service, String permissions) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const Icon(
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
