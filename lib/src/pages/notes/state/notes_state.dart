import 'package:equatable/equatable.dart';
import 'package:pinboard_wizard/src/pinboard/models/note.dart';
import 'package:pinboard_wizard/src/pinboard/models/notes_response.dart';

enum NotesStatus { initial, loading, loaded, error, searching }

class NotesState extends Equatable {
  const NotesState({
    this.status = NotesStatus.initial,
    this.notes = const [],
    this.filteredNotes = const [],
    this.selectedNote,
    this.selectedNoteDetail,
    this.errorMessage,
    this.isSearching = false,
    this.searchQuery = '',
  });

  final NotesStatus status;
  final List<Note> notes;
  final List<Note> filteredNotes;
  final Note? selectedNote;
  final NoteDetailResponse? selectedNoteDetail;
  final String? errorMessage;
  final bool isSearching;
  final String searchQuery;

  NotesState copyWith({
    NotesStatus? status,
    List<Note>? notes,
    List<Note>? filteredNotes,
    Note? selectedNote,
    NoteDetailResponse? selectedNoteDetail,
    String? errorMessage,
    bool? isSearching,
    String? searchQuery,
  }) {
    return NotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      filteredNotes: filteredNotes ?? this.filteredNotes,
      selectedNote: selectedNote ?? this.selectedNote,
      selectedNoteDetail: selectedNoteDetail ?? this.selectedNoteDetail,
      errorMessage: errorMessage ?? this.errorMessage,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Convenience getters
  bool get isLoading => status == NotesStatus.loading;
  bool get hasError => status == NotesStatus.error;
  bool get isEmpty => notes.isEmpty && status != NotesStatus.loading;

  List<Note> get displayNotes {
    if (isSearching) {
      return filteredNotes;
    }
    return notes;
  }

  @override
  List<Object?> get props => [
    status,
    notes,
    filteredNotes,
    selectedNote,
    selectedNoteDetail,
    errorMessage,
    isSearching,
    searchQuery,
  ];
}
