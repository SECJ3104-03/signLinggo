/// Landing Screen
/// 
/// First-time user onboarding screen with:
/// - Three-page introduction to app features
/// - Skip functionality
/// - Navigation to sign-in after completion
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> pages = [
    {
      "title": "Understand Sign Language Instantly",
      "desc":
          "Our AI-powered technology recognizes Malaysian Sign Language (BIM) in real-time.",
      "icon": Icons.pan_tool_rounded,
      "colors": [Color(0xFFFF5F6D), Color(0xFFFFC371)],
    },
    {
      "title": "Translate Signs to Voice",
      "desc":
          "Convert sign language to text or speech effortlessly for seamless communication.",
      "icon": Icons.chat_bubble_outline_rounded,
      "colors": [Color(0xFF36D1DC), Color(0xFF5B86E5)],
    },
    {
      "title": "Communicate Effortlessly",
      "desc":
          "Bridge the gap between the deaf community and non-signers with ease.",
      "icon": Icons.people_alt_outlined,
      "colors": [Color(0xFFFF8008), Color(0xFFFFC837)],
    },
  ];

  /// Complete onboarding and navigate to sign-in
  Future<void> _finishOnboarding() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.completeOnboarding();
    if (!mounted) return;
    context.go('/signin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _controller,
        itemCount: pages.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          final page = pages[index];
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page["colors"],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip button
                    Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: _finishOnboarding,
                        child: const Text(
                          "Skip",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),

                    // Icon + text
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page["icon"],
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page["title"],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page["desc"],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),

                    // Bottom section
                    Column(
                      children: [
                        // Page indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            pages.length,
                            (dotIndex) => Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              width: _currentPage == dotIndex ? 14 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPage == dotIndex
                                    ? Colors.white
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Button
                        GestureDetector(
                          onTap: () {
                            if (_currentPage == pages.length - 1) {
                              _finishOnboarding();
                            } else {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == pages.length - 1
                                        ? "Get Started"
                                        : "Next",
                                    style: const TextStyle(
                                      color: Color(0xFF980FFA),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_currentPage != pages.length - 1)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Color(0xFF980FFA),
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
