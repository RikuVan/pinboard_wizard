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
import 'package:pinboard_wizard/src/backup/backup_service.dart';
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
        backupService: locator.get<BackupService>(),
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
  final TextEditingController _s3AccessKeyController = TextEditingController();
  final TextEditingController _s3SecretKeyController = TextEditingController();
  final TextEditingController _s3RegionController = TextEditingController();
  final TextEditingController _s3BucketNameController = TextEditingController();
  final TextEditingController _s3FilePathController = TextEditingController();
  late MacosTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = MacosTabController(length: 3);
    _apiKeyController.addListener(_onApiKeyChanged);
    _openaiKeyController.addListener(_onOpenAiKeyChanged);
    _jinaKeyController.addListener(_onJinaKeyChanged);
    _s3AccessKeyController.addListener(_onS3AccessKeyChanged);
    _s3SecretKeyController.addListener(_onS3SecretKeyChanged);
    _s3RegionController.addListener(_onS3RegionChanged);
    _s3BucketNameController.addListener(_onS3BucketNameChanged);
    _s3FilePathController.addListener(_onS3FilePathChanged);
  }

  @override
  void dispose() {
    _apiKeyController.removeListener(_onApiKeyChanged);
    _openaiKeyController.removeListener(_onOpenAiKeyChanged);
    _jinaKeyController.removeListener(_onJinaKeyChanged);
    _s3AccessKeyController.removeListener(_onS3AccessKeyChanged);
    _s3SecretKeyController.removeListener(_onS3SecretKeyChanged);
    _s3RegionController.removeListener(_onS3RegionChanged);
    _s3BucketNameController.removeListener(_onS3BucketNameChanged);
    _s3FilePathController.removeListener(_onS3FilePathChanged);
    _apiKeyController.dispose();
    _openaiKeyController.dispose();
    _jinaKeyController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3RegionController.dispose();
    _s3BucketNameController.dispose();
    _s3FilePathController.dispose();
    _tabController.dispose();
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

  void _onS3AccessKeyChanged() {
    context.read<SettingsCubit>().updateS3Config(
      accessKey: _s3AccessKeyController.text,
    );
  }

  void _onS3SecretKeyChanged() {
    context.read<SettingsCubit>().updateS3Config(
      secretKey: _s3SecretKeyController.text,
    );
  }

  void _onS3RegionChanged() {
    context.read<SettingsCubit>().updateS3Config(
      region: _s3RegionController.text,
    );
  }

  void _onS3BucketNameChanged() {
    context.read<SettingsCubit>().updateS3Config(
      bucketName: _s3BucketNameController.text,
    );
  }

  void _onS3FilePathChanged() {
    context.read<SettingsCubit>().updateS3Config(
      filePath: _s3FilePathController.text,
    );
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
        // Update S3 controllers
        if (_s3AccessKeyController.text != state.s3Config.accessKey) {
          _s3AccessKeyController.removeListener(_onS3AccessKeyChanged);
          _s3AccessKeyController.text = state.s3Config.accessKey;
          _s3AccessKeyController.addListener(_onS3AccessKeyChanged);
        }
        if (_s3SecretKeyController.text != state.s3Config.secretKey) {
          _s3SecretKeyController.removeListener(_onS3SecretKeyChanged);
          _s3SecretKeyController.text = state.s3Config.secretKey;
          _s3SecretKeyController.addListener(_onS3SecretKeyChanged);
        }
        if (_s3RegionController.text != state.s3Config.region) {
          _s3RegionController.removeListener(_onS3RegionChanged);
          _s3RegionController.text = state.s3Config.region;
          _s3RegionController.addListener(_onS3RegionChanged);
        }
        if (_s3BucketNameController.text != state.s3Config.bucketName) {
          _s3BucketNameController.removeListener(_onS3BucketNameChanged);
          _s3BucketNameController.text = state.s3Config.bucketName;
          _s3BucketNameController.addListener(_onS3BucketNameChanged);
        }
        if (_s3FilePathController.text != state.s3Config.filePath) {
          _s3FilePathController.removeListener(_onS3FilePathChanged);
          _s3FilePathController.text = state.s3Config.filePath;
          _s3FilePathController.addListener(_onS3FilePathChanged);
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
                    MacosTab(label: 'Backups'),
                  ],
                  children: [
                    _buildPinboardTab(context, state),
                    _buildAiTab(context, state),
                    _buildBackupTab(context, state),
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

  Widget _buildBackupTab(BuildContext context, SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup Configuration',
            style: MacosTheme.of(context).typography.title1,
          ),
          const SizedBox(height: 12),
          Text(
            'Securely backup your bookmarks to Amazon S3. All credentials are encrypted and stored locally.',
            style: TextStyle(fontSize: 12, color: context.subtitleTextColor),
          ),
          const SizedBox(height: 24),

          // S3 Configuration Section
          Row(
            children: [
              Text(
                'Amazon S3 Settings',
                style: MacosTheme.of(context).typography.headline,
              ),
              const SizedBox(width: 8),
              MacosIconButton(
                icon: const MacosIcon(CupertinoIcons.link, size: 14),
                onPressed: () => _launchUrl(
                  'https://docs.aws.amazon.com/s3/latest/userguide/setting-up-s3.html',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll need an AWS account with an S3 bucket and IAM credentials with S3 write permissions.',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
          const SizedBox(height: 16),

          // Access Key
          Text('Access Key', style: MacosTheme.of(context).typography.body),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _s3AccessKeyController,
            placeholder: 'Enter your AWS Access Key ID',
          ),
          const SizedBox(height: 4),
          Text(
            'Your AWS IAM user access key (e.g., AKIAIOSFODNN7EXAMPLE)',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
          const SizedBox(height: 16),

          // Secret Key
          Text('Secret Key', style: MacosTheme.of(context).typography.body),
          const SizedBox(height: 4),
          ValidatedSecretField(
            controller: _s3SecretKeyController,
            placeholder: 'Enter your AWS Secret Access Key',
            helperText:
                'Your AWS IAM user secret key (kept secure and encrypted)',
            isValidating: false,
            isValid: null,
          ),
          const SizedBox(height: 16),

          // Region
          Text('Region', style: MacosTheme.of(context).typography.body),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _s3RegionController,
            placeholder: 'us-east-1',
          ),
          const SizedBox(height: 4),
          Text(
            'AWS region where your S3 bucket is located (e.g., us-east-1, eu-west-1)',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
          const SizedBox(height: 16),

          // Bucket Name
          Text('Bucket Name', style: MacosTheme.of(context).typography.body),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _s3BucketNameController,
            placeholder: 'my-pinboard-backups',
          ),
          const SizedBox(height: 4),
          Text(
            'Name of your S3 bucket where backups will be stored',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
          const SizedBox(height: 16),

          // File Path (optional)
          Text(
            'File Path (Optional)',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _s3FilePathController,
            placeholder: 'backups/pinboard',
          ),
          const SizedBox(height: 4),
          Text(
            'Optional folder path within your bucket. Leave empty to store in root.',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
          const SizedBox(height: 16),

          // Validation Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: state.isBackupValidating
                  ? MacosColors.systemBlueColor.withOpacity(0.1)
                  : state.isBackupValid
                  ? MacosColors.systemGreenColor.withOpacity(0.1)
                  : state.isBackupInvalid
                  ? MacosColors.systemRedColor.withOpacity(0.1)
                  : MacosColors.systemGrayColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: state.isBackupValidating
                    ? MacosColors.systemBlueColor.withOpacity(0.3)
                    : state.isBackupValid
                    ? MacosColors.systemGreenColor.withOpacity(0.3)
                    : state.isBackupInvalid
                    ? MacosColors.systemRedColor.withOpacity(0.3)
                    : MacosColors.systemGrayColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                if (state.isBackupValidating) ...[
                  const ProgressCircle(),
                  const SizedBox(width: 8),
                  const Text('Testing connection to S3...'),
                ] else if (state.isBackupValid) ...[
                  const MacosIcon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: MacosColors.systemGreenColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✓ Configuration Valid',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (state.backupValidationMessage != null)
                          Text(
                            state.backupValidationMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.subtitleTextColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else if (state.isBackupInvalid) ...[
                  const MacosIcon(
                    CupertinoIcons.xmark_circle_fill,
                    color: MacosColors.systemRedColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✗ Configuration Invalid',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          state.backupValidationMessage ??
                              'Please check your S3 credentials and try again.',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.subtitleTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const MacosIcon(
                    CupertinoIcons.info_circle,
                    color: MacosColors.systemGrayColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ready to Validate',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Fill in all required fields and click "Validate Config" to test your S3 connection.',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.subtitleTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              PushButton(
                controlSize: ControlSize.large,
                onPressed: state.s3Config.isValid && !state.isBackupValidating
                    ? () => context.read<SettingsCubit>().validateS3Config()
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isBackupValidating) ...[
                      const ProgressCircle(),
                      const SizedBox(width: 8),
                    ] else if (state.isBackupValid)
                      const MacosIcon(CupertinoIcons.checkmark, size: 16),
                    if (state.isBackupValid) const SizedBox(width: 4),
                    Text(
                      state.isBackupValidating
                          ? 'Testing...'
                          : 'Validate Config',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PushButton(
                controlSize: ControlSize.large,
                secondary: true,
                onPressed: () =>
                    context.read<SettingsCubit>().clearBackupConfig(),
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Validation tests your S3 credentials by uploading a small test file.',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),

          const SizedBox(height: 32),
          Container(height: 1, color: MacosColors.separatorColor),
          const SizedBox(height: 32),

          // Backup Section
          Text(
            'Backup Operations',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a JSON backup of all your bookmarks including titles, descriptions, tags, and metadata.',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
          const SizedBox(height: 16),

          if (state.lastBackupMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MacosColors.systemGreenColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MacosColors.systemGreenColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MacosIcon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: MacosColors.systemGreenColor,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Backup Successful',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.lastBackupMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.subtitleTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              PushButton(
                controlSize: ControlSize.large,
                onPressed: state.canBackup
                    ? () => context.read<SettingsCubit>().performBackup()
                    : null,
                child: state.isBackupInProgress
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProgressCircle(),
                          SizedBox(width: 8),
                          Text('Creating backup...'),
                        ],
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MacosIcon(CupertinoIcons.cloud_upload, size: 16),
                          SizedBox(width: 6),
                          Text('Backup Bookmarks'),
                        ],
                      ),
              ),
              if (!state.canBackup && !state.isBackupInProgress) ...[
                const SizedBox(width: 8),
                Text(
                  state.isBackupValid
                      ? 'Ready to backup'
                      : 'Please validate configuration first',
                  style: TextStyle(
                    fontSize: 12,
                    color: state.isBackupValid
                        ? MacosColors.systemGreenColor
                        : MacosColors.systemOrangeColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This will export all your bookmarks as a timestamped JSON file and upload it to your S3 bucket. The backup includes bookmark metadata and is compressed for efficiency.',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
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
