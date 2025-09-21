import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

void main() {
  group('Post', () {
    const basePostData = {
      'href': 'https://example.com',
      'description': 'Test Post',
      'extended': 'Test description',
      'meta': 'test-meta',
      'hash': 'test-hash',
      'time': '2023-01-01T00:00:00Z',
      'shared': 'yes',
      'toread': 'no',
    };

    group('isPinned', () {
      test('returns true for simple pin tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin development',
        });

        expect(post.isPinned, isTrue);
      });

      test('returns true for categorized pin tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work development',
        });

        expect(post.isPinned, isTrue);
      });

      test('returns true for uppercase PIN tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter PIN development',
        });

        expect(post.isPinned, isTrue);
      });

      test('returns false when no pin tags exist', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter development',
        });

        expect(post.isPinned, isFalse);
      });

      test('returns false for empty tags', () {
        final post = Post.fromJson({...basePostData, 'tags': ''});

        expect(post.isPinned, isFalse);
      });

      test(
        'returns false for tags containing pin as substring but not pin tag',
        () {
          final post = Post.fromJson({
            ...basePostData,
            'tags': 'pinning spinner',
          });

          expect(post.isPinned, isFalse);
        },
      );
    });

    group('pinCategory', () {
      test('returns null for simple pin tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin development',
        });

        expect(post.pinCategory, isNull);
      });

      test('returns category for single word category', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work development',
        });

        expect(post.pinCategory, equals('Work'));
      });

      test('returns formatted category for hyphenated category', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work-projects development',
        });

        expect(post.pinCategory, equals('Work Projects'));
      });

      test('returns formatted category for multiple hyphens', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work-in-progress development',
        });

        expect(post.pinCategory, equals('Work In Progress'));
      });

      test('handles uppercase category names', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:WORK-STUFF development',
        });

        expect(post.pinCategory, equals('Work Stuff'));
      });

      test('returns null when no pin tags exist', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter development',
        });

        expect(post.pinCategory, isNull);
      });

      test('prefers categorized pin over simple pin', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin pin:work development',
        });

        expect(post.pinCategory, equals('Work'));
      });

      test('handles empty category after colon', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin: development',
        });

        expect(post.pinCategory, equals(''));
      });

      test('handles malformed pin category tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work: development',
        });

        expect(post.pinCategory, equals('Work'));
      });
    });

    group('pinTags', () {
      test('returns simple pin tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin development',
        });

        expect(post.pinTags, equals(['pin']));
      });

      test('returns categorized pin tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work development',
        });

        expect(post.pinTags, equals(['pin:work']));
      });

      test('returns multiple pin tags', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin pin:work development',
        });

        expect(post.pinTags, containsAll(['pin', 'pin:work']));
        expect(post.pinTags.length, equals(2));
      });

      test('returns empty list when no pin tags exist', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter development',
        });

        expect(post.pinTags, isEmpty);
      });

      test('filters out non-pin tags that contain pin', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work pinning spinner development',
        });

        expect(post.pinTags, equals(['pin:work']));
      });
    });

    group('tagList', () {
      test('splits tags correctly', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work development',
        });

        expect(post.tagList, equals(['flutter', 'pin:work', 'development']));
      });

      test('handles empty tags', () {
        final post = Post.fromJson({...basePostData, 'tags': ''});

        expect(post.tagList, isEmpty);
      });

      test('handles whitespace-only tags', () {
        final post = Post.fromJson({...basePostData, 'tags': '   '});

        expect(post.tagList, isEmpty);
      });

      test('filters out empty tag segments', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter  pin:work   development',
        });

        expect(post.tagList, equals(['flutter', 'pin:work', 'development']));
      });
    });

    group('hasTag', () {
      test('returns true for existing tag (case-insensitive)', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work development',
        });

        expect(post.hasTag('flutter'), isTrue);
        expect(post.hasTag('Flutter'), isTrue);
        expect(post.hasTag('FLUTTER'), isTrue);
        expect(post.hasTag('pin:work'), isTrue);
        expect(post.hasTag('PIN:WORK'), isTrue);
      });

      test('returns false for non-existing tag', () {
        final post = Post.fromJson({
          ...basePostData,
          'tags': 'flutter pin:work development',
        });

        expect(post.hasTag('javascript'), isFalse);
        expect(post.hasTag('pin'), isFalse); // pin:work is different from pin
      });
    });
  });
}
