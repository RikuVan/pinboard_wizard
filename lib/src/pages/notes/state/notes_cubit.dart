import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/pages/notes/state/notes_state.dart';
import 'package:pinboard_wizard/src/pinboard/models/note.dart';

import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_client.dart';

class NotesCubit extends Cubit<NotesState> {
  NotesCubit({required this.pinboardService}) : super(const NotesState());

  final PinboardService pinboardService;

  Future<void> loadNotes() async {
    emit(state.copyWith(status: NotesStatus.loading));

    try {
      final notes = await pinboardService.getAllNotes();
      emit(
        state.copyWith(
          status: NotesStatus.loaded,
          notes: notes,
          errorMessage: null,
        ),
      );
    } on PinboardException catch (e) {
      emit(state.copyWith(status: NotesStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(
        state.copyWith(
          status: NotesStatus.error,
          errorMessage: 'Failed to load notes: $e',
        ),
      );
    }
  }

  Future<void> selectNote(Note note) async {
    emit(state.copyWith(selectedNote: note, selectedNoteDetail: null));

    try {
      final noteDetail = await pinboardService.getNote(note.id);
      emit(state.copyWith(selectedNoteDetail: noteDetail));
    } on PinboardException catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to load note details: ${e.message}',
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to load note details: $e'));
    }
  }

  void clearSelection() {
    emit(state.copyWith(selectedNote: null, selectedNoteDetail: null));
  }

  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    emit(
      state.copyWith(
        status: NotesStatus.searching,
        searchQuery: query,
        isSearching: true,
      ),
    );

    try {
      final filteredNotes = await pinboardService.searchNotes(query);
      emit(
        state.copyWith(
          status: NotesStatus.loaded,
          filteredNotes: filteredNotes,
        ),
      );
    } on PinboardException catch (e) {
      emit(state.copyWith(status: NotesStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(
        state.copyWith(
          status: NotesStatus.error,
          errorMessage: 'Search failed: $e',
        ),
      );
    }
  }

  void clearSearch() {
    emit(
      state.copyWith(
        isSearching: false,
        searchQuery: '',
        filteredNotes: [],
        status: NotesStatus.loaded,
      ),
    );
  }

  Future<void> refresh() async {
    await loadNotes();
  }

  String getFooterText() {
    final displayNotes = state.displayNotes;
    final totalNotes = state.notes.length;

    if (state.isSearching) {
      return '${displayNotes.length} of $totalNotes notes';
    }

    if (totalNotes == 1) {
      return '1 note';
    }

    return '$totalNotes notes';
  }
}
