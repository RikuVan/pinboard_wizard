# Liquid Glass Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unmaintained `macos_ui` dependency with `liquid_glass_widgets`, re-skinning Pinboard Wizard in Liquid Glass while keeping its desktop window + sidebar layout, so that no reference to `macos_ui` remains.

**Architecture:** Introduce a local UI facade at `lib/src/ui/` that re-exports the real `liquid_glass_widgets` we use, adds local shim widgets for the desktop/controls the library lacks (window shell, sidebar, tabs, radio, checkbox, tooltip, alert dialog, sheet), and replaces `MacosColors`/`MacosTheme` with a token layer. Build the facade alongside `macos_ui`, migrate callsites file-by-file, then delete `macos_ui`. Glass is applied to chrome only; content lists stay opaque; a muted wallpaper sits behind the glass.

**Tech Stack:** Flutter 3.44.4 / Dart ^3.12.0, `liquid_glass_widgets: ^0.21.1`, `macos_window_utils: ^1.9.1`, `provider`, `flutter_bloc`, macOS desktop (Impeller).

## Global Constraints

- **Platform:** macOS desktop only. Verify glass renders under Impeller.
- **No `macos_ui`:** On completion, `grep -rn macos_ui lib test` returns nothing except intentionally-updated doc prose. `macos_ui` is removed from `pubspec.yaml`.
- **Glass for chrome only:** sidebar, page toolbars/headers, dialogs, sheets, buttons, switches, fields, tabs. **Opaque** surfaces for bookmark/note/pinned lists and settings body. Wallpaper never sits directly behind body text.
- **Root widget:** `MaterialApp` wrapped by `LiquidGlassWidgets.wrap(...)`. Not `MacosApp`, not Cupertino.
- **Preserve behavior:** No business-logic/service/cubit/database changes. Keep `navigatorKey`, `PlatformMenuBar`, `KeyboardShortcuts`, `FocusScope`, light/dark/system switching via the existing `AppTheme` (`lib/src/theme.dart`) ChangeNotifier.
- **Facade import:** Every file that imported `package:macos_ui/macos_ui.dart` imports `package:pinboard_wizard/src/ui/ui.dart` instead.
- **Verified library APIs (v0.21.1) — do NOT deviate:**
  - `LiquidGlassWidgets.initialize({bool enablePerformanceMonitor = true})`
  - `LiquidGlassWidgets.wrap({required Widget child, GlassThemeData? theme, bool respectSystemAccessibility = true, bool adaptiveQuality = false, GlassAdaptiveScopeConfig? adaptiveConfig})`
  - `GlassThemeData.simple({double? blur, double? thickness, GlassQuality? quality, ...})`
  - `GlassQuality { standard, premium, minimal }`
  - `LiquidGlassScope({required Widget child})` — **use this; `LiquidGlassScope.stack(...)` is DEPRECATED.**
  - `GlassContainer({Widget? child, double? width, double? height, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, LiquidShape shape, LiquidGlassSettings? settings, GlassQuality? quality, AlignmentGeometry? alignment, ...})`
  - `GlassIconButton({required Widget icon, required VoidCallback? onPressed, double size = 44, double? iconSize, GlassIconButtonShape shape, double borderRadius = 12, ...})`
  - `GlassTextField({TextEditingController? controller, FocusNode? focusNode, String? placeholder, Widget? prefixIcon, Widget? suffixIcon, VoidCallback? onSuffixTap, bool obscureText, int maxLines = 1, int? minLines, ValueChanged<String>? onChanged, TextStyle? textStyle, TextStyle? placeholderStyle, GlassQuality? quality, ...})`
  - `GlassSearchBar({TextEditingController? controller, String placeholder = 'Search', ValueChanged<String>? onChanged, GlassQuality? quality, ...})`
  - `GlassSwitch({required bool value, required ValueChanged<bool> onChanged, Color? activeColor, double width = 58, double height = 26, GlassQuality? quality, ...})`
  - `GlassListTile({Widget? leading, required Widget title, Widget? subtitle, Widget? trailing, VoidCallback? onTap, ...})`
  - `GlassProgressIndicator.circular({double? value, double size = 20, double strokeWidth = 2.5, Color? color, GlassQuality? quality})`
  - **Confirmed NOT to exist:** `GlassCheckbox`, `GlassTooltip`, any desktop window/sidebar/tab/radio widget. These are local shims.
- **Verified `macos_window_utils` bootstrap (replicates `MacosWindowUtilsConfig().apply()`):** `WindowManipulator.initialize(enableWindowDelegate: true)` → `setMaterial(NSVisualEffectViewMaterial.windowBackground)` → `enableFullSizeContentView()` → `makeTitlebarTransparent()` → `hideTitle()` → `addToolbar()` → `setToolbarStyle(toolbarStyle: NSWindowToolbarStyle.unified)`.

---

## Migration Rules (applied in every Phase 4 callsite task)

Apply these fixed symbol substitutions. They are identical across files; each Phase-4 task lists the symbols present in its file.

