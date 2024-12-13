import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:wanderlog_alt/widgets/blocks/flight_block.dart';
import 'package:wanderlog_alt/widgets/blocks/hotel_block.dart';
import 'package:wanderlog_alt/widgets/blocks/note_block.dart';
import 'package:wanderlog_alt/widgets/blocks/place_block.dart';
import 'package:wanderlog_alt/widgets/blocks/transit_block.dart';
import 'package:wanderlog_alt/services/trip_cache_service.dart';

class TripPage extends StatefulWidget {
  final String? tripId;
  const TripPage({super.key, required this.tripId});

  @override
  State<TripPage> createState() => TripPageState();
}

const apiUrl = "https://wanderlog.com/api/tripPlans/";
const bool isProduction = bool.fromEnvironment('dart.vm.product');

class TripPageState extends State<TripPage> {
  TripPlanResponse? plan;
  String? tripId;
  Map<DateTime, List<FlightBlock>> flightsByDate = {};
  Map<DateTime, List<PlaceBlock>> hotelsByDate = {};
  Map<DateTime, List<TransitBlock>> transitByDate = {};
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  Map<DateTime, GlobalKey> _dateKeys = {};
  final Map<DateTime, double> _sectionOffsets = {};
  final PageController _pageController = PageController();
  int _currentPage = 0;

