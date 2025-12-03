// data/progress_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressManager extends ChangeNotifier {
  // Storage keys
  static const String _totalWatchedKey = 'total_watched';
  static const String _pointsKey = 'user_points';
  static const String _streakKey = 'day_streak';
  static const String _lastQuizDateKey = 'last_quiz_date';
  static const String _dailyQuizDoneKey = 'daily_quiz_done';
  static const String _streakHistoryKey = 'streak_history';
  static const String _lastAppOpenDateKey = 'last_app_open_date';
  static const String _watchedSignsKey = 'watched_signs';

  int _totalWatched = 0;
  int _points = 0;
  int _dayStreak = 0;
  bool _dailyQuizDone = false;
  List<String> _streakHistory = [];
  Set<String> _watchedSigns = {};

  ProgressManager() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadProgress();
    await _checkStreakOnAppOpen();
  }

  // Helper: Convert DateTime to date string (YYYY-MM-DD)
  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper: Get today's date string
  String _getTodayString() {
    return _dateToString(DateTime.now());
  }

  // Helper: Get yesterday's date string
  String _getYesterdayString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _dateToString(yesterday);
  }

  // Helper: Parse date string to DateTime
  DateTime _stringToDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  // Helper: Check if date is today
  bool _isToday(String dateStr) {
    return dateStr == _getTodayString();
  }

  // Helper: Check if date is yesterday
  bool _isYesterday(String dateStr) {
    return dateStr == _getYesterdayString();
  }

  

  
 
  // Load all data from storage
  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    _totalWatched = prefs.getInt(_totalWatchedKey) ?? 0;
    _points = prefs.getInt(_pointsKey) ?? 0;
    _dayStreak = prefs.getInt(_streakKey) ?? 0;
    _dailyQuizDone = prefs.getBool(_dailyQuizDoneKey) ?? false;
    _streakHistory = prefs.getStringList(_streakHistoryKey) ?? [];
    
    // Load watched signs
    final watchedList = prefs.getStringList(_watchedSignsKey) ?? [];
    _watchedSigns = watchedList.toSet();
    
    notifyListeners();
  }

  // Check streak whenever app opens
  Future<void> _checkStreakOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    
    // Update last app open date
    await prefs.setString(_lastAppOpenDateKey, today);
    
    // Check if we need to update daily quiz status
    if (_streakHistory.isNotEmpty) {
      final lastQuizDate = _streakHistory.last;
      
      // Check if last quiz was today
      _dailyQuizDone = _isToday(lastQuizDate);
      
      // Calculate current streak
      _dayStreak = _calculateCurrentStreak();
      
      // Save updates
      await prefs.setInt(_streakKey, _dayStreak);
      await prefs.setBool(_dailyQuizDoneKey, _dailyQuizDone);
    }
    
    notifyListeners();
  }

  // Calculate current streak from history
  int _calculateCurrentStreak() {
    if (_streakHistory.isEmpty) return 0;
    
    // Sort dates (newest first)
    _streakHistory.sort((a, b) => b.compareTo(a));
    
    int streak = 0;
    DateTime? previousDate;
    final today = _getTodayString();
    final yesterday = _getYesterdayString();
    
    for (final dateStr in _streakHistory) {
      if (streak == 0) {
        // First check: must be today or yesterday to start streak
        if (_isToday(dateStr) || _isYesterday(dateStr)) {
          streak = 1;
          previousDate = _stringToDate(dateStr);
        } else {
          // No recent activity
          break;
        }
      } else {
        // Check consecutive days
        if (previousDate != null) {
          final currentDate = _stringToDate(dateStr);
          final daysDifference = previousDate.difference(currentDate).inDays.abs();
          
          if (daysDifference == 1) {
            streak++;
            previousDate = currentDate;
          } else {
            break; // Gap found, streak ends
          }
        }
      }
    }
    
    return streak;
  }

  // Complete daily quiz
  Future<void> completeDailyQuiz({required bool isCorrect}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    
    // Check if quiz already completed today
    if (_dailyQuizDone) {
      throw Exception('Daily quiz already completed today');
    }
    
    // Add today to streak history
    if (!_streakHistory.contains(today)) {
      _streakHistory.add(today);
      
      // Keep only last 365 days to save storage
      if (_streakHistory.length > 365) {
        _streakHistory = _streakHistory.sublist(_streakHistory.length - 365);
      }
      
      // Save updated history
      await prefs.setStringList(_streakHistoryKey, _streakHistory);
    }
    
    // Update streak
    _dayStreak = _calculateCurrentStreak();
    _dailyQuizDone = true;
    
    // Award points if correct
    if (isCorrect) {
      _points += 10;
    }
    
    // Save all changes
    await prefs.setInt(_totalWatchedKey, _totalWatched);
    await prefs.setInt(_pointsKey, _points);
    await prefs.setInt(_streakKey, _dayStreak);
    await prefs.setBool(_dailyQuizDoneKey, _dailyQuizDone);
    
    notifyListeners();
  }

  // Get streak calendar for display (last 30 days)
  Map<String, bool> getStreakCalendar() {
    final calendar = <String, bool>{};
    final today = DateTime.now();
    
    // Generate last 30 days
    for (int i = 0; i < 30; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = _dateToString(date);
      calendar[dateStr] = _streakHistory.contains(dateStr);
    }
    
    return calendar;
  }

  // Get longest streak
  int getLongestStreak() {
    if (_streakHistory.isEmpty) return 0;
    
    final dates = _streakHistory.map(_stringToDate).toList();
    dates.sort((a, b) => a.compareTo(b));
    
    int longestStreak = 0;
    int currentStreak = 1;
    
    for (int i = 1; i < dates.length; i++) {
      final daysDifference = dates[i].difference(dates[i - 1]).inDays.abs();
      
      if (daysDifference == 1) {
        currentStreak++;
      } else if (daysDifference > 1) {
        longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
        currentStreak = 1;
      }
    }
    
    return longestStreak > currentStreak ? longestStreak : currentStreak;
  }

  // Mark sign as watched
  void markAsWatched(String signTitle) {
    _watchedSigns.add(signTitle);
    _totalWatched = _watchedSigns.length;
    
    // Save to storage
    _saveWatchedSigns();
  }

  bool isWatched(String signTitle) {
    return _watchedSigns.contains(signTitle);
  }

  Future<void> _saveWatchedSigns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_watchedSignsKey, _watchedSigns.toList());
    await prefs.setInt(_totalWatchedKey, _totalWatched);
    
    notifyListeners();
  }

  // Reset for testing
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    
    _totalWatched = 0;
    _points = 0;
    _dayStreak = 0;
    _dailyQuizDone = false;
    _streakHistory.clear();
    _watchedSigns.clear();
    
    await prefs.remove(_totalWatchedKey);
    await prefs.remove(_pointsKey);
    await prefs.remove(_streakKey);
    await prefs.remove(_lastQuizDateKey);
    await prefs.remove(_dailyQuizDoneKey);
    await prefs.remove(_streakHistoryKey);
    await prefs.remove(_lastAppOpenDateKey);
    await prefs.remove(_watchedSignsKey);
    
    notifyListeners();
  }

  // Getters
  int get totalWatched => _totalWatched;
  int get points => _points;
  int get dayStreak => _dayStreak;
  bool get dailyQuizDone => _dailyQuizDone;
  Set<String> get watchedSigns => _watchedSigns;
  List<String> get streakHistory => List.unmodifiable(_streakHistory);
}