// lib/main.dart
//
// The ListenableBuilder here is the single most important line in the v3
// rewrite. AppSettings has always called notifyListeners(); in v2 nothing
// subscribed, so changing a setting updated memory and never the screen.
// That one omission accounted for the dead sliders, dead toggles and the
// accent colour that did nothing.

import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(MoistSenseApp(settings: settings));
}

class MoistSenseApp extends StatelessWidget {
  final AppSettings settings;
  const MoistSenseApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'MoistSense',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(settings),
          home: DashboardScreen(settings: settings),
        );
      },
    );
  }
}
