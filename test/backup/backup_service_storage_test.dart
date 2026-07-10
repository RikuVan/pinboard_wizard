import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/backup/backup_service.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/common/storage/app_secure_storage.dart';

import '../common/storage/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fake;
  late AppSecureStorage appStorage;
  late BackupService service;

  setUp(() async {
    fake = FakeFlutterSecureStorage();
    appStorage = AppSecureStorage(storage: fake);
    await appStorage.init();
    service = BackupService(storage: appStorage);
  });

  test('saveConfiguration persists under backup_s3_config', () async {
    const config = S3Config(
      accessKey: 'AKIA123',
      secretKey: 'shhh',
      region: 'eu-west-1',
      bucketName: 'my-bucket',
      filePath: 'backups/',
    );

    await service.saveConfiguration(config);

    final stored =
        json.decode(fake.local['backup_s3_config']!) as Map<String, dynamic>;
    expect(stored['accessKey'], 'AKIA123');
    expect(stored['secretKey'], 'shhh');
    expect(service.s3Config, config);
  });

  test('loadConfiguration restores a stored config', () async {
    fake.local['backup_s3_config'] = json.encode(
      const S3Config(
        accessKey: 'AKIA123',
        secretKey: 'shhh',
        region: 'eu-west-1',
        bucketName: 'my-bucket',
      ).toJson(),
    );

    await service.loadConfiguration();
    expect(service.s3Config.accessKey, 'AKIA123');
    expect(service.s3Config.bucketName, 'my-bucket');
  });

  test('clearConfiguration deletes the stored entry', () async {
    fake.local['backup_s3_config'] = json.encode(
      const S3Config(
        accessKey: 'AKIA123',
        secretKey: 'shhh',
        region: 'eu-west-1',
        bucketName: 'my-bucket',
      ).toJson(),
    );

    await service.clearConfiguration();
    expect(fake.local.containsKey('backup_s3_config'), isFalse);
    expect(service.s3Config.isEmpty, isTrue);
  });
}
