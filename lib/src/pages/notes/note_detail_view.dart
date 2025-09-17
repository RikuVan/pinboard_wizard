import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/models/note.dart';
import 'package:pinboard_wizard/src/pinboard/models/notes_response.dart';
import 'package:intl/intl.dart';

class NoteDetailView extends StatelessWidget {
  const NoteDetailView({
    super.key,
    required this.note,
    this.noteDetail,
    this.onEdit,
  });

  final Note note;
  final NoteDetailResponse? noteDetail;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final brightness = MacosTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(color: MacosTheme.of(context).canvasColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: MacosColors.separatorColor.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onEdit != null)
                      PushButton(
                        controlSize: ControlSize.mini,
                        secondary: true,
                        onPressed: onEdit,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MacosIcon(CupertinoIcons.pencil, size: 12),
                            const SizedBox(width: 4),
                            const Text('Edit'),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip(
                      context,
                      icon: CupertinoIcons.doc_text,
                      label: _formatLength(note.length),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      context,
                      icon: CupertinoIcons.clock,
                      label: 'Updated ${_formatDate(note.updatedAt)}',
                    ),
                    if (note.createdAt != note.updatedAt) ...[
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        context,
                        icon: CupertinoIcons.calendar,
                        label: 'Created ${_formatDate(note.createdAt)}',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (noteDetail == null) {
      return const Center(child: ProgressCircle());
    }

    final brightness = MacosTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            noteDetail!.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? const Color(0xFFDEDEDE) : Colors.black87,
              fontFamily: 'San Francisco',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final brightness = MacosTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : MacosColors.tertiaryLabelColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? Colors.white70 : MacosColors.secondaryLabelColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : MacosColors.secondaryLabelColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
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
      return '$length chars';
    } else if (length < 10000) {
      return '${(length / 1000).toStringAsFixed(1)}k chars';
    } else {
      return '${(length / 1000).round()}k chars';
    }
  }
}
