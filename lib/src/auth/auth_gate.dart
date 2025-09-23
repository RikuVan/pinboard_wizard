import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';

class AuthGate extends StatefulWidget {
  final Widget child;
  final VoidCallback? onNavigateToSettings;

  const AuthGate({super.key, required this.child, this.onNavigateToSettings});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final CredentialsService _credentialsService;

  @override
  void initState() {
    super.initState();
    _credentialsService = locator.get<CredentialsService>();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _credentialsService.isAuthenticatedNotifier,
      builder: (context, isAuthenticated, _) {
        if (isAuthenticated) {
          return widget.child;
        }

        return _buildAuthRequired();
      },
    );
  }

  Widget _buildAuthRequired() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 120),
            const SizedBox(height: 32),
            Text(
              'Welcome to Pinboard Wizard',
              style: MacosTheme.of(context).typography.largeTitle,
            ),
            const SizedBox(height: 16),
            Text(
              'To get started, please configure your Pinboard API credentials in Settings.',
              style: MacosTheme.of(context).typography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: widget.onNavigateToSettings,
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