| Old (macos_ui) | New (facade) | Notes |
|---|---|---|
| `import 'package:macos_ui/macos_ui.dart';` | `import 'package:pinboard_wizard/src/ui/ui.dart';` | one per file |
| `PushButton(controlSize: ControlSize.X, secondary: b, color: c, onPressed: f, child: w)` | `AppButton(size: AppButtonSize.X, secondary: b, color: c, onPressed: f, child: w)` | `ControlSize.large→AppButtonSize.large`, `regular→regular`, `small→small`, `mini→mini` |
| `MacosIconButton(icon: w, onPressed: f, backgroundColor: c)` | `AppIconButton(icon: w, onPressed: f, backgroundColor: c)` | |
| `MacosIcon(icon, color: c, size: s)` | `Icon(icon, color: c, size: s)` | plain Flutter `Icon` |
| `MacosTextField(controller:, placeholder:, placeholderStyle:, maxLines:, focusNode:, onChanged:, suffix:)` | `AppTextField(controller:, placeholder:, placeholderStyle:, maxLines:, focusNode:, onChanged:, suffixIcon:)` | `suffix`→`suffixIcon` |
| `MacosSearchField(controller:, placeholder:, onChanged:)` | `AppSearchField(controller:, placeholder:, onChanged:)` | |
| `MacosSwitch(value:, onChanged:, size: ControlSize.mini)` | `AppSwitch(value:, onChanged:, mini: true)` | drop `ControlSize`; `mini:true` only when size was `.mini` |
| `MacosCheckbox(value:, onChanged:)` | `AppCheckbox(value:, onChanged:)` | |
| `MacosRadioButton<T>(value:, groupValue:, onChanged:)` | `AppRadio<T>(value:, groupValue:, onChanged:)` | |
| `MacosListTile(leading:, title:, subtitle:)` | `AppListTile(leading:, title:, subtitle:)` | |
| `MacosTooltip(message:, child:)` | `AppTooltip(message:, child:)` | |
| `ProgressCircle()` / `ProgressCircle(radius: r)` | `AppProgress()` / `AppProgress(radius: r)` | |
| `MacosTabController(length: n)` | `AppTabController(length: n)` | |
| `MacosTabView(controller:, tabs:, children:)` | `AppTabView(controller:, tabs:, children:)` | |
| `MacosTab(label: s)` | `AppTab(label: s)` | |
| `MacosSheet(child: w)` | `AppSheet(child: w)` | |
| `showMacosSheet<T>(context:, builder:)` | `showAppSheet<T>(context:, builder:)` | |
| `MacosAlertDialog(appIcon:, title:, message:, primaryButton:, secondaryButton:, suppress:)` | `AppAlertDialog(appIcon:, title:, message:, primaryButton:, secondaryButton:, suppress:)` | |
| `showMacosAlertDialog<T>(context:, builder:)` | `showAppAlertDialog<T>(context:, builder:)` | |
| `MacosTheme.of(context).typography.largeTitle` | `context.appTypography.largeTitle` | also `title2`, `headline`, `body` |
| `MacosTheme.of(context).brightness` / `MacosTheme.brightnessOf(context)` | `context.appBrightness` | |
| `MacosTheme.of(context).canvasColor` | `AppColors.canvas.resolveFrom(context)` | |
| `MacosColors.separatorColor` | `AppColors.separator` | |
| `MacosColors.labelColor` | `AppColors.label` | |
| `MacosColors.secondaryLabelColor` | `AppColors.secondaryLabel` | |
| `MacosColors.tertiaryLabelColor` | `AppColors.tertiaryLabel` | |
| `MacosColors.controlBackgroundColor` (+`.darkColor`) | `AppColors.controlBackground` (+`.darkColor`) | `AppColors.controlBackground` is a `CupertinoDynamicColor` |
| `MacosColors.controlAccentColor` | `AppColors.accent` | |
| `MacosColors.system{Red,Orange,Green,Blue,Purple,Gray}Color` | `AppColors.system{Red,Orange,Green,Blue,Purple,Grey}` | |
| `.resolveFrom(context)` on any of the above | unchanged | `AppColors.*` are `CupertinoDynamicColor` and keep `.resolveFrom` |
| existing `context.secondaryLabelColor` etc. (from `theme_extensions.dart`) | unchanged names, now provided by facade | just repoint the import |

---

## Phase 1 — Dependencies

### Task 1: Add liquid_glass_widgets + macos_window_utils (keep macos_ui for now)

**Files:**
- Modify: `pubspec.yaml:17` (dependencies block)

**Interfaces:**
- Produces: the two packages resolvable for import in every later task.

- [ ] **Step 1: Add the dependencies**

In `pubspec.yaml`, keep `macos_ui: ^2.2.2` for now and add these two lines under `dependencies:` (immediately after the `macos_ui` line):

```yaml
  macos_ui: ^2.2.2
  liquid_glass_widgets: ^0.21.1
  macos_window_utils: ^1.9.1
```

- [ ] **Step 2: Resolve**

Run: `flutter pub get`
Expected: resolves with no version conflicts (Flutter 3.44 satisfies liquid_glass's ≥3.41 floor).

- [ ] **Step 3: Verify the app still builds unchanged**

Run: `flutter analyze lib`
Expected: no NEW errors (same baseline as before the change).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build: add liquid_glass_widgets and macos_window_utils deps"
```

---

## Phase 2 — Build the `lib/src/ui/` facade

The facade compiles against `liquid_glass_widgets` + Flutter only; it does not touch `macos_ui`. After Phase 2 the app still uses `macos_ui` everywhere — nothing is wired up yet.

### Task 2: Token layer

**Files:**
- Create: `lib/src/ui/tokens/app_colors.dart`
- Create: `lib/src/ui/tokens/app_typography.dart`
- Create: `lib/src/ui/tokens/context_ext.dart`
- Create: `lib/src/ui/tokens/app_theme.dart`

**Interfaces:**
- Produces: `AppColors` (static `CupertinoDynamicColor` tokens: `separator`, `label`, `secondaryLabel`, `tertiaryLabel`, `systemRed/Orange/Green/Blue/Purple/Grey`, `accent`, `controlBackground`, `canvas`); `context.appTypography.{largeTitle,title2,headline,body}`; `context.appBrightness`, `context.isDarkMode`, `context.canvasColor`, `context.secondaryLabelColor`, `context.tertiaryLabelColor`, `context.helperTextColor`, `context.subtitleTextColor`, `context.urlTextColor`; `appLightTheme()`, `appDarkTheme()`, `appGlassTheme()`.

- [ ] **Step 1: Create `app_colors.dart`**

```dart
import 'package:flutter/cupertino.dart';

/// Color tokens replacing macos_ui's `MacosColors`.
/// All are `CupertinoDynamicColor` so `.resolveFrom(context)` and `.darkColor` work.
class AppColors {
  const AppColors._();

  static const CupertinoDynamicColor separator = CupertinoColors.separator;
  static const CupertinoDynamicColor label = CupertinoColors.label;
  static const CupertinoDynamicColor secondaryLabel =
      CupertinoColors.secondaryLabel;
  static const CupertinoDynamicColor tertiaryLabel =
      CupertinoColors.tertiaryLabel;

  static const CupertinoDynamicColor systemRed = CupertinoColors.systemRed;
  static const CupertinoDynamicColor systemOrange =
      CupertinoColors.systemOrange;
  static const CupertinoDynamicColor systemGreen = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor systemBlue = CupertinoColors.systemBlue;
  static const CupertinoDynamicColor systemPurple =
      CupertinoColors.systemPurple;
  static const CupertinoDynamicColor systemGrey = CupertinoColors.systemGrey;

  /// Accent (was `MacosColors.controlAccentColor`).
  static const CupertinoDynamicColor accent = CupertinoColors.systemBlue;

  /// Control surface (was `MacosColors.controlBackgroundColor`).
  static const CupertinoDynamicColor controlBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF3A3A3C),
  );

  /// Window canvas (was `MacosTheme.of(context).canvasColor`).
  static const CupertinoDynamicColor canvas =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFECECEC),
    darkColor: Color(0xFF1E1E1E),
  );
}
```

- [ ] **Step 2: Create `app_typography.dart`**

```dart
import 'package:flutter/cupertino.dart';

/// Text styles replacing `MacosTheme.of(context).typography.*`.
class AppTypography {
  const AppTypography(this._context);
  final BuildContext _context;

  Color get _label => CupertinoColors.label.resolveFrom(_context);

  TextStyle get largeTitle =>
      TextStyle(fontSize: 26, fontWeight: FontWeight.w400, color: _label);
  TextStyle get title2 =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: _label);
  TextStyle get headline =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _label);
  TextStyle get body =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: _label);
}

