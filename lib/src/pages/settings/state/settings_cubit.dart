import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/pages/settings/state/settings_state.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required CredentialsService credentialsService,
    required PinboardService pinboardService,
    required AiSettingsService aiSettingsService,
  }) : _credentialsService = credentialsService,
       _pinboardService = pinboardService,
       _aiSettingsService = aiSettingsService,
       super(const SettingsState()) {
    // Listen to authentication changes
    _credentialsService.isAuthenticatedNotifier.addListener(_onAuthChanged);
    // Listen to AI settings changes
    _aiSettingsService.addListener(_onAiSettingsChanged);
  }

  final CredentialsService _credentialsService;
  final PinboardService _pinboardService;
  final AiSettingsService _aiSettingsService;
  Timer? _debounceTimer;

  /// Initialize and load current settings
  Future<void> loadSettings() async {
    emit(state.copyWith(status: SettingsStatus.loading));

    try {
      // Load Pinboard credentials
      final credentials = await _credentialsService.getCredentials();
      final pinboardApiKey = credentials?.apiKey ?? '';
      final isPinboardAuthenticated =
          _credentialsService.isAuthenticatedNotifier.value;

      // Load AI settings
      final aiSettings = _aiSettingsService.settings;

      emit(
        state.copyWith(
          status: SettingsStatus.loaded,
          pinboardApiKey: pinboardApiKey,
          isPinboardAuthenticated: isPinboardAuthenticated,
          isAiEnabled: aiSettings.isEnabled,
          openAiApiKey: aiSettings.openai.apiKey ?? '',
          jinaApiKey: aiSettings.webScraping.jinaApiKey ?? '',
          descriptionMaxLength: aiSettings.openai.descriptionMaxLength,
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
      emit(
        state.copyWith(
          status: SettingsStatus.error,
          errorMessage: 'Failed to load settings: $e',
        ),
      );
    }
  }

  /// Update Pinboard API key
  void updatePinboardApiKey(String apiKey) {
    emit(
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
      emit(
        state.copyWith(
          errorMessage: 'Invalid API key. Expected: username:hexstring',
        ),
      );
      return;
    }

    emit(state.copyWith(status: SettingsStatus.saving, errorMessage: null));

    try {
      await _credentialsService.saveCredentials(apiKey);

      // Test the connection and update validation status
      emit(state.copyWith(isPinboardTesting: true));
      final connectionOk = await _pinboardService.testConnection();

      emit(
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
      emit(
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
      emit(
        state.copyWith(
          pinboardApiKey: '',
          pinboardValidationStatus: ValidationStatus.initial,
          pinboardValidationMessage: null,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to clear: $e'));
    }
  }

  /// Toggle AI enabled state
  Future<void> setAiEnabled(bool enabled) async {
    try {
      await _aiSettingsService.setAiEnabled(enabled);
      emit(state.copyWith(isAiEnabled: enabled));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to update AI settings: $e'));
    }
  }

  /// Update OpenAI API key
  void updateOpenAiApiKey(String apiKey) {
    emit(
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
        emit(
          state.copyWith(
            openAiValidationStatus: ValidationStatus.initial,
            openAiValidationMessage: null,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to save OpenAI key: $e'));
    }
  }

  /// Clear OpenAI API key
  Future<void> clearOpenAiKey() async {
    try {
      await _aiSettingsService.setOpenAiApiKey(null);
      emit(
        state.copyWith(
          openAiApiKey: '',
          openAiValidationStatus: ValidationStatus.initial,
          openAiValidationMessage: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to clear OpenAI key: $e'));
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
    emit(
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
      emit(state.copyWith(errorMessage: 'Failed to save Jina key: $e'));
    }
  }

  /// Clear Jina API key
  Future<void> clearJinaKey() async {
    try {
      await _aiSettingsService.setJinaApiKey(null);
      emit(
        state.copyWith(
          jinaApiKey: '',
          jinaValidationStatus: ValidationStatus.initial,
          jinaValidationMessage: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to clear Jina key: $e'));
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
      emit(
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
      emit(state.copyWith(errorMessage: 'Failed to clear AI settings: $e'));
    }
  }

  /// Set description max length
  Future<void> setDescriptionMaxLength(int length) async {
    try {
      await _aiSettingsService.setDescriptionMaxLength(length);
      emit(state.copyWith(descriptionMaxLength: length));
    } catch (e) {
      emit(
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
      emit(state.copyWith(maxTags: maxTags));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to update max tags: $e'));
    }
  }

  /// Clear error message
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }

  /// Private method to validate OpenAI API key
  Future<void> _validateOpenAiKey(String apiKey) async {
    emit(
      state.copyWith(
        openAiValidationStatus: ValidationStatus.validating,
        openAiValidationMessage: null,
      ),
    );

    try {
      final result = await _aiSettingsService.testOpenAiConnection(apiKey);

      if (!isClosed) {
        emit(
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
        emit(
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
    emit(
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
        emit(
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
        emit(
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
    emit(
      state.copyWith(
        isPinboardAuthenticated:
            _credentialsService.isAuthenticatedNotifier.value,
      ),
    );
  }

  /// Listen to AI settings changes from AiSettingsService
  void _onAiSettingsChanged() {
    final aiSettings = _aiSettingsService.settings;
    emit(
      state.copyWith(
        isAiEnabled: aiSettings.isEnabled,
        descriptionMaxLength: aiSettings.openai.descriptionMaxLength,
        maxTags: aiSettings.openai.maxTags,
      ),
    );
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _credentialsService.isAuthenticatedNotifier.removeListener(_onAuthChanged);
    _aiSettingsService.removeListener(_onAiSettingsChanged);
    return super.close();
  }
}
