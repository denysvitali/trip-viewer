import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/pages/trip.dart';

void main() {
  testWidgets('DayView sorts timed activities by default', (tester) async {
    await tester.pumpWidget(
      _dayView(
        sortActivitiesByTime: true,
        blocks: [
          _place('Afternoon', '2:00 PM'),
          _place('Morning', '09:00'),
          _place('Untimed', null),
        ],
      ),
    );

    expect(
      _top(tester, 'Morning'),
      lessThan(_top(tester, 'Afternoon')),
    );
    expect(
      _top(tester, 'Afternoon'),
      lessThan(_top(tester, 'Untimed')),
    );
  });

  testWidgets('DayView can preserve provider activity order', (tester) async {
    await tester.pumpWidget(
      _dayView(
        sortActivitiesByTime: false,
        blocks: [
          _place('Afternoon', '2:00 PM'),
          _place('Morning', '09:00'),
          _place('Untimed', null),
        ],
      ),
    );

    expect(
      _top(tester, 'Afternoon'),
      lessThan(_top(tester, 'Morning')),
    );
    expect(
      _top(tester, 'Morning'),
      lessThan(_top(tester, 'Untimed')),
    );
  });
}

Widget _dayView({
  required List<Block> blocks,
  required bool sortActivitiesByTime,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DayView(
        date: DateTime(2026, 5, 18),
        section: Section(
          heading: '',
          date: '2026-05-18',
          blocks: blocks,
        ),
        flights: const [],
        hotels: const [],
        transit: const [],
        placeMetadata: const {},
        expensesById: const {},
        compactMode: true,
        sortActivitiesByTime: sortActivitiesByTime,
        tripTitle: 'Test trip',
        tripId: 'test-trip',
        provider: TripProvider.wanderlog,
      ),
    ),
  );
}

PlaceBlock _place(String name, String? startTime) {
  return PlaceBlock(
    place: GooglePlace(
      formattedAddress: '',
      name: name,
      photos: null,
      url: null,
      placeId: name,
    ),
    hotel: null,
    startTime: startTime,
    endTime: null,
    description: null,
  );
}

double _top(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text)).dy;
}
