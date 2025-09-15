# Makefile for running Flutter app on macOS with debug tools

# Run app on macOS in debug mode
run:
	flutter run -d macos --debug

# Run with verbose logs
run-verbose:
	flutter run -d macos --debug -v

# Build app for macOS in debug mode
build:
	flutter build macos --debug

# Clean build artifacts
clean:
	flutter clean

# Run Flutter doctor
doctor:
	flutter doctor -v

# Open Flutter DevTools
devtools:
	flutter pub global run devtools

# Run with DevTools (launch app + open DevTools in browser)
run-devtools:
	flutter run -d macos --debug --start-paused & \
	open "http://127.0.0.1:9100"

# Run unit/widget tests
test:
	flutter test

# Run macOS integration tests
test-macos:
	flutter test integration_test -d macos

# Run app and then tests (for integration)
run-test:
	flutter run -d macos --debug & \
	sleep 10 && \
	flutter test integration_test -d macos

# Run analyzer (lint check)
analyze:
	flutter analyze

# Format all Dart files
format:
	dart format .

# Check formatting without modifying (fails if not formatted)
format-check:
	dart format --set-exit-if-changed .

# Run everything: format check + an
