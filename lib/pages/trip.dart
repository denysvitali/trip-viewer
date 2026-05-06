import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trip_viewer/models/amount.dart';
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/services/trip_cache_service.dart';
import 'package:trip_viewer/services/trip_provider_service.dart';
import 'package:trip_viewer/services/trip_storage_service.dart';
import 'package:trip_viewer/widgets/blocks/flight_block.dart';
import 'package:trip_viewer/widgets/blocks/hotel_block.dart';
import 'package:trip_viewer/widgets/blocks/note_block.dart';
import 'package:trip_viewer/widgets/blocks/place_block.dart';
import 'package:trip_viewer/widgets/blocks/transit_block.dart';
import 'package:trip_viewer/pages/expenses.dart';
import 'package:trip_viewer/pages/budget.dart';
import 'package:trip_viewer/pages/map_view.dart';
import 'package:trip_viewer/pages/packing_list.dart';
import 'package:trip_viewer/pages/trip_info.dart';
import 'package:trip_viewer/widgets/text_container_widget.dart';

class TripPage extends StatefulWidget {
  final TripProvider provider;
  final String tripId;
  final String? tripTitle;

  const TripPage({
    super.key,
    this.provider = TripProvider.wanderlog,
    required this.tripId,
    this.tripTitle,
  });

  @override
  State<TripPage> createState() => TripPageState();
}

class TripPageState extends State<TripPage> {
  TripPlanResponse? plan;
  Map<DateTime, List<FlightBlock>> flightsByDate = {};
  Map<DateTime, List<PlaceBlock>> hotelsByDate = {};
  Map<DateTime, List<TransitBlock>> transitByDate = {};
  Map<int, Expense> expensesById = {};
  List<Section> _unscheduledSections = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastFetchTime;
  final PageController _pageController = PageController();
  final ScrollController _calendarScrollController = ScrollController();
  int _currentPage = 0;
  bool _compactMode = false;

  @override
  void initState() {
    super.initState();
    _loadTripWithCache();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _calendarScrollController.dispose();
    super.dispose();
  }

