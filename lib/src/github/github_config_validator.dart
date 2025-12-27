import 'package:flutter/foundation.dart';
import 'package:pinboard_wizard/src/github/github_client.dart';
import 'package:pinboard_wizard/src/github/models/models.dart';

/// Result of a GitHub configuration validation
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final ValidationErrorType? errorType;

  const ValidationResult.success()
    : isValid = true,
      errorMessage = null,
      errorType = null;

  const ValidationResult.error(this.errorMessage, this.errorType)
    : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $errorMessage';
}

/// Types of validation errors
enum ValidationErrorType {
  invalidToken,
  tokenNoPermissions,
  tokenExpired,
  invalidTokenExpiry,
  invalidOwner,
  invalidRepo,
  invalidBranch,
  invalidNotesPath,
  repositoryNotFound,
  branchNotFound,
  networkError,
  unknownError,
}

/// Service for validating GitHub configuration and credentials.
///
/// Provides both local (format) and remote (API) validation.
///
/// Example:
/// ```dart
/// final validator = GitHubConfigValidator();
///
/// // Quick local validation
/// final localResult = validator.validateLocally(config, token);
/// if (!localResult.isValid) {
///   print('Invalid config: ${localResult.errorMessage}');
///   return;
/// }
///
/// // Full validation with API calls
/// final remoteResult = await validator.validateRemotely(config, token);
/// if (remoteResult.isValid) {
///   // Safe to save and use
///   await saveConfig(config, token);
/// }
/// ```
class GitHubConfigValidator {
  /// GitHub token prefixes for different token types
  static const _personalAccessTokenPrefixes = [
    'ghp_', // Personal access token (classic)
    'github_pat_', // Fine-grained personal access token
  ];

  static const _otherTokenPrefixes = [
    'gho_', // OAuth access token
    'ghu_', // GitHub App user access token
    'ghs_', // GitHub App installation access token
    'ghr_', // GitHub App refresh token
  ];

  /// All valid GitHub token prefixes
  static const _allTokenPrefixes = [
    ..._personalAccessTokenPrefixes,
    ..._otherTokenPrefixes,
  ];

