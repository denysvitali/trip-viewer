import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/services/trip_storage_service.dart';
import 'package:trip_viewer/services/trip_provider_service.dart';
import 'package:trip_viewer/pages/trip.dart';
import 'package:trip_viewer/widgets/place_image.dart';

class TripListPage extends StatefulWidget {
  const TripListPage({super.key});

  @override
  State<TripListPage> createState() => _TripListPageState();
}

class _TripListPageState extends State<TripListPage> {
  List<SavedTrip> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    await TripStorageService.migrateLegacyTripId();
    final trips = await TripStorageService.getSavedTrips();
    if (mounted) {
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddTripDialog() async {
    final controller = TextEditingController();
    var selectedProvider = TripProvider.wanderlog;
    final reference = await showDialog<TripImportReference>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Trip'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<TripProvider>(
                initialValue: selectedProvider,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: TripProviderService.providers
                    .map(
                      (client) => DropdownMenuItem(
                        value: client.provider,
                        child: Text(client.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (provider) {
                  if (provider == null) return;
                  setDialogState(() => selectedProvider = provider);
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Enter a trip ID or paste a trip URL',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. vevtulccsc or a trip URL',
                ),
                onSubmitted: (value) {
                  if (value.isEmpty) return;
                  Navigator.pop(
                    context,
                    TripProviderService.parseImport(
                      provider: selectedProvider,
                      input: value,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isEmpty) return;
                Navigator.pop(
                  context,
                  TripProviderService.parseImport(
                    provider: selectedProvider,
                    input: controller.text,
                  ),
                );
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );

    if (reference != null && reference.tripId.isNotEmpty) {
      await TripStorageService.addTrip(
        reference.tripId,
        provider: reference.provider,
      );
      await _loadTrips();
      if (mounted) {
        _openTrip(
          _trips.firstWhere(
            (t) =>
                t.provider == reference.provider &&
                t.tripId == reference.tripId,
          ),
        );
      }
    }
  }

  void _openTrip(SavedTrip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripPage(
          provider: trip.provider,
          tripId: trip.tripId,
          tripTitle: trip.title,
        ),
      ),
    ).then((_) => _loadTrips());
  }

  Future<void> _deleteTrip(SavedTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Trip'),
        content: Text(
          'Remove "${trip.title ?? trip.tripId}" and its cached data?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TripStorageService.removeTrip(trip.provider, trip.tripId);
      await _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmptyState()
              : _buildTripList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTripDialog,
        icon: const Icon(Icons.add),
        label: const Text('Import Trip'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withAlpha(120),
            ),
            const SizedBox(height: 24),
            Text(
              'No trips yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import your first trip to get started',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showAddTripDialog,
              icon: const Icon(Icons.add),
              label: const Text('Import your first trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripList() {
    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          return _TripCard(
            trip: _trips[index],
            onTap: () => _openTrip(_trips[index]),
            onDelete: () => _deleteTrip(_trips[index]),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final SavedTrip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = trip.firstImageKey != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: CachedNetworkImageProvider(
                          getImageUrlById(trip.firstImageKey!),
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.travel_explore,
                            size: 48,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      // Gradient overlay for readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withAlpha(120),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!hasImage) ...[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.travel_explore,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.title ?? trip.tripId,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (trip.startDate != null &&
                                  trip.endDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _formatDateRange(
                                      trip.startDate!,
                                      trip.endDate!,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'ID: ${trip.tripId}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text('Remove'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') onDelete();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (trip.placeCount != null && trip.placeCount! > 0)
                          _InfoChip(
                            icon: Icons.place_outlined,
                            label: '${trip.placeCount} places',
                          ),
                        if (trip.placeCount != null && trip.placeCount! > 0)
                          const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.cloud_outlined,
                          label: trip.provider.displayName,
                        ),
                        const Spacer(),
                        Text(
                          timeago.format(
                            DateTime.fromMillisecondsSinceEpoch(
                              trip.lastAccessedAt,
                            ),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateRange(String startDate, String endDate) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('d, yyyy').format(end)}';
    }
    if (start.year == end.year) {
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    }
    return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