  int _findMostRelevantDayIndex(List<DateTime> dates) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    for (int i = 0; i < dates.length; i++) {
      final compareDate = DateTime(dates[i].year, dates[i].month, dates[i].day);
      if (compareDate.isAtSameMomentAs(todayDate)) return i;
      if (compareDate.isAfter(todayDate)) return i;
    }
    return dates.length - 1;
  }

  /// Stale-while-revalidate: show cached data immediately, refresh in background
  Future<void> _loadTripWithCache() async {
    try {
      await TripStorageService.updateLastAccessed(
        widget.provider,
        widget.tripId,
      );
      final cachedData = await TripCacheService.getCachedTrip(
        widget.provider,
        widget.tripId,
      );
      _lastFetchTime = await TripCacheService.getLastFetchTime(
        widget.provider,
        widget.tripId,
      );

      if (cachedData != null) {
        _updateTripData(cachedData);
        if (await TripCacheService.shouldRefresh(
          widget.provider,
          widget.tripId,
        )) {
          _refreshInBackground();
        }
      } else {
        await _fetchTripData();
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _fetchTripData(silent: true);
    } catch (e) {
      log('Background refresh failed: $e');
    }
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _fetchTripData({bool silent = false}) async {
    try {
      log("Fetching trip data for ${widget.tripId}");
      final tripData = await TripProviderService.fetchTrip(
        provider: widget.provider,
        tripId: widget.tripId,
      );

      await TripCacheService.cacheTrip(
        widget.provider,
        widget.tripId,
        tripData,
      );
      _lastFetchTime = DateTime.now();

      _updateTripData(tripData);

      // Update trip metadata for trip list
      if (plan != null) {
        await TripStorageService.updateTripMetadata(
          widget.provider,
          widget.tripId,
          plan!,
        );
      }
    } catch (e) {
      if (!silent) _handleError(e);
    }
  }

  void _updateTripData(Map<String, dynamic> tripData) {
    final fetchedPlan = TripPlanResponse.fromJson(tripData);
    final dates = fetchedPlan.tripPlan.itinerary.sections
        .where((s) => s.date != null)
        .map((s) => DateTime.parse(s.date!))
        .toList()
      ..sort();

    // Collect unscheduled sections (those without a date, with non-empty blocks)
    final unscheduled = fetchedPlan.tripPlan.itinerary.sections
        .where((s) => s.date == null && s.blocks.isNotEmpty)
        .toList();

    final mostRelevantDayIndex = _findMostRelevantDayIndex(dates);
    // Offset by unscheduled sections count
    final initialPage = unscheduled.length +
        (mostRelevantDayIndex >= 0 ? mostRelevantDayIndex : 0);

    setState(() {
      flightsByDate = _getFlightsByDate(fetchedPlan);
      hotelsByDate = _getHotelsByDate(fetchedPlan);
      transitByDate = _getTransitByDate(fetchedPlan);
      expensesById = _getExpensesById(fetchedPlan);
      _unscheduledSections = unscheduled;
      plan = fetchedPlan;
      _isLoading = false;
      _currentPage = initialPage;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(initialPage);
      }
      _scrollCalendarToIndex(initialPage);
    });
  }

  void _handleError(dynamic e) {
    if (e is Error) {
      log('Failed to load trip data: $e', stackTrace: e.stackTrace);
    } else {
      log('Failed to load trip data: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load trip data: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _scrollCalendarToIndex(int index) {
    if (!_calendarScrollController.hasClients) return;
    const itemWidth = 56.0; // 48 width + 8 padding
    final offset = (index * itemWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (itemWidth / 2);
    _calendarScrollController.animateTo(
      offset.clamp(0.0, _calendarScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  List<DateTime> _getSortedDates() {
    Set<DateTime> dateSet = {};
    if (plan != null) {
      dateSet.addAll(
        plan!.tripPlan.itinerary.sections
            .where((s) => s.date != null)
            .map((s) => DateTime.parse(s.date!)),
      );
    }
    dateSet.addAll(flightsByDate.keys);
    dateSet.addAll(hotelsByDate.keys);
    dateSet.addAll(transitByDate.keys);
    return dateSet.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && plan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tripTitle ?? 'Loading...')),
        body: _buildLoadingSkeleton(),
      );
    }
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tripTitle ?? widget.tripId)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load trip data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadTripWithCache();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final dates = _getSortedDates();
    final pm = _getPlaceMetadataMap(plan!.resources.placeMetadata);
    final totalPages = _unscheduledSections.length + dates.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan!.tripPlan.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              _lastFetchTime == null
                  ? 'ID: ${widget.tripId}'
                  : 'ID: ${widget.tripId} - Updated ${timeago.format(_lastFetchTime!)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _compactMode
                  ? Icons.view_agenda_outlined
                  : Icons.format_list_bulleted,
            ),
            tooltip: _compactMode ? 'Comfortable mode' : 'Compact mode',
            onPressed: () => setState(() => _compactMode = !_compactMode),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Map View',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapView(tripPlan: plan!.tripPlan),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Trip Info',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripInfoPage(
                  provider: widget.provider,
                  tripId: widget.tripId,
                  plan: plan!,
                  lastFetchTime: _lastFetchTime,
                ),
              ),
            ),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'packing',
                child: ListTile(
                  leading: Icon(Icons.checklist),
                  title: Text('Packing List'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'budget',
                child: ListTile(
                  leading: Icon(Icons.account_balance_wallet),
                  title: Text('Budget'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'expenses',
                child: ListTile(
                  leading: Icon(Icons.receipt_long),
                  title: Text('Expenses'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'packing':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PackingListPage(
                        tripPlan: plan!.tripPlan,
                        tripId: widget.tripId,
                      ),
                    ),
                  );
                  break;
                case 'budget':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BudgetPage(budget: plan!.tripPlan.itinerary.budget),
                    ),
                  );
                  break;
                case 'expenses':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ExpensesPage(expenses: plan!.tripPlan.expenses),
                    ),
                  );
                  break;
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Column(
            children: [
              if (_isRefreshing)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: CalendarStrip(
                  dates: dates,
                  selectedIndex: _currentPage,
                  unscheduledSections: _unscheduledSections,
                  scrollController: _calendarScrollController,
                  onDateSelected: (index) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() => _currentPage = page);
          _scrollCalendarToIndex(page);
        },
        itemCount: totalPages,
        key: const PageStorageKey<String>('trip-page-view'),
        itemBuilder: (context, index) {
          // Unscheduled sections come first
          if (index < _unscheduledSections.length) {
            final section = _unscheduledSections[index];
            return UnscheduledSectionView(
              key: ValueKey('unscheduled-${section.heading}'),
              section: section,
              placeMetadata: pm,
              expensesById: expensesById,
              onRefresh: () => _fetchTripData(),
            );
          }

          // Dated sections
          final dateIndex = index - _unscheduledSections.length;
          final date = dates[dateIndex];
          final section = plan!.tripPlan.itinerary.sections.firstWhere(
            (s) {
              String formattedDate = DateFormat("yyyy-MM-dd").format(date);
              return s.date == formattedDate;
            },
            orElse: () =>
                Section(date: date.toString(), heading: '', blocks: []),
          );

          return DayView(
            key: ValueKey('day-view-$date'),
            date: date,
            section: section,
            flights: flightsByDate[date] ?? [],
            hotels: hotelsByDate[date] ?? [],
            transit: transitByDate[date] ?? [],
            placeMetadata: pm,
            expensesById: expensesById,
            compactMode: _compactMode,
            onRefresh: () => _fetchTripData(),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Calendar skeleton
          Container(
            height: 60,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Day header skeleton
          Container(
            height: 20,
            width: 100,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            height: 28,
            width: 200,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Card skeletons
          for (int i = 0; i < 4; i++)
            Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }

  Map<DateTime, List<FlightBlock>> _getFlightsByDate(
    TripPlanResponse fetchedPlan,
  ) {
    Map<DateTime, List<FlightBlock>> result = {};
    for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
      for (Block block in section.blocks) {
        if (block is FlightBlock) {
          DateTime departDate = DateTime.parse(block.depart.date);
          DateTime arriveDate = DateTime.parse(block.arrive.date);
          result.putIfAbsent(departDate, () => []).add(block);
          if (arriveDate != departDate) {
            result.putIfAbsent(arriveDate, () => []).add(block);
          }
        }
      }
    }
    return result;
  }

  Map<DateTime, List<PlaceBlock>> _getHotelsByDate(
    TripPlanResponse fetchedPlan,
  ) {
    Map<DateTime, List<PlaceBlock>> result = {};
    for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
      for (Block block in section.blocks) {
        if (block is PlaceBlock && block.hotel != null) {
          DateTime checkInDate = DateTime.parse(block.hotel!.checkIn!);
          DateTime checkOutDate = DateTime.parse(block.hotel!.checkOut!);
          if (checkInDate.isAfter(checkOutDate)) continue;
          for (DateTime date = checkInDate;
              date.isBefore(checkOutDate);
              date = date.add(const Duration(days: 1))) {
            result.putIfAbsent(date, () => []).add(block);
          }
        }
      }
    }
    return result;
  }

  Map<DateTime, List<TransitBlock>> _getTransitByDate(
    TripPlanResponse fetchedPlan,
  ) {
    Map<DateTime, List<TransitBlock>> result = {};
    for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
      for (Block block in section.blocks) {
        if (block is TransitBlock) {
          DateTime departDate = DateTime.parse(block.depart.date);
          DateTime arriveDate = DateTime.parse(block.arrive.date);
          result.putIfAbsent(departDate, () => []).add(block);
          if (arriveDate != departDate) {
            result.putIfAbsent(arriveDate, () => []).add(block);
          }
        }
      }
    }
    for (var date in result.keys) {
      result[date]!.sort((a, b) {
        final aTime = a.depart.time ?? '00:00';
        final bTime = b.depart.time ?? '00:00';
        return aTime.compareTo(bTime);
      });
    }
    return result;
  }

  Map<int, Expense> _getExpensesById(TripPlanResponse fetchedPlan) {
    return {
      for (final expense in fetchedPlan.tripPlan.expenses) expense.id: expense,
    };
  }

  Map<String, PlaceMetadata> _getPlaceMetadataMap(
    List<PlaceMetadata> placeMetadata,
  ) {
    return {for (final p in placeMetadata) p.placeId: p};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DayView
// ─────────────────────────────────────────────────────────────────────────────

class DayView extends StatefulWidget {
  final DateTime date;
  final Section section;
  final List<FlightBlock> flights;
  final List<PlaceBlock> hotels;
  final List<TransitBlock> transit;
  final Map<String, PlaceMetadata> placeMetadata;
  final Map<int, Expense> expensesById;
  final bool compactMode;
  final Future<void> Function()? onRefresh;

  const DayView({
    super.key,
    required this.date,
    required this.section,
    required this.flights,
    required this.hotels,
    required this.transit,
    required this.placeMetadata,
    required this.expensesById,
    this.compactMode = false,
    this.onRefresh,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool get _isEmpty =>
      widget.flights.isEmpty &&
      widget.hotels.isEmpty &&
      widget.transit.isEmpty &&
      widget.section.blocks.isEmpty &&
      widget.section.text == null;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () => Future.value(),
      child: ListView(
        key: PageStorageKey('day-view-${widget.date}'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeader(theme),
          if (!_isEmpty) _buildDaySummary(theme),
          if (widget.section.text != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextContainerWidget(textContainer: widget.section.text!),
            ),
          if (_isEmpty) _buildEmptyDay(theme),
          if (widget.flights.isNotEmpty) ...[
            _SectionLabel(label: 'Flights', icon: Icons.flight),
            ...widget.flights.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FlightBlockWidget(
                  flightBlock: f,
                  initiallyExpanded: false,
                  expense: widget.expensesById[f.expenseId],
                ),
              ),
            ),
          ],
          if (widget.hotels.isNotEmpty) ...[
            _SectionLabel(label: 'Lodging', icon: Icons.hotel),
            ...widget.hotels.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HotelBlockWidget(
                  placeBlock: h,
                  metadata: widget.placeMetadata[h.place.placeId],
                  initiallyExpanded: false,
                  expense: widget.expensesById[h.expenseId],
                ),
              ),
            ),
          ],
          if (widget.transit.isNotEmpty) ...[
            _SectionLabel(label: 'Transit', icon: Icons.directions_transit),
            ...widget.transit.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TransitBlockWidget(
                  transitBlock: t,
                  transitType: _getTransitType(t.type),
                  initiallyExpanded: false,
                  expense: widget.expensesById[t.expenseId],
                ),
              ),
            ),
          ],
          if (widget.section.blocks.isNotEmpty) ...[
            _SectionLabel(label: 'Activities', icon: Icons.place),
            ...widget.section.blocks.map((b) {
              if (b is PlaceBlock) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PlaceBlockWidget(
                    placeBlock: b,
                    metadata: widget.placeMetadata[b.place.placeId],
                    expense: widget.expensesById[b.expenseId],
                    compact: widget.compactMode,
                  ),
                );
              }
              if (b is NoteBlock) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NoteBlockWidget(block: b),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySummary(ThemeData theme) {
    final nextItem = _nextTimedItem();
    final plannedSpend = _plannedSpendLabel();
    final summaryItems = <_DaySummaryItem>[
      if (widget.flights.isNotEmpty)
        _DaySummaryItem(
          icon: Icons.flight_takeoff,
          label: 'Flights',
          value: widget.flights.length.toString(),
        ),
      if (widget.transit.isNotEmpty)
        _DaySummaryItem(
          icon: Icons.directions_transit,
          label: 'Transit',
          value: widget.transit.length.toString(),
        ),
      if (widget.hotels.isNotEmpty)
        _DaySummaryItem(
          icon: Icons.hotel,
          label: 'Lodging',
          value: widget.hotels.length.toString(),
        ),
      if (_activityCount > 0)
        _DaySummaryItem(
          icon: Icons.place_outlined,
          label: 'Stops',
          value: _activityCount.toString(),
        ),
      if (plannedSpend != null)
        _DaySummaryItem(
          icon: Icons.receipt_long_outlined,
          label: 'Known spend',
          value: plannedSpend,
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.route_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'At a glance',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextItem == null
                          ? 'No timed items yet'
                          : 'Next: ${nextItem.time} - ${nextItem.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summaryItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summaryItems
                  .map((item) => _DaySummaryChip(item: item))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  int get _activityCount => widget.section.blocks
      .where((block) => block is PlaceBlock && block.hotel == null)
      .length;

  _TimedSummaryItem? _nextTimedItem() {
    final items = <_TimedSummaryItem>[];

    for (final flight in widget.flights) {
      items.add(
        _TimedSummaryItem(
          time: flight.depart.time,
          title:
              '${flight.flightInfo.flightNumber} to ${flight.arrive.airport.iata}',
        ),
      );
    }

    for (final transit in widget.transit) {
      final time = transit.depart.time;
      if (time == null || time.isEmpty) continue;
      items.add(
        _TimedSummaryItem(
          time: time,
          title: transit.arrive.place.name,
        ),
      );
    }

    for (final block in widget.section.blocks) {
      if (block is! PlaceBlock) continue;
      final time = block.startTime;
      if (time == null || time.isEmpty) continue;
      items.add(_TimedSummaryItem(time: time, title: block.place.name));
    }

    if (items.isEmpty) return null;
    items.sort((a, b) => a.time.compareTo(b.time));
    return items.first;
  }

  String? _plannedSpendLabel() {
    final expenseIds = <int>{};

    void addExpense(Block block) {
      final id = block.expenseId;
      if (id != null) expenseIds.add(id);
    }

    for (final flight in widget.flights) {
      addExpense(flight);
    }
    for (final hotel in widget.hotels) {
      addExpense(hotel);
    }
    for (final transit in widget.transit) {
      addExpense(transit);
    }
    for (final block in widget.section.blocks) {
      addExpense(block);
    }

    final totalsByCurrency = <String, double>{};
    for (final id in expenseIds) {
      final expense = widget.expensesById[id];
      if (expense == null) continue;
      final currency = expense.amount.currencyCode ?? '';
      totalsByCurrency[currency] =
          (totalsByCurrency[currency] ?? 0) + expense.amount.amount;
    }

    if (totalsByCurrency.isEmpty) return null;

    final labels = totalsByCurrency.entries.map((entry) {
      return Amount(amount: entry.value, currencyCode: entry.key).format();
    }).toList()
      ..sort();

    return labels.join(' + ');
  }

  Widget _buildHeader(ThemeData theme) {
    final today = DateTime.now();
    final isToday = widget.date.year == today.year &&
        widget.date.month == today.month &&
        widget.date.day == today.day;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('EEEE').format(widget.date),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Today',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  DateFormat('MMMM d, yyyy').format(widget.date),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.section.heading.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.section.heading,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 56,
            color: theme.colorScheme.primary.withAlpha(80),
          ),
          const SizedBox(height: 12),
          Text(
            'Free day',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing planned — enjoy exploring!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }

  TransitType _getTransitType(String type) {
    switch (type) {
      case 'train':
        return TransitType.train;
      case 'bus':
        return TransitType.bus;
      default:
        return TransitType.other;
    }
  }
}

class _DaySummaryChip extends StatelessWidget {
  final _DaySummaryItem item;

  const _DaySummaryChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            item.value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            item.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySummaryItem {
  final IconData icon;
  final String label;
  final String value;

  const _DaySummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _TimedSummaryItem {
  final String time;
  final String title;

  const _TimedSummaryItem({required this.time, required this.title});
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UnscheduledSectionView — displays sections without a date (wishlists, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class UnscheduledSectionView extends StatefulWidget {
  final Section section;
  final Map<String, PlaceMetadata> placeMetadata;
  final Map<int, Expense> expensesById;
  final Future<void> Function()? onRefresh;

  const UnscheduledSectionView({
    super.key,
    required this.section,
    required this.placeMetadata,
    required this.expensesById,
    this.onRefresh,
  });

  @override
  State<UnscheduledSectionView> createState() => _UnscheduledSectionViewState();
}

class _UnscheduledSectionViewState extends State<UnscheduledSectionView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  IconData _getSectionIcon(String heading) {
    final h = heading.toLowerCase();
    if (h.contains('flight')) return Icons.flight;
    if (h.contains('hotel') || h.contains('lodging')) return Icons.hotel;
    if (h.contains('transit')) return Icons.directions_transit;
    if (h.contains('suggestion')) return Icons.lightbulb_outline;
    if (h.contains('place') || h.contains('visit')) return Icons.explore;
    return Icons.list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () => Future.value(),
      child: ListView(
        key: PageStorageKey('unscheduled-${widget.section.heading}'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getSectionIcon(widget.section.heading),
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.section.heading,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.section.blocks.length} items',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.section.text != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextContainerWidget(textContainer: widget.section.text!),
            ),
          ...widget.section.blocks.map((b) {
            if (b is PlaceBlock) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PlaceBlockWidget(
                  placeBlock: b,
                  metadata: widget.placeMetadata[b.place.placeId],
                  expense: widget.expensesById[b.expenseId],
                ),
              );
            }
            if (b is FlightBlock) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FlightBlockWidget(
                  flightBlock: b,
                  initiallyExpanded: false,
                  expense: widget.expensesById[b.expenseId],
                ),
              );
            }
            if (b is TransitBlock) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TransitBlockWidget(
                  transitBlock: b,
                  transitType: _getTransitType(b.type),
                  initiallyExpanded: false,
                  expense: widget.expensesById[b.expenseId],
                ),
              );
            }
            if (b is NoteBlock) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NoteBlockWidget(block: b),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  TransitType _getTransitType(String type) {
    switch (type) {
      case 'train':
        return TransitType.train;
      case 'bus':
        return TransitType.bus;
      default:
        return TransitType.other;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CalendarStrip — with support for unscheduled section pills
// ─────────────────────────────────────────────────────────────────────────────

class CalendarStrip extends StatelessWidget {
  final List<DateTime> dates;
  final int selectedIndex;
  final Function(int) onDateSelected;
  final ScrollController? scrollController;
  final List<Section> unscheduledSections;

  const CalendarStrip({
    super.key,
    required this.dates,
    required this.selectedIndex,
    required this.onDateSelected,
    this.scrollController,
    this.unscheduledSections = const [],
  });

  IconData _getSectionIcon(String heading) {
    final h = heading.toLowerCase();
    if (h.contains('flight')) return Icons.flight;
    if (h.contains('hotel') || h.contains('lodging')) return Icons.hotel;
    if (h.contains('transit')) return Icons.directions_transit;
    if (h.contains('suggestion')) return Icons.lightbulb_outline;
    if (h.contains('place') || h.contains('visit')) return Icons.explore;
    return Icons.list;
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = unscheduledSections.length + dates.length;

    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index < unscheduledSections.length) {
            final section = unscheduledSections[index];
            return _SectionPill(
              icon: _getSectionIcon(section.heading),
              label: _abbreviateHeading(section.heading),
              isSelected: index == selectedIndex,
              onTap: () => onDateSelected(index),
            );
          }
          final dateIndex = index - unscheduledSections.length;
          return CalendarDay(
            date: dates[dateIndex],
            isSelected: index == selectedIndex,
            onTap: () => onDateSelected(index),
          );
        },
      ),
    );
  }

  String _abbreviateHeading(String heading) {
    if (heading.length <= 8) return heading;
    // Take first word
    final words = heading.split(' ');
    if (words.first.length <= 8) return words.first;
    return '${heading.substring(0, 6)}..';
  }
}

class _SectionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionPill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarDay extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  const CalendarDay({
    super.key,
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : isToday
                    ? theme.colorScheme.primaryContainer.withAlpha(100)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('E').format(date).substring(0, 2).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date.day.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
