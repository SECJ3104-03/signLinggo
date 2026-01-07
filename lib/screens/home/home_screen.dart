library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:signlinggo/widgets/pressable_scale.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    const headerHeight = 70.0;

    return Scaffold(
      body: Stack(
        children: [
          // ================= SCROLLABLE CONTENT =================
          SingleChildScrollView(
            padding: EdgeInsets.only(top: headerHeight + topPadding),
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
                  const SizedBox(height: 16),

                  // ================= MAIN BODY =================
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

                  const SizedBox(height: 16),

                  // ================= OFFLINE MODE =================
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: PressableScale(
                        onTap: () => context.push('/offline'),
                        child: Container(
                          height: 68,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF615EFF),
                                Color(0xFFAC46FF),
                                Color(0xFFF6329A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 8,
                                offset: Offset(0, 6),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.cloud_download,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Offline Mode',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontFamily: 'Arimo',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================= PINNED HEADER =================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: headerHeight + topPadding,
              padding: EdgeInsets.only(
                top: topPadding,
                left: 24,
                right: 24,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Signlingo Home',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF101727),
                    ),
                  ),

                  // ================= PROFILE IMAGE =================
                  PressableScale(
                    onTap: () => context.push('/profile'),
                    child: _HomeProfileAvatar(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= CARD BUILDER =================
  static Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradientColors,
    VoidCallback? onTap,
  }) {
    return PressableScale(
      onTap: onTap ?? () {},
      child: Container(
        width: 160,
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x99FFFEFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF101727),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF495565),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= PROFILE AVATAR WIDGET =================
class _HomeProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _defaultAvatar();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        String? url;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          url = data['profileUrl']?.toString();
        }

        url ??= user.photoURL;

        if (url == null || url.isEmpty) {
          return _defaultAvatar();
        }

        return Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => _defaultAvatar(),
            ),
          ),
        );
      },
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFF615EFF),
            Color(0xFFAC46FF),
            Color(0xFFF6329A),
          ],
        ),
      ),
      child: const Icon(Icons.person, color: Colors.white),
    );
  }
}
