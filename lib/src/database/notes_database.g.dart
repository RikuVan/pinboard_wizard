// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastKnownShaMeta = const VerificationMeta(
    'lastKnownSha',
  );
  @override
  late final GeneratedColumn<String> lastKnownSha = GeneratedColumn<String>(
    'last_known_sha',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _contentPreviewMeta = const VerificationMeta(
    'contentPreview',
  );
  @override
  late final GeneratedColumn<String> contentPreview = GeneratedColumn<String>(
    'content_preview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentLengthMeta = const VerificationMeta(
    'contentLength',
  );
  @override
  late final GeneratedColumn<int> contentLength = GeneratedColumn<int>(
    'content_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isConflictMeta = const VerificationMeta(
    'isConflict',
  );
  @override
  late final GeneratedColumn<bool> isConflict = GeneratedColumn<bool>(
    'is_conflict',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_conflict" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _markedForDeletionMeta = const VerificationMeta(
    'markedForDeletion',
  );
  @override
  late final GeneratedColumn<bool> markedForDeletion = GeneratedColumn<bool>(
    'marked_for_deletion',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("marked_for_deletion" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    title,
    lastKnownSha,
    isDirty,
    updatedAt,
    createdAt,
    contentPreview,
    contentLength,
    isConflict,
    markedForDeletion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('last_known_sha')) {
      context.handle(
        _lastKnownShaMeta,
        lastKnownSha.isAcceptableOrUnknown(
          data['last_known_sha']!,
          _lastKnownShaMeta,
        ),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('content_preview')) {
      context.handle(
        _contentPreviewMeta,
        contentPreview.isAcceptableOrUnknown(
          data['content_preview']!,
          _contentPreviewMeta,
        ),
      );
    }
    if (data.containsKey('content_length')) {
      context.handle(
        _contentLengthMeta,
        contentLength.isAcceptableOrUnknown(
          data['content_length']!,
          _contentLengthMeta,
        ),
      );
    }
    if (data.containsKey('is_conflict')) {
      context.handle(
        _isConflictMeta,
        isConflict.isAcceptableOrUnknown(data['is_conflict']!, _isConflictMeta),
      );
    }
    if (data.containsKey('marked_for_deletion')) {
      context.handle(
        _markedForDeletionMeta,
        markedForDeletion.isAcceptableOrUnknown(
          data['marked_for_deletion']!,
          _markedForDeletionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      lastKnownSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_known_sha'],
      ),
      isDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dirty'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      contentPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_preview'],
      ),
      contentLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_length'],
      )!,
      isConflict: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_conflict'],
      )!,
      markedForDeletion: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marked_for_deletion'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  /// UUID v4, generated using Uuid().v4() from uuid package
  final String id;

  /// Repo path: "notes/flutter-state.md"
  final String path;

  /// Parsed from markdown H1 or filename
  final String? title;

  /// GitHub file SHA at last successful sync
  /// CRITICAL: Used to detect conflicts
  final String? lastKnownSha;

  /// True if edited locally since last pull
  final bool isDirty;

  /// Last local edit time
  final DateTime updatedAt;

  /// When note was first discovered
  final DateTime createdAt;

  /// First 300 characters for preview (not authoritative)
  final String? contentPreview;

  /// Cached content length
  final int contentLength;

  /// True if this is a conflict file
  final bool isConflict;

  /// True if note should be deleted from GitHub on next sync
  final bool markedForDeletion;
  const Note({
    required this.id,
    required this.path,
    this.title,
    this.lastKnownSha,
    required this.isDirty,
    required this.updatedAt,
    required this.createdAt,
    this.contentPreview,
    required this.contentLength,
    required this.isConflict,
    required this.markedForDeletion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || lastKnownSha != null) {
      map['last_known_sha'] = Variable<String>(lastKnownSha);
    }
    map['is_dirty'] = Variable<bool>(isDirty);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || contentPreview != null) {
      map['content_preview'] = Variable<String>(contentPreview);
    }
    map['content_length'] = Variable<int>(contentLength);
    map['is_conflict'] = Variable<bool>(isConflict);
    map['marked_for_deletion'] = Variable<bool>(markedForDeletion);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      path: Value(path),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      lastKnownSha: lastKnownSha == null && nullToAbsent
          ? const Value.absent()
          : Value(lastKnownSha),
      isDirty: Value(isDirty),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
      contentPreview: contentPreview == null && nullToAbsent
          ? const Value.absent()
          : Value(contentPreview),
      contentLength: Value(contentLength),
      isConflict: Value(isConflict),
      markedForDeletion: Value(markedForDeletion),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String?>(json['title']),
      lastKnownSha: serializer.fromJson<String?>(json['lastKnownSha']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      contentPreview: serializer.fromJson<String?>(json['contentPreview']),
      contentLength: serializer.fromJson<int>(json['contentLength']),
      isConflict: serializer.fromJson<bool>(json['isConflict']),
      markedForDeletion: serializer.fromJson<bool>(json['markedForDeletion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'path': serializer.toJson<String>(path),
      'title': serializer.toJson<String?>(title),
      'lastKnownSha': serializer.toJson<String?>(lastKnownSha),
      'isDirty': serializer.toJson<bool>(isDirty),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'contentPreview': serializer.toJson<String?>(contentPreview),
      'contentLength': serializer.toJson<int>(contentLength),
      'isConflict': serializer.toJson<bool>(isConflict),
      'markedForDeletion': serializer.toJson<bool>(markedForDeletion),
    };
  }

  Note copyWith({
    String? id,
    String? path,
    Value<String?> title = const Value.absent(),
    Value<String?> lastKnownSha = const Value.absent(),
    bool? isDirty,
    DateTime? updatedAt,
    DateTime? createdAt,
    Value<String?> contentPreview = const Value.absent(),
    int? contentLength,
    bool? isConflict,
    bool? markedForDeletion,
  }) => Note(
    id: id ?? this.id,
    path: path ?? this.path,
    title: title.present ? title.value : this.title,
    lastKnownSha: lastKnownSha.present ? lastKnownSha.value : this.lastKnownSha,
    isDirty: isDirty ?? this.isDirty,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
    contentPreview: contentPreview.present
        ? contentPreview.value
        : this.contentPreview,
    contentLength: contentLength ?? this.contentLength,
    isConflict: isConflict ?? this.isConflict,
    markedForDeletion: markedForDeletion ?? this.markedForDeletion,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      title: data.title.present ? data.title.value : this.title,
      lastKnownSha: data.lastKnownSha.present
          ? data.lastKnownSha.value
          : this.lastKnownSha,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      contentPreview: data.contentPreview.present
          ? data.contentPreview.value
          : this.contentPreview,
      contentLength: data.contentLength.present
          ? data.contentLength.value
          : this.contentLength,
      isConflict: data.isConflict.present
          ? data.isConflict.value
          : this.isConflict,
      markedForDeletion: data.markedForDeletion.present
          ? data.markedForDeletion.value
          : this.markedForDeletion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('lastKnownSha: $lastKnownSha, ')
          ..write('isDirty: $isDirty, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('contentPreview: $contentPreview, ')
          ..write('contentLength: $contentLength, ')
          ..write('isConflict: $isConflict, ')
          ..write('markedForDeletion: $markedForDeletion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    path,
    title,
    lastKnownSha,
    isDirty,
    updatedAt,
    createdAt,
    contentPreview,
    contentLength,
    isConflict,
    markedForDeletion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.path == this.path &&
          other.title == this.title &&
          other.lastKnownSha == this.lastKnownSha &&
          other.isDirty == this.isDirty &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt &&
          other.contentPreview == this.contentPreview &&
          other.contentLength == this.contentLength &&
          other.isConflict == this.isConflict &&
          other.markedForDeletion == this.markedForDeletion);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> path;
  final Value<String?> title;
  final Value<String?> lastKnownSha;
  final Value<bool> isDirty;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<String?> contentPreview;
  final Value<int> contentLength;
  final Value<bool> isConflict;
  final Value<bool> markedForDeletion;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.title = const Value.absent(),
    this.lastKnownSha = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.contentPreview = const Value.absent(),
    this.contentLength = const Value.absent(),
    this.isConflict = const Value.absent(),
    this.markedForDeletion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String path,
    this.title = const Value.absent(),
    this.lastKnownSha = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.contentPreview = const Value.absent(),
    this.contentLength = const Value.absent(),
    this.isConflict = const Value.absent(),
    this.markedForDeletion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       path = Value(path);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? path,
    Expression<String>? title,
    Expression<String>? lastKnownSha,
    Expression<bool>? isDirty,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<String>? contentPreview,
    Expression<int>? contentLength,
    Expression<bool>? isConflict,
    Expression<bool>? markedForDeletion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (lastKnownSha != null) 'last_known_sha': lastKnownSha,
      if (isDirty != null) 'is_dirty': isDirty,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (contentPreview != null) 'content_preview': contentPreview,
      if (contentLength != null) 'content_length': contentLength,
      if (isConflict != null) 'is_conflict': isConflict,
      if (markedForDeletion != null) 'marked_for_deletion': markedForDeletion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? path,
    Value<String?>? title,
    Value<String?>? lastKnownSha,
    Value<bool>? isDirty,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<String?>? contentPreview,
    Value<int>? contentLength,
    Value<bool>? isConflict,
    Value<bool>? markedForDeletion,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      lastKnownSha: lastKnownSha ?? this.lastKnownSha,
      isDirty: isDirty ?? this.isDirty,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      contentPreview: contentPreview ?? this.contentPreview,
      contentLength: contentLength ?? this.contentLength,
      isConflict: isConflict ?? this.isConflict,
      markedForDeletion: markedForDeletion ?? this.markedForDeletion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (lastKnownSha.present) {
      map['last_known_sha'] = Variable<String>(lastKnownSha.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (contentPreview.present) {
      map['content_preview'] = Variable<String>(contentPreview.value);
    }
    if (contentLength.present) {
      map['content_length'] = Variable<int>(contentLength.value);
    }
    if (isConflict.present) {
      map['is_conflict'] = Variable<bool>(isConflict.value);
    }
    if (markedForDeletion.present) {
      map['marked_for_deletion'] = Variable<bool>(markedForDeletion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('lastKnownSha: $lastKnownSha, ')
          ..write('isDirty: $isDirty, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('contentPreview: $contentPreview, ')
          ..write('contentLength: $contentLength, ')
          ..write('isConflict: $isConflict, ')
          ..write('markedForDeletion: $markedForDeletion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NotesDatabase extends GeneratedDatabase {
  _$NotesDatabase(QueryExecutor e) : super(e);
  $NotesDatabaseManager get managers => $NotesDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [notes];
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required String path,
      Value<String?> title,
      Value<String?> lastKnownSha,
      Value<bool> isDirty,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<String?> contentPreview,
      Value<int> contentLength,
      Value<bool> isConflict,
      Value<bool> markedForDeletion,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> path,
      Value<String?> title,
      Value<String?> lastKnownSha,
      Value<bool> isDirty,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<String?> contentPreview,
      Value<int> contentLength,
      Value<bool> isConflict,
      Value<bool> markedForDeletion,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer
    extends Composer<_$NotesDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastKnownSha => $composableBuilder(
    column: $table.lastKnownSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentPreview => $composableBuilder(
    column: $table.contentPreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentLength => $composableBuilder(
    column: $table.contentLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isConflict => $composableBuilder(
    column: $table.isConflict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get markedForDeletion => $composableBuilder(
    column: $table.markedForDeletion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$NotesDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastKnownSha => $composableBuilder(
    column: $table.lastKnownSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentPreview => $composableBuilder(
    column: $table.contentPreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentLength => $composableBuilder(
    column: $table.contentLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isConflict => $composableBuilder(
    column: $table.isConflict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get markedForDeletion => $composableBuilder(
    column: $table.markedForDeletion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$NotesDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get lastKnownSha => $composableBuilder(
    column: $table.lastKnownSha,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get contentPreview => $composableBuilder(
    column: $table.contentPreview,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentLength => $composableBuilder(
    column: $table.contentLength,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isConflict => $composableBuilder(
    column: $table.isConflict,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get markedForDeletion => $composableBuilder(
    column: $table.markedForDeletion,
    builder: (column) => column,
  );
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$NotesDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$NotesDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> lastKnownSha = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> contentPreview = const Value.absent(),
                Value<int> contentLength = const Value.absent(),
                Value<bool> isConflict = const Value.absent(),
                Value<bool> markedForDeletion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                path: path,
                title: title,
                lastKnownSha: lastKnownSha,
                isDirty: isDirty,
                updatedAt: updatedAt,
                createdAt: createdAt,
                contentPreview: contentPreview,
                contentLength: contentLength,
                isConflict: isConflict,
                markedForDeletion: markedForDeletion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String path,
                Value<String?> title = const Value.absent(),
                Value<String?> lastKnownSha = const Value.absent(),
                Value<bool> isDirty = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> contentPreview = const Value.absent(),
                Value<int> contentLength = const Value.absent(),
                Value<bool> isConflict = const Value.absent(),
                Value<bool> markedForDeletion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                path: path,
                title: title,
                lastKnownSha: lastKnownSha,
                isDirty: isDirty,
                updatedAt: updatedAt,
                createdAt: createdAt,
                contentPreview: contentPreview,
                contentLength: contentLength,
                isConflict: isConflict,
                markedForDeletion: markedForDeletion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$NotesDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;

class $NotesDatabaseManager {
  final _$NotesDatabase _db;
  $NotesDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
}
