import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/models/trip_plan.dart';

void main() {
  test('Fetch and process trip id "vevtulccsc"', () async {
    const tripId = 'vevtulccsc';
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

    final tripPlanResponse = TripPlanResponse.fromJson(tripData);

    expect(tripPlanResponse, isA<TripPlanResponse>());
    expect(tripPlanResponse.tripPlan, isA<TripPlan>());
    expect(tripPlanResponse.resources, isA<Resources>());
  });

  test('Expense.fromJson handles null amount and blockId', () {
    final json = {
      'id': 1,
      'amount': null,
      'category': 'Food',
      'description': 'Lunch',
      'blockId': null,
      // Add required fields that were missing
      'paidByUserId': 0,
      'paidByUser': {'type': 'user', 'id': 0},
      'splitWith': {
        'type': 'even',
        'users': [0]
      }
    };

    final expense = Expense.fromJson(json);

    expect(expense.amount.amount, 0.0);
    expect(expense.blockId, null);
    expect(expense.paidByUserId, 0);
  });

  test('SavedTrip.fromJson tolerates legacy incomplete entries', () {
    final savedTrip = SavedTrip.fromJson({
      'provider': 1,
      'tripId': null,
      'title': false,
      'placeCount': 'many',
      'startDate': ['2026-05-01'],
      'addedAt': 'recently',
      'lastAccessedAt': 'recently',
    });

    expect(savedTrip.provider, TripProvider.wanderlog);
    expect(savedTrip.tripId, '');
    expect(savedTrip.addedAt, greaterThan(0));
    expect(savedTrip.lastAccessedAt, greaterThan(0));
  });

  test('TripPlanResponse.fromJson tolerates missing optional provider data',
      () {
    final plan = TripPlanResponse.fromJson({
      'tripPlan': {
        'title': 'Sparse trip',
        'itinerary': {
          'sections': [
            {
              'heading': 'Day 1',
              'blocks': [
                {
                  'type': 'place',
                  'place': {'name': 'Null Island'},
                  'imageKeys': [null, 'image-1'],
                  'price': {'amount': null},
                },
                {
                  'type': 'note',
                  'image_keys': [null, 'image-2'],
                  'text': null,
                },
                {
                  'type': 'flight',
                  'flightInfo': {
                    'airline': {'iata': 'MU'},
                    'number': 244,
                  },
                  'depart': {'airport': {}},
                  'arrive': {'airport': {}},
                  'imageKeys': [null, 'image-3'],
                },
              ],
            },
          ],
        },
      },
      'resources': {
        'placeMetadata': [
          {
            'id': null,
            'name': 'Null Island',
            'placeId': 'place-1',
            'imageKeys': [null, 'image-4'],
          },
        ],
      },
    });

    expect(plan.tripPlan.title, 'Sparse trip');
    expect(plan.resources.placeMetadata.single.imageKeys, ['image-4']);
    expect(
      plan.tripPlan.itinerary.sections.single.blocks
          .map((block) => block.imageKeys),
      [
        ['image-1'],
        ['image-2'],
        ['image-3'],
      ],
    );
    expect(plan.tripPlan.itinerary.budget.expenses, isEmpty);
  });
}
