import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:wanderlog_alt/theme/app_theme.dart';
import 'package:intl/intl.dart';

class FlightBlockWidget extends StatefulWidget {
  final FlightBlock flightBlock;
  final bool initiallyExpanded;
  final Expense? expense;

  const FlightBlockWidget({
    super.key,
    required this.flightBlock,
    this.initiallyExpanded = true,
    this.expense,
  });

  @override
  State<FlightBlockWidget> createState() => _FlightBlockWidgetState();
}

class _FlightBlockWidgetState extends State<FlightBlockWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() => setState(() => _isExpanded = !_isExpanded);

  void _openFlightInfo() {
    final url =
        "https://www.flightaware.com/live/flight/${widget.flightBlock.flightInfo.airline.icao}${widget.flightBlock.flightInfo.number}/";
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
    final flight = widget.flightBlock;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _toggleExpanded,
        onLongPress: _openFlightInfo,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.flightColor,
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
                      // Compact airport row (always shown)
                      Row(
                        children: [
                          _AirportCode(
                            code: flight.depart.airport.iata,
                            time: _formatTime(flight.depart.time),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${flight.flightInfo.airline.name ?? ''} ${flight.flightInfo.number}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                          color: AppTheme.flightColor
                                              .withAlpha(80)),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.flight,
                                          size: 18,
                                          color: AppTheme.flightColor),
                                    ),
                                    Expanded(
                                      child: Divider(
                                          color: AppTheme.flightColor
                                              .withAlpha(80)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _AirportCode(
                            code: flight.arrive.airport.iata,
                            time: _formatTime(flight.arrive.time),
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
                              Icons.flight_takeoff,
                              flight.depart.airport.name,
                              _formatDate(flight.depart.date),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              theme,
                              Icons.flight_land,
                              flight.arrive.airport.name,
                              _formatDate(flight.arrive.date),
                            ),
                            if (flight.confirmationNumber != null) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                theme,
                                Icons.confirmation_number_outlined,
                                'Confirmation',
                                flight.confirmationNumber!,
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
          child: Text(label, style: theme.textTheme.bodySmall),
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

class _AirportCode extends StatelessWidget {
  final String code;
  final String time;

  const _AirportCode({required this.code, required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          code,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
