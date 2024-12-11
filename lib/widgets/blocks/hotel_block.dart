import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderlog_alt/widgets/place_image.dart';

class StayDateInfo extends StatelessWidget {
  final DateTime date;
  final bool isCheckIn;

  const StayDateInfo({
    super.key,
    required this.date,
    this.isCheckIn = true,
  });

  String _formatDate(DateTime date) {
    return DateFormat('E, MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatDate(date),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 14),
        Icon(
          isCheckIn ? Icons.login : Icons.logout,
          size: 20,
        ),
        const SizedBox(height: 14),
        Text(
          isCheckIn ? 'Check-in' : 'Check-out',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class HotelBlock extends StatelessWidget {
  final PlaceBlock placeBlock;

  const HotelBlock({
    super.key,
    required this.placeBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          if (placeBlock.imageKeys.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 350,
                width: double.infinity,
                child: PlaceImage(block: placeBlock),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StayDateInfo(
                        date: DateTime.parse(placeBlock.hotel?.checkIn ?? ''),
                        isCheckIn: true,
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          width: 2,
                          height: 30,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        Icon(
                          Icons.hotel,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          width: 2,
                          height: 30,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                    Expanded(
                      child: StayDateInfo(
                        date: DateTime.parse(placeBlock.hotel?.checkOut ?? ''),
                        isCheckIn: false,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                GestureDetector(
                  onTap: () {
                    if (placeBlock.place.url != null) {
                      launchUrl(
                        Uri.parse(placeBlock.place.url!),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.hotel,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              placeBlock.place.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (placeBlock.hotel?.confirmationNumber != null)
                            Row(children: [
                              Icon(
                                Icons.confirmation_number,
                                size: 18,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${placeBlock.hotel!.confirmationNumber}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ])
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
