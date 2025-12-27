import 'package:get_it/get_it.dart';
import 'package:pinboard_wizard/src/ai/ai_bookmark_service.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/ai/openai/openai_service.dart';
import 'package:pinboard_wizard/src/ai/web_scraping/jina_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/flutter_secure_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

final locator = GetIt.instance;

Future<void> setup() async {
  locator
    ..registerLazySingleton<PinboardService>(
      () => PinboardService(secretStorage: locator.get<SecretStorage>()),
    )
    ..registerLazySingleton<CredentialsService>(
      () => CredentialsService(storage: locator.get<SecretStorage>()),
    )
    ..registerLazySingleton<SecretStorage>(() => FlutterSecureSecretsStorage())
    ..registerLazySingleton<AiSettingsService>(() => AiSettingsService())
    ..registerLazySingleton<OpenAiService>(() => OpenAiService())
    ..registerLazySingleton<JinaService>(() => JinaService())
    ..registerLazySingleton<AiBookmarkService>(() => AiBookmarkService())
    ..registerLazySingleton<BackupService>(() => BackupService())
    ..registerLazySingleton<GitHubCredentialsStorage>(
      () => GitHubCredentialsStorage(),
    )
    ..registerLazySingleton<GitHubAuthService>(
      () => GitHubAuthService(storage: locator.get<GitHubCredentialsStorage>()),
    );
}
