// screens/daily_quiz/daily_quiz_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/progress_manager.dart';
import '../../data/quiz_questions.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDailyQuestion();
  }

  void _loadDailyQuestion() {
    setState(() {
      _currentQuestion = QuizRepository.getRandomQuestion();
      _selectedAnswerIndex = null;
      _answerSubmitted = false;
      _showResult = false;
      _isCorrect = false;
    });
  }

  void _selectAnswer(int index) {
    if (_answerSubmitted) return;
    
    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswerIndex == null || _answerSubmitted) return;
    
    setState(() {
      _answerSubmitted = true;
      _isCorrect = _selectedAnswerIndex == _currentQuestion!.correctAnswerIndex;
    });
    
    // Wait 1.5 seconds before showing result
    await Future.delayed(const Duration(milliseconds: 1500));
    
    setState(() {
      _showResult = true;
    });
    
    // Complete the quiz in progress manager
    final progressManager = context.read<ProgressManager>();
    try {
      await progressManager.completeDailyQuiz(isCorrect: _isCorrect);
    } catch (e) {
      // Show error if quiz already completed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    
    // Check if quiz already completed today
    if (progressManager.dailyQuizDone && _currentQuestion == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAlreadyCompletedDialog();
      });
    }

    if (_currentQuestion == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
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
          ? _buildResultScreen()
          : _buildQuizScreen(),
    );
  }

  Widget _buildQuizScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak and progress indicator
          _buildQuizHeader(),
          
          const SizedBox(height: 24),
          
          // Category badge
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
          
          // Question
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question:',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentQuestion!.question,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Options
          Text(
            'Select your answer:',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                _answerSubmitted
                    ? 'Checking Answer...'
                    : _selectedAnswerIndex == null
                        ? 'Select an answer to submit'
                        : 'Submit Answer',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, String option) {
    final bool isSelected = _selectedAnswerIndex == index;
    final bool isCorrect = index == _currentQuestion!.correctAnswerIndex;
    
    Color backgroundColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.black87;
    
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
                  width: 32,
                  height: 32,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
                
                // Selection indicator
                if (isSelected && !_answerSubmitted)
                  Icon(
                    Icons.check_circle,
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                
                // Result indicator
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

  Widget _buildQuizHeader() {
    final progressManager = context.watch<ProgressManager>();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Streak
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${progressManager.dayStreak} Day Streak',
                style: const TextStyle(
                  color: Colors.orange,
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
          ),
          child: Row(
            children: [
              const Icon(
                Icons.star,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${progressManager.points} Points',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    final progressManager = context.watch<ProgressManager>();
    
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
              color: _isCorrect
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isCorrect ? Icons.check : Icons.close,
              size: 60,
              color: _isCorrect ? Colors.green : Colors.orange,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Result Text
          Text(
            _isCorrect ? 'Excellent! 🎉' : 'Almost There!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _isCorrect ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Points earned
          Text(
            _isCorrect ? '+10 Points Earned!' : 'No points this time',
            style: TextStyle(
              fontSize: 20,
              color: _isCorrect ? Colors.green.shade600 : Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Streak update
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              children: [
                Text(
                  'Your Streak:',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${progressManager.dayStreak} Days',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isCorrect
                      ? 'Keep it up! Come back tomorrow.'
                      : 'Try again tomorrow to continue!',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Explanation (if available)
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
          
          // Continue Button
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
                elevation: 2,
              ),
              child: const Text(
                'Back to Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Retry Button (for learning purposes)
          if (!_isCorrect)
            TextButton(
              onPressed: () {
                _loadDailyQuestion();
              },
              child: const Text(
                'Try Another Question',
                style: TextStyle(fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Greetings':
        return Icons.waving_hand;
      case 'Numbers':
        return Icons.numbers;
      case 'Family':
        return Icons.family_restroom;
      case 'Food & Drink':
        return Icons.restaurant;
      case 'Emotions':
        return Icons.emoji_emotions;
      case 'Time':
        return Icons.access_time;
      case 'Colors':
        return Icons.color_lens;
      case 'Animals':
        return Icons.pets;
      default:
        return Icons.quiz;
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

  void _showAlreadyCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Quiz Already Completed'),
          ],
        ),
        content: const Text(
          'You have already completed today\'s quiz. '
          'Come back tomorrow for a new challenge!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _returnToProgress();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}