// lib/data/adaptive_quiz_generator.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_repository.dart';
import 'quiz_questions.dart';

class AdaptiveQuizGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SignRepository _signRepository = SignRepository();

  /// Generate adaptive quiz questions
  Future<List<QuizQuestion>> generateAdaptiveQuiz({
    required String userId,
    int numberOfQuestions = 10,
  }) async {
    try {
      // 1. Fetch user's progress
      final userProgress = await _getUserProgress(userId);
      final learnedSignIds = userProgress['learnedSignIds'] as List<dynamic>? ?? [];
      final masteryScores = Map<String, int>.from(userProgress['masteryScore'] as Map? ?? {});
      
      // 2. Fetch all signs
      final allSigns = await _signRepository.getAllSigns();
      
      // 3. Categorize signs
      final List<Sign> learnedSigns = [];
      final List<Sign> weakSigns = [];
      final List<Sign> newSigns = [];
      
      for (final sign in allSigns) {
        if (learnedSignIds.contains(sign.id)) {
          // Check mastery score
          final mastery = masteryScores[sign.id] ?? 0;
          if (mastery < 70) {
            weakSigns.add(sign); // Weak signs (learned but low mastery)
          } else {
            learnedSigns.add(sign); // Well-learned signs
          }
        } else {
          newSigns.add(sign); // New signs
        }
      }
      
      // 4. Calculate distribution (70% learned, 30% weak/new)
      final int learnedCount = (numberOfQuestions * 0.7).round();
      final int weakNewCount = numberOfQuestions - learnedCount;
      
      // 5. Select signs for quiz
      final List<Sign> selectedSigns = [];
      
      // Add learned signs (prioritize lower mastery first)
      final sortedLearned = _sortByMastery(learnedSigns, masteryScores);
      selectedSigns.addAll(sortedLearned.take(learnedCount).toList());
      
      // Add weak/new signs
      final availableWeakNew = [...weakSigns, ...newSigns];
      selectedSigns.addAll(_selectByDifficulty(availableWeakNew, weakNewCount));
      
      // 6. Generate quiz questions
      return await _generateQuestionsFromSigns(selectedSigns);
      
    } catch (e) {
      print('Error generating adaptive quiz: $e');
      return _getFallbackQuestions();
    }
  }

  /// Get user progress data
  Future<Map<String, dynamic>> _getUserProgress(String userId) async {
    final doc = await _firestore.collection('user_progress').doc(userId).get();
    if (doc.exists) {
      return doc.data()!;
    }
    return {};
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
}