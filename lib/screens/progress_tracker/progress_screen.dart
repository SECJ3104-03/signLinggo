/// Progress Tracker Screen
/// 
/// Displays user learning progress including:
/// - Total signs learned
/// - Daily, weekly, and monthly goals
/// - Achievement badges
/// - Learning statistics
import 'package:flutter/material.dart';
import '../../data/progress_manager.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  // Example total counts for goals (adjust to match your LearnModePage data)
  final int totalSigns = 100; // total signs available
  final int dailyGoal = 10;
  final int weeklyGoal = 50;
  final int monthlyGoal = 300;

  @override
  Widget build(BuildContext context) {
    final progressManager = ProgressManager();
    final totalWatched = progressManager.totalWatched;

    // Compute dynamic progress for goals
    final dailyProgress = (totalWatched % dailyGoal) / dailyGoal;
    final weeklyProgress =
        (totalWatched % weeklyGoal) / weeklyGoal; // simple modulo example
    final monthlyProgress = totalWatched / monthlyGoal;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            // Navigation handled by GoRouter
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Progress Tracker',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Stats ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                  value: '12', // could be dynamic daily streak
                  label: 'Day Streak',
                ),
                const SizedBox(width: 8),
                _StatCard(
                  color: const Color(0xFF00C389),
                  icon: '✅',
                  value: '85%', // could be dynamic quiz score
                  label: 'Quiz Score',
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
                  const Text('Achievements',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _AchievementDot(
                          icon: '🎯', label: 'First Sign', completed: totalWatched >= 1),
                      _AchievementDot(
                          icon: '🔥', label: 'Week Streak', completed: false),
                      _AchievementDot(
                          icon: '⭐', label: '50 Signs', completed: totalWatched >= 50),
                      _AchievementDot(
                          icon: '💎', label: '100 Signs', completed: totalWatched >= 100),
                      _AchievementDot(
                          icon: '👑', label: 'Master', completed: totalWatched >= totalSigns),
                    ],
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
              child: const Text(
                '"Keep going! You\'re making amazing progress! 💪"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────
// Reuse your existing widgets
// ──────────────────────────────
class _StatCard extends StatelessWidget {
  final Color color;
  final String icon;
  final String value;
  final String label;
  const _StatCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 140,
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
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
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
