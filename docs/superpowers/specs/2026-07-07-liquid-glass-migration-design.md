# Liquid Glass Migration Design

**Date:** 2026-07-07
**Status:** Approved (design) — pending implementation plan
**Topic:** Replace the unmaintained `macos_ui` dependency with `liquid_glass_widgets`

## Goal

Remove `macos_ui` (unmaintained) from Pinboard Wizard and re-skin the app with
`liquid_glass_widgets` (`^0.21.1`, iOS-26 Liquid Glass). Preserve the existing
desktop macOS experience — window + left sidebar + content area — while adopting
the glass visual language for navigation chrome. Widgets the target library does
not provide are re-implemented locally as temporary shims styled with liquid
glass. On completion, **no reference to `macos_ui` remains** anywhere in `lib/`
or `test/`.

## Constraints & Decisions

- **Platform:** macOS desktop only (the app ships only a `macos/` runner).
  liquid_glass renders on macOS via Impeller (Metal). Requires Flutter ≥ 3.41 /
  Dart ≥ 3.5 — satisfied (project is Flutter 3.44.4 / Dart ^3.12.0).
- **Layout paradigm (decided):** Keep the desktop **window + left sidebar +
  content area**. Do NOT adopt the library's mobile `GlassScaffold`/`GlassTabBar`
  navigation model. Glass is applied to **chrome only**; content stays opaque.
- **Window chrome (decided):** Keep native transparent titlebar + traffic
  lights + window blur by depending on **`macos_window_utils`** directly (the
  package `macos_ui` bundled), replacing `MacosWindowUtilsConfig`.
- **Backdrop (decided):** A **wallpaper image** sits behind the glass. It MUST be
  muted / low-contrast so readability holds. Content lists/tiles render on
  **opaque** surfaces; the wallpaper is visible only behind glass chrome and at
  window edges.
- **Root app widget (decided):** Replace `MacosApp` with **`MaterialApp`**
  wrapped by `LiquidGlassWidgets.wrap(...)`. Material keeps `provider`,
  `flutter_bloc`, `showDialog`, and overlays working cleanly. Not Cupertino.
- **Wallpaper assets (decided):** Generate tasteful **default muted light/dark
  wallpapers**; the user can swap them later.
- **Theme switching:** Preserve the existing light/dark/system switch
  (`AppTheme.mode` → `MaterialApp.themeMode`); the wallpaper and color tokens
  switch on brightness.
- **State management:** Unchanged. Existing cubits/providers stay as-is; this is
  a UI-layer migration only. No business logic changes.
- **API accuracy:** Exact `liquid_glass_widgets` constructor signatures are
  treated as unverified in this design. The implementation plan pins every shim
  to the installed package's real API (read from the resolved package source),
  before writing shim internals.

## Approach (chosen: Local UI facade)

Create a cohesive local design system at **`lib/src/ui/`** that:

1. **Re-exports** the real `liquid_glass_widgets` we consume.
2. Supplies **local shim widgets** for desktop-only pieces the library lacks
   (window shell, sidebar, tooltip, checkbox, the multi-button alert dialog).
3. Provides a **token layer** replacing `MacosColors` / `MacosTheme`.

All `liquid_glass_widgets` coupling lives behind this one facade, so a future
library swap is contained. Callsites change their import + widget names once.

Rejected alternatives:
- **Drop-in compat layer** keeping `macos_ui` names (`PushButton`, `MacosColors`,
  …) — smallest diff but enshrines the old naming the user called "temporary"
  and hides that widgets are now glass.
- **Full per-page rewrite** to native `GlassScaffold` patterns — highest effort
  and risk, and conflicts with the decided desktop sidebar layout.

## Architecture

### Entry point (`lib/main.dart`)

```
main():
  WidgetsFlutterBinding.ensureInitialized()
  <macos_window_utils setup: WindowManipulator.initialize,
     makeTitlebarTransparent, full-size content view, hidden title,
     traffic-light positioning>            // replaces MacosWindowUtilsConfig().apply()
  await LiquidGlassWidgets.initialize()      // pre-warm shaders
  runApp(LiquidGlassWidgets.wrap(
    theme: <GlassThemeData light/dark>,
    child: PinboardWizard(version: ...),
  ))
```

