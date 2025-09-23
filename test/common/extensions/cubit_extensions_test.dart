import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/common/extensions/cubit_extensions.dart';

// Test cubit for testing purposes
class TestState {
  final String value;
  const TestState(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestState &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class TestCubit extends Cubit<TestState> {
  TestCubit() : super(const TestState('initial'));

  void updateValue(String value) {
    emit(TestState(value));
  }

  void safeUpdateValue(String value) {
    safeEmit(TestState(value));
  }
}

void main() {
  group('CubitX Extension', () {
    late TestCubit cubit;

    setUp(() {
      cubit = TestCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('safeEmit should emit state when cubit is open', () {
      // Arrange
      const newState = TestState('updated');
      final states = <TestState>[];

      // Listen to state changes
      final subscription = cubit.stream.listen(states.add);

      // Act
      cubit.safeEmit(newState);

      // Assert
      expect(cubit.state, equals(newState));

      // Clean up
      subscription.cancel();
    });

    test('safeEmit should not emit state when cubit is closed', () async {
      // Arrange
      const newState = TestState('updated');
      final states = <TestState>[];

      // Listen to state changes
      final subscription = cubit.stream.listen(states.add);

      // Close the cubit first
      await cubit.close();

      // Act - this should not throw an error or emit
      cubit.safeEmit(newState);

      // Assert - state should remain initial since cubit is closed
      expect(cubit.state, equals(const TestState('initial')));

      // Clean up
      subscription.cancel();
    });

    test('regular emit throws error when cubit is closed', () async {
      // Arrange
      await cubit.close();

      // Act & Assert
      expect(
        () => cubit.emit(const TestState('should fail')),
        throwsA(isA<StateError>()),
      );
    });

    test('safeEmit vs regular emit behavior comparison', () {
      // Arrange
      const state2 = TestState('state2');

      // Act - both should work when cubit is open
      cubit.updateValue('state1'); // uses regular emit
      expect(cubit.state.value, equals('state1'));

      cubit.safeUpdateValue('state2'); // uses safeEmit
      expect(cubit.state.value, equals('state2'));

      // Both methods should produce the same result when cubit is open
      expect(cubit.state, equals(state2));
    });

    test('safeEmit handles multiple calls gracefully after close', () async {
      // Arrange
      await cubit.close();

      // Act - multiple safe emits should not cause issues
      cubit.safeEmit(const TestState('test1'));
      cubit.safeEmit(const TestState('test2'));
      cubit.safeEmit(const TestState('test3'));

      // Assert - no exceptions should be thrown and state remains initial
      expect(cubit.state, equals(const TestState('initial')));
    });

    test('isClosed property works correctly with safeEmit', () {
      // Initially cubit should not be closed
      expect(cubit.isClosed, isFalse);

      // safeEmit should work
      cubit.safeEmit(const TestState('working'));
      expect(cubit.state.value, equals('working'));

      // After closing
      cubit.close();
      expect(cubit.isClosed, isTrue);

      // safeEmit should not update state
      cubit.safeEmit(const TestState('should not work'));
      expect(cubit.state.value, equals('working')); // Still the previous value
    });

    test(
      'safeEmit prevents "Cannot emit new states after calling close" error',
      () async {
        // Arrange
        bool errorThrown = false;
        String? errorMessage;

        // Close the cubit
        await cubit.close();

        // Act & Assert - safeEmit should not throw any error
        try {
          cubit.safeEmit(const TestState('after close'));
        } catch (e) {
          errorThrown = true;
          errorMessage = e.toString();
        }

        // Assert no error was thrown
        expect(
          errorThrown,
          isFalse,
          reason: 'safeEmit should not throw error: $errorMessage',
        );

        // Compare with regular emit which should throw
        expect(
          () => cubit.emit(const TestState('should fail')),
          throwsA(
            predicate(
              (e) => e.toString().contains(
                'Cannot emit new states after calling close',
              ),
            ),
          ),
        );
      },
    );
  });
}
