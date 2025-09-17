# Test Directory Organization

This document describes the organization and structure of tests in the Pinboard Wizard Flutter application.

## Directory Structure

```
test/
├── README.md                    # This documentation
├── test_helpers.dart           # Shared test utilities and data factories
├── pages/                      # UI page tests
│   └── bookmarks/             # Bookmarks feature tests
│       └── state/             # State management tests
│           └── bookmarks_cubit_test.dart
└── pinboard/                  # Pinboard API and service tests
    ├── credentials_service_test.dart
    ├── pinboard_client_test.dart
    ├── pinboard_client_test.mocks.dart
    ├── pinboard_service_test.dart
    ├── pinboard_service_test.mocks.dart
    └── secrets_storage_test.dart
```

## Test Organization Principles

### 1. Mirror App Structure
Tests are organized to mirror the `lib/src/` directory structure:
- `test/pages/` corresponds to `lib/src/pages/`
- `test/pinboard/` corresponds to `lib/src/pinboard/`
- Each feature has its own subdirectory

### 2. Separation of Concerns
- **State Tests**: Located in `state/` subdirectories, test business logic
- **Widget Tests**: Test UI components and their interactions
- **Service Tests**: Test API clients and data services
- **Integration Tests**: End-to-end functionality tests

### 3. Mock Files
- Mock files are co-located with their corresponding test files
- Named with `.mocks.dart` suffix
- Generated using `mockito` package

## Test Categories

### Unit Tests
- **Cubit/Bloc Tests**: Test state management logic
- **Service Tests**: Test API interactions and data processing
- **Model Tests**: Test data models and serialization

### Widget Tests
- **Page Tests**: Test complete page functionality
- **Component Tests**: Test individual UI components
- **Dialog Tests**: Test modal dialogs and overlays

### Integration Tests
- **Feature Tests**: Test complete user workflows
- **API Integration**: Test real API interactions (when needed)

## Test Helpers

### `test_helpers.dart`
Provides shared utilities:

#### TestHelpers Class
- Credential service helpers
- Storage management utilities
- Common test data creation

#### PostTestData Class
- `createPost()` - Single post creation
- `createPostList()` - Multiple posts with variations
- `createPostsWithTags()` - Posts for tag testing
- `createSearchTestPosts()` - Posts for search testing
- `createLargePostList()` - Large datasets for performance testing

#### ExceptionTestData Class
- `createNetworkException()` - Network error scenarios
- `createAuthException()` - Authentication failures
- `createServerException()` - Server error responses
- `createTimeoutException()` - Timeout scenarios

## Running Tests

### Individual Test Files
```bash
# Run a specific test file
flutter test test/pages/bookmarks/state/bookmarks_cubit_test.dart

# Run with detailed output
flutter test test/pages/bookmarks/state/bookmarks_cubit_test.dart --reporter expanded
```

### Test Categories
```bash
# Run all unit tests
flutter test test/

# Run specific feature tests
flutter test test/pages/bookmarks/

# Run service tests
flutter test test/pinboard/
```

### Coverage Reports
```bash
# Generate coverage report
flutter test --coverage

# View coverage in browser
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Testing Best Practices

### 1. Test Structure
- Use `group()` to organize related tests
- Use descriptive test names that explain the scenario
- Follow the Arrange-Act-Assert pattern

### 2. Mocking
- Mock external dependencies (services, APIs)
- Use `MockPinboardService` for API interactions
- Stub return values for expected scenarios
- Verify method calls when testing interactions

### 3. State Testing
- Use `blocTest` for testing Cubit/Bloc state changes
- Test both success and failure scenarios
- Verify state emissions with `expect()`
- Use `isA<StateType>()` matchers for flexible assertions

### 4. Data Management
- Use test data factories from `PostTestData`
- Create realistic test scenarios
- Test edge cases (empty lists, null values, etc.)

### 5. Async Testing
- Use `wait` parameter in `blocTest` for timing-sensitive tests
- Handle async operations properly
- Test loading states and error handling

## Example Test Pattern

```dart
group('FeatureCubit', () {
  late MockService mockService;
  late FeatureCubit cubit;

  setUp(() {
    mockService = MockService();
    cubit = FeatureCubit(service: mockService);
  });

  tearDown(() {
    cubit.close();
  });

  group('loadData', () {
    blocTest<FeatureCubit, FeatureState>(
      'emits loading then loaded when successful',
      build: () {
        when(mockService.getData()).thenAnswer((_) async => testData);
        return cubit;
      },
      act: (cubit) => cubit.loadData(),
      expect: () => [
        isA<FeatureState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FeatureState>().having((s) => s.data, 'data', equals(testData)),
      ],
      verify: (_) {
        verify(mockService.getData()).called(1);
      },
    );

    blocTest<FeatureCubit, FeatureState>(
      'emits error when service fails',
      build: () {
        when(mockService.getData()).thenThrow(Exception('Error'));
        return cubit;
      },
      act: (cubit) => cubit.loadData(),
      expect: () => [
        isA<FeatureState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FeatureState>().having((s) => s.hasError, 'hasError', true),
      ],
    );
  });
});
```

## Continuous Integration

Tests are run automatically on:
- Pull requests
- Main branch commits
- Release builds

### GitHub Actions
- Runs all tests in CI/CD pipeline
- Generates coverage reports
- Fails builds on test failures

## Maintenance

### Adding New Tests
1. Create test file in appropriate directory
2. Follow naming convention: `*_test.dart`
3. Include both success and failure scenarios
4. Add mock files if needed
5. Update this documentation if adding new patterns

### Updating Existing Tests
- Keep tests in sync with code changes
- Update mocks when service interfaces change
- Maintain test data factories
- Ensure tests remain fast and reliable

### Performance Guidelines
- Keep individual test execution under 100ms
- Use efficient test data creation
- Minimize file I/O in tests
- Parallelize independent test groups

## Debugging Tests

### Common Issues
1. **Mock setup**: Ensure proper `when()` stubs
2. **Async timing**: Use `wait` parameter for timing
3. **State assertions**: Use flexible matchers like `isA<>()`
4. **Clean up**: Always close cubits in `tearDown()`

### Debugging Tips
```bash
# Run single test with verbose output
flutter test test/path/to/test.dart --plain-name "test name"

# Debug test execution
flutter test --debug test/path/to/test.dart
```

This test organization provides a solid foundation for maintaining high code quality and ensuring reliable functionality across the Pinboard Wizard application.
