import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/notes/services/note_filename_service.dart';

void main() {
  group('NoteFilenameService', () {
    late NoteFilenameService service;

    setUp(() {
      service = NoteFilenameService();
    });

    group('generateFilename', () {
      test('converts title to lowercase', () {
        final filename = service.generateFilename('My Flutter Tips');

        expect(filename, contains('my-flutter-tips'));
      });

      test('replaces spaces with hyphens', () {
        final filename = service.generateFilename('Multiple Word Title');

        expect(filename, contains('multiple-word-title'));
      });

      test('removes special characters', () {
        final filename = service.generateFilename('Title!@#\$%^&*()');

        expect(filename, contains('title'));
        expect(filename, isNot(contains('!')));
        expect(filename, isNot(contains('@')));
        expect(filename, isNot(contains('#')));
      });

      test('removes multiple consecutive hyphens', () {
        final filename = service.generateFilename('Title   With   Spaces');

        expect(filename, isNot(contains('---')));
        expect(filename, isNot(contains('--')));
      });

      test('trims hyphens from start and end', () {
        final filename = service.generateFilename('  Title  ');

        expect(filename, isNot(startsWith('-')));
        expect(filename, isNot(endsWith('-.md')));
      });

      test('limits length to 50 characters before timestamp', () {
        final longTitle = 'a' * 100;
        final filename = service.generateFilename(longTitle);

        // Extract the part before the timestamp
        final parts = filename.split('-');
        final beforeTimestamp = parts.sublist(0, parts.length - 1).join('-');

        expect(beforeTimestamp.length, lessThanOrEqualTo(50));
      });

      test('handles empty title by using "untitled"', () {
        final filename = service.generateFilename('');

        expect(filename, contains('untitled'));
      });

      test('handles title with only special characters', () {
        final filename = service.generateFilename('!@#\$%^&*()');

        expect(filename, contains('untitled'));
      });

      test('adds timestamp for uniqueness', () async {
        final filename1 = service.generateFilename('Same Title');

        // Add small delay to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 2));

        final filename2 = service.generateFilename('Same Title');

        // Filenames should be different due to timestamp
        expect(filename1, isNot(equals(filename2)));
      });

      test('adds .md extension', () {
        final filename = service.generateFilename('Test Note');

        expect(filename, endsWith('.md'));
      });

      test('keeps alphanumeric characters', () {
        final filename = service.generateFilename('Note123');

        expect(filename, contains('note123'));
      });

      test('handles unicode characters by removing them', () {
        final filename = service.generateFilename('测试 Test 🎉');

        expect(filename, contains('test'));
        expect(filename, isNot(contains('测试')));
        expect(filename, isNot(contains('🎉')));
      });

      test('handles mixed case properly', () {
        final filename = service.generateFilename('CamelCaseTitle');

        expect(filename, contains('camelcasetitle'));
      });

      test('produces valid filename format', () {
        final filename = service.generateFilename('Valid Title');

        // Should match pattern: word-word-timestamp.md
        final pattern = RegExp(r'^[a-z0-9-]+-\d{13}\.md$');
        expect(filename, matches(pattern));
      });

      test('handles title with hyphens', () {
        final filename = service.generateFilename('Pre-existing-hyphens');

        expect(filename, contains('pre-existing-hyphens'));
      });

      test('handles title with numbers', () {
        final filename = service.generateFilename('2024 Plans');

        expect(filename, contains('2024-plans'));
      });

      test('multiple spaces become single hyphen', () {
        final filename = service.generateFilename(
          'Title     With     Many     Spaces',
        );

        expect(filename, isNot(contains('-----')));
      });
    });

    group('extractTitle', () {
      test('extracts H1 heading from markdown', () {
        final markdown = '# My Note Title\n\nSome content...';
        final title = service.extractTitle(markdown, 'my-note-123.md');

        expect(title, equals('My Note Title'));
      });

      test('trims whitespace from H1 heading', () {
        final markdown = '#   Spaced Title   \n\nContent...';
        final title = service.extractTitle(markdown, 'note.md');

        expect(title, equals('Spaced Title'));
      });

      test('uses first H1 heading when multiple exist', () {
        final markdown = '# First Title\n\nContent\n\n# Second Title';
        final title = service.extractTitle(markdown, 'note.md');

        expect(title, equals('First Title'));
      });

      test('falls back to filename when no H1 heading', () {
        final markdown = 'Just some content without heading';
        final title = service.extractTitle(
          markdown,
          'my-note-1234567890123.md',
        );

        expect(title, equals('my note'));
      });

      test('removes timestamp from filename fallback', () {
        final markdown = 'Content without H1';
        final title = service.extractTitle(
          markdown,
          'test-note-1234567890123.md',
        );

        expect(title, equals('test note'));
        expect(title, isNot(contains('1234567890123')));
      });

      test('converts hyphens to spaces in filename fallback', () {
        final markdown = 'Content';
        final title = service.extractTitle(
          markdown,
          'multi-word-title-1234567890123.md',
        );

        expect(title, equals('multi word title'));
      });

      test('handles empty markdown with filename fallback', () {
        final markdown = '';
        final title = service.extractTitle(
          markdown,
          'fallback-1234567890123.md',
        );

        expect(title, equals('fallback'));
      });

      test('handles markdown with H2 but no H1', () {
        final markdown = '## Subheading\n\nContent';
        final title = service.extractTitle(
          markdown,
          'filename-1234567890123.md',
        );

        expect(title, equals('filename'));
      });

      test('handles H1 at end of content', () {
        final markdown = 'Some content\n\n# Title at End';
        final title = service.extractTitle(markdown, 'note.md');

        expect(title, equals('Title at End'));
      });

      test('handles H1 with special characters', () {
        final markdown = '# Title with 🎉 Emoji!';
        final title = service.extractTitle(markdown, 'note.md');

        expect(title, equals('Title with 🎉 Emoji!'));
      });

      test('handles markdown with only H1', () {
        final markdown = '# Lone Title';
        final title = service.extractTitle(markdown, 'note.md');

        expect(title, equals('Lone Title'));
      });

      test('handles filename without timestamp', () {
        final markdown = 'Content';
        final title = service.extractTitle(markdown, 'simple.md');

        expect(title, equals('simple'));
      });

      test('handles H1 with inline code', () {
        final markdown = '# Title with `code`';
        final title = service.extractTitle(markdown, 'note.md');

        expect(title, equals('Title with `code`'));
      });

      test('handles multiline content before H1', () {
        final markdown = 'Line 1\nLine 2\nLine 3\n\n# Actual Title\n\nContent';
        final title = service.extractTitle(markdown, 'note.md');

        expect(title, equals('Actual Title'));
      });
    });

    group('isValidFilename', () {
      test('accepts normal markdown filename', () {
        expect(service.isValidFilename('my-note.md'), isTrue);
      });

      test('rejects hidden files starting with dot', () {
        expect(service.isValidFilename('.hidden.md'), isFalse);
      });

      test('rejects Windows reserved name: con', () {
        expect(service.isValidFilename('con.md'), isFalse);
      });

      test('rejects Windows reserved name: prn', () {
        expect(service.isValidFilename('prn.md'), isFalse);
      });

      test('rejects Windows reserved name: aux', () {
        expect(service.isValidFilename('aux.md'), isFalse);
      });

      test('rejects Windows reserved name: nul', () {
        expect(service.isValidFilename('nul.md'), isFalse);
      });

      test('rejects Windows reserved name: com1', () {
        expect(service.isValidFilename('com1.md'), isFalse);
      });

      test('rejects Windows reserved name: lpt1', () {
        expect(service.isValidFilename('lpt1.md'), isFalse);
      });

      test('rejects reserved name regardless of case', () {
        expect(service.isValidFilename('CON.md'), isFalse);
        expect(service.isValidFilename('Con.md'), isFalse);
      });

      test('accepts filename containing reserved word', () {
        expect(service.isValidFilename('console.md'), isTrue);
        expect(service.isValidFilename('print.md'), isTrue);
      });

      test('accepts filename with numbers', () {
        expect(service.isValidFilename('note-123.md'), isTrue);
      });

      test('accepts filename with hyphens', () {
        expect(service.isValidFilename('my-test-note.md'), isTrue);
      });
    });

    group('hasMarkdownExtension', () {
      test('returns true for .md extension', () {
        expect(service.hasMarkdownExtension('note.md'), isTrue);
      });

      test('returns true for .markdown extension', () {
        expect(service.hasMarkdownExtension('note.markdown'), isTrue);
      });

      test('returns false for .txt extension', () {
        expect(service.hasMarkdownExtension('note.txt'), isFalse);
      });

      test('returns false for no extension', () {
        expect(service.hasMarkdownExtension('note'), isFalse);
      });

      test('returns false for .mdx extension', () {
        expect(service.hasMarkdownExtension('note.mdx'), isFalse);
      });

      test('is case sensitive', () {
        expect(service.hasMarkdownExtension('note.MD'), isFalse);
        expect(service.hasMarkdownExtension('note.Md'), isFalse);
      });
    });

    group('sanitizeFilename', () {
      test('removes .md extension before processing', () {
        final sanitized = service.sanitizeFilename('test.md');

        expect(sanitized, equals('test.md'));
      });

      test('removes .markdown extension before processing', () {
        final sanitized = service.sanitizeFilename('test.markdown');

        expect(sanitized, equals('test.md'));
      });

      test('converts to lowercase', () {
        final sanitized = service.sanitizeFilename('CamelCase');

        expect(sanitized, equals('camelcase.md'));
      });

      test('replaces spaces with hyphens', () {
        final sanitized = service.sanitizeFilename('multiple words');

        expect(sanitized, equals('multiple-words.md'));
      });

      test('removes special characters', () {
        final sanitized = service.sanitizeFilename('special!@#chars');

        expect(sanitized, equals('specialchars.md'));
      });

      test('removes multiple consecutive hyphens', () {
        final sanitized = service.sanitizeFilename('word---word');

        expect(sanitized, equals('word-word.md'));
      });

      test('trims hyphens from start and end', () {
        final sanitized = service.sanitizeFilename('-trimmed-');

        expect(sanitized, equals('trimmed.md'));
      });

      test('uses untitled for empty result', () {
        final sanitized = service.sanitizeFilename('!@#\$');

        expect(sanitized, equals('untitled.md'));
      });

      test('does not add timestamp', () {
        final sanitized = service.sanitizeFilename('test');

        expect(sanitized, isNot(contains(RegExp(r'\d{13}'))));
      });

      test('preserves existing hyphens', () {
        final sanitized = service.sanitizeFilename('pre-existing-hyphens');

        expect(sanitized, equals('pre-existing-hyphens.md'));
      });

      test('handles filename that already has extension', () {
        final sanitized = service.sanitizeFilename('already.md');

        // Should not have double extension
        expect(sanitized, equals('already.md'));
        expect(sanitized, isNot(contains('.md.md')));
      });

      test('keeps alphanumeric characters', () {
        final sanitized = service.sanitizeFilename('abc123');

        expect(sanitized, equals('abc123.md'));
      });
    });

    group('Integration Tests', () {
      test('generate and validate workflow', () {
        final generated = service.generateFilename('My Test Note');

        expect(service.isValidFilename(generated), isTrue);
        expect(service.hasMarkdownExtension(generated), isTrue);
      });

      test('generate and extract title workflow', () {
        final filename = service.generateFilename('Original Title');
        final markdown = '# Actual Title\n\nContent';

        final extractedTitle = service.extractTitle(markdown, filename);

        expect(extractedTitle, equals('Actual Title'));
      });

      test('sanitize produces valid filename', () {
        final sanitized = service.sanitizeFilename('Random!@# Input');

        expect(service.isValidFilename(sanitized), isTrue);
        expect(service.hasMarkdownExtension(sanitized), isTrue);
      });

      test('multiple generates produce unique filenames', () async {
        final filenames = <String>{};

        for (var i = 0; i < 10; i++) {
          final filename = service.generateFilename('Test Note');
          filenames.add(filename);

          // Add small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 2));
        }

        // All should be unique due to timestamps
        expect(filenames.length, equals(10));
      });

      test('extract title fallback matches sanitize output', () {
        final originalTitle = 'Multi Word Title';
        final filename = service.generateFilename(originalTitle);
        final markdown = 'No H1 heading';

        final extracted = service.extractTitle(markdown, filename);

        // Should get cleaned version of original title
        expect(extracted, contains('multi'));
        expect(extracted, contains('word'));
        expect(extracted, contains('title'));
      });
    });

    group('Edge Cases', () {
      test('handles very long title gracefully', () {
        final longTitle = 'a' * 1000;
        final filename = service.generateFilename(longTitle);

        expect(filename.length, lessThan(100)); // Should be truncated
        expect(service.isValidFilename(filename), isTrue);
      });

      test('handles title with only whitespace', () {
        final filename = service.generateFilename('     ');

        expect(filename, contains('untitled'));
      });

      test('handles markdown with malformed H1', () {
        final markdown = '#Missing space after hash';
        final title = service.extractTitle(markdown, 'fallback.md');

        // Should fall back to filename
        expect(title, equals('fallback'));
      });

      test('handles filename without extension in extractTitle', () {
        final markdown = 'Content';
        final title = service.extractTitle(markdown, 'noextension');

        expect(title, equals('noextension'));
      });

      test('handles empty filename in extractTitle', () {
        final markdown = 'Content';
        final title = service.extractTitle(markdown, '');

        expect(title, isEmpty);
      });
    });
  });
}
