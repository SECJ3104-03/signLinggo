/// Home Screen
/// 
/// Main navigation hub displaying:
/// - Feature cards for different app modules
/// - Quick access to all major features
/// - Offline mode availability indicator
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0.00, 0.00),
              end: Alignment(1.00, 1.00),
              colors: [
                Color(0xFFF2E7FE),
                Color(0xFFFCE6F3),
                Color(0xFFFFECD4),
              ],
            ),
          ),
          child: Column(
            children: [
              // === TOP BAR ===
              Container(
                width: double.infinity,
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.80),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                      spreadRadius: -1,
                    ),
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Signlingo Home',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF101727),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // === MAIN BODY ===
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildCard(
                      icon: Icons.camera, 
                      title: "Real-Time Sign Recognition", 
                      description: 'Translate BIM gesture instantly',
                      gradientColors: const [
                        Color(0xFF00C850),
                        Color(0xFF00BC7C),
                        Color(0xFF00BBA6),
                      ],
                      onTap: () => context.push('/sign-recognition'),
                    ),
                    _buildCard(
                      icon: Icons.record_voice_over,
                      title: 'Voice/Text to Sign',
                      description: 'Convert speech to sign language',
                      gradientColors: const [
                        Color(0xFFAC46FF),
                        Color(0xFFF6329A),
                        Color(0xFFFF1F56),
                      ],
                      onTap: () => context.push('/text-to-sign'),
                    ),
                    _buildCard(
                      icon: Icons.menu_book,
                      title: 'Learn Mode',
                      description: 'Explore sign language dictionary',
                      gradientColors: const [
                        Color(0xFF00C850),
                        Color(0xFF00BC7C),
                        Color(0xFF00BBA6),
                      ],
                      onTap: () => context.push('/learning'),
                    ),
                    _buildCard(
                      icon: Icons.chat_bubble,
                      title: 'Conversation Mode',
                      description: 'Real-time two-way chat',
                      gradientColors: const [
                        Color(0xFFFF6800),
                        Color(0xFFFD9900),
                        Color(0xFFF0B000),
                      ],
                      onTap: () => context.push('/conversation'),
                    ),
                    _buildCard(
                      icon: Icons.show_chart,
                      title: 'Progress Tracker',
                      description: 'Track your learning journey',
                      gradientColors: const [
                        Color(0xFFF6329A),
                        Color(0xFFE12AFB),
                        Color(0xFFAC46FF),
                      ],
                      onTap: () => context.push('/progress'),
                    ),
                    _buildCard(
                      icon: Icons.people,
                      title: 'Community Hub',
                      description: 'Connect and share experiences',
                      gradientColors: const [
                        Color(0xFF00B8DA),
                        Color(0xFF00A5F4),
                        Color(0xFF2B7FFF),
                      ],
                      onTap: () => context.push('/community'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // === FOOTER ===
              Container(
                width: double.infinity,
                height: 91.95,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(0.00, 0.50),
                    end: Alignment(1.00, 0.50),
                    colors: [
                      Color(0xFF615EFF),
                      Color(0xFFAC46FF),
                      Color(0xFFF6329A),
                    ],
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 6,
                      offset: Offset(0, 4),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 15,
                      offset: Offset(0, 10),
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 47.99,
                      height: 47.99,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.cloud_download, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Offline Mode Available',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Arimo',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            'Download signs for offline use',
                            style: TextStyle(
                              color: Color(0xCCFFFEFE),
                              fontSize: 14,
                              fontFamily: 'Arimo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Reusable card builder =====
  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradientColors,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0x99FFFEFE)),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF101727),
              fontSize: 16,
              fontFamily: 'Arimo',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF495565),
              fontSize: 14,
              fontFamily: 'Arimo',
            ),
          ),
        ],
      ),
      ),
    );
  }
}
