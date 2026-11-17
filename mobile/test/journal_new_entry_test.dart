import 'dart:async';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/session/active_user_id_provider.dart';
import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/features/journal/presentation/journal_providers.dart';
import 'package:anchor/features/journal/presentation/journal_screen.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'reminder_permissions_test.dart' show FakeGateway;

class MockNotesRepository extends Mock implements NotesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockAttachmentsRepository extends Mock
    implements NoteAttachmentsRepository {}

class MockPreferencesRepository extends Mock implements PreferencesRepository {}

class FakeActiveUserId extends ActiveUserId {
  @override
  String? build() => 'user-1';
}

void main() {
  late MockNotesRepository notesRepo;
  late MockTagsRepository tagsRepo;
  late MockAttachmentsRepository attachmentsRepo;
  late MockPreferencesRepository prefsRepo;
  late FakeGateway gateway;

  const journal = Tag(id: 'j1', name: 'journal');

  setUpAll(() {
    registerFallbackValue(const Note(id: 'fallback', title: ''));
    registerFallbackValue(const Tag(id: '', name: ''));
  });

  setUp(() {
    notesRepo = MockNotesRepository();
    tagsRepo = MockTagsRepository();
    attachmentsRepo = MockAttachmentsRepository();
    prefsRepo = MockPreferencesRepository();

    when(() => notesRepo.createNote(any())).thenAnswer((_) async {});
    when(() => notesRepo.updateNote(any())).thenAnswer((_) async {});
    when(
      () => notesRepo.watchNote(any()),
    ).thenAnswer((_) => const Stream<Note?>.empty());
    when(
      () => tagsRepo.watchTags(),
    ).thenAnswer((_) => const Stream<List<Tag>>.empty());
    when(() => tagsRepo.getTags()).thenAnswer((_) async => const <Tag>[]);
    when(() => tagsRepo.createTag(any())).thenAnswer((_) async => journal);
    when(
      () => attachmentsRepo.watchAttachments(any()),
    ).thenAnswer((_) => Stream.value(const []));
    when(() => prefsRepo.getSortChecklistItems()).thenAnswer((_) async => true);
    when(() => prefsRepo.getExactAlarmsOffered()).thenAnswer((_) async => true);
    when(
      () => prefsRepo.getNotificationsAsked(),
    ).thenAnswer((_) async => false);
    when(() => prefsRepo.setNotificationsAsked(any())).thenAnswer((_) async {});
    gateway = FakeGateway();
  });

  testWidgets('the pencil creates the journal tag and opens a new entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo),
          tagsRepositoryProvider.overrideWithValue(tagsRepo),
          journalNotesProvider.overrideWith(
            (ref) => Stream.value(const <Note>[]),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          routerConfig: GoRouter(
            initialLocation: '/journal',
            routes: [
              GoRoute(
                path: '/journal',
                builder: (_, _) => const JournalScreen(),
              ),
              GoRoute(
                path: '/journal/new',
                builder: (_, _) => const Text('Journal new entry'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No entries yet'), findsOneWidget);
    await tester.tap(find.text('New entry'));
    await tester.pumpAndSettle();

    final created =
        verify(() => tagsRepo.createTag(captureAny())).captured.single as Tag;
    expect(created.name, 'journal');
    expect(find.text('Journal new entry'), findsOneWidget);
  });

  testWidgets('a new journal note saves with the journal tag and a header', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo),
          tagsRepositoryProvider.overrideWithValue(tagsRepo),
          noteAttachmentsRepositoryProvider.overrideWithValue(attachmentsRepo),
          preferencesRepositoryProvider.overrideWithValue(prefsRepo),
          serverUrlProvider.overrideWith((ref) => null),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream<List<ConnectivityResult>>.empty(),
          ),
          activeUserIdProvider.overrideWith(FakeActiveUserId.new),
          notificationGatewayProvider.overrideWithValue(gateway),
          journalTagProvider.overrideWithValue(journal),
        ],
        child: MaterialApp.router(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          routerConfig: GoRouter(
            initialLocation: '/note',
            routes: [
              GoRoute(
                path: '/note',
                builder: (_, _) => const NoteEditScreen(journal: true),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final editor = tester.state<RichTextEditorState>(
      find.byType(RichTextEditor),
    );
    editor.controller.replaceText(0, 0, 'hello', null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final captured = verify(() => notesRepo.createNote(captureAny())).captured;
    expect(captured, hasLength(1));
    final note = captured.single as Note;
    expect(note.tagIds, contains('j1'));
    expect(note.content, contains('date:'));
    expect(note.content, contains('time:'));
    expect(note.content, contains('---'));
    expect(note.content, contains('hello'));
  });
}