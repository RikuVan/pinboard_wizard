import 'dart:convert';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';
import 'package:pinboard_wizard/src/common/storage/credential_keys.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

class FlutterSecureSecretsStorage implements SecretStorage {
  static const String _credentialsKey = CredentialKeys.pinboardCredentials;

  final AppSecureStorage _storage;

  FlutterSecureSecretsStorage({required this._storage});

  @override
  Future<Credentials?> read() async {
    try {
      final credentialsJson = await _storage.read(_credentialsKey);

      if (credentialsJson == null || credentialsJson.isEmpty) {
        return null;
      }

      final Map<String, dynamic> credentialsMap =
          json.decode(credentialsJson) as Map<String, dynamic>;

      return Credentials.fromJson(credentialsMap);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> save(Credentials credentials) async {
    try {
      final credentialsJson = json.encode(credentials.toJson());
      await _storage.write(_credentialsKey, credentialsJson);
    } catch (e) {
      throw SecureStorageException('Failed to save credentials: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(_credentialsKey);
    } catch (e) {
      throw SecureStorageException('Failed to clear credentials: $e');
    }
  }

  Future<bool> hasCredentials() async {
    try {
      final credentialsJson = await _storage.read(_credentialsKey);
      return credentialsJson != null && credentialsJson.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

class SecureStorageException implements Exception {
  final String message;

  const SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}
