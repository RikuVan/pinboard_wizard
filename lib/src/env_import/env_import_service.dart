import 'package:flutter/foundation.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/env_import/env_file_parser.dart';
import 'package:pinboard_wizard/src/github/github_auth_service.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/github/models/github_notes_config.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:uuid/uuid.dart';

/// Preview of a parsed `.env` file, split into variables the app understands
/// and everything else.
class EnvImportPreview {
  final Map<String, String> recognized;
  final int ignoredLines;
  final List<String> unrecognized;

  const EnvImportPreview({
    required this.recognized,
    required this.ignoredLines,
    required this.unrecognized,
  });

  bool get isEmpty => recognized.isEmpty;
}

/// Outcome of applying an import: which variables were written, and which
/// failed with what message.
class EnvImportResult {
  final List<String> applied;
  final Map<String, String> failed;

  const EnvImportResult({required this.applied, required this.failed});
}

/// One-time import of credentials from `.env` file contents.
///
/// Env values always win over stored values; variables absent from the file
/// are never touched. Writes go through the existing services so listeners
/// (auth state, settings UI) update immediately.
class EnvImportService {
  static const Set<String> recognizedVariables = {
    'PINBOARD_API_TOKEN',
    'OPENAI_API_KEY',
    'JINA_API_KEY',
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_REGION',
    'S3_BUCKET',
    'S3_FILE_PATH',
    'GITHUB_PAT',
    'GITHUB_OWNER',
    'GITHUB_REPO',
    'GITHUB_BRANCH',
    'GITHUB_NOTES_PATH',
  };

  static const _s3Variables = {
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_REGION',
    'S3_BUCKET',
    'S3_FILE_PATH',
  };

  static const _githubVariables = {
    'GITHUB_PAT',
    'GITHUB_OWNER',
    'GITHUB_REPO',
    'GITHUB_BRANCH',
    'GITHUB_NOTES_PATH',
  };

  final CredentialsService _credentialsService;
  final AiSettingsService _aiSettingsService;
  final BackupService _backupService;
  final GitHubCredentialsStorage _githubStorage;
  final GitHubAuthService _githubAuthService;
  final EnvFileParser _parser = EnvFileParser();
  final Uuid _uuid = const Uuid();

  EnvImportService({
    required this._credentialsService,
    required this._aiSettingsService,
    required this._backupService,
    required this._githubStorage,
    required this._githubAuthService,
  });

  EnvImportPreview preview(String contents) {
    final parsed = _parser.parse(contents);
    final recognized = <String, String>{};
    final unrecognized = <String>[];
    var emptyValueLines = 0;

    for (final entry in parsed.variables.entries) {
      if (!recognizedVariables.contains(entry.key)) {
        unrecognized.add(entry.key);
      } else if (entry.value.isEmpty) {
        // An empty value would clear a stored credential on import; treat
        // the line as ignored instead so imports never erase secrets.
        emptyValueLines++;
      } else {
        recognized[entry.key] = entry.value;
      }
    }

    return EnvImportPreview(
      recognized: recognized,
      ignoredLines: parsed.ignoredLines + emptyValueLines,
      unrecognized: unrecognized,
    );
  }

  Future<EnvImportResult> apply(Map<String, String> variables) async {
    final applied = <String>[];
    final failed = <String, String>{};

    // Pinboard
    final pinboardToken = variables['PINBOARD_API_TOKEN'];
    if (pinboardToken != null) {
      try {
        await _credentialsService.saveCredentials(pinboardToken);
        applied.add('PINBOARD_API_TOKEN');
      } catch (e) {
        failed['PINBOARD_API_TOKEN'] = '$e';
      }
    }

    // OpenAI / Jina
    final openAiKey = variables['OPENAI_API_KEY'];
    if (openAiKey != null) {
      try {
        await _aiSettingsService.setOpenAiApiKey(openAiKey);
        applied.add('OPENAI_API_KEY');
      } catch (e) {
        failed['OPENAI_API_KEY'] = '$e';
      }
    }
    final jinaKey = variables['JINA_API_KEY'];
    if (jinaKey != null) {
      try {
        await _aiSettingsService.setJinaApiKey(jinaKey);
        applied.add('JINA_API_KEY');
      } catch (e) {
        failed['JINA_API_KEY'] = '$e';
      }
    }

    // S3 backup — merge into the existing config.
    final s3Keys = variables.keys.where(_s3Variables.contains).toList();
    if (s3Keys.isNotEmpty) {
      try {
        await _backupService.loadConfiguration();
        // loadConfiguration swallows storage errors into status/lastError;
        // merging into a config that failed to load could clobber the real
        // one, so skip the merge/save entirely when the load failed.
        if (_backupService.status == BackupStatus.error) {
          final message =
              _backupService.lastError ??
              'Failed to load existing S3 configuration';
          for (final key in s3Keys) {
            failed[key] = message;
          }
        } else {
          final merged = _backupService.s3Config.copyWith(
            accessKey: variables['AWS_ACCESS_KEY_ID'],
            secretKey: variables['AWS_SECRET_ACCESS_KEY'],
            region: variables['AWS_REGION'],
            bucketName: variables['S3_BUCKET'],
            filePath: variables['S3_FILE_PATH'],
          );
          await _backupService.saveConfiguration(merged);
          // saveConfiguration swallows storage errors into status/lastError
          // instead of throwing, so check the status explicitly.
          if (_backupService.status == BackupStatus.error) {
            final message =
                _backupService.lastError ?? 'Failed to save S3 configuration';
            for (final key in s3Keys) {
              failed[key] = message;
            }
          } else {
            applied.addAll(s3Keys);
          }
        }
      } catch (e) {
        for (final key in s3Keys) {
          failed[key] = '$e';
        }
      }
    }

    // GitHub — merge into the existing config, or create one.
    final githubKeys = variables.keys.where(_githubVariables.contains).toList();
    if (githubKeys.isNotEmpty) {
      final configKeys = githubKeys
          .where((key) => key != 'GITHUB_PAT')
          .toList();
      final importedToken = variables['GITHUB_PAT'];

      try {
        final existing = await _githubStorage.readConfig();
        final token = importedToken ?? await _githubStorage.readToken();

        final base =
            existing ??
            GitHubNotesConfig(owner: '', repo: '', deviceId: _uuid.v4());
        final owner = variables['GITHUB_OWNER'] ?? base.owner;
        final repo = variables['GITHUB_REPO'] ?? base.repo;
        final merged = base.copyWith(
          owner: owner,
          repo: repo,
          branch: variables['GITHUB_BRANCH'] ?? base.branch,
          notesPath: variables['GITHUB_NOTES_PATH'] ?? base.notesPath,
          isConfigured:
              owner.isNotEmpty &&
              repo.isNotEmpty &&
              (token?.isNotEmpty ?? false),
        );

        await _githubStorage.saveConfig(merged);
        applied.addAll(configKeys);
      } catch (e) {
        for (final key in configKeys) {
          failed[key] = '$e';
        }
      }

      if (importedToken != null) {
        try {
          await _githubStorage.saveToken(importedToken);
          applied.add('GITHUB_PAT');
        } catch (e) {
          failed['GITHUB_PAT'] = '$e';
        }
      }

      // Refresh auth state; a failure here is not an import failure — the
      // credentials were already persisted above.
      try {
        await _githubAuthService.initialize();
      } catch (e) {
        debugPrint('EnvImportService: GitHub auth refresh failed: $e');
      }
    }

    return EnvImportResult(applied: applied, failed: failed);
  }
}
