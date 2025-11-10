/// App-wide Constants
/// 
/// Centralized location for all app constants including:
/// - Route names
/// - Color values
/// - Asset paths
/// - Default values
import 'package:flutter/material.dart';

/// Route names for navigation
class AppRoutes {
  static const String landing = '/landing';
  static const String signin = '/signin';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String learning = '/learning';
  static const String category = '/category';
  static const String progress = '/progress';
  static const String signRecognition = '/sign-recognition';
  static const String community = '/community';
  static const String offline = '/offline';
  static const String conversation = '/conversation';
  static const String textToSign = '/text-to-sign';
  static const String speechOutput = '/speech-output';
}

/// App color constants
class AppColors {
  static const primaryPurple = Color(0xFFAC46FF);
  static const primaryPink = Color(0xFFF6329A);
  static const primaryBlue = Color(0xFF00B8DA);
  static const primaryOrange = Color(0xFFFF6800);
  static const primaryYellow = Color(0xFFFDC700);
  
  static const backgroundGradient1 = Color(0xFFF2E7FE);
  static const backgroundGradient2 = Color(0xFFFCE6F3);
  static const backgroundGradient3 = Color(0xFFFFECD4);
  
  static const textPrimary = Color(0xFF101727);
  static const textSecondary = Color(0xFF495565);
  static const textGrey = Color(0xFF717182);
}

/// Asset paths
class AppAssets {
  static const String placeholderImage = 'assets/assets/placeholder.png';
  static const String iconsPath = 'assets/assets/icons/';
  static const String videosPath = 'assets/assets/videos/';
}

/// Default values
class AppDefaults {
  static const int dailyGoal = 10;
  static const int weeklyGoal = 50;
  static const int monthlyGoal = 300;
  static const int totalSigns = 100;
  static const String defaultLanguage = 'en';
}

