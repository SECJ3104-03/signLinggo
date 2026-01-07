import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/progress_manager.dart';
import '../../data/quiz_questions.dart';
import '../../data/adaptive_quiz_generator.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  QuizQuestion? _currentQuestion;
  int? _selectedAnswerIndex;
  bool _answerSubmitted = false;
  bool _showResult = false;
  bool _isCorrect = false;
  bool _isLoading = true;
  bool _quizCompletedToday = false;
  
  String? _currentSignId;
  DateTime? _questionStartTime;
  String? _currentStageCategory;
  int? _currentStageDay;
  int? _totalStageDays;
  int? _stageNumber;

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    final progressManager = context.read<ProgressManager>();
    
    setState(() {
      _isLoading = true;
    });

    // Check if user has already completed quiz today
    await progressManager.checkAndResetDailyLogs();
    
    if (progressManager.dailyQuizDone) {
      print('🎯 Quiz already completed today');
      setState(() {
        _quizCompletedToday = true;
        _isLoading = false;
      });
      return;
    }

    // Load daily question based on learning stage
    await _loadDailyQuestion();
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadDailyQuestion() async {
    final progressManager = context.read<ProgressManager>();
    
    // Reset state
    setState(() {
      _selectedAnswerIndex = null;
      _answerSubmitted = false;
      _showResult = false;
      _isCorrect = false;
      _currentSignId = null;
      _questionStartTime = DateTime.now();
      _currentStageCategory = null;
      _currentStageDay = null;
      _totalStageDays = null;
      _stageNumber = null;
    });

    // Get current learning stage
    final stageInfo = progressManager.getLearningStageInfo();
    final currentCategory = stageInfo['currentCategory'];
    final stageDay = stageInfo['stageDay'];
    final stageLength = stageInfo['stageLength'];
    final stageNumber = stageInfo['stageNumber'];
    
    print('🎯 Stage Info: $stageInfo');
    print('🎯 Current Category: $currentCategory');
    print('🎯 Stage Day: $stageDay/$stageLength');
    
    // Store stage info for UI
    setState(() {
      _currentStageCategory = currentCategory;
      _currentStageDay = stageDay;
      _totalStageDays = stageLength;
      _stageNumber = stageNumber;
    });

    // Get questions from current category
    final categoryQuestions = QuizRepository.getQuestionsByCategory(currentCategory);
    
    if (categoryQuestions.isEmpty) {
      print('⚠️ No questions for category $currentCategory, using fallback');
      // Fallback to Alphabet
      final fallbackQuestions = QuizRepository.getQuestionsByCategory('Alphabet');
      if (fallbackQuestions.isNotEmpty) {
        final randomQuestion = QuizRepository.getRandomQuestionByCategory('Alphabet');
        setState(() {
          _currentQuestion = randomQuestion;
          _currentSignId = _currentQuestion!.signId;
          _currentStageCategory = 'Alphabet';
          _currentStageDay = 1;
          _totalStageDays = 5;
          _stageNumber = 1;
        });
      } else {
        // Ultimate fallback
        setState(() {
          _currentQuestion = QuizRepository.getRandomQuestion();
          _currentSignId = _currentQuestion?.signId;
        });
      }
    } else {
      // Use adaptive selection to prioritize new or weak signs
      final adaptiveQuestion = await _getAdaptiveQuestionFromCategory(
        progressManager,
        categoryQuestions,
        currentCategory,
        stageDay,
      );
      
      setState(() {
        _currentQuestion = adaptiveQuestion;
        _currentSignId = _currentQuestion!.signId;
      });
    }
    
    print('✅ Question loaded: ${_currentQuestion?.question}');
  }

  Future<QuizQuestion> _getAdaptiveQuestionFromCategory(
    ProgressManager progressManager,
    List<QuizQuestion> categoryQuestions,
    String currentCategory,
    int stageDay,
  ) async {
    try {
      // Get user's progress
      final userProgress = await progressManager.getUserProgressForQuiz();
      final learnedSignIds = List<String>.from(userProgress['learnedSignIds'] ?? []);
      final masteryScores = Map<String, int>.from(userProgress['masteryScore'] ?? {});
      
      // Categorize questions based on mastery
      final List<QuizQuestion> newQuestions = [];
      final List<QuizQuestion> weakQuestions = [];
      final List<QuizQuestion> learnedQuestions = [];
      
      for (final question in categoryQuestions) {
        if (learnedSignIds.contains(question.signId)) {
          final mastery = masteryScores[question.signId] ?? 0;
          if (mastery < 70) {
            weakQuestions.add(question);
          } else {
            learnedQuestions.add(question);
          }
        } else {
          newQuestions.add(question);
        }
      }
      
      // Priority order based on stage day
      List<QuizQuestion> priorityList = [];
      
      if (stageDay <= 2) {
        // Early in stage: focus on new signs
        priorityList = [...newQuestions, ...weakQuestions, ...learnedQuestions];
      } else if (stageDay <= 4) {
        // Middle of stage: balance new and weak
        priorityList = [...weakQuestions, ...newQuestions, ...learnedQuestions];
      } else {
        // End of stage: reinforce all
        priorityList = [...weakQuestions, ...learnedQuestions, ...newQuestions];
      }
      
      if (priorityList.isNotEmpty) {
        priorityList.shuffle();
        return priorityList.first;
      }
      
      // Fallback
      categoryQuestions.shuffle();
      return categoryQuestions.first;
      
    } catch (e) {
      print('Error in adaptive selection: $e');
      categoryQuestions.shuffle();
      return categoryQuestions.first;
    }
  }

  void _selectAnswer(int index) {
    if (_answerSubmitted || _quizCompletedToday) return;
    
    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswerIndex == null || _answerSubmitted || _quizCompletedToday) return;
    
    final progressManager = context.read<ProgressManager>();
    
    // Check again to prevent double submission
    if (progressManager.dailyQuizDone) {
      setState(() {
        _quizCompletedToday = true;
      });
      return;
    }
    
    // Calculate response time
    final endTime = DateTime.now();
    final responseTimeMs = _questionStartTime != null 
        ? endTime.difference(_questionStartTime!).inMilliseconds 
        : 0;

    setState(() {
      _answerSubmitted = true;
      _isCorrect = _selectedAnswerIndex == _currentQuestion!.correctAnswerIndex;
    });

    try {
      // 1. Log quiz attempt
      await progressManager.saveQuizAttempt(
        questionText: _currentQuestion!.question,
        signId: _currentSignId,
        isCorrect: _isCorrect,
        responseTimeMs: responseTimeMs,
      );
      
      // 2. Update mastery score
      if (_currentSignId != null) {
        await progressManager.updateMasteryScore(_currentSignId!, _isCorrect);
      }
      
      // 3. Complete daily quiz (this updates dailyQuizDone flag and totalActiveDays)
      await progressManager.completeDailyQuiz(isCorrect: _isCorrect);
      
      print('✅ Quiz completed successfully');
      
    } catch (e) {
      print('❌ Error in quiz submission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    // Show result after delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    setState(() {
      _showResult = true;
      _quizCompletedToday = true;
    });
  }

  void _returnToProgress() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/progress');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressManager = context.watch<ProgressManager>();
    
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    
    if (_quizCompletedToday && !_showResult) {
      return _buildAlreadyCompletedScreen();
    }
    
    if (_currentQuestion == null) {
      return _buildErrorScreen();
    }
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: _showResult
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: () {
                  if (!_answerSubmitted) {
                    _showExitConfirmation();
                  } else {
                    _returnToProgress();
                  }
                },
              ),
        title: Text(
          _showResult ? 'Quiz Result' : 'Daily Quiz',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _showResult
          ? _buildResultScreen(progressManager)
          : _buildQuizScreen(progressManager),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _returnToProgress,
        ),
        title: const Text(
          'Daily Quiz',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Loading your daily quiz...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyCompletedScreen() {
    final progressManager = context.read<ProgressManager>();
    final stageInfo = progressManager.getLearningStageInfo();
    final nextCategory = _getNextCategory(stageInfo['currentCategory']);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _returnToProgress,
        ),
        title: const Text(
          'Daily Quiz',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 30),
            const Text(
              'Quiz Completed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You have already completed today\'s quiz.\nCome back tomorrow!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            
            // Streak Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'Current Streak',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.orange.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${progressManager.dayStreak} Days',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Next Stage Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'Next Learning Stage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tomorrow: ${stageInfo['currentCategory']}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Day ${stageInfo['stageDay'] + 1}/${stageInfo['stageLength']}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.purple.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Return Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _returnToProgress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Return to Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _returnToProgress,
        ),
        title: const Text(
          'Daily Quiz',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 20),
              const Text(
                'Unable to Load Quiz',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'There was an error loading your daily quiz.\nPlease try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _initializeQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _returnToProgress,
                child: const Text('Return to Progress'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizScreen(ProgressManager progressManager) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with streak and points
          _buildQuizHeader(progressManager),
          
          // Stage Progress
          if (_currentStageCategory != null)
            _buildStageProgress(),
          
          const SizedBox(height: 20),
          
          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getCategoryIcon(_currentQuestion!.category),
                  size: 16,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentQuestion!.category,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Question Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Question:',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentQuestion!.question,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Options
          const Text(
            'Choose your answer:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          
          const SizedBox(height: 16),
          
          ..._currentQuestion!.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            
            return _buildOptionCard(index, option);
          }).toList(),
          
          const SizedBox(height: 32),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedAnswerIndex == null || _answerSubmitted
                  ? null
                  : _submitAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAnswerIndex == null 
                    ? Colors.grey.shade400 
                    : Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Text(
                _answerSubmitted
                    ? 'Checking Answer...'
                    : _selectedAnswerIndex == null
                        ? 'Select an Answer'
                        : 'Submit Answer',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Timer
          if (_questionStartTime != null && !_answerSubmitted)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Time: ${DateTime.now().difference(_questionStartTime!).inSeconds}s',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, String option) {
    final bool isSelected = _selectedAnswerIndex == index;
    final bool isCorrect = index == _currentQuestion!.correctAnswerIndex;
    
    Color backgroundColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    
    if (_answerSubmitted) {
      if (isCorrect) {
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
      }
    } else if (isSelected) {
      backgroundColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade400;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 2 : 1,
        child: InkWell(
          onTap: () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Option letter
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: TextStyle(
                        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Option text
                Expanded(
                  child: Text(
                    option,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
                
                // Selection/Result indicator
                if (isSelected && !_answerSubmitted)
                  Icon(
                    Icons.check_circle,
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                
                if (_answerSubmitted)
                  Icon(
                    isCorrect
                        ? Icons.check_circle
                        : (isSelected ? Icons.cancel : null),
                    color: isCorrect
                        ? Colors.green.shade600
                        : (isSelected ? Colors.red.shade600 : null),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizHeader(ProgressManager progressManager) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Streak
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${progressManager.dayStreak} Day Streak',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Points
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.green.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${progressManager.points} Points',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageProgress() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                size: 20,
                color: Colors.purple.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Stage $_stageNumber: $_currentStageCategory',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _currentStageDay! / _totalStageDays!,
                  backgroundColor: Colors.purple.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Day $_currentStageDay/$_totalStageDays',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Complete today\'s quiz to progress to next stage!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen(ProgressManager progressManager) {
    final stageInfo = progressManager.getLearningStageInfo();
    final nextCategory = _getNextCategory(stageInfo['currentCategory']);
    final daysRemaining = stageInfo['daysRemainingInStage'];
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Result Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _isCorrect ? Colors.green.shade100 : Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isCorrect ? Icons.check : Icons.close,
              size: 60,
              color: _isCorrect ? Colors.green.shade600 : Colors.orange.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Result Text
          Text(_isCorrect ? 'Excellent! 🎉' : 'Keep Learning!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _isCorrect ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Points earned
          Text(
            _isCorrect ? '+10 Points Earned!' : 'No points earned this time',
            style: TextStyle(
              fontSize: 20,
              color: _isCorrect ? Colors.green.shade600 : Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Stage Progress Update
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Column(
              children: [
                Text(
                  'Learning Progress Updated',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Stage $_stageNumber: $_currentStageCategory',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStageDay! + 1) / _totalStageDays!,
                  backgroundColor: Colors.purple.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  daysRemaining > 1
                      ? '${daysRemaining - 1} more days in this stage'
                      : 'Moving to $nextCategory tomorrow!',
                  style: TextStyle(
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Streak Update
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              children: [
                Text(
                  'Your Streak',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orange.shade700,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${progressManager.dayStreak} Days',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isCorrect
                      ? 'Come back tomorrow to continue your streak!'
                      : 'Try again tomorrow to build your streak!',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Explanation
          if (_currentQuestion!.explanation != null)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explanation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentQuestion!.explanation!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Return Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _returnToProgress,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Return to Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextCategory(String currentCategory) {
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
    
    final currentIndex = categories.indexOf(currentCategory);
    final nextIndex = (currentIndex + 1) % categories.length;
    return categories[nextIndex];
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Alphabet': return Icons.abc;
      case 'Greetings': return Icons.waving_hand;
      case 'Numbers': return Icons.numbers;
      case 'Family': return Icons.family_restroom;
      case 'Food & Drink': return Icons.restaurant;
      case 'Emotions': return Icons.emoji_emotions;
      case 'Time': return Icons.access_time;
      case 'Colors': return Icons.color_lens;
      case 'Animals': return Icons.pets;
      default: return Icons.quiz;
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text('Your progress will not be saved. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _returnToProgress();
            },
            child: const Text(
              'Exit',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}