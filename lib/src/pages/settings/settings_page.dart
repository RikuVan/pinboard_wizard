import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/common/extensions/theme_extensions.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/common/widgets/validated_secret_field.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/models/models.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_cubit.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_state.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
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
        githubAuthService: locator.get<GitHubAuthService>(),
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
  final TextEditingController _githubOwnerController = TextEditingController();
  final TextEditingController _githubRepoController = TextEditingController();
  final TextEditingController _githubBranchController = TextEditingController();
  final TextEditingController _githubNotesPathController =
      TextEditingController();
  final TextEditingController _githubTokenController = TextEditingController();
  final TextEditingController _githubTokenExpiryController =
      TextEditingController();
  late MacosTabController _tabController;
  Timer? _s3DebounceTimer;
  TokenType _githubTokenType = TokenType.fineGrained;

  @override
  void initState() {
    super.initState();
    _tabController = MacosTabController(length: 4);
    _apiKeyController.addListener(_onApiKeyChanged);
    _openaiKeyController.addListener(_onOpenAiKeyChanged);
    _jinaKeyController.addListener(_onJinaKeyChanged);
  }

  @override
  void dispose() {
    _apiKeyController.removeListener(_onApiKeyChanged);
    _openaiKeyController.removeListener(_onOpenAiKeyChanged);
    _jinaKeyController.removeListener(_onJinaKeyChanged);
    _apiKeyController.dispose();
    _openaiKeyController.dispose();
    _jinaKeyController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3RegionController.dispose();
    _s3BucketNameController.dispose();
    _s3FilePathController.dispose();
    _githubOwnerController.dispose();
    _githubRepoController.dispose();
    _githubBranchController.dispose();
    _githubNotesPathController.dispose();
    _githubTokenController.dispose();
    _githubTokenExpiryController.dispose();
    _tabController.dispose();
    _s3DebounceTimer?.cancel();
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
        // Load S3 configuration only once when settings are loaded
        if (state.status == SettingsStatus.loaded &&
            _s3AccessKeyController.text.isEmpty &&
            _s3SecretKeyController.text.isEmpty &&
            _s3RegionController.text.isEmpty &&
            _s3BucketNameController.text.isEmpty &&
            _s3FilePathController.text.isEmpty) {
          _s3AccessKeyController.text = state.s3Config.accessKey;
          _s3SecretKeyController.text = state.s3Config.secretKey;
          _s3RegionController.text = state.s3Config.region;
          _s3BucketNameController.text = state.s3Config.bucketName;
          _s3FilePathController.text = state.s3Config.filePath;
        }
        // Load GitHub configuration only once when settings are loaded
        if (state.status == SettingsStatus.loaded &&
            _githubOwnerController.text.isEmpty &&
            _githubRepoController.text.isEmpty &&
            state.githubConfig != null) {
          _githubOwnerController.text = state.githubConfig!.owner;
          _githubRepoController.text = state.githubConfig!.repo;
          _githubBranchController.text = state.githubConfig!.branch;
          _githubNotesPathController.text = state.githubConfig!.notesPath;
          _githubTokenController.text = state.githubToken;
          _githubTokenType = state.githubConfig!.tokenType;
          if (state.githubConfig!.tokenExpiry != null) {
            _githubTokenExpiryController.text = state.githubConfig!.tokenExpiry!
                .toIso8601String()
                .split('T')[0];
          }
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
                    MacosTab(label: 'GitHub Notes'),
                  ],
                  children: [
                    _buildPinboardTab(context, state),
                    _buildAiTab(context, state),
                    _buildBackupTab(context, state),
                    _buildGitHubTab(context, state),
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
                  ? MacosColors.systemBlueColor.withValues(alpha: 0.1)
                  : state.isBackupValid
                  ? MacosColors.systemGreenColor.withValues(alpha: 0.1)
                  : state.isBackupInvalid
                  ? MacosColors.systemRedColor.withValues(alpha: 0.1)
                  : MacosColors.systemGrayColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: state.isBackupValidating
                    ? MacosColors.systemBlueColor.withValues(alpha: 0.3)
                    : state.isBackupValid
                    ? MacosColors.systemGreenColor.withValues(alpha: 0.3)
                    : state.isBackupInvalid
                    ? MacosColors.systemRedColor.withValues(alpha: 0.3)
                    : MacosColors.systemGrayColor.withValues(alpha: 0.2),
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
                onPressed: _canValidateS3Config() && !state.isBackupValidating
                    ? () => _validateS3Config()
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
                onPressed: () => _clearS3Config(),
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Validation tests your S3 credentials by uploading a small test file to verify access and permissions.',
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
                color: MacosColors.systemGreenColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MacosColors.systemGreenColor.withValues(alpha: 0.3),
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
                onPressed:
                    _canValidateS3Config() &&
                        state.isBackupValid &&
                        !state.isBackupInProgress
                    ? () => _performBackup()
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

  Widget _buildGitHubTab(BuildContext context, SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GitHub Notes Configuration',
            style: MacosTheme.of(context).typography.title1,
          ),
          const SizedBox(height: 12),

          // Status indicator
          Row(
            children: [
              const Text('Status:'),
              const SizedBox(width: 8),
              Row(
                children: [
                  MacosIcon(
                    state.isGitHubAuthenticated
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.exclamationmark_triangle,
                    color: state.isGitHubAuthenticated
                        ? MacosColors.systemGreenColor
                        : MacosColors.systemGrayColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.isGitHubAuthenticated
                        ? 'Configured'
                        : 'Not configured',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Token expiry warning banner
          if (state.tokenExpiryWarning != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    state.tokenExpiryWarning!.severity == WarningSeverity.high
                    ? MacosColors.systemRedColor.withValues(alpha: 0.1)
                    : MacosColors.systemOrangeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      state.tokenExpiryWarning!.severity == WarningSeverity.high
                      ? MacosColors.systemRedColor
                      : MacosColors.systemOrangeColor,
                ),
              ),
              child: Row(
                children: [
                  MacosIcon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color:
                        state.tokenExpiryWarning!.severity ==
                            WarningSeverity.high
                        ? MacosColors.systemRedColor
                        : MacosColors.systemOrangeColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.tokenExpiryWarning!.message)),
                  PushButton(
                    controlSize: ControlSize.small,
                    onPressed: () => context
                        .read<SettingsCubit>()
                        .dismissGitHubTokenWarning(),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Repository Configuration
          Text(
            'Repository Settings',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),

          Text(
            'GitHub Owner/Organization',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _githubOwnerController,
            placeholder: 'username or org-name',
          ),
          const SizedBox(height: 12),

          Text(
            'Repository Name',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _githubRepoController,
            placeholder: 'personal-notes',
          ),
          const SizedBox(height: 12),

          Text(
            'Branch (Optional)',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _githubBranchController,
            placeholder: 'main',
          ),
          const SizedBox(height: 12),

          Text(
            'Notes Path (Optional)',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _githubNotesPathController,
            placeholder: 'notes/',
          ),
          const SizedBox(height: 24),

          // Token Configuration
          Row(
            children: [
              Text(
                'Personal Access Token',
                style: MacosTheme.of(context).typography.headline,
              ),
              const SizedBox(width: 8),
              MacosIconButton(
                icon: const MacosIcon(CupertinoIcons.link, size: 14),
                onPressed: () =>
                    _launchUrl('https://github.com/settings/tokens?type=beta'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Token Type Selection
          Row(
            children: [
              const Text('Token Type:'),
              const SizedBox(width: 12),
              MacosRadioButton<TokenType>(
                value: TokenType.fineGrained,
                groupValue: _githubTokenType,
                onChanged: (value) {
                  setState(() {
                    _githubTokenType = value!;
                  });
                },
              ),
              const SizedBox(width: 4),
              const Text('Fine-Grained (Recommended)'),
              const SizedBox(width: 16),
              MacosRadioButton<TokenType>(
                value: TokenType.classic,
                groupValue: _githubTokenType,
                onChanged: (value) {
                  setState(() {
                    _githubTokenType = value!;
                  });
                },
              ),
              const SizedBox(width: 4),
              const Text('Classic'),
            ],
          ),
          const SizedBox(height: 12),

          ValidatedSecretField(
            controller: _githubTokenController,
            placeholder: 'ghp_xxxxxxxxxxxxxxxxxxxx',
            helperText:
                'Generate a GitHub Personal Access Token with Contents: Read/Write permissions',
            isValidating: false,
            isValid: null,
          ),
          const SizedBox(height: 12),

          // Token Expiry Date
          Text(
            'Token Expiry Date (Optional)',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 4),
          MacosTextField(
            controller: _githubTokenExpiryController,
            placeholder: 'YYYY-MM-DD',
          ),
          Text(
            'Enter the expiration date of your token for monitoring',
            style: TextStyle(fontSize: 11, color: context.helperTextColor),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              PushButton(
                controlSize: ControlSize.large,
                onPressed: () async {
                  final owner = _githubOwnerController.text.trim();
                  final repo = _githubRepoController.text.trim();
                  final token = _githubTokenController.text.trim();
                  final branch = _githubBranchController.text.trim().isEmpty
                      ? 'main'
                      : _githubBranchController.text.trim();
                  final notesPath =
                      _githubNotesPathController.text.trim().isEmpty
                      ? 'notes/'
                      : _githubNotesPathController.text.trim();

                  DateTime? tokenExpiry;
                  if (_githubTokenExpiryController.text.trim().isNotEmpty) {
                    try {
                      tokenExpiry = DateTime.parse(
                        _githubTokenExpiryController.text.trim(),
                      );
                    } catch (e) {
                      // Invalid date format - ignore
                    }
                  }

                  await context.read<SettingsCubit>().saveGitHubConfig(
                    owner: owner,
                    repo: repo,
                    token: token,
                    branch: branch,
                    notesPath: notesPath,
                    tokenType: _githubTokenType,
                    tokenExpiry: tokenExpiry,
                  );
                },
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              PushButton(
                controlSize: ControlSize.large,
                secondary: true,
                onPressed: () async {
                  await context.read<SettingsCubit>().clearGitHubConfig();
                  _githubOwnerController.clear();
                  _githubRepoController.clear();
                  _githubBranchController.clear();
                  _githubNotesPathController.clear();
                  _githubTokenController.clear();
                  _githubTokenExpiryController.clear();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Validation message
          if (state.githubValidationMessage != null) ...[
            Text(
              state.githubValidationMessage!,
              style: TextStyle(
                color: state.isGitHubValid
                    ? MacosColors.systemGreenColor
                    : state.isGitHubInvalid
                    ? MacosColors.systemRedColor
                    : MacosColors.systemGrayColor,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Help Section
          Container(height: 1, color: MacosColors.separatorColor),
          const SizedBox(height: 16),
          Text(
            'Setup Instructions',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),
          Text(
            '1. Create a private repository on GitHub for your notes\n'
            '2. Generate a Fine-Grained Personal Access Token:\n'
            '   • Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens\n'
            '   • Repository access: Only select your notes repository\n'
            '   • Permissions: Contents (Read and write), Metadata (Read-only)\n'
            '   • Expiration: 180 days recommended\n'
            '3. Enter the repository details and token above\n'
            '4. Click Save to configure',
            style: TextStyle(fontSize: 12, color: context.subtitleTextColor),
          ),
        ],
      ),
    );
  }

  bool _canValidateS3Config() {
    final accessKey = _s3AccessKeyController.text.trim();
    final secretKey = _s3SecretKeyController.text.trim();
    final region = _s3RegionController.text.trim();
    final bucketName = _s3BucketNameController.text.trim();

    return accessKey.isNotEmpty &&
        secretKey.isNotEmpty &&
        region.isNotEmpty &&
        bucketName.isNotEmpty;
  }

  void _validateS3Config() {
    final s3Config = S3Config(
      accessKey: _s3AccessKeyController.text.trim(),
      secretKey: _s3SecretKeyController.text.trim(),
      region: _s3RegionController.text.trim(),
      bucketName: _s3BucketNameController.text.trim(),
      filePath: _s3FilePathController.text.trim(),
    );

    context.read<SettingsCubit>().validateS3ConfigWithValues(s3Config);
  }

  void _clearS3Config() {
    _s3AccessKeyController.clear();
    _s3SecretKeyController.clear();
    _s3RegionController.clear();
    _s3BucketNameController.clear();
    _s3FilePathController.clear();
    context.read<SettingsCubit>().clearBackupConfig();
  }

  void _performBackup() {
    final s3Config = S3Config(
      accessKey: _s3AccessKeyController.text.trim(),
      secretKey: _s3SecretKeyController.text.trim(),
      region: _s3RegionController.text.trim(),
      bucketName: _s3BucketNameController.text.trim(),
      filePath: _s3FilePathController.text.trim(),
    );

    context.read<SettingsCubit>().performBackupWithConfig(s3Config);
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
