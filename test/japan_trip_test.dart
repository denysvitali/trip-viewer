import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trip_viewer/models/trip_plan.dart';

void main() {
  test('Parse Japan trip with unscheduled sections and place text', () async {
    const tripId = 'ykzckbvgxrdbcsun';
    final url = Uri.parse(
        'https://wanderlog.com/api/tripPlans/$tripId?clientSchemaVersion=2');
    final response = await http.get(url);
    if (response.statusCode >= 500) {
      markTestSkipped(
        'Wanderlog API returned ${response.statusCode} for $tripId.',
      );
      return;
    }
    expect(response.statusCode, 200);

    final tripData = jsonDecode(response.body);
    final plan = TripPlanResponse.fromJson(tripData);

    expect(plan.tripPlan.title, 'Trip to Japan');

    // Check unscheduled sections exist
    final unscheduled = plan.tripPlan.itinerary.sections
        .where((s) => s.date == null && s.blocks.isNotEmpty)
        .toList();
    expect(unscheduled.length, greaterThan(0));

    // Check "Places to visit" has many blocks
    final placesToVisit =
        unscheduled.firstWhere((s) => s.heading.contains('Places to visit'));
    expect(placesToVisit.blocks.length, greaterThan(50));

    // Check PlaceBlock.text is parsed
    int placesWithText = 0;
    for (final section in plan.tripPlan.itinerary.sections) {
      for (final block in section.blocks) {
        if (block is PlaceBlock && block.text != null) {
          final content = block.text!.ops.map((op) => op.insert).join().trim();
          if (content.isNotEmpty) placesWithText++;
        }
      }
    }
    expect(placesWithText, greaterThan(0));

    // Check mixed currencies in expenses
    final currencies =
        plan.tripPlan.expenses.map((e) => e.amount.currencyCode).toSet();
    expect(currencies.length, greaterThan(1));
  });
}
