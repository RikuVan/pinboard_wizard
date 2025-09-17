import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/theme.dart';
import 'package:pinboard_wizard/src/auth/auth_gate.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/bookmarks_page.dart';
import 'package:pinboard_wizard/src/pages/pinned/pinned_page.dart';
import 'package:pinboard_wizard/src/pages/settings_page.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  const config = MacosWindowUtilsConfig();
  await config.apply();
  await setup();
  runApp(PinboardWizard(version: packageInfo.version));
}

class PinboardWizard extends StatefulWidget {
  const PinboardWizard({required this.version, super.key});

  final String version;

  @override
  State<PinboardWizard> createState() => _PinboardWizardState();
}

class _PinboardWizardState extends State<PinboardWizard> {
  int pageIndex = 0;
  CredentialsService? _credentialsService;

  @override
  void initState() {
    super.initState();
    _credentialsService = locator.get<CredentialsService>();

    // Ensure initial selection reflects auth state
    if (!_credentialsService!.isAuthenticatedNotifier.value) {
      pageIndex = 3;
    }
    _credentialsService!.isAuthenticatedNotifier.addListener(() {
      final authed = _credentialsService!.isAuthenticatedNotifier.value;
      if (!authed) {
        setState(() => pageIndex = 3);
      } else if (pageIndex == 3) {
        setState(() => pageIndex = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppTheme(),
      builder: (context, _) {
        final appTheme = context.watch<AppTheme>();
        return MacosApp(
          title: 'Pinboard Wizard',
          themeMode: appTheme.mode,
          debugShowCheckedModeBanner: false,
          home: PlatformMenuBar(
            menus: menuBarItems(),
            child: MacosWindow(
              sidebar: Sidebar(
                minWidth: 200,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      Expanded(
                        child: SidebarItems(
                          currentIndex: pageIndex,
                          items: [
                            SidebarItem(label: Text('Pinned')),
                            SidebarItem(label: Text('Bookmarks')),
                            SidebarItem(label: Text('Notes')),
                            SidebarItem(label: Text('Settings')),
                          ],
                          onChanged: (i) {
                            setState(() => pageIndex = i);
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: MacosColors.separatorColor,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: MacosListTile(
                          leading: const AppLogo.small(),
                          title: Text('Pinboard Wizard'),
                          subtitle: Text('Version ${widget.version}'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              child: ContentArea(
                builder: (context, _) => AuthGate(
                  child: [
                    const PinnedPage(),
                    const BookmarksPage(),
                    const Text("3"),
                    const SettingsPage(),
                  ][pageIndex],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

List<PlatformMenuItem> menuBarItems() {
  return const [
    PlatformMenu(
      label: 'Pinboard Wizard',
      menus: [
        PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
        PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
      ],
    ),
    PlatformMenu(
      label: 'View',
      menus: [
        PlatformProvidedMenuItem(
          type: PlatformProvidedMenuItemType.toggleFullScreen,
        ),
      ],
    ),
    PlatformMenu(
      label: 'Window',
      menus: [
        PlatformProvidedMenuItem(
          type: PlatformProvidedMenuItemType.minimizeWindow,
        ),
        PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow),
      ],
    ),
  ];
}
