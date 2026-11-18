import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/bar_title.dart';
import '../../../../l10n/l10n.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/widgets/app_drawer.dart';
import '../../notes/presentation/widgets/drawer_host.dart';
import '../../notes/presentation/widgets/notes_bottom_bar.dart';
import '../domain/journal_day.dart';
import 'journal_providers.dart';
import 'widgets/journal_calendar.dart';
import 'widgets/journal_day_cards.dart';
import 'widgets/journal_stats_row.dart';
import 'widgets/journal_timeline.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _drawerKey = GlobalKey<DrawerHostState>();
  final _scroll = ScrollController();
  bool _calendar = false;
  bool _searching = false;
  DateTime? _selectedDay;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openMenu() => _drawerKey.currentState?.open();

  void _open(Note note) => context.go(AppRoutes.note(note.id), extra: note);

  Future<void> _newEntry() async {
    await ensureJournalTag(ref);
    if (!mounted) return;
    context.go(AppRoutes.journalNew);
  }

  void _startSearch() => setState(() => _searching = true);

  void _endSearch() {
    setState(() => _searching = false);
    ref.read(journalQueryProvider.notifier).set('');
  }

  DateTime _firstOfMonth(DateTime day) => DateTime(day.year, day.month, 1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = ref.watch(journalDaysProvider);
    final tag = ref.watch(journalTagProvider);
    final query = ref.watch(journalQueryProvider);

    final empty = tag == null || days.isEmpty;

    List<JournalDay> shownDays = days;
    final selected = _selectedDay;
    if (_calendar) {
      shownDays = selected == null
          ? const []
          : [
              for (final day in days)
                if (day.day.year == selected.year &&
                    day.day.month == selected.month &&
                    day.day.day == selected.day)
                  day,
            ];
    }

    final page = AppScaffold(
      title: l10n.navJournal,
      isTall: true,
      showBack: false,
      controller: _scroll,
      largeTitle: LargeBarTitle(
        l10n.navJournal,
        line: null,
        onTap: _openMenu,
        semanticLabel: l10n.listTitleMenu(l10n.navJournal),
      ),
      actions: [
        BarButton(
          icon: _calendar ? LucideIcons.rows3 : LucideIcons.calendarDays,
          label: _calendar ? l10n.journalTimeline : l10n.journalCalendar,
          onPressed: () => setState(() {
            _calendar = !_calendar;
            if (_calendar) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              _selectedDay = today;
              _month = _firstOfMonth(today);
            } else {
              _selectedDay = null;
            }
          }),
        ),
      ],
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (empty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              kind: EmptyStateKind.notes,
              title: l10n.journalEmptyTitle,
              message: l10n.journalEmptyHelp,
              action: AppButton(
                label: l10n.journalNew,
                icon: LucideIcons.plus,
                isExpanded: false,
                onPressed: _newEntry,
              ),
            ),
          )
        else ...[
          if (_calendar) ...[
            SliverToBoxAdapter(
              child: JournalCalendar(
                month: _month,
                entryCounts: ref.watch(journalEntryCountsProvider),
                selectedDay: _selectedDay,
                onPickDay: (day) => setState(() {
                  _selectedDay = day;
                  _month = _firstOfMonth(day);
                }),
                onPreviousMonth: () =>
                    setState(() => _month = _previousMonth()),
                onNextMonth: () => setState(() => _month = _nextMonth()),
              ),
            ),
            JournalDayCards(
              days: shownDays,
              journalTagId: tag.id,
              onOpen: _open,
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: JournalStatsRow(
                days: ref.watch(journalAllDaysProvider),
              ),
            ),
            JournalTimeline(days: shownDays, onOpen: _open),
          ],
        ],
      ],
      bottomBar: NotesBottomBar(
        placeholder: l10n.journalSearchHint,
        compact: false,
        searching: _searching,
        query: query,
        onStartSearch: _startSearch,
        onQuery: (q) => ref.read(journalQueryProvider.notifier).set(q),
        onCancel: _endSearch,
        onNewNote: _newEntry,
      ),
    );

    return DrawerHost(
      key: _drawerKey,
      canSwipeOpen: !_searching,
      drawerBuilder: (close) => AppDrawer(
        onClose: close,
        onOpenSettings: () => context.push(AppRoutes.settings),
        onOpenList: _endSearch,
      ),
      child: page,
    );
  }

  DateTime _previousMonth() {
    final previous = _month.subtract(const Duration(days: 1));
    return DateTime(previous.year, previous.month, 1);
  }

  DateTime _nextMonth() {
    final next = _month.month == 12
        ? DateTime(_month.year + 1, 1, 1)
        : DateTime(_month.year, _month.month + 1, 1);
    return next;
  }
}
