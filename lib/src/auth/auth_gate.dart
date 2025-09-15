import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/pages/settings_page.dart';

class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final CredentialsService _credentialsService;
  late final PinboardService _pinboardService;

  bool _checking = true;
  String? _error;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _credentialsService = locator.get<CredentialsService>();
    _pinboardService = locator.get<PinboardService>();
    _check();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final has = await _credentialsService.isAuthenticated();
    _authenticated = has;
    if (!has) {
      setState(() => _checking = false);
      return;
    }

    try {
      final ok = await _pinboardService.testConnection();
      if (!ok) {
        setState(() {
          _checking = false;
          _error = 'Failed to authenticate with Pinboard.';
          _authenticated = false;
        });
      } else {
        setState(() {
          _checking = false;
          _authenticated = true;
        });
      }
    } catch (e) {
      setState(() {
        _checking = false;
        _error = 'Connection error: $e';
        _authenticated = false;
      });
    }
  }

  // Dialog flow replaced by SettingsPage navigation/content handled by AuthGate.

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: ProgressCircle());
    }

    final notAuthed = _error == null && !_authenticated;
    if (notAuthed) {
      return const SettingsPage();
    }

    if (_error != null) {
      return const SettingsPage();
    }

    return widget.child;
  }
}
