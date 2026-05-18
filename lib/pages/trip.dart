import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trip_viewer/models/amount.dart';
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/services/day_text_formatter.dart';
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
import 'package:url_launcher/url_launcher.dart';

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
  static const _sortActivitiesByTimeKey = 'sort_activities_by_time';

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
  bool _sortActivitiesByTime = true;

  @override
  void initState() {
    super.initState();
    _loadDisplayPreferences();
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

  Future<void> _loadDisplayPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sortActivitiesByTime = prefs.getBool(_sortActivitiesByTimeKey) ?? true;
    });
  }

  Future<void> _setSortActivitiesByTime(bool value) async {
    setState(() => _sortActivitiesByTime = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sortActivitiesByTimeKey, value);
  }

  /// Stale-while-revalidate: show cached data immediately, refresh in background
  Future<void> _loadTripWithCache() async {
    final transaction = _startTripLoadTransaction('TripPage load');
    try {
      await _runSpan(
        transaction,
        'storage.update_last_accessed',
        'Update saved trip access time',
        () => TripStorageService.updateLastAccessed(
          widget.provider,
          widget.tripId,
        ),
      );
      final cachedData = await _runSpan(
        transaction,
        'cache.read',
        'Read cached trip data',
        () => TripCacheService.getCachedTrip(
          widget.provider,
          widget.tripId,
        ),
      );
      _lastFetchTime = await _runSpan(
        transaction,
        'cache.read_timestamp',
        'Read cached trip timestamp',
        () => TripCacheService.getLastFetchTime(
          widget.provider,
          widget.tripId,
        ),
      );

      if (cachedData != null) {
        transaction.setData('cache.hit', true);
        _updateTripData(
          cachedData,
          parentSpan: transaction,
          source: 'cache',
        );
        final shouldRefresh = await _runSpan(
          transaction,
          'cache.ttl_check',
          'Check cached trip freshness',
          () => TripCacheService.shouldRefresh(
            widget.provider,
            widget.tripId,
          ),
        );
        if (shouldRefresh) {
          _refreshInBackground();
        }
      } else {
        transaction.setData('cache.hit', false);
        await _fetchTripData(parentSpan: transaction);
      }
      transaction.status = const SpanStatus.ok();
    } catch (e, stackTrace) {
      transaction
        ..throwable = e
        ..status = const SpanStatus.internalError();
      _handleError(e, stackTrace);
    } finally {
      await transaction.finish(
        status: transaction.status ?? const SpanStatus.ok(),
      );
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final transaction =
        _startTripLoadTransaction('TripPage background refresh');
    try {
      await _fetchTripData(silent: true, parentSpan: transaction);
      transaction.status = const SpanStatus.ok();
    } catch (e, stackTrace) {
      transaction
        ..throwable = e
        ..status = const SpanStatus.internalError();
      log('Background refresh failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    } finally {
      await transaction.finish(
        status: transaction.status ?? const SpanStatus.ok(),
      );
    }
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _fetchTripData({
    bool silent = false,
    ISentrySpan? parentSpan,
  }) async {
    final transaction =
        parentSpan ?? _startTripLoadTransaction('TripPage fetch trip');
    try {
      log("Fetching trip data for ${widget.tripId}");
      final tripData = await _runSpan(
        transaction,
        'http.client',
        'Fetch trip from provider',
        () => TripProviderService.fetchTrip(
          provider: widget.provider,
          tripId: widget.tripId,
        ),
      );

      await _runSpan(
        transaction,
        'cache.write',
        'Write fetched trip cache',
        () => TripCacheService.cacheTrip(
          widget.provider,
          widget.tripId,
          tripData,
        ),
      );
      _lastFetchTime = DateTime.now();

      _updateTripData(
        tripData,
        parentSpan: transaction,
        source: 'network',
      );

      // Update trip metadata for trip list
      if (plan != null) {
        await _runSpan(
          transaction,
          'storage.update_metadata',
          'Update saved trip metadata',
          () => TripStorageService.updateTripMetadata(
            widget.provider,
            widget.tripId,
            plan!,
          ),
        );
      }
      transaction.status = const SpanStatus.ok();
    } catch (e, stackTrace) {
      transaction
        ..throwable = e
        ..status = const SpanStatus.internalError();
      if (parentSpan != null) {
        rethrow;
      } else if (!silent) {
        _handleError(e, stackTrace);
      } else {
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    } finally {
      if (parentSpan == null) {
        await transaction.finish(
          status: transaction.status ?? const SpanStatus.ok(),
        );
      }
    }
  }

  void _updateTripData(
    Map<String, dynamic> tripData, {
    ISentrySpan? parentSpan,
    String? source,
  }) {
    final TripPlanResponse fetchedPlan;
    try {
      fetchedPlan = _runSyncSpan(
        parentSpan,
        'json.parse',
        'Parse trip provider response',
        () => TripPlanResponse.fromJson(tripData),
      );
    } catch (e, stackTrace) {
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stackTrace,
          withScope: (scope) {
            scope.setTag('tripId', widget.tripId);
            scope.setContexts('trip_json_top_level', {
              'keys': tripData.keys.toList(),
              'tripPlan_keys':
                  (tripData['tripPlan'] as Map?)?.keys.toList() ?? const [],
              'itinerary_keys':
                  ((tripData['tripPlan'] as Map?)?['itinerary'] as Map?)
                          ?.keys
                          .toList() ??
                      const [],
            });
          },
        ),
      );
      rethrow;
    }
    parentSpan?.setData('trip.source', source);
    parentSpan?.setData(
      'trip.section_count',
      fetchedPlan.tripPlan.itinerary.sections.length,
    );
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

  ISentrySpan _startTripLoadTransaction(String name) {
    final transaction = Sentry.startTransaction(
      name,
      'trip.load',
      bindToScope: true,
    );
    transaction.setTag('trip.provider', widget.provider.name);
    transaction.setData('trip.id_length', widget.tripId.length);
    return transaction;
  }

  Future<T> _runSpan<T>(
    ISentrySpan parentSpan,
    String operation,
    String description,
    Future<T> Function() callback,
  ) async {
    final span = parentSpan.startChild(
      operation,
      description: description,
    );
    try {
      final result = await callback();
      await span.finish(status: const SpanStatus.ok());
      return result;
    } catch (e) {
      span
        ..throwable = e
        ..status = const SpanStatus.internalError();
      await span.finish(status: span.status);
      rethrow;
    }
  }

  T _runSyncSpan<T>(
    ISentrySpan? parentSpan,
    String operation,
    String description,
    T Function() callback,
  ) {
    if (parentSpan == null) return callback();

    final span = parentSpan.startChild(
      operation,
      description: description,
    );
    try {
      final result = callback();
      unawaited(span.finish(status: const SpanStatus.ok()));
      return result;
    } catch (e) {
      span
        ..throwable = e
        ..status = const SpanStatus.internalError();
      unawaited(span.finish(status: span.status));
      rethrow;
    }
  }

  void _handleError(Object e, [StackTrace? stackTrace]) {
    final effectiveStackTrace =
        stackTrace ?? (e is Error ? e.stackTrace : null);
    log('Failed to load trip data: $e', stackTrace: effectiveStackTrace);
    unawaited(
      Sentry.captureException(e, stackTrace: effectiveStackTrace),
    );
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
          PopupMenuButton(
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'sortActivitiesByTime',
                checked: _sortActivitiesByTime,
                child: const ListTile(
                  leading: Icon(Icons.schedule),
                  title: Text('Sort activities by time'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Trip Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
                case 'sortActivitiesByTime':
                  unawaited(
                    _setSortActivitiesByTime(!_sortActivitiesByTime),
                  );
                  break;
                case 'info':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TripInfoPage(
                        provider: widget.provider,
                        tripId: widget.tripId,
                        plan: plan!,
                        lastFetchTime: _lastFetchTime,
                      ),
                    ),
                  );
                  break;
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
              tripTitle: plan!.tripPlan.title,
              tripId: widget.tripId,
              provider: widget.provider,
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
            sortActivitiesByTime: _sortActivitiesByTime,
            tripTitle: plan!.tripPlan.title,
            tripId: widget.tripId,
            provider: widget.provider,
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
  final bool sortActivitiesByTime;
  final String tripTitle;
  final String tripId;
  final TripProvider provider;
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
    required this.tripTitle,
    required this.tripId,
    required this.provider,
    this.compactMode = false,
    this.sortActivitiesByTime = true,
    this.onRefresh,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> with AutomaticKeepAliveClientMixin {
  final Map<String, GlobalKey> _timedItemKeys = {};

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
    final activityEntries = _activityEntries();

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
            ...widget.flights.indexed.map(
              (entry) {
                final (index, f) = entry;
                return Padding(
                  key: _targetKey(_flightTargetId(f, index)),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FlightBlockWidget(
                    flightBlock: f,
                    initiallyExpanded: false,
                    expense: widget.expensesById[f.expenseId],
                  ),
                );
              },
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
            ...widget.transit.indexed.map(
              (entry) {
                final (index, t) = entry;
                return Padding(
                  key: _targetKey(_transitTargetId(t, index)),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransitBlockWidget(
                    transitBlock: t,
                    transitType: _getTransitType(t.type),
                    initiallyExpanded: false,
                    expense: widget.expensesById[t.expenseId],
                  ),
                );
              },
            ),
          ],
          if (activityEntries.isNotEmpty) ...[
            _SectionLabel(label: 'Activities', icon: Icons.place),
            ...activityEntries.map((entry) {
              final index = entry.index;
              final b = entry.block;
              if (b is PlaceBlock) {
                return Padding(
                  key: _targetKey(_placeTargetId(b, index)),
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

  List<({int index, Block block})> _activityEntries() {
    final entries = widget.section.blocks.indexed
        .map((entry) => (index: entry.$1, block: entry.$2))
        .toList();

    if (!widget.sortActivitiesByTime) return entries;

    entries.sort((a, b) {
      final aTime = _activitySortTime(a.block);
      final bTime = _activitySortTime(b.block);

      if (aTime != null && bTime != null) {
        final timeOrder = _compareTimes(aTime, bTime);
        if (timeOrder != 0) return timeOrder;
      } else if (aTime != null) {
        return -1;
      } else if (bTime != null) {
        return 1;
      }

      return a.index.compareTo(b.index);
    });

    return entries;
  }

  TimeOfDay? _activitySortTime(Block block) {
    return block is PlaceBlock ? _parseTimeOfDay(block.startTime) : null;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: nextItem == null ? null : () => _activateNextItem(nextItem),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
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
                  if (nextItem != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      nextItem.place == null
                          ? Icons.expand_more
                          : Icons.map_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            if (summaryItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in summaryItems)
                      _DaySummaryChip(item: item),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int get _activityCount => widget.section.blocks
      .where((block) => block is PlaceBlock && block.hotel == null)
      .length;

  _TimedSummaryItem? _nextTimedItem() {
    final items = <_TimedSummaryItem>[];

    for (final entry in widget.flights.indexed) {
      final (index, flight) = entry;
      final time = _parseTimeOfDay(flight.depart.time);
      if (time == null) continue;
      items.add(
        _TimedSummaryItem(
          time: flight.depart.time,
          sortTime: time,
          title:
              '${flight.flightInfo.flightNumber} to ${flight.arrive.airport.iata}',
          targetId: _flightTargetId(flight, index),
          place: flight.depart.airport.googlePlace,
        ),
      );
    }

    for (final entry in widget.transit.indexed) {
      final (index, transit) = entry;
      final rawTime = transit.depart.time;
      if (rawTime == null || rawTime.isEmpty) continue;
      final time = _parseTimeOfDay(rawTime);
      if (time == null) continue;
      items.add(
        _TimedSummaryItem(
          time: rawTime,
          sortTime: time,
          title: transit.arrive.place.name,
          targetId: _transitTargetId(transit, index),
          place: transit.depart.place,
        ),
      );
    }

    for (final entry in widget.section.blocks.indexed) {
      final (index, block) = entry;
      if (block is! PlaceBlock) continue;
      final rawTime = block.startTime;
      if (rawTime == null || rawTime.isEmpty) continue;
      final time = _parseTimeOfDay(rawTime);
      if (time == null) continue;
      items.add(_TimedSummaryItem(
        time: rawTime,
        sortTime: time,
        title: block.place.name,
        targetId: _placeTargetId(block, index),
        place: block.place,
      ));
    }

    if (items.isEmpty) return null;
    items.sort((a, b) => _compareTimes(a.sortTime, b.sortTime));

    if (_isSameDate(widget.date, DateTime.now())) {
      final now = TimeOfDay.now();
      for (final item in items) {
        if (_compareTimes(item.sortTime, now) >= 0) return item;
      }
      return items.last;
    }

    return items.first;
  }

  GlobalKey _targetKey(String targetId) {
    return _timedItemKeys.putIfAbsent(targetId, GlobalKey.new);
  }

  String _flightTargetId(FlightBlock flight, int index) {
    return 'flight-$index-${flight.depart.date}-${flight.depart.time}-${flight.flightInfo.flightNumber}';
  }

  String _transitTargetId(TransitBlock transit, int index) {
    return 'transit-$index-${transit.depart.time}-${transit.depart.place.placeId}-${transit.arrive.place.placeId}';
  }

  String _placeTargetId(PlaceBlock block, int index) {
    return 'place-$index-${block.startTime}-${block.place.placeId}';
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?',
    ).firstMatch(value);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    final meridiem = match.group(3)?.toLowerCase();
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'am') {
        if (hour == 12) hour = 0;
      } else if (hour != 12) {
        hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) {
    return (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _activateNextItem(_TimedSummaryItem item) async {
    if (item.place != null && await _openPlaceInMaps(item.place!)) return;
    await _scrollToTimedItem(item);
  }

  Future<bool> _openPlaceInMaps(GooglePlace place) async {
    final url = place.url;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          )) {
        return true;
      }
    }

    Uri? uri;
    if (place.placeId.isNotEmpty) {
      uri = Uri.https(
        'www.google.com',
        '/maps/search/',
        {
          'api': '1',
          'query': place.name,
          'query_place_id': place.placeId,
        },
      );
    } else {
      final query = [place.name, place.formattedAddress]
          .where((part) => part.isNotEmpty)
          .join(', ');
      if (query.isNotEmpty) {
        uri = Uri.https(
          'www.google.com',
          '/maps/search/',
          {'api': '1', 'query': query},
        );
      }
    }

    return uri != null &&
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
  }

  Future<void> _scrollToTimedItem(_TimedSummaryItem item) async {
    final targetContext = _timedItemKeys[item.targetId]?.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
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
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy day',
            onPressed: _copyDay,
          ),
        ],
      ),
    );
  }

  Future<void> _copyDay() async {
    final text = formatDayAsText(
      tripTitle: widget.tripTitle,
      tripId: widget.tripId,
      provider: widget.provider,
      date: widget.date,
      section: widget.section,
      flights: widget.flights,
      hotels: widget.hotels,
      transit: widget.transit,
      placeMetadata: widget.placeMetadata,
      expensesById: widget.expensesById,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Day copied to clipboard')),
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
  final TimeOfDay sortTime;
  final String title;
  final String targetId;
  final GooglePlace? place;

  const _TimedSummaryItem({
    required this.time,
    required this.sortTime,
    required this.title,
    required this.targetId,
    this.place,
  });
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
  final String tripTitle;
  final String tripId;
  final TripProvider provider;
  final Future<void> Function()? onRefresh;

  const UnscheduledSectionView({
    super.key,
    required this.section,
    required this.placeMetadata,
    required this.expensesById,
    required this.tripTitle,
    required this.tripId,
    required this.provider,
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
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy section',
                  onPressed: _copySection,
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

  Future<void> _copySection() async {
    final text = formatUnscheduledSectionAsText(
      tripTitle: widget.tripTitle,
      tripId: widget.tripId,
      provider: widget.provider,
      section: widget.section,
      placeMetadata: widget.placeMetadata,
      expensesById: widget.expensesById,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Section copied to clipboard')),
    );
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
