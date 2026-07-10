import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinboard_wizard/src/ai/ai_bookmark_service.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/ai/openai/openai_service.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/jina_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/env_import/env_import_service.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/github_client.dart';
import 'package:pinboard_wizard/src/github/github_config_validator.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/notes/services/file_service.dart';
import 'package:pinboard_wizard/src/notes/services/network_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_filename_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_sync_engine.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/flutter_secure_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

final locator = GetIt.instance;

Future<void> setup() async {
  // Get notes directory for file service (use root app documents directory)
  final appDocDir = await getApplicationDocumentsDirectory();
  final notesDir = appDocDir;

  // Central keychain access — must be initialized before any service reads
  // credentials, because the sync flag decides which keychain set is active.
  final appSecureStorage = AppSecureStorage();
  await appSecureStorage.init();
  locator.registerSingleton<AppSecureStorage>(appSecureStorage);

  locator
    ..registerLazySingleton<PinboardService>(
      () => PinboardService(secretStorage: locator.get<SecretStorage>()),
    )
    ..registerLazySingleton<CredentialsService>(
      () => CredentialsService(storage: locator.get<SecretStorage>()),
    )
    ..registerLazySingleton<SecretStorage>(
      () => FlutterSecureSecretsStorage(
        storage: locator.get<AppSecureStorage>(),
      ),
    )
    ..registerLazySingleton<AiSettingsService>(
      () => AiSettingsService(storage: locator.get<AppSecureStorage>()),
    )
    ..registerLazySingleton<OpenAiService>(() => OpenAiService())
    ..registerLazySingleton<JinaService>(() => JinaService())
    ..registerLazySingleton<AiBookmarkService>(() => AiBookmarkService())
    ..registerLazySingleton<BackupService>(
      () => BackupService(storage: locator.get<AppSecureStorage>()),
    )
    ..registerLazySingleton<GitHubCredentialsStorage>(
      () => GitHubCredentialsStorage(storage: locator.get<AppSecureStorage>()),
    )
    ..registerLazySingleton<GitHubAuthService>(
      () => GitHubAuthService(storage: locator.get<GitHubCredentialsStorage>()),
    )
    ..registerLazySingleton<GitHubConfigValidator>(
      () => GitHubConfigValidator(),
    )
    ..registerLazySingleton<EnvImportService>(
      () => EnvImportService(
        credentialsService: locator.get<CredentialsService>(),
        aiSettingsService: locator.get<AiSettingsService>(),
        backupService: locator.get<BackupService>(),
        githubStorage: locator.get<GitHubCredentialsStorage>(),
        githubAuthService: locator.get<GitHubAuthService>(),
      ),
    )
    // Notes services
    ..registerLazySingleton<NotesDatabase>(() => NotesDatabase())
    ..registerLazySingleton<NetworkService>(() => NetworkService())
    ..registerLazySingleton<NoteFilenameService>(() => NoteFilenameService())
    ..registerLazySingleton<FileService>(() => FileService(notesDir))
    ..registerFactoryAsync<NoteSyncEngine>(() async {
      final authService = locator.get<GitHubAuthService>();
      final config = await authService.getConfig();
      final token = await authService.getToken();

      if (config == null || token == null || !config.isConfigured) {
        throw Exception('GitHub credentials not configured');
      }

      final githubClient = GitHubClient(
        token: token,
        owner: config.owner,
        repo: config.repo,
        branch: config.branch,
        notesPath: config.notesPath,
      );

      return NoteSyncEngine(
        database: locator.get<NotesDatabase>(),
        githubClient: githubClient,
        fileService: locator.get<FileService>(),
        networkService: locator.get<NetworkService>(),
        filenameService: locator.get<NoteFilenameService>(),
      );
    });
}
