import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:timeago/timeago.dart' as timeago;

/// A tile widget for displaying a GitHub note in a list.
///
/// Shows:
/// - Note title
/// - Content preview
/// - Last updated time
/// - Sync status indicator (dirty, conflict, synced)
class GitHubNoteTile extends StatelessWidget {
  const GitHubNoteTile({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
  });

  /// The note to display
  final Note note;

  /// Whether this tile is currently selected
  final bool isSelected;

  /// Callback when the tile is tapped
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = context.appBrightness;
    final isDark = brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE5E5EA))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5EA),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            _buildStatusIndicator(),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    note.title ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Preview
                  if (note.contentPreview != null &&
                      note.contentPreview!.isNotEmpty)
                    Text(
                      note.contentPreview!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 6),

                  // Metadata
                  Row(
                    children: [
                      Text(
                        timeago.format(note.updatedAt, locale: 'en_short'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                      ),
                      if (note.contentLength > 0) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                        ),
                        Text(
                          _formatContentLength(note.contentLength),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    // Conflict takes precedence
    if (note.isConflict) {
      return const AppTooltip(
        message: 'Conflict detected',
        child: Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: Colors.red,
          size: 18,
        ),
      );
    }

    // Marked for deletion
    if (note.markedForDeletion) {
      return const AppTooltip(
        message: 'Marked for deletion',
        child: Icon(CupertinoIcons.trash, color: Colors.orange, size: 18),
      );
    }

    // Dirty (pending sync)
    if (note.isDirty) {
      return const AppTooltip(
        message: 'Pending sync',
        child: Icon(CupertinoIcons.clock, color: Colors.orange, size: 18),
      );
    }

    // Synced
    return const AppTooltip(
      message: 'Synced',
      child: Icon(
        CupertinoIcons.checkmark_circle_fill,
        color: Colors.green,
        size: 18,
      ),
    );
  }

  String _formatContentLength(int length) {
    if (length < 1000) {
      return '$length chars';
    } else if (length < 1000000) {
      return '${(length / 1000).toStringAsFixed(1)}K chars';
    } else {
      return '${(length / 1000000).toStringAsFixed(1)}M chars';
    }
  }
}
