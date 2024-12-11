import 'dart:convert';
import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:wanderlog_alt/models/trip_plan.dart';

class TripPage extends StatefulWidget {
  final String tripId;
  const TripPage({super.key, required this.tripId});

  @override
  State<TripPage> createState() => _TripPageState();
}

const apiUrl = "https://wanderlog.com/api/tripPlans/";

class _TripPageState extends State<TripPage> {
  TripPlan? plan;
  @override
  void initState() {
    // Load trip data
    loadTripData();
    super.initState();
  }

  void loadTripData() async {
    http
        .get(Uri.parse('$apiUrl/${widget.tripId}?clientSchemaVersion=2'))
        .then((response) {
      // Parse response
      final tripData = jsonDecode(response.body);
      // Update state with trip data
      TripPlan fetchedPlan = TripPlanResponse.fromJson(tripData).tripPlan;
      setState(() {
        plan = fetchedPlan;
      });
    });
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

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return DefaultTabController(
      length: plan!.itinerary.sections.length,
      child: Scaffold(
        appBar: AppBar(
            title: Text(plan!.title),
            bottom: TabBar(
              isScrollable: true,
              tabs: plan!.itinerary.sections.map((section) {
                return Tab(
                  text: getSectionTitle(section),
                );
              }).toList(),
            )),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TabBarView(
            children: plan!.itinerary.sections.map((section) {
              return ListView.builder(
                itemBuilder: (context, index) {
                  Block block = section.blocks[index];

                  if (block is PlaceBlock) {
                    PlaceBlock placeBlock = block;
                    return Card(
                      child: Material(
                        child: InkWell(
                          onTap: () async {
                            String url = placeBlock.url ?? '';
                            try {
                              await launchUrl(
                                Uri.parse(url),
                                webOnlyWindowName: '_blank',
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              showError(e);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                            child: renderPlace(placeBlock),
                          ),
                        ),
                      ),
                    );
                  }
                  return ListTile(
                      title: Text('Unknown block type ${block.type}'));
                },
                itemCount: section.blocks.length,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String getSectionTitle(Section section) {
    if (section.date != null) {
      if (section.heading != "") {
        return '${section.date} - ${section.heading}';
      }
      return section.date!;
    }
    return section.heading;
  }

  Widget renderPlace(PlaceBlock placeBlock) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            placeBlock.name ?? 'Unknown place',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (placeBlock.hotel != null)
            Text(
              'Chheck-In: ${placeBlock.hotel!.checkIn}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (placeBlock.hotel != null)
            Text(
              'Check-Out: ${placeBlock.hotel!.checkOut}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (placeBlock.imageKeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image(
                  image: CachedNetworkImageProvider(
                    getImageUrl(placeBlock),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

String getImageUrl(PlaceBlock placeBlock) {
  return 'https://itin-dev.sfo2.cdn.digitaloceanspaces.com/freeImage/${placeBlock.imageKeys[0]}';
}

List<String>? getListStrings(List<dynamic>? json) {
  if (json == null) {
    return null;
  }
  return json.map((item) => item.toString()).toList();
}
