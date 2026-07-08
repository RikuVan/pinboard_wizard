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
            ?footer,
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
    final fg = selected ? Colors.white : labelColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: fg),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
