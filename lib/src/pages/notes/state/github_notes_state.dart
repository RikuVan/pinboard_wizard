import 'package:equatable/equatable.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/notes/models/sync_result.dart';

/// Status of the GitHub notes UI
enum GitHubNotesStatus {
  /// Initial state, no data loaded
  initial,

  /// Loading notes from database
  loading,

  /// Notes loaded successfully
  loaded,

  /// Performing search
  searching,

  /// Error occurred
  error,
}

/// State for GitHub-backed notes management
class GitHubNotesState extends Equatable {
  const GitHubNotesState({
    this.status = GitHubNotesStatus.initial,
    this.notes = const [],
    this.filteredNotes = const [],
    this.selectedNote,
    this.noteContent,
    this.searchQuery = '',
    this.isSearching = false,
    this.isEditing = false,
    this.isSaving = false,
    this.isCreating = false,
    this.isSyncing = false,
    this.isOnline = true,
    this.syncResult,
    this.lastSyncTime,
    this.errorMessage,
  });

  /// Current UI status
  final GitHubNotesStatus status;

  /// All notes from the database
  final List<Note> notes;

  /// Filtered notes from search (empty if not searching)
  final List<Note> filteredNotes;

  /// Currently selected note
  final Note? selectedNote;

  /// Content of the selected note (loaded from file)
  final String? noteContent;

  /// Current search query
  final String searchQuery;

  /// Whether search is active
  final bool isSearching;

  /// Whether user is currently editing a note
  final bool isEditing;

  /// Whether a save operation is in progress
  final bool isSaving;

  /// Whether a create operation is in progress
  final bool isCreating;

  /// Whether a sync operation is in progress
  final bool isSyncing;

  /// Whether device is online
  final bool isOnline;

  /// Result of last sync operation
  final SyncResult? syncResult;

  /// Timestamp of last successful sync
  final DateTime? lastSyncTime;

  /// Error message to display
  final String? errorMessage;

  /// Get the notes to display (filtered if searching, otherwise all)
  List<Note> get displayNotes => isSearching ? filteredNotes : notes;

  /// Whether the list is empty
  bool get isEmpty => displayNotes.isEmpty;

  /// Whether there's an error
  bool get hasError => status == GitHubNotesStatus.error;

  /// Whether data is loading
  bool get isLoading => status == GitHubNotesStatus.loading;

  /// Whether there are dirty (unsaved) notes
  bool get hasDirtyNotes => notes.any((n) => n.isDirty);

  /// Number of dirty notes
  int get dirtyNotesCount => notes.where((n) => n.isDirty).length;

  /// Whether there are conflicts
  bool get hasConflicts => notes.any((n) => n.isConflict);

  /// Number of conflict notes
  int get conflictNotesCount => notes.where((n) => n.isConflict).length;

  /// Get all conflict notes
  List<Note> get conflictNotes => notes.where((n) => n.isConflict).toList();

  GitHubNotesState copyWith({
    GitHubNotesStatus? status,
    List<Note>? notes,
    List<Note>? filteredNotes,
    Note? selectedNote,
    bool clearSelectedNote = false,
    String? noteContent,
    bool clearNoteContent = false,
    String? searchQuery,
    bool? isSearching,
    bool? isEditing,
    bool? isSaving,
    bool? isCreating,
    bool? isSyncing,
    bool? isOnline,
    SyncResult? syncResult,
    bool clearSyncResult = false,
    DateTime? lastSyncTime,
    bool clearLastSyncTime = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return GitHubNotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      filteredNotes: filteredNotes ?? this.filteredNotes,
      selectedNote: clearSelectedNote ? null : (selectedNote ?? this.selectedNote),
      noteContent: clearNoteContent ? null : (noteContent ?? this.noteContent),
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
      isCreating: isCreating ?? this.isCreating,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      syncResult: clearSyncResult ? null : (syncResult ?? this.syncResult),
      lastSyncTime: clearLastSyncTime ? null : (lastSyncTime ?? this.lastSyncTime),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    notes,
    filteredNotes,
    selectedNote,
    noteContent,
    searchQuery,
    isSearching,
    isEditing,
    isSaving,
    isCreating,
    isSyncing,
    isOnline,
    syncResult,
    lastSyncTime,
    errorMessage,
  ];
}
