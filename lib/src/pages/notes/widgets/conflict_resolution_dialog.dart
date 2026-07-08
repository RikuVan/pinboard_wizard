import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';

/// Dialog for resolving sync conflicts between local and remote note versions.
///
/// Presents the user with options to:
/// - Keep original (discard local changes)
/// - Keep yours (replace with conflict version)
/// - View both files side-by-side for manual merge
class ConflictResolutionDialog extends StatelessWidget {
  const ConflictResolutionDialog({
    super.key,
    required this.originalNote,
    required this.conflictNote,
    required this.onKeepOriginal,
    required this.onKeepYours,
    required this.onViewBoth,
  });

  /// The original note from GitHub
  final Note originalNote;

  /// The conflict version (local changes)
  final Note conflictNote;

  /// Callback when user chooses to keep the original version
  final VoidCallback onKeepOriginal;

  /// Callback when user chooses to keep their version
  final VoidCallback onKeepYours;

  /// Callback when user wants to view both files
  final VoidCallback onViewBoth;

  @override
  Widget build(BuildContext context) {
    final isDark = context.appBrightness == Brightness.dark;

    return AppAlertDialog(
      appIcon: const AppLogo.dialog(),
      title: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text('Conflict Detected'),
        ],
      ),
      message: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The note "${originalNote.title ?? 'Untitled'}" has conflicting changes between your local version and the version on GitHub.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildFileInfo('Original (GitHub)', originalNote, isDark),
            const SizedBox(height: 12),
            _buildFileInfo('Your Version (Local)', conflictNote, isDark),
            const SizedBox(height: 16),
            Text(
              'How would you like to resolve this conflict?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
      primaryButton: AppButton(
        size: AppButtonSize.large,
        onPressed: () {
          Navigator.of(context).pop();
          onViewBoth();
        },
        child: const Text('View Both Files'),
      ),
      secondaryButton: AppButton(
        size: AppButtonSize.large,
        secondary: true,
        onPressed: () {
          Navigator.of(context).pop();
          _showKeepOriginalConfirmation(context);
        },
        child: const Text('Keep Original'),
      ),
      suppress: AppButton(
        size: AppButtonSize.large,
        secondary: true,
        onPressed: () {
          Navigator.of(context).pop();
          _showKeepYoursConfirmation(context);
        },
        child: const Text('Keep Yours'),
      ),
    );
  }

  Widget _buildFileInfo(String label, Note note, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFD1D1D6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note.path,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'SF Mono',
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          if (note.contentPreview != null) ...[
            const SizedBox(height: 8),
            Text(
              note.contentPreview!,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Updated: ${_formatDate(note.updatedAt)}',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  void _showKeepOriginalConfirmation(BuildContext context) {
    showAppAlertDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        appIcon: const AppLogo.dialog(),
        title: const Text('Discard Your Changes?'),
        message: const Text(
          'This will delete your local version and keep the version from GitHub. '
          'Your changes will be lost.',
        ),
        primaryButton: AppButton(
          size: AppButtonSize.large,
          onPressed: () {
            Navigator.of(context).pop();
            onKeepOriginal();
          },
          child: const Text('Discard My Changes'),
        ),
        secondaryButton: AppButton(
          size: AppButtonSize.large,
          secondary: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showKeepYoursConfirmation(BuildContext context) {
    showAppAlertDialog(
      context: context,
      builder: (_) => AppAlertDialog(
        appIcon: const AppLogo.dialog(),
        title: const Text('Replace Original?'),
        message: const Text(
          'This will replace the GitHub version with your local changes. '
          'The conflict file will be deleted and your version will be synced to GitHub.',
        ),
        primaryButton: AppButton(
          size: AppButtonSize.large,
          onPressed: () {
            Navigator.of(context).pop();
            onKeepYours();
          },
          child: const Text('Use My Version'),
        ),
        secondaryButton: AppButton(
          size: AppButtonSize.large,
          secondary: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