  int _findTodayIndex(List<DateTime> dates) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return dates.indexWhere((date) {
      final compareDate = DateTime(date.year, date.month, date.day);
      return compareDate.isAtSameMomentAs(todayDate);
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateSectionOffsets);
    if (widget.tripId == null) {
      // Show dialog on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showTripIdDialog();
      });
    } else {
      tripId = widget.tripId;
      _loadTripWithCache();
    }
  }

  @override
  void didUpdateWidget(TripPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      reloadTrip(widget.tripId!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTripWithCache() async {
    if (tripId == null) return;

    // Try to load cached data first
    final cachedData = await TripCacheService.getCachedTrip(tripId!);
    if (cachedData != null) {
      _updateTripData(cachedData);
      return;
    }

    // Load fresh data
    await loadTripData();
  }

  void _updateTripData(Map<String, dynamic> tripData) {
    final fetchedPlan = TripPlanResponse.fromJson(tripData);

    // Create GlobalKeys for all dates when data loads
    final dateKeys = <DateTime, GlobalKey>{};
    final dates = fetchedPlan.tripPlan.itinerary.sections
        .where((s) => s.date != null)
        .map((s) => DateTime.parse(s.date!))
        .toList()
      ..sort();

    // Find today's index
    final todayIndex = _findTodayIndex(dates);
    final initialPage = todayIndex >= 0 ? todayIndex : 0;

    setState(() {
      flightsByDate = getFlightsByDate(fetchedPlan);
      hotelsByDate = getHotelsByDate(fetchedPlan);
      transitByDate = getTransitByDate(fetchedPlan);
      plan = fetchedPlan;
      _dateKeys = dateKeys;
      _isLoading = false;
      _currentPage = initialPage;
    });

    // Wait for the next frame when PageView is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(initialPage);
      }
    });
  }

  Future<void> loadTripData() async {
    if (tripId == null) {
      if (mounted) {
        // Show SnackBar saying that the trip ID is missing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip ID is missing'),
          ),
        );
      }
      return;
    }

    try {
      log("Loading trip data for $tripId");
      Uri url = Uri.parse('$apiUrl/$tripId?clientSchemaVersion=2');
      if (!isProduction) {
        url = Uri.parse("http://127.0.0.1:5005/thailand2.json");
      }

      final response = await http.get(url);
      final tripData = jsonDecode(response.body);

      // Cache the response
      await TripCacheService.cacheTrip(tripId!, tripData);

      // Update state with trip data
      _updateTripData(tripData);
    } catch (e) {
      log('Error loading trip data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trip data: ${e.toString()}')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void reloadTrip(String? newTripId) {
    setState(() {
      // Reset any existing state
      plan = null;
      tripId = newTripId;
      _isLoading = true;
    });
    _loadTripWithCache();
  }

  void showTripIdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Trip ID'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter the Wanderlog trip ID',
            ),
            autofocus: true,
            onSubmitted: (value) {
              Navigator.pop(context);
              reloadTrip(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context);
                  reloadTrip(controller.text);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void showError(e) {
    log('Error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch URL: $e'),
        ),
      );
    }
  }

  void _updateSectionOffsets() {
    for (final date in _dateKeys.keys) {
      final context = _dateKeys[date]?.currentContext;
      if (context != null) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        _sectionOffsets[date] = position.dy;
      }
    }
  }

  List<DateTime> _getSortedDates() {
    if (plan == null) return [];
    return plan!.tripPlan.itinerary.sections
        .where((s) => s.date != null)
        .map((s) => DateTime.parse(s.date!))
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && plan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (plan == null) {
      return Center(child: Text('No trip data for $tripId'));
    }

    final dates = _getSortedDates();
    final pm = getPlaceMetadata(plan!.resources.placeMetadata);

    return Scaffold(
      appBar: AppBar(
        title: Text('${plan!.tripPlan.title} ($tripId)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: CalendarStrip(
            dates: dates,
            selectedIndex: _currentPage,
            onDateSelected: (index) {
              _pageController.jumpToPage(index);
            },
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        itemCount: dates.length,
        // Add key to PageView for maintaining scroll position
        key: const PageStorageKey<String>('trip-page-view'),
        itemBuilder: (context, index) {
          final date = dates[index];
          final section = plan!.tripPlan.itinerary.sections.firstWhere(
            (s) {
              String formattedDate = DateFormat("yyyy-MM-dd").format(date);
              return s.date == formattedDate;
            },
            orElse: () => Section(
              date: date.toString(),
              heading: '',
              blocks: [],
            ),
          );

          return DayView(
            key: ValueKey('day-view-$date'),
            date: date,
            section: section,
            flights: flightsByDate[date] ?? [],
            hotels: hotelsByDate[date] ?? [],
            transit: transitByDate[date] ?? [],
            placeMetadata: pm,
          );
        },
      ),
    );
  }

  Map<DateTime, List<FlightBlock>> getFlightsByDate(
      TripPlanResponse fetchedPlan) {
    Map<DateTime, List<FlightBlock>> flightsByDate = {};
    for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
      for (Block block in section.blocks) {
        if (block is FlightBlock) {
          DateTime departDate = DateTime.parse(block.depart.date);
          DateTime arriveDate = DateTime.parse(block.arrive.date);

          if (!flightsByDate.containsKey(departDate)) {
            flightsByDate[departDate] = [];
          }
          flightsByDate[departDate]!.add(block);

          if (arriveDate != departDate) {
            if (!flightsByDate.containsKey(arriveDate)) {
              flightsByDate[arriveDate] = [];
            }
            flightsByDate[arriveDate]!.add(block);
          }
        }
      }
    }
    return flightsByDate;
  }

  Widget renderPlace(PlaceBlock placeBlock, PlaceMetadata? metadata) {
    if (placeBlock.hotel != null) {
      return HotelBlockWidget(
        placeBlock: placeBlock,
        metadata: metadata,
        initiallyExpanded: false,
      );
    }
    return PlaceBlockWidget(placeBlock: placeBlock, metadata: metadata);
  }

  Map<String, PlaceMetadata> getPlaceMetadata(
      List<PlaceMetadata> placemetadata) {
    Map<String, PlaceMetadata> pm = {};
    for (PlaceMetadata p in placemetadata) {
      pm[p.placeId] = p;
    }
    return pm;
  }

  Widget renderTransit(TransitBlock block, {bool initiallyExpanded = true}) {
    switch (block.type) {
      case "train":
        return TransitBlockWidget(
          transitBlock: block,
          transitType: TransitType.train,
          initiallyExpanded: initiallyExpanded,
        );
      case "bus":
        return TransitBlockWidget(
          transitBlock: block,
          transitType: TransitType.bus,
          initiallyExpanded: initiallyExpanded,
        );
      default:
        return TransitBlockWidget(
          transitBlock: block,
          transitType: TransitType.other,
          initiallyExpanded: initiallyExpanded,
        );
    }
  }
}

class TimelineSection extends StatelessWidget {
  final DateTime date;
  final Widget child;
  final bool isLast;

