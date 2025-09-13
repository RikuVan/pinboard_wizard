import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';

abstract interface class SecretStorage {
  Future<Credentials?> read();

  Future<void> save(Credentials credentials);

  Future<void> clear();
}