`PinboardWizard` builds `MaterialApp` (was `MacosApp`), keeping `navigatorKey`,
`themeMode` from `AppTheme`, `debugShowCheckedModeBanner: false`, and the
existing `PlatformMenuBar` → `KeyboardShortcuts` → `FocusScope` chain. The
`MacosWindow`/`Sidebar`/`ContentArea` subtree is replaced by
`GlassWindowScaffold` (see below).

### The facade: `lib/src/ui/`

```
lib/src/ui/
  ui.dart                       # barrel: re-exports liquid_glass + shims + tokens
  tokens/
    app_colors.dart             # replaces MacosColors.*
    app_typography.dart         # replaces MacosTheme.of(ctx).typography.*
    app_theme.dart              # GlassThemeData + MaterialApp ThemeData (light/dark)
    context_ext.dart            # brightness/canvasColor/label-color extensions
  layout/
    glass_window_scaffold.dart  # wallpaper backdrop + Row(sidebar, content)
    glass_sidebar.dart          # replaces Sidebar/SidebarItems
    glass_sidebar_item.dart     # replaces SidebarItem
  controls/
    app_button.dart             # PushButton  -> GlassButton
    app_icon_button.dart        # MacosIconButton -> GlassIconButton
    app_text_field.dart         # MacosTextField  -> GlassTextField
    app_search_field.dart       # MacosSearchField -> GlassSearchBar
    app_switch.dart             # MacosSwitch  -> GlassSwitch
    app_checkbox.dart           # MacosCheckbox -> local glass checkbox (no library equiv)
    app_list_tile.dart          # MacosListTile -> GlassListTile
    app_tooltip.dart            # MacosTooltip  -> styled Tooltip
    app_progress.dart           # ProgressCircle -> GlassProgressIndicator
  overlays/
    app_dialog.dart             # MacosAlertDialog -> GlassDialog (+ showAppAlertDialog)
    app_sheet.dart              # MacosSheet -> GlassSheet
```

Existing `lib/src/common/extensions/theme_extensions.dart` (currently built on
`MacosTheme`/`MacosColors`) is folded into `tokens/context_ext.dart` +
`tokens/app_colors.dart`; the old file is removed and its callers repointed.

### Token layer

- **`AppColors`** — `CupertinoDynamicColor`-backed constants preserving
  `.resolveFrom(context)` semantics, mapping the former palette:
  `separatorColor → CupertinoColors.separator`;
  `label/secondaryLabel/tertiaryLabelColor → CupertinoColors.label/.secondaryLabel/.tertiaryLabel`;
  `controlBackgroundColor` (+ `.darkColor`) → a glass-friendly surface token;
  `controlAccentColor → systemBlue` (app accent);
  `system{Red,Orange,Green,Blue,Purple,Gray}Color → CupertinoColors.system*`.
- **`AppTypography`** — `context.appTypography.{largeTitle,title2,headline,body}`
  backed by Material `TextTheme`/Cupertino styles, matching current sizes/weights.
- **`context_ext.dart`** — `context.brightness` (via `Theme.of`/
  `MediaQuery.platformBrightnessOf`), `context.canvasColor`, and the label-color
  getters currently in `theme_extensions.dart`.

### Glass theme

`GlassThemeData` with light + dark `GlassThemeVariant`s (`GlassQuality.standard`,
accent = systemBlue) passed to `LiquidGlassWidgets.wrap(theme:)`. `MaterialApp`
carries matching light/dark `ThemeData` driven by `AppTheme.mode`.

### Layout shell

