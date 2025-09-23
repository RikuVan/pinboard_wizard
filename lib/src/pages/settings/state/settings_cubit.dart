import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/common/extensions/cubit_extensions.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_state.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required CredentialsService credentialsService,
    required PinboardService pinboardService,
    required AiSettingsService aiSettingsService,
    required BackupService backupService,
  }) : _credentialsService = credentialsService,
       _pinboardService = pinboardService,
       _aiSettingsService = aiSettingsService,
       _backupService = backupService,
       super(const SettingsState()) {
    // Listen to authentication changes
    _credentialsService.isAuthenticatedNotifier.addListener(_onAuthChanged);
    // Listen to AI settings changes
    _aiSettingsService.addListener(_onAiSettingsChanged);
    // Listen to backup service changes
    _backupService.addListener(_onBackupServiceChanged);
  }

  final CredentialsService _credentialsService;
  final PinboardService _pinboardService;
  final AiSettingsService _aiSettingsService;
  final BackupService _backupService;
  Timer? _debounceTimer;

  /// Initialize and load current settings
  Future<void> loadSettings() async {
    safeEmit(state.copyWith(status: SettingsStatus.loading));

    try {
      // Load Pinboard credentials
      final credentials = await _credentialsService.getCredentials();
      final pinboardApiKey = credentials?.apiKey ?? '';
      final isPinboardAuthenticated =
          _credentialsService.isAuthenticatedNotifier.value;

      // Load AI settings
      final aiSettings = _aiSettingsService.settings;

      // Load backup settings
      await _backupService.loadConfiguration();
      final s3Config = _backupService.s3Config;

      safeEmit(
        state.copyWith(
          status: SettingsStatus.loaded,
          pinboardApiKey: pinboardApiKey,
          isPinboardAuthenticated: isPinboardAuthenticated,
          isAiEnabled: aiSettings.isEnabled,
          openAiApiKey: aiSettings.openai.apiKey ?? '',
          jinaApiKey: aiSettings.webScraping.jinaApiKey ?? '',
          descriptionMaxLength: aiSettings.openai.descriptionMaxLength,
          s3Config: s3Config,
          backupValidationStatus: s3Config.isValid
              ? ValidationStatus.valid
              : ValidationStatus.initial,
          maxTags: aiSettings.openai.maxTags,
        ),
      );

      // Validate existing keys if present
      if (aiSettings.openai.apiKey?.isNotEmpty == true) {
        _validateOpenAiKey(aiSettings.openai.apiKey!);
      }
      // Always validate Jina (empty key is valid for free tier)
      _validateJinaKey(aiSettings.webScraping.jinaApiKey ?? '');
    } catch (e) {
      safeEmit(
        state.copyWith(
          status: SettingsStatus.error,
          errorMessage: 'Failed to load settings: $e',
        ),
      );
    }
  }

  /// Update Pinboard API key
  void updatePinboardApiKey(String apiKey) {
    safeEmit(
      state.copyWith(
        pinboardApiKey: apiKey,
        pinboardValidationStatus: ValidationStatus.initial,
        pinboardValidationMessage: null,
      ),
    );
  }

  /// Save Pinboard API key
  Future<void> savePinboardApiKey() async {
    final apiKey = state.pinboardApiKey.trim();
    if (!_credentialsService.isValidApiKey(apiKey)) {
      safeEmit(
        state.copyWith(
          errorMessage: 'Invalid API key. Expected: username:hexstring',
        ),
      );
      return;
    }

    safeEmit(state.copyWith(status: SettingsStatus.saving, errorMessage: null));

    try {
      await _credentialsService.saveCredentials(apiKey);

      // Test the connection and update validation status
      safeEmit(state.copyWith(isPinboardTesting: true));
      final connectionOk = await _pinboardService.testConnection();

      safeEmit(
        state.copyWith(
          status: SettingsStatus.loaded,
          isPinboardTesting: false,
          pinboardValidationStatus: connectionOk
              ? ValidationStatus.valid
              : ValidationStatus.invalid,
          pinboardValidationMessage: connectionOk
              ? 'Valid API key - connection successful'
              : 'Connection failed',
          errorMessage: connectionOk
              ? null
              : 'Saved, but connection test failed.',
        ),
      );
    } catch (e) {
      safeEmit(
        state.copyWith(
          status: SettingsStatus.error,
          isPinboardTesting: false,
          errorMessage: 'Failed to save: $e',
        ),
      );
    }
  }

  /// Clear Pinboard API key
  Future<void> clearPinboardApiKey() async {
    try {
      await _credentialsService.clearCredentials();
      safeEmit(
        state.copyWith(
          pinboardApiKey: '',
          pinboardValidationStatus: ValidationStatus.initial,
          pinboardValidationMessage: null,
          errorMessage: null,
        ),
      );
    } catch (e) {
      safeEmit(state.copyWith(errorMessage: 'Failed to clear: $e'));
    }
  }

  /// Toggle AI enabled state
  Future<void> setAiEnabled(bool enabled) async {
    try {
      await _aiSettingsService.setAiEnabled(enabled);
      safeEmit(state.copyWith(isAiEnabled: enabled));
    } catch (e) {
      safeEmit(
        state.copyWith(errorMessage: 'Failed to update AI settings: $e'),
      );
    }
  }

  /// Update OpenAI API key
  void updateOpenAiApiKey(String apiKey) {
    safeEmit(
      state.copyWith(
        openAiApiKey: apiKey,
        openAiValidationStatus: ValidationStatus.initial,
        openAiValidationMessage: null,
      ),
    );
  }

  /// Save OpenAI API key
  Future<void> saveOpenAiKey() async {
    final apiKey = state.openAiApiKey.trim();
    try {
      await _aiSettingsService.setOpenAiApiKey(apiKey.isEmpty ? null : apiKey);
      if (apiKey.isNotEmpty) {
        await _validateOpenAiKey(apiKey);
      } else {
        safeEmit(
          state.copyWith(
            openAiValidationStatus: ValidationStatus.initial,
            openAiValidationMessage: null,
          ),
        );
      }
    } catch (e) {
      safeEmit(state.copyWith(errorMessage: 'Failed to save OpenAI key: $e'));
    }
  }

  /// Clear OpenAI API key
  Future<void> clearOpenAiKey() async {
    try {
      await _aiSettingsService.setOpenAiApiKey(null);
      safeEmit(
        state.copyWith(
          openAiApiKey: '',
          openAiValidationStatus: ValidationStatus.initial,
          openAiValidationMessage: null,
        ),
      );
    } catch (e) {
      safeEmit(state.copyWith(errorMessage: 'Failed to clear OpenAI key: $e'));
    }
  }

  /// Test OpenAI connection
  Future<void> testOpenAiConnection() async {
    final apiKey = state.openAiApiKey.trim();
    if (apiKey.isNotEmpty) {
      await _validateOpenAiKey(apiKey);
    }
  }

  /// Update Jina API key
  void updateJinaApiKey(String apiKey) {
    safeEmit(
      state.copyWith(
        jinaApiKey: apiKey,
        jinaValidationStatus: ValidationStatus.initial,
        jinaValidationMessage: null,
      ),
    );
  }

  /// Save Jina API key
  Future<void> saveJinaKey() async {
    final apiKey = state.jinaApiKey.trim();
    try {
      await _aiSettingsService.setJinaApiKey(apiKey.isEmpty ? null : apiKey);
      // Always validate Jina key since empty is valid (free tier)
      await _validateJinaKey(apiKey);
    } catch (e) {
      safeEmit(state.copyWith(errorMessage: 'Failed to save Jina key: $e'));
    }
  }

  /// Clear Jina API key
  Future<void> clearJinaKey() async {
    try {
      await _aiSettingsService.setJinaApiKey(null);
      safeEmit(
        state.copyWith(
          jinaApiKey: '',
          jinaValidationStatus: ValidationStatus.initial,
          jinaValidationMessage: null,
        ),
      );
    } catch (e) {
      safeEmit(state.copyWith(errorMessage: 'Failed to clear Jina key: $e'));
    }
  }

  /// Test Jina connection
  Future<void> testJinaConnection() async {
    final apiKey = state.jinaApiKey.trim();
    await _validateJinaKey(apiKey);
  }

  /// Clear all AI settings
  Future<void> clearAllAiSettings() async {
    try {
      await _aiSettingsService.clearAllAiSettings();
      safeEmit(
        state.copyWith(
          openAiApiKey: '',
          openAiValidationStatus: ValidationStatus.initial,
          openAiValidationMessage: null,
          jinaApiKey: '',
          jinaValidationStatus: ValidationStatus.initial,
          jinaValidationMessage: null,
        ),
      );
    } catch (e) {
      safeEmit(state.copyWith(errorMessage: 'Failed to clear AI settings: $e'));
    }
  }

  /// Set description max length
  Future<void> setDescriptionMaxLength(int length) async {
    try {
      await _aiSettingsService.setDescriptionMaxLength(length);
      safeEmit(state.copyWith(descriptionMaxLength: length));
    } catch (e) {
      safeEmit(
        state.copyWith(
          errorMessage: 'Failed to update description max length: $e',
        ),
      );
    }
  }

  /// Set max tags
  Future<void> setMaxTags(int maxTags) async {
    try {
      await _aiSettingsService.setMaxTags(maxTags);
      safeEmit(state.copyWith(maxTags: maxTags));
    } catch (e) {
      safeEmit(state.copyWith(errorMessage: 'Failed to update max tags: $e'));
    }
  }

  /// Clear error message
  void clearError() {
    safeEmit(state.copyWith(errorMessage: null));
  }

  /// Private method to validate OpenAI API key
  Future<void> _validateOpenAiKey(String apiKey) async {
    safeEmit(
      state.copyWith(
        openAiValidationStatus: ValidationStatus.validating,
        openAiValidationMessage: null,
      ),
    );

    try {
      final result = await _aiSettingsService.testOpenAiConnection(apiKey);

      if (!isClosed) {
        safeEmit(
          state.copyWith(
            openAiValidationStatus: result.isValid
                ? ValidationStatus.valid
                : ValidationStatus.invalid,
            openAiValidationMessage: result.message,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        safeEmit(
          state.copyWith(
            openAiValidationStatus: ValidationStatus.invalid,
            openAiValidationMessage: 'Error testing API key: $e',
          ),
        );
      }
    }
  }

  /// Private method to validate Jina API key
  Future<void> _validateJinaKey(String apiKey) async {
    safeEmit(
      state.copyWith(
        jinaValidationStatus: ValidationStatus.validating,
        jinaValidationMessage: null,
      ),
    );

    try {
      final result = await _aiSettingsService.testJinaConnection(
        apiKey.isEmpty ? null : apiKey,
      );

      if (!isClosed) {
        safeEmit(
          state.copyWith(
            jinaValidationStatus: result.isValid
                ? ValidationStatus.valid
                : ValidationStatus.invalid,
            jinaValidationMessage: result.message,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        safeEmit(
          state.copyWith(
            jinaValidationStatus: ValidationStatus.invalid,
            jinaValidationMessage: 'Error testing connection: $e',
          ),
        );
      }
    }
  }

  /// Listen to authentication changes from CredentialsService
  void _onAuthChanged() {
    safeEmit(
      state.copyWith(
        isPinboardAuthenticated:
            _credentialsService.isAuthenticatedNotifier.value,
      ),
    );
  }

  /// Listen to AI settings changes from AiSettingsService
  void _onAiSettingsChanged() {
    final aiSettings = _aiSettingsService.settings;
    safeEmit(
      state.copyWith(
        isAiEnabled: aiSettings.isEnabled,
        descriptionMaxLength: aiSettings.openai.descriptionMaxLength,
        maxTags: aiSettings.openai.maxTags,
      ),
    );
  }

  /// Listen to backup service changes
  void _onBackupServiceChanged() {
    final backupService = _backupService;

    // Determine validation status based on backup service status
    ValidationStatus validationStatus = ValidationStatus.initial;
    String? validationMessage;
    String? successMessage;

    if (backupService.status == BackupStatus.backingUp) {
      validationStatus = ValidationStatus.validating;
      validationMessage = 'Backup in progress...';
    } else if (backupService.status == BackupStatus.success) {
      validationStatus = ValidationStatus.valid;
      successMessage = backupService.lastBackupMessage;
    } else if (backupService.status == BackupStatus.error) {
      validationStatus = ValidationStatus.invalid;
      validationMessage = backupService.lastError;
    } else if (backupService.isConfigValid) {
      validationStatus = ValidationStatus.valid;
    }

    safeEmit(
      state.copyWith(
        s3Config: backupService.s3Config,
        backupValidationStatus: validationStatus,
        isBackupInProgress: backupService.isBackingUp,
        lastBackupMessage: successMessage,
        backupValidationMessage: validationMessage,
      ),
    );
  }

  /// Save S3 configuration
  Future<void> _saveS3Config(S3Config config) async {
    try {
      await _backupService.saveConfiguration(config);
    } catch (e) {
      safeEmit(
        state.copyWith(
          backupValidationStatus: ValidationStatus.invalid,
          backupValidationMessage: 'Failed to save configuration: $e',
        ),
      );
    }
  }

  /// Validate S3 configuration
  Future<void> validateS3Config() async {
    if (!state.s3Config.isValid) {
      safeEmit(
        state.copyWith(
          backupValidationStatus: ValidationStatus.invalid,
          backupValidationMessage: 'Please fill in all required fields',
        ),
      );
      return;
    }

    safeEmit(
      state.copyWith(
        backupValidationStatus: ValidationStatus.validating,
        backupValidationMessage: 'Validating S3 configuration...',
      ),
    );

    try {
      final isValid = await _backupService.validateConfiguration();

      safeEmit(
        state.copyWith(
          backupValidationStatus: isValid
              ? ValidationStatus.valid
              : ValidationStatus.invalid,
          backupValidationMessage: isValid
              ? 'S3 configuration is valid'
              : _backupService.lastError ??
                    'Failed to validate S3 configuration',
        ),
      );
    } catch (e) {
      safeEmit(
        state.copyWith(
          backupValidationStatus: ValidationStatus.invalid,
          backupValidationMessage: 'Validation failed: $e',
        ),
      );
    }
  }

  /// Validate S3 configuration with provided values
  Future<void> validateS3ConfigWithValues(S3Config config) async {
    if (!config.isValid) {
      safeEmit(
        state.copyWith(
          backupValidationStatus: ValidationStatus.invalid,
          backupValidationMessage: 'Please fill in all required fields',
        ),
      );
      return;
    }

    // Save the config first
    safeEmit(state.copyWith(s3Config: config));
    await _saveS3Config(config);

    safeEmit(
      state.copyWith(
        backupValidationStatus: ValidationStatus.validating,
        backupValidationMessage: 'Validating S3 configuration...',
      ),
    );

    try {
      final isValid = await _backupService.validateConfiguration();

      safeEmit(
        state.copyWith(
          backupValidationStatus: isValid
              ? ValidationStatus.valid
              : ValidationStatus.invalid,
          backupValidationMessage: isValid
              ? 'S3 configuration is valid'
              : _backupService.lastError ??
                    'Failed to validate S3 configuration',
        ),
      );
    } catch (e) {
      safeEmit(
        state.copyWith(
          backupValidationStatus: ValidationStatus.invalid,
          backupValidationMessage: 'Validation failed: $e',
        ),
      );
    }
  }

  /// Perform backup to S3
  Future<void> performBackup() async {
    if (!state.canBackup) {
      return;
    }

    safeEmit(state.copyWith(isBackupInProgress: true, lastBackupMessage: null));

    try {
      final success = await _backupService.backupBookmarks();

      if (success) {
        safeEmit(
          state.copyWith(
            isBackupInProgress: false,
            lastBackupMessage: _backupService.lastBackupMessage,
          ),
        );
      } else {
        safeEmit(
          state.copyWith(
            isBackupInProgress: false,
            backupValidationMessage: _backupService.lastError,
          ),
        );
      }
    } catch (e) {
      safeEmit(
        state.copyWith(
          isBackupInProgress: false,
          backupValidationMessage: 'Backup failed: $e',
        ),
      );
    }
  }

  /// Perform backup with provided S3 configuration
  Future<void> performBackupWithConfig(S3Config config) async {
    if (!config.isValid) {
      return;
    }

    // Save the config first
    safeEmit(state.copyWith(s3Config: config));
    await _saveS3Config(config);

    // Then perform the backup
    await performBackup();
  }

  /// Clear backup configuration
  Future<void> clearBackupConfig() async {
    try {
      await _backupService.clearConfiguration();
      safeEmit(
        state.copyWith(
          s3Config: const S3Config(),
          backupValidationStatus: ValidationStatus.initial,
          backupValidationMessage: null,
          lastBackupMessage: null,
        ),
      );
    } catch (e) {
      safeEmit(
        state.copyWith(
          backupValidationMessage: 'Failed to clear configuration: $e',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _credentialsService.isAuthenticatedNotifier.removeListener(_onAuthChanged);
    _aiSettingsService.removeListener(_onAiSettingsChanged);
    _backupService.removeListener(_onBackupServiceChanged);
    return super.close();
  }
}