  /// RegExp patterns for validation (static final for performance)
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9-]+$');
  static final _repoNamePattern = RegExp(r'^[a-zA-Z0-9._-]+$');
  static final _invalidBranchCharsPattern = RegExp(
    r'[\x00-\x1f\x7f~^:?*\[\]\\]',
  );
  static final _invalidPathCharsPattern = RegExp(r'[\\:*?"<>|]');

  /// Validates configuration locally (format checks only, no API calls).
  ///
  /// This is fast and can be used for immediate feedback in the UI.
  ValidationResult validateLocally(GitHubNotesConfig config, String token) {
    // Validate token format
    final tokenResult = _validateTokenFormat(token);
    if (!tokenResult.isValid) return tokenResult;

    // Validate owner
    if (config.owner.isEmpty) {
      return const ValidationResult.error(
        'GitHub owner/username cannot be empty',
        ValidationErrorType.invalidOwner,
      );
    }

    if (!_isValidGitHubUsername(config.owner)) {
      return const ValidationResult.error(
        'Invalid GitHub username. Must contain only alphanumeric characters or hyphens, '
        'cannot start with a hyphen, and cannot be longer than 39 characters.',
        ValidationErrorType.invalidOwner,
      );
    }

    // Validate repository name
    if (config.repo.isEmpty) {
      return const ValidationResult.error(
        'Repository name cannot be empty',
        ValidationErrorType.invalidRepo,
      );
    }

    if (!_isValidRepositoryName(config.repo)) {
      return const ValidationResult.error(
        'Invalid repository name. Cannot contain spaces, must be less than 100 characters, '
        'and can only contain alphanumeric characters, hyphens, underscores, and periods.',
        ValidationErrorType.invalidRepo,
      );
    }

    // Validate branch name
    if (config.branch.isEmpty) {
      return const ValidationResult.error(
        'Branch name cannot be empty',
        ValidationErrorType.invalidBranch,
      );
    }

    if (!_isValidBranchName(config.branch)) {
      return const ValidationResult.error(
        'Invalid branch name. Cannot contain spaces, .., consecutive slashes, '
        'or end with .lock or a slash.',
        ValidationErrorType.invalidBranch,
      );
    }

    // Validate notes path
    if (!_isValidNotesPath(config.notesPath)) {
      return const ValidationResult.error(
        'Invalid notes path. Cannot contain invalid characters like \\, :, *, ?, ", <, >, |',
        ValidationErrorType.invalidNotesPath,
      );
    }

    // Validate token expiry if provided
    if (config.tokenExpiry != null) {
      final expiryResult = _validateTokenExpiry(config.tokenExpiry!);
      if (!expiryResult.isValid) return expiryResult;
    }

    return const ValidationResult.success();
  }

  /// Validates configuration remotely by making API calls to GitHub.
  ///
  /// This verifies that:
  /// - The token is valid and not expired
  /// - The token has access to the repository
  /// - The repository exists
  /// - The branch exists
  ///
  /// This is slower and requires network access, so use sparingly.
  Future<ValidationResult> validateRemotely(
    GitHubNotesConfig config,
    String token,
  ) async {
    debugPrint('🔍 Starting remote validation...');
    debugPrint('   Owner: ${config.owner}');
    debugPrint('   Repo: ${config.repo}');
    debugPrint('   Branch: ${config.branch}');
    debugPrint('   Notes Path: "${config.notesPath}"');

    // First do local validation
    final localResult = validateLocally(config, token);
    if (!localResult.isValid) {
      debugPrint('   ✗ Local validation failed: ${localResult.errorMessage}');
      return localResult;
    }
    debugPrint('   ✓ Local validation passed');

    // Create a client to test the configuration
    GitHubClient? client;
    try {
      client = GitHubClient(
        token: token,
        owner: config.owner,
        repo: config.repo,
        branch: config.branch,
        notesPath: config.notesPath,
      );

      // Test authentication
      debugPrint('   Testing authentication...');
      final isAuthenticated = await client.testAuthentication();
      if (!isAuthenticated) {
        debugPrint('   ✗ Authentication failed');
        return const ValidationResult.error(
          'Invalid token or authentication failed. Please check your Personal Access Token.',
          ValidationErrorType.invalidToken,
        );
      }
      debugPrint('   ✓ Authentication successful');

      // Try to get the latest commit to verify repo and branch access
      debugPrint('   Verifying repository and branch access...');
      try {
        final files = await client.listNotesFiles();
        debugPrint('   ✓ Repository access successful');
        debugPrint('   ✓ Found ${files.length} files in notes path');
        debugPrint('🎉 Remote validation completed successfully');
      } on GitHubAuthException catch (e) {
        debugPrint('   ✗ Permission denied: ${e.message}');
        return const ValidationResult.error(
          'Token does not have permission to access this repository. '
          'Please ensure your token has "Contents: Read and write" permissions.',
          ValidationErrorType.tokenNoPermissions,
        );
      } on GitHubException catch (e) {
        if (e.statusCode == 404) {
          debugPrint('   ✗ Repository or branch not found (404)');
          // Could be repo not found or branch not found
          return ValidationResult.error(
            'Repository "${config.owner}/${config.repo}" or branch "${config.branch}" not found. '
            'Please check the owner, repository name, and branch.',
            ValidationErrorType.repositoryNotFound,
          );
        }
        debugPrint('   ✗ GitHub API error: ${e.message}');
        return ValidationResult.error(
          'Failed to access repository: ${e.message}',
          ValidationErrorType.unknownError,
        );
      }

      return const ValidationResult.success();
    } catch (e) {
      debugPrint('   ✗ Unexpected error during validation: $e');
      return ValidationResult.error(
        'Network error or unexpected failure: $e',
        ValidationErrorType.networkError,
      );
    } finally {
      client?.dispose();
    }
  }

  /// Validates just the token format (local check).
  ValidationResult _validateTokenFormat(String token) {
    if (token.isEmpty) {
      return const ValidationResult.error(
        'Token cannot be empty',
        ValidationErrorType.invalidToken,
      );
    }

    // Check for valid token prefix
    final hasValidPrefix = _allTokenPrefixes.any(
      (prefix) => token.startsWith(prefix),
    );
    if (!hasValidPrefix) {
      return ValidationResult.error(
        'Token does not appear to be a valid GitHub token. '
        'GitHub tokens start with: ${_personalAccessTokenPrefixes.join(", ")}',
        ValidationErrorType.invalidToken,
      );
    }

    // GitHub tokens should be at least 40 characters
    if (token.length < 40) {
      return const ValidationResult.error(
        'Token is too short. GitHub tokens are typically at least 40 characters long.',
        ValidationErrorType.invalidToken,
      );
    }

    // Check for common mistakes
    if (token.contains(' ')) {
      return const ValidationResult.error(
        'Token contains spaces. Please remove any spaces from your token.',
        ValidationErrorType.invalidToken,
      );
    }

    return const ValidationResult.success();
  }

  /// Validates token expiration date.
  ///
  /// Checks that:
  /// - The date is not in the past (token not already expired)
  /// - The date is reasonable (not too far in the future)
  ///
  /// Note: This is optional validation. If no expiry date is provided,
  /// the token is assumed to have no expiration.
  ValidationResult _validateTokenExpiry(DateTime expiryDate) {
    final now = DateTime.now();

    // Check if token is already expired
    if (expiryDate.isBefore(now)) {
      return const ValidationResult.error(
        'Token expiration date is in the past. The token has already expired.',
        ValidationErrorType.invalidToken,
      );
    }

    // Check if expiry date is suspiciously far in the future (> 2 years)
    // GitHub tokens can be set to never expire, but if a date is provided,
    // it should be reasonable
    final twoYearsFromNow = now.add(const Duration(days: 730));
    if (expiryDate.isAfter(twoYearsFromNow)) {
      return const ValidationResult.error(
        'Token expiration date is more than 2 years in the future. '
        'Please verify the date is correct.',
        ValidationErrorType.invalidToken,
      );
    }

    return const ValidationResult.success();
  }

  /// Validates GitHub username/organization name format.
  ///
  /// Rules from GitHub:
  /// - May only contain alphanumeric characters or hyphens
  /// - Cannot have multiple consecutive hyphens
  /// - Cannot begin or end with a hyphen
  /// - Maximum 39 characters
  bool _isValidGitHubUsername(String username) {
    if (username.isEmpty || username.length > 39) return false;
    if (username.startsWith('-') || username.endsWith('-')) return false;
    if (username.contains('--')) return false;

    return _usernamePattern.hasMatch(username);
  }

  /// Validates repository name format.
  ///
  /// Rules from GitHub:
  /// - Cannot contain spaces
  /// - Maximum 100 characters
  /// - Should only contain alphanumeric, hyphens, underscores, and periods
  bool _isValidRepositoryName(String repoName) {
    if (repoName.isEmpty || repoName.length > 100) return false;
    if (repoName.contains(' ')) return false;

    // Allow alphanumeric, hyphens, underscores, periods
    return _repoNamePattern.hasMatch(repoName);
  }

  /// Validates Git branch name format.
  ///
  /// Rules from Git:
  /// - Cannot contain spaces
  /// - Cannot contain ..
  /// - Cannot contain consecutive slashes
  /// - Cannot end with .lock
  /// - Cannot end with a slash
  bool _isValidBranchName(String branchName) {
    if (branchName.isEmpty) return false;
    if (branchName.contains(' ')) return false;
    if (branchName.contains('..')) return false;
    if (branchName.contains('//')) return false;
    if (branchName.endsWith('.lock')) return false;
    if (branchName.endsWith('/')) return false;
    if (branchName.startsWith('/')) return false;

    // Cannot contain control characters or special Git characters
    return !_invalidBranchCharsPattern.hasMatch(branchName);
  }

  /// Validates notes path format.
  ///
  /// Should be a valid relative path without Windows/Unix invalid characters.
  bool _isValidNotesPath(String path) {
    if (path.isEmpty) return true; // Empty is valid (root)

    // Check for invalid path characters (Windows + Unix)
    if (_invalidPathCharsPattern.hasMatch(path)) return false;

    // Cannot contain ..
    if (path.contains('..')) return false;

    // Cannot start with /
    if (path.startsWith('/')) return false;

    return true;
  }

  /// Gets the token type based on prefix.
  ///
  /// Returns 'personal' for PATs, or 'other' for OAuth/App tokens.
  /// Returns null if prefix is not recognized.
  String? getTokenType(String token) {
    for (final prefix in _personalAccessTokenPrefixes) {
      if (token.startsWith(prefix)) return 'personal';
    }
    for (final prefix in _otherTokenPrefixes) {
      if (token.startsWith(prefix)) return 'other';
    }
    return null;
  }

  /// Checks if the token is a fine-grained PAT based on prefix.
  bool isFineGrainedToken(String token) {
    return token.startsWith('github_pat_');
  }

  /// Checks if the token is a classic PAT based on prefix.
  bool isClassicToken(String token) {
    return token.startsWith('ghp_');
  }
}
