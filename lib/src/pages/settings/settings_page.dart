import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/common/widgets/validated_secret_field.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
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
        appSecureStorage: locator.get<AppSecureStorage>(),
        envImportService: locator.get<EnvImportService>(),
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
  late AppTabController _tabController;
  Timer? _s3DebounceTimer;
  TokenType _githubTokenType = TokenType.fineGrained;

  @override
  void initState() {
    super.initState();
    _tabController = AppTabController(length: 5);
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
                    style: context.appTypography.largeTitle,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tab View
              Expanded(
                child: AppTabView(
                  controller: _tabController,
                  tabs: const [
                    AppTab(label: 'Pinboard'),
                    AppTab(label: 'AI Settings'),
                    AppTab(label: 'Backups'),
                    AppTab(label: 'GitHub Notes'),
                    AppTab(label: 'Sync'),
                  ],
                  children: [
                    _buildPinboardTab(context, state),
                    _buildAiTab(context, state),
                    _buildBackupTab(context, state),
                    _buildGitHubTab(context, state),
                    _buildSyncTab(context, state),
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
          Text('Pinboard Configuration', style: context.appTypography.title1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Status:'),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(
                    state.isPinboardAuthenticated
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.exclamationmark_triangle,
                    color: state.isPinboardAuthenticated
                        ? AppColors.systemGreen
                        : AppColors.systemYellow,
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
                const AppProgress(),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Pinboard API Key'),
              const SizedBox(width: 8),
              AppIconButton(
                icon: const Icon(CupertinoIcons.link, size: 14),
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
              style: const TextStyle(color: AppColors.systemRed),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppButton(
                size: AppButtonSize.large,
                onPressed: () =>
                    context.read<SettingsCubit>().savePinboardApiKey(),
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              AppButton(
                size: AppButtonSize.large,
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
          Text('AI Assistance', style: context.appTypography.title1),
          const SizedBox(height: 12),

          // Enable AI Toggle
          Row(
            children: [
              AppSwitch(
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
                  style: context.appTypography.headline,
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  icon: const Icon(CupertinoIcons.link, size: 14),
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
                  const AppProgress(),
                  const SizedBox(width: 6),
                  const Text('Validating...'),
                ] else if (state.openAiValidationStatus !=
                    ValidationStatus.initial) ...[
                  Icon(
                    state.isOpenAiValid
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.xmark_octagon_fill,
                    color: state.isOpenAiValid
                        ? AppColors.systemGreen
                        : AppColors.systemRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.openAiValidationMessage ?? 'Unknown status',
                      style: TextStyle(
                        color: state.isOpenAiValid
                            ? AppColors.systemGreen
                            : AppColors.systemRed,
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(
                    CupertinoIcons.minus_circle,
                    color: AppColors.systemGrey,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Not tested',
                    style: TextStyle(color: AppColors.systemGrey),
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
                AppButton(
                  size: AppButtonSize.large,
                  onPressed: () =>
                      context.read<SettingsCubit>().saveOpenAiKey(),
                  child: const Text('Save OpenAI Key'),
                ),
                const SizedBox(width: 8),
                AppButton(
                  size: AppButtonSize.large,
                  secondary: true,
                  onPressed: () =>
                      context.read<SettingsCubit>().testOpenAiConnection(),
                  child: const Text('Test'),
                ),
                const SizedBox(width: 8),
                AppButton(
                  size: AppButtonSize.large,
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
                      child: AppSlider(
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
                      child: AppSlider(
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
                  style: context.appTypography.headline,
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  icon: const Icon(CupertinoIcons.link, size: 14),
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
                  const AppProgress(),
                  const SizedBox(width: 6),
                  const Text('Validating...'),
                ] else if (state.jinaValidationStatus !=
                    ValidationStatus.initial) ...[
                  Icon(
                    state.isJinaValid
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.xmark_octagon_fill,
                    color: state.isJinaValid
                        ? AppColors.systemGreen
                        : AppColors.systemRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.jinaValidationMessage ?? 'Unknown status',
                      style: TextStyle(
                        color: state.isJinaValid
                            ? AppColors.systemGreen
                            : AppColors.systemRed,
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(
                    CupertinoIcons.minus_circle,
                    color: AppColors.systemGrey,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Not tested',
                    style: TextStyle(color: AppColors.systemGrey),
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
                AppButton(
                  size: AppButtonSize.large,
                  onPressed: () => context.read<SettingsCubit>().saveJinaKey(),
                  child: const Text('Save Jina Key'),
                ),
                const SizedBox(width: 8),
                AppButton(
                  size: AppButtonSize.large,
                  secondary: true,
                  onPressed: () =>
                      context.read<SettingsCubit>().testJinaConnection(),
                  child: const Text('Test'),
                ),
                const SizedBox(width: 8),
                AppButton(
                  size: AppButtonSize.large,
                  secondary: true,
                  onPressed: () => context.read<SettingsCubit>().clearJinaKey(),
                  child: const Text('Clear'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Clear All AI Settings Button
            AppButton(
              size: AppButtonSize.large,
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
          Text('Backup Configuration', style: context.appTypography.title1),
          const SizedBox(height: 12),
          Text(
            'Securely backup your bookmarks to Amazon S3. All credentials are encrypted and stored locally.',
            style: TextStyle(fontSize: 12, color: context.subtitleTextColor),
          ),
          const SizedBox(height: 24),

          // S3 Configuration Section
          Row(
            children: [
              Text('Amazon S3 Settings', style: context.appTypography.headline),
              const SizedBox(width: 8),
              AppIconButton(
                icon: const Icon(CupertinoIcons.link, size: 14),
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
          Text('Access Key', style: context.appTypography.body),
          const SizedBox(height: 4),
          AppTextField(
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
          Text('Secret Key', style: context.appTypography.body),
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
          Text('Region', style: context.appTypography.body),
          const SizedBox(height: 4),
          AppTextField(
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
          Text('Bucket Name', style: context.appTypography.body),
          const SizedBox(height: 4),
          AppTextField(
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
          Text('File Path (Optional)', style: context.appTypography.body),
          const SizedBox(height: 4),
          AppTextField(
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
                  ? AppColors.systemBlue.withValues(alpha: 0.1)
                  : state.isBackupValid
                  ? AppColors.systemGreen.withValues(alpha: 0.1)
                  : state.isBackupInvalid
                  ? AppColors.systemRed.withValues(alpha: 0.1)
                  : AppColors.systemGrey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: state.isBackupValidating
                    ? AppColors.systemBlue.withValues(alpha: 0.3)
                    : state.isBackupValid
                    ? AppColors.systemGreen.withValues(alpha: 0.3)
                    : state.isBackupInvalid
                    ? AppColors.systemRed.withValues(alpha: 0.3)
                    : AppColors.systemGrey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                if (state.isBackupValidating) ...[
                  const AppProgress(),
                  const SizedBox(width: 8),
                  const Text('Testing connection to S3...'),
                ] else if (state.isBackupValid) ...[
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: AppColors.systemGreen,
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
                  const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: AppColors.systemRed,
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
                  const Icon(
                    CupertinoIcons.info_circle,
                    color: AppColors.systemGrey,
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
              AppButton(
                size: AppButtonSize.large,
                onPressed: _canValidateS3Config() && !state.isBackupValidating
                    ? () => _validateS3Config()
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isBackupValidating) ...[
                      const AppProgress(),
                      const SizedBox(width: 8),
                    ] else if (state.isBackupValid)
                      const Icon(CupertinoIcons.checkmark, size: 16),
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
              AppButton(
                size: AppButtonSize.large,
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
          Container(height: 1, color: AppColors.separator),
          const SizedBox(height: 32),

          // Backup Section
          Text('Backup Operations', style: context.appTypography.headline),
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
                color: AppColors.systemGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.systemGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: AppColors.systemGreen,
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
              AppButton(
                size: AppButtonSize.large,
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
                          AppProgress(),
                          SizedBox(width: 8),
                          Text('Creating backup...'),
                        ],
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.cloud_upload, size: 16),
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
                        ? AppColors.systemGreen
                        : AppColors.systemOrange,
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
            style: context.appTypography.title1,
          ),
          const SizedBox(height: 12),

          // Status indicator
          Row(
            children: [
              const Text('Status:'),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(
                    state.isGitHubAuthenticated
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.exclamationmark_triangle,
                    color: state.isGitHubAuthenticated
                        ? AppColors.systemGreen
                        : AppColors.systemGrey,
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
                    ? AppColors.systemRed.withValues(alpha: 0.1)
                    : AppColors.systemOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      state.tokenExpiryWarning!.severity == WarningSeverity.high
                      ? AppColors.systemRed
                      : AppColors.systemOrange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color:
                        state.tokenExpiryWarning!.severity ==
                            WarningSeverity.high
                        ? AppColors.systemRed
                        : AppColors.systemOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.tokenExpiryWarning!.message)),
                  AppButton(
                    size: AppButtonSize.small,
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
          Text('Repository Settings', style: context.appTypography.headline),
          const SizedBox(height: 8),

          Text('GitHub Owner/Organization', style: context.appTypography.body),
          const SizedBox(height: 4),
          AppTextField(
            controller: _githubOwnerController,
            placeholder: 'username or org-name',
          ),
          const SizedBox(height: 12),

          Text('Repository Name', style: context.appTypography.body),
          const SizedBox(height: 4),
          AppTextField(
            controller: _githubRepoController,
            placeholder: 'personal-notes',
          ),
          const SizedBox(height: 12),

          Text('Branch (Optional)', style: context.appTypography.body),
          const SizedBox(height: 4),
          AppTextField(
            controller: _githubBranchController,
            placeholder: 'main',
          ),
          const SizedBox(height: 12),

          Text('Notes Path (Optional)', style: context.appTypography.body),
          const SizedBox(height: 8),
          AppTextField(
            controller: _githubNotesPathController,
            placeholder: 'Leave empty for root level, or enter: notes/',
          ),
          const SizedBox(height: 4),
          Text(
            'Default: root level (empty). Use "notes/" for subdirectory, or "documents/" for custom path.',
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 24),

          // Token Configuration
          Row(
            children: [
              Text(
                'Personal Access Token',
                style: context.appTypography.headline,
              ),
              const SizedBox(width: 8),
              AppIconButton(
                icon: const Icon(CupertinoIcons.link, size: 14),
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
              AppRadio<TokenType>(
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
              AppRadio<TokenType>(
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
            style: context.appTypography.body,
          ),
          const SizedBox(height: 4),
          AppTextField(
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
              AppButton(
                size: AppButtonSize.large,
                onPressed: () async {
                  final owner = _githubOwnerController.text.trim();
                  final repo = _githubRepoController.text.trim();
                  final token = _githubTokenController.text.trim();
                  final branch = _githubBranchController.text.trim().isEmpty
                      ? 'main'
                      : _githubBranchController.text.trim();
                  final notesPath = _githubNotesPathController.text.trim();

                  // Capture context and cubit before any async operations
                  final dialogContext = context;
                  final settingsCubit = context.read<SettingsCubit>();

                  DateTime? tokenExpiry;
                  if (_githubTokenExpiryController.text.trim().isNotEmpty) {
                    try {
                      tokenExpiry = DateTime.parse(
                        _githubTokenExpiryController.text.trim(),
                      );
                    } catch (e) {
                      // Show error for invalid date format
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      final navigator = Navigator.of(dialogContext);
                      // ignore: use_build_context_synchronously
                      await showAppAlertDialog(
                        context: dialogContext,
                        builder: (builderContext) => AppAlertDialog(
                          appIcon: const FlutterLogo(size: 56),
                          title: const Text('Invalid Date Format'),
                          message: Text(
                            'Token expiry date must be in YYYY-MM-DD format.\n\n'
                            'Example: 2025-12-31\n\n'
                            'Error: ${e.toString()}',
                          ),
                          primaryButton: AppButton(
                            size: AppButtonSize.large,
                            onPressed: () => navigator.pop(),
                            child: const Text('OK'),
                          ),
                        ),
                      );
                      return;
                    }
                  }

                  await settingsCubit.saveGitHubConfig(
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
              AppButton(
                size: AppButtonSize.large,
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
                    ? AppColors.systemGreen
                    : state.isGitHubInvalid
                    ? AppColors.systemRed
                    : AppColors.systemGrey,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Help Section
          Container(height: 1, color: AppColors.separator),
          const SizedBox(height: 16),
          Text('Setup Instructions', style: context.appTypography.headline),
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
    showAppAlertDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        appIcon: const Icon(
          CupertinoIcons.info_circle_fill,
          size: 64,
          color: AppColors.systemBlue,
        ),
        title: Text('$service API Status'),
        message: Text(permissions),
        primaryButton: AppButton(
          size: AppButtonSize.large,
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

  Widget _buildSyncTab(BuildContext context, SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('iCloud Sync', style: context.appTypography.headline),
          const SizedBox(height: 8),
          Text(
            'Sync your Pinboard, AI, backup, and GitHub credentials across '
            'your Macs using iCloud Keychain. Requires iCloud Keychain to be '
            'enabled in System Settings, and must be switched on separately '
            'on each Mac.',
            style: context.appTypography.body,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppSwitch(
                value: state.secretsSyncEnabled,
                onChanged: (value) => _onSyncToggleChanged(context, value),
              ),
              const SizedBox(width: 8),
              Text(
                'Sync credentials across devices',
                style: context.appTypography.body,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: AppColors.separator),
          const SizedBox(height: 16),
          Text('Import from .env', style: context.appTypography.headline),
          const SizedBox(height: 8),
          Text(
            'Import credentials from a .env file instead of entering them '
            'manually. Values in the file replace existing ones; anything '
            'not in the file is left unchanged. The file is read once — you '
            'can delete it afterwards.',
            style: context.appTypography.body,
          ),
          const SizedBox(height: 12),
          AppButton(
            size: AppButtonSize.large,
            onPressed: () => _importEnvFile(context),
            child: const Text('Import from .env…'),
          ),
          if (state.envImportMessage != null) ...[
            const SizedBox(height: 12),
            Text(state.envImportMessage!, style: context.appTypography.body),
          ],
        ],
      ),
    );
  }

  Future<void> _onSyncToggleChanged(BuildContext context, bool value) async {
    final cubit = context.read<SettingsCubit>();
    if (!value) {
      await cubit.setSecretsSyncEnabled(false);
      return;
    }
    final confirmed = await showAppAlertDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Enable iCloud sync?'),
        message: const Text(
          'Your credentials will sync across Macs signed into the same '
          'iCloud account. Where a synced value already exists, it replaces '
          'this Mac\'s value.',
        ),
        primaryButton: AppButton(
          size: AppButtonSize.large,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Enable'),
        ),
        secondaryButton: AppButton(
          size: AppButtonSize.large,
          secondary: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed == true) {
      await cubit.setSecretsSyncEnabled(true);
    }
  }

  String _maskSecret(String value) {
    if (value.length <= 12) return '••••';
    return '${value.substring(0, 4)}…${value.substring(value.length - 4)}';
  }

  Future<void> _importEnvFile(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final file = await openFile(
      acceptedTypeGroups: const [XTypeGroup(label: 'env files')],
    );
    if (file == null) return;

    final String contents;
    try {
      contents = await file.readAsString();
    } catch (e) {
      if (!mounted) return;
      await showAppAlertDialog<void>(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('Could not read file'),
          message: Text('$e'),
          primaryButton: AppButton(
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ),
      );
      return;
    }

    final preview = cubit.previewEnvImport(contents);
    if (!mounted) return;

    if (preview.isEmpty) {
      await showAppAlertDialog<void>(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('Nothing to import'),
          message: Text(
            'No recognized variables found.'
            '${preview.unrecognized.isNotEmpty ? ' Unrecognized: ${preview.unrecognized.join(', ')}.' : ''}',
          ),
          primaryButton: AppButton(
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ),
      );
      return;
    }

    final lines = preview.recognized.entries
        .map((e) => '${e.key} = ${_maskSecret(e.value)}')
        .join('\n');
    final extra = <String>[
      if (preview.unrecognized.isNotEmpty)
        '${preview.unrecognized.length} unrecognized variable(s) ignored.',
      if (preview.ignoredLines > 0)
        '${preview.ignoredLines} unparseable line(s) ignored.',
    ].join(' ');

    final confirmed = await showAppAlertDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Import credentials?'),
        message: Text(
          'The following values will be imported and will REPLACE any '
          'existing values:\n\n$lines${extra.isNotEmpty ? '\n\n$extra' : ''}',
        ),
        primaryButton: AppButton(
          size: AppButtonSize.large,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Import'),
        ),
        secondaryButton: AppButton(
          size: AppButtonSize.large,
          secondary: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (confirmed == true) {
      await cubit.importEnvVariables(preview.recognized);
    }
  }
}
