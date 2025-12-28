import 'package:flutter/foundation.dart';
import 'package:pinboard_wizard/src/github/github_credentials_storage.dart';
import 'package:pinboard_wizard/src/github/models/github_notes_config.dart';
import 'package:pinboard_wizard/src/github/models/token_expiry_warning.dart';

/// Service for handling GitHub authentication, token validation, and expiry monitoring
class GitHubAuthService extends ChangeNotifier {
  final GitHubCredentialsStorage _storage;

  TokenExpiryWarning? _currentWarning;
  bool _isAuthenticated = false;

  GitHubAuthService({GitHubCredentialsStorage? storage})
    : _storage = storage ?? GitHubCredentialsStorage();

  /// Current token expiry warning, if any
  TokenExpiryWarning? get currentWarning => _currentWarning;

  /// Whether the user is currently authenticated with valid credentials
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize the auth service and check authentication status
  Future<void> initialize() async {
    await _checkAuthStatus();
    await checkTokenExpiry();
  }

  /// Check if the user has valid GitHub credentials
  Future<void> _checkAuthStatus() async {
    _isAuthenticated = await _storage.isConfigured();
    notifyListeners();
  }

  /// Check if token is expired or expiring soon
  bool isTokenExpiringSoon(GitHubNotesConfig config) {
    if (config.tokenExpiry == null) return false;

    final daysUntilExpiry = config.tokenExpiry!
        .difference(DateTime.now())
        .inDays;
    return daysUntilExpiry <= 7; // Warn 7 days before expiry
  }

  /// Check if token is already expired
  bool isTokenExpired(GitHubNotesConfig config) {
    if (config.tokenExpiry == null) return false;

    return config.tokenExpiry!.isBefore(DateTime.now());
  }

  /// Get the number of days until token expires
  int? getDaysUntilExpiry(GitHubNotesConfig config) {
    if (config.tokenExpiry == null) return null;

    return config.tokenExpiry!.difference(DateTime.now()).inDays;
  }

  /// Check token expiry and update warning state
  /// Call this on app launch and before each sync
  Future<void> checkTokenExpiry() async {
    try {
      final config = await _storage.readConfig();

      if (config == null || !config.isConfigured) {
        _currentWarning = null;
        notifyListeners();
        return;
      }

      if (config.tokenExpiry == null) {
        _currentWarning = null;
        notifyListeners();
        return;
      }

      final daysLeft = config.tokenExpiry!.difference(DateTime.now()).inDays;

      if (daysLeft < 0) {
        // Token is expired
        _currentWarning = TokenExpiryWarning(
          message:
              'Your GitHub token has expired. Please update it in Settings to resume sync.',
          daysRemaining: 0,
          severity: WarningSeverity.high,
        );
        _isAuthenticated = false;
      } else if (daysLeft <= 7) {
        // Token is expiring soon
        _currentWarning = TokenExpiryWarning.fromExpiry(config.tokenExpiry!);
      } else {
        _currentWarning = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking token expiry: $e');
    }
  }

  /// Dismiss the current token warning
  void dismissTokenWarning() {
    _currentWarning = null;
    notifyListeners();
  }

  /// Handle authentication errors from API responses
  /// Returns true if the error was an auth error (401/403)
  Future<bool> handleAuthError(int statusCode, {String? message}) async {
    if (statusCode == 401 || statusCode == 403) {
      _isAuthenticated = false;
      _currentWarning = TokenExpiryWarning(
        message:
            message ??
            'GitHub token expired or invalid. Please update your token in settings.',
        daysRemaining: 0,
        severity: WarningSeverity.high,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Save new GitHub credentials
  Future<void> saveCredentials({
    required GitHubNotesConfig config,
    required String token,
  }) async {
    try {
      await _storage.saveAll(config: config, token: token);
      _isAuthenticated = true;
      await checkTokenExpiry();
      notifyListeners();
    } catch (e) {
      throw GitHubAuthException('Failed to save credentials: $e');
    }
  }

  /// Update just the token (e.g., when renewing)
  Future<void> updateToken(String token, {DateTime? newExpiry}) async {
    try {
      await _storage.saveToken(token);

      if (newExpiry != null) {
        final config = await _storage.readConfig();
        if (config != null) {
          final updatedConfig = config.copyWith(tokenExpiry: newExpiry);
          await _storage.saveConfig(updatedConfig);
        }
      }

      _isAuthenticated = true;
      await checkTokenExpiry();
      notifyListeners();
    } catch (e) {
      throw GitHubAuthException('Failed to update token: $e');
    }
  }

  /// Clear all GitHub credentials
  Future<void> clearCredentials() async {
    try {
      await _storage.clearAll();
      _isAuthenticated = false;
      _currentWarning = null;
      notifyListeners();
    } catch (e) {
      throw GitHubAuthException('Failed to clear credentials: $e');
    }
  }

  /// Get the current configuration
  Future<GitHubNotesConfig?> getConfig() async {
    return await _storage.readConfig();
  }

  /// Get the current token
  Future<String?> getToken() async {
    return await _storage.readToken();
  }
}

/// Exception thrown when GitHub authentication operations fail
class GitHubAuthException implements Exception {
  final String message;

  const GitHubAuthException(this.message);

  @override
  String toString() => 'GitHubAuthException: $message';
}