extension AppTypographyX on BuildContext {
  AppTypography get appTypography => AppTypography(this);
}
```

- [ ] **Step 3: Create `context_ext.dart`** (reproduces the old `theme_extensions.dart` getters)

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppThemeContext on BuildContext {
  Brightness get appBrightness => Theme.of(this).brightness;
  bool get isDarkMode => appBrightness == Brightness.dark;

  Color get canvasColor => AppColors.canvas.resolveFrom(this);

  Color get secondaryLabelColor => isDarkMode
      ? AppColors.systemGrey.darkColor
      : AppColors.secondaryLabel.resolveFrom(this);

  Color get tertiaryLabelColor => isDarkMode
      ? AppColors.tertiaryLabel.resolveFrom(this)
      : AppColors.secondaryLabel.resolveFrom(this);

  Color get helperTextColor => isDarkMode
      ? AppColors.systemGrey.resolveFrom(this)
      : AppColors.secondaryLabel.resolveFrom(this);

  Color get subtitleTextColor => helperTextColor;

  Color get urlTextColor => isDarkMode
      ? AppColors.secondaryLabel.resolveFrom(this)
      : AppColors.label.resolveFrom(this).withValues(alpha: 0.75);
}
```

- [ ] **Step 4: Create `app_theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'app_colors.dart';

ThemeData appLightTheme() => ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorSchemeSeed: AppColors.accent.color,
      scaffoldBackgroundColor: Colors.transparent,
    );

ThemeData appDarkTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: AppColors.accent.color,
      scaffoldBackgroundColor: Colors.transparent,
    );

/// App-wide glass defaults passed to `LiquidGlassWidgets.wrap(theme:)`.
GlassThemeData appGlassTheme() => GlassThemeData.simple(
      blur: 8,
      thickness: 24,
      quality: GlassQuality.standard,
    );
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/src/ui/tokens`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/src/ui/tokens
git commit -m "feat(ui): add liquid glass token layer (colors, typography, theme)"
```

---

### Task 3: Glass-wrapper controls

**Files:**
- Create: `lib/src/ui/controls/app_button.dart`
- Create: `lib/src/ui/controls/app_icon_button.dart`
- Create: `lib/src/ui/controls/app_text_field.dart`
- Create: `lib/src/ui/controls/app_search_field.dart`
- Create: `lib/src/ui/controls/app_switch.dart`
- Create: `lib/src/ui/controls/app_list_tile.dart`
- Create: `lib/src/ui/controls/app_progress.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 2).
- Produces: `AppButton`, `AppButtonSize {large,regular,small,mini}`, `AppIconButton`, `AppTextField`, `AppSearchField`, `AppSwitch`, `AppListTile`, `AppProgress`.

- [ ] **Step 1: Create `app_button.dart`** (glass push-button; built on `GlassContainer` because `GlassButton` is an icon/oval control, not a content-sized text button)

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../tokens/app_colors.dart';

enum AppButtonSize { large, regular, small, mini }

/// Text push-button on a glass surface. Replaces macos_ui `PushButton`.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.secondary = false,
    this.color,
    this.size = AppButtonSize.regular,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool secondary;
  final Color? color;
  final AppButtonSize size;

  EdgeInsets get _padding {
    switch (size) {
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case AppButtonSize.regular:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case AppButtonSize.mini:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final accent = color ?? AppColors.accent.resolveFrom(context);
    final fill = secondary
        ? AppColors.controlBackground.resolveFrom(context)
        : accent;
    final fg = secondary ? AppColors.label.resolveFrom(context) : Colors.white;
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500),
      child: IconTheme.merge(
        data: IconThemeData(color: fg, size: 16),
        child: child,
      ),
    );
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GlassContainer(
        quality: GlassQuality.standard,
        alignment: Alignment.center,
        padding: _padding,
        shape: const LiquidRoundedSuperellipse(borderRadius: 8),
        settings: LiquidGlassSettings(
          glassColor: fill.withValues(alpha: secondary ? 0.5 : 0.9),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? onPressed : null,
            child: content,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `app_icon_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Icon button. Replaces macos_ui `MacosIconButton`.
/// When `backgroundColor == Colors.transparent`, renders a plain icon button
/// (preserving the borderless look some call-sites request); otherwise a
/// `GlassIconButton`.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.size = 32,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (backgroundColor == Colors.transparent) {
      return IconButton(
        onPressed: onPressed,
        icon: icon,
        iconSize: size * 0.5,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
      );
    }
    return GlassIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      quality: GlassQuality.standard,
    );
  }
}
```

- [ ] **Step 3: Create `app_text_field.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Text field. Replaces macos_ui `MacosTextField` (wraps `GlassTextField`).
/// `maxLines: null` (unbounded editors) maps to a very large line cap since
/// `GlassTextField.maxLines` is a non-nullable `int`.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.placeholderStyle,
    this.maxLines = 1,
    this.onChanged,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextStyle? placeholderStyle;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return GlassTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      placeholderStyle: placeholderStyle,
      maxLines: maxLines ?? 100000,
      onChanged: onChanged,
      suffixIcon: suffixIcon,
      onSuffixTap: onSuffixTap,
      obscureText: obscureText,
      quality: GlassQuality.standard,
    );
  }
}
```

- [ ] **Step 4: Create `app_search_field.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Search field. Replaces macos_ui `MacosSearchField` (wraps `GlassSearchBar`).
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.placeholder = 'Search',
    this.onChanged,
  });

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSearchBar(
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
      quality: GlassQuality.standard,
    );
  }
}
```

- [ ] **Step 5: Create `app_switch.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Toggle switch. Replaces macos_ui `MacosSwitch`. `mini: true` maps the old
/// `ControlSize.mini` to a smaller track.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.mini = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    return GlassSwitch(
      value: value,
      onChanged: onChanged,
      width: mini ? 40 : 58,
      height: mini ? 20 : 26,
      quality: GlassQuality.standard,
    );
  }
}
```

- [ ] **Step 6: Create `app_list_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// List tile. Replaces macos_ui `MacosListTile` (wraps `GlassListTile`).
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 7: Create `app_progress.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Indeterminate spinner. Replaces macos_ui `ProgressCircle`.
/// The old default radius was 10; `size = radius * 2`.
class AppProgress extends StatelessWidget {
  const AppProgress({super.key, this.radius = 10});
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GlassProgressIndicator.circular(
      size: radius * 2,
      quality: GlassQuality.standard,
    );
  }
}
```

- [ ] **Step 8: Analyze**

Run: `flutter analyze lib/src/ui/controls`
Expected: No issues found. (If `GlassContainer.settings`/`LiquidRoundedSuperellipse`/`GlassTextField.onSuffixTap` names differ from the resolved package, read `~/.pub-cache/hosted/pub.dev/liquid_glass_widgets-0.21.1/lib/` for the exact symbol and correct it — do NOT invent names.)

- [ ] **Step 9: Commit**

```bash
git add lib/src/ui/controls
git commit -m "feat(ui): add glass-wrapper controls (button, field, switch, etc.)"
```

---

### Task 4: Local controls (no library equivalent)

**Files:**
- Create: `lib/src/ui/controls/app_checkbox.dart`
- Create: `lib/src/ui/controls/app_radio.dart`
- Create: `lib/src/ui/controls/app_tooltip.dart`
- Create: `lib/src/ui/controls/app_tabs.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 2).
- Produces: `AppCheckbox`, `AppRadio<T>`, `AppTooltip`, `AppTabController`, `AppTab`, `AppTabView`.

