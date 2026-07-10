/// Canonical keychain key for every stored credential.
///
/// Single source of truth referenced both by `AppSecureStorage.syncedKeys`
/// and by each service's storage key, so the sync migration list can never
/// drift from the keys services actually write. Deliberately imports
/// nothing, making it safe to import from anywhere without cycles.
abstract final class CredentialKeys {
  static const String pinboardCredentials = 'pinboard_credentials';
  static const String aiSettings = 'ai_settings';
  static const String backupS3Config = 'backup_s3_config';
  static const String githubNotesConfig = 'github_notes_config';
  static const String githubPatToken = 'github_pat_token';
}
