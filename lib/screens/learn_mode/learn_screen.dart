import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:signlinggo/data/progress_manager.dart';
import 'package:signlinggo/services/sign_service.dart';
import 'package:signlinggo/data/models/sign_model.dart';
import 'package:signlinggo/data/models/category_model.dart';

class LearnModePage extends StatefulWidget {
  const LearnModePage({super.key});

  @override
  State<LearnModePage> createState() => _LearnModePageState();
}

class _LearnModePageState extends State<LearnModePage> {
  String? selectedCategoryId; // null means "All"
  String selectedCategoryName = 'All';
  final TextEditingController _searchController = TextEditingController();
  final SignService _signService = SignService();

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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

              // Categories - Dynamically loaded from Firestore
              StreamBuilder<List<Category>>(
                stream: _signService.getCategories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final categories = snapshot.data!;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // "All" category button
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategoryId = null;
                                selectedCategoryName = 'All';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedCategoryName == 'All'
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'All',
                                style: TextStyle(
                                  color: selectedCategoryName == 'All'
                                      ? Colors.white
                                      : Colors.grey[800],
                                  fontWeight: selectedCategoryName == 'All'
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Dynamic categories from Firestore
                        ...categories.map((category) {
                          final bool isSelected = selectedCategoryId == category.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCategoryId = category.id;
                                  selectedCategoryName = category.name;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[800],
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // StreamBuilder for Firebase data
              StreamBuilder<List<Sign>>(
                stream: _signService.getFilteredSigns(selectedCategoryId, searchQuery),
                builder: (context, snapshot) {
                  // Loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // Error state
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading signs',
                              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Empty state
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No signs found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'No signs available in this category',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Data loaded successfully
                  final signs = snapshot.data!;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: signs.length,
                    itemBuilder: (context, index) {
                      final sign = signs[index];
                      final progressManager = Provider.of<ProgressManager>(context);
                      final isWatched = progressManager.isWatched(sign.title);
                      
                      return GestureDetector(
                        onTap: () {
                          _showVideoPopup(context, sign);
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
                            border: isWatched 
                              ? Border.all(color: Colors.green, width: 2)
                              : null,
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
                                          image: AssetImage('assets/assets/placeholder.png'),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    
                                    // Already watched indicator
                                    if (isWatched)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
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
                                    Text(sign.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(selectedCategoryName,
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(sign.difficultyLevel,
                                              style: TextStyle(
                                                  fontSize: 12, color: Colors.blue.shade700)),
                                        ),
                                        const Spacer(),
                                        if (isWatched)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to show popup dialog with video
  void _showVideoPopup(BuildContext context, Sign sign) {
    // Mark this sign as watched
    final progressManager = Provider.of<ProgressManager>(context, listen: false);
    progressManager.markAsWatched(sign.title);

    // Show video dialog
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(20),
          child: _VideoPlayerDialog(
            videoPath: sign.videoUrl,
            title: sign.title,
          ),
        );
      },
    );
  }
}

// Separate stateful widget for the video player inside popup
class _VideoPlayerDialog extends StatefulWidget {
  final String videoPath;
  final String title;

  const _VideoPlayerDialog({required this.videoPath, required this.title});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isNetworkVideo = false;

  @override
  void initState() {
    super.initState();
    
    // Check if video is from network or asset
    _isNetworkVideo = widget.videoPath.startsWith('http://') || 
                      widget.videoPath.startsWith('https://');
    
    // Initialize appropriate controller
    _controller = _isNetworkVideo
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoPath))
        : VideoPlayerController.asset(widget.videoPath);
    
    _controller.initialize().then((_) {
      setState(() {});
      _controller.play();
    }).catchError((error) {
      print('❌ Error loading video: $error');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressManager = Provider.of<ProgressManager>(context);
    final isWatched = progressManager.isWatched(widget.title);
    
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
          child: Column(
            children: [
              Text(widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              if (isWatched)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Learned',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                  ],
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}