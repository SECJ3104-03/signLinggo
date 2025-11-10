/// SignLinggo - Main Entry Point
/// 
/// This is the main entry point for the SignLinggo app.
/// It initializes the app, sets up navigation, and manages app-wide state.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes/app_router.dart';
import 'providers/app_provider.dart';
import 'package:camera/camera.dart';

List<CameraDescription> cameras = [];
/// Main function - initializes the app and checks if it's the first launch
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cameras
  cameras = await availableCameras();
  
  // Check if this is the first time the app is launched
  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('isFirstTime') ?? true;

  runApp(MyApp(isFirstTime: isFirstTime));
}

/// Root widget of the application
/// 
/// Sets up Provider for state management and GoRouter for navigation
class MyApp extends StatelessWidget {
  final bool isFirstTime;

  const MyApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(isFirstTime: isFirstTime),
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'SignLinggo',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
            ),
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
