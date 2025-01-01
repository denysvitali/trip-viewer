import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('Fetch and process trip id "vevtulccsc"', () async {
    final tripId = 'vevtulccsc';
    final url = Uri.parse('https://wanderlog.com/api/tripPlans/$tripId?clientSchemaVersion=2');

    final response = await http.get(url);

    expect(response.statusCode, 200);

    final tripData = jsonDecode(response.body);

    expect(tripData, isA<Map<String, dynamic>>());
    expect(tripData['tripPlan'], isA<Map<String, dynamic>>());
    expect(tripData['resources'], isA<Map<String, dynamic>>());
  });
}
