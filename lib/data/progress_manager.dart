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
  int _totalActiveDays = 0; // Tracks total days user was active for stages
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
  int get totalActiveDays => _totalActiveDays; // For stage calculation
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
    _totalActiveDays = data['totalActiveDays'] ?? _dayStreak; // Default to streak for old users
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

    final progressData = {
      'userId': uid,
      'userName': userName ?? 'Learner',
      'learnedSignIds': _watchedVideos.toList(),
      'masteryScore': _masteryScores.isNotEmpty ? _masteryScores : { 'overall': _points },
      'lastActiveDate': FieldValue.serverTimestamp(),
      
      // Keep these for app logic
      'points': _points,
      'dayStreak': _dayStreak,
      'totalActiveDays': _totalActiveDays, // CRITICAL: Add total active days
      'dailyQuizDone': _dailyQuizDone,
      'dailyWatchedCount': _dailyWatchedCount,
      'totalWatched': _totalWatched,
      
      // Add quiz statistics
      'totalQuizAttempts': FieldValue.increment(0),
      'correctQuizAttempts': FieldValue.increment(0),
      'averageResponseTime': 0.0,
    };

    // Save Local
    final localData = Map<String, dynamic>.from(progressData);
    localData['lastActiveDate'] = DateTime.now().toIso8601String();
    await _saveToLocalCache(uid, localData);

    // Save Cloud
    try {
      await _firestore
          .collection('user_progress')
          .doc(uid)
          .set(progressData, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('⚠️ Cloud sync failed: $e');
    }
  }

  Future<void> _saveToLocalCache(String uid, Map<String, dynamic> data) async {
    if (_prefs == null) return;
    final key = _getUserStorageKey(uid);
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.removeWhere((key, value) => value is FieldValue); 
    
    await _prefs!.setString(key, jsonEncode(cleanData));
  }

  void _clearInMemoryState() {
    _totalWatched = 0;
    _dailyWatchedCount = 0;
    _dayStreak = 0;
    _totalActiveDays = 0;
    _points = 0;
    _dailyQuizDone = false;
    _watchedVideos = {};
    _masteryScores = {};
    _lastActiveDate = null;
    notifyListeners();
  }

  // ─── ACTIONS ───────────────────────────────────────────────────────

  Future<void> markAsWatched(String signId) async {
    if (!isSignedIn) return;
    await _checkAndResetDailyLogs();
    await _updateActiveDays(); // Update active days when user watches

    if (!_watchedVideos.contains(signId)) {
      _watchedVideos.add(signId);
      _totalWatched++;
      _dailyWatchedCount++; 
      await _updateStreak();
      await _saveUserData(); 
      notifyListeners();
    }
  }

  Future<void> completeDailyQuiz({required bool isCorrect}) async {
    if (!isSignedIn) throw Exception('Must be signed in');
    
    await _checkAndResetDailyLogs();
    
    // Double-check if already completed today
    if (_dailyQuizDone) {
      throw Exception('Daily quiz already completed for today');
    }
    
    // Update active days for stage progression
    await _updateActiveDays();
    
    _dailyQuizDone = true;
    if (isCorrect) _points += 10;

    await _updateStreak();
    await _saveUserData(); 
    notifyListeners();
  }

  // ─── ACTIVE DAYS TRACKING FOR STAGES ───────────────────────────────
  Future<void> _updateActiveDays() async {
    final now = DateTime.now();
    
    print('📅 Active Days Update:');
    print('📅 Current lastActiveDate: $_lastActiveDate');
    
    // If first time
    if (_lastActiveDate == null) {
      _totalActiveDays = 1;
      _lastActiveDate = now;
      print('📅 First time - set totalActiveDays to 1');
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
    
    print('📅 Today: $today');
    print('📅 Last Date: $lastDate');
    print('📅 Diff in days: $diffInDays');
    print('📅 Current totalActiveDays: $_totalActiveDays');
    
    if (diffInDays >= 1) {
      // New day - increment total active days
      _totalActiveDays++;
      _lastActiveDate = now;
      print('📅 New active day - totalActiveDays: $_totalActiveDays');
    }
    // If diffInDays == 0, same day, don't increment
    // If diffInDays < 0 (future date), ignore
    
    await _saveUserData();
  }

  // ─── DAILY RESET LOGIC ────────────────────────────────────────────
  Future<void> _checkAndResetDailyLogs() async {
    print('🕐 Checking daily logs...');
    print('🕐 Current time: ${DateTime.now()}');
    print('🕐 Last active: $_lastActiveDate');
    
    if (_lastActiveDate != null) {
      final now = DateTime.now();
      final last = _lastActiveDate!;
      
      // Check if it's a new calendar day (00:00)
      final bool isNewDay = now.year != last.year || 
                            now.month != last.month || 
                            now.day != last.day;
      
      print('🕐 Is new day? $isNewDay');
      print('🕐 Daily quiz done before reset: $_dailyQuizDone');
      
      if (isNewDay) {
        // Reset daily quiz availability
        _dailyQuizDone = false;
        _dailyWatchedCount = 0; 
        print('🔄 Daily quiz reset to: $_dailyQuizDone');
        
        // Save the reset state
        await _saveUserData();
      }
    }
    notifyListeners();
  }

  // ─── LEARNING STAGE TRACKING (UPDATED) ─────────────────────────────
  
  /// Get current learning stage based on total active days
  Map<String, dynamic> getLearningStageInfo() {
    const int stageLength = 5; // 5 days per category
    
    // Use totalActiveDays for stage calculation
    // Day 0 should be treated as Day 1 for new users
    final int activeDaysForStage = _totalActiveDays == 0 ? 1 : _totalActiveDays;
    
    // Calculate stage based on total active days
    // Day 1-5: Stage 1 (Alphabet)
    // Day 6-10: Stage 2 (Numbers)
    final int stageNumber = ((activeDaysForStage - 1) ~/ stageLength) + 1;
    
    // Day within current stage (1-5)
    final int stageDay = ((activeDaysForStage - 1) % stageLength) + 1;
    
    // Define category sequence (9 categories total)
    final List<String> categories = [
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
    final int categoryIndex = (stageNumber - 1) % categories.length;
    final String currentCategory = categories[categoryIndex];
    
    // Calculate days remaining in current stage
    final int daysRemainingInStage = stageLength - stageDay;
    
    print('📊 Learning Stage Debug:');
    print('📊 Total Active Days: $_totalActiveDays');
    print('📊 Active Days for Stage Calc: $activeDaysForStage');
    print('📊 Stage Number: $stageNumber');
    print('📊 Stage Day: $stageDay/$stageLength');
    print('📊 Current Category: $currentCategory');
    print('📊 Days Remaining: $daysRemainingInStage');
    
    return {
      'currentCategory': currentCategory,
      'stageNumber': stageNumber,
      'stageDay': stageDay,
      'stageLength': stageLength,
      'totalActiveDays': _totalActiveDays,
      'daysRemainingInStage': daysRemainingInStage,
    };
  }

  /// Get the next category after current one
  String getNextCategory() {
    final stageInfo = getLearningStageInfo();
    final String currentCategory = stageInfo['currentCategory'];
    
    final List<String> categories = [
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
    
    final int currentIndex = categories.indexOf(currentCategory);
    final int nextIndex = (currentIndex + 1) % categories.length;
    
    return categories[nextIndex];
  }

  // ─── TASK 1.2: QUIZ LOGGING ──────────────────────────────────────
  Future<void> saveQuizAttempt({
    required String questionText,
    required String? signId,
    required bool isCorrect,
    required int responseTimeMs,
  }) async {
    if (!isSignedIn) return;

    try {
      await _firestore.collection('quiz_attempts').add({
        'userId': userId,
        'questionText': questionText,
        'signId': signId ?? questionText,
        'isCorrect': isCorrect,
        'responseTime': responseTimeMs,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final userRef = _firestore.collection('user_progress').doc(userId!);
      await userRef.update({
        'totalQuizAttempts': FieldValue.increment(1),
        'correctQuizAttempts': isCorrect 
          ? FieldValue.increment(1) 
          : FieldValue.increment(0),
      });

      await _updateAverageResponseTime(responseTimeMs);

      if (kDebugMode) print('📊 Quiz attempt logged: $signId - $isCorrect (${responseTimeMs}ms)');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to log quiz attempt: $e');
    }
  }

  Future<void> _updateAverageResponseTime(int newResponseTime) async {
    try {
      final userRef = _firestore.collection('user_progress').doc(userId!);
      final doc = await userRef.get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final currentAvg = data['averageResponseTime'] ?? 0.0;
        final totalAttempts = data['totalQuizAttempts'] ?? 1;
        
        final newAvg = (currentAvg * (totalAttempts - 1) + newResponseTime) / totalAttempts;
        
        await userRef.update({
          'averageResponseTime': newAvg,
        });
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to update average response time: $e');
    }
  }

  // ─── TASK 1.3: ADAPTIVE QUIZ SUPPORT ────────────────────────────
  
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
          'totalActiveDays': data['totalActiveDays'] ?? 0,
        };
      }
    } catch (e) {
      if (kDebugMode) print('Error getting user progress for quiz: $e');
    }
    return {};
  }

  Future<void> updateMasteryScore(String signId, bool isCorrect) async {
    if (!isSignedIn) return;
    
    try {
      final userRef = _firestore.collection('user_progress').doc(userId!);
      final doc = await userRef.get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final masteryScores = Map<String, int>.from(data['masteryScore'] ?? {});
        
        final currentScore = masteryScores[signId] ?? 0;
        final change = isCorrect ? 10 : -5;
        final newScore = (currentScore + change).clamp(0, 100);
        
        masteryScores[signId] = newScore;
        _masteryScores[signId] = newScore;
        
        await userRef.update({
          'masteryScore': masteryScores,
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error updating mastery score: $e');
    }
  }

  // ─── STREAK MANAGEMENT ──────────────────────────────────────────
  Future<void> _updateStreak() async {
    final now = DateTime.now();
    
    if (_lastActiveDate == null) {
      _dayStreak = 1;
      _lastActiveDate = now;
      return;
    }
    
    final lastDate = DateTime(
      _lastActiveDate!.year, 
      _lastActiveDate!.month, 
      _lastActiveDate!.day
    );
    
    final today = DateTime(now.year, now.month, now.day);
    
    final diffInDays = today.difference(lastDate).inDays;
    
    print('📅 Streak Debug:');
    print('📅 Today: $today');
    print('📅 Last Date: $lastDate');
    print('📅 Diff in days: $diffInDays');
    print('📅 Current streak: $_dayStreak');
    
    if (diffInDays == 1) {
      _dayStreak++;
      print('📅 New day - streak increased to $_dayStreak');
    } else if (diffInDays > 1) {
      _dayStreak = 1;
      print('📅 Streak broken - reset to 1');
    }
    
    _lastActiveDate = now;
    print('📅 Streak updated - new streak: $_dayStreak');
    
    await _saveUserData();
  }

  // ─── PUBLIC METHOD FOR DAILY QUIZ SCREEN ────────────────────────
  Future<void> checkAndResetDailyLogs() async {
    await _checkAndResetDailyLogs();
  }

  // ─── ADDITIONAL HELPER METHODS ────────────────────────────────
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

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final snapshot = await _firestore
          .collection('user_progress')
          .orderBy('points', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['userId'] = doc.id;
        
        if (!data.containsKey('userName') || data['userName'] == null) {
          data['userName'] = 'Learner';
        }
        
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

  Map<DateTime, bool> getStreakCalendar() {
    final calendar = <DateTime, bool>{};
    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final isActive = (_dayStreak > 0) && (i < _dayStreak);
      calendar[date] = isActive;
    }
    return calendar;
  }

  int get watchedVideosCount => _watchedVideos.length;
  
  int getMasteryScore(String signId) {
    return _masteryScores[signId] ?? 0;
  }
}