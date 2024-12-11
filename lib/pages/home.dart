import 'package:flutter/material.dart';
import 'package:wanderlog_alt/pages/trip.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _tripKey = GlobalKey<TripPageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: TripPage(key: _tripKey, tripId: null),
      drawer: Drawer(
        child: SettingsPage(
          onTripIdChanged: (String newTripId) {
            _tripKey.currentState?.reloadTrip(newTripId);
          },
        ),
      ),
    );
  }
}
