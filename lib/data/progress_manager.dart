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
  int _dailyWatchedCount = 0; // [FIX 1] New variable to track daily progress specifically
  int _dayStreak = 0;
  int _points = 0;
  bool _dailyQuizDone = false;
  Set<String> _watchedVideos = {};
  DateTime? _lastActiveDate;

  // ─── DEPENDENCIES ──────────────────────────────────────────────────
  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── GETTERS ───────────────────────────────────────────────────────
  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isSignedIn => currentUser != null;
  String? get userId => currentUser?.uid;
  String? get userName =>
      currentUser?.displayName ?? currentUser?.email?.split('@').first;

  int get totalWatched => _totalWatched;
  int get dailyWatchedCount => _dailyWatchedCount; // [FIX 2] Expose daily count
  int get dayStreak => _dayStreak;
  int get points => _points;
  bool get dailyQuizDone => _dailyQuizDone;

  bool isWatched(String videoTitle) => _watchedVideos.contains(videoTitle);

  // ─── INITIALIZATION ────────────────────────────────────────────────
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

    // Listen for Login/Logout events
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // User Logged In: Load Cloud Data
        _loadUserData(user.uid);
      } else {
        // User Logged Out: Clear Screen
        _clearInMemoryState();
      }
    });
  }

  // ─── DATA SYNC (CLOUD + LOCAL) ─────────────────────────────────────

  String _getUserStorageKey(String uid) => 'progress_data_$uid';

  Future<void> _loadUserData(String uid) async {
    bool dataLoaded = false;

    // 1. Try Loading from Cloud (Firestore)
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _parseAndApplyData(data);
        dataLoaded = true;

        // Update local cache to match cloud
        await _saveToLocalCache(uid, data);
        if (kDebugMode) print('☁️ Loaded data from Cloud Firestore');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Cloud load failed (Offline?): $e');
    }

    // 2. Fallback: Load from Local Storage if Cloud failed
    if (!dataLoaded) {
      final key = _getUserStorageKey(uid);
      final localJson = _prefs?.getString(key);
      if (localJson != null) {
        _parseAndApplyData(jsonDecode(localJson));
        if (kDebugMode) print('📱 Loaded data from Local Cache');
      } else {
        _clearInMemoryState(); // New user
      }
    }

    // 3. Logic Checks: Reset counters if it's a new day
    await _checkAndResetDailyLogs();
    
    notifyListeners();
  }

  /// Helper to parse raw JSON/Map data into variables
  void _parseAndApplyData(Map<String, dynamic> data) {
    _totalWatched = data['totalWatched'] ?? 0;
    
    // [FIX 3] Load the daily count. Default to 0 if missing.
    _dailyWatchedCount = data['dailyWatchedCount'] ?? 0; 
    
    _dayStreak = data['dayStreak'] ?? 0;
    _points = data['points'] ?? 0;
    _dailyQuizDone = data['dailyQuizDone'] ?? false;

    final watchedList = List<String>.from(data['watchedVideos'] ?? []);
    _watchedVideos = Set<String>.from(watchedList);

    final lastActiveString = data['lastActiveDate'];
    if (lastActiveString != null) {
      _lastActiveDate = DateTime.tryParse(lastActiveString);
    }
  }

  /// Master Save Method: Saves to BOTH Local and Cloud
  Future<void> _saveUserData() async {
    if (!isSignedIn) return;
    final uid = userId!;

    // Prepare Data Object
    final data = {
      'userId': uid,
      'userName': userName,
      'totalWatched': _totalWatched,
      'dailyWatchedCount': _dailyWatchedCount, // [FIX 4] Save daily count
      'dayStreak': _dayStreak,
      'points': _points,
      'dailyQuizDone': _dailyQuizDone,
      'watchedVideos': _watchedVideos.toList(),
      'lastActiveDate': _lastActiveDate?.toIso8601String(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    // 1. Save to Local Cache (Fast, works offline)
    await _saveToLocalCache(uid, data);

    // 2. Save to Cloud Firestore (Async background sync)
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      if (kDebugMode) print('☁️ Synced to Cloud');
    } catch (e) {
      if (kDebugMode) print('⚠️ Cloud sync failed (will retry next time): $e');
    }
  }

  Future<void> _saveToLocalCache(String uid, Map<String, dynamic> data) async {
    if (_prefs == null) return;
    final key = _getUserStorageKey(uid);
    await _prefs!.setString(key, jsonEncode(data));
  }

  // ─── RESET STATE ──────────────────────────────────────────────────

  void _clearInMemoryState() {
    _totalWatched = 0;
    _dailyWatchedCount = 0;
    _dayStreak = 0;
    _points = 0;
    _dailyQuizDone = false;
    _watchedVideos = {};
    _lastActiveDate = null;
    notifyListeners();
  }

  // ─── USER ACTIONS ─────────────────────────────────────────────────

  Future<void> markAsWatched(String videoTitle) async {
    if (!isSignedIn) return;

    // [FIX 5] Check if it's a new day before we do anything
    await _checkAndResetDailyLogs();

    if (!_watchedVideos.contains(videoTitle)) {
      _watchedVideos.add(videoTitle);
      
      _totalWatched++;
      _dailyWatchedCount++; // [FIX 6] Increment daily count specifically

      await _updateStreak();
      await _saveUserData(); // Triggers Cloud Sync
      notifyListeners();
    }
  }

  Future<void> completeDailyQuiz({required bool isCorrect}) async {
    if (!isSignedIn) throw Exception('Must be signed in');
    
    // Ensure we are operating on the correct day's data
    await _checkAndResetDailyLogs();

    if (_dailyQuizDone) throw Exception('Quiz already done');

    _dailyQuizDone = true;
    if (isCorrect) _points += 10;

    await _updateStreak();
    await _saveUserData(); // Triggers Cloud Sync
    notifyListeners();
  }

  // ─── INTERNAL LOGIC ───────────────────────────────────────────────

  /// [FIX 7] Renamed and updated to handle Daily Count Reset
  Future<void> _checkAndResetDailyLogs() async {
    if (_lastActiveDate != null) {
      final now = DateTime.now();
      final last = _lastActiveDate!;

      // Compare Date parts only (Year, Month, Day)
      bool isNewDay = now.year != last.year || 
                      now.month != last.month || 
                      now.day != last.day;

      if (isNewDay) {
        // It's a new day! Reset daily specific trackers.
        _dailyQuizDone = false;
        _dailyWatchedCount = 0; 
        
        // Note: We don't save immediately here. We wait for a user action
        // or a sync to save these new 0 values to the database.
      }
    }
  }

  Future<void> _updateStreak() async {
    final now = DateTime.now();
    
    if (_lastActiveDate == null) {
      _dayStreak = 1;
      _lastActiveDate = now;
      return;
    }

    final last = _lastActiveDate!;
    final dateNow = DateTime(now.year, now.month, now.day);
    final dateLast = DateTime(last.year, last.month, last.day);

    final diff = dateNow.difference(dateLast).inDays;

    if (diff == 0) {
       // Same day, update timestamp but keep streak
       _lastActiveDate = now;
       return; 
    }

    if (diff == 1) {
      _dayStreak++; // Consecutive day
    } else {
      _dayStreak = 1; // Streak broken (diff > 1)
    }
    
    _lastActiveDate = now;
  }

  Map<DateTime, bool> getStreakCalendar() {
    final calendar = <DateTime, bool>{};
    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      calendar[date] = i < _dayStreak;
    }
    return calendar;
  }
}