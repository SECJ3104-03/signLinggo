/// Categories Screen
/// 
/// Displays sign language categories for browsing:
/// - Category grid with icons
/// - Navigation to category detail pages
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> categories = [
      {'title': 'Alphabet', 'icon': 'assets/icons/alphabet.png'},
      {'title': 'Greetings', 'icon': 'assets/icons/greetings.png'},
      {'title': 'Emotions', 'icon': 'assets/icons/emotions.png'},
      {'title': 'Travel', 'icon': 'assets/icons/travel.png'},
      {'title': 'Numbers', 'icon': 'assets/icons/numbers.png'},
      {'title': 'Medical', 'icon': 'assets/icons/medical.png'},
      {'title': 'Food & Drinks', 'icon': 'assets/icons/food.png'},
      {'title': 'Family', 'icon': 'assets/icons/family.png'},
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5CFFF), Color(0xFFFAD1E3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
             Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        // Use pop if there's a route to pop, otherwise go to home
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                    const Expanded(
                      child: Text(
                        "Categories",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontFamily: 'Roboto Serif',
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Category grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryDetailPage(title: cat['title']!),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0C0ABD)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(cat['icon']!),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat['title']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                              fontFamily: 'Roboto Serif',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom navigation bar
              Container(
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8DC5FF), Color(0xFFAC46FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.home, color: Colors.white),
                    Icon(Icons.menu_book, color: Colors.white),
                    Icon(Icons.chat, color: Colors.white),
                    Icon(Icons.person, color: Colors.white),
                    Icon(Icons.settings, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryDetailPage extends StatelessWidget {
  final String title;
  const CategoryDetailPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text("This is the $title page."),
      ),
    );
  }
}
