import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wanderlog_alt/models/trip_plan.dart';

void main() {
  test('Fetch and process trip id "vevtulccsc"', () async {
    final tripId = 'vevtulccsc';
    final url = Uri.parse('https://wanderlog.com/api/tripPlans/$tripId?clientSchemaVersion=2');

    final response = await http.get(url);

    expect(response.statusCode, 200);

    final tripData = jsonDecode(response.body);

    final tripPlanResponse = TripPlanResponse.fromJson(tripData);

    expect(tripPlanResponse, isA<TripPlanResponse>());
    expect(tripPlanResponse.tripPlan, isA<TripPlan>());
    expect(tripPlanResponse.resources, isA<Resources>());
  });
}
