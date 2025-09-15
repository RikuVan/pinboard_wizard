import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' hide OverlayVisibilityMode;
import 'dart:async';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/pinboard/in_memory_secrets_storage.dart';
import 'package:pinboard_wizard/src/pinboard/models/credentials.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();

  late final CredentialsService _credentialsService;
  late final PinboardService _pinboardService;

  bool _testing = false;
  String? _error;
  bool? _apiKeyWorks;
  bool _validating = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _credentialsService = locator.get<CredentialsService>();
    _pinboardService = locator.get<PinboardService>();
    _prefill();
    _apiKeyController.addListener(_onApiKeyChanged);
  }

  Future<void> _prefill() async {
    try {
      final creds = await _credentialsService.getCredentials();
      if (creds != null) {
        _apiKeyController.text = creds.apiKey;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (!_credentialsService.isValidApiKey(apiKey)) {
      setState(() => _error = 'Invalid API key. Expected: username:hexstring');
      return;
    }

    setState(() => _error = null);
    try {
      await _credentialsService.saveCredentials(apiKey);
      setState(() => _testing = true);
      final ok = await _pinboardService.testConnection();
      setState(() {
        _testing = false;
        _error = ok ? null : 'Saved, but connection test failed.';
      });
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    }
  }

  Future<void> _clear() async {
    try {
      await _credentialsService.clearCredentials();
      _apiKeyController.clear();
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = 'Failed to clear: $e');
    }
  }

  void _onApiKeyChanged() {
    final apiKey = _apiKeyController.text.trim();
    _debounce?.cancel();
    if (!_credentialsService.isValidApiKey(apiKey)) {
      setState(() {
        _apiKeyWorks = null;
        _validating = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _validateApiKey(apiKey);
    });
  }

  Future<void> _validateApiKey(String apiKey) async {
    setState(() {
      _validating = true;
      _apiKeyWorks = null;
    });

    try {
      final tempStorage = InMemorySecretsStorage();
      await tempStorage.save(Credentials(apiKey: apiKey));
      final tempService = PinboardService(secretStorage: tempStorage);
      final ok = await tempService.testConnection();
      tempService.dispose();
      if (!mounted) return;
      setState(() {
        _apiKeyWorks = ok;
        _validating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiKeyWorks = false;
        _validating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: MacosTheme.of(context).typography.largeTitle),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Status:'),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _credentialsService.isAuthenticatedNotifier,
                builder: (context, authed, _) {
                  return Row(
                    children: [
                      MacosIcon(
                        authed
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.exclamationmark_triangle,
                        color: authed
                            ? MacosColors.systemGreenColor
                            : MacosColors.systemYellowColor,
                      ),
                      const SizedBox(width: 6),
                      Text(authed ? 'Authenticated' : 'Not authenticated'),
                    ],
                  );
                },
              ),
              if (_testing) ...[
                const SizedBox(width: 8),
                const ProgressCircle(),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Text('Pinboard API Key'),
          const SizedBox(height: 6),
          MacosTextField(
            controller: _apiKeyController,
            placeholder: 'username:abcdef1234',
            obscureText: true,
            clearButtonMode: OverlayVisibilityMode.editing,
            suffixMode: OverlayVisibilityMode.always,
            suffix: Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _validating
                  ? const ProgressCircle()
                  : (_apiKeyWorks == null
                        ? const SizedBox.shrink()
                        : MacosIcon(
                            _apiKeyWorks == true
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.xmark_octagon_fill,
                            color: _apiKeyWorks == true
                                ? MacosColors.systemGreenColor
                                : MacosColors.systemRedColor,
                          )),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: MacosColors.systemRedColor),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              PushButton(
                controlSize: ControlSize.large,
                onPressed: _save,
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: _clear,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
