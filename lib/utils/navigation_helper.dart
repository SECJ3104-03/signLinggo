/// Navigation Helper Utilities
/// 
/// Provides helper functions for common navigation operations
import 'package:flutter/material.dart'; 
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';

/// Helper class for navigation operations
class NavigationHelper {
  /// Navigate to a route by name
  static void goToRoute(BuildContext context, String routeName) {
    context.go(routeName);
  }

  /// Navigate to a route and replace current route
  static void goToRouteReplacement(BuildContext context, String routeName) {
    context.go(routeName);
  }

  /// Navigate back
  static void goBack(BuildContext context) {
    context.pop();
  }

  /// Navigate to category screen with category parameter
  static void goToCategory(BuildContext context, String category) {
    context.go('${AppRoutes.category}?category=$category');
  }
}

