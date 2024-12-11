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
    return GestureDetector(
      onTap: () {
        String flightAwareUrl =
            "https://www.flightaware.com/live/flight/${flightBlock.flightInfo.airline.icao}${flightBlock.flightInfo.number}/";
        launchUrl(
          Uri.parse(flightAwareUrl),
          webOnlyWindowName: '_blank',
          mode: LaunchMode.externalApplication,
        );
      },
      child: Text(
        '${flightBlock.flightInfo.airline.name} ${flightBlock.flightInfo.number}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class FlightBlockWidget extends StatelessWidget {
  final FlightBlock flightBlock;

  const FlightBlockWidget({super.key, required this.flightBlock});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    info: flightBlock.depart,
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
                    info: flightBlock.arrive,
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
                FlightFooter(flightBlock: flightBlock),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
