import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/session/active_user_id_provider.dart';
import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_date_pill.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:anchor/features/notes/presentation/note_edit_screen.dart';
import 'package:anchor/features/reminders/data/notification_gateway.dart';
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

  testWidgets('the journal editor hides the header and shows the date pill', (
    tester,
  ) async {
    final note = journalNote();
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
                    NoteEditScreen(note: note, noteId: 'n1', journal: true),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final editor = tester.state<RichTextEditorState>(find.byType(RichTextEditor));
    final plain = editor.controller.document.toPlainText();
    expect(plain, isNot(contains('mood:')));
    expect(plain, contains('AM'));
    expect(find.byType(JournalDatePill), findsOneWidget);
  });
}
