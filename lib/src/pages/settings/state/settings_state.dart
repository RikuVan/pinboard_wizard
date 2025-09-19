import 'package:equatable/equatable.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';

enum SettingsStatus { initial, loading, loaded, error, saving, testing }

enum ValidationStatus { initial, validating, valid, invalid }

class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.errorMessage,
    // Pinboard settings
    this.pinboardApiKey = '',
    this.pinboardValidationStatus = ValidationStatus.initial,
    this.pinboardValidationMessage,
    this.isPinboardAuthenticated = false,
    this.isPinboardTesting = false,
    // AI settings
    this.isAiEnabled = false,
    this.openAiApiKey = '',
    this.openAiValidationStatus = ValidationStatus.initial,
    this.openAiValidationMessage,
    this.jinaApiKey = '',
    this.jinaValidationStatus = ValidationStatus.initial,
    this.jinaValidationMessage,
    this.descriptionMaxLength = 100,
    this.maxTags = 5,
    // Backup settings
    this.s3Config = const S3Config(),
    this.backupValidationStatus = ValidationStatus.initial,
    this.backupValidationMessage,
    this.isBackupInProgress = false,
    this.lastBackupMessage,
  });

  final SettingsStatus status;
  final String? errorMessage;

  // Pinboard settings
  final String pinboardApiKey;
  final ValidationStatus pinboardValidationStatus;
  final String? pinboardValidationMessage;
  final bool isPinboardAuthenticated;
  final bool isPinboardTesting;

  // AI settings
  final bool isAiEnabled;
  final String openAiApiKey;
  final ValidationStatus openAiValidationStatus;
  final String? openAiValidationMessage;
  final String jinaApiKey;
  final ValidationStatus jinaValidationStatus;
  final String? jinaValidationMessage;
  final int descriptionMaxLength;
  final int maxTags;

  // Backup settings
  final S3Config s3Config;
  final ValidationStatus backupValidationStatus;
  final String? backupValidationMessage;
  final bool isBackupInProgress;
  final String? lastBackupMessage;

  SettingsState copyWith({
    SettingsStatus? status,
    Object? errorMessage = _sentinel,
    String? pinboardApiKey,
    ValidationStatus? pinboardValidationStatus,
    Object? pinboardValidationMessage = _sentinel,
    bool? isPinboardAuthenticated,
    bool? isPinboardTesting,
    bool? isAiEnabled,
    String? openAiApiKey,
    ValidationStatus? openAiValidationStatus,
    Object? openAiValidationMessage = _sentinel,
    String? jinaApiKey,
    ValidationStatus? jinaValidationStatus,
    Object? jinaValidationMessage = _sentinel,
    int? descriptionMaxLength,
    int? maxTags,
    S3Config? s3Config,
    ValidationStatus? backupValidationStatus,
    Object? backupValidationMessage = _sentinel,
    bool? isBackupInProgress,
    Object? lastBackupMessage = _sentinel,
  }) {
    return SettingsState(
      status: status ?? this.status,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      pinboardApiKey: pinboardApiKey ?? this.pinboardApiKey,
      pinboardValidationStatus:
          pinboardValidationStatus ?? this.pinboardValidationStatus,
      pinboardValidationMessage: pinboardValidationMessage == _sentinel
          ? this.pinboardValidationMessage
          : pinboardValidationMessage as String?,
      isPinboardAuthenticated:
          isPinboardAuthenticated ?? this.isPinboardAuthenticated,
      isPinboardTesting: isPinboardTesting ?? this.isPinboardTesting,
      isAiEnabled: isAiEnabled ?? this.isAiEnabled,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiValidationStatus:
          openAiValidationStatus ?? this.openAiValidationStatus,
      openAiValidationMessage: openAiValidationMessage == _sentinel
          ? this.openAiValidationMessage
          : openAiValidationMessage as String?,
      jinaApiKey: jinaApiKey ?? this.jinaApiKey,
      jinaValidationStatus: jinaValidationStatus ?? this.jinaValidationStatus,
      jinaValidationMessage: jinaValidationMessage == _sentinel
          ? this.jinaValidationMessage
          : jinaValidationMessage as String?,
      descriptionMaxLength: descriptionMaxLength ?? this.descriptionMaxLength,
      maxTags: maxTags ?? this.maxTags,
      s3Config: s3Config ?? this.s3Config,
      backupValidationStatus:
          backupValidationStatus ?? this.backupValidationStatus,
      backupValidationMessage: backupValidationMessage == _sentinel
          ? this.backupValidationMessage
          : backupValidationMessage as String?,
      isBackupInProgress: isBackupInProgress ?? this.isBackupInProgress,
      lastBackupMessage: lastBackupMessage == _sentinel
          ? this.lastBackupMessage
          : lastBackupMessage as String?,
    );
  }

  static const _sentinel = Object();

  // Convenience getters
  bool get isLoading => status == SettingsStatus.loading;
  bool get isSaving => status == SettingsStatus.saving;
  bool get isTesting => status == SettingsStatus.testing;
  bool get hasError => status == SettingsStatus.error;

  bool get isPinboardValidating =>
      pinboardValidationStatus == ValidationStatus.validating;
  bool get isPinboardValid =>
      pinboardValidationStatus == ValidationStatus.valid;
  bool get isPinboardInvalid =>
      pinboardValidationStatus == ValidationStatus.invalid;

  bool get isOpenAiValidating =>
      openAiValidationStatus == ValidationStatus.validating;
  bool get isOpenAiValid => openAiValidationStatus == ValidationStatus.valid;
  bool get isOpenAiInvalid =>
      openAiValidationStatus == ValidationStatus.invalid;

  bool get isJinaValidating =>
      jinaValidationStatus == ValidationStatus.validating;
  bool get isJinaValid => jinaValidationStatus == ValidationStatus.valid;
  bool get isJinaInvalid => jinaValidationStatus == ValidationStatus.invalid;

  bool get isBackupValidating =>
      backupValidationStatus == ValidationStatus.validating;
  bool get isBackupValid => backupValidationStatus == ValidationStatus.valid;
  bool get isBackupInvalid =>
      backupValidationStatus == ValidationStatus.invalid;
  bool get canBackup => isBackupValid && !isBackupInProgress;

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    pinboardApiKey,
    pinboardValidationStatus,
    pinboardValidationMessage,
    isPinboardAuthenticated,
    isPinboardTesting,
    isAiEnabled,
    openAiApiKey,
    openAiValidationStatus,
    openAiValidationMessage,
    jinaApiKey,
    jinaValidationStatus,
    jinaValidationMessage,
    descriptionMaxLength,
    maxTags,
    s3Config,
    backupValidationStatus,
    backupValidationMessage,
    isBackupInProgress,
    lastBackupMessage,
  ];
}
