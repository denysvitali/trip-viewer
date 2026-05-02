import 'package:flutter/material.dart';
import 'package:trip_viewer/pages/trip_list.dart';
import 'package:trip_viewer/pages/settings.dart';
import 'package:trip_viewer/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Viewer',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const TripListPage(),
      routes: {
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
