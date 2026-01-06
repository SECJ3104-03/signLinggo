/// App Router Configuration
///
/// Defines all routes for the SignLinggo app using GoRouter.
/// Handles navigation between screens and manages route parameters.

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/landing/landing_screen.dart';
import '../screens/sign_in/signin_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/home/home_screen.dart' show HomePage;
import '../screens/learn_mode/learn_screen.dart' show LearnModePage;
import '../screens/learn_mode/category.dart' show CategoriesPage;
import '../screens/progress_tracker/progress_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/sign_recognition/sign_recognition_screen.dart';
import '../screens/Community_Module/community_hub.dart' show CommunityHubEdited;
import '../screens/Offline_Mode/offline_view.dart' show OfflineMode;
import '../screens/Offline_Mode/offline_file_list_screen.dart';
import '../screens/conversation_mode/chat_list_screen.dart';
import '../screens/conversation_mode/conversation_mode_screen.dart'
    show ConversationScreen;
import '../screens/text_to_sign/text_to_sign_screen.dart'
    show TextTranslationScreen;
import '../screens/Community_Module/notification_screen.dart';
import '../screens/daily_quiz/daily_quiz_screen.dart' show DailyQuizScreen;

import '../services/camera_service.dart';

/// Router configuration for the app
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/landing',

    // 🔁 Rebuild router when Firebase auth state changes
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),

    // 🔐 Global auth guard
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.uri.toString();

      final isAuthRoute = location == '/signin' ||
          location == '/register' ||
          location == '/landing';

      // ❌ Not logged in → force Sign In
      if (user == null && !isAuthRoute) {
        return '/signin';
      }

      // ✅ Logged in → block auth pages
      if (user != null && isAuthRoute) {
        return '/home';
      }

      return null; // allow navigation
    },

    routes: [
      // ================= AUTH / LANDING =================
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

      // ================= PROFILE =================
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfilePage(),
      ),

      // ================= MAIN APP =================
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
        builder: (context, state) => CategoriesPage(),
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

      // ================= SIGN RECOGNITION =================
      GoRoute(
        path: '/sign-recognition',
        name: 'sign-recognition',
        builder: (context, state) {
          if (!CameraService.hasCameras) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Sign Recognition'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 80),
                    const SizedBox(height: 24),
                    Text(
                      CameraService.errorMessage ??
                          'Camera not available on this device',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        final ok =
                            await CameraService.initializeCameras();
                        if (ok) context.go('/sign-recognition');
                      },
                      child: const Text('Retry Camera'),
                    ),
                  ],
                ),
              ),
            );
          }

          final camera = CameraService.getFirstCamera();
          return SignRecognitionScreen(
            camera: camera!,
            isSignToText: false,
          );
        },
      ),

      // ================= COMMUNITY =================
      GoRoute(
        path: '/community',
        name: 'community',
        builder: (context, state) => const CommunityHubEdited(),
      ),
      GoRoute(
        path: '/conversation',
        name: 'conversation',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/text-to-sign',
        name: 'text-to-sign',
        builder: (context, state) =>
            const TextTranslationScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationScreen(),
      ),

      // ================= OFFLINE =================
      GoRoute(
        path: '/offline',
        name: 'offline',
        builder: (context, state) => OfflineMode(),
      ),
      GoRoute(
        path: '/offline-files',
        name: 'offline-files',
        builder: (context, state) {
          final params = state.extra as Map<String, String>;
          return OfflineFileListScreen(
            folderPath: params['path']!,
            title: params['title']!,
          );
        },
      ),
    ],
  );
}

/// 🔁 Helper class to refresh GoRouter on Firebase auth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
