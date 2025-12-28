import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pinboard_wizard/src/notes/services/file_service.dart';

void main() {
  group('FileService', () {
    late Directory tempDir;
    late FileService fileService;

    setUp(() async {
      // Create a temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('file_service_test_');
      fileService = FileService(tempDir);
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('readFile', () {
      test('reads existing file content', () async {
        final testPath = path.join(tempDir.path, 'test.md');
        final testFile = File(testPath);
        await testFile.writeAsString('# Test Content');

        final content = await fileService.readFile(testPath);

        expect(content, equals('# Test Content'));
      });

      test('throws FileNotFoundException for non-existent file', () async {
        final testPath = path.join(tempDir.path, 'nonexistent.md');

        expect(
          () => fileService.readFile(testPath),
          throwsA(isA<FileNotFoundException>()),
        );
      });

      test('reads empty file', () async {
        final testPath = path.join(tempDir.path, 'empty.md');
        final testFile = File(testPath);
        await testFile.writeAsString('');

        final content = await fileService.readFile(testPath);

        expect(content, isEmpty);
      });

      test('reads file with unicode content', () async {
        final testPath = path.join(tempDir.path, 'unicode.md');
        final testFile = File(testPath);
        await testFile.writeAsString('# 测试 🎉 Тест');

        final content = await fileService.readFile(testPath);

        expect(content, equals('# 测试 🎉 Тест'));
      });

      test('reads file with newlines', () async {
        final testPath = path.join(tempDir.path, 'newlines.md');
        final testFile = File(testPath);
        await testFile.writeAsString('Line 1\nLine 2\nLine 3');

        final content = await fileService.readFile(testPath);

        expect(content, equals('Line 1\nLine 2\nLine 3'));
      });
    });

    group('writeFile', () {
      test('writes content to new file', () async {
        final testPath = path.join(tempDir.path, 'new.md');

        await fileService.writeFile(testPath, '# New Content');

        final file = File(testPath);
        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), equals('# New Content'));
      });

      test('overwrites existing file content', () async {
        final testPath = path.join(tempDir.path, 'existing.md');
        final testFile = File(testPath);
        await testFile.writeAsString('Old content');

        await fileService.writeFile(testPath, 'New content');

        expect(await testFile.readAsString(), equals('New content'));
      });

      test('creates parent directories if they do not exist', () async {
        final testPath = path.join(tempDir.path, 'subdir', 'nested', 'file.md');

        await fileService.writeFile(testPath, 'Content');

        final file = File(testPath);
        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), equals('Content'));
      });

      test('writes empty content', () async {
        final testPath = path.join(tempDir.path, 'empty.md');

        await fileService.writeFile(testPath, '');

        final file = File(testPath);
        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), isEmpty);
      });

      test('writes unicode content', () async {
        final testPath = path.join(tempDir.path, 'unicode.md');

        await fileService.writeFile(testPath, '# 测试 🎉 Тест');

        final file = File(testPath);
        expect(await file.readAsString(), equals('# 测试 🎉 Тест'));
      });

      test('writes content with newlines', () async {
        final testPath = path.join(tempDir.path, 'newlines.md');

        await fileService.writeFile(testPath, 'Line 1\nLine 2\nLine 3');

        final file = File(testPath);
        expect(await file.readAsString(), equals('Line 1\nLine 2\nLine 3'));
      });
    });

    group('deleteFile', () {
      test('deletes existing file', () async {
        final testPath = path.join(tempDir.path, 'to-delete.md');
        final testFile = File(testPath);
        await testFile.writeAsString('Content');

        await fileService.deleteFile(testPath);

        expect(await testFile.exists(), isFalse);
      });

      test('does nothing if file does not exist (idempotent)', () async {
        final testPath = path.join(tempDir.path, 'nonexistent.md');

        // Should not throw
        await fileService.deleteFile(testPath);

        expect(await File(testPath).exists(), isFalse);
      });

      test('can delete multiple times (idempotent)', () async {
        final testPath = path.join(tempDir.path, 'to-delete.md');
        final testFile = File(testPath);
        await testFile.writeAsString('Content');

        await fileService.deleteFile(testPath);
        await fileService.deleteFile(testPath);
        await fileService.deleteFile(testPath);

        expect(await testFile.exists(), isFalse);
      });
    });

    group('getLocalPath', () {
      test('extracts filename from repository path', () {
        final localPath = fileService.getLocalPath('notes/my-note.md');

        expect(localPath, equals(path.join(tempDir.path, 'my-note.md')));
      });

      test('handles simple filename', () {
        final localPath = fileService.getLocalPath('simple.md');

        expect(localPath, equals(path.join(tempDir.path, 'simple.md')));
      });

      test('handles nested paths', () {
        final localPath = fileService.getLocalPath('folder/subfolder/file.md');

        expect(localPath, equals(path.join(tempDir.path, 'file.md')));
      });

      test('handles paths with multiple extensions', () {
        final localPath = fileService.getLocalPath('notes/file.backup.md');

        expect(localPath, equals(path.join(tempDir.path, 'file.backup.md')));
      });
    });

    group('listLocalFiles', () {
      test('returns empty list when directory does not exist', () async {
        final nonexistentDir = Directory(
          path.join(tempDir.path, 'nonexistent'),
        );
        final service = FileService(nonexistentDir);

        final files = await service.listLocalFiles();

        expect(files, isEmpty);
        expect(await nonexistentDir.exists(), isTrue); // Should create it
      });

      test('returns empty list when directory is empty', () async {
        final files = await fileService.listLocalFiles();

        expect(files, isEmpty);
      });

      test('returns only markdown files', () async {
        await File(
          path.join(tempDir.path, 'note1.md'),
        ).writeAsString('Content 1');
        await File(
          path.join(tempDir.path, 'note2.md'),
        ).writeAsString('Content 2');
        await File(path.join(tempDir.path, 'readme.txt')).writeAsString('Text');
        await File(
          path.join(tempDir.path, 'image.png'),
        ).writeAsBytes([0, 1, 2]);

        final files = await fileService.listLocalFiles();

        expect(files, hasLength(2));
        expect(
          files.map((f) => path.basename(f.path)),
          containsAll(['note1.md', 'note2.md']),
        );
      });

      test('ignores subdirectories', () async {
        await File(path.join(tempDir.path, 'root.md')).writeAsString('Root');
        await Directory(path.join(tempDir.path, 'subdir')).create();
        await File(
          path.join(tempDir.path, 'subdir', 'sub.md'),
        ).writeAsString('Sub');

        final files = await fileService.listLocalFiles();

        expect(files, hasLength(1));
        expect(path.basename(files.first.path), equals('root.md'));
      });

      test('handles files with similar extensions', () async {
        await File(
          path.join(tempDir.path, 'note.md'),
        ).writeAsString('Markdown');
        await File(path.join(tempDir.path, 'note.mdx')).writeAsString('MDX');
        await File(
          path.join(tempDir.path, 'note.markdown'),
        ).writeAsString('Markdown alt');

        final files = await fileService.listLocalFiles();

        expect(files, hasLength(1)); // Only .md files
        expect(path.basename(files.first.path), equals('note.md'));
      });
    });

    group('fileExists', () {
      test('returns true for existing file', () async {
        final testPath = path.join(tempDir.path, 'existing.md');
        await File(testPath).writeAsString('Content');

        final exists = await fileService.fileExists(testPath);

        expect(exists, isTrue);
      });

      test('returns false for non-existent file', () async {
        final testPath = path.join(tempDir.path, 'nonexistent.md');

        final exists = await fileService.fileExists(testPath);

        expect(exists, isFalse);
      });

      test('returns false for directory', () async {
        final testPath = path.join(tempDir.path, 'subdir');
        await Directory(testPath).create();

        final exists = await fileService.fileExists(testPath);

        expect(exists, isFalse);
      });
    });

    group('getFileSize', () {
      test('returns correct size for file with content', () async {
        final testPath = path.join(tempDir.path, 'sized.md');
        final content = '# Test\nSome content here';
        await File(testPath).writeAsString(content);

        final size = await fileService.getFileSize(testPath);

        expect(size, equals(content.length));
      });

      test('returns 0 for empty file', () async {
        final testPath = path.join(tempDir.path, 'empty.md');
        await File(testPath).writeAsString('');

        final size = await fileService.getFileSize(testPath);

        expect(size, equals(0));
      });

      test('returns 0 for non-existent file', () async {
        final testPath = path.join(tempDir.path, 'nonexistent.md');

        final size = await fileService.getFileSize(testPath);

        expect(size, equals(0));
      });

      test('returns correct size for unicode content', () async {
        final testPath = path.join(tempDir.path, 'unicode.md');
        final content = '测试 🎉';
        await File(testPath).writeAsString(content);

        final size = await fileService.getFileSize(testPath);

        // Unicode characters take more than one byte
        expect(size, greaterThan(content.length));
      });
    });

    group('ensureDirectoryExists', () {
      test('creates directory if it does not exist', () async {
        final newDir = Directory(path.join(tempDir.path, 'newdir'));
        final service = FileService(newDir);

        await service.ensureDirectoryExists();

        expect(await newDir.exists(), isTrue);
      });

      test('does nothing if directory already exists', () async {
        expect(await tempDir.exists(), isTrue);

        await fileService.ensureDirectoryExists();

        expect(await tempDir.exists(), isTrue);
      });

      test('creates nested directories', () async {
        final nestedDir = Directory(path.join(tempDir.path, 'a', 'b', 'c'));
        final service = FileService(nestedDir);

        await service.ensureDirectoryExists();

        expect(await nestedDir.exists(), isTrue);
      });
    });

    group('Integration Tests', () {
      test('write, read, then delete workflow', () async {
        final testPath = path.join(tempDir.path, 'workflow.md');
        final content = '# Workflow Test\n\nThis is a test.';

        // Write
        await fileService.writeFile(testPath, content);
        expect(await fileService.fileExists(testPath), isTrue);

        // Read
        final readContent = await fileService.readFile(testPath);
        expect(readContent, equals(content));

        // Delete
        await fileService.deleteFile(testPath);
        expect(await fileService.fileExists(testPath), isFalse);
      });

      test('multiple files workflow', () async {
        final paths = [
          path.join(tempDir.path, 'file1.md'),
          path.join(tempDir.path, 'file2.md'),
          path.join(tempDir.path, 'file3.md'),
        ];

        // Write multiple files
        for (var i = 0; i < paths.length; i++) {
          await fileService.writeFile(paths[i], 'Content $i');
        }

        // List files
        final files = await fileService.listLocalFiles();
        expect(files, hasLength(3));

        // Read each file
        for (var i = 0; i < paths.length; i++) {
          final content = await fileService.readFile(paths[i]);
          expect(content, equals('Content $i'));
        }

        // Delete all files
        for (final filePath in paths) {
          await fileService.deleteFile(filePath);
        }

        final filesAfterDelete = await fileService.listLocalFiles();
        expect(filesAfterDelete, isEmpty);
      });
    });
  });

  group('FileNotFoundException', () {
    test('has correct message', () {
      final exception = FileNotFoundException('File not found: test.md');

      expect(exception.toString(), equals('File not found: test.md'));
    });
  });
}
