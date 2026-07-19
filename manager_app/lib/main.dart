import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  await Supabase.initialize(
    url: 'https://cavxvkwixbxbdvaasxpa.supabase.co',
    anonKey: 'sb_publishable_Sz5cqHM7sIpKGxOcgCWkTQ_8deGQEGt',
  );

  // 2. Initialize Window Manager for Desktop features (Windows only in this block)
  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'Angels Livorno - Kitchen Dashboard',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 3. Initialize Local Notifier for native OS notifications
  await localNotifier.setup(
    appName: 'Angels Livorno',
    // The shortcut policy is only needed for custom Windows MSI installations
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Angels Livorno Kitchen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEA580C),
          primary: const Color(0xFFEA580C),
          secondary: const Color(0xFFFACC15),
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
