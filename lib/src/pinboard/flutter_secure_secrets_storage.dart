import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

class FlutterSecureSecretsStorage implements SecretStorage {
  static const String _credentialsKey = 'pinboard_credentials';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  Future<Credentials?> read() async {
    try {
      final credentialsJson = await _secureStorage.read(key: _credentialsKey);

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
      await _secureStorage.write(key: _credentialsKey, value: credentialsJson);
    } catch (e) {
      throw SecureStorageException('Failed to save credentials: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _credentialsKey);
    } catch (e) {
      throw SecureStorageException('Failed to clear credentials: $e');
    }
  }

  Future<bool> hasCredentials() async {
    try {
      final credentialsJson = await _secureStorage.read(key: _credentialsKey);
      return credentialsJson != null && credentialsJson.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw SecureStorageException('Failed to clear all data: $e');
    }
  }

  Future<Map<String, String>> readAll() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      return {};
    }
  }
}

class SecureStorageException implements Exception {
  final String message;

  const SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}