- [ ] **Step 1: Create `app_checkbox.dart`**

```dart
import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';

/// Checkbox. No `liquid_glass_widgets` equivalent — local glass-styled control.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent.resolveFrom(context);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: value ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? accent : AppColors.separator.resolveFrom(context),
            width: 1,
          ),
        ),
        child: value
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : null,
      ),
    );
  }
}
```

- [ ] **Step 2: Create `app_radio.dart`**

```dart
import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';

/// Radio button. No `liquid_glass_widgets` equivalent — local control.
class AppRadio<T> extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final accent = AppColors.accent.resolveFrom(context);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accent : AppColors.separator.resolveFrom(context),
            width: 1.5,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
```

- [ ] **Step 3: Create `app_tooltip.dart`**

```dart
import 'package:flutter/material.dart';

/// Tooltip. No `liquid_glass_widgets` equivalent — wraps Flutter `Tooltip`.
class AppTooltip extends StatelessWidget {
  const AppTooltip({super.key, required this.message, required this.child});
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(message: message, child: child);
}
```

- [ ] **Step 4: Create `app_tabs.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../tokens/app_colors.dart';

/// Tab controller. Replaces macos_ui `MacosTabController`.
class AppTabController extends ChangeNotifier {
  AppTabController({required this.length, int initialIndex = 0})
      : _index = initialIndex;
  final int length;
  int _index;
  int get index => _index;
  set index(int value) {
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }
}

/// Tab descriptor. Replaces macos_ui `MacosTab`.
class AppTab {
  const AppTab({required this.label});
  final String label;
}

/// Tabbed container. Replaces macos_ui `MacosTabView`. Glass segmented header
/// over an `IndexedStack` body.
class AppTabView extends StatelessWidget {
  const AppTabView({
    super.key,
    required this.controller,
    required this.tabs,
    required this.children,
  }) : assert(tabs.length == children.length);

  final AppTabController controller;
  final List<AppTab> tabs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final accent = AppColors.accent.resolveFrom(context);
        final label = AppColors.label.resolveFrom(context);
        return Column(
          children: [
            GlassContainer(
              quality: GlassQuality.standard,
              padding: const EdgeInsets.all(4),
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < tabs.length; i++)
                    GestureDetector(
                      onTap: () => controller.index = i,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: controller.index == i
                              ? accent.withValues(alpha: 0.9)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 13,
                            color: controller.index == i
                                ? Colors.white
                                : label,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: controller.index, children: children),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/src/ui/controls`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/src/ui/controls
git commit -m "feat(ui): add local controls (checkbox, radio, tooltip, tabs)"
```

---

### Task 5: Overlays

**Files:**
- Create: `lib/src/ui/overlays/app_dialog.dart`
- Create: `lib/src/ui/overlays/app_sheet.dart`

**Interfaces:**
- Produces: `AppAlertDialog`, `showAppAlertDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible})`, `AppSheet`, `showAppSheet<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible})`.

- [ ] **Step 1: Create `app_dialog.dart`** (local glass panel — `GlassDialog.show`'s `List<GlassDialogAction>` model does not fit the appIcon + up-to-3 arbitrary-button shape)

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Alert dialog. Replaces macos_ui `MacosAlertDialog`. Local glass panel built
/// on `GlassContainer`.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.appIcon,
    required this.title,
    this.message,
    required this.primaryButton,
    this.secondaryButton,
    this.suppress,
  });

  final Widget? appIcon;
  final Widget title;
  final Widget? message;
  final Widget primaryButton;
  final Widget? secondaryButton;
  final Widget? suppress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: GlassContainer(
          quality: GlassQuality.standard,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (appIcon != null) ...[appIcon!, const SizedBox(height: 12)],
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                child: title,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                  child: message!,
                ),
              ],
              const SizedBox(height: 20),
              primaryButton,
              if (secondaryButton != null) ...[
                const SizedBox(height: 8),
                secondaryButton!,
              ],
              if (suppress != null) ...[
                const SizedBox(height: 8),
                suppress!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents a dialog. Replaces macos_ui `showMacosAlertDialog`.
Future<T?> showAppAlertDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}
```

- [ ] **Step 2: Create `app_sheet.dart`** (centered desktop modal, not the mobile bottom-sheet `GlassSheet`)

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Modal sheet panel. Replaces macos_ui `MacosSheet`.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(quality: GlassQuality.standard, child: child),
    );
  }
}

/// Presents a modal sheet. Replaces macos_ui `showMacosSheet`.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/src/ui/overlays`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/src/ui/overlays
git commit -m "feat(ui): add glass alert dialog and sheet overlays"
```

---

### Task 6: Layout shell (window + sidebar)

**Files:**
- Create: `lib/src/ui/layout/glass_window_scaffold.dart`
- Create: `lib/src/ui/layout/glass_sidebar.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 2). Reads assets `assets/wallpaper_light.png` / `assets/wallpaper_dark.png` (created in Task 8).
- Produces: `GlassWindowScaffold({required Widget sidebar, required Widget body})`; `GlassSidebar({required List<GlassSidebarItem> items, required int selectedIndex, required ValueChanged<int> onSelected, Widget? footer, double width})`; `GlassSidebarItem({required IconData icon, required String label})`.

- [ ] **Step 1: Create `glass_window_scaffold.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Desktop shell: muted wallpaper backdrop + [sidebar] beside [body].
/// Replaces macos_ui `MacosWindow` + `ContentArea`.
class GlassWindowScaffold extends StatelessWidget {
  const GlassWindowScaffold({
    super.key,
    required this.sidebar,
    required this.body,
  });

  final Widget sidebar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallpaper =
        isDark ? 'assets/wallpaper_dark.png' : 'assets/wallpaper_light.png';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidGlassScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(wallpaper, fit: BoxFit.cover),
            Row(
              children: [
                sidebar,
                Expanded(child: body),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `glass_sidebar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../tokens/app_colors.dart';

