/// App Router Configuration
/// 
/// Defines all routes for the SignLinggo app using GoRouter.
/// Handles navigation between screens and manages route parameters.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/sign_in/signin_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/home/home_screen.dart' show HomePage;
import '../screens/learn_mode/learn_screen.dart' show LearnModePage;
import '../screens/learn_mode/category.dart' show CategoriesPage;
import '../screens/progress_tracker/progress_screen.dart';
import '../screens/sign_recognition/sign_recognition_screen.dart';
import '../screens/Community_Module/community_hub.dart' show CommunityHubEdited;
import '../screens/Offline_Mode/offline_view.dart' show OfflineMode;
import '../screens/conversation_mode/conversation_mode_screen.dart' show ConversationScreen;
import '../screens/text_to_sign/text_to_sign_screen.dart' show TextTranslationScreen;
import '../screens/speech_output/speech_output_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';

// Note: Some screens may need to be created or renamed to match these imports

/// Router configuration for the app
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/landing',
    routes: [
      // Landing and Authentication Routes
      GoRoute(
        path: '/landing',
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/signin',
        name: 'signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Note: OnboardingScreen and WelcomeScreen need to be created or imported
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Onboarding Screen - To be implemented')),
        ),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Welcome Screen - To be implemented')),
        ),
      ),

      // Main App Routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/learning',
        name: 'learning',
        builder: (context, state) => const LearnModePage(),
      ),
      GoRoute(
        path: '/category',
        name: 'category',
        builder: (context, state) {
          // Category parameter can be used in future implementation
          // final category = state.uri.queryParameters['category'] ?? 'All';
          return CategoriesPage();
        },
      ),
      GoRoute(
        path: '/progress',
        name: 'progress',
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: '/sign-recognition',
        name: 'sign-recognition',
        builder: (context, state) {
          // TODO: Initialize camera and pass to SignRecognitionScreen
          // For now, return a placeholder that navigates to text-to-sign
          return const Scaffold(
            body: Center(
              child: Text('Sign Recognition - Camera initialization required'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/community',
        name: 'community',
        builder: (context, state) => const CommunityHubEdited(),
      ),
      GoRoute(
        path: '/offline',
        name: 'offline',
        builder: (context, state) => OfflineMode(),
      ),
      GoRoute(
        path: '/conversation',
        name: 'conversation',
        builder: (context, state) => const ConversationScreen(),
      ),
      GoRoute(
        path: '/text-to-sign',
        name: 'text-to-sign',
        builder: (context, state) => const TextTranslationScreen(),
      ),
      // Note: SpeechOutputScreen and OfflineView need to be created or imported
      GoRoute(
        path: '/speech-output',
        name: 'speech-output',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Speech Output Screen - To be implemented')),
        ),
      ),
    ],
  );
}

