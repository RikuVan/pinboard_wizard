import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';

/// Example showing how to use CredentialsService in your Flutter app
class CredentialsExample {
  final CredentialsService _credentialsService = CredentialsService();

  /// Example: Login flow
  Future<bool> login(String apiKey) async {
    try {
      // Validate the API key format
      if (!_credentialsService.isValidApiKey(apiKey)) {
        throw Exception('Invalid API key format. Expected: username:hexstring');
      }

      // Save to macOS keychain
      await _credentialsService.saveCredentials(apiKey);

      // Optional: Get username for display
      final username = _credentialsService.getUsernameFromApiKey(apiKey);
      debugPrint('Logged in as: $username');

      return true;
    } catch (e) {
      debugPrint('Login failed: $e');
      return false;
    }
  }

  /// Example: Check authentication status on app startup
  Future<bool> checkAuthenticationStatus() async {
    try {
      return await _credentialsService.isAuthenticated();
    } catch (e) {
      debugPrint('Authentication check failed: $e');
      return false;
    }
  }

  /// Example: Get stored credentials for API calls
  Future<String?> getApiKeyForRequest() async {
    try {
      final credentials = await _credentialsService.getCredentials();
      return credentials?.apiKey;
    } catch (e) {
      debugPrint('Failed to get API key: $e');
      return null;
    }
  }

  /// Example: Logout flow
  Future<void> logout() async {
    try {
      await _credentialsService.clearCredentials();
      debugPrint('Successfully logged out');
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

  /// Example: App startup flow
  Future<void> initializeApp() async {
    final isAuthenticated = await checkAuthenticationStatus();

    if (isAuthenticated) {
      final credentials = await _credentialsService.getCredentials();
      final username = _credentialsService.getUsernameFromApiKey(
        credentials?.apiKey,
      );
      debugPrint('App initialized - User: $username');
    } else {
      debugPrint('App initialized - No authentication');
    }
  }
}

/// Example Widget showing login form
class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final _apiKeyController = TextEditingController();
  final _credentialsService = CredentialsService();
  bool _isLoading = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = _apiKeyController.text.trim();

      if (!_credentialsService.isValidApiKey(apiKey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid API key format. Expected: username:hexstring',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _credentialsService.saveCredentials(apiKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credentials saved to keychain successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Pinboard API Key'),
          ),
          const SizedBox(height: 6),
          MacosTextField(
            controller: _apiKeyController,
            placeholder: 'username:1234567890abcdef',
            obscureText: true,
            clearButtonMode: OverlayVisibilityMode.editing,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PushButton(
              controlSize: ControlSize.large,
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const ProgressCircle()
                  : const Text('Save to Keychain'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Example usage in your main app
class ExampleAppIntegration {
  static Future<void> setupApp() async {
    final credentialsService = CredentialsService();

    // Check if user is already authenticated
    final isAuthenticated = await credentialsService.isAuthenticated();

    if (isAuthenticated) {
      // User is logged in, proceed to main app
      await credentialsService.getCredentials();
      debugPrint('Welcome back! API key loaded from keychain.');
    } else {
      // Show login screen
      debugPrint('Please log in to continue.');
    }
  }
}
