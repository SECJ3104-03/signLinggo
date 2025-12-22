// lib/data/adaptive_quiz_generator.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_repository.dart';
import 'quiz_questions.dart';
import 'progress_manager.dart';

class AdaptiveQuizGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SignRepository _signRepository = SignRepository();

  /// Generate adaptive quiz questions following learning stages
  Future<List<QuizQuestion>> generateAdaptiveQuiz({
    required String userId,
    int numberOfQuestions = 10,
    String? forceCategory, // Optional: override for testing
  }) async {
    try {
      // 1. Fetch user's progress
      final userProgress = await _getUserProgress(userId);
      final learnedSignIds = userProgress['learnedSignIds'] as List<dynamic>? ?? [];
      final masteryScores = Map<String, int>.from(userProgress['masteryScore'] as Map? ?? {});
      
      // 2. Get user's current learning stage
      // Note: In a real app, you might want to pass ProgressManager as a parameter
      // or use a singleton. For now, we'll fetch from Firestore directly.
      final stageInfo = await _getUserLearningStage(userId);
      final currentCategory = forceCategory ?? stageInfo['currentCategory'];
      
      // 3. Fetch all signs
      final allSigns = await _signRepository.getAllSigns();
      
      // 4. Categorize signs for current stage
      final List<Sign> stageSigns = [];
      final List<Sign> otherSigns = [];
      
      for (final sign in allSigns) {
        if (sign.category == currentCategory) {
          stageSigns.add(sign); // Signs from current learning stage
        } else {
          otherSigns.add(sign); // Other signs for variety
        }
      }
      
      // 5. Categorize stage signs by mastery
      final List<Sign> learnedStageSigns = [];
      final List<Sign> weakStageSigns = [];
      final List<Sign> newStageSigns = [];
      
      for (final sign in stageSigns) {
        if (learnedSignIds.contains(sign.id)) {
          final mastery = masteryScores[sign.id] ?? 0;
          if (mastery < 70) {
            weakStageSigns.add(sign);
          } else {
            learnedStageSigns.add(sign);
          }
        } else {
          newStageSigns.add(sign);
        }
      }
      
      // 6. Calculate distribution (80% from current stage, 20% from other stages for review)
      final int stageCount = (numberOfQuestions * 0.8).round();
      final int reviewCount = numberOfQuestions - stageCount;
      
      // 7. Select signs for quiz
      final List<Sign> selectedSigns = [];
      
      // Add signs from current learning stage (prioritize new and weak signs)
      final availableStageSigns = [...newStageSigns, ...weakStageSigns, ...learnedStageSigns];
      selectedSigns.addAll(_getRandomItems(availableStageSigns, _min(stageCount, availableStageSigns.length)));
      
      // If we need more signs from current stage, add any stage signs
      if (selectedSigns.length < stageCount) {
        final remaining = stageCount - selectedSigns.length;
        selectedSigns.addAll(_getRandomItems(stageSigns, remaining));
      }
      
      // Add review signs from other categories
      final reviewSigns = _selectReviewSigns(otherSigns, learnedSignIds, masteryScores, reviewCount);
      selectedSigns.addAll(reviewSigns);
      
      // Fill any remaining slots with random signs
      if (selectedSigns.length < numberOfQuestions) {
        final remaining = numberOfQuestions - selectedSigns.length;
        final allRemaining = allSigns.where((s) => !selectedSigns.contains(s)).toList();
        selectedSigns.addAll(_getRandomItems(allRemaining, remaining));
      }
      
      // 8. Generate quiz questions
      return await _generateQuestionsFromSigns(selectedSigns);
      
    } catch (e) {
      print('Error generating adaptive quiz: $e');
      return _getFallbackQuestions();
    }
  }

  /// Get user learning stage from Firestore
  Future<Map<String, dynamic>> _getUserLearningStage(String userId) async {
    try {
      final doc = await _firestore.collection('user_progress').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final dayStreak = data['dayStreak'] ?? 0;
        
        // Calculate stage based on day streak
        final stageLength = 5;
        final stageNumber = (dayStreak ~/ stageLength) + 1;
        final stageDay = (dayStreak % stageLength) + 1;
        
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
        
        // Cycle through categories if streak exceeds total categories
        final categoryIndex = (stageNumber - 1) % categories.length;
        final currentCategory = categories[categoryIndex];
        
        return {
          'currentCategory': currentCategory,
          'stageNumber': stageNumber,
          'stageDay': stageDay,
          'stageLength': stageLength,
        };
      }
    } catch (e) {
      print('Error getting user learning stage: $e');
    }
    
    // Default to first category if not found
    return {
      'currentCategory': 'Alphabet',
      'stageNumber': 1,
      'stageDay': 1,
      'stageLength': 5,
    };
  }

  /// Get user progress data
  Future<Map<String, dynamic>> _getUserProgress(String userId) async {
    final doc = await _firestore.collection('user_progress').doc(userId).get();
    if (doc.exists) {
      return doc.data()!;
    }
    return {};
  }

  /// Select review signs from other categories
  List<Sign> _selectReviewSigns(
    List<Sign> otherSigns,
    List<dynamic> learnedSignIds,
    Map<String, int> masteryScores,
    int count,
  ) {
    if (count <= 0) return [];
    
    final List<Sign> reviewSigns = [];
    
    // Prioritize signs that need review (learned but low mastery)
    final weakReviewSigns = otherSigns.where((sign) {
      if (!learnedSignIds.contains(sign.id)) return false;
      final mastery = masteryScores[sign.id] ?? 0;
      return mastery < 70;
    }).toList();
    
    reviewSigns.addAll(_getRandomItems(weakReviewSigns, _min(count, weakReviewSigns.length)));
    
    // If we need more review signs, add random learned signs
    if (reviewSigns.length < count) {
      final remaining = count - reviewSigns.length;
      final learnedReviewSigns = otherSigns.where((sign) => learnedSignIds.contains(sign.id)).toList();
      reviewSigns.addAll(_getRandomItems(learnedReviewSigns, _min(remaining, learnedReviewSigns.length)));
    }
    
    // If still not enough, add random signs from other categories
    if (reviewSigns.length < count) {
      final remaining = count - reviewSigns.length;
      reviewSigns.addAll(_getRandomItems(otherSigns, remaining));
    }
    
    return reviewSigns;
  }

  /// Sort signs by mastery (lower mastery first)
  List<Sign> _sortByMastery(List<Sign> signs, Map<String, int> masteryScores) {
    return signs..sort((a, b) {
      final masteryA = masteryScores[a.id] ?? 0;
      final masteryB = masteryScores[b.id] ?? 0;
      return masteryA.compareTo(masteryB); // Lower mastery first
    });
  }

  /// Select signs by difficulty distribution
  List<Sign> _selectByDifficulty(List<Sign> signs, int count) {
    if (signs.length <= count) return signs;
    
    // Categorize by difficulty
    final easy = signs.where((s) => s.difficulty <= 2).toList();
    final medium = signs.where((s) => s.difficulty == 3).toList();
    final hard = signs.where((s) => s.difficulty >= 4).toList();
    
    final List<Sign> selected = [];
    
    // Select 40% easy, 40% medium, 20% hard
    final int easyCount = (count * 0.4).round();
    final int mediumCount = (count * 0.4).round();
    final int hardCount = count - easyCount - mediumCount;
    
    selected.addAll(_getRandomItems(easy, easyCount));
    selected.addAll(_getRandomItems(medium, mediumCount));
    selected.addAll(_getRandomItems(hard, hardCount));
    
    // Fill remaining slots if any category is empty
    if (selected.length < count) {
      final remaining = count - selected.length;
      final allRemaining = signs.where((s) => !selected.contains(s)).toList();
      selected.addAll(_getRandomItems(allRemaining, remaining));
    }
    
    return selected;
  }

  /// Get random items from list
  List<Sign> _getRandomItems(List<Sign> list, int count) {
    if (list.isEmpty || count <= 0) return [];
    final shuffled = List<Sign>.from(list)..shuffle();
    return shuffled.take(count).toList();
  }

  /// Generate quiz questions from signs
  Future<List<QuizQuestion>> _generateQuestionsFromSigns(List<Sign> signs) async {
    final List<QuizQuestion> questions = [];
    
    for (final sign in signs) {
      // Get similar signs for options (same category, different signs)
      final similarSigns = await _signRepository.getSignsByCategory(sign.category);
      final otherSigns = similarSigns.where((s) => s.id != sign.id).toList();
      
      // Create 4 options (1 correct + 3 similar)
      final options = <String>[sign.translations['en'] ?? sign.description];
      
      for (int i = 0; i < 3 && i < otherSigns.length; i++) {
        options.add(otherSigns[i].translations['en'] ?? otherSigns[i].description);
      }
      
      // Shuffle options
      options.shuffle();
      final correctIndex = options.indexOf(sign.translations['en'] ?? sign.description);
      
      // Create question
      questions.add(QuizQuestion(
        question: 'What is the sign for "${sign.translations['en'] ?? sign.description}"?',
        options: options,
        correctAnswerIndex: correctIndex,
        explanation: sign.description,
        category: sign.category,
        signId: sign.id,
      ));
    }
    
    return questions;
  }

  /// Fallback questions if adaptive generation fails
  List<QuizQuestion> _getFallbackQuestions() {
    // Return random questions from your existing QuizRepository
    final allQuestions = QuizRepository.allQuestions;
    allQuestions.shuffle();
    return allQuestions.take(10).toList();
  }

  // Helper method for min since we can't import dart:math without conflict
  int _min(int a, int b) => a < b ? a : b;
}