// screens/progress_tracker/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/progress_manager.dart';
import '../../data/quiz_questions.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
  }

  // Example total counts for goals
  final int totalSigns = 100;
  final int dailyGoal = 10;
  final int weeklyGoal = 50;
  final int monthlyGoal = 300;

  @override
  Widget build(BuildContext context) {
    final progressManager = context.watch<ProgressManager>();
    final totalWatched = progressManager.totalWatched;
    final dayStreak = progressManager.dayStreak;
    final userPoints = progressManager.points;
    final dailyQuizDone = progressManager.dailyQuizDone;
    final streakCalendar = progressManager.getStreakCalendar();

    // Compute progress for goals
    final dailyProgress = (totalWatched % dailyGoal) / dailyGoal;
    final weeklyProgress = (totalWatched % weeklyGoal) / weeklyGoal;
    final monthlyProgress = totalWatched / monthlyGoal;

    // Calculate quiz score percentage
    final quizScorePercentage = totalWatched > 0 
        ? ((userPoints / (totalWatched * 10)) * 100).clamp(0, 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          'Progress Tracker',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          Consumer<ProgressManager>(
      builder: (context, progressManager, child) {
        if (progressManager.isSignedIn && progressManager.userName != null) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              radius: 16,
              child: Text(
                progressManager.userName!.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
        return const SizedBox(); // Don't show anything if not signed in
      },
    ),
          IconButton(
            icon: Badge(
              smallSize: 8,
              isLabelVisible: !dailyQuizDone,
              backgroundColor: Colors.red,
              child: Icon(
                dailyQuizDone ? Icons.quiz : Icons.quiz_outlined,
                color: dailyQuizDone ? Colors.grey : Colors.blueAccent,
              ),
            ),
            onPressed: dailyQuizDone
                ? null
                : () => _showDailyQuizDialog(context),
            tooltip: dailyQuizDone ? 'Quiz Completed Today' : 'Take Daily Quiz',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Daily Quiz Banner ──
            if (!dailyQuizDone)
              _DailyQuizBanner(
                dayStreak: dayStreak,
                onTap: () => _showDailyQuizDialog(context),
              ),

            const SizedBox(height: 20),

            // ── Top Stats ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 8),
                _StatCard(
                  color: const Color(0xFF1AB0E6),
                  icon: '🎯',
                  value: '$totalWatched',
                  label: 'Signs Learned',
                ),
                const SizedBox(width: 8),
                _StatCard(
                  color: const Color(0xFFFF6B6B),
                  icon: '🔥',
                  value: '$dayStreak',
                  label: 'Day Streak',
                  subtitle: dailyQuizDone ? 'Completed' : 'Pending',
                ),
                const SizedBox(width: 8),
                _StatCard(
                  color: const Color(0xFF00C389),
                  icon: '✅',
                  value: '$quizScorePercentage%',
                  label: 'Quiz Score',
                  subtitle: '$userPoints Points',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Learning Goals ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.circle_outlined, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text('Learning Goals',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GoalRow(
                    title: 'Daily Goal (${totalWatched % dailyGoal}/$dailyGoal signs)',
                    percentLabel: '${(dailyProgress * 100).toStringAsFixed(0)}%',
                    progress: dailyProgress,
                  ),
                  const SizedBox(height: 12),
                  _GoalRow(
                    title: 'Weekly Goal (${totalWatched % weeklyGoal}/$weeklyGoal signs)',
                    percentLabel: '${(weeklyProgress * 100).toStringAsFixed(0)}%',
                    progress: weeklyProgress,
                  ),
                  const SizedBox(height: 12),
                  _GoalRow(
                    title: 'Monthly Goal ($totalWatched/$monthlyGoal signs)',
                    percentLabel: '${(monthlyProgress * 100).toStringAsFixed(0)}%',
                    progress: monthlyProgress > 1 ? 1 : monthlyProgress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Streak Calendar ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '30-Day Streak Calendar',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: 30,
                    itemBuilder: (context, index) {
                      final dateKey = streakCalendar.keys.elementAt(index);
                      final hasActivity = streakCalendar[dateKey] ?? false;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: hasActivity ? Colors.green.shade300 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: hasActivity ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Achievements ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Achievements',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  
                  // FIX: Wrapped Row in FittedBox to prevent overflow
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _AchievementDot(
                            icon: '🎯', label: 'First Sign', completed: totalWatched >= 1),
                        const SizedBox(width: 8), // Optional spacing
                        _AchievementDot(
                            icon: '🔥', label: 'Week Streak', completed: dayStreak >= 7),
                        const SizedBox(width: 8),
                        _AchievementDot(
                            icon: '⭐', label: '50 Signs', completed: totalWatched >= 50),
                        const SizedBox(width: 8),
                        _AchievementDot(
                            icon: '💎', label: '100 Signs', completed: totalWatched >= 100),
                        const SizedBox(width: 8),
                        _AchievementDot(
                            icon: '👑', label: 'Master', completed: totalWatched >= totalSigns),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Quiz Status ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dailyQuizDone ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dailyQuizDone ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    dailyQuizDone ? Icons.check_circle : Icons.access_time,
                    color: dailyQuizDone ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dailyQuizDone ? 'Daily Quiz Completed!' : 'Daily Quiz Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: dailyQuizDone ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dailyQuizDone 
                            ? 'Great job! Your $dayStreak-day streak continues.'
                            : 'Take today\'s quiz to earn points and continue your streak!',
                          style: TextStyle(
                            color: dailyQuizDone ? Colors.green.shade600 : Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ── Motivational Message ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBF5FF), Color(0xFFF0F7FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    dayStreak >= 7
                      ? '🔥 Amazing ${dayStreak}-day streak! You\'re on fire!'
                      : dayStreak >= 3
                        ? '💪 Keep it up! ${dayStreak} days in a row!'
                        : '"Keep going! You\'re making amazing progress! 💪"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showDailyQuizDialog(BuildContext context) {
  final progressManager = context.read<ProgressManager>();
  final quizQuestion = QuizRepository.getRandomQuestion(); // Fixed: Use QuizRepository
  
  if (progressManager.dailyQuizDone) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have already completed today\'s quiz!'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  int? selectedIndex;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Quiz',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(quizQuestion.category),
                backgroundColor: Colors.blue.shade50,
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  quizQuestion.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Quiz Options
                ...quizQuestion.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selectedIndex == index 
                          ? Colors.blue 
                          : Colors.grey.shade300,
                        width: selectedIndex == index ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      title: Text(option),
                      leading: Radio<int>(
                        value: index,
                        groupValue: selectedIndex,
                        onChanged: (value) {
                          setState(() {
                            selectedIndex = value;
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedIndex == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      _completeQuiz(
                        context, 
                        selectedIndex == quizQuestion.correctAnswerIndex
                      );
                    },
              child: const Text('Submit Answer'),
            ),
          ],
        );
      },
    ),
  );
}

  void _completeQuiz(BuildContext context, bool isCorrect) {
    final progressManager = context.read<ProgressManager>();
    
    try {
      progressManager.completeDailyQuiz(isCorrect: isCorrect);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCorrect
              ? '✅ Correct! +10 points and streak continued!'
              : '❌ Incorrect. Try again tomorrow to continue streak!',
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ──────────────────────────────
// Supporting Widgets
// ──────────────────────────────

class _DailyQuizBanner extends StatelessWidget {
  final int dayStreak;
  final VoidCallback onTap;

  const _DailyQuizBanner({
    required this.dayStreak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1AB0E6), Color(0xFF0066FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.quiz, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Quiz Available!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete today\'s quiz to continue your $dayStreak-day streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Take Quiz'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color color;
  final String icon;
  final String value;
  final String label;
  final String? subtitle;
  
  const _StatCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 120), // Changed from fixed height
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(1.0), color.withOpacity(0.75)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String title;
  final String percentLabel;
  final double progress;
  const _GoalRow({
    required this.title,
    required this.percentLabel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            Text(percentLabel,
                style: const TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress > 1 ? 1 : progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87),
          ),
        ),
      ],
    );
  }
}

class _AchievementDot extends StatelessWidget {
  final String icon;
  final String label;
  final bool completed;
  const _AchievementDot({
    required this.icon,
    required this.label,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = completed ? Colors.yellow.shade100 : Colors.grey.shade200;
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: bg,
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 64,
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      ],
    );
  }
}