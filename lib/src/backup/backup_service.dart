import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aws_s3_upload_lite/aws_s3_upload_lite.dart';
import 'package:pinboard_wizard/src/backup/models/s3_config.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:intl/intl.dart';

enum BackupStatus { idle, configuring, backingUp, success, error }

class BackupService extends ChangeNotifier {
  static const String _s3ConfigKey = 'backup_s3_config';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  S3Config _s3Config = const S3Config();
  BackupStatus _status = BackupStatus.idle;
  String? _lastError;
  String? _lastBackupMessage;

  S3Config get s3Config => _s3Config;
  BackupStatus get status => _status;
  String? get lastError => _lastError;
  String? get lastBackupMessage => _lastBackupMessage;

  bool get isConfigValid => _s3Config.isValid;
  bool get isBackingUp => _status == BackupStatus.backingUp;
  bool get canBackup => isConfigValid && _status != BackupStatus.backingUp;

  /// Load S3 configuration from secure storage
  Future<void> loadConfiguration() async {
    try {
      final configJson = await _secureStorage.read(key: _s3ConfigKey);
      if (configJson != null && configJson.isNotEmpty) {
        final Map<String, dynamic> configMap = json.decode(configJson);
        _s3Config = S3Config.fromJson(configMap);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load S3 configuration: $e');
    }
  }

  /// Save S3 configuration to secure storage
  Future<void> saveConfiguration(S3Config config) async {
    try {
      _status = BackupStatus.configuring;
      _lastError = null;
      notifyListeners();

      final configJson = json.encode(config.toJson());
      await _secureStorage.write(key: _s3ConfigKey, value: configJson);

      _s3Config = config;
      _status = BackupStatus.idle;
      notifyListeners();
    } catch (e) {
      _status = BackupStatus.error;
      _lastError = 'Failed to save configuration: $e';
      notifyListeners();
      debugPrint('Failed to save S3 configuration: $e');
    }
  }

  /// Validate S3 configuration by attempting a test connection
  Future<bool> validateConfiguration() async {
    if (!_s3Config.isValid) {
      return false;
    }

    try {
      _status = BackupStatus.configuring;
      _lastError = null;
      notifyListeners();

      // Create a test file to validate the connection
      final testContent = json.encode({
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
        'app': 'Pinboard Wizard',
      });

      final testFileName =
          'test_connection_${DateTime.now().millisecondsSinceEpoch}.json';

      await AwsS3.uploadFile(
        accessKey: _s3Config.accessKey,
        secretKey: _s3Config.secretKey,
        file: File.fromRawPath(utf8.encode(testContent)),
        bucket: _s3Config.bucketName,
        region: _s3Config.region,
        destDir: _s3Config.filePath,
        filename: testFileName,
      );

      _status = BackupStatus.idle;
      notifyListeners();

      return true;
    } catch (e) {
      _status = BackupStatus.error;
      _lastError = 'Configuration validation failed: $e';
      notifyListeners();
      debugPrint('S3 configuration validation failed: $e');
      return false;
    }
  }

  /// Backup all bookmarks to S3 as JSON
  Future<bool> backupBookmarks() async {
    if (!canBackup) {
      return false;
    }

    try {
      _status = BackupStatus.backingUp;
      _lastError = null;
      _lastBackupMessage = null;
      notifyListeners();

      // Get the pinboard service
      final pinboardService = locator.get<PinboardService>();

      // Fetch all bookmarks
      final bookmarks = await pinboardService.getAllBookmarks();

      if (bookmarks.isEmpty) {
        _status = BackupStatus.error;
        _lastError = 'No bookmarks found to backup';
        notifyListeners();
        return false;
      }

      // Create backup data
      final backupData = {
        'metadata': {
          'app': 'Pinboard Wizard',
          'version': '1.0.0',
          'backup_date': DateTime.now().toIso8601String(),
          'total_bookmarks': bookmarks.length,
        },
        'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
      };

      // Convert to JSON
      final backupJson = json.encode(backupData);

      // Generate filename with timestamp
      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final fileName = 'pinboard_backup_$timestamp.json';

      // Upload to S3
      await AwsS3.uploadFile(
        accessKey: _s3Config.accessKey,
        secretKey: _s3Config.secretKey,
        file: File.fromRawPath(utf8.encode(backupJson)),
        bucket: _s3Config.bucketName,
        region: _s3Config.region,
        destDir: _s3Config.filePath,
        filename: fileName,
      );

      _status = BackupStatus.success;
      _lastBackupMessage =
          'Successfully backed up ${bookmarks.length} bookmarks to S3';
      notifyListeners();
      return true;
    } catch (e) {
      _status = BackupStatus.error;
      _lastError = 'Backup failed: $e';
      notifyListeners();
      debugPrint('Backup failed: $e');
      return false;
    }
  }

  /// Clear all stored configuration
  Future<void> clearConfiguration() async {
    try {
      await _secureStorage.delete(key: _s3ConfigKey);
      _s3Config = const S3Config();
      _status = BackupStatus.idle;
      _lastError = null;
      _lastBackupMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to clear S3 configuration: $e');
    }
  }

  /// Reset status and error messages
  void resetStatus() {
    _status = BackupStatus.idle;
    _lastError = null;
    _lastBackupMessage = null;
    notifyListeners();
  }
}

class BackupServiceException implements Exception {
  final String message;
  const BackupServiceException(this.message);

  @override
  String toString() => 'BackupServiceException: $message';
}
