// lib/main.dart
import 'package:flutter/material.dart';
//import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'screens/learn_mode/learn_screen.dart'; // 👈 correct import path
import 'screens/learn_mode/category.dart'; // 👈 import Category screen
import 'screens/progress_tracker/progress_screen.dart'; // 👈 import Progress Tracker screen
import 'package:signlinggo/screens/sign_recognition/sign_recognition_screen.dart';
import 'package:signlinggo/screens/Community_Module/community_hub.dart'; 
import 'package:signlinggo/screens/Offline_Mode/offline_view.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signlinggo/screens/sign_in/signin_screen.dart';
import 'package:signlinggo/screens/landing/landing_screen.dart'; // your 3-page landing

//List<CameraDescription> cameras = [];

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  //cameras = await availableCameras();
// --- STEP 1: Call runApp() ONLY ONCE ---import 'package:signlinggo/screens/home/home_screen.dart';



void main() {
  runApp(MaterialApp (
    home: HomePage(),
  ));
}

}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('isFirstTime') ?? true;

  runApp(MyApp(isFirstTime: isFirstTime));
}

class MyApp extends StatelessWidget {
  final bool isFirstTime;
  const MyApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isFirstTime ? const LandingScreen() : const SignInScreen(),
    );
  }
}
