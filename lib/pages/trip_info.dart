import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trip_viewer/models/amount.dart';
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/models/trip_plan.dart';

class TripInfoPage extends StatelessWidget {
  final TripProvider provider;
  final String tripId;
  final TripPlanResponse plan;
  final DateTime? lastFetchTime;

  const TripInfoPage({
    super.key,
    required this.provider,
    required this.tripId,
    required this.plan,
    this.lastFetchTime,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _TripStats.fromPlan(plan);
    final theme = Theme.of(context);
    final lastUpdatedLabel = lastFetchTime == null
        ? null
        : '${DateFormat.yMMMd().add_jm().format(lastFetchTime!)} '
            '(${timeago.format(lastFetchTime!)})';

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoSection(
            title: 'Overview',
            children: [
              _InfoRow(label: 'Title', value: plan.tripPlan.title),
              _InfoRow(
                label: 'Views',
                value: NumberFormat.decimalPattern().format(
                  plan.tripPlan.viewCount,
                ),
              ),
              _InfoRow(label: 'Provider', value: provider.displayName),
              _InfoRow(
                label: 'Trip ID',
                value: tripId,
                icon: Icons.copy_outlined,
                onLongPress: () => _copyTripId(context),
              ),
              if (lastUpdatedLabel != null)
                _InfoRow(label: 'Last updated', value: lastUpdatedLabel),
            ],
          ),
          const SizedBox(height: 12),
          _InfoSection(
            title: 'Schedule',
            children: [
              _InfoRow(label: 'Date range', value: stats.dateRangeLabel),
              _InfoRow(label: 'Scheduled days', value: stats.dayCountLabel),
              _InfoRow(
                label: 'Unscheduled sections',
                value: stats.unscheduledSections.toString(),
              ),
              _InfoRow(
                label: 'Total sections',
                value: stats.totalSections.toString(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoSection(
            title: 'Itinerary',
            children: [
              _InfoRow(label: 'Places', value: stats.placeCount.toString()),
              _InfoRow(label: 'Lodging', value: stats.hotelCount.toString()),
              _InfoRow(label: 'Flights', value: stats.flightCount.toString()),
              _InfoRow(label: 'Transit', value: stats.transitCount.toString()),
              _InfoRow(label: 'Notes', value: stats.noteCount.toString()),
              if (stats.otherBlockCount > 0)
                _InfoRow(
                  label: 'Other blocks',
                  value: stats.otherBlockCount.toString(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoSection(
            title: 'Budget',
            children: [
              _InfoRow(
                label: 'Budget amount',
                value: plan.tripPlan.itinerary.budget.amount.format(),
              ),
              _InfoRow(
                label: 'Expenses',
                value: stats.expenseCount.toString(),
              ),
              _InfoRow(
                label: 'Expense total',
                value: stats.expenseTotalLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoSection(
            title: 'Resources',
            children: [
              _InfoRow(
                label: 'Place metadata',
                value: stats.placeMetadataCount.toString(),
              ),
              _InfoRow(label: 'Images', value: stats.imageCount.toString()),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Source: ${provider.displayName}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _copyTripId(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: tripId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip ID copied')),
    );
  }
}

class _TripStats {
  final int totalSections;
  final int unscheduledSections;
  final int placeCount;
  final int hotelCount;
  final int flightCount;
  final int transitCount;
  final int noteCount;
  final int otherBlockCount;
  final int expenseCount;
  final int placeMetadataCount;
  final int imageCount;
  final String dateRangeLabel;
  final String dayCountLabel;
  final String expenseTotalLabel;

  const _TripStats({
    required this.totalSections,
    required this.unscheduledSections,
    required this.placeCount,
    required this.hotelCount,
    required this.flightCount,
    required this.transitCount,
    required this.noteCount,
    required this.otherBlockCount,
    required this.expenseCount,
    required this.placeMetadataCount,
    required this.imageCount,
    required this.dateRangeLabel,
    required this.dayCountLabel,
    required this.expenseTotalLabel,
  });

  factory _TripStats.fromPlan(TripPlanResponse response) {
    var placeCount = 0;
    var hotelCount = 0;
    var flightCount = 0;
    var transitCount = 0;
    var noteCount = 0;
    var otherBlockCount = 0;
    final blockImageKeys = <String>{};

    for (final section in response.tripPlan.itinerary.sections) {
      for (final block in section.blocks) {
        blockImageKeys.addAll(block.imageKeys);
        if (block is PlaceBlock) {
          if (block.hotel == null) {
            placeCount++;
          } else {
            hotelCount++;
          }
        } else if (block is FlightBlock) {
          flightCount++;
        } else if (block is TransitBlock) {
          transitCount++;
        } else if (block is NoteBlock) {
          noteCount++;
        } else {
          otherBlockCount++;
        }
      }
    }

    final datedSections = response.tripPlan.itinerary.sections
        .where((section) => section.date != null)
        .toList();
    final dates = datedSections
        .map((section) => DateTime.tryParse(section.date!))
        .whereType<DateTime>()
        .toList()
      ..sort();

    final resourceImageKeys = <String>{};
    for (final place in response.resources.placeMetadata) {
      resourceImageKeys.addAll(place.imageKeys);
    }

    return _TripStats(
      totalSections: response.tripPlan.itinerary.sections.length,
      unscheduledSections: response.tripPlan.itinerary.sections
          .where((section) => section.date == null)
          .length,
      placeCount: placeCount,
      hotelCount: hotelCount,
      flightCount: flightCount,
      transitCount: transitCount,
      noteCount: noteCount,
      otherBlockCount: otherBlockCount,
      expenseCount: response.tripPlan.expenses.length,
      placeMetadataCount: response.resources.placeMetadata.length,
      imageCount: {...blockImageKeys, ...resourceImageKeys}.length,
      dateRangeLabel: _dateRangeLabel(dates),
      dayCountLabel: _dayCountLabel(dates),
      expenseTotalLabel: _expenseTotalLabel(response.tripPlan.expenses),
    );
  }

  static String _dateRangeLabel(List<DateTime> dates) {
    if (dates.isEmpty) return 'No dated sections';
    final formatter = DateFormat.yMMMd();
    if (dates.length == 1) return formatter.format(dates.first);
    return '${formatter.format(dates.first)} - ${formatter.format(dates.last)}';
  }

  static String _dayCountLabel(List<DateTime> dates) {
    if (dates.isEmpty) return '0';
    final uniqueDates = dates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    return uniqueDates.length.toString();
  }

  static String _expenseTotalLabel(List<Expense> expenses) {
    if (expenses.isEmpty) return 'No expenses';

    final totalsByCurrency = <String, double>{};
    for (final expense in expenses) {
      final currency = expense.amount.currencyCode ?? '';
      totalsByCurrency[currency] =
          (totalsByCurrency[currency] ?? 0) + expense.amount.amount;
    }

    final labels = totalsByCurrency.entries.map((entry) {
      return Amount(amount: entry.value, currencyCode: entry.key).format();
    }).toList()
      ..sort();
    return labels.join(' + ');
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onLongPress;

  const _InfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
