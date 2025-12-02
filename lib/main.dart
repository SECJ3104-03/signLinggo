import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes/app_router.dart';
import 'providers/app_provider.dart';
import 'services/camera_service.dart';

void main() {
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
      'isFirstTime': true,
    };

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

    try {
      final camerasInitialized = await CameraService.initializeCameras();
      result['camerasInitialized'] = camerasInitialized;
      if (!camerasInitialized) {
        debugPrint('Camera init failed: ${CameraService.errorMessage}');
      }
    } catch (e) {
      debugPrint('Camera init exception: $e');
    }

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
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
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
