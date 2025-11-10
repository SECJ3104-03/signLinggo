/// App-wide State Provider
/// 
/// Manages global app state including:
/// - Authentication status
/// - User preferences (theme, language)
/// - First-time launch flag
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app-wide state
class AppProvider extends ChangeNotifier {
  bool _isFirstTime;
  bool _isLoggedIn = false;
  bool _isGuestMode = false;
  String _selectedLanguage = 'en'; // Default to English
  bool _isDarkMode = false;

  AppProvider({required bool isFirstTime}) : _isFirstTime = isFirstTime;

  // Getters
  bool get isFirstTime => _isFirstTime;
  bool get isLoggedIn => _isLoggedIn;
  bool get isGuestMode => _isGuestMode;
  String get selectedLanguage => _selectedLanguage;
  bool get isDarkMode => _isDarkMode;

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    _isFirstTime = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    notifyListeners();
  }

  /// Set login status
  void setLoggedIn(bool value) {
    _isLoggedIn = value;
    notifyListeners();
  }

  /// Set guest mode
  void setGuestMode(bool value) {
    _isGuestMode = value;
    notifyListeners();
  }

  /// Set selected language
  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  /// Toggle dark mode
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// Logout user
  Future<void> logout() async {
    _isLoggedIn = false;
    _isGuestMode = false;
    notifyListeners();
  }
}

