import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/notes/services/file_service.dart';
import 'package:pinboard_wizard/src/notes/services/network_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_sync_engine.dart';
import 'package:pinboard_wizard/src/pages/notes/resizable_split_view.dart';
import 'package:pinboard_wizard/src/pages/notes/state/github_notes_cubit.dart';
import 'package:pinboard_wizard/src/pages/notes/state/github_notes_state.dart';
import 'package:pinboard_wizard/src/pages/notes/widgets/conflict_resolution_dialog.dart';
import 'package:pinboard_wizard/src/pages/notes/widgets/github_note_tile.dart';
import 'package:pinboard_wizard/src/pages/notes/widgets/markdown_editor.dart';
import 'package:pinboard_wizard/src/pages/notes/widgets/new_note_form.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:timeago/timeago.dart' as timeago;

/// GitHub-backed notes page with local editing, sync, and conflict resolution.
///
/// Features:
/// - List view with search
/// - Markdown editor
/// - Sync status indicators
/// - Manual sync trigger
/// - Conflict resolution
/// - Offline-first with background sync
class GitHubNotesPage extends StatefulWidget {
  const GitHubNotesPage({super.key});

  @override
  State<GitHubNotesPage> createState() => _GitHubNotesPageState();
}

class _GitHubNotesPageState extends State<GitHubNotesPage> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  GitHubNotesCubit? _notesCubit;
  bool _isInitializing = true;
  String? _initError;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _initializeCubit();
  }

  Future<void> _initializeCubit() async {
    try {
      final syncEngine = await locator.getAsync<NoteSyncEngine>();

      _notesCubit = GitHubNotesCubit(
        database: locator.get<NotesDatabase>(),
        syncEngine: syncEngine,
        fileService: locator.get<FileService>(),
        networkService: locator.get<NetworkService>(),
      );

      await _notesCubit!.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _notesCubit?.close();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_notesCubit == null || !mounted) return;

    // Cancel previous debounce timer
    _searchDebounce?.cancel();

    final query = _searchController.text;

    if (query.isEmpty) {
      // Clear search immediately when empty
      _notesCubit!.clearSearch();
    } else {
      // Debounce search queries to avoid rapid state changes
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _notesCubit != null) {
          _notesCubit!.search(query);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while initializing
    if (_isInitializing) {
      return const Center(child: ProgressCircle());
    }

    // Show error state if initialization failed
    if (_initError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MacosIcon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to initialize notes',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _initError!.contains('not configured')
                    ? 'GitHub credentials are not configured. Please go to Settings → GitHub to set up your repository.'
                    : _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: () => _initializeCubit(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show notes UI once initialized
    return BlocProvider.value(
      value: _notesCubit!,
      child: BlocConsumer<GitHubNotesCubit, GitHubNotesState>(
        listener: (context, state) {
          // Show errors
          if (state.hasError && state.errorMessage != null) {
            _showErrorDialog(state.errorMessage!);
          }

          // Show sync results
          if (state.syncResult != null && !state.isSyncing) {
            _showSyncResult(state);
          }

          // Prompt for conflict resolution
          if (state.hasConflicts && !state.isSyncing) {
            _checkForConflicts();
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: ProgressCircle());
          }

          if (state.hasError && state.isEmpty) {
            return _buildErrorView(state.errorMessage);
          }

          if (state.isEmpty && !state.isSearching) {
            return _buildEmptyView();
          }

          return Column(
            children: [
              _buildToolbar(state),
              Expanded(
                child: ResizableSplitView(
                  initialRatio: 0.35,
                  minLeftWidth: 250,
                  minRightWidth: 400,
                  left: _buildNotesList(state),
                  right: _buildNoteDetail(state),
                ),
              ),
              _buildFooterBar(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView(String? errorMessage) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MacosIcon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: () => _notesCubit?.loadNotes(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MacosIcon(
              CupertinoIcons.doc_text,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No notes yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first note to get started.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: () => _notesCubit?.startCreating(),
              child: const Text('Create Note'),
            ),
            const SizedBox(height: 12),
            PushButton(
              controlSize: ControlSize.large,
              secondary: true,
              onPressed: () => _notesCubit?.sync(),
              child: const Text('Sync from GitHub'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(GitHubNotesState state) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        border: Border(
          bottom: BorderSide(color: MacosColors.separatorColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Create button
          PushButton(
            controlSize: ControlSize.regular,
            onPressed: () => _notesCubit?.startCreating(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MacosIcon(
                  CupertinoIcons.add,
                  size: 16,
                  color: isDark ? Colors.white : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'New Note',
                  style: TextStyle(color: isDark ? Colors.white : Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Sync button
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: state.isSyncing ? null : () => _notesCubit?.sync(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isSyncing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: ProgressCircle(radius: 7),
                  )
                else
                  MacosIcon(
                    CupertinoIcons.arrow_2_circlepath,
                    size: 16,
                    color: isDark ? Colors.white70 : null,
                  ),
                const SizedBox(width: 4),
                Text(state.isSyncing ? 'Syncing...' : 'Sync'),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Online/Offline indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: state.isOnline
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: state.isOnline ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  state.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: state.isOnline ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Conflict indicator
          if (state.hasConflicts) ...[
            const SizedBox(width: 12),
            MacosTooltip(
              message:
                  '${state.conflictNotesCount} conflict${state.conflictNotesCount == 1 ? '' : 's'}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MacosIcon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${state.conflictNotesCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),

          // Search field
          Expanded(
            child: MacosSearchField(
              controller: _searchController,
              placeholder: 'Search notes...',
              onChanged: (_) {}, // handled by controller listener
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(GitHubNotesState state) {
    final displayNotes = state.displayNotes;

    if (displayNotes.isEmpty && state.isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MacosIcon(
              CupertinoIcons.search,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No notes found',
              style: TextStyle(
                fontSize: 14,
                color: MacosTheme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : MacosColors.secondaryLabelColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 12,
                color: MacosTheme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: displayNotes.length,
      itemBuilder: (context, index) {
        final note = displayNotes[index];
        return GitHubNoteTile(
          note: note,
          isSelected: state.selectedNote?.id == note.id,
          onTap: () => _notesCubit?.selectNote(note),
        );
      },
    );
  }

  Widget _buildNoteDetail(GitHubNotesState state) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;

    // Show new note form if creating
    if (state.isCreating) {
      return NewNoteForm(
        onCreate: (title, content) =>
            _notesCubit?.createNote(title: title, content: content),
        onCancel: () => _notesCubit?.cancelCreating(),
      );
    }

    if (state.selectedNote == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MacosIcon(
              CupertinoIcons.doc_text,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a note to view',
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? Colors.white60
                    : MacosColors.secondaryLabelColor,
              ),
            ),
          ],
        ),
      );
    }

    final note = state.selectedNote!;

    // Show editor if in editing mode
    if (state.isEditing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownEditor(
          initialContent: state.noteContent ?? '',
          onSave: (content) => _notesCubit?.saveNote(content),
          onCancel: () => _notesCubit?.cancelEditing(),
        ),
      );
    }

    // Show note detail view
    return _buildNoteReadView(note, state.noteContent, isDark);
  }

  Widget _buildNoteReadView(Note note, String? content, bool isDark) {
    return Column(
      children: [
        // Header with actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFE5E5EA),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title ?? 'Untitled',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Updated ${timeago.format(note.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              PushButton(
                controlSize: ControlSize.regular,
                onPressed: content == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Note copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                child: const Text('Copy'),
              ),
              const SizedBox(width: 8),
              PushButton(
                controlSize: ControlSize.regular,
                onPressed: note.markedForDeletion
                    ? null
                    : () => _notesCubit?.startEditing(),
                child: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              if (note.markedForDeletion)
                GestureDetector(
                  onTap: () => _notesCubit?.undoDeleteNote(note.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MacosIcon(
                          CupertinoIcons.arrow_uturn_left,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Undo Delete',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _confirmDeleteNote(note),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MacosColors.systemRedColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MacosIcon(
                          CupertinoIcons.trash,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Deletion warning banner
        if (note.markedForDeletion)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                MacosIcon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This note is marked for deletion and will be permanently removed when you sync.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.orange.shade300
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: content == null
              ? const Center(child: ProgressCircle())
              : Markdown(
                  data: content,
                  selectable: true,
                  extensionSet: md.ExtensionSet.gitHubFlavored,
                  padding: const EdgeInsets.all(24),
                  builders: {'code': CodeElementBuilder(isDark: isDark)},
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    h1: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    h2: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    h3: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    code: TextStyle(
                      fontFamily: 'SF Mono',
                      fontSize: 12,
                      backgroundColor: isDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF5F5F5),
                      color: isDark
                          ? const Color(0xFFD4D4D4)
                          : const Color(0xFF1E1E1E),
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    blockquote: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 4,
                        ),
                      ),
                    ),
                    a: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    tableHead: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    tableBody: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    tableBorder: TableBorder.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                      width: 1,
                    ),
                    tableColumnWidth: const FlexColumnWidth(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFooterBar(GitHubNotesState state) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        border: Border(
          top: BorderSide(color: MacosColors.separatorColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _notesCubit?.footerText ?? '',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 11,
            ),
          ),
          if (state.lastSyncTime != null)
            Text(
              'Last synced ${timeago.format(state.lastSyncTime!)}',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    if (!mounted) return;

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const AppLogo.dialog(),
        title: const Text('Error'),
        message: Text(errorMessage),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ),
    );
  }

  void _showSyncResult(GitHubNotesState state) {
    final result = state.syncResult;
    if (result == null) return;

    // Don't show toast for offline state
    if (!result.isOnline) return;

    // Show toast notification
    final message = result.userMessage;
    final color = result.isFullSuccess
        ? Colors.green
        : result.isPartialSuccess
        ? Colors.orange
        : Colors.red;

    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkForConflicts() async {
    if (_notesCubit == null) return;
    final conflicts = await _notesCubit!.getConflictNotes();
    if (conflicts.isEmpty) return;

    // Find pairs of original and conflict notes
    for (final conflict in conflicts) {
      // Extract original filename from conflict filename
      final path = conflict.path;
      if (!path.contains('.conflict-')) continue;

      final originalPath = '${path.split('.conflict-').first}.md';
      final originalNote = _notesCubit!.state.notes
          .where((n) => n.path == originalPath)
          .firstOrNull;

      if (originalNote != null && mounted) {
        _showConflictDialog(originalNote, conflict);
        break; // Show one at a time
      }
    }
  }

  void _showConflictDialog(Note originalNote, Note conflictNote) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => ConflictResolutionDialog(
        originalNote: originalNote,
        conflictNote: conflictNote,
        onKeepOriginal: () =>
            _notesCubit!.resolveConflictKeepOriginal(conflictNote),
        onKeepYours: () =>
            _notesCubit!.resolveConflictKeepYours(originalNote, conflictNote),
        onViewBoth: () {
          // Select the conflict note to view both
          _notesCubit!.selectNote(conflictNote);
        },
      ),
    );
  }

  void _confirmDeleteNote(Note note) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const AppLogo.dialog(),
        title: const Text('Delete Note?'),
        message: Text(
          'Are you sure you want to delete "${note.title ?? 'Untitled'}"? '
          'This will mark it for deletion and remove it from GitHub on next sync.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: false,
          onPressed: () {
            Navigator.of(context).pop();
            _notesCubit!.deleteNote(note.id);
          },
          child: const Text('Delete'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

/// Custom code block builder with syntax highlighting
class CodeElementBuilder extends MarkdownElementBuilder {
  final bool isDark;

  CodeElementBuilder({required this.isDark});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      language = lg.substring(9); // Remove 'language-' prefix
    }

    return SizedBox(
      width: double.infinity,
      child: HighlightView(
        element.textContent,
        language: language,
        theme: isDark ? a11yDarkTheme : githubTheme,
        padding: const EdgeInsets.all(12),
        textStyle: const TextStyle(fontFamily: 'SF Mono', fontSize: 12),
      ),
    );
  }
}
