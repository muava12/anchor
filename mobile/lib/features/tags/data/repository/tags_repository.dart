import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/sync_requester.dart';
import '../../domain/tag.dart';
import '../local/tag_rows.dart';

part 'tags_repository.g.dart';

@Riverpod(keepAlive: true)
TagsRepository tagsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return TagsRepository(db);
}

/// Nothing here talks to the server.
class TagsRepository {
  final AppDatabase? _db;

  TagsRepository(this._db);

  /// A data-less instance for tests and empty states: reads return nothing,
  /// writes throw, so the scheduler can depend on the provider without a
  /// live database.
  TagsRepository.empty() : _db = null;

  Stream<List<Tag>> watchTags() {
    final db = _db;
    if (db == null) return const Stream.empty();
    return _liveTags(db).watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  Future<List<Tag>> getTags() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await _liveTags(db).get();
    return rows.map(_mapToDomain).toList();
  }

  Future<Tag> createTag(Tag tag) async {
    final created = tag.copyWith(updatedAt: DateTime.now().toUtc());

    final db = _db!;
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: created.id,
            name: created.name,
            color: drift.Value(created.color),
            updatedAt: drift.Value(created.updatedAt),
            isSynced: const drift.Value(false),
            localRev: const drift.Value(1),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

    scheduleAppSync(trigger: 'TagsRepo.createTag');

    return created;
  }

  Future<void> updateTag(Tag tag) async {
    final db = _db!;
    await db.transaction(() async {
      final prior = await db.tagRow(tag.id);
      if (prior == null) return;

      await db.writeTag(
        tag.id,
        TagsCompanion(
          name: drift.Value(tag.name),
          color: drift.Value(tag.color),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          isSynced: const drift.Value(false),
          localRev: drift.Value(prior.localRev + 1),
        ),
      );
    });

    scheduleAppSync(trigger: 'TagsRepo.updateTag');
  }

  // Kept, marked deleted, until the server has been told.
  Future<void> deleteTag(String id) async {
    final db = _db!;
    await db.transaction(() async {
      final prior = await db.tagRow(id);
      if (prior == null) return;

      await db.writeTag(
        id,
        TagsCompanion(
          isDeleted: const drift.Value(true),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          isSynced: const drift.Value(false),
          localRev: drift.Value(prior.localRev + 1),
        ),
      );
      await (db.delete(
        db.noteTags,
      )..where((tbl) => tbl.tagId.equals(id))).go();
    });

    scheduleAppSync(trigger: 'TagsRepo.deleteTag');
  }

  drift.SimpleSelectStatement<$TagsTable, TagRow> _liveTags(AppDatabase db) {
    return db.select(db.tags)
      ..where((tbl) => tbl.isDeleted.equals(false))
      ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.name)]);
  }

  Tag _mapToDomain(TagRow row) {
    return Tag(
      id: row.id,
      name: row.name,
      color: row.color,
      updatedAt: row.updatedAt,
      isSynced: row.isSynced,
      isDeleted: row.isDeleted,
    );
  }
}
