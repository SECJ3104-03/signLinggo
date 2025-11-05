import 'package:flutter/material.dart';

// Import both of your screens
import 'package:signlinggo/screens/Community_Module/community_hub.dart'; 
import 'package:signlinggo/screens/Offline_Mode/offline_view.dart';

// --- STEP 1: Call runApp() ONLY ONCE ---
void main() {
  // This is the only line you need in main()
  runApp(const MyApp());
}

// --- STEP 2: Use MyApp as your ONLY app controller ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      // --- STEP 3: Use 'home' to pick which screen to test ---

      // Set this to the screen you are currently working on:
      //home: OfflineMode(),

      // When you are done, or want to test the other screen,
      // comment out OfflineMode() and uncomment CommunityHubEdited():
       home: CommunityHubEdited(),
    );
  }
}

// --- STEP 4: Delete the FigmaToCodeApp widget ---
// You do not need this at all. Your MyApp widget already
// creates the MaterialApp that your app needs.

/*
class FigmaToCodeApp extends StatelessWidget {
  const FigmaToCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 18, 32, 47),
      ),
      home: Scaffold(
        body: ListView(children: [
          OfflineMode(),
        ]),
      ),
    );
  }
}
*/