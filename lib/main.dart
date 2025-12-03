// lib/main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes/app_router.dart';
import 'providers/app_provider.dart';
import 'services/camera_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

/// Widget to handle async initialization safely
class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  Future<Map<String, dynamic>> _initializeApp() async {
    Map<String, dynamic> result = {
      'firebaseInitialized': false,
      'camerasInitialized': false,
      'supabaseInitialized': false, // Track Supabase status
      'isFirstTime': true,
    };

    // 1. Initialize Firebase
    try {
      if(kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyB-sc6v7UDLwKVN714rcAuuE6fvzEMgnF0",
            authDomain: "signlinggo.firebaseapp.com",
            projectId: "signlinggo",
            storageBucket: "signlinggo.firebasestorage.app",
            messagingSenderId: "724828186533",
            appId: "1:724828186533:web:b7431f34cbcf6ba4f6ea4c",
            measurementId: "G-GV4N1JMLTB",
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      result['firebaseInitialized'] = true;
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    // 2. Initialize Supabase (NEW)
    try {
      await Supabase.initialize(
        // TODO: Replace these with your actual keys from Supabase Dashboard -> Settings -> API
        url: 'https://tdtosjyrvwtnrmkjiwav.supabase.co', 
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkdG9zanlydnd0bnJta2ppd2F2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2NDYxODQsImV4cCI6MjA4MDIyMjE4NH0.c1-c8kRdLIjWT3LvC7NaP5Bd4nKMxQw6YcFGJuetgSc',
      );
      result['supabaseInitialized'] = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase init error: $e');
    }

    // 3. Initialize Cameras
    try {
      final camerasInitialized = await CameraService.initializeCameras();
      result['camerasInitialized'] = camerasInitialized;
      if (!camerasInitialized) {
        debugPrint('Camera init failed: ${CameraService.errorMessage}');
      }
    } catch (e) {
      debugPrint('Camera init exception: $e');
    }

    // 4. Check First Time User
    final prefs = await SharedPreferences.getInstance();
    result['isFirstTime'] = prefs.getBool('isFirstTime') ?? true;

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Show loading spinner while initializing
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Starting SignLinggo...", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }

        // Initialization done, run the main app
        final isFirstTime = snapshot.data?['isFirstTime'] ?? true;

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
      },
    );
  }
}