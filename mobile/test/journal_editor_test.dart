import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/session/active_user_id_provider.dart';
import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_entry_meta_row.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/editor/editor_overlay.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:anchor/features/notes/presentation/note_edit_screen.dart';
import 'package:anchor/features/notes/presentation/widgets/note_bar.dart';
import 'package:anchor/features/reminders/data/notification_gateway.dart';
import 'package:anchor/features/reminders/presentation/month_grid.dart';
import 'package:anchor/features/tags/data/repository/tags_repository.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'reminder_permissions_test.dart' show FakeGateway;

class _MockNotes extends Mock implements NotesRepository {}

class _MockTags extends Mock implements TagsRepository {}

class _MockAttachments extends Mock implements NoteAttachmentsRepository {}

class _MockPrefs extends Mock implements PreferencesRepository {}

class _ActiveUserId extends ActiveUserId {
  @override
  String? build() => 'user-1';
}

void main() {
  late _MockNotes notes;
  late _MockTags tags;
  late _MockAttachments attachments;
  late _MockPrefs prefs;
  late FakeGateway gateway;

  setUpAll(() => registerFallbackValue(const Note(id: 'fallback', title: '')));

  setUp(() {
    notes = _MockNotes();
    tags = _MockTags();
    attachments = _MockAttachments();
    prefs = _MockPrefs();
    gateway = FakeGateway();
    when(() => notes.updateNote(any())).thenAnswer((_) async {});
    when(() => notes.watchNote(any())).thenAnswer(
      (_) => const Stream<Note?>.empty(),
    );
    when(() => tags.watchTags()).thenAnswer((_) => Stream.value(const <Tag>[]));
    when(() => attachments.watchAttachments(any())).thenAnswer(
      (_) => Stream.value(const []),
    );
    when(() => prefs.getSortChecklistItems()).thenAnswer((_) async => true);
    when(() => prefs.getExactAlarmsOffered()).thenAnswer((_) async => true);
    when(() => prefs.getNotificationsAsked()).thenAnswer((_) async => false);
    when(() => prefs.setNotificationsAsked(any())).thenAnswer((_) async {});
  });

  Note journalNote() {
    final meta = JournalMeta(entryAt: DateTime(2026, 11, 17, 9, 41));
    return Note(
      id: 'n1',
      title: 'Morning pages',
      tagIds: ['journal'],
      content: composeJournalContent(meta, '{"ops":[{"insert":"AM\\n"}]}'),
    );
  }

  Future<void> openScreen(
    WidgetTester tester, {
    Note? note,
    bool journal = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notes),
          tagsRepositoryProvider.overrideWithValue(tags),
          noteAttachmentsRepositoryProvider.overrideWithValue(attachments),
          preferencesRepositoryProvider.overrideWithValue(prefs),
          serverUrlProvider.overrideWith((ref) => null),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream<List<ConnectivityResult>>.empty(),
          ),
          activeUserIdProvider.overrideWith(_ActiveUserId.new),
          notificationGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(
            initialLocation: '/note',
            routes: [
              GoRoute(
                path: '/note',
                builder: (_, _) =>
                    NoteEditScreen(note: note, noteId: 'n1', journal: journal),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the journal editor hides the metadata header and shows pills '
      'under the title', (tester) async {
    final note = journalNote();
    await openScreen(tester, note: note);

    final editor = tester.state<RichTextEditorState>(find.byType(RichTextEditor));
    final plain = editor.controller.document.toPlainText();
    expect(plain, isNot(contains('mood:')));
    expect(plain, contains('AM'));

    // The pills render with the date and a placeholder mood.
    final meta = tester.widget<JournalEntryMetaRow>(
      find.byType(JournalEntryMetaRow),
    );
    expect(meta.meta.entryAt, DateTime(2026, 11, 17, 9, 41));
    expect(meta.meta.mood, isNull);
    expect(find.text('Add mood'), findsOneWidget);
    expect(
      find.text('How are you feeling?'),
      findsNothing,
      reason: 'the v1 above-keyboard mood row is gone',
    );

    // The old v1 wiring is gone.
    expect(
      tester.widget<NoteBar>(find.byType(NoteBar)).leadingInset,
      isNull,
      reason: 'the date no longer sits in the top bar',
    );
    expect(
      tester.widget<EditorOverlay>(find.byType(EditorOverlay)).editorMood,
      isNull,
      reason: 'the toolbar no longer opens the mood picker',
    );
  });

  testWidgets('a non-journal note shows no metadata pills', (tester) async {
    await openScreen(
      tester,
      journal: false,
      note: const Note(id: 'n2', title: 'Groceries'),
    );

    expect(find.byType(JournalEntryMetaRow), findsNothing);
  });

  testWidgets('picking a mood and a date survives a save and reopen', (
    tester,
  ) async {
    await openScreen(tester, note: journalNote());

    // Mood: open the sheet from the pill, pick one, close it.
    await tester.tap(find.byKey(JournalEntryMetaRow.moodKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Date: open the sheet from the pill, pick a day, save it.
    await tester.tap(find.byKey(JournalEntryMetaRow.dateKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(MonthGrid), matching: find.text('12'))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Let the auto-save flush the metadata into the stored content.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final saved = verify(() => notes.updateNote(captureAny())).captured.last
        as Note;
    expect(saved.content, contains('mood: happy'));
    expect(saved.content, contains('date: 2026-11-12'));

    await openScreen(tester, note: saved);
    final meta = tester.widget<JournalEntryMetaRow>(
      find.byType(JournalEntryMetaRow),
    );
    expect(meta.meta.mood, JournalMood.happy);
    expect(meta.meta.entryAt, DateTime(2026, 11, 12, 9, 41));
  });
}