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
    _dailyQuizDone = data['dailyQuizDone'] ?? false;
    _points = data['points'] ?? 0;

    // Handle both old 'watchedVideos' and new 'learnedSignIds'
    List<String> loadedSigns = [];
    if (data['learnedSignIds'] != null) {
      loadedSigns = List<String>.from(data['learnedSignIds']);
    } else if (data['watchedVideos'] != null) {
      loadedSigns = List<String>.from(data['watchedVideos']);
    }
    _watchedVideos = Set<String>.from(loadedSigns);

    // Handle Timestamps
    final lastActiveVal = data['lastAccessed'] ?? data['lastActiveDate'];
    if (lastActiveVal != null) {
      if (lastActiveVal is Timestamp) {
        _lastActiveDate = lastActiveVal.toDate();
      } else if (lastActiveVal is String) {
        _lastActiveDate = DateTime.tryParse(lastActiveVal);
      }
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
      'lastAccessed': FieldValue.serverTimestamp(),
      
      // Keep these for app logic
      'points': _points,
      'dayStreak': _dayStreak,
      'dailyQuizDone': _dailyQuizDone,
      'dailyWatchedCount': _dailyWatchedCount,
      'totalWatched': _totalWatched,
    };

    // Save Local
    final localData = Map<String, dynamic>.from(progressData);
    localData['lastAccessed'] = DateTime.now().toIso8601String();
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
    if (_dailyQuizDone) throw Exception('Quiz already done');

    _dailyQuizDone = true;
    if (isCorrect) _points += 10;

    await _updateStreak();
    await _saveUserData(); 
    notifyListeners();
  }

  /// Fetches ALL users from 'user_progress' sorted by points
  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final snapshot = await _firestore
          .collection('user_progress') // Queries the new clean collection
          .orderBy('points', descending: true)
          // .limit(20) // <--- REMOVED or INCREASED this limit
          .limit(100)   // Now fetches top 100 users. Change to 1000 if needed.
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

  // ─── HELPERS ───────────────────────────────────────────────────────

  Future<void> _checkAndResetDailyLogs() async {
    if (_lastActiveDate != null) {
      final now = DateTime.now();
      final last = _lastActiveDate!;
      bool isNewDay = now.year != last.year || now.month != last.month || now.day != last.day;
      if (isNewDay) {
        _dailyQuizDone = false;
        _dailyWatchedCount = 0; 
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

    if (diff == 0) { _lastActiveDate = now; return; }
    if (diff == 1) { _dayStreak++; } else { _dayStreak = 1; }
    _lastActiveDate = now;
  }
  
  Map<DateTime, bool> getStreakCalendar() {
    final calendar = <DateTime, bool>{};
    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      calendar[now.subtract(Duration(days: i))] = i < _dayStreak;
    }
    return calendar;
  }
}