import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';

// On-device smoke test for the Liquid Glass UI facade (lib/src/ui/).
//
// Runs on the REAL macOS device (`fvm flutter test integration_test -d macos`)
// so the actual Impeller/Skia GPU path is exercised — headless widget tests use
// a fake rasterizer and cannot prove the glass shaders/containers render on
// hardware. This is the automated stand-in for a manual click-through.
//
// It deliberately does NOT boot the full app (main()/PinboardWizard/setup()),
// which registers real services (secure storage, sqlite, GetIt) and native
// window setup — that would hit the real keychain/DB and be flaky. Instead a
// representative screen is built straight from the facade.

const String _kFirstLabel = 'Bookmarks';
const String _kSecondLabel = 'Notes';

/// Representative Liquid Glass screen: a [GlassWindowScaffold] with a navigable
/// [GlassSidebar] and a body of facade controls. All mutable state is mirrored
/// into visible [Text] widgets so tests observe behaviour through the public
/// render tree (black-box) rather than reaching into private State.
class _GlassHarness extends StatefulWidget {
  const _GlassHarness();

  @override
  State<_GlassHarness> createState() => _GlassHarnessState();
}

class _GlassHarnessState extends State<_GlassHarness> {
  int _selectedIndex = 0;
  bool _actionFired = false;
  bool _switchOn = false;

  @override
  Widget build(BuildContext context) {
    return GlassWindowScaffold(
      sidebar: GlassSidebar(
        selectedIndex: _selectedIndex,
        onSelected: (i) => setState(() => _selectedIndex = i),
        items: const [
          GlassSidebarItem(icon: Icons.bookmark, label: _kFirstLabel),
          GlassSidebarItem(icon: Icons.note, label: _kSecondLabel),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Visible state mirrors — the tests assert against these.
            Text('index=$_selectedIndex'),
            Text(_actionFired ? 'action=fired' : 'action=idle'),
            Text(_switchOn ? 'switch=on' : 'switch=off'),
            const SizedBox(height: 16),
            AppButton(
              onPressed: () => setState(() => _actionFired = !_actionFired),
              child: const Text('Run action'),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 360,
              child: AppTextField(placeholder: 'Filter items'),
            ),
            const SizedBox(height: 16),
            AppSwitch(
              value: _switchOn,
              onChanged: (v) => setState(() => _switchOn = v),
            ),
            const SizedBox(height: 16),
            const AppProgress(),
            const SizedBox(height: 16),
            const SizedBox(
              width: 360,
              child: AppListTile(title: Text('A saved item')),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _app() => LiquidGlassWidgets.wrap(
      theme: appGlassTheme(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appLightTheme(),
        home: const _GlassHarness(),
      ),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await LiquidGlassWidgets.initialize();
  });

  // NOTE: we intentionally do NOT use `tester.pumpAndSettle()`.
  //
  // The screen mounts an `AppProgress`, which renders an *indeterminate*
  // `GlassProgressIndicator.circular()`. Its State calls
  // `AnimationController.repeat()` in initState, so a new frame is scheduled
  // forever. `pumpAndSettle()` loops until `hasScheduledFrame` is false and,
  // with that spinner mounted, never settles — it would run until its 10-minute
  // timeout and throw (the classic indeterminate-progress-indicator gotcha).
  //
  // Instead we drive frames explicitly: one build frame plus a fixed window that
  // is comfortably longer than the heaviest transient animation in the tree (the
  // switch's 380ms position/bloom) and long enough for the wallpaper assets to
  // decode. This keeps every assertion intact while remaining terminating.
  Future<void> renderFrames(WidgetTester tester) async {
    await tester.pump(); // build the frame just scheduled
    await tester.pump(const Duration(milliseconds: 600)); // decode + transients
  }

  group('liquid glass smoke (on-device)', () {
    testWidgets('glass shell renders on device', (tester) async {
      await tester.pumpWidget(_app());
      await renderFrames(tester);

      // Shell + a representative sample of glass widgets are on screen.
      expect(find.byType(GlassWindowScaffold), findsOneWidget);
      expect(find.byType(GlassSidebar), findsOneWidget);
      expect(find.text(_kFirstLabel), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
      expect(find.byType(AppProgress), findsOneWidget);

      // The whole point of running on hardware: no shader/asset/runtime error
      // escaped on the real GPU path (this also proves the wallpaper assets
      // actually decoded on-device).
      expect(tester.takeException(), isNull);
    });

    testWidgets('sidebar selection is interactive', (tester) async {
      await tester.pumpWidget(_app());
      await renderFrames(tester);

      expect(find.text('index=0'), findsOneWidget);

      // Tap the second destination; the sidebar row's InkWell fires onSelected.
      await tester.tap(find.text(_kSecondLabel));
      await renderFrames(tester);

      // Selection moved to index 1 and the old value is gone — proves the
      // callback fired AND the parent rebuilt with the new selection.
      expect(find.text('index=1'), findsOneWidget);
      expect(find.text('index=0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('glass controls respond', (tester) async {
      await tester.pumpWidget(_app());
      await renderFrames(tester);

      expect(find.text('action=idle'), findsOneWidget);
      expect(find.text('switch=off'), findsOneWidget);

      // Button: tapping runs its onPressed, which flips the visible label.
      await tester.tap(find.byType(AppButton));
      await renderFrames(tester);
      expect(find.text('action=fired'), findsOneWidget);
      expect(find.text('action=idle'), findsNothing);

      // Switch: tapping toggles the tracked value (GlassSwitch confirms a tap
      // via onTapUp), flipping the visible label.
      await tester.tap(find.byType(AppSwitch));
      await renderFrames(tester);
      expect(find.text('switch=on'), findsOneWidget);
      expect(find.text('switch=off'), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
