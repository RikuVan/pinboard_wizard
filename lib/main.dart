import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pinboard_wizard/src/auth/auth_gate.dart';
import 'package:pinboard_wizard/src/common/state/bookmark_change_notifier.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/common/widgets/keyboard_shortcuts.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/bookmarks_page.dart';
import 'package:pinboard_wizard/src/pages/notes/github_notes_page.dart';
import 'package:pinboard_wizard/src/pages/pinned/pinned_page.dart';
import 'package:pinboard_wizard/src/pages/settings/settings_page.dart';
import 'package:pinboard_wizard/src/pinboard/credentials_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/theme.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
import 'package:provider/provider.dart';

// Global navigator key for menu navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  await WindowManipulator.initialize(enableWindowDelegate: true);
  await WindowManipulator.setMaterial(
    NSVisualEffectViewMaterial.windowBackground,
  );
  await WindowManipulator.enableFullSizeContentView();
  await WindowManipulator.makeTitlebarTransparent();
  await WindowManipulator.hideTitle();
  await WindowManipulator.addToolbar();
  await WindowManipulator.setToolbarStyle(
    toolbarStyle: NSWindowToolbarStyle.unified,
  );
  await LiquidGlassWidgets.initialize();
  await setup();
  runApp(
    LiquidGlassWidgets.wrap(
      theme: appGlassTheme(),
      child: PinboardWizard(version: packageInfo.version),
    ),
  );
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
        return MaterialApp(
          title: 'Pinboard Wizard',
          navigatorKey: navigatorKey,
          themeMode: appTheme.mode,
          theme: appLightTheme(),
          darkTheme: appDarkTheme(),
          debugShowCheckedModeBanner: false,
          home: PlatformMenuBar(
            menus: menuBarItems(
              context,
              onNavigateToPinned: () => setState(() => pageIndex = 0),
              onNavigateToBookmarks: () => setState(() => pageIndex = 1),
              onNavigateToNotes: () => setState(() => pageIndex = 2),
              onNavigateToSettings: () => setState(() => pageIndex = 3),
              onRefresh: _refreshCurrentPage,
            ),
            child: FocusScope(
              autofocus: true,
              child: KeyboardShortcuts(
                onNavigateToPinned: () => setState(() => pageIndex = 0),
                onNavigateToBookmarks: () => setState(() => pageIndex = 1),
                onNavigateToNotes: () => setState(() => pageIndex = 2),
                onNavigateToSettings: () => setState(() => pageIndex = 3),
                onRefreshPage: _refreshCurrentPage,
                child: GlassWindowScaffold(
                  sidebar: GlassSidebar(
                    selectedIndex: pageIndex,
                    onSelected: (i) => setState(() => pageIndex = i),
                    items: const [
                      GlassSidebarItem(
                        icon: CupertinoIcons.pin_fill,
                        label: 'Pinned',
                      ),
                      GlassSidebarItem(
                        icon: CupertinoIcons.bookmark_fill,
                        label: 'Bookmarks',
                      ),
                      GlassSidebarItem(
                        icon: CupertinoIcons.doc_text_fill,
                        label: 'Notes',
                      ),
                      GlassSidebarItem(
                        icon: CupertinoIcons.gear_alt_fill,
                        label: 'Settings',
                      ),
                    ],
                    footer: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppColors.separator.resolveFrom(context),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const AppLogo(size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Pinboard Wizard',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Version ${widget.version}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryLabel.resolveFrom(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  body: pageIndex == 3
                      ? const SettingsPage()
                      : AuthGate(
                          onNavigateToSettings: () =>
                              setState(() => pageIndex = 3),
                          child: const [
                            PinnedPage(),
                            BookmarksPage(),
                            GitHubNotesPage(),
                          ][pageIndex],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Refresh the currently active page
  void _refreshCurrentPage() {
    // Only refresh if authenticated
    if (!_credentialsService!.isAuthenticatedNotifier.value) return;

    switch (pageIndex) {
      case 1: // Bookmarks page
        // Trigger a bookmark refresh notification
        bookmarkChangeNotifier.notifyBookmarksChanged();
        break;
      case 0: // Pinned page
      case 2: // Notes page
      case 3: // Settings page
      default:
        // For other pages, we could add specific refresh logic later
        break;
    }
  }
}

List<PlatformMenuItem> menuBarItems(
  BuildContext context, {
  VoidCallback? onNavigateToPinned,
  VoidCallback? onNavigateToBookmarks,
  VoidCallback? onNavigateToNotes,
  VoidCallback? onNavigateToSettings,
  VoidCallback? onRefresh,
}) {
  return [
    const PlatformMenu(
      label: 'Pinboard Wizard',
      menus: [
        PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
        PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
      ],
    ),
    PlatformMenu(
      label: 'File',
      menus: [
        PlatformMenuItem(
          label: 'New Bookmark',
          shortcut: SingleActivator(LogicalKeyboardKey.keyB, meta: true),
          onSelected: () {
            final navigatorContext = navigatorKey.currentContext;
            if (navigatorContext != null) {
              showAddBookmarkDialog(navigatorContext);
            }
          },
        ),
      ],
    ),
    PlatformMenu(
      label: 'View',
      menus: [
        PlatformMenuItem(
          label: 'Pinned',
          shortcut: SingleActivator(LogicalKeyboardKey.digit1, meta: true),
          onSelected: () {
            onNavigateToPinned?.call();
          },
        ),
        PlatformMenuItem(
          label: 'Bookmarks',
          shortcut: SingleActivator(LogicalKeyboardKey.digit2, meta: true),
          onSelected: () {
            onNavigateToBookmarks?.call();
          },
        ),
        PlatformMenuItem(
          label: 'Notes',
          shortcut: SingleActivator(LogicalKeyboardKey.digit3, meta: true),
          onSelected: () {
            onNavigateToNotes?.call();
          },
        ),
        PlatformMenuItem(
          label: 'Settings',
          shortcut: SingleActivator(LogicalKeyboardKey.digit4, meta: true),
          onSelected: () {
            onNavigateToSettings?.call();
          },
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Refresh',
              shortcut: SingleActivator(LogicalKeyboardKey.keyR, meta: true),
              onSelected: () {
                onRefresh?.call();
              },
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
      ],
    ),
    const PlatformMenu(
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
