import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

void main() {
  group('Pin Functionality Integration Tests', () {
    group('Pin Detection', () {
      test('detects simple pin tag', () {
        final post = _createPost(tags: 'flutter pin development');

        expect(post.isPinned, isTrue);
        expect(post.pinCategory, isNull);
        expect(post.pinTags, equals(['pin']));
      });

      test('detects categorized pin tag', () {
        final post = _createPost(tags: 'flutter pin:work development');

        expect(post.isPinned, isTrue);
        expect(post.pinCategory, equals('Work'));
        expect(post.pinTags, equals(['pin:work']));
      });

      test('detects multiple pin tags', () {
        final post = _createPost(tags: 'flutter pin pin:work development');

        expect(post.isPinned, isTrue);
        expect(post.pinCategory, equals('Work')); // Prefers categorized
        expect(post.pinTags, containsAll(['pin', 'pin:work']));
      });

      test('ignores non-pin tags that contain "pin"', () {
        final post = _createPost(tags: 'flutter pinning spinner development');

        expect(post.isPinned, isFalse);
        expect(post.pinCategory, isNull);
        expect(post.pinTags, isEmpty);
      });
    });

    group('Category Parsing', () {
      test('handles single word categories', () {
        expect(_createPost(tags: 'pin:work').pinCategory, equals('Work'));
        expect(
          _createPost(tags: 'pin:personal').pinCategory,
          equals('Personal'),
        );
        expect(_createPost(tags: 'pin:reading').pinCategory, equals('Reading'));
      });

      test('handles hyphenated categories', () {
        expect(
          _createPost(tags: 'pin:work-projects').pinCategory,
          equals('Work Projects'),
        );
        expect(
          _createPost(tags: 'pin:reading-list').pinCategory,
          equals('Reading List'),
        );
        expect(
          _createPost(tags: 'pin:side-hustle').pinCategory,
          equals('Side Hustle'),
        );
      });

      test('handles complex hyphenated categories', () {
        expect(
          _createPost(tags: 'pin:work-in-progress').pinCategory,
          equals('Work In Progress'),
        );
        expect(
          _createPost(tags: 'pin:ai-ml-resources').pinCategory,
          equals('Ai Ml Resources'),
        );
      });

      test('handles case variations', () {
        expect(_createPost(tags: 'pin:WORK').pinCategory, equals('Work'));
        expect(
          _createPost(tags: 'pin:Work-Projects').pinCategory,
          equals('Work Projects'),
        );
        expect(
          _createPost(tags: 'pin:work-PROJECTS').pinCategory,
          equals('Work Projects'),
        );
      });

      test('handles edge cases', () {
        expect(_createPost(tags: 'pin:').pinCategory, equals(''));
        expect(_createPost(tags: 'pin:a').pinCategory, equals('A'));
        expect(_createPost(tags: 'pin:-').pinCategory, equals(' '));
      });
    });

    group('Pin Removal Logic', () {
      test('removes simple pin tag', () {
        final post = _createPost(tags: 'flutter pin development');
        final updatedTags = _removePinTags(post.tagList);

        expect(updatedTags, equals(['flutter', 'development']));
      });

      test('removes categorized pin tag', () {
        final post = _createPost(tags: 'flutter pin:work development');
        final updatedTags = _removePinTags(post.tagList);

        expect(updatedTags, equals(['flutter', 'development']));
      });

      test('removes multiple pin tags', () {
        final post = _createPost(
          tags: 'flutter pin pin:work pin:personal development',
        );
        final updatedTags = _removePinTags(post.tagList);

        expect(updatedTags, equals(['flutter', 'development']));
      });

      test('preserves non-pin tags containing "pin"', () {
        final post = _createPost(
          tags: 'flutter pin pinning spinner development',
        );
        final updatedTags = _removePinTags(post.tagList);

        expect(
          updatedTags,
          equals(['flutter', 'pinning', 'spinner', 'development']),
        );
      });

      test('handles case-insensitive pin removal', () {
        final post = _createPost(tags: 'flutter PIN pin:WORK development');
        final updatedTags = _removePinTags(post.tagList);

        expect(updatedTags, equals(['flutter', 'development']));
      });

      test('handles empty result when only pin tags exist', () {
        final post = _createPost(tags: 'pin pin:work pin:personal');
        final updatedTags = _removePinTags(post.tagList);

        expect(updatedTags, isEmpty);
      });
    });

    group('Pin Update Logic', () {
      test('replaces simple pin with categorized pin', () {
        final post = _createPost(tags: 'flutter pin development');
        final updatedTags = _updatePinTag(post.tagList, 'pin:work');

        expect(updatedTags, equals(['flutter', 'development', 'pin:work']));
      });

      test('replaces categorized pin with different category', () {
        final post = _createPost(tags: 'flutter pin:personal development');
        final updatedTags = _updatePinTag(post.tagList, 'pin:work');

        expect(updatedTags, equals(['flutter', 'development', 'pin:work']));
      });

      test('replaces categorized pin with simple pin', () {
        final post = _createPost(tags: 'flutter pin:work development');
        final updatedTags = _updatePinTag(post.tagList, 'pin');

        expect(updatedTags, equals(['flutter', 'development', 'pin']));
      });

      test('replaces multiple pin tags with single new pin tag', () {
        final post = _createPost(
          tags: 'flutter pin pin:work pin:personal development',
        );
        final updatedTags = _updatePinTag(post.tagList, 'pin:reading');

        expect(updatedTags, equals(['flutter', 'development', 'pin:reading']));
      });
    });

    group('Real-world Scenarios', () {
      test('workflow: pin -> categorize -> recategorize -> unpin', () {
        var post = _createPost(tags: 'flutter development tutorial');

        // Initial state: not pinned
        expect(post.isPinned, isFalse);

        // Pin with general category
        var tags = _updatePinTag(post.tagList, 'pin');
        post = post.copyWith(tags: tags.join(' '));
        expect(post.isPinned, isTrue);
        expect(post.pinCategory, isNull);

        // Categorize as work
        tags = _updatePinTag(post.tagList, 'pin:work');
        post = post.copyWith(tags: tags.join(' '));
        expect(post.isPinned, isTrue);
        expect(post.pinCategory, equals('Work'));

        // Recategorize as learning
        tags = _updatePinTag(post.tagList, 'pin:learning-resources');
        post = post.copyWith(tags: tags.join(' '));
        expect(post.isPinned, isTrue);
        expect(post.pinCategory, equals('Learning Resources'));

        // Unpin entirely
        tags = _removePinTags(post.tagList);
        post = post.copyWith(tags: tags.join(' '));
        expect(post.isPinned, isFalse);
        expect(post.pinCategory, isNull);
        expect(post.tagList, equals(['flutter', 'development', 'tutorial']));
      });

      test('handles complex tag combinations', () {
        final post = _createPost(
          tags:
              'flutter pin:work-tools development spinning pinning tutorial pin:backup',
        );

        expect(post.isPinned, isTrue);
        expect(
          post.pinCategory,
          equals('Work Tools'),
        ); // First categorized pin wins
        expect(post.pinTags, equals(['pin:work-tools', 'pin:backup']));

        // Remove all pins but keep "pinning" and "spinning"
        final updatedTags = _removePinTags(post.tagList);
        expect(
          updatedTags,
          equals(['flutter', 'development', 'spinning', 'pinning', 'tutorial']),
        );
      });
    });
  });
}

// Helper function to create test posts
Post _createPost({required String tags}) {
  return Post(
    href: 'https://example.com',
    description: 'Test Post',
    extended: 'Test description',
    meta: 'test-meta',
    hash: 'test-hash',
    time: DateTime(2023, 1, 1),
    shared: true,
    toread: false,
    tags: tags,
  );
}

// Helper function to simulate pin tag removal logic
List<String> _removePinTags(List<String> tags) {
  return tags.where((tag) {
    final lowerTag = tag.toLowerCase();
    return !(lowerTag == 'pin' || lowerTag.startsWith('pin:'));
  }).toList();
}

// Helper function to simulate pin tag update logic
List<String> _updatePinTag(List<String> currentTags, String newPinTag) {
  final tagsWithoutPin = _removePinTags(currentTags);
  return [...tagsWithoutPin, newPinTag];
}