/// One sidebar entry. Replaces macos_ui `SidebarItem`.
class GlassSidebarItem {
  const GlassSidebarItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Glass navigation sidebar. Replaces macos_ui `Sidebar` + `SidebarItems`.
class GlassSidebar extends StatelessWidget {
  const GlassSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.footer,
    this.width = 220,
  });

  final List<GlassSidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? footer;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassContainer(
        quality: GlassQuality.standard,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28), // clear transparent titlebar/traffic lights
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => _SidebarRow(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassSidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent.resolveFrom(context);
    final labelColor = AppColors.label.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 18, color: selected ? accent : labelColor),
                const SizedBox(width: 10),
                Text(item.label,
                    style: TextStyle(fontSize: 13, color: labelColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/src/ui/layout`
Expected: No issues found. (Image assets are wired in Task 8; a missing asset only fails at runtime, not analysis.)

- [ ] **Step 4: Commit**

```bash
git add lib/src/ui/layout
git commit -m "feat(ui): add glass window scaffold and sidebar shell"
```

---

### Task 7: Barrel export + facade smoke test

**Files:**
- Create: `lib/src/ui/ui.dart`
- Test: `test/ui/facade_smoke_test.dart`

**Interfaces:**
- Consumes: every facade symbol from Tasks 2–6.
- Produces: `package:pinboard_wizard/src/ui/ui.dart` exporting the whole facade (does NOT re-export `liquid_glass_widgets` — the dependency stays encapsulated).

- [ ] **Step 1: Create `ui.dart`**

```dart
// Liquid Glass facade for Pinboard Wizard.
// Encapsulates liquid_glass_widgets; call-sites import only this file.
export 'tokens/app_colors.dart';
export 'tokens/app_typography.dart';
export 'tokens/context_ext.dart';
export 'tokens/app_theme.dart';

export 'layout/glass_window_scaffold.dart';
export 'layout/glass_sidebar.dart';

export 'controls/app_button.dart';
export 'controls/app_icon_button.dart';
export 'controls/app_text_field.dart';
export 'controls/app_search_field.dart';
export 'controls/app_switch.dart';
export 'controls/app_checkbox.dart';
export 'controls/app_radio.dart';
export 'controls/app_list_tile.dart';
export 'controls/app_tooltip.dart';
export 'controls/app_progress.dart';
export 'controls/app_tabs.dart';

export 'overlays/app_dialog.dart';
export 'overlays/app_sheet.dart';
```

- [ ] **Step 2: Write the failing smoke test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';

Widget _host(Widget child) => LiquidGlassWidgets.wrap(
      child: MaterialApp(
        theme: appLightTheme(),
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('facade controls build', (tester) async {
    await tester.pumpWidget(_host(
      Column(
        children: [
          AppButton(child: const Text('Go'), onPressed: () {}),
          AppButton(child: const Text('Off'), onPressed: null),
          AppIconButton(icon: const Icon(Icons.add), onPressed: () {}),
          AppSwitch(value: true, onChanged: (_) {}),
          AppCheckbox(value: true, onChanged: (_) {}),
          AppRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
          const AppProgress(),
          const AppTooltip(message: 'hi', child: Icon(Icons.info)),
          const AppListTile(title: Text('Tile')),
        ],
      ),
    ));
    expect(find.text('Go'), findsOneWidget);
    expect(find.byType(AppSwitch), findsOneWidget);
    expect(find.byType(AppProgress), findsOneWidget);
  });

  testWidgets('window scaffold + sidebar build', (tester) async {
    await tester.pumpWidget(_host(
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
    ));
    expect(find.text('content'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the smoke test**

Run: `flutter test test/ui/facade_smoke_test.dart`
Expected: PASS. (The `GlassWindowScaffold` test tolerates the missing wallpaper asset — `Image.asset` shows an error box in tests without failing the pump. If it does throw, add `wrapWithDefaultAssetBundle` or precache; but pump should succeed.)

- [ ] **Step 4: Commit**

```bash
git add lib/src/ui/ui.dart test/ui/facade_smoke_test.dart
git commit -m "feat(ui): add facade barrel + smoke test"
```

---

## Phase 3 — Wallpaper assets

### Task 8: Generate and register muted wallpapers

**Files:**
- Create: `assets/wallpaper_light.png`
- Create: `assets/wallpaper_dark.png`
- Modify: `pubspec.yaml` (flutter `assets:` list)

**Interfaces:**
- Produces: the two asset paths consumed by `GlassWindowScaffold` (Task 6).

- [ ] **Step 1: Create the two wallpaper PNGs**

Produce two 1536×1024 PNGs that are muted and low-contrast so content stays legible:
- `assets/wallpaper_light.png` — soft near-white cool-grey vertical gradient, top `#EDEFF2` → bottom `#E3E7EC`, no sharp detail.
- `assets/wallpaper_dark.png` — deep muted charcoal-blue vertical gradient, top `#1C1E24` → bottom `#141519`, no sharp detail.

Generate them with the image tool (prompt: "extremely soft, muted, low-contrast blurred vertical gradient wallpaper, [colors], no detail, no texture, minimal, desktop background") or any gradient generator. Verify each is a valid PNG at the target path (`file assets/wallpaper_light.png` reports PNG image data).

- [ ] **Step 2: Register the assets in `pubspec.yaml`**

Under `flutter: assets:` (currently only `assets/app_logo.png`), add:

```yaml
  assets:
    - assets/app_logo.png
    - assets/wallpaper_light.png
    - assets/wallpaper_dark.png
```

- [ ] **Step 3: Verify**

Run: `flutter pub get && flutter analyze lib/src/ui/layout`
Expected: resolves; no issues.

- [ ] **Step 4: Commit**

```bash
git add assets/wallpaper_light.png assets/wallpaper_dark.png pubspec.yaml
git commit -m "feat(ui): add muted light/dark wallpapers"
```

---

## Phase 4 — Migrate call-sites off macos_ui

Apply the **Migration Rules** table (top of this document) to each file: swap the import to `package:pinboard_wizard/src/ui/ui.dart`, rename the symbols listed for that file, and replace `MacosTheme.*`/`MacosColors.*` with tokens.

> **Mid-phase runtime note:** Until Task 15 (main.dart) flips the root to `MaterialApp`, and until every page is migrated, the app will not run fully (un-migrated pages still call `MacosTheme.of`, which needs the `MacosApp` ancestor removed in Task 15). This is expected. Each task's gate is `flutter analyze <file>` reporting **no new errors**; the end-to-end runtime check is Phase 6. `flutter analyze` may report un-migrated files still referencing `macos_ui` — that is the pre-existing baseline, not a regression.

Per-task verification for Tasks 9–15:
- Run `flutter analyze <the file(s) in the task>` → the migrated file(s) have no errors.
- Commit.

### Task 9: Common widgets

**Files (Modify):**
- `lib/src/common/widgets/bookmark_tile.dart` — symbols: `MacosTheme.brightnessOf`/`MacosTheme.of`, `MacosColors.{controlBackgroundColor(.darkColor),separatorColor,secondaryLabelColor,tertiaryLabelColor}`, `MacosSwitch(size: ControlSize.mini)`, `MacosIconButton`, `MacosIcon`. Note: this file also uses `flutter_html` colors via `MacosColors.*.resolveFrom(context)` → `AppColors.*.resolveFrom(context)`.
- `lib/src/common/widgets/dialogs.dart` — `showMacosAlertDialog`→`showAppAlertDialog`, `MacosAlertDialog`→`AppAlertDialog`, `PushButton`→`AppButton`, `MacosColors.system{Orange,Red,Green}Color`→`AppColors.system{Orange,Red,Green}`, `MacosIcon`→`Icon`.
- `lib/src/common/widgets/keyboard_shortcuts.dart` — `showMacosSheet`→`showAppSheet`.
- `lib/src/common/widgets/validated_secret_field.dart` — `MacosTextField(suffix:)`→`AppTextField(suffixIcon:)`, `MacosIconButton`→`AppIconButton`, `MacosIcon`→`Icon`, `ProgressCircle`→`AppProgress`, `MacosColors.system{Green,Red}Color`→`AppColors.system{Green,Red}`. This file has `import 'package:flutter/cupertino.dart' hide OverlayVisibilityMode;` — keep the cupertino import (drop the `hide`, which was for a macos_ui clash; if analyzer flags an unused hide, remove `hide OverlayVisibilityMode`).

- [ ] **Step 1: Migrate the four files** per the Migration Rules table and the symbol notes above.
- [ ] **Step 2: Analyze**  `flutter analyze lib/src/common/widgets` → migrated files clean.
- [ ] **Step 3: Commit**  `git commit -am "refactor(ui): migrate common widgets to liquid glass facade"`

### Task 10: Bookmarks pages

**Files (Modify):**
- `lib/src/pages/bookmarks/add_bookmark_dialog.dart` — `MacosSheet`→`AppSheet`, `PushButton`→`AppButton`, `MacosTextField`→`AppTextField`, `MacosIcon`→`Icon`, `MacosIconButton`→`AppIconButton`, `MacosColors.*`→`AppColors.*`, `MacosTheme.of(context).typography.largeTitle`→`context.appTypography.largeTitle`, `ProgressCircle`→`AppProgress`.
- `lib/src/pages/bookmarks/edit_bookmark_dialog.dart` — same symbol set as add_bookmark_dialog.
- `lib/src/pages/bookmarks/bookmarks_page.dart` — `PushButton`→`AppButton`, `MacosSearchField`→`AppSearchField`, `MacosSwitch`→`AppSwitch`, `MacosIcon`→`Icon`, `ProgressCircle`→`AppProgress`, `showMacosSheet`→`showAppSheet`, `showMacosAlertDialog`→`showAppAlertDialog`, `MacosTheme.of(context).{canvasColor,brightness}`→`context.canvasColor`/`context.appBrightness`, `MacosColors.*`→`AppColors.*`.
- `lib/src/pages/bookmarks/pin_category_dialog.dart` — `MacosAlertDialog`→`AppAlertDialog`, `showMacosAlertDialog`→`showAppAlertDialog`, `MacosCheckbox`→`AppCheckbox`, `MacosTextField`→`AppTextField`, `PushButton`→`AppButton`, `MacosColors.*`→`AppColors.*`.
- `lib/src/pages/bookmarks/tags_panel.dart` — `MacosIconButton`→`AppIconButton`, `MacosIcon`→`Icon`, `MacosTheme.of(context).{canvasColor,brightness}`→tokens, `MacosColors.*`→`AppColors.*`.
- `lib/src/pages/bookmarks/resizable_split_view.dart` — `MacosColors.{controlAccentColor,separatorColor}`→`AppColors.{accent,separator}`. (No `MacosTheme`; keep `flutter/material.dart` import, just swap the macos_ui import for the facade.)

- [ ] **Step 1: Migrate the six files.**
- [ ] **Step 2: Analyze**  `flutter analyze lib/src/pages/bookmarks` → migrated files clean.
- [ ] **Step 3: Commit**  `git commit -am "refactor(ui): migrate bookmarks pages to liquid glass facade"`

### Task 11: Notes pages

**Files (Modify):**
- `lib/src/pages/notes/github_notes_page.dart` — `PushButton`→`AppButton`, `MacosIcon`→`Icon`, `ProgressCircle`(incl. `ProgressCircle(radius: 7)`)→`AppProgress`(`AppProgress(radius: 7)`), `showMacosAlertDialog`→`showAppAlertDialog`, `MacosAlertDialog`→`AppAlertDialog`, `MacosTheme.of(context).{brightness,canvasColor}`→tokens, `MacosColors.separatorColor`→`AppColors.separator`.
- `lib/src/pages/notes/resizable_split_view.dart` — same as bookmarks/resizable_split_view.dart. (If this is byte-identical to the bookmarks copy, still migrate the file that exists at this path.)
- `lib/src/pages/notes/widgets/conflict_resolution_dialog.dart` — `MacosAlertDialog`→`AppAlertDialog`, `showMacosAlertDialog`→`showAppAlertDialog`, `PushButton`(incl. `suppress:` button)→`AppButton`, `MacosIcon`→`Icon`, `MacosTheme.of(context).brightness`→`context.appBrightness`.
- `lib/src/pages/notes/widgets/github_note_tile.dart` — `MacosTooltip`→`AppTooltip`, `MacosIcon`→`Icon`, `MacosTheme.of(context).brightness`→`context.appBrightness`.
- `lib/src/pages/notes/widgets/markdown_editor.dart` — `MacosTextField(maxLines: null)`→`AppTextField(maxLines: null)` (verify the editor still expands to fill; the shim maps null → large line cap), `MacosIconButton`→`AppIconButton`, `MacosIcon`→`Icon`, `MacosTooltip`→`AppTooltip`, `PushButton`→`AppButton`, `MacosTheme.of(context).brightness`→`context.appBrightness`.
- `lib/src/pages/notes/widgets/new_note_form.dart` — `MacosTextField`(incl. `maxLines: null`)→`AppTextField`, `MacosIcon`→`Icon`, `PushButton`→`AppButton`, `MacosTheme.of(context).typography.{title2,headline}`→`context.appTypography.*`, `MacosTheme.of(context).brightness`→`context.appBrightness`.

- [ ] **Step 1: Migrate the files.**
- [ ] **Step 2: Analyze**  `flutter analyze lib/src/pages/notes` → migrated files clean.
- [ ] **Step 3: Commit**  `git commit -am "refactor(ui): migrate notes pages to liquid glass facade"`

### Task 12: Pinned pages

**Files (Modify):**
- `lib/src/pages/pinned/pinned_bookmark_tile.dart` — `showMacosAlertDialog`→`showAppAlertDialog`, `MacosAlertDialog`→`AppAlertDialog`, `PushButton`→`AppButton`, `MacosTheme.brightnessOf`/`MacosTheme.of`→`context.appBrightness`, `MacosColors.{tertiaryLabelColor,secondaryLabelColor,controlBackgroundColor(.darkColor),separatorColor,systemPurpleColor}`→`AppColors.*` (note `.withOpacity(0.3)` → keep or switch to `.withValues(alpha: 0.3)` to match the repo's newer style). Also repoint the `theme_extensions.dart` import to `ui.dart`.
- `lib/src/pages/pinned/pinned_page.dart` — `PushButton`→`AppButton`, `MacosIcon`→`Icon`, `showMacosAlertDialog`→`showAppAlertDialog`, `MacosAlertDialog`→`AppAlertDialog`, `MacosColors.*`/`MacosTheme.*`→tokens.

- [ ] **Step 1: Migrate the two files.**
- [ ] **Step 2: Analyze**  `flutter analyze lib/src/pages/pinned` → migrated files clean.
- [ ] **Step 3: Commit**  `git commit -am "refactor(ui): migrate pinned pages to liquid glass facade"`

### Task 13: Settings page

**Files (Modify):**
- `lib/src/pages/settings/settings_page.dart` — the largest file. Symbols: `MacosTabController`→`AppTabController`, `MacosTabView`→`AppTabView`, `MacosTab`→`AppTab`, `MacosRadioButton<TokenType>`→`AppRadio<TokenType>`, `PushButton`(sizes large/small)→`AppButton` (`ControlSize.small`→`AppButtonSize.small`), `MacosTextField`→`AppTextField`, `ValidatedSecretField` (already migrated in Task 9 — no change here), `showMacosAlertDialog`→`showAppAlertDialog`, `MacosAlertDialog`→`AppAlertDialog`, `MacosColors.*`→`AppColors.*`, and repoint the `theme_extensions.dart` import to `ui.dart`. Keep the existing `import 'package:flutter/cupertino.dart';`.

- [ ] **Step 1: Migrate `settings_page.dart`.** Pay attention to the `_tabController = MacosTabController(length: 4)` field type (`late MacosTabController` → `late AppTabController`) and the `MacosTabView(controller:, tabs:, children:)` block.
- [ ] **Step 2: Analyze**  `flutter analyze lib/src/pages/settings/settings_page.dart` → clean.
- [ ] **Step 3: Commit**  `git commit -am "refactor(ui): migrate settings page to liquid glass facade"`

### Task 14: Auth gate

**Files (Modify):**
- `lib/src/auth/auth_gate.dart` — `PushButton`→`AppButton`, `MacosTheme.of(context).typography.{largeTitle,body}`→`context.appTypography.*`. Keep the `flutter/cupertino.dart` import.

- [ ] **Step 1: Migrate `auth_gate.dart`.**
- [ ] **Step 2: Analyze**  `flutter analyze lib/src/auth/auth_gate.dart` → clean.
- [ ] **Step 3: Commit**  `git commit -am "refactor(ui): migrate auth gate to liquid glass facade"`

### Task 15: App root (main.dart) — the flip

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `GlassWindowScaffold`, `GlassSidebar`, `GlassSidebarItem`, `AppListTile`, `AppColors`, `appLightTheme`, `appDarkTheme`, `appGlassTheme` (facade); `LiquidGlassWidgets`, `WindowManipulator` (packages).

- [ ] **Step 1: Replace the imports**

Remove `import 'package:macos_ui/macos_ui.dart';`. Add:

```dart
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
```

Keep `import 'package:flutter/cupertino.dart';` (used for `CupertinoIcons`, `PlatformMenuBar`) and `import 'package:flutter/services.dart';`.

- [ ] **Step 2: Rewrite `main()` window bootstrap + wrap**

Replace:

```dart
  const config = MacosWindowUtilsConfig();
  await config.apply();
  await setup();
  runApp(PinboardWizard(version: packageInfo.version));
```

with (verified `macos_window_utils` sequence replicating `MacosWindowUtilsConfig().apply()`):

```dart
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
  runApp(LiquidGlassWidgets.wrap(
    theme: appGlassTheme(),
    child: PinboardWizard(version: packageInfo.version),
  ));
```

- [ ] **Step 3: Replace `MacosApp` with `MaterialApp`**

In `_PinboardWizardState.build`, change the returned `MacosApp(...)` to:

```dart
        return MaterialApp(
          title: 'Pinboard Wizard',
          navigatorKey: navigatorKey,
          themeMode: appTheme.mode,
          theme: appLightTheme(),
          darkTheme: appDarkTheme(),
          debugShowCheckedModeBanner: false,
          home: PlatformMenuBar(
            // ... unchanged menus + FocusScope + KeyboardShortcuts ...
```

Keep the `PlatformMenuBar`, `menuBarItems(...)`, `FocusScope`, and `KeyboardShortcuts` exactly as they are.

- [ ] **Step 4: Replace `MacosWindow`/`Sidebar`/`ContentArea`**

Replace the `MacosWindow(sidebar: Sidebar(...), child: ContentArea(...))` subtree (the `child:` of `KeyboardShortcuts`) with:

```dart
                child: GlassWindowScaffold(
                  sidebar: GlassSidebar(
                    selectedIndex: pageIndex,
                    onSelected: (i) => setState(() => pageIndex = i),
                    items: const [
                      GlassSidebarItem(
                          icon: CupertinoIcons.pin_fill, label: 'Pinned'),
                      GlassSidebarItem(
                          icon: CupertinoIcons.bookmark_fill, label: 'Bookmarks'),
                      GlassSidebarItem(
                          icon: CupertinoIcons.doc_text_fill, label: 'Notes'),
                      GlassSidebarItem(
                          icon: CupertinoIcons.gear_alt_fill, label: 'Settings'),
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
                      child: AppListTile(
                        leading: const AppLogo.small(),
                        title: const Text('Pinboard Wizard'),
                        subtitle: Text('Version ${widget.version}'),
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
```

- [ ] **Step 5: Analyze**  `flutter analyze lib/main.dart` → clean.
- [ ] **Step 6: Commit**  `git commit -am "refactor(ui): flip app root to MaterialApp + glass window shell"`

---

## Phase 5 — Remove macos_ui and clean up

### Task 16: Delete the old theme extensions

**Files:**
- Delete: `lib/src/common/extensions/theme_extensions.dart`

**Interfaces:**
- Consumes: confirmation that all three importers (`bookmark_tile.dart`, `pinned_bookmark_tile.dart`, `settings_page.dart`) now import `package:pinboard_wizard/src/ui/ui.dart` (which re-exports the identical getters via `context_ext.dart`) — done in Tasks 9, 12, 13.

- [ ] **Step 1: Confirm no importers remain**
Run: `grep -rn "extensions/theme_extensions" lib`
Expected: no matches.
- [ ] **Step 2: Delete the file**
```bash
git rm lib/src/common/extensions/theme_extensions.dart
```
- [ ] **Step 3: Analyze**  `flutter analyze lib` → no errors referencing the deleted file.
- [ ] **Step 4: Commit**  `git commit -m "refactor(ui): remove old macos theme_extensions (folded into facade)"`

### Task 17: Remove the macos_ui dependency

**Files:**
- Modify: `pubspec.yaml` (remove the `macos_ui: ^2.2.2` line)

- [ ] **Step 1: Remove the line**  Delete `  macos_ui: ^2.2.2` from `dependencies:`.
- [ ] **Step 2: Resolve**  `flutter pub get` → resolves without macos_ui.
- [ ] **Step 3: Prove it's gone**
Run: `grep -rn "macos_ui" lib`
Expected: **no matches.**
Run: `flutter analyze lib`
Expected: No issues found (0 errors). Any `macos_ui`-not-found error means a call-site was missed — fix it before continuing.
- [ ] **Step 4: Commit**  `git commit -am "build: remove unmaintained macos_ui dependency"`

### Task 18: Update the widget test

**Files:**
- Modify: `test/pages/bookmarks/add_bookmark_dialog_test.dart`

- [ ] **Step 1: Swap the import and test harness**
Replace `import 'package:macos_ui/macos_ui.dart';` with:
```dart
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
```
Replace `createTestWidget()`'s body:
```dart
  Widget createTestWidget() {
    return LiquidGlassWidgets.wrap(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) => AddBookmarkDialog()),
        ),
      ),
    );
  }
```

- [ ] **Step 2: Retype the finders**
Replace every `widget is PushButton` with `widget is AppButton`, every `tester.widget<PushButton>(...)` with `tester.widget<AppButton>(...)`, and `find.byType(MacosTextField)` with `find.byType(AppTextField)`. `AppButton.onPressed` and `AppButton.child` have the same names as the old `PushButton` fields, so the assertions (`pushButton.onPressed`, `.child is Row`) transfer unchanged (rename the local var if desired).

- [ ] **Step 3: Run the test**
Run: `flutter test test/pages/bookmarks/add_bookmark_dialog_test.dart`
Expected: PASS (same assertions, new widget types).

- [ ] **Step 4: Commit**  `git commit -am "test: update add_bookmark_dialog test to liquid glass facade"`

### Task 19: Update docs

**Files:**
- Modify: `CLAUDE.md`
- Modify: `lib/src/pages/notes/README.md`

- [ ] **Step 1: Update `CLAUDE.md`**
Replace the `# UI` bullet referencing `mac_ui` with:
```markdown
# UI

- Use the local Liquid Glass facade at `lib/src/ui/` (barrel `package:pinboard_wizard/src/ui/ui.dart`) for widgets, colors, and typography. It wraps `liquid_glass_widgets` and provides local shims (window shell, sidebar, tabs, radio, checkbox, tooltip, alert dialog, sheet) for controls the library lacks. Glass is for chrome; content lists stay opaque.
```

- [ ] **Step 2: Update `lib/src/pages/notes/README.md`**
Replace the `macos_ui components` / `MacosTheme.of(context).brightness` snippet (around line 342-345) with the facade equivalent:
```markdown
The UI uses the Liquid Glass facade (`lib/src/ui/`) and respects system theme:

\`\`\`dart
final isDark = context.isDarkMode;
\`\`\`
```

- [ ] **Step 3: Commit**  `git commit -am "docs: update UI guidance to liquid glass facade"`

---

## Phase 6 — Verification

### Task 20: Full verification + macOS smoke run

- [ ] **Step 1: Static analysis**
Run: `flutter analyze`
Expected: **No issues found.**

- [ ] **Step 2: No macos_ui anywhere**
Run: `grep -rn "macos_ui" lib test`
Expected: **no matches.** (Doc prose in `CLAUDE.md`/README already updated; if any remain there, they must read "liquid glass", not "macos_ui".)

- [ ] **Step 3: Test suite**
Run: `flutter test`
Expected: all tests pass (includes `test/ui/facade_smoke_test.dart` and the updated `add_bookmark_dialog_test.dart`).

- [ ] **Step 4: macOS smoke run** (manual)
Run: `flutter run -d macos`
Confirm each:
  - Window renders with the muted wallpaper; titlebar is transparent with visible traffic lights.
  - Glass sidebar shows Pinned / Bookmarks / Notes / Settings; clicking each switches the page; the selected row is accent-highlighted; the version tile shows in the footer.
  - Bookmarks: search field, unread `AppSwitch`, `Add` opens the glass sheet; add/edit dialogs submit; AI button enables only with a valid URL; tag chips select.
  - Notes: list renders on opaque surfaces and stays legible; new-note form and markdown editor `AppTextField`s expand and accept multi-line input; sync/retry buttons work; tooltips show on status icons; conflict dialog shows all three buttons.
  - Settings: the four `AppTabView` tabs switch; `AppRadio` token-type selection toggles; save/clear/test buttons work; `ValidatedSecretField` shows the spinner then the check/x icon.
  - Pinned: tiles legible; pin/unpin dialog works.
  - Toggle system appearance light↔dark: wallpaper, chrome, and text colors update; content stays legible in both.
- [ ] **Step 5: Final commit (if any smoke fixes were needed)**
```bash
git commit -am "fix(ui): address issues found in macOS smoke run"
```

---

## Self-Review

**Spec coverage:** Every spec section maps to tasks — deps (T1, T17), facade/tokens (T2), controls (T3–T4), overlays (T5), layout shell (T6), barrel+test (T7), wallpaper (T8), per-file migration incl. tabs/radio (T9–T15), theme-extensions fold (T2 + delete T16), test update (T18), docs (T19), verification incl. dark/light + readability (T20). Widget mapping table rows all have a producing task.

**Placeholder scan:** No "TBD/TODO/implement later". Every code step shows complete code. Migration tasks reference the single Migration Rules table plus the exact symbols per file (not "similar to Task N").

**Type consistency:** Facade symbols are defined once and referenced consistently — `AppButtonSize {large,regular,small,mini}`, `AppButton(child,onPressed,secondary,color,size)`, `AppTextField(...,suffixIcon,onSuffixTap)`, `AppSwitch(value,onChanged,mini)`, `AppRadio<T>(value,groupValue,onChanged: ValueChanged<T>?)`, `AppTabController(length)`/`AppTab(label)`/`AppTabView(controller,tabs,children)`, `showAppAlertDialog<T>(context,builder,barrierDismissible)`, `showAppSheet<T>(...)`, `GlassSidebar(items,selectedIndex,onSelected,footer,width)`, `GlassWindowScaffold(sidebar,body)`. The migration table and Task 15 use exactly these names.

**Known API risks (verify against resolved package source `~/.pub-cache/hosted/pub.dev/liquid_glass_widgets-0.21.1/` during Task 3/5, correct in place if a name differs — never invent):** `GlassContainer.settings`, `LiquidRoundedSuperellipse`, `GlassTextField.onSuffixTap`/`placeholder`, `GlassProgressIndicator.circular`. All were reported by source-verified research; treat a mismatch as a local fix, not a redesign.
