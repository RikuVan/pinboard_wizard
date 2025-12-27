import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinboard_wizard/src/github/models/github_notes_config.dart';

/// Service for securely storing and retrieving GitHub credentials and configuration
class GitHubCredentialsStorage {
  static const String _configKey = 'github_notes_config';
  static const String _tokenKey = 'github_pat_token';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Read the GitHub notes configuration (without token)
  Future<GitHubNotesConfig?> readConfig() async {
    try {
      final configJson = await _secureStorage.read(key: _configKey);

      if (configJson == null || configJson.isEmpty) {
        return null;
      }

      final Map<String, dynamic> configMap =
          json.decode(configJson) as Map<String, dynamic>;

      return GitHubNotesConfig.fromJson(configMap);
    } catch (e) {
      return null;
    }
  }

  /// Read the Personal Access Token
  Future<String?> readToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Save the GitHub notes configuration (without token)
  Future<void> saveConfig(GitHubNotesConfig config) async {
    try {
      final configJson = json.encode(config.toJson());
      await _secureStorage.write(key: _configKey, value: configJson);
    } catch (e) {
      throw GitHubStorageException('Failed to save configuration: $e');
    }
  }

  /// Save the Personal Access Token
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (e) {
      throw GitHubStorageException('Failed to save token: $e');
    }
  }

  /// Save both config and token together
  Future<void> saveAll({
    required GitHubNotesConfig config,
    required String token,
  }) async {
    try {
      await saveConfig(config);
      await saveToken(token);
    } catch (e) {
      throw GitHubStorageException('Failed to save credentials: $e');
    }
  }

  /// Check if GitHub notes is configured
  Future<bool> isConfigured() async {
    try {
      final config = await readConfig();
      final token = await readToken();
      return config != null &&
          config.isConfigured &&
          token != null &&
          token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear the GitHub notes configuration
  Future<void> clearConfig() async {
    try {
      await _secureStorage.delete(key: _configKey);
    } catch (e) {
      throw GitHubStorageException('Failed to clear configuration: $e');
    }
  }

  /// Clear the Personal Access Token
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (e) {
      throw GitHubStorageException('Failed to clear token: $e');
    }
  }

  /// Clear all GitHub-related data
  Future<void> clearAll() async {
    try {
      await clearConfig();
      await clearToken();
    } catch (e) {
      throw GitHubStorageException('Failed to clear all GitHub data: $e');
    }
  }
}

/// Exception thrown when GitHub storage operations fail
class GitHubStorageException implements Exception {
  final String message;

  const GitHubStorageException(this.message);

  @override
  String toString() => 'GitHubStorageException: $message';
}
