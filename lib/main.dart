import 'package:flutter/material.dart';
import 'package:wanderlog_alt/pages/trip.dart';
import 'package:wanderlog_alt/services/settings_service.dart';
import 'package:wanderlog_alt/widgets/trip_id_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SetupWidget(),
    );
  }
}

class SetupWidget extends StatefulWidget {
  const SetupWidget({super.key});

  @override
  State<SetupWidget> createState() => _SetupWidgetState();
}

class _SetupWidgetState extends State<SetupWidget> {
  String? tripId;

  @override
  void initState() {
    super.initState();
    _loadTripId();
  }

  Future<void> _loadTripId() async {
    final savedTripId = await SettingsService.getTripId();
    setState(() {
      tripId = savedTripId;
    });
  }

  Future<void> _showTripIdDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TripIdDialog(),
    );

    if (result != null) {
      await SettingsService.setTripId(result);
      setState(() {
        tripId = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tripId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTripIdDialog();
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return TripPage(tripId: tripId!);
  }
}
