import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/journal/presentation/journal_screen.dart';
import '../../features/notes/presentation/note_folder.dart';
import '../../features/notes/presentation/notes_list_screen.dart';

/// The app's home: the Journal page when the folder is Journal, else the notes
/// list.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(noteFolderProvider) == NoteFolder.journal
        ? const JournalScreen()
        : const NotesListScreen();
  }
}
