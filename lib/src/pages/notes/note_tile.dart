import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/models/note.dart';
import 'package:intl/intl.dart';

class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
  });

  final Note note;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = MacosTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected
            ? MacosColors.controlAccentColor.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: MacosColors.separatorColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MacosListTile(
          onClick: onTap,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MacosColors.tertiaryLabelColor.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatLength(note.length),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white70
                            : MacosColors.secondaryLabelColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.doc_text,
                    size: 12,
                    color: isDark
                        ? Colors.white70
                        : MacosColors.secondaryLabelColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_formatDate(note.updatedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white70
                          : MacosColors.secondaryLabelColor,
                    ),
                  ),
                  const Spacer(),
                  if (note.createdAt != note.updatedAt) ...[
                    Text(
                      'Created ${_formatDate(note.createdAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white60
                            : MacosColors.tertiaryLabelColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          subtitle: const SizedBox.shrink(),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  String _formatLength(int length) {
    if (length < 1000) {
      return '${length}c';
    } else if (length < 10000) {
      return '${(length / 1000).toStringAsFixed(1)}k';
    } else {
      return '${(length / 1000).round()}k';
    }
  }
}
