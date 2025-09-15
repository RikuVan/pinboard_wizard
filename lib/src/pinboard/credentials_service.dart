import 'package:flutter/foundation.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/flutter_secure_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

class CredentialsService {
  final SecretStorage _storage;
  // Emits true when a valid API key is present, false otherwise
  final ValueNotifier<bool> isAuthenticatedNotifier = ValueNotifier(false);

  CredentialsService({SecretStorage? storage})
    : _storage = storage ?? FlutterSecureSecretsStorage() {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final creds = await _storage.read();
      final hasValid = creds != null && isValidApiKey(creds.apiKey);
      isAuthenticatedNotifier.value = hasValid;
    } catch (_) {
      isAuthenticatedNotifier.value = false;
    }
  }

  /// Get stored credentials from macOS keychain
  Future<Credentials?> getCredentials() async {
    try {
      return await _storage.read();
    } catch (e) {
      throw CredentialsServiceException('Failed to retrieve credentials: $e');
    }
  }

  /// Save credentials to macOS keychain
  Future<void> saveCredentials(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw CredentialsServiceException('API key cannot be empty');
    }

    final credentials = Credentials(apiKey: apiKey.trim());

    try {
      await _storage.save(credentials);
      isAuthenticatedNotifier.value = true;
    } catch (e) {
      throw CredentialsServiceException('Failed to save credentials: $e');
    }
  }

  /// Remove credentials from macOS keychain
  Future<void> clearCredentials() async {
    try {
      await _storage.clear();
      isAuthenticatedNotifier.value = false;
    } catch (e) {
      throw CredentialsServiceException('Failed to clear credentials: $e');
    }
  }

  /// Check if credentials are stored in keychain
  Future<bool> hasCredentials() async {
    try {
      final storage = _storage as FlutterSecureSecretsStorage;
      return await storage.hasCredentials();
    } catch (e) {
      // Fallback: try to read credentials
      final credentials = await getCredentials();
      return credentials != null;
    }
  }

  bool isValidApiKey(String apiKey) {
    // Pinboard API keys are typically in format: username:hexstring
    final regex = RegExp(r'^[a-zA-Z0-9_-]+:[a-fA-F0-9]+$');
    return regex.hasMatch(apiKey.trim());
  }

  String? getUsernameFromApiKey(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return null;

    final parts = apiKey.split(':');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return parts[0];
    }
    return null;
  }

  Future<bool> isAuthenticated() async {
    try {
      final credentials = await getCredentials();
      return credentials != null && isValidApiKey(credentials.apiKey);
    } catch (e) {
      return false;
    }
  }
}

class CredentialsServiceException implements Exception {
  final String message;

  const CredentialsServiceException(this.message);

  @override
  String toString() => 'CredentialsServiceException: $message';
}
