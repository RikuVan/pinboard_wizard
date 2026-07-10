import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';

// Minimal valid 1x1 transparent PNG. The window scaffold renders
// `Image.asset('assets/wallpaper_*.png')`, but those assets don't exist yet
// (added in Task 8). Serving valid bytes for `.png` keys lets the pump build
// cleanly without the framework throwing an "Unable to load asset" error.
const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

/// Test bundle that serves a valid image for `.png` keys (the not-yet-shipped
/// wallpaper assets) and defers everything else — including the asset manifest
/// — to the real [rootBundle], so scale-variant resolution is unchanged.
class _WallpaperStubBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.png')) {
      return ByteData.view(Uint8List.fromList(_kTransparentPng).buffer);
    }
    return rootBundle.load(key);
  }
}

Widget _host(Widget child) => DefaultAssetBundle(
  bundle: _WallpaperStubBundle(),
  child: LiquidGlassWidgets.wrap(
    child: MaterialApp(
      theme: appLightTheme(),
      home: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('facade controls build', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            AppButton(onPressed: () {}, child: const Text('Go')),
            AppButton(onPressed: null, child: const Text('Off')),
            AppIconButton(icon: const Icon(Icons.add), onPressed: () {}),
            AppSwitch(value: true, onChanged: (_) {}),
            AppCheckbox(value: true, onChanged: (_) {}),
            AppRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
            const AppProgress(),
            const AppTooltip(message: 'hi', child: Icon(Icons.info)),
            const AppListTile(title: Text('Tile')),
          ],
        ),
      ),
    );
    expect(find.text('Go'), findsOneWidget);
    expect(find.byType(AppSwitch), findsOneWidget);
    expect(find.byType(AppProgress), findsOneWidget);
  });

  testWidgets('window scaffold + sidebar build', (tester) async {
    await tester.pumpWidget(
      _host(
        GlassWindowScaffold(
          sidebar: GlassSidebar(
            items: const [
              GlassSidebarItem(icon: Icons.star, label: 'A'),
              GlassSidebarItem(icon: Icons.book, label: 'B'),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
          body: const Center(child: Text('content')),
        ),
      ),
    );
    expect(find.text('content'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });
}
