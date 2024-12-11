import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  TripPlanResponse? plan;
  String? tripId;
  Map<DateTime, List<FlightBlock>> flightsByDate = {};
  Map<DateTime, List<HotelBlock>> hotelsByDate = {};

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
      url = Uri.parse("http://127.0.0.1:5005/thailand2.json");
    }
    http.get(url).then((response) {
      // Parse response
      final tripData = jsonDecode(response.body);
      // Update state with trip data
      TripPlanResponse fetchedPlan = TripPlanResponse.fromJson(tripData);
      setState(() {
        flightsByDate = getFlightsByDate(fetchedPlan);
        hotelsByDate = getHotelsByDate(fetchedPlan);
        plan = fetchedPlan;
      });
    });
  }

  void reloadTrip(String? newTripId) {
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
    Map<String, PlaceMetadata> pm =
        getPlaceMetadata(plan!.resources.placeMetadata);

    return DefaultTabController(
      length: plan!.tripPlan.itinerary.sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${plan!.tripPlan.title} ($tripId)'),
          bottom: TabBar(
            isScrollable: true,
            tabs: plan!.tripPlan.itinerary.sections.map((section) {
              return Tab(
                text: getSectionTitle(section),
              );
            }).toList(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TabBarView(
            children: plan!.tripPlan.itinerary.sections.map((section) {
              List<Widget> initialSections = [
                _sectionHeader(context, section),
              ];
              return RefreshIndicator(
                  onRefresh: () async {
                    reloadTrip(tripId);
                  },
                  child: ListView.builder(
                    itemBuilder: (context, index) {
                      if (index < initialSections.length) {
                        return initialSections[index];
                      }
                      Block block =
                          section.blocks[index - initialSections.length];

                      if (block is PlaceBlock) {
                        PlaceMetadata? placeMd = pm[block.place.placeId];
                        return renderPlace(block, placeMd);
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
                    itemCount: section.blocks.length + initialSections.length,
                  ));
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, Section section) {
    if (section.date == null) {
      return Container();
    }
    DateTime date = DateTime.parse(section.date!);
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMMM d yyyy').format(date),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            _flights(context, date),
            _lodging(context, date),
            _sectionTitle("Activities"),
          ],
        ));
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  Widget _flights(BuildContext context, DateTime date) {
    if (!flightsByDate.containsKey(date)) {
      return Container();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Flights"),
        Column(
          children: flightsByDate[date]!.map((flight) {
            return FlightBlockWidget(flightBlock: flight);
          }).toList(),
        ),
      ],
    );
  }

  Widget _lodging(BuildContext context, DateTime date) {
    if (!hotelsByDate.containsKey(date)) {
      return Container();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Lodging"),
        Column(
          children: hotelsByDate[date]!.map((hotel) {
            return HotelBlock(placeBlock: hotel.placeBlock, metadata: null);
          }).toList(),
        ),
      ],
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

  Widget renderPlace(PlaceBlock placeBlock, PlaceMetadata? metadata) {
    if (placeBlock.hotel != null) {
      return HotelBlock(placeBlock: placeBlock, metadata: metadata);
    }
    return PlaceBlockWidget(placeBlock: placeBlock, metadata: metadata);
  }

  Map<String, PlaceMetadata> getPlaceMetadata(
      List<PlaceMetadata> placemetadata) {
    Map<String, PlaceMetadata> pm = {};
    for (PlaceMetadata p in placemetadata) {
      pm[p.placeId] = p;
    }
    return pm;
  }

  Map<DateTime, List<FlightBlock>> getFlightsByDate(
      TripPlanResponse fetchedPlan) {
    Map<DateTime, List<FlightBlock>> flightsByDate = {};
    for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
      for (Block block in section.blocks) {
        if (block is FlightBlock) {
          DateTime departDate = DateTime.parse(block.depart.date);
          DateTime arriveDate = DateTime.parse(block.arrive.date);

          if (!flightsByDate.containsKey(departDate)) {
            flightsByDate[departDate] = [];
          }
          flightsByDate[departDate]!.add(block);

          if (arriveDate != departDate) {
            if (!flightsByDate.containsKey(arriveDate)) {
              flightsByDate[arriveDate] = [];
            }
            flightsByDate[arriveDate]!.add(block);
          }
        }
      }
    }
    return flightsByDate;
  }
}

Map<DateTime, List<HotelBlock>> getHotelsByDate(TripPlanResponse fetchedPlan) {
  Map<DateTime, List<HotelBlock>> hotelsByDate = {};
  for (Section section in fetchedPlan.tripPlan.itinerary.sections) {
    for (Block block in section.blocks) {
      if (block is PlaceBlock) {
        if (block.hotel != null) {
          DateTime checkIn = DateTime.parse(block.hotel!.checkIn!);
          DateTime checkOut = DateTime.parse(block.hotel!.checkOut!);
          for (DateTime date = checkIn;
              date.isBefore(checkOut);
              date = date.add(const Duration(days: 1))) {
            if (!hotelsByDate.containsKey(date)) {
              hotelsByDate[date] = [];
            }
            hotelsByDate[date]!.add(HotelBlock(
              placeBlock: block,
              metadata: null,
            ));
          }
        }
      }
    }
  }
  return hotelsByDate;
}

List<String>? getListStrings(List<dynamic>? json) {
  if (json == null) {
    return null;
  }
  return json.map((item) => item.toString()).toList();
}