  const TimelineSection({
    super.key,
    required this.date,
    required this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((0.2 * 255).toInt()),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

Map<DateTime, List<PlaceBlock>> getHotelsByDate(TripPlanResponse fetchedPlan) {
  Map<DateTime, List<PlaceBlock>> hotelsByDate = {};
  for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
    for (Block block in section.blocks) {
      if (block is PlaceBlock) {
        if (block.hotel != null) {
          DateTime checkInDate = DateTime.parse(block.hotel!.checkIn!);
          DateTime checkOutDate = DateTime.parse(block.hotel!.checkOut!);

          if (checkInDate.isAfter(checkOutDate)) {
            log('Invalid hotel dates: $checkInDate - $checkOutDate');
            continue;
          }

          for (DateTime date = checkInDate;
              date.isBefore(checkOutDate);
              date = date.add(const Duration(days: 1))) {
            if (!hotelsByDate.containsKey(date)) {
              hotelsByDate[date] = [];
            }
            hotelsByDate[date]!.add(block);
          }
        }
      }
    }
  }
  return hotelsByDate;
}

Map<DateTime, List<TransitBlock>> getTransitByDate(
    TripPlanResponse fetchedPlan) {
  Map<DateTime, List<TransitBlock>> transitByDate = {};
  for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
    for (Block block in section.blocks) {
      if (block is TransitBlock) {
        DateTime departDate = DateTime.parse(block.depart.date);
        DateTime arriveDate = DateTime.parse(block.arrive.date);

        if (!transitByDate.containsKey(departDate)) {
          transitByDate[departDate] = [];
        }
        transitByDate[departDate]!.add(block);

        if (arriveDate != departDate) {
          if (!transitByDate.containsKey(arriveDate)) {
            transitByDate[arriveDate] = [];
          }
          transitByDate[arriveDate]!.add(block);
        }
      }
    }
  }
  return transitByDate;
}

List<String>? getListStrings(List<dynamic>? json) {
  if (json == null) {
    return null;
  }
  return json.map((item) => item.toString()).toList();
}

class DayView extends StatefulWidget {
  // Changed to StatefulWidget
  final DateTime date;
  final Section section;
  final List<FlightBlock> flights;
  final List<PlaceBlock> hotels;
  final List<TransitBlock> transit;
  final Map<String, PlaceMetadata> placeMetadata;

  const DayView({
    super.key,
    required this.date,
    required this.section,
    required this.flights,
    required this.hotels,
    required this.transit,
    required this.placeMetadata,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> with AutomaticKeepAliveClientMixin {
  late final List<PlaceBlock> _activities;

  @override
  void initState() {
    super.initState();
    _activities = widget.section.blocks
        .where((b) => b is PlaceBlock && (b).hotel == null)
        .cast<PlaceBlock>()
        .toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    return PageStorage(
      bucket: PageStorageBucket(),
      child: ListView(
        key: PageStorageKey('day-view-${widget.date}'),
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context),
          if (widget.flights.isNotEmpty) ...[
            _buildSectionTitle(context, 'Flights'),
            ...widget.flights.map(
              (f) => FlightBlockWidget(
                flightBlock: f,
                initiallyExpanded: false,
              ),
            ),
          ],
          if (widget.hotels.isNotEmpty) ...[
            _buildSectionTitle(context, 'Lodging'),
            ...widget.hotels.map(
              (h) => HotelBlockWidget(
                placeBlock: h,
                metadata: widget.placeMetadata[h.place.placeId],
                initiallyExpanded: false,
              ),
            ),
          ],
          if (widget.transit.isNotEmpty) ...[
            _buildSectionTitle(context, 'Transit'),
            ...widget.transit.map(
              (t) => TransitBlockWidget(
                transitBlock: t,
                transitType: getTransitType(t.type),
                initiallyExpanded: false,
              ),
            ),
          ],
          _buildSectionTitle(context, 'Activities'),
          ..._activities.map((b) => PlaceBlockWidget(
                placeBlock: b,
                metadata: widget.placeMetadata[b.place.placeId],
              )),
        ],
      ),
    );
  }

  // ... rest of the DayView methods remain the same ...
  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE').format(widget.date),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          Text(
            DateFormat('MMMM d, yyyy').format(widget.date),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (widget.section.heading.isNotEmpty)
            Text(
              widget.section.heading,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  TransitType getTransitType(String type) {
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

class CalendarStrip extends StatelessWidget {
  final List<DateTime> dates;
  final int selectedIndex;
  final Function(int) onDateSelected;

  const CalendarStrip({
    super.key,
    required this.dates,
    required this.selectedIndex,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = index == selectedIndex;

          return CalendarDay(
            date: date,
            isSelected: isSelected,
            onTap: () => onDateSelected(index),
          );
        },
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('E').format(date).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date.day.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('MMM').format(date).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
