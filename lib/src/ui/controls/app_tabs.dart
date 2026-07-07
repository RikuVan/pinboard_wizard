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
