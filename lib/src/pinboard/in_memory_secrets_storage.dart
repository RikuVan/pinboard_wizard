import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';
import 'package:pinboard_wizard/src/pinboard/secrets_storage.dart';

/// In-memory implementation of SecretStorage for testing purposes.
/// This storage does not persist data between app restarts.
class InMemorySecretsStorage implements SecretStorage {
  Credentials? _credentials;

  @override
  Future<Credentials?> read() async {
    await Future.delayed(const Duration(milliseconds: 1));
    return _credentials;
  }

  @override
  Future<void> save(Credentials credentials) async {
    await Future.delayed(const Duration(milliseconds: 1));
    _credentials = credentials;
  }

  @override
  Future<void> clear() async {
    await Future.delayed(const Duration(milliseconds: 1));
    _credentials = null;
  }

  Future<bool> hasCredentials() async {
    await Future.delayed(const Duration(milliseconds: 1));
    return _credentials != null;
  }

  Credentials? get credentials => _credentials;

  bool get isEmpty => _credentials == null;

  bool get isNotEmpty => _credentials != null;

  void clearSync() {
    _credentials = null;
  }
}
