import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/theme.dart';
import 'package:provider/provider.dart';

void main() async {
  const config = MacosWindowUtilsConfig();
  await config.apply();
  runApp(const PinboardWizard());
}

class PinboardWizard extends StatelessWidget {
  const PinboardWizard({super.key});

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
                  return SidebarItems(
                    items: [SidebarItem(label: Text('Test'))],
                    currentIndex: 0,
                    onChanged: (i) {
                      return;
                    },
                  );
                },
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
      label: 'macos_ui Widget Gallery',
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
