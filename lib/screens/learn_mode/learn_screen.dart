/// Learn Mode Screen
/// 
/// Displays sign language learning content with:
/// - Category filtering
/// - Search functionality
/// - Video playback for each sign
/// - Progress tracking integration
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../data/progress_manager.dart';

class LearnModePage extends StatefulWidget {
  const LearnModePage({super.key});

  @override
  State<LearnModePage> createState() => _LearnModePageState();
}

class _LearnModePageState extends State<LearnModePage> {
  final List<String> categories = [
    'All', 'Alphabets', 'Numbers', 'Greetings', 'Family',
    'Food & Drinks', 'Emotions', 'Travel', 'Medical', 'Others',
  ];

  String selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  // ✅ Example: Add video file names matching sign titles
    final List<Map<String, String>> signs = [
    //food and drinks
    {'title': 'Bread', 'category': 'Food & Drinks', 'difficulty': 'Easy'},
    {'title': 'Drink', 'category': 'Food & Drinks', 'difficulty': 'Easy'},
    {'title': 'Eat', 'category': 'Food & Drinks', 'difficulty': 'Easy'},
    {'title': 'Water', 'category': 'Food & Drinks', 'difficulty': 'Easy'},
    //family
    {'title': 'Brother', 'category': 'Family', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Brother.mp4'},
    {'title': 'Elder Sister', 'category': 'Family', 'difficulty': 'Medium', 'video': 'assets/assets/videos/ElderSister.mp4'},
    {'title': 'Father', 'category': 'Family', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Father.mp4'},
    {'title': 'Mother', 'category': 'Family', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Mother.mp4'},
    //travel
    {'title': 'Bus', 'category': 'Travel', 'difficulty': 'Medium'},
    {'title': 'Hotel', 'category': 'Travel', 'difficulty': 'Medium'},
    {'title': 'Toilet', 'category': 'Travel', 'difficulty': 'Medium'},
    //emotions
    {'title': 'Help', 'category': 'Emotions', 'difficulty': 'Medium'},
    {'title': 'Hungry', 'category': 'Emotions', 'difficulty': 'Medium'},
    {'title': 'Thirsty', 'category': 'Emotions', 'difficulty': 'Medium'},
    //others
    {'title': 'Objects', 'category': 'Others', 'difficulty': 'Medium'},
    //numbers
    {'title': '0', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/0.mp4'},
    {'title': '1', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/1.mp4'},
    {'title': '2', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/2.mp4'},
    {'title': '3', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/3.mp4'},
    {'title': '4', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/4.mp4'},
    {'title': '5', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/5.mp4'},
    {'title': '6', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/6.mp4'},
    {'title': '7', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/7.mp4'},
    {'title': '8', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/8.mp4'},
    {'title': '9', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/9.mp4'},
    {'title': '10', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/10.mp4'},
    //alphabets
    {'title': 'A', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/A.mp4'},
    {'title': 'B', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/B.mp4'},
    {'title': 'C', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/C.mp4'},
    {'title': 'D', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/D.mp4'},
    {'title': 'E', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/E.mp4'},
    {'title': 'F', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/F.mp4'},
    {'title': 'G', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/G.mp4'},
    {'title': 'H', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/H.mp4'},
    {'title': 'I', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/I.mp4'},
    {'title': 'J', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/J.mp4'},
    {'title': 'K', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/K.mp4'},
    {'title': 'L', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/L.mp4'},
    {'title': 'M', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/M.mp4'},
    {'title': 'N', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/N.mp4'},
    {'title': 'O', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/O.mp4'},
    {'title': 'P', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/P.mp4'},
    {'title': 'Q', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Q.mp4'},
    {'title': 'R', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/R.mp4'},
    {'title': 'S', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/S.mp4'},
    {'title': 'T', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/T.mp4'},
    {'title': 'U', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/U.mp4'},
    {'title': 'V', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/V.mp4'},
    {'title': 'W', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/videos/W.mp4'},
    {'title': 'S', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/X.mp4'},
    {'title': 'Y', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Y.mp4'},
    {'title': 'Z', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Z.mp4'},
    {'title': 'Backspace', 'category': 'Alphabets', 'difficulty': 'Medium'},
    {'title': 'Space', 'category': 'Alphabets', 'difficulty': 'Easy'},
    // greetings and others
    {'title': 'Hari ini', 'category': 'Greetings', 'difficulty': 'Medium'},
    {'title': 'Hello', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'I', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'I love you', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'Kawan-kawan', 'category': 'Family', 'difficulty': 'Medium'},
    {'title': 'Malam', 'category': 'Greetings', 'difficulty': 'Medium'},
    {'title': 'Pagi', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'Selamat', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'Tengahari', 'category': 'Greetings', 'difficulty': 'Medium'},
    {'title': 'Terima Kasih', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'Ucapan', 'category': 'Greetings', 'difficulty': 'Medium'},
    {'title': 'How much', 'category': 'Greetings', 'difficulty': 'Hard'},
    {'title': 'No', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'Yes', 'category': 'Greetings', 'difficulty': 'Easy'},
    {'title': 'Sorry', 'category': 'Greetings', 'difficulty': 'Easy'},
  ];


  @override
  Widget build(BuildContext context) {
    final filteredSigns = signs.where((sign) {
      final matchesSearch = sign['title']!
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final matchesCategory = selectedCategory == 'All' ||
          sign['category'] == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Use pop if there's a route to pop, otherwise go to home
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        centerTitle: true,
        title: const Text(
          'Learn Mode',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search signs (e.g., 'Hello')",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Categories
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    final bool isSelected = category == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[800],
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Grid of cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filteredSigns.length,
                itemBuilder: (context, index) {
                  final sign = filteredSigns[index];
                  return GestureDetector(
                    onTap: () {
                      _showVideoPopup(context, sign); // ✅ show popup
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            spreadRadius: 2,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                    image: const DecorationImage(
                                      image: AssetImage('assets/placeholder.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    radius: 16,
                                    child: Icon(Icons.play_arrow,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sign['title']!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(sign['category']!,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(sign['difficulty']!,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.blue.shade700)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

// ✅ Function to show popup dialog with video
void _showVideoPopup(BuildContext context, Map<String, String> sign) {
  // 🟢 Mark this sign as watched
  ProgressManager().markAsWatched(sign['title']!);

  // 🟦 Then show video dialog
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(20),
        child: _VideoPlayerDialog(
          videoPath: sign['video']!,
          title: sign['title']!,
        ),
      );
    },
  );
}

}

// ✅ Separate stateful widget for the video player inside popup
class _VideoPlayerDialog extends StatefulWidget {
  final String videoPath;
  final String title;

  const _VideoPlayerDialog({required this.videoPath, required this.title});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.isInitialized
              ? _controller.value.aspectRatio
              : 16 / 9,
          child: _controller.value.isInitialized
              ? VideoPlayer(_controller)
              : const Center(child: CircularProgressIndicator()),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text("Close", style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}
