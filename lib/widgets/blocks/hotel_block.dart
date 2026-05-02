import 'package:flutter/material.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HotelBlockWidget extends StatefulWidget {
  final PlaceBlock placeBlock;
  final PlaceMetadata? metadata;
  final bool initiallyExpanded;
  final Expense? expense;

  const HotelBlockWidget({
    super.key,
    required this.placeBlock,
    required this.metadata,
    this.initiallyExpanded = true,
    this.expense,
  });

  @override
  State<HotelBlockWidget> createState() => _HotelBlockWidgetState();
}

class _HotelBlockWidgetState extends State<HotelBlockWidget>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    if (_isExpanded) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      _isExpanded ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hotel = widget.placeBlock.hotel;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _toggleExpanded,
        onLongPress: () {
          if (widget.placeBlock.place.url != null) {
            launchUrl(Uri.parse(widget.placeBlock.place.url!),
                mode: LaunchMode.externalApplication);
          }
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.hotelColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Always-visible header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.hotelColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.hotel,
                                    color: AppTheme.hotelColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.placeBlock.place.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (hotel?.checkIn != null &&
                                        hotel?.checkOut != null)
                                      Text(
                                        '${DateFormat('MMM d').format(DateTime.parse(hotel!.checkIn!))} - ${DateFormat('MMM d').format(DateTime.parse(hotel.checkOut!))}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                _isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                        // Expandable content
                        ClipRect(
                          child: Align(
                            heightFactor: _heightFactor.value,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Divider(
                                      color: theme
                                          .colorScheme.outlineVariant,
                                      height: 1),
                                  const SizedBox(height: 12),
                                  if (widget.metadata?.description !=
                                          null ||
                                      widget.metadata
                                              ?.generatedDescription !=
                                          null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 12),
                                      child: Text(
                                        widget.metadata?.description ??
                                            widget.metadata
                                                ?.generatedDescription ??
                                            '',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (hotel?.confirmationNumber != null)
                                    _infoRow(
                                      theme,
                                      Icons.confirmation_number_outlined,
                                      hotel!.confirmationNumber!,
                                    ),
                                  if (widget.expense != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 8),
                                      child: _infoRow(
                                        theme,
                                        Icons.receipt_outlined,
                                        widget.expense!.amount.format(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon,
            size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
