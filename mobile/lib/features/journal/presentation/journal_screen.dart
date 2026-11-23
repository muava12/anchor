import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/l10n.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/note_folder.dart';
import '../../notes/presentation/widgets/app_drawer.dart';
import '../../notes/presentation/widgets/drawer_host.dart';
import '../../notes/presentation/widgets/list_title.dart';
import '../../notes/presentation/widgets/notes_bottom_bar.dart';
import '../domain/journal_day.dart';
import 'journal_providers.dart';
import 'widgets/journal_calendar.dart';
import 'widgets/journal_cards_list.dart';
import 'widgets/journal_day_cards.dart';
import 'widgets/journal_section_header.dart';
import 'widgets/journal_stats_row.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _drawerKey = GlobalKey<DrawerHostState>();
  final _scroll = ScrollController();
  final _isBottomBarCompact = ValueNotifier(false);
  double _scrollDistance = 0;
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
    _isBottomBarCompact.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollUpdateNotification update) {
    final metrics = update.metrics;
    if (update.depth != 0 || metrics.axis != Axis.vertical || _searching) {
      return false;
    }
    if (metrics.pixels < 40) {
      _scrollDistance = 0;
      _isBottomBarCompact.value = false;
      return false;
    }
    final delta = update.scrollDelta ?? 0;
    if (delta == 0 || metrics.outOfRange) return false;
    _scrollDistance = delta.sign == _scrollDistance.sign
        ? _scrollDistance + delta
        : delta;
    if (_scrollDistance > 4) {
      _isBottomBarCompact.value = true;
    } else if (_scrollDistance < -4) {
      _isBottomBarCompact.value = false;
    }
    return false;
  }

  void _openMenu() => _drawerKey.currentState?.open();

  void _open(Note note) =>
      context.go(AppRoutes.journalEdit(note.id), extra: note);

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
      largeTitle: ListLargeTitle(
        folder: NoteFolder.journal,
        tag: null,
        onOpenMenu: _openMenu,
      ),
      barTitle: ListBarTitle(
        folder: NoteFolder.journal,
        tag: null,
        onOpenMenu: _openMenu,
      ),
      actions: [
        BarButton(
          icon: LucideIcons.calendarDays,
          label: _calendar ? l10n.journalTimeline : l10n.journalCalendar,
          isOn: _calendar ? true : null,
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
        // Placeholder for a future Notes-style view menu; no action yet.
        BarButton(
          icon: LucideIcons.layoutGrid,
          label: l10n.viewGrid,
          onPressed: null,
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
              child: JournalStatsRow(days: ref.watch(journalAllDaysProvider)),
            ),
            SliverToBoxAdapter(child: const JournalSectionHeader()),
            JournalCardsList(
              days: shownDays,
              journalTagId: tag.id,
              onOpen: _open,
            ),
          ],
        ],
      ],
      bottomBar: ValueListenableBuilder<bool>(
        valueListenable: _isBottomBarCompact,
        builder: (context, compact, _) => NotesBottomBar(
          placeholder: l10n.journalSearchHint,
          compact: compact,
          searching: _searching,
          query: query,
          onStartSearch: _startSearch,
          onQuery: (q) => ref.read(journalQueryProvider.notifier).set(q),
          onCancel: _endSearch,
          onNewNote: _newEntry,
        ),
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
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: _onScroll,
        child: page,
      ),
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
