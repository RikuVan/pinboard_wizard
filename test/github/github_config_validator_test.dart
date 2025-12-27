import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:pinboard_wizard/src/github/github_config_validator.dart';
import 'package:pinboard_wizard/src/github/models/models.dart';

@GenerateMocks([http.Client])
void main() {
  late GitHubConfigValidator validator;

  setUp(() {
    validator = GitHubConfigValidator();
  });

  group('GitHubConfigValidator - Token Format Validation', () {
    test('accepts valid classic PAT token', () {
      final result = validator.validateLocally(
        _createValidConfig(),
        'ghp_1234567890123456789012345678901234567890',
      );

      expect(result.isValid, true);
    });

    test('accepts valid fine-grained PAT token', () {
      final result = validator.validateLocally(
        _createValidConfig(),
        'github_pat_1234567890123456789012345678901234567890',
      );

      expect(result.isValid, true);
    });

    test('rejects empty token', () {
      final result = validator.validateLocally(_createValidConfig(), '');

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidToken);
      expect(result.errorMessage, contains('cannot be empty'));
    });

    test('rejects token without valid prefix', () {
      final result = validator.validateLocally(
        _createValidConfig(),
        'invalid_1234567890123456789012345678901234567890',
      );

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidToken);
      expect(result.errorMessage, contains('does not appear to be a valid'));
    });

    test('rejects token that is too short', () {
      final result = validator.validateLocally(
        _createValidConfig(),
        'ghp_short',
      );

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidToken);
      expect(result.errorMessage, contains('too short'));
    });

    test('rejects token with spaces', () {
      final result = validator.validateLocally(
        _createValidConfig(),
        'ghp_1234567890 1234567890123456789012345678901234567890',
      );

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidToken);
      expect(result.errorMessage, contains('contains spaces'));
    });

    test('identifies classic PAT token', () {
      final isClassic = validator.isClassicToken(
        'ghp_1234567890123456789012345678901234567890',
      );
      expect(isClassic, true);

      final isNotClassic = validator.isClassicToken(
        'github_pat_123456789012345678901234567890',
      );
      expect(isNotClassic, false);
    });

    test('identifies fine-grained PAT token', () {
      final isFineGrained = validator.isFineGrainedToken(
        'github_pat_1234567890123456789012345678901234567890',
      );
      expect(isFineGrained, true);

      final isNotFineGrained = validator.isFineGrainedToken(
        'ghp_123456789012345678901234567890',
      );
      expect(isNotFineGrained, false);
    });

    test('gets token type for personal tokens', () {
      expect(
        validator.getTokenType('ghp_1234567890123456789012345678901234567890'),
        'personal',
      );
      expect(
        validator.getTokenType(
          'github_pat_1234567890123456789012345678901234567890',
        ),
        'personal',
      );
    });

    test('gets token type for other tokens', () {
      expect(
        validator.getTokenType('gho_1234567890123456789012345678901234567890'),
        'other',
      );
    });

    test('returns null for unknown token type', () {
      expect(validator.getTokenType('unknown_token'), null);
    });
  });

  group('GitHubConfigValidator - Owner Validation', () {
    test('accepts valid username', () {
      final config = _createValidConfig(owner: 'validuser');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('accepts username with hyphens', () {
      final config = _createValidConfig(owner: 'valid-user-name');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('accepts username with numbers', () {
      final config = _createValidConfig(owner: 'user123');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('rejects empty owner', () {
      final config = _createValidConfig(owner: '');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidOwner);
      expect(result.errorMessage, contains('cannot be empty'));
    });

    test('rejects owner starting with hyphen', () {
      final config = _createValidConfig(owner: '-invaliduser');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidOwner);
      expect(result.errorMessage, contains('Invalid GitHub username'));
    });

    test('rejects owner ending with hyphen', () {
      final config = _createValidConfig(owner: 'invaliduser-');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidOwner);
    });

    test('rejects owner with consecutive hyphens', () {
      final config = _createValidConfig(owner: 'invalid--user');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidOwner);
    });

    test('rejects owner with special characters', () {
      final config = _createValidConfig(owner: 'invalid@user');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidOwner);
    });

    test('rejects owner longer than 39 characters', () {
      final config = _createValidConfig(owner: 'a' * 40);
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidOwner);
    });
  });

  group('GitHubConfigValidator - Repository Validation', () {
    test('accepts valid repository name', () {
      final config = _createValidConfig(repo: 'my-repo');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('accepts repo with underscores and periods', () {
      final config = _createValidConfig(repo: 'my_repo.notes');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('rejects empty repository name', () {
      final config = _createValidConfig(repo: '');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidRepo);
      expect(result.errorMessage, contains('cannot be empty'));
    });

    test('rejects repository name with spaces', () {
      final config = _createValidConfig(repo: 'my repo');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidRepo);
      expect(result.errorMessage, contains('Cannot contain spaces'));
    });

    test('rejects repository name with special characters', () {
      final config = _createValidConfig(repo: 'my@repo!');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidRepo);
    });

    test('rejects repository name longer than 100 characters', () {
      final config = _createValidConfig(repo: 'a' * 101);
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidRepo);
    });
  });

  group('GitHubConfigValidator - Branch Validation', () {
    test('accepts valid branch name', () {
      final config = _createValidConfig(branch: 'main');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('accepts branch with slashes', () {
      final config = _createValidConfig(branch: 'feature/new-feature');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('rejects empty branch name', () {
      final config = _createValidConfig(branch: '');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidBranch);
      expect(result.errorMessage, contains('cannot be empty'));
    });

    test('rejects branch with spaces', () {
      final config = _createValidConfig(branch: 'my branch');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidBranch);
    });

    test('rejects branch with double dots', () {
      final config = _createValidConfig(branch: 'feature..branch');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidBranch);
      expect(result.errorMessage, contains('Cannot contain'));
    });

    test('rejects branch with consecutive slashes', () {
      final config = _createValidConfig(branch: 'feature//branch');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidBranch);
    });

    test('rejects branch ending with .lock', () {
      final config = _createValidConfig(branch: 'mybranch.lock');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidBranch);
    });

    test('rejects branch ending with slash', () {
      final config = _createValidConfig(branch: 'feature/');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidBranch);
    });

    test('rejects branch starting with slash', () {
      final config = _createValidConfig(branch: '/feature');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidBranch);
    });
  });

  group('GitHubConfigValidator - Notes Path Validation', () {
    test('accepts valid notes path', () {
      final config = _createValidConfig(notesPath: 'notes/');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('accepts empty notes path', () {
      final config = _createValidConfig(notesPath: '');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('accepts nested path', () {
      final config = _createValidConfig(notesPath: 'docs/notes/');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('rejects path with backslashes', () {
      final config = _createValidConfig(notesPath: 'notes\\folder');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidNotesPath);
    });

    test('rejects path with colons', () {
      final config = _createValidConfig(notesPath: 'C:/notes');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidNotesPath);
    });

    test('rejects path with asterisks', () {
      final config = _createValidConfig(notesPath: 'notes/*');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidNotesPath);
    });

    test('rejects path with double dots', () {
      final config = _createValidConfig(notesPath: '../notes');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidNotesPath);
    });

    test('rejects path starting with slash', () {
      final config = _createValidConfig(notesPath: '/notes');
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidNotesPath);
    });
  });

  group('GitHubConfigValidator - Token Expiry Validation', () {
    test('accepts future expiry date', () {
      final futureDate = DateTime.now().add(const Duration(days: 90));
      final config = _createValidConfig(tokenExpiry: futureDate);
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('accepts expiry date in 1 year', () {
      final futureDate = DateTime.now().add(const Duration(days: 365));
      final config = _createValidConfig(tokenExpiry: futureDate);
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });

    test('rejects expiry date in the past', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final config = _createValidConfig(tokenExpiry: pastDate);
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidToken);
      expect(result.errorMessage, contains('already expired'));
    });

    test('rejects expiry date more than 2 years in future', () {
      final farFutureDate = DateTime.now().add(const Duration(days: 800));
      final config = _createValidConfig(tokenExpiry: farFutureDate);
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, false);
      expect(result.errorType, ValidationErrorType.invalidToken);
      expect(result.errorMessage, contains('more than 2 years in the future'));
    });

    test('accepts null expiry date', () {
      final config = _createValidConfig(tokenExpiry: null);
      final result = validator.validateLocally(config, _validToken());

      expect(result.isValid, true);
    });
  });

  group('GitHubConfigValidator - ValidationResult', () {
    test('success result has correct properties', () {
      const result = ValidationResult.success();

      expect(result.isValid, true);
      expect(result.errorMessage, null);
      expect(result.errorType, null);
      expect(result.toString(), 'Valid');
    });

    test('error result has correct properties', () {
      const result = ValidationResult.error(
        'Test error',
        ValidationErrorType.invalidToken,
      );

      expect(result.isValid, false);
      expect(result.errorMessage, 'Test error');
      expect(result.errorType, ValidationErrorType.invalidToken);
      expect(result.toString(), contains('Invalid: Test error'));
    });
  });
}

// Helper functions

GitHubNotesConfig _createValidConfig({
  String owner = 'testuser',
  String repo = 'testrepo',
  String branch = 'main',
  String notesPath = 'notes/',
  DateTime? tokenExpiry,
}) {
  return GitHubNotesConfig(
    owner: owner,
    repo: repo,
    branch: branch,
    notesPath: notesPath,
    deviceId: 'test-device-id',
    tokenType: TokenType.fineGrained,
    tokenExpiry: tokenExpiry,
    isConfigured: true,
  );
}

String _validToken() {
  return 'ghp_1234567890123456789012345678901234567890';
}