`GlassWindowScaffold` uses `LiquidGlassScope.stack(background: <wallpaper>, content: Row([GlassSidebar, Expanded(contentArea)]))`
(the library's documented non-`GlassPage` wiring). The wallpaper widget is chosen
by brightness. `GlassSidebar` is a glass panel hosting `GlassSidebarItem`s (icon +
label, selection state, `onChanged`) plus a footer slot for the version
`AppListTile`. The content area is an **opaque** surface.

### Readability rule (explicit)

Glass surfaces: sidebar, page toolbars/headers, dialogs, sheets, buttons,
switches, fields. **Opaque** surfaces: bookmark list & tiles, notes list & tiles,
pinned grid/tiles, settings body. The wallpaper never sits directly behind body
text.

## Migration Mechanics

Per file currently importing `package:macos_ui/macos_ui.dart`:
1. Swap import → `package:pinboard_wizard/src/ui/ui.dart`.
2. Rename widgets per the mapping table.
3. Replace `MacosTheme.of(context).*` / `MacosColors.*` with tokens/extensions.

Files touched (from inventory): `lib/main.dart`; `lib/src/auth/auth_gate.dart`;
`lib/src/common/extensions/theme_extensions.dart` (folded/removed);
`lib/src/common/widgets/{bookmark_tile,dialogs,keyboard_shortcuts,validated_secret_field}.dart`;
`lib/src/pages/bookmarks/{add_bookmark_dialog,bookmarks_page,edit_bookmark_dialog,pin_category_dialog,resizable_split_view,tags_panel}.dart`;
`lib/src/pages/notes/{github_notes_page,resizable_split_view}.dart` and
`lib/src/pages/notes/widgets/{conflict_resolution_dialog,github_note_tile,markdown_editor,new_note_form}.dart`;
`lib/src/pages/pinned/{pinned_bookmark_tile,pinned_page}.dart`;
`lib/src/pages/settings/settings_page.dart`.

Test: `test/pages/bookmarks/add_bookmark_dialog_test.dart` — replace the
`MacosApp`/`MacosWindow` test harness with `MaterialApp` (+ `wrap` if needed) and
retype finders (`PushButton → AppButton`, `MacosTextField → AppTextField`).

Docs: `CLAUDE.md` UI note and page `README.md` mentions of `macos_ui` updated to
reference the new facade.

## Widget Mapping

| macos_ui | replacement |
|---|---|
| `MacosApp` | `MaterialApp` + `LiquidGlassWidgets.wrap` |
| `MacosWindow` / `Sidebar` / `SidebarItems` / `SidebarItem` / `ContentArea` | `GlassWindowScaffold` + `GlassSidebar` / `GlassSidebarItem` |
| `MacosWindowUtilsConfig` | `macos_window_utils` (`WindowManipulator`) |
| `PushButton` | `AppButton` → `GlassButton` |
| `MacosIconButton` / `MacosIcon` | `AppIconButton` → `GlassIconButton` / `Icon` |
| `MacosTextField` / `MacosSearchField` | `AppTextField` → `GlassTextField` / `AppSearchField` → `GlassSearchBar` |
| `MacosSwitch` / `MacosCheckbox` | `AppSwitch` → `GlassSwitch` / `AppCheckbox` (local) |
| `MacosListTile` | `AppListTile` → `GlassListTile` |
| `MacosSheet` / `MacosAlertDialog` | `AppSheet` → `GlassSheet` / `showAppAlertDialog` → `GlassDialog` |
| `MacosTooltip` / `ProgressCircle` | `AppTooltip` / `AppProgress` → `GlassProgressIndicator` |
| `MacosTheme.of(...)` / `MacosColors.*` | `AppTypography` / `context` ext / `AppColors` |

## Testing & Verification

- `flutter analyze` clean.
- `grep -r macos_ui lib test` returns nothing (except intentionally-updated docs).
- `flutter test` green, including the updated `add_bookmark_dialog_test.dart`.
- `flutter run -d macos` smoke test:
  - Window renders with muted wallpaper and transparent titlebar/traffic lights.
  - Glass sidebar switches between Pinned / Bookmarks / Notes / Settings.
  - Add/Edit bookmark dialogs open; buttons, text fields, AI button, switches work.
  - Bookmark/note lists remain fully legible (opaque surfaces).
  - Light / dark / system toggle updates chrome, wallpaper, and tokens.

## Out of Scope

- No changes to business logic, services, cubits, database, or networking.
- No adoption of the library's mobile navigation model.
- No redesign of page layouts beyond the glass re-skin.

## Risks

- **Exact liquid_glass API drift** — mitigated by pinning shims to the resolved
  package source during implementation.
- **Impeller requirement** — macOS defaults to Impeller on current Flutter; verify
  during smoke test. Glass degrades gracefully (`minimal`) if a shader path is
  unavailable.
- **`macos_window_utils` native setup** — small surface; validated by the window
  rendering correctly in the smoke test.
