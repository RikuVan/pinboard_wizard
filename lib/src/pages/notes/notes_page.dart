import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pages/notes/state/notes_cubit.dart';
import 'package:pinboard_wizard/src/pages/notes/state/notes_state.dart';
import 'package:pinboard_wizard/src/pages/notes/note_tile.dart';
import 'package:pinboard_wizard/src/pages/notes/note_detail_view.dart';
import 'package:pinboard_wizard/src/pages/notes/resizable_split_view.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/pinboard/models/note.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:url_launcher/url_launcher.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  late final NotesCubit _notesCubit;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _notesCubit = NotesCubit(pinboardService: locator.get<PinboardService>());

    _searchController.addListener(_onSearchChanged);
    _notesCubit.loadNotes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _notesCubit.close();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      _notesCubit.clearSearch();
    } else {
      _notesCubit.performSearch(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _notesCubit,
      child: BlocConsumer<NotesCubit, NotesState>(
        listener: (context, state) {
          if (state.hasError && state.errorMessage != null) {
            _showErrorDialog(state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: ProgressCircle());
          }

          if (state.hasError && state.isEmpty) {
            return _buildErrorView(state.errorMessage);
          }

          if (state.isEmpty) {
            return _buildEmptyView();
          }

          return Column(
            children: [
              _buildToolbar(state),
              Expanded(
                child: ResizableSplitView(
                  initialRatio: 0.4,
                  minLeftWidth: 300,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                errorMessage ?? 'An error occurred',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: () => _notesCubit.loadNotes(),
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
            const Text('No notes found.'),
            const SizedBox(height: 12),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: () => _notesCubit.refresh(),
              child: const Text('Refresh'),
            ),
            const SizedBox(height: 8),
            PushButton(
              controlSize: ControlSize.large,
              secondary: true,
              onPressed: _createNote,
              child: const Text('Create Note'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(NotesState state) {
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
          PushButton(
            controlSize: ControlSize.regular,
            onPressed: _createNote,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MacosIcon(
                  CupertinoIcons.add,
                  size: 16,
                  color: MacosTheme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Create Note',
                  style: TextStyle(
                    color: MacosTheme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: () => _notesCubit.refresh(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MacosIcon(
                  CupertinoIcons.refresh,
                  size: 16,
                  color: MacosTheme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : null,
                ),
                const SizedBox(width: 4),
                Text('Refresh'),
              ],
            ),
          ),
          const SizedBox(width: 16),
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

  Widget _buildNotesList(NotesState state) {
    final displayNotes = state.displayNotes;

    if (displayNotes.isEmpty && state.isSearching) {
      return const Center(
        child: Text(
          'No notes found',
          style: TextStyle(
            color: MacosColors.secondaryLabelColor,
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount: displayNotes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final note = displayNotes[index];
        return NoteTile(
          note: note,
          isSelected: state.selectedNote?.id == note.id,
          onTap: () => _notesCubit.selectNote(note),
        );
      },
    );
  }

  Widget _buildNoteDetail(NotesState state) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;

    if (state.selectedNote == null) {
      return Center(
        child: Text(
          'Select a note to view details',
          style: TextStyle(
            color: isDark ? Colors.white60 : MacosColors.secondaryLabelColor,
            fontSize: 16,
          ),
        ),
      );
    }

    return NoteDetailView(
      note: state.selectedNote!,
      noteDetail: state.selectedNoteDetail,
      onEdit: () => _editNote(state.selectedNote!),
    );
  }

  Widget _buildFooterBar(NotesState state) {
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
            _notesCubit.footerText,
            style: TextStyle(
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
              fontSize: 11,
            ),
          ),
          if (state.isSearching)
            Text(
              'Searching: "${state.searchQuery}"',
              style: TextStyle(
                color: MacosTheme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black54,
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
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _createNote() async {
    final url = Uri.parse('https://pinboard.in/note/add/');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);

        // Show a dialog suggesting to refresh after creating the note
        if (mounted) {
          showMacosAlertDialog(
            context: context,
            builder: (_) => MacosAlertDialog(
              appIcon: const AppLogo.dialog(),
              title: const Text('Note Creation'),
              message: const Text(
                'The Pinboard notes page has been opened in your browser. '
                'After creating your note, click "Refresh" to see it in the app.',
              ),
              primaryButton: PushButton(
                controlSize: ControlSize.large,
                child: const Text('Refresh Now'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _notesCubit.refresh();
                },
              ),
              secondaryButton: PushButton(
                controlSize: ControlSize.large,
                secondary: true,
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          );
        }
      } else {
        _showErrorDialog('Could not open Pinboard notes page');
      }
    } catch (e) {
      _showErrorDialog('Failed to open notes page: $e');
    }
  }

  Future<void> _editNote(Note note) async {
    final username = await locator.get<PinboardService>().getUsername();
    final url = Uri.parse(
      'https://pinboard.in/u:$username/notes/${note.id}/edit/',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);

        // Show a dialog suggesting to refresh after editing the note
        if (mounted) {
          showMacosAlertDialog(
            context: context,
            builder: (_) => MacosAlertDialog(
              appIcon: const AppLogo.dialog(),
              title: const Text('Note Editing'),
              message: const Text(
                'The note editing page has been opened in your browser. '
                'After making changes, click "Refresh" to see updates in the app.',
              ),
              primaryButton: PushButton(
                controlSize: ControlSize.large,
                child: const Text('Refresh Now'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _notesCubit.refresh();
                },
              ),
              secondaryButton: PushButton(
                controlSize: ControlSize.large,
                secondary: true,
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          );
        }
      } else {
        _showErrorDialog('Could not open note editing page');
      }
    } catch (e) {
      _showErrorDialog('Failed to open note editing page: $e');
    }
  }
}
