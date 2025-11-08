// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/learn_mode/learn_screen.dart'; // 👈 correct import path
import 'screens/learn_mode/category.dart'; // 👈 import Category screen
import 'screens/progress_tracker/progress_screen.dart'; // 👈 import Progress Tracker screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Learn Mode App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ProgressScreen()); // 👈 Runs your Screen
  }
}
