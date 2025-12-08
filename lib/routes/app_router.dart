/// App Router Configuration
/// 
/// Defines all routes for the SignLinggo app using GoRouter.
/// Handles navigation between screens and manages route parameters.
library;
import 'package:flutter/material.dart';
import '../screens/profile/profile_screen.dart' show ProfileScreen;
import 'package:go_router/go_router.dart';
import 'package:signlinggo/screens/conversation_mode/chat_list_screen.dart';
import 'package:signlinggo/screens/profile/profile_screen.dart';
import 'package:signlinggo/screens/profile/edit_profile_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/sign_in/signin_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/home/home_screen.dart' show HomePage;
import '../screens/learn_mode/learn_screen.dart' show LearnModePage;
import '../screens/learn_mode/category.dart' show CategoriesPage;
import '../screens/progress_tracker/progress_screen.dart';
import '../screens/sign_recognition/sign_recognition_screen.dart';
import '../services/camera_service.dart';
import '../screens/Community_Module/community_hub.dart' show CommunityHubEdited;
import '../screens/Offline_Mode/offline_view.dart' show OfflineMode;
import '../screens/conversation_mode/conversation_mode_screen.dart' show ConversationScreen;
import '../screens/text_to_sign/text_to_sign_screen.dart' show TextTranslationScreen;
import '../screens/Offline_Mode/offline_file_list_screen.dart';
import '../screens/Community_Module/notification_screen.dart';
import '../screens/daily_quiz/daily_quiz_screen.dart' show DailyQuizScreen;

// Note: Speech output and onboarding screens are placeholders for future implementation

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
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
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
        path: '/daily-quiz',
        name: 'daily-quiz',
        builder: (context, state) => const DailyQuizScreen(),
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
          // Check if cameras are available
          if (!CameraService.hasCameras) {
            // Show error screen if no cameras available
            return Scaffold(
              appBar: AppBar(
                title: const Text('Sign Recognition'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Camera Not Available',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        CameraService.errorMessage ?? 
                        'No camera found on this device. Please connect a camera or use a device with a camera.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Try to re-initialize cameras
                          final initialized = await CameraService.initializeCameras();
                          if (initialized && CameraService.hasCameras) {
                            // Navigate to sign recognition if camera is now available
                            context.go('/sign-recognition');
                          } else {
                            // Show snackbar with error
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  CameraService.errorMessage ?? 
                                  'Camera is still not available',
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Camera'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/text-to-sign'),
                        child: const Text('Use Text to Sign Instead'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Get first available camera
          final camera = CameraService.getFirstCamera();
          if (camera == null) {
            // Fallback if camera is null (shouldn't happen if hasCameras is true)
            return Scaffold(
              body: Center(
                child: Text(
                  CameraService.errorMessage ?? 
                  'Camera initialization failed',
                ),
              ),
            );
          }

          // Navigate to sign recognition screen with camera
          return SignRecognitionScreen(
            camera: camera,
            isSignToText: false,
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
        path: '/offline-files',
        name: 'offline-files',
        builder: (context, state) {
          // Get the parameters we passed
          final params = state.extra as Map<String, String>;
          final String folderPath = params['path']!;
          final String title = params['title']!;

          return OfflineFileListScreen(
            folderPath: folderPath,
            title: title,
          );
        },
       ),
      GoRoute(
        path: '/conversation',
        name: 'conversation',
        builder: (context, state) => const ChatListScreen(),
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

      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      
    ],
  );
}

