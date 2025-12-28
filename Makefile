# Makefile for running Flutter app on macOS with debug tools

# Run app on macOS in debug mode
run:
	fvm flutter run -d macos --debug

# Run with verbose logs
run-verbose:
	fvm flutter run -d macos --debug -v

# Build app for macOS in debug mode
build:
	fvm flutter build macos --debug

# Clean build artifacts
clean:
	fvm flutter clean

# Run Flutter doctor
doctor:
	fvm flutter doctor -v

# Open Flutter DevTools
devtools:
	fvm flutter pub global run devtools

# Run with DevTools (launch app + open DevTools in browser)
run-devtools:
	fvm flutter run -d macos --debug --start-paused & \
	open "http://127.0.0.1:9100"

# Run unit/widget tests
test:
	fvm flutter test

# Run macOS integration tests
test-macos:
	fvm flutter test integration_test -d macos

# Run app and then tests (for integration)
run-test:
	fvm flutter run -d macos --debug & \
	sleep 10 && \
	fvm flutter test integration_test -d macos

# Run analyzer (lint check)
analyze:
	fvm flutter analyze

# Format all Dart files
format:
	fvm dart format .

# Check formatting without modifying (fails if not formatted)
format-check:
	fvm dart format --set-exit-if-changed .

generate:
	fvm dart run build_runner build --delete-conflicting-outputs

# Run everything: format check + an
