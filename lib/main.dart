import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:trip_viewer/pages/trip_list.dart';
import 'package:trip_viewer/pages/settings.dart';
import 'package:trip_viewer/services/dart_sentry_transport.dart';
import 'package:trip_viewer/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryFlutter.init(
    (options) => options
      ..dsn = 'https://0c4c5560da4841dcb0271da750b5dfea@glitchtip.k2.k8s.best/6'
      ..tracesSampleRate = 0.01
      ..enableAutoSessionTracking = false
      ..debug = kDebugMode
      ..diagnosticLevel = SentryLevel.debug
      ..transport = DartSentryTransport(options),
    appRunner: () => runApp(const MyApp()),
  );
  await Sentry.captureMessage(
    'trip_viewer started',
    level: SentryLevel.info,
  );
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
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
      routes: {
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
