import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:wanderlog_alt/widgets/blocks/flight_block.dart';
import 'package:wanderlog_alt/widgets/blocks/hotel_block.dart';
import 'package:wanderlog_alt/widgets/blocks/note_block.dart';
import 'package:wanderlog_alt/widgets/blocks/place_block.dart';

class TripPage extends StatefulWidget {
  final String? tripId;
  const TripPage({super.key, required this.tripId});

  @override
  State<TripPage> createState() => TripPageState();
}

const apiUrl = "https://wanderlog.com/api/tripPlans/";
const bool isProduction = bool.fromEnvironment('dart.vm.product');

class TripPageState extends State<TripPage> {
  TripPlan? plan;
  String? tripId;

  @override
  void initState() {
    super.initState();
    if (widget.tripId == null) {
      // Show dialog on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showTripIdDialog();
      });
    } else {
      loadTripData();
    }
  }

  @override
  void didUpdateWidget(TripPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      reloadTrip(widget.tripId!);
    }
  }

  void loadTripData() async {
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
    log("Loading trip data for $tripId");
    Uri url = Uri.parse('$apiUrl/$tripId?clientSchemaVersion=2');
    if (!isProduction) {
      url = Uri.parse("http://127.0.0.1:5005/thailand.json");
    }
    http.get(url).then((response) {
      // Parse response
      final tripData = jsonDecode(response.body);
      // Update state with trip data
      TripPlan fetchedPlan = TripPlanResponse.fromJson(tripData).tripPlan;
      setState(() {
        plan = fetchedPlan;
      });
    });
  }

  void reloadTrip(String newTripId) {
    setState(() {
      // Reset any existing state
      plan = null;
      tripId = newTripId;

      // Trigger new data load
    });
    loadTripData();
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

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return DefaultTabController(
      length: plan!.itinerary.sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${plan!.title} ($tripId)'),
          bottom: TabBar(
            isScrollable: true,
            tabs: plan!.itinerary.sections.map((section) {
              return Tab(
                text: getSectionTitle(section),
              );
            }).toList(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TabBarView(
            children: plan!.itinerary.sections.map((section) {
              return ListView.builder(
                itemBuilder: (context, index) {
                  Block block = section.blocks[index];

                  if (block is PlaceBlock) {
                    return placeBlock(block);
                  }
                  if (block is NoteBlock) {
                    return NoteBlockWidget(block: block);
                  }
                  if (block is FlightBlock) {
                    return FlightBlockWidget(flightBlock: block);
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

  Widget placeBlock(PlaceBlock block) {
    PlaceBlock placeBlock = block;
    return renderPlace(placeBlock);
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
    if (placeBlock.hotel != null) {
      return HotelBlock(placeBlock: placeBlock);
    }
    return PlaceBlockWidget(placeBlock: placeBlock);
  }
}

List<String>? getListStrings(List<dynamic>? json) {
  if (json == null) {
    return null;
  }
  return json.map((item) => item.toString()).toList();
}
