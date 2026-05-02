import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/services/trip_provider_service.dart';

Future<TripPlanResponse> _fetchAndParseTrip(String tripId) async {
  final url = Uri.parse(
    'https://wanderlog.com/api/tripPlans/$tripId?clientSchemaVersion=2',
  );
  final response = await http.get(url);

  expect(response.statusCode, 200);

  return TripPlanResponse.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}

void main() {
  test('parses another public Wanderlog trip', () async {
    final trip = await _fetchAndParseTrip('vevtulccsc');

    expect(trip.tripPlan.title, isNotEmpty);
    expect(trip.tripPlan.itinerary.sections, isNotEmpty);
  });

  test('parses private trip supplied by environment', () async {
    final input = Platform.environment['WANDERLOG_PRIVATE_TRIP_URL'];

    if (input == null || input.isEmpty) {
      markTestSkipped('Set WANDERLOG_PRIVATE_TRIP_URL to run this locally.');
      return;
    }

    final tripId = WanderlogTripProviderClient().parseTripId(input);
    final trip = await _fetchAndParseTrip(tripId);

    expect(trip.tripPlan.title, isNotEmpty);
    expect(trip.tripPlan.itinerary.sections, isNotEmpty);
  });
}
