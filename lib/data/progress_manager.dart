// lib/data/progress_manager.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressManager with ChangeNotifier {
  // ─── STATE VARIABLES ───────────────────────────────────────────────
  int _totalWatched = 0;
  int _dailyWatchedCount = 0;
  int _dayStreak = 0;
  int _totalActiveDays = 0; // NEW: Tracks total days user was active
  int _points = 0;
  bool _dailyQuizDone = false;
  
  Set<String> _watchedVideos = {}; // Maps to 'learnedSignIds'
  Map<String, int> _masteryScores = {}; // Maps to 'masteryScore'
  DateTime? _lastActiveDate;

  // ─── DEPENDENCIES ──────────────────────────────────────────────────
  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── GETTERS ───────────────────────────────────────────────────────
  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isSignedIn => currentUser != null;
  String? get userId => currentUser?.uid;
  String? get userName => currentUser?.displayName ?? currentUser?.email?.split('@').first;

  int get totalWatched => _totalWatched;
  int get dailyWatchedCount => _dailyWatchedCount;
  int get dayStreak => _dayStreak;
  int get totalActiveDays => _totalActiveDays; // NEW
  int get points => _points;
  bool get dailyQuizDone => _dailyQuizDone;

  bool isWatched(String videoTitle) => _watchedVideos.contains(videoTitle);

  ProgressManager() {
    _init();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _clearInMemoryState();
      }
    });
  }

  // ─── DATA SYNC (CLOUD + LOCAL) ─────────────────────────────────────

  String _getUserStorageKey(String uid) => 'progress_data_$uid';

  Future<void> _loadUserData(String uid) async {
    bool dataLoaded = false;

    try {
      // 1. Load from NEW 'user_progress' collection
      final docSnapshot = await _firestore.collection('user_progress').doc(uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _parseAndApplyData(data);
        dataLoaded = true;
        await _saveToLocalCache(uid, data);
        if (kDebugMode) print('☁️ Loaded data from user_progress');
      } 
      // 2. Fallback: Migration for old users (reads from 'users')
      else {
        final oldDoc = await _firestore.collection('users').doc(uid).get();
        if (oldDoc.exists && oldDoc.data()!.containsKey('points')) {
           _parseAndApplyData(oldDoc.data()!);
           // Immediately save to new collection to complete migration
           await _saveUserData(); 
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Cloud load failed: $e');
    }

    if (!dataLoaded) {
      final key = _getUserStorageKey(uid);
      final localJson = _prefs?.getString(key);
      if (localJson != null) {
        _parseAndApplyData(jsonDecode(localJson));
      }
    }

    await _checkAndResetDailyLogs();
    notifyListeners();
  }

  void _parseAndApplyData(Map<String, dynamic> data) {
    _totalWatched = data['totalWatched'] ?? 0;
    _dailyWatchedCount = data['dailyWatchedCount'] ?? 0; 
    _dayStreak = data['dayStreak'] ?? 0;
    _totalActiveDays = data['totalActiveDays'] ?? _dayStreak; // NEW: Default to streak for old users
    _dailyQuizDone = data['dailyQuizDone'] ?? false;
    _points = data['points'] ?? 0;

    // Handle watched videos/learned signs
    List<String> loadedSigns = [];
    if (data['learnedSignIds'] != null) {
      loadedSigns = List<String>.from(data['learnedSignIds']);
    } else if (data['watchedVideos'] != null) {
      loadedSigns = List<String>.from(data['watchedVideos']);
    }
    _watchedVideos = Set<String>.from(loadedSigns);

    // Handle lastActiveDate - CRITICAL for streak calculation
    final lastActiveVal = data['lastActiveDate'] ?? data['lastAccessed'];
    if (lastActiveVal != null) {
      if (lastActiveVal is Timestamp) {
        _lastActiveDate = lastActiveVal.toDate();
      } else if (lastActiveVal is String) {
        _lastActiveDate = DateTime.tryParse(lastActiveVal);
      }
    }
    
    // If still null, initialize with current date
    if (_lastActiveDate == null) {
      _lastActiveDate = DateTime.now();
    }
  }

  Future<void> _saveUserData() async {
    if (!isSignedIn) return;
    final uid = userId!;

    // This data structure matches your NEW Schema
    final progressData = {
      'userId': uid,
      'userName': userName ?? 'Learner', // Needed for Leaderboard
      'learnedSignIds': _watchedVideos.toList(),
      'masteryScore': { 'overall': _points },
      'lastActiveDate': FieldValue.serverTimestamp(),
      
      // Keep these for app logic
      'points': _points,
      'dayStreak': _dayStreak,
      'totalActiveDays': _totalActiveDays, // NEW: Add total active days
      'dailyQuizDone': _dailyQuizDone,
      'dailyWatchedCount': _dailyWatchedCount,
      'totalWatched': _totalWatched,
      
      // Add quiz statistics for Task 1.2
      'totalQuizAttempts': FieldValue.increment(0), // Will be updated via saveQuizAttempt
      'correctQuizAttempts': FieldValue.increment(0),
      'averageResponseTime': 0.0,
    };

    // Save Local
    final localData = Map<String, dynamic>.from(progressData);
    localData['lastActiveDate'] = DateTime.now().toIso8601String();
    await _saveToLocalCache(uid, localData);

    // Save Cloud (To NEW Collection)
    try {
      await _firestore
          .collection('user_progress') // <--- The important change
          .doc(uid)
          .set(progressData, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('⚠️ Cloud sync failed: $e');
    }
  }

  Future<void> _saveToLocalCache(String uid, Map<String, dynamic> data) async {
    if (_prefs == null) return;
    final key = _getUserStorageKey(uid);
    // Simple sanitization to remove FieldValues before JSON encoding
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.removeWhere((key, value) => value is FieldValue); 
    
    await _prefs!.setString(key, jsonEncode(cleanData));
  }

  void _clearInMemoryState() {
    _totalWatched = 0;
    _dailyWatchedCount = 0;
    _dayStreak = 0;
    _totalActiveDays = 0; // NEW: Reset active days
    _points = 0;
    _dailyQuizDone = false;
    _watchedVideos = {};
    _lastActiveDate = null;
    notifyListeners();
  }

  // ─── ACTIONS ───────────────────────────────────────────────────────

  Future<void> markAsWatched(String signId) async {
    if (!isSignedIn) return;
    await _checkAndResetDailyLogs();
    await _updateActiveDays(); // NEW: Update active days when user watches

    if (!_watchedVideos.contains(signId)) {
      _watchedVideos.add(signId);
      _totalWatched++;
      _dailyWatchedCount++; 
      await _updateStreak(); // Keep streak for motivation
      await _saveUserData(); 
      notifyListeners();
    }
  }

  Future<void> completeDailyQuiz({required bool isCorrect}) async {
    if (!isSignedIn) throw Exception('Must be signed in');
    await _checkAndResetDailyLogs();
    await _updateActiveDays(); // NEW: Update active days when user takes quiz
    
    if (_dailyQuizDone) throw Exception('Quiz already done');

    _dailyQuizDone = true;
    if (isCorrect) _points += 10;

    await _updateStreak(); // Keep streak for motivation
    await _saveUserData(); 
    notifyListeners();
  }

  // ─── ACTIVE DAYS TRACKING ──────────────────────────────────────────
  /// Updates total active days (counts days user was active)
  Future<void> _updateActiveDays() async {
    final now = DateTime.now();
    
    // If first time
    if (_lastActiveDate == null) {
      _totalActiveDays = 1;
      _lastActiveDate = now;
      return;
    }
    
    final lastDate = DateTime(
      _lastActiveDate!.year, 
      _lastActiveDate!.month, 
      _lastActiveDate!.day
    );
    
    final today = DateTime(now.year, now.month, now.day);
    
    // Calculate days difference
    final diffInDays = today.difference(lastDate).inDays;
    
    print('📅 Active Days Debug:');
    print('📅 Today: $today');
    print('📅 Last Date: $lastDate');
    print('📅 Diff in days: $diffInDays');
    print('📅 Current active days: $_totalActiveDays');
    
    if (diffInDays >= 1) {
      // New day - increment total active days
      _totalActiveDays++;
      _lastActiveDate = now;
      print('📅 New active day - total: $_totalActiveDays');
    }
    // If diffInDays == 0, same day, don't increment
    // If diffInDays < 0 (future date), ignore
    
    await _saveUserData();
  }

  // ─── TASK 1.2: QUIZ LOGGING ──────────────────────────────────────
  /// Logs every single quiz attempt to the 'quiz_attempts' collection
  Future<void> saveQuizAttempt({
    required String questionText,
    required String? signId,
    required bool isCorrect,
    required int responseTimeMs,
  }) async {
    if (!isSignedIn) return;

    try {
      // Save to quiz_attempts collection
      await _firestore.collection('quiz_attempts').add({
        'userId': userId,
        'questionText': questionText,
        'signId': signId ?? questionText, // Use question as fallback
        'isCorrect': isCorrect,
        'responseTime': responseTimeMs,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user's quiz statistics in user_progress
      final userRef = _firestore.collection('user_progress').doc(userId!);
      await userRef.update({
        'totalQuizAttempts': FieldValue.increment(1),
        'correctQuizAttempts': isCorrect 
          ? FieldValue.increment(1) 
          : FieldValue.increment(0),
      });

      // Update average response time
      await _updateAverageResponseTime(responseTimeMs);

      if (kDebugMode) print('📊 Quiz attempt logged: $signId - $isCorrect (${responseTimeMs}ms)');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to log quiz attempt: $e');
    }
  }

  /// Update average response time
  Future<void> _updateAverageResponseTime(int newResponseTime) async {
    try {
      final userRef = _firestore.collection('user_progress').doc(userId!);
      final doc = await userRef.get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final currentAvg = data['averageResponseTime'] ?? 0.0;
        final totalAttempts = data['totalQuizAttempts'] ?? 1;
        
        // Calculate new average
        final newAvg = (currentAvg * (totalAttempts - 1) + newResponseTime) / totalAttempts;
        
        await userRef.update({
          'averageResponseTime': newAvg,
        });
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to update average response time: $e');
    }
  }

  /// Get user's quiz history
  Future<List<Map<String, dynamic>>> getQuizHistory() async {
    if (!isSignedIn) return [];

    try {
      final snapshot = await _firestore
          .collection('quiz_attempts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'signId': data['signId'],
          'questionText': data['questionText'],
          'isCorrect': data['isCorrect'],
          'responseTime': data['responseTime'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching quiz history: $e');
      return [];
    }
  }

  /// Fetches ALL users from 'user_progress' sorted by points
  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final snapshot = await _firestore
          .collection('user_progress')
          .orderBy('points', descending: true)
          .limit(100)
          .get();

      // Transform data to ensure LeaderboardScreen works
      return snapshot.docs.map((doc) {
        final data = doc.data();
        
        // INJECT ID: This fixes the 'isMe' check in your LeaderboardScreen
        data['userId'] = doc.id; 
        
        // Ensure name exists
        if (!data.containsKey('userName') || data['userName'] == null) {
          data['userName'] = 'Learner';
        }
        
        // Ensure points exist
        if (!data.containsKey('points')) {
          data['points'] = 0;
        }
        
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching leaderboard: $e');
      return [];
    }
  }

  // ─── TASK 1.3: ADAPTIVE QUIZ SUPPORT ────────────────────────────
  
  /// Get user's learned signs and mastery scores
  Future<Map<String, dynamic>> getUserProgressForQuiz() async {
    if (!isSignedIn) return {};
    
    try {
      final doc = await _firestore.collection('user_progress').doc(userId!).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'learnedSignIds': List<String>.from(data['learnedSignIds'] ?? []),
          'masteryScore': Map<String, int>.from(data['masteryScore'] ?? {}),
          'totalWatched': data['totalWatched'] ?? 0,
          'totalActiveDays': data['totalActiveDays'] ?? 0, // NEW
        };
      }
    } catch (e) {
      if (kDebugMode) print('Error getting user progress for quiz: $e');
    }
    return {};
  }

  /// Update mastery score for a sign after quiz attempt
  Future<void> updateMasteryScore(String signId, bool isCorrect) async {
    if (!isSignedIn) return;
    
    try {
      final userRef = _firestore.collection('user_progress').doc(userId!);
      final doc = await userRef.get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final masteryScores = Map<String, int>.from(data['masteryScore'] ?? {});
        
        // Calculate new mastery score
        final currentScore = masteryScores[signId] ?? 0;
        final change = isCorrect ? 10 : -5;
        final newScore = (currentScore + change).clamp(0, 100);
        
        masteryScores[signId] = newScore;
        
        await userRef.update({
          'masteryScore': masteryScores,
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error updating mastery score: $e');
    }
  }

  // ─── LEARNING STAGE TRACKING (UPDATED) ─────────────────────────────
  
  /// Get current learning stage based on total active days
  String getCurrentLearningStage() {
    final stageLength = 5;
    
    // Use totalActiveDays instead of dayStreak
    final activeDaysForStage = _totalActiveDays;
    
    if (activeDaysForStage <= 0) {
      return 'Alphabet'; // Default to first stage
    }
    
    // Calculate stage based on total active days
    // Day 1-5: Stage 1 (Alphabet)
    // Day 6-10: Stage 2 (Numbers)
    final stageNumber = ((activeDaysForStage - 1) ~/ stageLength) + 1;
    
    // Define category sequence
    final categories = [
      'Alphabet',
      'Numbers',
      'Family',
      'Food & Drink',
      'Emotions',
      'Time',
      'Colors',
      'Animals',
      'Greetings',
    ];
    
    // Cycle through categories if active days exceed total categories
    final categoryIndex = (stageNumber - 1) % categories.length;
    final currentCategory = categories[categoryIndex];
    
    print('📊 Learning Stage Debug:');
    print('📊 Total Active Days: $activeDaysForStage');
    print('📊 Stage Number: $stageNumber');
    print('📊 Current Category: $currentCategory');
    
    return currentCategory;
  }

  /// Get stage progress info based on total active days
  Map<String, dynamic> getLearningStageInfo() {
    final stageLength = 5;
    final activeDaysForStage = _totalActiveDays;
    
    // Handle day 0 (new user)
    if (activeDaysForStage == 0) {
      return {
        'currentCategory': 'Alphabet',
        'stageNumber': 1,
        'stageDay': 1,
        'stageLength': stageLength,
        'daysInCurrentStage': 1,
        'daysRemainingInStage': stageLength,
      };
    }
    
    // Calculate stage number based on active days
    final stageNumber = ((activeDaysForStage - 1) ~/ stageLength) + 1;
    
    // Day within current stage (1-5)
    final stageDay = ((activeDaysForStage - 1) % stageLength) + 1;
    
    final currentCategory = getCurrentLearningStage();
    
    return {
      'currentCategory': currentCategory,
      'stageNumber': stageNumber,
      'stageDay': stageDay,
      'stageLength': stageLength,
      'daysInCurrentStage': stageDay,
      'daysRemainingInStage': stageLength - stageDay + 1,
    };
  }

  // ─── HELPERS ───────────────────────────────────────────────────────

  Future<void> _checkAndResetDailyLogs() async {
    print('🕐 Checking daily logs...');
    print('🕐 Current time: ${DateTime.now()}');
    print('🕐 Last active: $_lastActiveDate');
    
    if (_lastActiveDate != null) {
      final now = DateTime.now();
      final last = _lastActiveDate!;
      bool isNewDay = now.year != last.year || 
                      now.month != last.month || 
                      now.day != last.day;
      
      print('🕐 Is new day? $isNewDay');
      print('🕐 Daily quiz done before reset: $_dailyQuizDone');
      
      if (isNewDay) {
        _dailyQuizDone = false;
        _dailyWatchedCount = 0; 
        print('🔄 Daily quiz reset to: $_dailyQuizDone');
      }
    }
    notifyListeners();
  }

  /// Updates streak for motivational purposes (consecutive days)
  Future<void> _updateStreak() async {
    final now = DateTime.now();
    
    // If first time or no last active date
    if (_lastActiveDate == null) {
      _dayStreak = 1;
      _lastActiveDate = now;
      _dailyQuizDone = false; // Ensure quiz is available
      return;
    }
    
    final lastDate = DateTime(
      _lastActiveDate!.year, 
      _lastActiveDate!.month, 
      _lastActiveDate!.day
    );
    
    final today = DateTime(now.year, now.month, now.day);
    
    // Calculate days difference
    final diffInDays = today.difference(lastDate).inDays;
    
    print('📅 Streak Debug:');
    print('📅 Today: $today');
    print('📅 Last Date: $lastDate');
    print('📅 Diff in days: $diffInDays');
    print('📅 Current streak: $_dayStreak');
    
    // Keep simple streak logic for motivation only
    if (diffInDays == 1) {
      // Consecutive day - increase streak
      _dayStreak++;
      print('📅 New day - streak increased to $_dayStreak');
    } else if (diffInDays > 1) {
      // Break in streak - reset to 1
      _dayStreak = 1;
      print('📅 Streak broken - reset to 1');
    }
    // If diffInDays == 0, same day - no change
    // If diffInDays < 0 (future date), ignore
    
    _lastActiveDate = now;
    _dailyQuizDone = false; // Ensure quiz is available for new day
    print('📅 Quiz reset to available');
    
    await _saveUserData();
  }
  
  Map<DateTime, bool> getStreakCalendar() {
    final calendar = <DateTime, bool>{};
    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      calendar[now.subtract(Duration(days: i))] = i < _dayStreak;
    }
    return calendar;
  }

  /// Get user's watched videos count
  int get watchedVideosCount => _watchedVideos.length;
  
  /// Get mastery score for a specific sign
  int getMasteryScore(String signId) {
    return _masteryScores[signId] ?? 0;
  }
}