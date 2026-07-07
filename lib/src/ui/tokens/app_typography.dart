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
