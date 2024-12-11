import 'package:flutter/material.dart';
import 'package:wanderlog_alt/pages/settings.dart';
import 'package:wanderlog_alt/pages/trip.dart';
import 'package:wanderlog_alt/services/settings_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
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

  @override
  Widget build(BuildContext context) {
    return MainLayout(tripId: tripId);
  }
}

class MainLayout extends StatefulWidget {
  final String? tripId;
  const MainLayout({super.key, required this.tripId});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String? tripId;

  @override
  void initState() {
    super.initState();
    tripId = widget.tripId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TripPage(tripId: tripId),
          const Center(child: Text('Explore - Coming Soon')),
          SettingsPage(
            onTripIdChanged: (String newTripId) async {
              await SettingsService.setTripId(newTripId);
              setState(() {
                tripId = newTripId;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Trip',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
