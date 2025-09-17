import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class ResizableSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;
  final double minLeftWidth;
  final double minRightWidth;
  final double dividerWidth;

  const ResizableSplitView({
    super.key,
    required this.left,
    required this.right,
    this.initialRatio = 0.75,
    this.minLeftWidth = 200,
    this.minRightWidth = 200,
    this.dividerWidth = 1,
  });

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final dividerWidth = widget.dividerWidth;
        final availableWidth = totalWidth - dividerWidth;

        // Calculate widths based on ratio
        double leftWidth = availableWidth * _ratio;
        double rightWidth = availableWidth * (1 - _ratio);

        // Ensure minimum widths are respected
        if (leftWidth < widget.minLeftWidth) {
          leftWidth = widget.minLeftWidth;
          rightWidth = availableWidth - leftWidth;
        } else if (rightWidth < widget.minRightWidth) {
          rightWidth = widget.minRightWidth;
          leftWidth = availableWidth - rightWidth;
        }

        // Widths are now calculated and constrained

        return Row(
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            _buildDivider(context, totalWidth),
            SizedBox(width: rightWidth, child: widget.right),
          ],
        );
      },
    );
  }

  Widget _buildDivider(BuildContext context, double totalWidth) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          final availableWidth = totalWidth - widget.dividerWidth;
          final newRatio = (details.globalPosition.dx) / totalWidth;

          // Calculate what the widths would be with this ratio
          final newLeftWidth = availableWidth * newRatio;
          final newRightWidth = availableWidth * (1 - newRatio);

          // Only update if both widths would be above minimum
          if (newLeftWidth >= widget.minLeftWidth &&
              newRightWidth >= widget.minRightWidth) {
            _ratio = newRatio.clamp(0.1, 0.9);
          }
        });
      },
      onPanEnd: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: widget.dividerWidth,
          decoration: BoxDecoration(
            color: _isDragging
                ? MacosColors.controlAccentColor.withValues(alpha: 0.3)
                : MacosColors.separatorColor,
          ),
          child: Center(
            child: Container(width: 1, color: MacosColors.separatorColor),
          ),
        ),
      ),
    );
  }
}
