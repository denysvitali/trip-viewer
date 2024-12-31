import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:intl/intl.dart';

class AirportInfo extends StatelessWidget {
  final DepartArrive info;
  final bool isDeparture;

  const AirportInfo({
    super.key,
    required this.info,
    this.isDeparture = true,
  });

  String _formatDate(String date) {
    final dt = DateTime.parse(date);
    return DateFormat('E, MMM d').format(dt);
  }

  String _formatTime(String time) {
    final dt = DateTime.parse('2024-01-01T$time');
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatDate(info.date),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          _formatTime(info.time),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDeparture ? Icons.flight_takeoff : Icons.flight_land,
              size: 20,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => {
                if (info.airport.googlePlace.url != null)
                  {
                    log("Launching URL: ${info.airport.googlePlace.url!}"),
                    launchUrl(
                      Uri.parse(info.airport.googlePlace.url!),
                      webOnlyWindowName: '_blank',
                      mode: LaunchMode.externalApplication,
                    ),
                  }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    info.airport.iata,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.airport.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FlightFooter extends StatelessWidget {
  final FlightBlock flightBlock;

  const FlightFooter({super.key, required this.flightBlock});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${flightBlock.flightInfo.airline.name} ${flightBlock.flightInfo.number}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (flightBlock.price != null)
          Text(
            '${flightBlock.price!.amount} ${flightBlock.price!.currencyCode}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class FlightBlockWidget extends StatefulWidget {
  final FlightBlock flightBlock;
  final bool initiallyExpanded;

  const FlightBlockWidget({
    super.key,
    required this.flightBlock,
    this.initiallyExpanded = true,
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

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _openFlightInfo() {
    String flightAwareUrl =
        "https://www.flightaware.com/live/flight/${widget.flightBlock.flightInfo.airline.icao}${widget.flightBlock.flightInfo.number}/";
    launchUrl(
      Uri.parse(flightAwareUrl),
      webOnlyWindowName: '_blank',
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildCompressedView(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _toggleExpanded,
        onLongPress: _openFlightInfo,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child:
                        _CompressedAirportInfo(info: widget.flightBlock.depart),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Icon(
                        Icons.flight,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.flightBlock.flightInfo.airline.name} ${widget.flightBlock.flightInfo.number}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                  Expanded(
                    child:
                        _CompressedAirportInfo(info: widget.flightBlock.arrive),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: _toggleExpanded,
        onLongPress: _openFlightInfo,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AirportInfo(
                      info: widget.flightBlock.depart,
                      isDeparture: true,
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        width: 2,
                        height: 50,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      Icon(
                        Icons.flight,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        width: 2,
                        height: 50,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ),
                  Expanded(
                    child: AirportInfo(
                      info: widget.flightBlock.arrive,
                      isDeparture: false,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(Icons.flight, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  FlightFooter(flightBlock: widget.flightBlock),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isExpanded
        ? _buildExpandedView(context)
        : _buildCompressedView(context);
  }
}

class _CompressedAirportInfo extends StatelessWidget {
  final DepartArrive info;

  const _CompressedAirportInfo({required this.info});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          info.airport.iata,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          AirportInfo(info: info)._formatTime(info.time),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          AirportInfo(info: info)._formatDate(info.date),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
