import 'package:flutter/material.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum TransitType { bus, train, other }

class TransitBlockWidget extends StatefulWidget {
  final TransitBlock transitBlock;
  final bool initiallyExpanded;
  final TransitType transitType;
  final Expense? expense;

  const TransitBlockWidget({
    super.key,
    required this.transitBlock,
    required this.transitType,
    this.initiallyExpanded = true,
    this.expense,
  });

  @override
  State<TransitBlockWidget> createState() => _TransitBlockWidgetState();
}

class _TransitBlockWidgetState extends State<TransitBlockWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() => setState(() => _isExpanded = !_isExpanded);

  Future<void> _openStation(GooglePlace place) async {
    final url = place.url;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }

    final location = place.geometry?.location;
    Uri? fallback;
    if (location != null) {
      final label = Uri.encodeComponent(
          place.name.isNotEmpty ? place.name : place.formattedAddress);
      fallback = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${location.lat},${location.lng}&query_place_id=$label');
    } else {
      final query = place.formattedAddress.isNotEmpty
          ? place.formattedAddress
          : place.name;
      if (query.isEmpty) return;
      fallback = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    }
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }

  IconData _getIcon() {
    switch (widget.transitType) {
      case TransitType.bus:
        return Icons.directions_bus;
      case TransitType.train:
        return Icons.train;
      default:
        return Icons.directions_transit;
    }
  }

  String _formatDate(String date) {
    return DateFormat('E, MMM d').format(DateTime.parse(date));
  }

  String _formatTime(String time) {
    return DateFormat('HH:mm').format(DateTime.parse('2024-01-01T$time'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transit = widget.transitBlock;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _toggleExpanded,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.transitColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Compact route row
                      Row(
                        children: [
                          GestureDetector(
                            onLongPress: () => _openStation(transit.depart.place),
                            child: _StationName(
                              name: transit.depart.place.name,
                              time: transit.depart.time != null
                                  ? _formatTime(transit.depart.time!)
                                  : null,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                if (transit.carrier != null)
                                  Text(
                                    transit.carrier!,
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                          color: AppTheme.transitColor
                                              .withAlpha(80)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Icon(_getIcon(),
                                          size: 18,
                                          color: AppTheme.transitColor),
                                    ),
                                    Expanded(
                                      child: Divider(
                                          color: AppTheme.transitColor
                                              .withAlpha(80)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onLongPress: () => _openStation(transit.arrive.place),
                            child: _StationName(
                              name: transit.arrive.place.name,
                              time: transit.arrive.time != null
                                  ? _formatTime(transit.arrive.time!)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      // Expanded details
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                          children: [
                            const SizedBox(height: 12),
                            Divider(
                                color: theme.colorScheme.outlineVariant,
                                height: 1),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              theme,
                              Icons.departure_board,
                              transit.depart.place.formattedAddress,
                              _formatDate(transit.depart.date),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              theme,
                              Icons.pin_drop_outlined,
                              transit.arrive.place.formattedAddress,
                              _formatDate(transit.arrive.date),
                            ),
                            if (transit.confirmationNumber != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.confirmation_number_outlined,
                                      size: 14,
                                      color: theme
                                          .colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(transit.confirmationNumber!,
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ],
                            if (widget.expense != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.receipt_outlined,
                                      size: 14,
                                      color: theme
                                          .colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.expense!.amount.format(),
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      ThemeData theme, IconData icon, String label, String detail) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          detail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StationName extends StatelessWidget {
  final String name;
  final String? time;

  const _StationName({required this.name, this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Text(
            name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (time != null) ...[
            const SizedBox(height: 2),
            Text(
              time!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
